// ============================================================
// DeepRest E2EE core — end-to-end encryption for direct messages.
//
// Design (v1):
//  • Your encryption identity is derived FROM YOUR PASSWORD with
//    PBKDF2-SHA256 (150k iterations). Same password on any device
//    = same keys, so nothing needs backing up and the server never
//    sees or stores anything that can decrypt your DMs.
//  • P-256 keypair from that seed; the PUBLIC key is registered on
//    the server so chat partners can find it.
//  • A DM's key = HKDF(ECDH(my_private, peer_public), salt=convoId).
//    The server only ever stores AES-256-GCM ciphertext.
//  • Messages encrypted by older clients (or when a partner has no
//    registered key yet) stay plain text and render as-is.
//
// Interop with the website's WebCrypto build is proven by
// tool/e2ee_probe.dart + scripts/e2ee_probe.mjs (INTEROP PASS).
// ============================================================
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/ecc/ecdh.dart' show ECDHBasicAgreement;
import 'package:pointycastle/export.dart' as pc;
import 'package:shared_preferences/shared_preferences.dart';

final _pcParams = pc.ECDomainParameters('prime256v1');

BigInt _bytesToBigInt(List<int> b) {
  var r = BigInt.zero;
  for (final x in b) {
    r = (r << 8) | BigInt.from(x);
  }
  return r;
}

List<int> _bigIntToBytes(BigInt v) {
  if (v == BigInt.zero) return const [0];
  final out = <int>[];
  var x = v;
  while (x > BigInt.zero) {
    out.insert(0, (x & BigInt.from(0xff)).toInt());
    x >>= 8;
  }
  return out;
}

class DeepKeys {
  static const _seedKey = 'deeprest_e2ee_seed';
  static const _ownerKey = 'deeprest_e2ee_owner';

  static pc.ECPrivateKey? _priv;
  static String? _pubB64;
  static String? _ownerName;
  static final _dmKeys = <String, String>{}; // 'convoId|peerPub' -> key b64

  static bool get ready => _priv != null;
  static String? get publicKeyB64 => _pubB64;

  /// Restore keys saved on this device (fast path after app restart).
  static Future<void> restore() async {
    final sp = await SharedPreferences.getInstance();
    final seedB64 = sp.getString(_seedKey);
    final owner = sp.getString(_ownerKey);
    if (seedB64 == null) return;
    _ownerName = owner;
    _applySeed(base64Decode(seedB64));
  }

  /// Derive + persist keys from the login credentials.
  static Future<void> initFromPassword(String name, String password) async {
    final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 150000, bits: 256);
    final seed = await (await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: utf8.encode('deeprest:v1:${name.trim().toLowerCase()}'),
    ))
        .extractBytes();
    _ownerName = name.trim().toLowerCase();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_seedKey, base64Encode(seed));
    await sp.setString(_ownerKey, _ownerName!);
    _applySeed(seed);
  }

  static void _applySeed(List<int> seed) {
    var d = _bytesToBigInt(seed) % _pcParams.n;
    if (d == BigInt.zero) d = BigInt.one;
    _priv = pc.ECPrivateKey(d, _pcParams);
    // Uncompressed point 0x04||X||Y — identical to WebCrypto 'raw' export.
    _pubB64 = base64Encode((_pcParams.G * d)!.getEncoded(false));
    _dmKeys.clear();
  }

  static Future<void> clear() async {
    _priv = null;
    _pubB64 = null;
    _ownerName = null;
    _dmKeys.clear();
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_seedKey);
    await sp.remove(_ownerKey);
  }

  static String _dmKey(String convoId, String peerPubB64) {
    final k = _dmKeys['$convoId|$peerPubB64'];
    if (k != null) return k;
    final q = _pcParams.curve.decodePoint(base64Decode(peerPubB64));
    final agree = ECDHBasicAgreement()..init(_priv!);
    final z = agree.calculateAgreement(pc.ECPublicKey(q, _pcParams));
    var shared = _bigIntToBytes(z);
    shared = [...List.filled(32 - shared.length, 0), ...shared]; // left-pad
    return _dmKeys['$convoId|$peerPubB64'] = _hkdfB64(
        shared, 'deeprest:dm:$convoId', 'dm-v1');
  }

  static String _hkdfB64(List<int> ikm, String salt, String info) {
    // Synchronous HKDF (RFC 5869) via pointycastle — byte-identical to
    // WebCrypto's deriveBits(HKDF) used by the website.
    final hkdf = pc.HKDFKeyDerivator(pc.SHA256Digest())
      ..init(pc.HkdfParameters(Uint8List.fromList(ikm), 32, Uint8List.fromList(utf8.encode(salt)), Uint8List.fromList(utf8.encode(info))));
    final out = Uint8List(32);
    hkdf.deriveKey(null, 0, out, 0);
    return base64Encode(out);
  }

  /// Encrypt a DM body. Returns a JSON envelope string, or the plain text
  /// unchanged if E2EE isn't possible yet (no keys / no partner key).
  static Future<String> encryptDm(
      String convoId, String? peerPubB64, String plain) async {
    if (!ready || peerPubB64 == null || peerPubB64.isEmpty) return plain;
    try {
      final algo = AesGcm.with256bits();
      final nonce = algo.newNonce();
      final box = await algo.encrypt(
        utf8.encode(plain),
        secretKey: SecretKey(base64Decode(_dmKey(convoId, peerPubB64))),
        nonce: nonce,
      );
      return jsonEncode({
        'v': 1,
        'iv': base64Encode(nonce),
        'ct': base64Encode([...box.cipherText, ...box.mac.bytes]),
      });
    } catch (_) {
      return plain;
    }
  }

  /// Decrypt a body that may be an E2EE envelope or a legacy plain text.
  /// Never throws — returns the original string when it can't decrypt.
  static Future<String> decryptDm(
      String convoId, String? peerPubB64, String body) async {
    if (!body.startsWith('{"v":1,')) return body;
    if (!ready || peerPubB64 == null || peerPubB64.isEmpty) return '🔒 Encrypted message — sign in with your password to read it.';
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      if (j['v'] != 1) return body;
      final all = base64Decode(j['ct'] as String);
      final algo = AesGcm.with256bits();
      final clear = await algo.decrypt(
        SecretBox(all.sublist(0, all.length - 16),
            nonce: base64Decode(j['iv'] as String), mac: Mac(all.sublist(all.length - 16))),
        secretKey: SecretKey(base64Decode(_dmKey(convoId, peerPubB64))),
      );
      return utf8.decode(clear);
    } catch (_) {
      return '🔒 Encrypted message';
    }
  }
}

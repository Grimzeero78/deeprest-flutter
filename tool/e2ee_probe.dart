// ignore_for_file: avoid_print
// E2EE interop probe — verifies the EXACT crypto stack the app will use
// matches WebCrypto (the website) byte-for-byte:
//   PBKDF2-SHA256 -> P-256 keypair from seed -> ECDH -> HKDF -> AES-256-GCM
// ECDH via pointycastle (pure Dart, no NDK); the rest via package:cryptography.
// Usage:  dart run tool/e2ee_probe.dart gen   (writes /tmp/probe_dart.json)
//         dart run tool/e2ee_probe.dart check (reads /tmp/probe_node.json)
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/ecc/ecdh.dart' show ECDHBasicAgreement;
import 'package:pointycastle/export.dart' as pc;

const name = 'Isaac Test';
const password = 'correct horse battery';
const convoId = 'dm_test_001';

final pcParams = pc.ECDomainParameters('prime256v1');

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

/// Valid P-256 scalar from a 32-byte seed (reduced mod curve order).
pc.ECPrivateKey privFromSeed(List<int> seed) {
  var d = _bytesToBigInt(seed) % pcParams.n;
  if (d == BigInt.zero) d = BigInt.one;
  return pc.ECPrivateKey(d, pcParams);
}

/// Uncompressed point 0x04||X||Y (65 bytes) — same as WebCrypto 'raw' format.
String pubB64(pc.ECPrivateKey priv) =>
    base64Encode((pcParams.G * priv.d)!.getEncoded(false));

Future<List<int>> shared(pc.ECPrivateKey priv, String peerB64) async {
  final q = pcParams.curve.decodePoint(base64Decode(peerB64));
  final agree = ECDHBasicAgreement()..init(priv);
  final z = agree.calculateAgreement(pc.ECPublicKey(q, pcParams));
  final b = _bigIntToBytes(z);
  return [...List.filled(32 - b.length, 0), ...b];
}

Future<List<int>> hkdf(List<int> ikm, String salt, String info) async {
  // Same RFC 5869 implementation the app ships (pointycastle) — re-prove it.
  final gen = pc.HKDFKeyDerivator(pc.SHA256Digest())
    ..init(pc.HkdfParameters(Uint8List.fromList(ikm), 32, Uint8List.fromList(utf8.encode(salt)), Uint8List.fromList(utf8.encode(info))));
  final out = Uint8List(32);
  gen.deriveKey(null, 0, out, 0);
  return out;
}

Future<String> encrypt(String keyB64, String plain) async {
  final algo = AesGcm.with256bits();
  final nonce = algo.newNonce();
  final box = await algo.encrypt(
    utf8.encode(plain),
    secretKey: SecretKey(base64Decode(keyB64)),
    nonce: nonce,
  );
  return jsonEncode({
    'v': 1,
    'iv': base64Encode(nonce),
    'ct': base64Encode([...box.cipherText, ...box.mac.bytes]),
  });
}

Future<String> decrypt(String keyB64, String body) async {
  final j = jsonDecode(body) as Map<String, dynamic>;
  final all = base64Decode(j['ct'] as String);
  final ct = all.sublist(0, all.length - 16);
  final mac = all.sublist(all.length - 16);
  final algo = AesGcm.with256bits();
  final clear = await algo.decrypt(
    SecretBox(ct, nonce: base64Decode(j['iv'] as String), mac: Mac(mac)),
    secretKey: SecretKey(base64Decode(keyB64)),
  );
  return utf8.decode(clear);
}

Future<List<int>> deriveSeed(String pw, String nm) async {
  final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 150000, bits: 256);
  return (await pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(pw)),
    nonce: utf8.encode('deeprest:v1:${nm.trim().toLowerCase()}'),
  ))
      .extractBytes();
}

Future<void> main(List<String> args) async {
  final mode = args.isNotEmpty ? args[0] : 'gen';
  final alice = privFromSeed(await deriveSeed(password, name));
  final alicePub = pubB64(alice);
  final bob = privFromSeed(await deriveSeed('bob pw 12345678', 'bob'));
  final bobPub = pubB64(bob);

  final dmKey = base64Encode(
      await hkdf(await shared(alice, bobPub), 'deeprest:dm:$convoId', 'dm-v1'));
  final dartEnc = await encrypt(dmKey, 'hello from flutter 🌙');

  if (mode == 'gen') {
    await File('/tmp/probe_dart.json').writeAsString(jsonEncode({
      'alicePub': alicePub,
      'bobPub': bobPub,
      'aliceToBob': dartEnc,
    }));
    print('dart gen done -> /tmp/probe_dart.json');
    return;
  }

  // check mode: node wrote its ciphertext + decrypted ours
  final n =
      jsonDecode(File('/tmp/probe_node.json').readAsStringSync()) as Map<String, dynamic>;
  final got = await decrypt(dmKey, n['nodeToAlice'] as String);
  final mineDecrypted = n['dartDecrypted'] == 'hello from flutter 🌙';
  print('dart pub == node pub: ${alicePub == n['alicePub']}');
  print('dart decrypted node msg: "$got"');
  print('node decrypted dart msg: $mineDecrypted');
  final ok =
      alicePub == n['alicePub'] && got == 'hi dart, node here 🚀' && mineDecrypted;
  print(ok ? 'INTEROP PASS ✅' : 'INTEROP FAIL ❌');
  exit(ok ? 0 : 1);
}

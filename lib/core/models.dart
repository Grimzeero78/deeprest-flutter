// DeepRest data models — parsed defensively (null-safe) from the API.
class Me {
  final String id, name, username;
  final int totalPoints, streak;
  final int dailyTargetMin;
  final int minutesUsed;
  final bool metTarget;
  final List<TopApp> topApps;
  final int rankLevel;
  final String rankName;
  final String? nextRankName;
  final int? nextRankMinXp;
  final int progressPercent;
  final List<HistoryDay> history;

  Me({
    required this.id,
    required this.name,
    required this.username,
    required this.totalPoints,
    required this.streak,
    required this.dailyTargetMin,
    required this.minutesUsed,
    required this.metTarget,
    required this.topApps,
    required this.rankLevel,
    required this.rankName,
    required this.nextRankName,
    required this.nextRankMinXp,
    required this.progressPercent,
    required this.history,
  });

  factory Me.fromJson(Map<String, dynamic> j) {
    final user = (j['user'] ?? {}) as Map<String, dynamic>;
    final today = (j['today'] ?? {}) as Map<String, dynamic>;
    final rank = (j['rank'] ?? {}) as Map<String, dynamic>;
    final cur = (rank['current'] ?? {}) as Map<String, dynamic>;
    final next = rank['next'] as Map<String, dynamic>?;
    final settings = (j['settings'] ?? {}) as Map<String, dynamic>;
    return Me(
      id: (user['id'] ?? '') as String,
      name: (user['name'] ?? '') as String,
      username: (user['username'] ?? '') as String,
      totalPoints: (user['totalPoints'] ?? 0) as int,
      streak: (user['streak'] ?? 0) as int,
      dailyTargetMin: (settings['dailyTargetMin'] ?? today['targetMin'] ?? 360) as int,
      minutesUsed: (today['minutesUsed'] ?? 0) as int,
      metTarget: (today['metTarget'] ?? false) as bool,
      topApps: ((today['topApps'] as List?) ?? [])
          .map((e) => TopApp.fromJson(e as Map<String, dynamic>))
          .toList(),
      rankLevel: (cur['level'] ?? 1) as int,
      rankName: (cur['name'] ?? 'Sleepless') as String,
      nextRankName: next?['name'] as String?,
      nextRankMinXp: next?['minXp'] as int?,
      progressPercent: (rank['progressPercent'] ?? 0) as int,
      history: ((j['history'] as List?) ?? [])
          .map((e) => HistoryDay.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TopApp {
  final String name;
  final int minutes;
  TopApp({required this.name, required this.minutes});
  factory TopApp.fromJson(Map<String, dynamic> j) =>
      TopApp(name: (j['name'] ?? '') as String, minutes: (j['minutes'] ?? 0) as int);
}

class HistoryDay {
  final String date;
  final int minutesUsed, targetMin;
  final bool metTarget;
  HistoryDay({required this.date, required this.minutesUsed, required this.targetMin, required this.metTarget});
  factory HistoryDay.fromJson(Map<String, dynamic> j) => HistoryDay(
      date: (j['date'] ?? '') as String,
      minutesUsed: (j['minutesUsed'] ?? 0) as int,
      targetMin: (j['targetMin'] ?? 0) as int,
      metTarget: (j['metTarget'] ?? false) as bool);
}

class User {
  final String id, name, username;
  final String? avatarColor, avatarImage, avatarEmoji, bio;
  final int totalPoints, streak;
  final bool online, isMe;
  final String? lastSeenAt;
  User({
    required this.id,
    required this.name,
    required this.username,
    this.avatarColor,
    this.avatarImage,
    this.avatarEmoji,
    this.bio,
    required this.totalPoints,
    required this.streak,
    required this.online,
    required this.isMe,
    this.lastSeenAt,
  });
  factory User.fromJson(Map<String, dynamic> j) => User(
      id: (j['id'] ?? '') as String,
      name: (j['name'] ?? '') as String,
      username: (j['username'] ?? '') as String,
      avatarColor: j['avatarColor'] as String?,
      avatarImage: j['avatarImage'] as String?,
      avatarEmoji: j['avatarEmoji'] as String?,
      bio: j['bio'] as String?,
      totalPoints: (j['totalPoints'] ?? 0) as int,
      streak: (j['streak'] ?? 0) as int,
      online: (j['online'] ?? false) as bool,
      isMe: (j['isMe'] ?? false) as bool,
      lastSeenAt: j['lastSeenAt'] as String?);
}

class LastMessage {
  final String body, kind, senderId, senderName;
  final String createdAt;
  LastMessage({required this.body, required this.kind, required this.senderId, required this.senderName, required this.createdAt});
  factory LastMessage.fromJson(Map<String, dynamic> j) => LastMessage(
      body: (j['body'] ?? '') as String,
      kind: (j['kind'] ?? 'text') as String,
      senderId: (j['senderId'] ?? '') as String,
      senderName: (j['senderName'] ?? '') as String,
      createdAt: (j['createdAt'] ?? '') as String);
}

class Conversation {
  final String id, kind, name;
  final String? emoji, peerLastReadAt;
  final int unreadCount, memberCount;
  final LastMessage? lastMessage;
  final User? peer;
  final bool online;
  final String? lastSeenAt;
  final List<User> members;
  Conversation({
    required this.id,
    required this.kind,
    required this.name,
    this.emoji,
    this.peerLastReadAt,
    required this.unreadCount,
    required this.memberCount,
    this.lastMessage,
    this.peer,
    required this.online,
    this.lastSeenAt,
    required this.members,
  });
  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
      id: (j['id'] ?? '') as String,
      kind: (j['kind'] ?? 'dm') as String,
      name: (j['name'] ?? '') as String,
      emoji: j['emoji'] as String?,
      peerLastReadAt: j['peerLastReadAt'] as String?,
      unreadCount: (j['unreadCount'] ?? 0) as int,
      memberCount: (j['memberCount'] ?? 0) as int,
      lastMessage: j['lastMessage'] == null ? null : LastMessage.fromJson(j['lastMessage'] as Map<String, dynamic>),
      peer: j['peer'] == null ? null : User.fromJson(j['peer'] as Map<String, dynamic>),
      online: (j['online'] ?? false) as bool,
      lastSeenAt: j['lastSeenAt'] as String?,
      members: ((j['members'] as List?) ?? []).map((e) => User.fromJson(e as Map<String, dynamic>)).toList());
}

class ChatMessage {
  final String id, body, kind, senderId, senderName, createdAt;
  final String? senderColor, senderImage, senderEmoji;
  final bool mine;
  ChatMessage({required this.id, required this.body, required this.kind, required this.senderId, required this.senderName, required this.createdAt, this.senderColor, this.senderImage, this.senderEmoji, required this.mine});
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
      id: (j['id'] ?? '') as String,
      body: (j['body'] ?? '') as String,
      kind: (j['kind'] ?? 'text') as String,
      senderId: (j['senderId'] ?? '') as String,
      senderName: (j['senderName'] ?? '') as String,
      createdAt: (j['createdAt'] ?? '') as String,
      senderColor: j['senderColor'] as String?,
      senderImage: j['senderImage'] as String?,
      senderEmoji: j['senderEmoji'] as String?,
      mine: (j['mine'] ?? false) as bool);
}

class SosAlert {
  final String id, message, status, createdAt;
  final String? reply, repliedAt;
  SosAlert({required this.id, required this.message, required this.status, required this.createdAt, this.reply, this.repliedAt});
  factory SosAlert.fromJson(Map<String, dynamic> j) => SosAlert(
      id: (j['id'] ?? '') as String,
      message: (j['message'] ?? '') as String,
      status: (j['status'] ?? '') as String,
      createdAt: (j['createdAt'] ?? '') as String,
      reply: j['reply'] as String?,
      repliedAt: j['repliedAt'] as String?);
}

class DuoState {
  final bool hasPartner;
  final String? inviteCode;
  final User? partner;
  final int partnerMinutes, partnerTarget;
  final bool partnerMetTarget;
  DuoState({required this.hasPartner, this.inviteCode, this.partner, required this.partnerMinutes, required this.partnerTarget, required this.partnerMetTarget});
}

class AiMsg {
  final String role, content, createdAt;
  AiMsg({required this.role, required this.content, required this.createdAt});
  factory AiMsg.fromJson(Map<String, dynamic> j) => AiMsg(
      role: (j['role'] ?? 'assistant') as String,
      content: (j['content'] ?? '') as String,
      createdAt: (j['createdAt'] ?? '') as String);
}

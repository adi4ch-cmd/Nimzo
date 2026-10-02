class Room {
  final String id;
  final int roomNo;
  final String name;
  final String ownerId;
  final String? country;
  final String theme;
  final bool isPrivate;
  final String status;
  final int lifetimeGiftCoins;
  final DateTime createdAt;
  final Map<String, String> permissions;
  final String? rules;
  const Room({required this.id, required this.roomNo, required this.name, required this.ownerId,
      this.country, required this.theme, required this.isPrivate, required this.status, this.lifetimeGiftCoins = 0, required this.createdAt, this.permissions = const {}, this.rules});

  factory Room.fromJson(Map<String, dynamic> j) => Room(
        id: j['id'], roomNo: j['room_no'], name: j['name'], ownerId: j['owner_id'],
        country: j['country'], theme: j['theme'] ?? 'nimzo_white',
        isPrivate: j['is_private'] ?? false, status: j['status'] ?? 'open', lifetimeGiftCoins: (j['lifetime_gift_coins'] ?? 0) as int,
        createdAt: DateTime.parse(j['created_at']),
        rules: j['rules'],
        permissions: {
          for (final k in const ['mic_permission', 'chat_permission', 'guest_permission', 'gift_permission', 'music_permission', 'game_permission', 'visitor_permission'])
            if (j[k] != null) k: j[k] as String
        });
}

class MicSeat {
  final int seatNo;
  final String? userId;
  final bool muted;
  final bool locked;
  const MicSeat({required this.seatNo, this.userId, this.muted = false, this.locked = false});
  factory MicSeat.fromJson(Map<String, dynamic> j) => MicSeat(
      seatNo: j['seat_no'], userId: j['user_id'], muted: j['muted'] ?? false, locked: j['locked'] ?? false);
}

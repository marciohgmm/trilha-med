import '../../../core/base/firestore_entity.dart';
import '../enums/platform_enums.dart';

/// Notificação in-app do usuário (`users/{uid}/platform_notifications`).
class UserNotification implements FirestoreEntity {
  @override
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationChannel channel;
  final bool isRead;
  final String? actionRoute;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const UserNotification({
    required this.id,
    required this.userId,
    required this.title,
    this.body = '',
    this.channel = NotificationChannel.inApp,
    this.isRead = false,
    this.actionRoute,
    this.payload = const {},
    required this.createdAt,
  });

  factory UserNotification.fromDoc(String id, Map<String, dynamic> d) {
    return UserNotification(
      id: id,
      userId: d['userId']?.toString() ?? '',
      title: d['title']?.toString() ?? '',
      body: d['body']?.toString() ?? '',
      channel: NotificationChannel.fromKey(d['channel']?.toString()),
      isRead: d['isRead'] as bool? ?? false,
      actionRoute: d['actionRoute']?.toString(),
      payload: Map<String, dynamic>.from(d['payload'] as Map? ?? {}),
      createdAt: FirestoreDates.from(d['createdAt']) ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'userId': userId,
        'title': title,
        'body': body,
        'channel': channel.key,
        'isRead': isRead,
        if (actionRoute != null) 'actionRoute': actionRoute,
        if (payload.isNotEmpty) 'payload': payload,
        'createdAt': FirestoreDates.to(createdAt),
      };
}

/// Perfil público mínimo (`users/{uid}/public_profile/profile`).
class UserPublicProfile {
  final String userId;
  final String displayName;
  final String? photoUrl;

  const UserPublicProfile({
    required this.userId,
    this.displayName = '',
    this.photoUrl,
  });

  factory UserPublicProfile.fromMap(String userId, Map<String, dynamic>? map) {
    if (map == null) {
      return UserPublicProfile(userId: userId);
    }
    return UserPublicProfile(
      userId: userId,
      displayName: map['displayName']?.toString() ?? '',
      photoUrl: map['photoUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      if (photoUrl != null && photoUrl!.isNotEmpty) 'photoUrl': photoUrl,
    };
  }
}

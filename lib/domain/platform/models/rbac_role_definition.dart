import '../../../core/base/firestore_entity.dart';

/// Papel RBAC (`platform_rbac_roles/{roleKey}`).
class RbacRoleDefinition implements FirestoreEntity {
  @override
  final String id;
  final String label;
  final List<String> permissionKeys;
  final bool isSystem;
  final int priority;

  const RbacRoleDefinition({
    required this.id,
    required this.label,
    this.permissionKeys = const [],
    this.isSystem = false,
    this.priority = 0,
  });

  factory RbacRoleDefinition.fromDoc(String id, Map<String, dynamic> d) {
    final keys = d['permissionKeys'];
    return RbacRoleDefinition(
      id: id,
      label: d['label']?.toString() ?? id,
      permissionKeys: keys is List
          ? keys.map((e) => e.toString()).toList()
          : const [],
      isSystem: d['isSystem'] as bool? ?? false,
      priority: (d['priority'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'label': label,
        'permissionKeys': permissionKeys,
        'isSystem': isSystem,
        'priority': priority,
      };
}

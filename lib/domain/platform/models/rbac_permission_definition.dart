import '../../../core/base/firestore_entity.dart';

/// Permissão registrada no catálogo (`platform_rbac_permissions/{key}`).
///
/// O ID do documento é a própria chave (ex.: `content.read`).
class RbacPermissionDefinition implements FirestoreEntity {
  @override
  final String id;
  final String label;
  final String description;
  final bool isActive;
  final String category;

  const RbacPermissionDefinition({
    required this.id,
    required this.label,
    this.description = '',
    this.isActive = true,
    this.category = 'general',
  });

  factory RbacPermissionDefinition.fromDoc(String id, Map<String, dynamic> d) {
    return RbacPermissionDefinition(
      id: id,
      label: d['label']?.toString() ?? id,
      description: d['description']?.toString() ?? '',
      isActive: d['isActive'] as bool? ?? true,
      category: d['category']?.toString() ?? 'general',
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'label': label,
        'description': description,
        'isActive': isActive,
        'category': category,
      };
}

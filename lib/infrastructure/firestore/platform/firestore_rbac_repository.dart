import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/rbac/rbac_catalog.dart';
import '../../../data/rbac_default_seed.dart';
import '../../../domain/platform/models/rbac_permission_definition.dart';
import '../../../domain/platform/models/rbac_role_definition.dart';
import '../../../domain/platform/repositories/rbac_repository.dart';

class FirestoreRbacRepository implements RbacRepository {
  FirestoreRbacRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _rolesCol =>
      _db.collection(FirestorePaths.platformRbacRoles);

  CollectionReference<Map<String, dynamic>> get _permsCol =>
      _db.collection(FirestorePaths.platformRbacPermissions);

  @override
  Stream<RbacCatalog> watchCatalog() {
    return _rolesCol.snapshots().asyncMap((_) => loadCatalog());
  }

  @override
  Future<RbacCatalog> loadCatalog() async {
    final rolesSnap = await _rolesCol.get();
    final permsSnap = await _permsCol.get();

    if (rolesSnap.docs.isEmpty) {
      return RbacCatalog.fallback();
    }

    final roles = <String, RbacRoleSnapshot>{};
    for (final d in rolesSnap.docs) {
      final def = RbacRoleDefinition.fromDoc(d.id, d.data());
      roles[def.id] = RbacRoleSnapshot(
        roleKey: def.id,
        label: def.label,
        permissionKeys: def.permissionKeys.toSet(),
        isSystem: def.isSystem,
        priority: def.priority,
      );
    }

    final labels = <String, String>{};
    for (final d in permsSnap.docs) {
      final p = RbacPermissionDefinition.fromDoc(d.id, d.data());
      if (p.isActive) labels[p.id] = p.label;
    }

    return RbacCatalog(rolesByKey: roles, permissionLabels: labels);
  }

  @override
  Future<int> ensureDefaultSeed() async {
    final rolesEmpty = (await _rolesCol.limit(1).get()).docs.isEmpty;
    if (!rolesEmpty) return 0;

    var n = 0;
    final batch = _db.batch();
    for (final p in RbacDefaultSeed.permissions()) {
      batch.set(_permsCol.doc(p.id), {
        ...p.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      n++;
    }
    for (final r in RbacDefaultSeed.roles()) {
      batch.set(_rolesCol.doc(r.id), {
        ...r.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      n++;
    }
    await batch.commit();
    return n;
  }

  @override
  Future<void> saveRole(RbacRoleDefinition role) async {
    await _rolesCol.doc(role.id).set({
      ...role.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> savePermission(RbacPermissionDefinition permission) async {
    await _permsCol.doc(permission.id).set({
      ...permission.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<List<RbacRoleDefinition>> listRoles() async {
    final snap = await _rolesCol.orderBy('priority', descending: true).get();
    return snap.docs
        .map((d) => RbacRoleDefinition.fromDoc(d.id, d.data()))
        .toList();
  }

  @override
  Future<List<RbacPermissionDefinition>> listPermissions() async {
    final snap = await _permsCol.get();
    return snap.docs
        .map((d) => RbacPermissionDefinition.fromDoc(d.id, d.data()))
        .toList();
  }
}

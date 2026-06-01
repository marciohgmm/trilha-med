import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/firestore_paths.dart';

/// Progresso de flashcards — fonte oficial `users/{uid}/progresso` (F1).
///
/// Substitui o path legado `usuarios/{uid}/progresso`.
/// Para migração de dados antigos, use [UserProgressMigrationService].
@Deprecated(
  'Use FirestorePaths.users + userProgressSubcollection diretamente '
  'ou UserProgressMigrationService. Coleção usuarios está obsoleta.',
)
class ProgressoService {
  ProgressoService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String get uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Usuário não está logado');
    }
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> _progressoRef(String cardId) =>
      _firestore
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection(FirestorePaths.userProgressSubcollection)
          .doc(cardId);

  /// Mantido por compatibilidade de API — grava apenas em `users`.
  Future<void> salvarResposta(
    String cardId,
    bool acertou,
  ) async {
    final ref = _progressoRef(cardId);
    final doc = await ref.get();

    int acertos = 0;
    int erros = 0;

    if (doc.exists) {
      acertos = (doc.data()?['acertos'] as num?)?.toInt() ?? 0;
      erros = (doc.data()?['erros'] as num?)?.toInt() ?? 0;
    }

    if (acertou) {
      acertos++;
    } else {
      erros++;
    }

    await ref.set({
      'acertos': acertos,
      'erros': erros,
      'ultima_revisao': Timestamp.now(),
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

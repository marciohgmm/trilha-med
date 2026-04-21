import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProgressoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("Usuário não está logado");
    }
    return user.uid;
  }

  Future<void> salvarResposta(
    String cardId,
    bool acertou,
  ) async {
    final ref = _firestore
        .collection('usuarios')
        .doc(uid)
        .collection('progresso')
        .doc(cardId);

    final doc = await ref.get();

    int acertos = 0;
    int erros = 0;

    if (doc.exists) {
      acertos = doc.data()?['acertos'] ?? 0;
      erros = doc.data()?['erros'] ?? 0;
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
    }, SetOptions(merge: true));
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';

class CronogramaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime _somenteData(DateTime data) {
    return DateTime(data.year, data.month, data.day);
  }

  Future<void> salvarDataProva({
    required String userId,
    required DateTime dataProva,
  }) async {
    final prova = _somenteData(dataProva);

    await _firestore.collection('cronograma_meta').doc(userId).set({
      'dataProva': Timestamp.fromDate(prova),
      'atualizadoEm': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> criarCronogramaInicial({
    required String userId,
    required DateTime dataProva,
  }) async {
    final metaDoc =
        await _firestore.collection('cronograma_meta').doc(userId).get();

    if (metaDoc.exists) {
      throw Exception('Cronograma já existe para este usuário');
    }

    await _batchCriarCronograma(userId, dataProva);
  }

  Future<void> marcarNovoConcluido({
    required String userId,
    required String itemId,
  }) async {
    final agora = _somenteData(DateTime.now());

    final itemRef = _firestore
        .collection('cronograma')
        .doc(userId)
        .collection('itens')
        .doc(itemId);

    await itemRef.update({
      'concluidoHoje': true,
      'ultimaConclusao': Timestamp.fromDate(agora),
      'atualizadoEm': Timestamp.now(),
    });
  }

  Future<void> marcarRevisaoConcluida({
    required String userId,
    required String itemId,
  }) async {
    final hoje = _somenteData(DateTime.now());

    await _firestore
        .collection('cronograma')
        .doc(userId)
        .collection('itens')
        .doc(itemId)
        .update({
      'concluidoHoje': true,
      'ultimaConclusao': Timestamp.fromDate(hoje),
      'atualizadoEm': Timestamp.now(),
    });
  }

  Future<void> desmarcarConclusao({
    required String userId,
    required String itemId,
  }) async {
    await _firestore
        .collection('cronograma')
        .doc(userId)
        .collection('itens')
        .doc(itemId)
        .update({
      'concluidoHoje': false,
      'atualizadoEm': Timestamp.now(),
    });
  }

  Future<void> resetarConcluidosDoDia(String userId) async {
    final snapshot = await _firestore
        .collection('cronograma')
        .doc(userId)
        .collection('itens')
        .where('concluidoHoje', isEqualTo: true)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'concluidoHoje': false});
    }

    await batch.commit();
  }

  Future<void> excluirCronograma(String userId) async {
    final batch = _firestore.batch();

    final itensSnapshot = await _firestore
        .collection('cronograma')
        .doc(userId)
        .collection('itens')
        .get();

    for (var doc in itensSnapshot.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_firestore.collection('cronograma_meta').doc(userId));

    await batch.commit();
  }

  Stream<QuerySnapshot> itensDeHoje(String userId) {
    return _firestore
        .collection('cronograma')
        .doc(userId)
        .collection('itens')
        .snapshots();
  }

  Stream<DocumentSnapshot> metaCronograma(String userId) {
    return _firestore.collection('cronograma_meta').doc(userId).snapshots();
  }

  Future<void> _batchCriarCronograma(
    String userId,
    DateTime dataProva,
  ) async {
    final batch = _firestore.batch();

    final flashcardsSnapshot = await _firestore.collection('flashcards').get();
    final subtemasUnicos = <String, Map<String, dynamic>>{};

    for (var doc in flashcardsSnapshot.docs) {
      final data = doc.data();
      final materia = (data['materia'] ?? '').toString().trim();
      final tema = (data['tema'] ?? '').toString().trim();
      final subtema = (data['subtema'] ?? '').toString().trim();

      if (materia.isEmpty || tema.isEmpty || subtema.isEmpty) continue;

      final key = '${materia}_${tema}_${subtema}';

      subtemasUnicos[key] = {
        'materia': materia,
        'tema': tema,
        'subtema': subtema,
      };
    }

    final listaSubtemas = subtemasUnicos.values.toList();

    final hoje = _somenteData(DateTime.now());
    final prova = _somenteData(dataProva);
    final diasRestantes = prova.difference(hoje).inDays.clamp(1, 3650);

    final totalSubtemas = listaSubtemas.length;
    if (totalSubtemas == 0) {
      await _firestore.collection('cronograma_meta').doc(userId).set({
        'dataProva': Timestamp.fromDate(prova),
        'criadoEm': Timestamp.now(),
        'atualizadoEm': Timestamp.now(),
        'totalSubtemas': 0,
        'metaDiaria': 0,
      });
      await batch.commit();
      return;
    }

    final metaDiaria = (totalSubtemas / diasRestantes).ceil().clamp(1, 999);

    for (int i = 0; i < listaSubtemas.length; i++) {
      final diaOffset = i ~/ metaDiaria;
      final dataEstudo = hoje.add(Duration(days: diaOffset));

      final docRef = _firestore
          .collection('cronograma')
          .doc(userId)
          .collection('itens')
          .doc();

      batch.set(docRef, {
        ...listaSubtemas[i],
        'dataEstudo': Timestamp.fromDate(dataEstudo),
        'status': 'novo',
        'concluidoHoje': false,
        'ultimaConclusao': null,
        'criadoEm': Timestamp.now(),
        'atualizadoEm': Timestamp.now(),
      });
    }

    batch.set(_firestore.collection('cronograma_meta').doc(userId), {
      'dataProva': Timestamp.fromDate(prova),
      'criadoEm': Timestamp.now(),
      'atualizadoEm': Timestamp.now(),
      'totalSubtemas': totalSubtemas,
      'metaDiaria': metaDiaria,
    });

    await batch.commit();
  }
}
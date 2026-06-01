import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:math';



import 'package:flutter_application_1/services/flashcard_subtema_catalog_service.dart';

import 'package:flutter_application_1/utils/content_hierarchy_utils.dart';



class CronogramaService {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FlashcardSubtemaCatalogService _subtemaCatalog =

      FlashcardSubtemaCatalogService.instance;



  DateTime _somenteData(DateTime data) {

    return DateTime(data.year, data.month, data.day);

  }



  DocumentReference<Map<String, dynamic>> _metaRef(String userId) {

    return _firestore

        .collection('users')

        .doc(userId)

        .collection('cronograma_meta')

        .doc('meta');

  }



  CollectionReference<Map<String, dynamic>> _itensRef(String userId) {

    return _firestore

        .collection('users')

        .doc(userId)

        .collection('cronograma_itens');

  }



  bool _ehFimDeSemana(DateTime d) {

    return d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

  }



  DateTime _proximoDiaUtil(DateTime d) {

    var x = _somenteData(d);

    while (_ehFimDeSemana(x)) {

      x = x.add(const Duration(days: 1));

    }

    return x;

  }



  Future<Map<String, Map<String, String>>> _carregarSubtemasDoCatalogo() async {

    final pairs = await _subtemaCatalog.fetchAllPairsForCronograma();

    final subtemasUnicos = <String, Map<String, String>>{};



    for (final pair in pairs) {

      final materia = pair['materia'] ?? '';

      final subtema = pair['subtema'] ?? '';

      if (materia.isEmpty || subtema.isEmpty) continue;

      final key = ContentHierarchyUtils.subtemaPairKey(materia, subtema);

      subtemasUnicos[key] = pair;

    }



    return subtemasUnicos;

  }



  Future<void> salvarDataProva({

    required String userId,

    required DateTime dataProva,

  }) async {

    final prova = _somenteData(dataProva);



    await _metaRef(userId).set({

      'dataProva': Timestamp.fromDate(prova),

      'atualizadoEm': Timestamp.now(),

    }, SetOptions(merge: true));

  }



  Future<void> criarCronogramaInicial({

    required String userId,

    required DateTime dataProva,

  }) async {

    final metaDoc = await _metaRef(userId).get();



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



    final itemRef = _itensRef(userId).doc(itemId);



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



    await _itensRef(userId).doc(itemId).update({

      'concluidoHoje': true,

      'ultimaConclusao': Timestamp.fromDate(hoje),

      'atualizadoEm': Timestamp.now(),

    });

  }



  Future<void> desmarcarConclusao({

    required String userId,

    required String itemId,

  }) async {

    await _itensRef(userId).doc(itemId).update({

      'concluidoHoje': false,

      'atualizadoEm': Timestamp.now(),

    });

  }



  Future<void> resetarConcluidosDoDia(String userId) async {

    final snapshot = await _firestore

        .collection('users')

        .doc(userId)

        .collection('cronograma_itens')

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



    final itensSnapshot = await _itensRef(userId).get();



    for (var doc in itensSnapshot.docs) {

      batch.delete(doc.reference);

    }



    batch.delete(_metaRef(userId));



    final progressoSnapshot = await _firestore

        .collection('users')

        .doc(userId)

        .collection('progresso')

        .get();

    for (final doc in progressoSnapshot.docs) {

      batch.delete(doc.reference);

    }



    await batch.commit();

  }



  Stream<QuerySnapshot> itensDeHoje(String userId) {

    return _itensRef(userId).snapshots();

  }



  Stream<DocumentSnapshot> metaCronograma(String userId) {

    return _metaRef(userId).snapshots();

  }



  Future<void> _batchCriarCronograma(

    String userId,

    DateTime dataProva,

  ) async {

    final batch = _firestore.batch();



    final subtemasUnicos = await _carregarSubtemasDoCatalogo();

    final listaSubtemas = subtemasUnicos.values.toList();

    listaSubtemas.shuffle(Random());



    final hoje = _somenteData(DateTime.now());

    final prova = _somenteData(dataProva);



    final totalSubtemas = listaSubtemas.length;

    if (totalSubtemas == 0) {

      await _metaRef(userId).set({

        'dataProva': Timestamp.fromDate(prova),

        'criadoEm': Timestamp.now(),

        'atualizadoEm': Timestamp.now(),

        'totalSubtemas': 0,

        'novosPorDia': 1,

      });

      await batch.commit();

      return;

    }



    // 1 tema novo por dia útil (sábado/domingo não entram novos).

    var dataCursor = _proximoDiaUtil(hoje);

    for (int i = 0; i < listaSubtemas.length; i++) {

      final docRef = _itensRef(userId).doc();

      batch.set(docRef, {

        ...listaSubtemas[i],

        'dataEstudo': Timestamp.fromDate(dataCursor),

        'status': 'novo',

        'concluidoHoje': false,

        'ultimaConclusao': null,

        'criadoEm': Timestamp.now(),

        'atualizadoEm': Timestamp.now(),

      });

      dataCursor = _proximoDiaUtil(dataCursor.add(const Duration(days: 1)));

    }



    batch.set(_metaRef(userId), {

      'dataProva': Timestamp.fromDate(prova),

      'criadoEm': Timestamp.now(),

      'atualizadoEm': Timestamp.now(),

      'totalSubtemas': totalSubtemas,

      'novosPorDia': 1,

    });



    await batch.commit();

  }



  /// Garante que subtemas recém-criados entrem no cronograma automaticamente.

  /// Regras:

  /// - 1 subtema novo por dia útil (sábado/domingo não entram novos)

  /// - só agenda subtemas presentes no catálogo agregado

  Future<void> sincronizarSubtemas(String userId) async {

    final subtemasUnicos = await _carregarSubtemasDoCatalogo();



    final existentes = await _itensRef(userId).get();

    final keysExistentes = <String>{};



    DateTime? maiorData;

    for (final doc in existentes.docs) {

      final data = doc.data();

      final materia = (data['materia'] ?? '').toString().trim();

      final subtema = (data['subtema'] ?? '').toString().trim();

      if (materia.isEmpty || subtema.isEmpty) continue;

      keysExistentes.add(ContentHierarchyUtils.subtemaPairKey(materia, subtema));



      final ts = data['dataEstudo'];

      if (ts is Timestamp) {

        final d = _somenteData(ts.toDate());

        if (maiorData == null || d.isAfter(maiorData)) maiorData = d;

      }

    }



    final faltantes = <Map<String, String>>[];

    for (final entry in subtemasUnicos.entries) {

      if (!keysExistentes.contains(entry.key)) {

        faltantes.add(entry.value);

      }

    }



    if (faltantes.isEmpty) return;

    faltantes.shuffle(Random());



    final batch = _firestore.batch();

    var cursor = _proximoDiaUtil((maiorData ?? _somenteData(DateTime.now()))

        .add(const Duration(days: 1)));

    for (final item in faltantes) {

      final docRef = _itensRef(userId).doc();

      batch.set(docRef, {

        ...item,

        'dataEstudo': Timestamp.fromDate(cursor),

        'status': 'novo',

        'concluidoHoje': false,

        'ultimaConclusao': null,

        'criadoEm': Timestamp.now(),

        'atualizadoEm': Timestamp.now(),

      });

      cursor = _proximoDiaUtil(cursor.add(const Duration(days: 1)));

    }



    batch.set(

        _metaRef(userId),

        {

          'atualizadoEm': Timestamp.now(),

          'totalSubtemas': subtemasUnicos.length,

          'novosPorDia': 1,

        },

        SetOptions(merge: true));



    await batch.commit();

  }

}



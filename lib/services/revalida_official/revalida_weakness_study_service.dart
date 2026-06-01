import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/revalida_official/revalida_official_config.dart';
import '../../models/questao_model.dart';
import '../../models/revalida_simulation_model.dart';
import '../questao_service.dart';

/// Gera plano de estudo a partir das fraquezas — sem IA.
class RevalidaWeaknessStudyService {
  RevalidaWeaknessStudyService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<RevalidaWeaknessStudyPlan> buildPlan({
    required List<RevalidaSubtopicBreakdown> weakSubtopics,
    required List<QuestaoModel> examQuestions,
    required Map<String, String> selecoes,
  }) async {
    final sorted = List<RevalidaSubtopicBreakdown>.from(weakSubtopics)
      ..sort((a, b) {
        final err = b.errorRatePercent.compareTo(a.errorRatePercent);
        if (err != 0) return err;
        return b.wrong.compareTo(a.wrong);
      });

    final top = sorted.take(5).toList();
    final flashcardIds = <String>{};
    final questaoIds = <String>{};
    final labels = <String>[];

    for (final sub in top) {
      labels.add('${sub.subject} — ${sub.subtopic}');

      final wrongInExam = examQuestions.where((q) {
        if (q.materia != sub.subject || q.subtema != sub.subtopic) {
          return false;
        }
        final sel = selecoes[q.id];
        return sel != null && sel.isNotEmpty && sel != q.corretaId;
      });
      for (final q in wrongInExam) {
        questaoIds.add(q.id);
        if (q.flashcardId != null && q.flashcardId!.isNotEmpty) {
          flashcardIds.add(q.flashcardId!);
        }
      }

      final flashSnap = await _db
          .collection('flashcards')
          .where('materia', isEqualTo: sub.subject)
          .where('subtema', isEqualTo: sub.subtopic)
          .limit(10)
          .get();
      for (final doc in flashSnap.docs) {
        flashcardIds.add(doc.id);
      }

      final questSnap = await _db
          .collection(QuestaoService.collectionQuestoes)
          .where('materia', isEqualTo: sub.subject)
          .get();
      for (final doc in questSnap.docs) {
        final q = QuestaoModel.fromMap(doc.id, doc.data());
        if (q.subtema != sub.subtopic || !q.disponivelParaEstudo) continue;
        questaoIds.add(q.id);
        if (q.flashcardId != null && q.flashcardId!.isNotEmpty) {
          flashcardIds.add(q.flashcardId!);
        }
        if (questaoIds.length >= 30) break;
      }
    }

    return RevalidaWeaknessStudyPlan(
      weakSubtopics: top,
      flashcardIds: flashcardIds.take(20).toList(),
      questaoIds: questaoIds.take(30).toList(),
      subtopicLabels: labels,
    );
  }
}

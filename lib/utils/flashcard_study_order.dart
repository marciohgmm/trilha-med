import 'package:cloud_firestore/cloud_firestore.dart';

/// Valor grande para cards **sem** [ordemEstudo] (ficam depois dos que têm ordem explícita).
const int kFlashcardOrdemEstudoAusente = 1 << 30;

int flashcardCreatedAtMillis(Map<String, dynamic> d) {
  final t = d['createdAt'];
  if (t is Timestamp) return t.millisecondsSinceEpoch;
  return 0;
}

int? flashcardOrdemEstudoNullable(Map<String, dynamic> d) {
  final raw = d['ordemEstudo'];
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw.toString());
}

/// Ordem na tela de estudo / reordenação:
/// 1) [ordemEstudo] quando existir (menor = mais cedo na fila pedagógica);
/// 2) cards sem campo usam [kFlashcardOrdemEstudoAusente] e desempatam por [createdAt];
/// 3) [DocumentReference.id].
void sortFlashcardDocsPorEstudo(List<QueryDocumentSnapshot> docs) {
  docs.sort((a, b) {
    final da = a.data() as Map<String, dynamic>;
    final db = b.data() as Map<String, dynamic>;
    final oa = flashcardOrdemEstudoNullable(da) ?? kFlashcardOrdemEstudoAusente;
    final ob = flashcardOrdemEstudoNullable(db) ?? kFlashcardOrdemEstudoAusente;
    if (oa != ob) return oa.compareTo(ob);
    final ca = flashcardCreatedAtMillis(da);
    final cb = flashcardCreatedAtMillis(db);
    if (ca != cb) return ca.compareTo(cb);
    return a.id.compareTo(b.id);
  });
}

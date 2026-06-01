import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Mensagens globais (comunicados) — Firestore, sem Storage.
class GlobalMessageService {
  GlobalMessageService._();
  static final GlobalMessageService instance = GlobalMessageService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String collection = 'global_messages';

  /// Publica nova mensagem (incrementa [versao]).
  Future<void> enviarMensagemParaTodos(String mensagem) async {
    final texto = mensagem.trim();
    if (texto.isEmpty) {
      throw ArgumentError('Mensagem vazia.');
    }

    final latest = await _db
        .collection(collection)
        .orderBy('versao', descending: true)
        .limit(1)
        .get();

    final ultimaVersao = latest.docs.isEmpty
        ? 0
        : (latest.docs.first.data()['versao'] as num?)?.toInt() ?? 0;

    await _db.collection(collection).add({
      'mensagem': texto,
      'data': FieldValue.serverTimestamp(),
      'versao': ultimaVersao + 1,
      'ativa': true,
    });
  }

  /// Se houver mensagem ativa com [versao] maior que [ultimaMensagemVisualizada],
  /// exibe o diálogo e grava o ack no usuário.
  Future<void> maybeShowGlobalMessageDialog(
    BuildContext context,
    String userId,
  ) async {
    final snap = await _db
        .collection(collection)
        .orderBy('versao', descending: true)
        .limit(5)
        .get();

    if (snap.docs.isEmpty) return;

    Map<String, dynamic>? escolhido;
    for (final d in snap.docs) {
      final m = d.data();
      if (m['ativa'] == true) {
        escolhido = m;
        break;
      }
    }
    if (escolhido == null) return;

    final versao = (escolhido['versao'] as num?)?.toInt() ?? 0;
    if (versao <= 0) return;

    final userRef = _db.collection('users').doc(userId);
    final userSnap = await userRef.get();
    final visto =
        (userSnap.data()?['ultimaMensagemVisualizada'] as num?)?.toInt() ?? 0;

    if (versao <= visto) return;
    if (!context.mounted) return;

    final texto = (escolhido['mensagem'] ?? '').toString().trim();
    if (texto.isEmpty) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.campaign_outlined, color: Color(0xFF1E3A8A)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Aviso',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 16, height: 1.45),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendi'),
            ),
          ],
        );
      },
    );

    if (!context.mounted) return;
    await userRef.set(
      {'ultimaMensagemVisualizada': versao},
      SetOptions(merge: true),
    );
  }
}

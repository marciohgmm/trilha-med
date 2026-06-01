import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/medical_tool_history_entry.dart';

/// Histórico local (últimos 20 cálculos) — sem Firestore.
class MedicalToolsHistoryStore {
  MedicalToolsHistoryStore({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;
  static const _key = 'medical_tools_history_v1';
  static const maxEntries = 20;

  Future<SharedPreferences> get _storage async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<List<MedicalToolHistoryEntry>> loadAll() async {
    final prefs = await _storage;
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) =>
              MedicalToolHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.calculatedAt.compareTo(a.calculatedAt));
    } catch (_) {
      return [];
    }
  }

  Future<List<MedicalToolHistoryEntry>> loadForTool(String toolId) async {
    final all = await loadAll();
    return all.where((e) => e.toolId == toolId).toList();
  }

  Future<void> append(MedicalToolHistoryEntry entry) async {
    final prefs = await _storage;
    final all = await loadAll();
    final updated = [entry, ...all.where((e) => e.id != entry.id)]
        .take(maxEntries)
        .toList();
    await prefs.setString(
      _key,
      jsonEncode(updated.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    final prefs = await _storage;
    await prefs.remove(_key);
  }
}

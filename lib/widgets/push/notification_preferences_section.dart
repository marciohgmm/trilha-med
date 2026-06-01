import 'package:flutter/material.dart';

import '../../core/push/push_notification_types.dart';
import '../../services/push/fcm_service.dart';
import '../../services/push/push_preferences_service.dart';

/// Preferências de push no perfil do usuário.
class NotificationPreferencesSection extends StatefulWidget {
  const NotificationPreferencesSection({
    super.key,
    required this.userId,
    this.embedded = false,
  });

  final String userId;

  /// Painel expansível (mesmo estilo do relógio no perfil).
  final bool embedded;

  @override
  State<NotificationPreferencesSection> createState() =>
      _NotificationPreferencesSectionState();
}

class _NotificationPreferencesSectionState
    extends State<NotificationPreferencesSection> {
  final _prefsService = PushPreferencesService();
  Map<String, bool>? _prefs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await _prefsService.getPrefs(widget.userId);
    if (mounted) setState(() => _prefs = p);
  }

  Future<void> _toggle(String key, bool value) async {
    await _prefsService.setPref(widget.userId, key, value);
    if (key == PushPreferenceKeys.promotional) {
      await FcmService.instance.syncPromotionalTopic(value);
    }
    if (mounted) {
      setState(() {
        _prefs = {...?_prefs, key: value};
      });
    }
  }

  Widget _panelDecoration({required Widget child}) {
    if (!widget.embedded) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    if (prefs == null) {
      return _panelDecoration(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final switches = PushNotificationType.all.map(
      (type) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(PushNotificationType.label(type)),
        value: prefs[type] ?? true,
        onChanged: (v) => _toggle(type, v),
      ),
    );

    if (widget.embedded) {
      return _panelDecoration(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: switches.toList(),
        ),
      );
    }

    return _panelDecoration(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notificações push',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Escolha quais alertas deseja receber no celular.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          ...switches,
        ],
      ),
    );
  }
}

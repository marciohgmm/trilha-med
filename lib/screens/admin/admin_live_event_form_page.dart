import 'package:flutter/material.dart';

import '../../models/live_event_models.dart';
import '../../services/live_event_service.dart';

class AdminLiveEventFormPage extends StatefulWidget {
  const AdminLiveEventFormPage({super.key});

  @override
  State<AdminLiveEventFormPage> createState() => _AdminLiveEventFormPageState();
}

class _AdminLiveEventFormPageState extends State<AdminLiveEventFormPage> {
  final _service = LiveEventService();
  final _descCtrl = TextEditingController(
    text: 'Regras do evento:\n\n'
        '• Você terá X segundos para responder cada questão.\n'
        '• Errou: perde uma vida (ou é eliminado, conforme o modo).\n'
        '• O evento continua até restar apenas um sobrevivente.',
  );

  DateTime _scheduled = DateTime.now().add(const Duration(days: 1));
  LiveEventGameMode _gameMode = LiveEventGameMode.lives;
  int _lives = 2;
  int _seconds = 45;
  /// null = questões aleatórias de qualquer matéria.
  String? _materiaPool;
  LiveEventPushAudience _pushAudience = LiveEventPushAudience.participants;
  bool _salvando = false;
  List<String> _materias = [];

  @override
  void initState() {
    super.initState();
    _carregarMaterias();
  }

  Future<void> _carregarMaterias() async {
    final lista = await _service.listarMateriasDoBanco();
    if (!mounted) return;
    setState(() => _materias = lista);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduled,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduled),
    );
    if (time == null) return;
    setState(() {
      _scheduled = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _escolherMateria() async {
    final escolha = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Seleção de matérias',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.public),
                title: const Text('Questões aleatórias — todas as matérias'),
                subtitle: const Text('Sorteio no banco completo de questões'),
                onTap: () => Navigator.pop(ctx, ''),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _materias.length,
                  itemBuilder: (context, i) {
                    final m = _materias[i];
                    return ListTile(
                      leading: const Icon(Icons.school_outlined),
                      title: Text(m),
                      onTap: () => Navigator.pop(ctx, m),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || escolha == null) return;
    setState(() {
      _materiaPool = escolha.isEmpty ? null : escolha;
    });
  }

  String get _rotuloMateria {
    if (_materiaPool == null || _materiaPool!.isEmpty) {
      return 'Todas as matérias (aleatório)';
    }
    return _materiaPool!;
  }

  Future<void> _salvar() async {
    final regras = _descCtrl.text.trim();
    if (regras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escreva as regras do evento na descrição.')),
      );
      return;
    }

    setState(() => _salvando = true);
    try {
      await _service.createEvent(
        description: regras,
        scheduledAt: _scheduled,
        gameMode: _gameMode,
        livesPerPlayer: _lives,
        secondsPerQuestion: _seconds,
        poolMateria: _materiaPool,
        pushAudience: _pushAudience,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evento Último Sobrevivente criado!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar — Último Sobrevivente'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '🔥 Último Sobrevivente',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Regras e funcionamento',
              hintText: 'Esta mensagem aparece para todos ao entrar no evento.',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            title: const Text('Data e horário'),
            subtitle: Text(
              '${_scheduled.day}/${_scheduled.month}/${_scheduled.year} '
              '${_scheduled.hour}:${_scheduled.minute.toString().padLeft(2, '0')}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<LiveEventGameMode>(
            initialValue: _gameMode,
            decoration: const InputDecoration(
              labelText: 'Modo de jogo',
              border: OutlineInputBorder(),
            ),
            items: LiveEventGameMode.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                .toList(),
            onChanged: (v) => setState(() => _gameMode = v!),
          ),
          if (_gameMode == LiveEventGameMode.lives)
            ListTile(
              title: const Text('Vidas por jogador'),
              trailing: DropdownButton<int>(
                value: _lives,
                items: [1, 2, 3, 4, 5]
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                    .toList(),
                onChanged: (v) => setState(() => _lives = v!),
              ),
            ),
          ListTile(
            title: const Text('Tempo por questão (segundos)'),
            trailing: DropdownButton<int>(
              value: _seconds,
              items: [30, 45, 60, 90]
                  .map((n) => DropdownMenuItem(value: n, child: Text('$n s')))
                  .toList(),
              onChanged: (v) => setState(() => _seconds = v!),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _escolherMateria,
            icon: const Icon(Icons.filter_alt_outlined),
            label: Text('Seleção de matérias: $_rotuloMateria'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              alignment: Alignment.centerLeft,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'As questões são sorteadas automaticamente do banco, sem limite fixo '
            'de quantidade — o evento termina quando restar um vencedor.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.35),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Notificações push amplas'),
            subtitle: Text(
              _pushAudience == LiveEventPushAudience.platformPublic
                  ? 'Usuários ativos (7 dias) com pref. de eventos — configuração explícita.'
                  : 'Padrão: apenas inscritos no evento e o host.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            value: _pushAudience == LiveEventPushAudience.platformPublic,
            onChanged: (v) => setState(() {
              _pushAudience = v
                  ? LiveEventPushAudience.platformPublic
                  : LiveEventPushAudience.participants;
            }),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _salvando ? null : _salvar,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(_salvando ? 'Salvando...' : 'Criar evento'),
          ),
        ],
      ),
    );
  }
}

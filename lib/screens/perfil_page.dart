import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_page.dart';
import '../services/auth/auth_rate_limit_service.dart';
import '../services/auth/user_public_profile_service.dart';
import '../services/study_timer_service.dart';
import '../utils/report_message_dialog.dart';
import '../widgets/push/notification_preferences_section.dart';
import 'commercial/my_subscription_page.dart';
import 'commercial/plans_page.dart';
import 'legal/privacy_center_page.dart';
import 'legal/privacy_policy_page.dart';
import 'legal/terms_of_use_page.dart';

class PerfilPage extends StatefulWidget {
  final String userId;

  const PerfilPage({
    super.key,
    required this.userId,
  });

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _cidadeController = TextEditingController();

  bool _salvando = false;

  // Configurações de estudo
  final StudyTimerService _timerService = StudyTimerService();
  bool _enablePauseReminder = true;
  int _studyDuration = 50;
  int _pauseDuration = 10;
  bool _enableSound = true;
  bool _showFloatingClock = true;
  bool _showNotificacoesConfig = false;
  bool _showRelogioConfig = false;
  int _fontSize = 16;

  static const List<int> _fontSizeOptions = [14, 16, 18, 20, 22];

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadTimerSettings();
  }

  Future<void> _loadTimerSettings() async {
    await _timerService.loadSettings();
    setState(() {
      _enablePauseReminder = _timerService.enablePauseReminder;
      _studyDuration = _timerService.studyDuration.inMinutes;
      _pauseDuration = _timerService.pauseDuration.inMinutes;
      _enableSound = _timerService.enableSound;
      _showFloatingClock = _timerService.showFloatingClock;
      _fontSize = _timerService.fontSize;
    });
  }

  String _iniciais(String nome, String email) {
    final nomeLimpo = nome.trim();

    if (nomeLimpo.isNotEmpty) {
      final partes =
          nomeLimpo.split(' ').where((e) => e.trim().isNotEmpty).toList();

      if (partes.length == 1) {
        return partes.first.substring(0, 1).toUpperCase();
      }

      return (partes.first.substring(0, 1) + partes.last.substring(0, 1))
          .toUpperCase();
    }

    if (email.isNotEmpty) {
      return email.substring(0, 1).toUpperCase();
    }

    return 'A';
  }

  Future<void> _salvarPerfil() async {
    final nome = _nomeController.text.trim();
    final telefone = _telefoneController.text.trim();
    final cidade = _cidadeController.text.trim();

    setState(() {
      _salvando = true;
    });

    try {
      await _firestore.collection('users').doc(widget.userId).set({
        'nome': nome,
        'telefone': telefone,
        'cidade': cidade,
        'email': _auth.currentUser?.email ?? '',
        'atualizadoEm': Timestamp.now(),
      }, SetOptions(merge: true));

      await UserPublicProfileService().syncProfile(
        userId: widget.userId,
        displayName: nome.isNotEmpty ? nome : null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil atualizado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar perfil: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _salvando = false;
      });
    }
  }

  Future<void> _enviarRedefinicaoSenha() async {
    try {
      final email = _auth.currentUser?.email;

      if (email == null || email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível identificar o e-mail do usuário.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await AuthRateLimitService().assertPasswordResetAllowed(email);
      await _auth.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enviamos o link de redefinição para $email',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao enviar redefinição de senha: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _abrirDialogoSuporte() async {
    if (!mounted) return;

    final mensagem = await showReportTextDialog(
      context: context,
      title: 'Falar com suporte',
      hintText: 'Digite sua mensagem',
      maxLines: 5,
      description: const Text(
        'Escreva sua dúvida, sugestão ou problema encontrado no app.',
      ),
    );

    if (mensagem == null || mensagem.trim().isEmpty) return;

    try {
      await _firestore.collection('notificacoes_admin').add({
        'tipo': 'contato_admin',
        'status': 'novo',
        'userId': widget.userId,
        'email': _auth.currentUser?.email ?? '',
        'mensagem': mensagem.trim(),
        'criadoEm': Timestamp.now(),
        'atualizadoEm': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mensagem enviada para a equipe com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao enviar mensagem: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _abrirSobreApp() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Sobre o app'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.school,
                size: 52,
                color: Color(0xFF1E3A8A),
              ),
              SizedBox(height: 14),
              Text(
                'Trilha Med',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Preparação Revalida',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'Versão 1.0.0',
                style: TextStyle(
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Aplicativo desenvolvido para auxiliar estudantes com flashcards, estudos organizados e revisão inteligente.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _salvarConfiguracoesEstudo() async {
    await _timerService.saveSettings(
      studyDuration: _studyDuration,
      pauseDuration: _pauseDuration,
      enableSound: _enableSound,
      showFloatingClock: _showFloatingClock,
      enablePauseReminder: _enablePauseReminder,
      fontSize: _fontSize,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configurações de estudo salvas!')),
      );
    }
  }

  Future<void> _abrirDialogoTamanhoFonte() async {
    final selecionado = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        var escolha = _fontSize;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tamanho da fonte'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: _fontSizeOptions.map(
                  (value) {
                    final selected = escolha == value;
                    return ListTile(
                      title: Text(
                        '$value pt',
                        style: TextStyle(fontSize: value.toDouble()),
                      ),
                      trailing: selected
                          ? const Icon(Icons.check_circle,
                              color: Color(0xFF1E3A8A))
                          : const Icon(Icons.circle_outlined),
                      onTap: () {
                        setDialogState(() => escolha = value);
                        Navigator.of(dialogContext).pop(value);
                      },
                    );
                  },
                ).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selecionado == null || !mounted) return;

    setState(() => _fontSize = selecionado);
    await _timerService.saveFontSize(selecionado);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tamanho da fonte: ${selecionado}pt'),
        backgroundColor: const Color(0xFF1E3A8A),
      ),
    );
  }

  Future<void> _confirmarLogout() async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Sair da conta'),
          content: const Text(
            'Tem certeza que deseja sair do aplicativo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );

    if (sair != true) return;

    await _auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
      (route) => false,
    );
  }

  Widget _buildAcaoTile({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required VoidCallback? onTap,
    Color corIcone = const Color(0xFF1E3A8A),
    bool? expanded,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: corIcone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: corIcone),
        ),
        title: Text(
          titulo,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitulo),
        trailing: Icon(
          expanded == null
              ? Icons.arrow_forward_ios
              : (expanded
                  ? Icons.keyboard_arrow_down
                  : Icons.arrow_forward_ios),
          size: expanded == null ? 16 : 22,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildCampo({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF1E3A8A),
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    _cidadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(widget.userId).snapshots(),
      builder: (context, snapshot) {
        final rawData = snapshot.data?.data();

        final userData =
            rawData is Map<String, dynamic> ? rawData : <String, dynamic>{};

        final nome = (userData['nome'] ?? '').toString();
        final telefone = (userData['telefone'] ?? '').toString();
        final cidade = (userData['cidade'] ?? '').toString();
        final email =
            (_auth.currentUser?.email ?? userData['email'] ?? '').toString();

        _nomeController.text = nome;
        _telefoneController.text = telefone;
        _cidadeController.text = cidade;

        return Scaffold(
          backgroundColor: const Color(0xFFF3F6FB),
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF1E3A8A),
                        Color(0xFF2563EB),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Meu perfil',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _confirmarLogout,
                            icon: const Icon(
                              Icons.logout,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: Colors.white,
                        child: Text(
                          _iniciais(nome, email),
                          style: const TextStyle(
                            color: Color(0xFF1E3A8A),
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        nome.isNotEmpty ? nome : 'Aluno(a)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        email.isNotEmpty ? email : 'Email não disponível',
                        style: const TextStyle(
                          color: Color(0xFFE0E7FF),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildCampo(
                        controller: _nomeController,
                        label: 'Nome',
                        icon: Icons.person_outline,
                      ),
                      _buildCampo(
                        controller: _telefoneController,
                        label: 'Telefone',
                        icon: Icons.phone_outlined,
                      ),
                      _buildCampo(
                        controller: _cidadeController,
                        label: 'Cidade',
                        icon: Icons.location_city_outlined,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _salvando ? null : _salvarPerfil,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                        child: Text(
                          _salvando ? 'Salvando...' : 'Salvar alterações',
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildAcaoTile(
                        icon: Icons.workspace_premium,
                        titulo: 'Planos',
                        subtitulo: 'Compare Gratuito e Premium',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PlansPage()),
                        ),
                        corIcone: const Color(0xFFD97706),
                      ),
                      _buildAcaoTile(
                        icon: Icons.card_membership,
                        titulo: 'Minha Assinatura',
                        subtitulo: 'Plano, status e validade',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MySubscriptionPage(),
                          ),
                        ),
                        corIcone: const Color(0xFF1E3A8A),
                      ),
                      _buildAcaoTile(
                        icon: Icons.lock_reset,
                        titulo: 'Trocar senha',
                        subtitulo: 'Enviar link para seu e-mail',
                        onTap: _enviarRedefinicaoSenha,
                      ),
                      _buildAcaoTile(
                        icon: Icons.support_agent,
                        titulo: 'Falar com suporte',
                        subtitulo: 'Relatar problema, dúvida ou sugestão',
                        onTap: _abrirDialogoSuporte,
                        corIcone: const Color(0xFF0F766E),
                      ),
                      _buildAcaoTile(
                        icon: Icons.info_outline,
                        titulo: 'Sobre o app',
                        subtitulo: 'Informações do aplicativo',
                        onTap: _abrirSobreApp,
                        corIcone: const Color(0xFF7C3AED),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Configurações',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildAcaoTile(
                        icon: Icons.privacy_tip_outlined,
                        titulo: 'Privacidade e dados',
                        subtitulo: 'Política, termos, exportação e exclusão',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PrivacyCenterPage(userId: widget.userId),
                          ),
                        ),
                        corIcone: const Color(0xFF1E3A8A),
                      ),
                      _buildAcaoTile(
                        icon: Icons.description_outlined,
                        titulo: 'Política de Privacidade',
                        subtitulo: 'Versão vigente',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyPage(),
                          ),
                        ),
                      ),
                      _buildAcaoTile(
                        icon: Icons.gavel_outlined,
                        titulo: 'Termos de Uso',
                        subtitulo: 'Versão vigente',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TermsOfUsePage(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildAcaoTile(
                        icon: Icons.text_fields,
                        titulo: 'Tamanho da fonte',
                        subtitulo: 'Atualmente ${_fontSize}pt',
                        onTap: _abrirDialogoTamanhoFonte,
                        corIcone: const Color(0xFF4B5563),
                      ),
                      _buildAcaoTile(
                        icon: Icons.notifications_outlined,
                        titulo: 'Editar notificações',
                        subtitulo: 'Escolha quais alertas receber no celular',
                        expanded: _showNotificacoesConfig,
                        onTap: () => setState(() {
                          _showNotificacoesConfig = !_showNotificacoesConfig;
                        }),
                        corIcone: const Color(0xFF0F766E),
                      ),
                      if (_showNotificacoesConfig) ...[
                        const SizedBox(height: 16),
                        NotificationPreferencesSection(
                          userId: widget.userId,
                          embedded: true,
                        ),
                      ],
                      _buildAcaoTile(
                        icon: Icons.access_time,
                        titulo: 'Relógio',
                        subtitulo:
                            'Ajustar tempo e opções de relógio flutuante',
                        expanded: _showRelogioConfig,
                        onTap: () => setState(() {
                          _showRelogioConfig = !_showRelogioConfig;
                        }),
                        corIcone: const Color(0xFF1E40AF),
                      ),
                      if (_showRelogioConfig) ...[
                        const SizedBox(height: 16),
                        Container(
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                title: const Text('Ativar lembrete de pausa'),
                                value: _enablePauseReminder,
                                onChanged: (value) => setState(
                                    () => _enablePauseReminder = value),
                              ),
                              ListTile(
                                title: const Text('Tempo de estudo'),
                                subtitle: Text('$_studyDuration minutos'),
                                trailing: DropdownButton<int>(
                                  value: _studyDuration,
                                  items: [25, 50, 75, 90].map((int value) {
                                    return DropdownMenuItem<int>(
                                      value: value,
                                      child: Text('$value min'),
                                    );
                                  }).toList(),
                                  onChanged: (value) =>
                                      setState(() => _studyDuration = value!),
                                ),
                              ),
                              ListTile(
                                title: const Text('Tempo de pausa'),
                                subtitle: Text('$_pauseDuration minutos'),
                                trailing: DropdownButton<int>(
                                  value: _pauseDuration,
                                  items: [5, 10, 15, 20].map((int value) {
                                    return DropdownMenuItem<int>(
                                      value: value,
                                      child: Text('$value min'),
                                    );
                                  }).toList(),
                                  onChanged: (value) =>
                                      setState(() => _pauseDuration = value!),
                                ),
                              ),
                              SwitchListTile(
                                title: const Text('Ativar som'),
                                value: _enableSound,
                                onChanged: (value) =>
                                    setState(() => _enableSound = value),
                              ),
                              SwitchListTile(
                                title: const Text('Mostrar relógio flutuante'),
                                value: _showFloatingClock,
                                onChanged: (value) =>
                                    setState(() => _showFloatingClock = value),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _salvarConfiguracoesEstudo,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A8A),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text(
                                    'Salvar configurações do relógio'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _confirmarLogout,
                        icon: const Icon(Icons.logout),
                        label: const Text('Sair da conta'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_page.dart';

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

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  String _iniciais(String nome, String email) {
    final nomeLimpo = nome.trim();
    if (nomeLimpo.isNotEmpty) {
      final partes = nomeLimpo.split(' ').where((e) => e.trim().isNotEmpty).toList();
      if (partes.length == 1) {
        return partes.first.substring(0, 1).toUpperCase();
      }
      return (partes.first.substring(0, 1) + partes.last.substring(0, 1)).toUpperCase();
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
      if (!mounted) return;
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
            content: Text('Não foi possível identificar o e-mail do usuário.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await _auth.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enviamos o link de redefinição para $email'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao enviar redefinição de senha: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _abrirDialogoSuporte() async {
    final mensagemController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Falar com suporte'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Escreva sua dúvida, sugestão ou problema encontrado no app.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mensagemController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Digite sua mensagem',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final mensagem = mensagemController.text.trim();

                if (mensagem.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Digite uma mensagem antes de enviar.'),
                    ),
                  );
                  return;
                }

                try {
                  await _firestore.collection('suporte_mensagens').add({
                    'userId': widget.userId,
                    'email': _auth.currentUser?.email ?? '',
                    'mensagem': mensagem,
                    'status': 'novo',
                    'criadoEm': Timestamp.now(),
                  });

                  if (!mounted) return;

                  Navigator.pop(context);

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
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Enviar'),
            ),
          ],
        );
      },
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
          content: const Text('Tem certeza que deseja sair do aplicativo?'),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
            color: corIcone.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: corIcone),
        ),
        title: Text(
          titulo,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
        subtitle: Text(
          subtitulo,
          style: const TextStyle(
            color: Color(0xFF6B7280),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF9CA3AF)),
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
          prefixIcon: Icon(icon, color: const Color(0xFF1E3A8A)),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFF1E3A8A),
              width: 2,
            ),
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
        final userData = rawData is Map<String, dynamic> ? rawData : <String, dynamic>{};

        final nome = (userData['nome'] ?? '').toString();
        final telefone = (userData['telefone'] ?? '').toString();
        final cidade = (userData['cidade'] ?? '').toString();
        final email = (_auth.currentUser?.email ?? userData['email'] ?? '').toString();

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
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
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
                            icon: const Icon(Icons.logout, color: Colors.white),
                            tooltip: 'Sair',
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
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
                      ),
                      const SizedBox(height: 14),
                      Text(
                        nome.isNotEmpty ? nome : 'Aluno(a)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        email.isNotEmpty ? email : 'Email não disponível',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFE0E7FF),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x11000000),
                              blurRadius: 16,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Atualizar cadastro',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Mantenha seus dados sempre atualizados.',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildCampo(
                              controller: _nomeController,
                              label: 'Nome',
                              icon: Icons.person_outline,
                            ),
                            _buildCampo(
                              controller: _telefoneController,
                              label: 'Telefone',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                            _buildCampo(
                              controller: _cidadeController,
                              label: 'Cidade',
                              icon: Icons.location_city_outlined,
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _salvando ? null : _salvarPerfil,
                                icon: _salvando
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(_salvando ? 'Salvando...' : 'Salvar alterações'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A8A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 10),
                        child: Text(
                          'Conta e suporte',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      _buildAcaoTile(
                        icon: Icons.lock_reset,
                        titulo: 'Trocar senha',
                        subtitulo: 'Enviar link de redefinição para o seu email',
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
                        subtitulo: 'Trilha Med • Preparação Revalida',
                        onTap: null,
                        corIcone: const Color(0xFF7C3AED),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _confirmarLogout,
                        icon: const Icon(Icons.logout),
                        label: const Text('Sair da conta'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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
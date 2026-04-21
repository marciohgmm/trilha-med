import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'main_navigation_page.dart';
import 'register_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  final emailRecuperacaoController = TextEditingController();

  bool exibirRecuperacao = false;
  bool carregandoLogin = false;
  bool mostrarSenha = false;

  Future<void> login() async {
    final email = emailController.text.trim();
    final senha = senhaController.text.trim();

    if (email.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Preencha email e senha"),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      carregandoLogin = true;
    });

    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );

      User? user = userCredential.user;

      if (user == null) {
        throw Exception('Usuário não encontrado');
      }

      await user.reload();
      user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Não foi possível atualizar os dados do usuário');
      }

      if (!user.emailVerified) {
        await user.sendEmailVerification();
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Seu email ainda não foi verificado. Enviamos um novo link para $email.",
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      final userId = user.uid;

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainNavigationPage(userId: userId),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String mensagem = "Erro ao fazer login";

      if (e.code == 'user-not-found') {
        mensagem = "Usuário não encontrado";
      } else if (e.code == 'wrong-password') {
        mensagem = "Senha incorreta";
      } else if (e.code == 'invalid-credential') {
        mensagem = "Email ou senha inválidos";
      } else if (e.code == 'invalid-email') {
        mensagem = "Email inválido";
      } else if (e.code == 'too-many-requests') {
        mensagem = "Muitas tentativas. Tente novamente mais tarde";
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensagem),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao fazer login: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        carregandoLogin = false;
      });
    }
  }

  Future<void> enviarCodigo() async {
    final email = emailRecuperacaoController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Preencha o email de recuperação"),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email de recuperação enviado! 📧"),
          backgroundColor: Colors.green,
        ),
      );

      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            exibirRecuperacao = false;
          });
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("Erro ao enviar email: ${e.toString().split('] ').last}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    emailRecuperacaoController.dispose();
    super.dispose();
  }

  InputDecoration _decoracaoCampo({
    required String label,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF1E3A8A),
          width: 2,
        ),
      ),
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("Login"),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: exibirRecuperacao
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.asset(
                                  'assets/images/logo_trilha_med.jpeg',
                                  height: 150,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              "Recuperar senha",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Digite seu email cadastrado para receber o link de redefinição.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: emailRecuperacaoController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _decoracaoCampo(
                                label: "Seu email cadastrado",
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: enviarCodigo,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A8A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  "Enviar email de recuperação",
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  exibirRecuperacao = false;
                                });
                              },
                              child: const Text("Voltar ao login"),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.asset(
                                  'assets/images/logo_trilha_med.jpeg',
                                  height: 150,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              "Bem-vindo",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Entre para continuar seus estudos no Trilha Med.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _decoracaoCampo(
                                label: "Email",
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: senhaController,
                              obscureText: !mostrarSenha,
                              decoration: _decoracaoCampo(
                                label: "Senha",
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      mostrarSenha = !mostrarSenha;
                                    });
                                  },
                                  icon: Icon(
                                    mostrarSenha
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: carregandoLogin ? null : login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A8A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: carregandoLogin
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        "Entrar",
                                        style: TextStyle(fontSize: 16),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const RegisterScreen(),
                                  ),
                                );
                              },
                              child: const Text("Criar conta"),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  exibirRecuperacao = true;
                                  emailRecuperacaoController.clear();
                                });
                              },
                              child: const Text("Esqueci a senha"),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
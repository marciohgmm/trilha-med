import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/criar_flashcard_page.dart';
import 'package:flutter_application_1/screens/admin_materias_page.dart';
import 'package:flutter_application_1/screens/admin_notificacoes_page.dart';
import 'package:flutter_application_1/services/firebase_service.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  Widget _botaoAdmin({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A).withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF1E3A8A),
            size: 28,
          ),
        ),
        title: Text(
          titulo,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitulo),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Color(0xFF1E3A8A),
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _importarFlashcards(BuildContext context) async {
    try {
      final service = FirebaseService();
      final quantidade = await service.importarCardsJson();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            quantidade > 0
                ? '$quantidade flashcards importados com sucesso!'
                : 'Nenhum flashcard foi importado.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao importar flashcards: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportarFlashcards(BuildContext context) async {
    try {
      final service = FirebaseService();
      await service.exportarCardsJson();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exportação iniciada com sucesso!'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao exportar flashcards: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Área Administrativa'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Gerenciar conteúdo',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use esta área para criar, organizar, importar, exportar e revisar notificações do app.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          _botaoAdmin(
            icon: Icons.notifications_active_outlined,
            titulo: 'Notificações admin',
            subtitulo: 'Ver reports de erro e mensagens recebidas',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminNotificacoesPage(),
                ),
              );
            },
          ),
          _botaoAdmin(
            icon: Icons.add_box_outlined,
            titulo: 'Criar flashcard',
            subtitulo: 'Adicionar novo card usando matéria, tema e subtema',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CriarFlashcardPage(),
                ),
              );
            },
          ),
          _botaoAdmin(
            icon: Icons.edit_note_outlined,
            titulo: 'Gerenciar cards',
            subtitulo: 'Abrir matérias, temas, subtemas e editar cards',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminMateriasPage(),
                ),
              );
            },
          ),
          _botaoAdmin(
            icon: Icons.file_upload_outlined,
            titulo: 'Importar flashcards',
            subtitulo: 'Importar cards em arquivo JSON',
            onTap: () => _importarFlashcards(context),
          ),
          _botaoAdmin(
            icon: Icons.file_download_outlined,
            titulo: 'Exportar flashcards',
            subtitulo: 'Exportar todos os cards para arquivo JSON',
            onTap: () => _exportarFlashcards(context),
          ),
        ],
      ),
    );
  }
}
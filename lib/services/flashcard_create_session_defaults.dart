/// Última combinação Matéria / Subtema usada ao **criar** flashcards ou questões.
///
/// Guardado **só em memória** durante a sessão do app (não usa SharedPreferences).
class FlashcardCreateSessionDefaults {
  static String? ultimaMateriaSelecionada;
  static String? ultimoSubtemaSelecionado;

  static void setFromForm(String materia, String subtema) {
    ultimaMateriaSelecionada = materia.trim();
    ultimoSubtemaSelecionado = subtema.trim();
  }

  static void clear() {
    ultimaMateriaSelecionada = null;
    ultimoSubtemaSelecionado = null;
  }

  static bool get hasPair {
    final m = ultimaMateriaSelecionada?.trim() ?? '';
    final s = ultimoSubtemaSelecionado?.trim() ?? '';
    return m.isNotEmpty && s.isNotEmpty;
  }
}

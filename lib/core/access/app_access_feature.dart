/// Funcionalidades controladas por `app_access_config/plans`.
enum AppAccessFeature {
  flashcards(
    'flashcards',
    'Flashcards',
    'flashcardsEnabled',
    'flashcardsLimit',
  ),
  questions(
    'questions',
    'Questões',
    'questionsEnabled',
    'questionsLimit',
  ),
  simulators(
    'simulators',
    'Simulados',
    'simulatorsEnabled',
    null,
  ),
  medicalTools(
    'medical_tools',
    'Ferramentas médicas',
    'medicalToolsEnabled',
    'medicalToolsLimit',
  ),
  smartReview(
    'smart_review',
    'Revisão inteligente',
    'smartReviewEnabled',
    null,
  ),
  themes(
    'themes',
    'Temas / subtemas',
    'themesEnabled',
    'themesLimit',
  ),
  practicalPhase(
    'practical_phase',
    'Fase Prática',
    'practicalPhaseEnabled',
    null,
  ),
  revalidaOfficial(
    'revalida_official',
    'Simulado Revalida Oficial',
    'revalidaOfficialEnabled',
    null,
  );

  final String id;
  final String label;
  final String enabledField;
  final String? limitField;

  const AppAccessFeature(
    this.id,
    this.label,
    this.enabledField,
    this.limitField,
  );

  static AppAccessFeature? fromId(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final f in AppAccessFeature.values) {
      if (f.id == value) return f;
    }
    return null;
  }

  /// Funcionalidades com checkbox na tela admin.
  static const adminFeatures = [
    AppAccessFeature.flashcards,
    AppAccessFeature.questions,
    AppAccessFeature.simulators,
    AppAccessFeature.medicalTools,
    AppAccessFeature.smartReview,
    AppAccessFeature.themes,
    AppAccessFeature.practicalPhase,
    AppAccessFeature.revalidaOfficial,
  ];

  /// Funcionalidades com campo numérico de limite (plano gratuito).
  static const adminLimitFeatures = [
    AppAccessFeature.flashcards,
    AppAccessFeature.questions,
    AppAccessFeature.themes,
    AppAccessFeature.medicalTools,
  ];
}

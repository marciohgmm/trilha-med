/// Identificadores de documentos em `platform_feature_flags`.
class FeatureModules {
  FeatureModules._();

  static const flashcards = 'flashcards';
  static const questoes = 'questoes';
  static const simulados = 'simulados';
  static const cronograma = 'cronograma';
  static const fasePratica = 'fase_pratica';
  static const osce = 'osce';
  static const liveEvents = 'live_events';
  static const ferramentasMedicas = 'ferramentas_medicas';
  static const revalidaOfficialSimulator = 'revalida_official_simulator';
  static const premium = 'premium';
  static const marketplace = 'marketplace';

  static const all = [
    flashcards,
    questoes,
    simulados,
    cronograma,
    fasePratica,
    osce,
    liveEvents,
    ferramentasMedicas,
    revalidaOfficialSimulator,
    premium,
    marketplace,
  ];

  static String label(String id) {
    switch (id) {
      case flashcards:
        return 'Flashcards';
      case questoes:
        return 'Questões';
      case simulados:
        return 'Simulados';
      case cronograma:
        return 'Cronograma';
      case fasePratica:
        return 'Fase Prática';
      case osce:
        return 'OSCE';
      case liveEvents:
        return 'Live Events';
      case ferramentasMedicas:
        return 'Ferramentas Médicas';
      case revalidaOfficialSimulator:
        return 'Simulado Revalida Oficial';
      case premium:
        return 'Premium';
      case marketplace:
        return 'Marketplace';
      default:
        return id;
    }
  }
}

// Enums do sistema de campanhas e anúncios.

/// Status administrativo definido pelo Painel Mestre.
enum AdCampaignAdminStatus {
  draft('draft', 'Rascunho'),
  active('active', 'Ativa'),
  paused('paused', 'Pausada'),
  ended('ended', 'Encerrada');

  final String key;
  final String label;
  const AdCampaignAdminStatus(this.key, this.label);

  static AdCampaignAdminStatus fromKey(String? v) {
    for (final e in AdCampaignAdminStatus.values) {
      if (e.key == v) return e;
    }
    return AdCampaignAdminStatus.draft;
  }
}

/// Ciclo de vida exibido (derivado de datas + status admin).
enum AdCampaignLifecycle {
  draft('draft', 'Rascunho'),
  scheduled('scheduled', 'Agendada'),
  active('active', 'Ativa'),
  paused('paused', 'Pausada'),
  ended('ended', 'Encerrada'),
  expired('expired', 'Expirada');

  final String key;
  final String label;
  const AdCampaignLifecycle(this.key, this.label);
}

/// Formato do criativo.
enum AdFormat {
  banner('banner', 'Banner'),
  nativeCard('native_card', 'Card nativo'),
  popup('popup', 'Popup'),
  fullscreen('fullscreen', 'Tela cheia'),
  institutional('institutional', 'Aviso institucional');

  final String key;
  final String label;
  const AdFormat(this.key, this.label);

  static AdFormat fromKey(String? v) {
    for (final e in AdFormat.values) {
      if (e.key == v) return e;
    }
    return AdFormat.banner;
  }
}

/// Locais preparados para exibição (opt-in via [AdPlacementSlot]).
enum AdPlacement {
  home('home', 'Home'),
  profile('profile', 'Perfil'),
  questions('questions', 'Questões'),
  simulados('simulados', 'Simulados'),
  practicalPhase('practical_phase', 'Fase Prática'),
  masterAdmin('master_admin', 'Painel Mestre');

  final String key;
  final String label;
  const AdPlacement(this.key, this.label);

  static AdPlacement fromKey(String? v) {
    for (final e in AdPlacement.values) {
      if (e.key == v) return e;
    }
    return AdPlacement.home;
  }

  static List<AdPlacement> fromKeys(List<dynamic>? keys) {
    if (keys == null) return const [];
    return keys
        .map((k) => fromKey(k.toString()))
        .where((p) => p != AdPlacement.home || keys.contains('home'))
        .toList();
  }
}

/// Segmentação de audiência.
enum AdAudienceSegment {
  all('all', 'Todos os usuários'),
  premium('premium', 'Apenas Premium'),
  free('free', 'Apenas Gratuitos'),
  betaTester('beta_tester', 'Beta testers'),
  seller('seller', 'Vendedores'),
  affiliate('affiliate', 'Afiliados');

  final String key;
  final String label;
  const AdAudienceSegment(this.key, this.label);

  static AdAudienceSegment fromKey(String? v) {
    for (final e in AdAudienceSegment.values) {
      if (e.key == v) return e;
    }
    return AdAudienceSegment.all;
  }
}

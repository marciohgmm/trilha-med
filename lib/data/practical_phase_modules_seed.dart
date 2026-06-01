import '../models/practical_phase_module.dart';

class PracticalPhaseModulesSeed {
  PracticalPhaseModulesSeed._();

  static final defaults = <PracticalPhaseModule>[
    const PracticalPhaseModule(
      id: '',
      sectionKey: 'simulados',
      title: 'Simulado integrado Revalida',
      description: 'Provas práticas no tempo oficial com correção orientada.',
      iconName: 'quiz',
      order: 0,
    ),
    const PracticalPhaseModule(
      id: '',
      sectionKey: 'casos_clinicos',
      title: 'Casos clínicos guiados',
      description: 'Raciocínio clínico passo a passo com feedback imediato.',
      iconName: 'medical_information',
      order: 0,
    ),
    const PracticalPhaseModule(
      id: '',
      sectionKey: 'osce',
      title: 'Estação OSCE — Anamnese',
      description: 'Treino de comunicação e exame físico em estação única.',
      iconName: 'monitor_heart',
      order: 0,
    ),
    const PracticalPhaseModule(
      id: '',
      sectionKey: 'checklist',
      title: 'Checklist de atendimento',
      description: 'Itens essenciais para não perder pontos na prática.',
      iconName: 'checklist',
      order: 0,
    ),
    const PracticalPhaseModule(
      id: '',
      sectionKey: 'comunicacao',
      title: 'Más notícias (SPIKES)',
      description: 'Roteiro de comunicação empática com paciente simulado.',
      iconName: 'forum',
      order: 0,
    ),
    const PracticalPhaseModule(
      id: '',
      sectionKey: 'condutas',
      title: 'Condutas de urgência',
      description: 'Fluxos rápidos: dor torácica, dispneia, convulsão.',
      iconName: 'emergency',
      order: 0,
    ),
    const PracticalPhaseModule(
      id: '',
      sectionKey: 'revisao',
      title: 'Revisão final pré-prova',
      description: 'Síntese dos temas mais cobrados na fase prática.',
      iconName: 'auto_stories',
      order: 0,
    ),
  ];
}

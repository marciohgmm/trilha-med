import '../models/practical_phase_model.dart';

/// Dados iniciais para teste local / primeira execução.
/// Integração real: os modelos passam a vir só do Firestore após o seed.
class PracticalPhaseSeed {
  PracticalPhaseSeed._();

  static List<PracticalPhaseModel> mockModels(String createdBy) {
    final now = DateTime.now();
    return [
      PracticalPhaseModel(
        id: '',
        title: 'Estação — Anamnese cardiovascular',
        slug: 'estacao-anamnese-cardiovascular',
        description:
            'Simulação de atendimento ambulatorial com foco em queixa principal, '
            'história da doença atual e antecedentes.',
        category: 'Clínica',
        specialty: 'Cardiologia',
        difficulty: 'Intermediário',
        thumbnailUrl: '',
        isActive: true,
        isPublished: true,
        createdAt: now,
        updatedAt: now,
        createdBy: createdBy,
        order: 0,
        sections: [
          PracticalPhaseSection(
            id: 's1',
            title: 'Estação 1 — Acolhimento',
            description: 'Apresente-se e organize a consulta.',
            order: 0,
            items: [
              const PracticalPhaseItem(
                id: 'i1',
                title: 'Roteiro',
                content:
                    '1. Cumprimente o paciente\n2. Confirme identidade\n3. Explique o tempo disponível (10 min)',
                type: 'checklist',
                order: 0,
              ),
            ],
          ),
          PracticalPhaseSection(
            id: 's2',
            title: 'Estação 2 — Exame físico dirigido',
            description: 'Priorize sinais de alarme.',
            order: 1,
            items: [
              const PracticalPhaseItem(
                id: 'i2',
                title: 'Pontos-chave',
                content: 'PA, FC, ausculta cardíaca e pulmonar, edema.',
                type: 'texto',
                order: 0,
              ),
            ],
          ),
        ],
      ),
      PracticalPhaseModel(
        id: '',
        title: 'Procedimento — Sutura simples',
        slug: 'procedimento-sutura-simples',
        description:
            'Treino de técnica asséptica, escolha do fio e fechamento em camadas.',
        category: 'Cirurgia',
        specialty: 'Cirurgia Geral',
        difficulty: 'Básico',
        thumbnailUrl: '',
        isActive: true,
        isPublished: true,
        createdAt: now,
        updatedAt: now,
        createdBy: createdBy,
        order: 1,
        sections: [
          PracticalPhaseSection(
            id: 's1',
            title: 'Preparo do campo',
            description: 'Materiais e segurança.',
            order: 0,
            items: const [
              PracticalPhaseItem(
                id: 'i1',
                title: 'Checklist',
                content: 'Campo estéril, luvas, fio 4-0, anestésico local.',
                order: 0,
              ),
            ],
          ),
        ],
      ),
      PracticalPhaseModel(
        id: '',
        title: 'Comunicação — Más notícias (rascunho)',
        slug: 'comunicacao-mas-noticias',
        description: 'Modelo em elaboração para treino SPIKES.',
        category: 'Comunicação',
        specialty: 'Geral',
        difficulty: 'Avançado',
        thumbnailUrl: '',
        isActive: true,
        isPublished: false,
        createdAt: now,
        updatedAt: now,
        createdBy: createdBy,
        order: 2,
        sections: const [],
      ),
    ];
  }
}

import '../models/osce_evaluation_models.dart';

/// Modelo padrão de avaliação OSCE (0–10) por critérios.
class OsceDefaultEvaluationRubric {
  OsceDefaultEvaluationRubric._();

  static const double maxTotal = 10.0;

  static OsceEvaluationCriterion _c({
    required String id,
    required String title,
    required String description,
    required double scoreAdequate,
    String? explainAdequate,
    String? explainPartial,
    String? explainInadequate,
  }) {
    return OsceEvaluationCriterion(
      id: id,
      title: title,
      description: description,
      scoreAdequate: scoreAdequate,
      scorePartial: scoreAdequate / 2,
      scoreInadequate: 0,
      explainAdequate: explainAdequate ??
          'Desempenho pleno do critério conforme esperado.',
      explainPartial:
          explainPartial ?? 'Desempenho parcial; apenas parte do critério.',
      explainInadequate:
          explainInadequate ?? 'Não realizou ou realizou de forma inadequada.',
    );
  }

  /// Oito critérios pré-preenchidos (soma dos pesos = 10).
  static List<OsceEvaluationCriterion> defaultCriteria() => [
        _c(
          id: 'crit_apresentacao',
          title:
              '(1) Apresenta-se e (2) cumprimenta o(a) paciente simulado(a).',
          description:
              'Perguntou nome do paciente, idade e profissão.',
          scoreAdequate: 0.5,
          explainAdequate: 'Realiza as duas ações.',
          explainPartial: 'Realiza apenas uma ação.',
          explainInadequate: 'Não realiza nenhuma das ações.',
        ),
        _c(
          id: 'crit_anamnese',
          title: 'Realiza anamnese.',
          description:
              'Investiga queixa principal, história da doença atual e antecedentes relevantes ao caso.',
          scoreAdequate: 1.5,
        ),
        _c(
          id: 'crit_manifestacoes',
          title: 'Pergunta manifestações clínicas associadas ao quadro.',
          description:
              'Explora sintomas associados, sinais de gravidade e fatores de risco.',
          scoreAdequate: 1.0,
        ),
        _c(
          id: 'crit_exame_fisico',
          title: 'Solicita exame físico.',
          description:
              'Solicita avaliação dirigida com descrição dos achados esperados.',
          scoreAdequate: 1.0,
        ),
        _c(
          id: 'crit_laboratorio',
          title: 'Solicita exames laboratoriais.',
          description:
              'Indica exames laboratoriais pertinentes ao caso clínico.',
          scoreAdequate: 1.0,
        ),
        _c(
          id: 'crit_imagem',
          title: 'Solicita exames complementares (imagem).',
          description:
              'Solicita exames de imagem ou outros complementares quando indicados.',
          scoreAdequate: 1.0,
        ),
        _c(
          id: 'crit_diagnostico',
          title: 'Estabelece o diagnóstico.',
          description:
              'Verbaliza hipótese diagnóstica coerente com o quadro clínico.',
          scoreAdequate: 2.0,
        ),
        _c(
          id: 'crit_tratamento',
          title: 'Prescreve tratamento específico.',
          description:
              'Indica conduta terapêutica adequada, incluindo orientações e segurança.',
          scoreAdequate: 2.0,
        ),
      ];

  // --- Legado (checklist por categoria) ---

  static const Map<String, double> defaultWeights = {
    'anamnesis': 2.0,
    'physicalExam': 2.0,
    'diagnosis': 2.5,
    'conduct': 2.5,
    'exams': 0.7,
    'communication': 0.3,
  };

  static List<String> defaultEnabledCategories({bool enableExams = true}) {
    final ids = [
      OsceEvaluationCategoryId.anamnesis.key,
      OsceEvaluationCategoryId.physicalExam.key,
      OsceEvaluationCategoryId.diagnosis.key,
      OsceEvaluationCategoryId.conduct.key,
      OsceEvaluationCategoryId.communication.key,
    ];
    if (enableExams) {
      ids.insert(4, OsceEvaluationCategoryId.exams.key);
    }
    return ids;
  }

  static OsceChecklistItem _item(String id, String label) =>
      OsceChecklistItem(id: id, label: label);

  static Map<String, List<OsceChecklistItem>> defaultChecklists() => {
        'anamnesis': [
          _item('an_1', 'Investigou sintomas principais'),
          _item('an_2', 'Explorou tempo de evolução'),
          _item('an_3', 'Investigou sinais de gravidade'),
          _item('an_4', 'Perguntou antecedentes relevantes'),
          _item('an_5', 'Fez perguntas direcionadas ao caso'),
        ],
        'physicalExam': [
          _item('ef_1', 'Exame direcionado ao caso'),
          _item('ef_2', 'Solicitou sinais vitais'),
          _item('ef_3', 'Pesquisou sinais importantes'),
          _item('ef_4', 'Sequência lógica do exame'),
        ],
        'conduct': [
          _item('co_1', 'Tratamento adequado'),
          _item('co_2', 'Segurança da conduta'),
          _item('co_3', 'Reconheceu gravidade'),
          _item('co_4', 'Encaminhamento adequado'),
          _item('co_5', 'Internação quando necessário'),
          _item('co_6', 'Prescrição adequada'),
        ],
        'communication': [
          _item('cm_1', 'Empatia'),
          _item('cm_2', 'Organização do raciocínio'),
          _item('cm_3', 'Linguagem adequada'),
          _item('cm_4', 'Respeito ao paciente'),
        ],
      };

  static List<OsceChecklistItem> defaultExpectedExams() => [
        _item('ex_1', 'Hemograma'),
        _item('ex_2', 'Radiografia de tórax'),
        _item('ex_3', 'ECG'),
        _item('ex_4', 'Gasometria / eletrólitos'),
      ];

  /// Rubrica efetiva ao iniciar avaliação (critérios ou legado).
  static OsceEvaluationRubric resolve(
    OsceEvaluationRubric? caseRubric, {
    String? fallbackDiagnosisText,
  }) {
    final fromCase = caseRubric ?? const OsceEvaluationRubric();

    if (fromCase.criteria.isNotEmpty) {
      return OsceEvaluationRubric(
        evaluationMode: 'criteria',
        criteria: List<OsceEvaluationCriterion>.from(fromCase.criteria),
      );
    }

    // Casos antigos sem critérios: usa lista padrão atual.
    if (fromCase.evaluationMode == 'criteria' ||
        fromCase.checklists.isEmpty && fromCase.weights.isEmpty) {
      return OsceEvaluationRubric(
        evaluationMode: 'criteria',
        criteria: defaultCriteria(),
      );
    }

    return _resolveLegacy(fromCase, fallbackDiagnosisText: fallbackDiagnosisText);
  }

  static OsceEvaluationRubric _resolveLegacy(
    OsceEvaluationRubric fromCase, {
    String? fallbackDiagnosisText,
  }) {
    final enableExams = fromCase.enableExamsCategory;
    final enabled = fromCase.enabledCategoryIds.isNotEmpty
        ? fromCase.enabledCategoryIds
        : defaultEnabledCategories(enableExams: enableExams);

    final weights = fromCase.useCustomWeights && fromCase.weights.isNotEmpty
        ? Map<String, double>.from(fromCase.weights)
        : Map<String, double>.from(defaultWeights);

    final categoryLabels = <String, String>{};
    for (final c in OsceEvaluationCategoryId.values) {
      final custom = fromCase.categoryLabels[c.key]?.trim();
      categoryLabels[c.key] =
          (custom != null && custom.isNotEmpty) ? custom : c.label;
    }

    final checklists = <String, List<OsceChecklistItem>>{};
    final defaults = defaultChecklists();
    for (final cat in enabled) {
      if (cat == 'diagnosis') continue;
      if (cat == 'exams') continue;
      final custom = fromCase.checklists[cat];
      checklists[cat] =
          (custom != null && custom.isNotEmpty) ? custom : (defaults[cat] ?? []);
    }

    final expectedExams = fromCase.expectedExams.isNotEmpty
        ? fromCase.expectedExams
        : defaultExpectedExams();

    var diagnoses = fromCase.acceptedDiagnoses;
    if (diagnoses.isEmpty && fallbackDiagnosisText != null) {
      final t = fallbackDiagnosisText.trim();
      if (t.isNotEmpty) diagnoses = [t];
    }

    return OsceEvaluationRubric(
      evaluationMode: 'legacy',
      useUniversalDefault: fromCase.useUniversalDefault,
      useCustomWeights: fromCase.useCustomWeights,
      weights: weights,
      categoryLabels: categoryLabels,
      enabledCategoryIds: enabled,
      enableExamsCategory: enableExams,
      checklists: checklists,
      acceptedDiagnoses: diagnoses,
      expectedExams: expectedExams,
      extraCategories: fromCase.extraCategories,
    );
  }

  /// Template para admin (aba Avaliação).
  static OsceEvaluationRubric templateForAdmin([OsceEvaluationRubric? saved]) {
    if (saved != null && saved.criteria.isNotEmpty) {
      return OsceEvaluationRubric(
        evaluationMode: 'criteria',
        criteria: List<OsceEvaluationCriterion>.from(saved.criteria),
      );
    }
    return OsceEvaluationRubric(
      evaluationMode: 'criteria',
      criteria: defaultCriteria(),
    );
  }

  static double sumCriteriaMaxWeight(List<OsceEvaluationCriterion> criteria) =>
      OsceEvaluationRubric.sumCriteriaMaxWeight(criteria);

  static double sumWeights(OsceEvaluationRubric rubric) {
    if (rubric.usesCriteriaMode) {
      return sumCriteriaMaxWeight(rubric.criteria);
    }
    var total = 0.0;
    for (final id in rubric.enabledCategoryIds) {
      total += rubric.weights[id] ?? defaultWeights[id] ?? 0;
    }
    for (final e in rubric.extraCategories) {
      total += e.maxScore;
    }
    return total;
  }
}

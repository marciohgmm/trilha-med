import 'package:cloud_firestore/cloud_firestore.dart';

/// Níveis de acerto do diagnóstico (categoria mais importante).
enum OsceDiagnosisLevel {
  wrong,
  partialLow,
  partialHigh,
  correct;

  String get firestoreValue => name;

  static OsceDiagnosisLevel fromValue(String? v) {
    return OsceDiagnosisLevel.values.firstWhere(
      (e) => e.name == v,
      orElse: () => OsceDiagnosisLevel.wrong,
    );
  }
}

/// Categorias do modelo universal OSCE.
enum OsceEvaluationCategoryId {
  anamnesis,
  physicalExam,
  diagnosis,
  conduct,
  exams,
  communication;

  String get key => name;

  String get label {
    switch (this) {
      case OsceEvaluationCategoryId.anamnesis:
        return 'Anamnese';
      case OsceEvaluationCategoryId.physicalExam:
        return 'Exame físico';
      case OsceEvaluationCategoryId.diagnosis:
        return 'Hipótese diagnóstica';
      case OsceEvaluationCategoryId.conduct:
        return 'Conduta';
      case OsceEvaluationCategoryId.exams:
        return 'Solicitação de exames';
      case OsceEvaluationCategoryId.communication:
        return 'Comunicação e postura';
    }
  }
}

/// Nível de desempenho em um critério avaliativo.
enum OsceCriterionLevel {
  adequate,
  partial,
  inadequate;

  String get label {
    switch (this) {
      case OsceCriterionLevel.adequate:
        return 'Adequado';
      case OsceCriterionLevel.partial:
        return 'Parcialmente adequado';
      case OsceCriterionLevel.inadequate:
        return 'Inadequado';
    }
  }

  String get firestoreValue => name;

  static OsceCriterionLevel? fromValue(String? v) {
    if (v == null || v.isEmpty) return null;
    for (final e in OsceCriterionLevel.values) {
      if (e.name == v) return e;
    }
    return null;
  }
}

/// Critério avaliativo configurável (modelo Revalida / OSCE).
class OsceEvaluationCriterion {
  final String id;
  final String title;
  final String description;
  final double scoreAdequate;
  final double scorePartial;
  final double scoreInadequate;
  final String explainAdequate;
  final String explainPartial;
  final String explainInadequate;

  const OsceEvaluationCriterion({
    required this.id,
    required this.title,
    required this.description,
    this.scoreAdequate = 0.5,
    this.scorePartial = 0.25,
    this.scoreInadequate = 0,
    this.explainAdequate = '',
    this.explainPartial = '',
    this.explainInadequate = '',
  });

  /// Peso máximo do critério (nota ao marcar "Adequado").
  double get maxWeight => scoreAdequate;

  double pointsFor(OsceCriterionLevel? level) {
    switch (level) {
      case OsceCriterionLevel.adequate:
        return scoreAdequate;
      case OsceCriterionLevel.partial:
        return scorePartial;
      case OsceCriterionLevel.inadequate:
        return scoreInadequate;
      case null:
        return 0;
    }
  }

  OsceEvaluationCriterion copyWith({
    String? id,
    String? title,
    String? description,
    double? scoreAdequate,
    double? scorePartial,
    double? scoreInadequate,
    String? explainAdequate,
    String? explainPartial,
    String? explainInadequate,
  }) {
    return OsceEvaluationCriterion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      scoreAdequate: scoreAdequate ?? this.scoreAdequate,
      scorePartial: scorePartial ?? this.scorePartial,
      scoreInadequate: scoreInadequate ?? this.scoreInadequate,
      explainAdequate: explainAdequate ?? this.explainAdequate,
      explainPartial: explainPartial ?? this.explainPartial,
      explainInadequate: explainInadequate ?? this.explainInadequate,
    );
  }

  factory OsceEvaluationCriterion.fromMap(Map<String, dynamic> m) {
    return OsceEvaluationCriterion(
      id: m['id']?.toString() ?? '',
      title: m['title']?.toString() ?? '',
      description: m['description']?.toString() ?? '',
      scoreAdequate: (m['scoreAdequate'] as num?)?.toDouble() ?? 0.5,
      scorePartial: (m['scorePartial'] as num?)?.toDouble() ?? 0.25,
      scoreInadequate: (m['scoreInadequate'] as num?)?.toDouble() ?? 0,
      explainAdequate: m['explainAdequate']?.toString() ?? '',
      explainPartial: m['explainPartial']?.toString() ?? '',
      explainInadequate: m['explainInadequate']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'scoreAdequate': scoreAdequate,
        'scorePartial': scorePartial,
        'scoreInadequate': scoreInadequate,
        'explainAdequate': explainAdequate,
        'explainPartial': explainPartial,
        'explainInadequate': explainInadequate,
      };
}

class OsceChecklistItem {
  final String id;
  final String label;

  const OsceChecklistItem({required this.id, required this.label});

  factory OsceChecklistItem.fromMap(Map<String, dynamic> m) {
    return OsceChecklistItem(
      id: m['id']?.toString() ?? '',
      label: m['label']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'id': id, 'label': label};
}

/// Rubrica configurável por estação (salva em [osce_cases]).
class OsceEvaluationRubric {
  /// `criteria` = critérios com Adequado/Parcial/Inadequado; `legacy` = checklist antigo.
  final String evaluationMode;
  final List<OsceEvaluationCriterion> criteria;
  final bool useUniversalDefault;
  final bool useCustomWeights;
  final Map<String, double> weights;
  final Map<String, String> categoryLabels;
  final List<String> enabledCategoryIds;
  final bool enableExamsCategory;
  final Map<String, List<OsceChecklistItem>> checklists;
  final List<String> acceptedDiagnoses;
  final List<OsceChecklistItem> expectedExams;
  final List<OsceExtraCategory> extraCategories;

  const OsceEvaluationRubric({
    this.evaluationMode = 'criteria',
    this.criteria = const [],
    this.useUniversalDefault = true,
    this.useCustomWeights = false,
    this.weights = const {},
    this.categoryLabels = const {},
    this.enabledCategoryIds = const [],
    this.enableExamsCategory = true,
    this.checklists = const {},
    this.acceptedDiagnoses = const [],
    this.expectedExams = const [],
    this.extraCategories = const [],
  });

  bool get usesCriteriaMode =>
      evaluationMode == 'criteria' && criteria.isNotEmpty;

  OsceEvaluationRubric copyWith({
    String? evaluationMode,
    List<OsceEvaluationCriterion>? criteria,
    bool? useUniversalDefault,
    bool? useCustomWeights,
    Map<String, double>? weights,
    Map<String, String>? categoryLabels,
    List<String>? enabledCategoryIds,
    bool? enableExamsCategory,
    Map<String, List<OsceChecklistItem>>? checklists,
    List<String>? acceptedDiagnoses,
    List<OsceChecklistItem>? expectedExams,
    List<OsceExtraCategory>? extraCategories,
  }) {
    return OsceEvaluationRubric(
      evaluationMode: evaluationMode ?? this.evaluationMode,
      criteria: criteria ?? this.criteria,
      useUniversalDefault: useUniversalDefault ?? this.useUniversalDefault,
      useCustomWeights: useCustomWeights ?? this.useCustomWeights,
      weights: weights ?? this.weights,
      categoryLabels: categoryLabels ?? this.categoryLabels,
      enabledCategoryIds: enabledCategoryIds ?? this.enabledCategoryIds,
      enableExamsCategory: enableExamsCategory ?? this.enableExamsCategory,
      checklists: checklists ?? this.checklists,
      acceptedDiagnoses: acceptedDiagnoses ?? this.acceptedDiagnoses,
      expectedExams: expectedExams ?? this.expectedExams,
      extraCategories: extraCategories ?? this.extraCategories,
    );
  }

  static double sumCriteriaMaxWeight(List<OsceEvaluationCriterion> list) {
    return list.fold<double>(0, (s, c) => s + c.maxWeight);
  }

  factory OsceEvaluationRubric.fromMap(Map<String, dynamic>? m) {
    if (m == null || m.isEmpty) {
      return const OsceEvaluationRubric();
    }
    final weightsRaw = m['weights'];
    final weights = <String, double>{};
    if (weightsRaw is Map) {
      weightsRaw.forEach((k, v) {
        weights[k.toString()] = (v as num?)?.toDouble() ?? 0;
      });
    }
    final labelsRaw = m['categoryLabels'];
    final categoryLabels = <String, String>{};
    if (labelsRaw is Map) {
      labelsRaw.forEach((k, v) {
        final s = v?.toString().trim() ?? '';
        if (s.isNotEmpty) categoryLabels[k.toString()] = s;
      });
    }
    final checklistsRaw = m['checklists'];
    final checklists = <String, List<OsceChecklistItem>>{};
    if (checklistsRaw is Map) {
      checklistsRaw.forEach((k, v) {
        if (v is List) {
          checklists[k.toString()] = v
              .whereType<Map>()
              .map((e) => OsceChecklistItem.fromMap(
                    Map<String, dynamic>.from(e),
                  ))
              .where((i) => i.id.isNotEmpty)
              .toList();
        }
      });
    }
    final examsRaw = m['expectedExams'];
    final expectedExams = <OsceChecklistItem>[];
    if (examsRaw is List) {
      for (final e in examsRaw) {
        if (e is Map) {
          expectedExams.add(
            OsceChecklistItem.fromMap(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    final extraRaw = m['extraCategories'];
    final extra = <OsceExtraCategory>[];
    if (extraRaw is List) {
      for (final e in extraRaw) {
        if (e is Map) {
          extra.add(OsceExtraCategory.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }
    final criteriaRaw = m['criteria'];
    final criteria = <OsceEvaluationCriterion>[];
    if (criteriaRaw is List) {
      for (final e in criteriaRaw) {
        if (e is Map) {
          final c = OsceEvaluationCriterion.fromMap(
            Map<String, dynamic>.from(e),
          );
          if (c.id.isNotEmpty) criteria.add(c);
        }
      }
    }

    return OsceEvaluationRubric(
      evaluationMode: m['evaluationMode']?.toString() ?? 'criteria',
      criteria: criteria,
      useUniversalDefault: m['useUniversalDefault'] != false,
      useCustomWeights: m['useCustomWeights'] == true,
      weights: weights,
      categoryLabels: categoryLabels,
      enabledCategoryIds: (m['enabledCategoryIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      enableExamsCategory: m['enableExamsCategory'] != false,
      checklists: checklists,
      acceptedDiagnoses: (m['acceptedDiagnoses'] as List?)
              ?.map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const [],
      expectedExams: expectedExams,
      extraCategories: extra,
    );
  }

  Map<String, dynamic> toMap() => {
        'evaluationMode': evaluationMode,
        'criteria': criteria.map((c) => c.toMap()).toList(),
        'useUniversalDefault': useUniversalDefault,
        'useCustomWeights': useCustomWeights,
        'weights': weights,
        'categoryLabels': categoryLabels,
        'enabledCategoryIds': enabledCategoryIds,
        'enableExamsCategory': enableExamsCategory,
        'checklists': checklists.map(
          (k, v) => MapEntry(k, v.map((i) => i.toMap()).toList()),
        ),
        'acceptedDiagnoses': acceptedDiagnoses,
        'expectedExams': expectedExams.map((e) => e.toMap()).toList(),
        'extraCategories': extraCategories.map((e) => e.toMap()).toList(),
      };
}

class OsceExtraCategory {
  final String id;
  final String label;
  final double maxScore;
  final List<OsceChecklistItem> items;

  const OsceExtraCategory({
    required this.id,
    required this.label,
    required this.maxScore,
    this.items = const [],
  });

  factory OsceExtraCategory.fromMap(Map<String, dynamic> m) {
    final itemsRaw = m['items'];
    final items = <OsceChecklistItem>[];
    if (itemsRaw is List) {
      for (final e in itemsRaw) {
        if (e is Map) {
          items.add(OsceChecklistItem.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }
    return OsceExtraCategory(
      id: m['id']?.toString() ?? '',
      label: m['label']?.toString() ?? '',
      maxScore: (m['maxScore'] as num?)?.toDouble() ?? 1,
      items: items,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'maxScore': maxScore,
        'items': items.map((i) => i.toMap()).toList(),
      };
}

enum OsceEvaluationStatus { draft, finalized }

/// Documento em [osce_evaluations] — sessão ao vivo + resultado final.
class OsceEvaluationRecord {
  final String id;
  final String roomId;
  final String caseId;
  final String caseTitle;
  final String stationName;
  final String specialty;
  final String specialtyKey;
  final String evaluatorId;
  final String evaluatorName;
  final String evaluatedUserId;
  final String evaluatedName;
  final OsceEvaluationStatus status;
  final OsceEvaluationRubric rubricSnapshot;
  final Map<String, String> criterionRatings;
  final Map<String, List<String>> checkedItemIds;
  final OsceDiagnosisLevel diagnosisLevel;
  final Map<String, double> categoryScores;
  final double totalScore;
  final double maxScore;
  final int correctCount;
  final int totalChecklistItems;
  final double performancePercent;
  final int durationInSeconds;
  final DateTime? stationStartedAt;
  final DateTime createdAt;
  final DateTime? finalizedAt;

  const OsceEvaluationRecord({
    required this.id,
    required this.roomId,
    required this.caseId,
    required this.caseTitle,
    required this.stationName,
    required this.specialty,
    required this.specialtyKey,
    required this.evaluatorId,
    required this.evaluatorName,
    required this.evaluatedUserId,
    required this.evaluatedName,
    required this.status,
    required this.rubricSnapshot,
    this.criterionRatings = const {},
    required this.checkedItemIds,
    required this.diagnosisLevel,
    required this.categoryScores,
    required this.totalScore,
    required this.maxScore,
    required this.correctCount,
    required this.totalChecklistItems,
    required this.performancePercent,
    required this.durationInSeconds,
    this.stationStartedAt,
    required this.createdAt,
    this.finalizedAt,
  });

  bool get isFinalized => status == OsceEvaluationStatus.finalized;
  bool get canEdit => status == OsceEvaluationStatus.draft;

  factory OsceEvaluationRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final m = doc.data() ?? {};
    final ratingsRaw = m['criterionRatings'] as Map<String, dynamic>? ?? {};
    final criterionRatings = <String, String>{};
    ratingsRaw.forEach((k, v) {
      criterionRatings[k.toString()] = v.toString();
    });

    final checkedRaw = m['checkedItemIds'] as Map<String, dynamic>? ?? {};
    final checked = <String, List<String>>{};
    checkedRaw.forEach((k, v) {
      if (v is List) {
        checked[k.toString()] = v.map((e) => e.toString()).toList();
      }
    });
    final scoresRaw = m['categoryScores'] as Map<String, dynamic>? ?? {};
    final scores = <String, double>{};
    scoresRaw.forEach((k, v) {
      scores[k.toString()] = (v as num?)?.toDouble() ?? 0;
    });
    return OsceEvaluationRecord(
      id: doc.id,
      roomId: m['roomId']?.toString() ?? '',
      caseId: m['caseId']?.toString() ?? '',
      caseTitle: m['caseTitle']?.toString() ?? '',
      stationName: m['stationName']?.toString() ?? '',
      specialty: m['specialty']?.toString() ?? '',
      specialtyKey: m['specialtyKey']?.toString() ?? '',
      evaluatorId: m['evaluatorId']?.toString() ?? '',
      evaluatorName: m['evaluatorName']?.toString() ?? '',
      evaluatedUserId: m['evaluatedUserId']?.toString() ?? '',
      evaluatedName: m['evaluatedName']?.toString() ?? '',
      status: m['status']?.toString() == 'finalized'
          ? OsceEvaluationStatus.finalized
          : OsceEvaluationStatus.draft,
      rubricSnapshot:
          OsceEvaluationRubric.fromMap(m['rubricSnapshot'] as Map<String, dynamic>?),
      criterionRatings: criterionRatings,
      checkedItemIds: checked,
      diagnosisLevel: OsceDiagnosisLevel.fromValue(m['diagnosisLevel']?.toString()),
      categoryScores: scores,
      totalScore: (m['totalScore'] as num?)?.toDouble() ?? 0,
      maxScore: (m['maxScore'] as num?)?.toDouble() ?? 10,
      correctCount: (m['correctCount'] as num?)?.toInt() ?? 0,
      totalChecklistItems: (m['totalChecklistItems'] as num?)?.toInt() ?? 0,
      performancePercent: (m['performancePercent'] as num?)?.toDouble() ?? 0,
      durationInSeconds: (m['durationInSeconds'] as num?)?.toInt() ?? 0,
      stationStartedAt: _ts(m['stationStartedAt']),
      createdAt: _ts(m['createdAt']) ?? DateTime.now(),
      finalizedAt: _ts(m['finalizedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap() => {
        'roomId': roomId,
        'caseId': caseId,
        'caseTitle': caseTitle,
        'stationName': stationName,
        'specialty': specialty,
        'specialtyKey': specialtyKey,
        'evaluatorId': evaluatorId,
        'evaluatorName': evaluatorName,
        'evaluatedUserId': evaluatedUserId,
        'evaluatedName': evaluatedName,
        'status': status == OsceEvaluationStatus.finalized ? 'finalized' : 'draft',
        'rubricSnapshot': rubricSnapshot.toMap(),
        'criterionRatings': criterionRatings,
        'checkedItemIds': checkedItemIds,
        'diagnosisLevel': diagnosisLevel.firestoreValue,
        'categoryScores': categoryScores,
        'totalScore': totalScore,
        'maxScore': maxScore,
        'correctCount': correctCount,
        'totalChecklistItems': totalChecklistItems,
        'performancePercent': performancePercent,
        'durationInSeconds': durationInSeconds,
        if (stationStartedAt != null)
          'stationStartedAt': Timestamp.fromDate(stationStartedAt!),
        'createdAt': Timestamp.fromDate(createdAt),
        if (finalizedAt != null) 'finalizedAt': Timestamp.fromDate(finalizedAt!),
      };
}

DateTime? _ts(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

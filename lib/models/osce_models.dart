import 'package:cloud_firestore/cloud_firestore.dart';

import 'osce_evaluation_models.dart';



enum OsceRoomStatus {

  waiting,

  selectingCase,

  ready,

  running,

  /// Estação encerrada; avaliação em andamento (todos na tela de notas).
  evaluating,

  ended;



  String get value => name;



  static OsceRoomStatus fromValue(String? v) {

    return OsceRoomStatus.values.firstWhere(

      (e) => e.name == v,

      orElse: () => OsceRoomStatus.waiting,

    );

  }

}



/// Papéis na sala: avaliador (ator), avaliado (médico), telespectador.

enum OsceParticipantRole {

  evaluator,

  evaluated,

  spectator;



  String get value => name;



  String get label {

    switch (this) {

      case OsceParticipantRole.evaluator:

        return 'Avaliador';

      case OsceParticipantRole.evaluated:

        return 'Médico avaliado';

      case OsceParticipantRole.spectator:

        return 'Telespectador';

    }

  }



  static OsceParticipantRole fromValue(String? v) {

    if (v == null) return OsceParticipantRole.spectator;

    switch (v) {

      case 'evaluator':

      case 'actor':

      case 'host':

        return OsceParticipantRole.evaluator;

      case 'evaluated':

      case 'doctor':

        return OsceParticipantRole.evaluated;

      case 'spectator':

      case 'observer':

        return OsceParticipantRole.spectator;

      default:

        return OsceParticipantRole.spectator;

    }

  }



  String get firestoreValue {

    switch (this) {

      case OsceParticipantRole.evaluator:

        return 'evaluator';

      case OsceParticipantRole.evaluated:

        return 'evaluated';

      case OsceParticipantRole.spectator:

        return 'spectator';

    }

  }

}



enum OsceExamType { physical, laboratory, imaging }



class OsceExamSlot {

  final bool requested;

  final bool released;

  final DateTime? requestedAt;

  final DateTime? releasedAt;



  const OsceExamSlot({

    this.requested = false,

    this.released = false,

    this.requestedAt,

    this.releasedAt,

  });



  factory OsceExamSlot.fromMap(Map<String, dynamic>? map) {

    if (map == null) return const OsceExamSlot();

    return OsceExamSlot(

      requested: map['requested'] == true,

      released: map['released'] == true,

      requestedAt: _ts(map['requestedAt']),

      releasedAt: _ts(map['releasedAt']),

    );

  }



  Map<String, dynamic> toMap() => {

        'requested': requested,

        'released': released,

        if (requestedAt != null)

          'requestedAt': Timestamp.fromDate(requestedAt!),

        if (releasedAt != null) 'releasedAt': Timestamp.fromDate(releasedAt!),

      };

}



class OsceRoomModel {

  final String id;

  final int roomNumber;

  final String specialty;

  final bool isPublic;

  final String? joinCode;

  final String hostId;

  final String? caseId;

  final OsceRoomStatus status;

  final bool stationStarted;

  final int timerDurationSec;

  final DateTime? timerStartedAt;

  final DateTime? timerEndsAt;

  final String? evaluatorUserId;

  final String? evaluatedUserId;

  final OsceExamSlot physicalExam;

  final OsceExamSlot laboratoryExam;

  final OsceExamSlot imagingExam;

  final int participantCount;

  final String? evaluationId;

  final DateTime createdAt;



  const OsceRoomModel({

    required this.id,

    required this.roomNumber,

    this.specialty = '',

    required this.isPublic,

    this.joinCode,

    required this.hostId,

    this.caseId,

    required this.status,

    this.stationStarted = false,

    this.timerDurationSec = 600,

    this.timerStartedAt,

    this.timerEndsAt,

    this.evaluatorUserId,

    this.evaluatedUserId,

    this.physicalExam = const OsceExamSlot(),

    this.laboratoryExam = const OsceExamSlot(),

    this.imagingExam = const OsceExamSlot(),

    this.participantCount = 0,

    this.evaluationId,

    required this.createdAt,

  });



  String get displayName => 'Sala $roomNumber';



  String get typeLabel => isPublic ? 'Pública' : 'Privada';



  String get listTitle => '$displayName — $typeLabel';



  int get remainingSeconds {

    if (timerEndsAt == null) return timerDurationSec;

    final diff = timerEndsAt!.difference(DateTime.now()).inSeconds;

    return diff.clamp(0, timerDurationSec);

  }



  factory OsceRoomModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {

    final m = doc.data() ?? {};

    final exams = m['exams'] as Map<String, dynamic>?;

    final roomNumRaw = (m['roomNumber'] as num?)?.toInt();

    final legacyName = m['name']?.toString() ?? '';

    int roomNumber = roomNumRaw ?? 0;

    if (roomNumber == 0) {

      final match = RegExp(r'Sala\s*(\d+)').firstMatch(legacyName);

      roomNumber = int.tryParse(match?.group(1) ?? '') ?? 0;

    }

    return OsceRoomModel(

      id: doc.id,

      roomNumber: roomNumber,

      specialty: m['specialty']?.toString() ?? '',

      isPublic: m['isPublic'] == true,

      joinCode: m['joinCode']?.toString(),

      hostId: m['hostId']?.toString() ?? '',

      caseId: m['caseId']?.toString(),

      status: OsceRoomStatus.fromValue(m['status']?.toString()),

      stationStarted: m['stationStarted'] == true,

      timerDurationSec: (m['timerDurationSec'] as num?)?.toInt() ?? 600,

      timerStartedAt: _ts(m['timerStartedAt']),

      timerEndsAt: _ts(m['timerEndsAt']),

      evaluatorUserId: m['evaluatorUserId']?.toString() ??

          m['actorUserId']?.toString(),

      evaluatedUserId: m['evaluatedUserId']?.toString() ??

          m['doctorUserId']?.toString(),

      physicalExam: OsceExamSlot.fromMap(

        exams?['physical'] as Map<String, dynamic>?,

      ),

      laboratoryExam: OsceExamSlot.fromMap(

        exams?['laboratory'] as Map<String, dynamic>?,

      ),

      imagingExam: OsceExamSlot.fromMap(

        exams?['imaging'] as Map<String, dynamic>?,

      ),

      participantCount: (m['participantCount'] as num?)?.toInt() ?? 0,

      evaluationId: m['evaluationId']?.toString(),

      createdAt: _ts(m['createdAt']) ?? DateTime.now(),

    );

  }

}



class OsceParticipantModel {

  final String userId;

  final String displayName;

  final OsceParticipantRole role;

  final DateTime joinedAt;



  const OsceParticipantModel({

    required this.userId,

    required this.displayName,

    required this.role,

    required this.joinedAt,

  });



  factory OsceParticipantModel.fromDoc(

    DocumentSnapshot<Map<String, dynamic>> doc,

  ) {

    final m = doc.data() ?? {};

    return OsceParticipantModel(

      userId: doc.id,

      displayName: m['displayName']?.toString() ?? 'Participante',

      role: OsceParticipantRole.fromValue(m['role']?.toString()),

      joinedAt: _ts(m['joinedAt']) ?? DateTime.now(),

    );

  }

}



class OsceCaseModel {

  final String id;

  final String title;

  final String specialty;

  final String scenario;

  final String caseDescription;

  final String tasks;

  final Map<String, String> actorScript;

  final String physicalExamContent;

  final String laboratoryContent;

  final String imagingContent;

  final String? imagingImageUrl;

  final String hiddenDiagnosis;

  final OsceEvaluationRubric evaluationRubric;

  const OsceCaseModel({

    required this.id,

    required this.title,

    required this.specialty,

    required this.scenario,

    required this.caseDescription,

    required this.tasks,

    required this.actorScript,

    required this.physicalExamContent,

    required this.laboratoryContent,

    required this.imagingContent,

    this.imagingImageUrl,

    required this.hiddenDiagnosis,

    this.evaluationRubric = const OsceEvaluationRubric(),

  });



  factory OsceCaseModel.fromMap(String id, Map<String, dynamic> m) {

    final scriptRaw = m['actorScript'];

    final script = <String, String>{};

    if (scriptRaw is Map) {

      scriptRaw.forEach((k, v) => script[k.toString()] = v.toString());

    }

    return OsceCaseModel(

      id: id,

      title: m['title']?.toString() ?? '',

      specialty: m['specialty']?.toString() ?? '',

      scenario: m['scenario']?.toString() ?? '',

      caseDescription: m['caseDescription']?.toString() ?? '',

      tasks: m['tasks']?.toString() ?? '',

      actorScript: script,

      physicalExamContent: m['physicalExamContent']?.toString() ?? '',

      laboratoryContent: m['laboratoryContent']?.toString() ?? '',

      imagingContent: m['imagingContent']?.toString() ?? '',

      imagingImageUrl: m['imagingImageUrl']?.toString(),

      hiddenDiagnosis: m['hiddenDiagnosis']?.toString() ?? '',

      evaluationRubric: OsceEvaluationRubric.fromMap(
        m['evaluationRubric'] as Map<String, dynamic>?,
      ),

    );

  }



  factory OsceCaseModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {

    return OsceCaseModel.fromMap(doc.id, doc.data() ?? {});

  }

  Map<String, dynamic> toFirestoreMap() => {
        'title': title,
        'specialty': specialty,
        'scenario': scenario,
        'caseDescription': caseDescription,
        'tasks': tasks,
        'actorScript': actorScript,
        'physicalExamContent': physicalExamContent,
        'laboratoryContent': laboratoryContent,
        'imagingContent': imagingContent,
        if (imagingImageUrl != null) 'imagingImageUrl': imagingImageUrl,
        'hiddenDiagnosis': hiddenDiagnosis,
        'evaluationRubric': evaluationRubric.toMap(),
      };

}



/// Especialidades para filtro de casos.

class OsceSpecialties {

  OsceSpecialties._();



  static const allLabel = 'Mostrar Todas';



  static const List<String> list = [

    'Clínica Médica',

    'Clínica Cirúrgica',

    'Medicina da Família e Comunidade',

    'Pediatria',

    'Ginecologia e Obstetrícia',

  ];

}



DateTime? _ts(dynamic v) {

  if (v is Timestamp) return v.toDate();

  if (v is DateTime) return v;

  return null;

}



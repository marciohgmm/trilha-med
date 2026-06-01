import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo da Fase Prática (estações / simulações).
/// Coleção Firestore: [PracticalPhaseRepository.collectionName].
class PracticalPhaseModel {
  final String id;
  final String title;
  final String slug;
  final String description;
  final String category;
  final String specialty;
  final String difficulty;
  final String thumbnailUrl;
  final bool isActive;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final List<PracticalPhaseAttachment> attachments;
  final List<PracticalPhaseSection> sections;
  final int order;

  const PracticalPhaseModel({
    required this.id,
    required this.title,
    required this.slug,
    required this.description,
    required this.category,
    required this.specialty,
    required this.difficulty,
    required this.thumbnailUrl,
    required this.isActive,
    required this.isPublished,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.attachments = const [],
    this.sections = const [],
    this.order = 0,
  });

  int get stationCount => sections.fold<int>(
        0,
        (total, s) => total + (s.items.isNotEmpty ? s.items.length : 1),
      );

  String get displayStatus {
    if (!isActive) return 'Inativo';
    if (!isPublished) return 'Rascunho';
    return 'Publicado';
  }

  bool get visibleToStudents => isActive && isPublished;

  factory PracticalPhaseModel.fromMap(String id, Map<String, dynamic> map) {
    return PracticalPhaseModel(
      id: id,
      title: map['title']?.toString() ?? '',
      slug: map['slug']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      specialty: map['specialty']?.toString() ?? '',
      difficulty: map['difficulty']?.toString() ?? 'Intermediário',
      thumbnailUrl: map['thumbnailUrl']?.toString() ?? '',
      isActive: map['isActive'] == true,
      isPublished: map['isPublished'] == true,
      createdAt: _ts(map['createdAt']) ?? DateTime.now(),
      updatedAt: _ts(map['updatedAt']) ?? DateTime.now(),
      createdBy: map['createdBy']?.toString() ?? '',
      attachments: _attachments(map['attachments']),
      sections: _sections(map['sections']),
      order: (map['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'slug': slug,
      'description': description,
      'category': category,
      'specialty': specialty,
      'difficulty': difficulty,
      'thumbnailUrl': thumbnailUrl,
      'isActive': isActive,
      'isPublished': isPublished,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'attachments': attachments.map((e) => e.toMap()).toList(),
      'sections': sections.map((e) => e.toMap()).toList(),
      'order': order,
    };
  }

  PracticalPhaseModel copyWith({
    String? id,
    String? title,
    String? slug,
    String? description,
    String? category,
    String? specialty,
    String? difficulty,
    String? thumbnailUrl,
    bool? isActive,
    bool? isPublished,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    List<PracticalPhaseAttachment>? attachments,
    List<PracticalPhaseSection>? sections,
    int? order,
  }) {
    return PracticalPhaseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      category: category ?? this.category,
      specialty: specialty ?? this.specialty,
      difficulty: difficulty ?? this.difficulty,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isActive: isActive ?? this.isActive,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      attachments: attachments ?? this.attachments,
      sections: sections ?? this.sections,
      order: order ?? this.order,
    );
  }

  static List<PracticalPhaseAttachment> _attachments(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => PracticalPhaseAttachment.fromMap(
            Map<String, dynamic>.from(e)))
        .toList();
  }

  static List<PracticalPhaseSection> _sections(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) =>
            PracticalPhaseSection.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static String slugify(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}

class PracticalPhaseAttachment {
  final String id;
  final String name;
  final String url;
  final String type;
  final int size;

  const PracticalPhaseAttachment({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    this.size = 0,
  });

  factory PracticalPhaseAttachment.fromMap(Map<String, dynamic> map) {
    return PracticalPhaseAttachment(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      url: map['url']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      size: (map['size'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'url': url,
        'type': type,
        'size': size,
      };
}

class PracticalPhaseSection {
  final String id;
  final String title;
  final String description;
  final int order;
  final List<PracticalPhaseItem> items;

  const PracticalPhaseSection({
    required this.id,
    required this.title,
    required this.description,
    this.order = 0,
    this.items = const [],
  });

  factory PracticalPhaseSection.fromMap(Map<String, dynamic> map) {
    final itemsRaw = map['items'];
    final items = itemsRaw is List
        ? itemsRaw
            .whereType<Map>()
            .map((e) =>
                PracticalPhaseItem.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : <PracticalPhaseItem>[];
    return PracticalPhaseSection(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      order: (map['order'] as num?)?.toInt() ?? 0,
      items: items,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'order': order,
        'items': items.map((e) => e.toMap()).toList(),
      };

  PracticalPhaseSection copyWith({
    String? title,
    String? description,
    int? order,
    List<PracticalPhaseItem>? items,
  }) {
    return PracticalPhaseSection(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      order: order ?? this.order,
      items: items ?? this.items,
    );
  }
}

class PracticalPhaseItem {
  final String id;
  final String title;
  final String content;
  final String type;
  final int order;

  const PracticalPhaseItem({
    required this.id,
    required this.title,
    required this.content,
    this.type = 'texto',
    this.order = 0,
  });

  factory PracticalPhaseItem.fromMap(Map<String, dynamic> map) {
    return PracticalPhaseItem(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      type: map['type']?.toString() ?? 'texto',
      order: (map['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'type': type,
        'order': order,
      };

  PracticalPhaseItem copyWith({
    String? title,
    String? content,
    String? type,
    int? order,
  }) {
    return PracticalPhaseItem(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      order: order ?? this.order,
    );
  }
}

/// Filtros da listagem (aluno e admin).
class PracticalPhaseFilters {
  final String search;
  final String? category;
  final String? specialty;
  final String? difficulty;
  final String? status; // publicado | rascunho | inativo | todos

  const PracticalPhaseFilters({
    this.search = '',
    this.category,
    this.specialty,
    this.difficulty,
    this.status,
  });

  PracticalPhaseFilters copyWith({
    String? search,
    String? category,
    String? specialty,
    String? difficulty,
    String? status,
    bool clearCategory = false,
    bool clearSpecialty = false,
    bool clearDifficulty = false,
    bool clearStatus = false,
  }) {
    return PracticalPhaseFilters(
      search: search ?? this.search,
      category: clearCategory ? null : (category ?? this.category),
      specialty: clearSpecialty ? null : (specialty ?? this.specialty),
      difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
      status: clearStatus ? null : (status ?? this.status),
    );
  }

  bool matches(PracticalPhaseModel m, {required bool adminView}) {
    if (!adminView && !m.visibleToStudents) return false;

    final q = search.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hay =
          '${m.title} ${m.description} ${m.category} ${m.specialty}'.toLowerCase();
      if (!hay.contains(q)) return false;
    }
    if (category != null && category!.isNotEmpty && m.category != category) {
      return false;
    }
    if (specialty != null &&
        specialty!.isNotEmpty &&
        m.specialty != specialty) {
      return false;
    }
    if (difficulty != null &&
        difficulty!.isNotEmpty &&
        m.difficulty != difficulty) {
      return false;
    }
    if (status != null && status!.isNotEmpty && status != 'todos') {
      switch (status) {
        case 'publicado':
          if (!m.isPublished || !m.isActive) return false;
          break;
        case 'rascunho':
          if (m.isPublished) return false;
          break;
        case 'inativo':
          if (m.isActive) return false;
          break;
      }
    }
    return true;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Card/módulo da landing da Fase Prática (gerenciável no admin).
/// Coleção: `practical_phase_modules`.
class PracticalPhaseModule {
  final String id;
  final String sectionKey;
  final String title;
  final String description;
  final String iconName;
  final int order;
  final bool isActive;
  final bool isPublished;
  final bool requiresPremium;
  final String? imageUrl;
  final String? pdfUrl;
  final String? videoUrl;
  final String? linkUrl;
  final String actionLabel;

  const PracticalPhaseModule({
    required this.id,
    required this.sectionKey,
    required this.title,
    required this.description,
    this.iconName = 'school',
    this.order = 0,
    this.isActive = true,
    this.isPublished = true,
    this.requiresPremium = false,
    this.imageUrl,
    this.pdfUrl,
    this.videoUrl,
    this.linkUrl,
    this.actionLabel = 'Acessar',
  });

  bool get visibleToStudents => isActive && isPublished;

  static const sectionLabels = <String, String>{
    'simulados': 'Simulados práticos',
    'casos_clinicos': 'Casos clínicos',
    'osce': 'Estações OSCE',
    'checklist': 'Checklist de atendimento',
    'comunicacao': 'Treinamento de comunicação',
    'condutas': 'Condutas rápidas',
    'revisao': 'Revisão final',
  };

  String get sectionLabel => sectionLabels[sectionKey] ?? sectionKey;

  factory PracticalPhaseModule.fromMap(String id, Map<String, dynamic> map) {
    return PracticalPhaseModule(
      id: id,
      sectionKey: map['sectionKey']?.toString() ?? 'simulados',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      iconName: map['iconName']?.toString() ?? 'school',
      order: (map['order'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] != false,
      isPublished: map['isPublished'] != false,
      imageUrl: map['imageUrl']?.toString(),
      pdfUrl: map['pdfUrl']?.toString(),
      videoUrl: map['videoUrl']?.toString(),
      linkUrl: map['linkUrl']?.toString(),
      actionLabel: map['actionLabel']?.toString() ?? 'Acessar',
    );
  }

  Map<String, dynamic> toMap() => {
        'sectionKey': sectionKey,
        'title': title,
        'description': description,
        'iconName': iconName,
        'order': order,
        'isActive': isActive,
        'isPublished': isPublished,
        'requiresPremium': requiresPremium,
        'imageUrl': imageUrl,
        'pdfUrl': pdfUrl,
        'videoUrl': videoUrl,
        'linkUrl': linkUrl,
        'actionLabel': actionLabel,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

import 'package:file_picker/file_picker.dart';
import '../data/practical_phase_seed.dart';
import '../models/practical_phase_model.dart';
import '../repositories/practical_phase_repository.dart';
import '../utils/practical_phase_storage_upload.dart';

/// Camada de negócio da Fase Prática.
/// Integração: Firestore via [FirestorePracticalPhaseRepository];
/// Storage via [uploadPracticalPhaseFile].
class PracticalPhaseService {
  PracticalPhaseService({PracticalPhaseRepository? repository})
      : _repo = repository ?? FirestorePracticalPhaseRepository();

  final PracticalPhaseRepository _repo;

  Stream<List<PracticalPhaseModel>> streamAllAdmin() => _repo.watchAll();

  Stream<List<PracticalPhaseModel>> streamPublished({
    bool includePremiumContent = true,
  }) =>
      _repo.watchPublished(includePremiumContent: includePremiumContent);

  Future<PracticalPhaseModel?> getById(String id) => _repo.getById(id);

  Future<String> saveModel({
    required PracticalPhaseModel model,
    required String userId,
    bool isNew = false,
  }) async {
    final now = DateTime.now();
    final slug = model.slug.isNotEmpty
        ? model.slug
        : PracticalPhaseModel.slugify(model.title);

    final payload = model.copyWith(
      slug: slug,
      updatedAt: now,
      createdBy: model.createdBy.isEmpty ? userId : model.createdBy,
      createdAt: isNew ? now : model.createdAt,
    );

    if (isNew || model.id.isEmpty) {
      return _repo.create(payload);
    }
    await _repo.update(model.id, payload.toMap());
    return model.id;
  }

  Future<void> deleteModel(String id) => _repo.delete(id);

  Future<String> duplicateModel(String id, String userId) async {
    final original = await _repo.getById(id);
    if (original == null) throw Exception('Modelo não encontrado.');
    final copy = original.copyWith(
      id: '',
      title: '${original.title} (cópia)',
      slug: PracticalPhaseModel.slugify('${original.title}-copia'),
      isPublished: false,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: userId,
    );
    return _repo.create(copy);
  }

  Future<void> setActive(String id, bool value) =>
      _repo.update(id, {'isActive': value});

  Future<void> setPublished(String id, bool value) =>
      _repo.update(id, {'isPublished': value});

  Future<void> reorder(List<PracticalPhaseModel> models) async {
    final items = <({String id, int order})>[];
    for (var i = 0; i < models.length; i++) {
      items.add((id: models[i].id, order: i));
    }
    await _repo.updateOrder(items);
  }

  Future<PracticalPhaseAttachment> uploadAttachment({
    required String modelId,
    required PlatformFile file,
    void Function(double progress)? onProgress,
  }) async {
    final err = validatePracticalPhaseFile(file);
    if (err != null) throw Exception(err);

    final size = await fileSizeFromPlatformFile(file);
    onProgress?.call(0.2);
    final url = await uploadPracticalPhaseFile(
      modelId: modelId,
      file: file,
      subfolder: 'attachments',
    );
    onProgress?.call(1.0);

    return PracticalPhaseAttachment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: file.name,
      url: url,
      type: file.extension ?? 'file',
      size: size,
    );
  }

  Future<String> uploadThumbnail({
    required String modelId,
    required PlatformFile file,
  }) async {
    final err = validatePracticalPhaseFile(file, maxBytes: 5 * 1024 * 1024, imagesOnly: true);
    if (err != null) throw Exception(err);
    return uploadPracticalPhaseFile(
      modelId: modelId,
      file: file,
      subfolder: 'thumbnails',
    );
  }

  /// Insere modelos de demonstração se a coleção estiver vazia.
  /// Remova ou desative em produção se não quiser seed automático.
  Future<int> seedMockIfEmpty({required String userId}) async {
    if (!await _repo.isEmpty()) return 0;
    var count = 0;
    for (final model in PracticalPhaseSeed.mockModels(userId)) {
      await _repo.create(model);
      count++;
    }
    return count;
  }

  List<PracticalPhaseModel> applyFilters(
    List<PracticalPhaseModel> list,
    PracticalPhaseFilters filters, {
    required bool adminView,
  }) {
    return list.where((m) => filters.matches(m, adminView: adminView)).toList();
  }

  Set<String> distinctValues(
    List<PracticalPhaseModel> list,
    String Function(PracticalPhaseModel) pick,
  ) {
    return list.map(pick).where((e) => e.trim().isNotEmpty).toSet();
  }
}

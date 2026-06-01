import 'dart:convert';

/// Imagens dos flashcards: URLs via Firebase Storage, memoização de
/// [getDownloadURL], cache em disco com [CachedNetworkImage] e toque para
/// fullscreen na tela de estudo ([FullScreenImagePage]).

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_application_1/screens/full_screen_image_page.dart';

/// Mensagem quando a imagem do card não pôde ser carregada (Storage / rede).
const String kFlashcardMissingAssetMessage =
    'Atualize o aplicativo para visualizar esta imagem.';

/// Pasta no bucket Firebase Storage (minúsculas, alinhado às regras típicas).
const String kFlashcardStorageRootSegment = 'imagenscard';

/// Legado: pasta empacotada no app (antes da migração para Storage).
const String pastaImagensCard = 'assets/images/Imagenscard/';

/// Extensões aceitas no seletor de arquivo ao criar/editar card.
const List<String> kExtensoesImagemCardPicker = [
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'bmp',
  'tif',
  'tiff',
  'heic',
  'heif',
];

/// Normaliza o identificador salvo no Firestore para ref em Storage ou URL pública.
///
/// Aceita: URL `http(s)`, `imagenscard/arquivo.ext`, nome simples `arquivo.ext`,
/// ou caminho legado `assets/images/Imagenscard/arquivo.ext`.
String flashcardMigrateImageFieldToStorageRef(String? raw) {
  var s = (raw ?? '').trim().replaceAll(r'\', '/');
  if (s.isEmpty) return '';
  if (s.contains('..')) return '';
  if (s.startsWith('http://') || s.startsWith('https://')) return s;
  final lower = s.toLowerCase();
  if (lower.startsWith('$kFlashcardStorageRootSegment/')) {
    final rest = s.substring('$kFlashcardStorageRootSegment/'.length);
    if (rest.isEmpty || rest.contains('/') || rest.contains('..')) {
      return '';
    }
    return '$kFlashcardStorageRootSegment/$rest';
  }
  final assetsImagenscard = 'assets/images/imagenscard/';
  if (lower.startsWith(assetsImagenscard) ||
      lower.startsWith('assets/images/Imagenscard/')) {
    final name = s.split(RegExp(r'[\\/]+')).last;
    return _bareFilenameToStorageRef(name);
  }
  if (lower.startsWith('assets/images/')) {
    final name = s.split(RegExp(r'[\\/]+')).last;
    return _bareFilenameToStorageRef(name);
  }
  return _bareFilenameToStorageRef(s);
}

String _bareFilenameToStorageRef(String name) {
  final base = flashcardSanitizeBareFilename(name);
  if (base.isEmpty) return '';
  return '$kFlashcardStorageRootSegment/$base';
}

/// Remove caracteres inválidos do **nome de arquivo** (sem pastas).
String flashcardSanitizeBareFilename(String? input) {
  if (input == null) return '';
  var s = input.trim().replaceAll(r'\', '/').split('/').last;
  if (s.isEmpty) return '';
  s = s.replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '');
  if (s.isEmpty || s == '.' || s == '..' || s.contains('..')) return '';
  final lower = s.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return '';
  }
  return s;
}

/// Compatível com chamadas antigas: trata nome simples ou ref `imagenscard/...`.
String flashcardSanitizeNomeArquivo(String? input) {
  final s = (input ?? '').trim().replaceAll(r'\', '/');
  if (s.isEmpty) return '';
  if (s.contains('..')) return '';
  if (s.startsWith('http://') || s.startsWith('https://')) return '';
  final lower = s.toLowerCase();
  if (lower.startsWith('$kFlashcardStorageRootSegment/')) {
    final rest = s.substring('$kFlashcardStorageRootSegment/'.length);
    if (rest.contains('/') || rest.contains('..')) return '';
    return rest;
  }
  return flashcardSanitizeBareFilename(s);
}

/// Evita chamadas repetidas a [getDownloadURL] para o mesmo path no Storage
/// (vários widgets / rebuilds na mesma sessão).
final Map<String, String> _flashcardResolvedStorageUrlCache = {};
final Map<String, Future<String>> _flashcardStorageUrlInFlight = {};

/// Retorna URL de download para exibir o card (Storage ou URL já absoluta).
Future<String> getFlashcardImageDownloadUrl(String imageId) async {
  final migrated = flashcardMigrateImageFieldToStorageRef(imageId);
  if (migrated.isEmpty) {
    if (kDebugMode) {
      debugPrint('[imagenscard] invalid image id: "$imageId"');
    }
    throw StateError('Identificador de imagem vazio ou inválido.');
  }
  if (migrated.startsWith('http://') || migrated.startsWith('https://')) {
    return migrated;
  }
  final cached = _flashcardResolvedStorageUrlCache[migrated];
  if (cached != null) {
    return cached;
  }
  final inFlight = _flashcardStorageUrlInFlight[migrated];
  if (inFlight != null) {
    return inFlight;
  }
  final future = () async {
    try {
      final ref = FirebaseStorage.instance.ref(migrated);
      final url = await ref.getDownloadURL();
      _flashcardResolvedStorageUrlCache[migrated] = url;
      return url;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[imagenscard] getDownloadURL failed for "$migrated": $e\n$st',
        );
      }
      rethrow;
    } finally {
      _flashcardStorageUrlInFlight.remove(migrated);
    }
  }();
  _flashcardStorageUrlInFlight[migrated] = future;
  return future;
}

/// Converte tag `[img:…]` em ref de Storage (`imagenscard/...`) ou mantém URL.
///
/// Histórico: devolvia path em `assets/...` — migrado para Firebase Storage.
String flashcardImgTagToStorageRef(String inner) {
  final t = inner.trim().replaceAll(r'\', '/');
  if (t.isEmpty) {
    return '$kFlashcardStorageRootSegment/_invalid.png';
  }
  if (t.startsWith('http://') || t.startsWith('https://')) {
    return t;
  }
  final migrated = flashcardMigrateImageFieldToStorageRef(t);
  return migrated.isEmpty
      ? '$kFlashcardStorageRootSegment/_invalid.png'
      : migrated;
}

/// Alias legado (nome antigo). Preferir [flashcardImgTagToStorageRef].
String flashcardImgTagToAssetPath(String inner) =>
    flashcardImgTagToStorageRef(inner);

String flashcardImagemCardAssetPath(String nomeArquivo) {
  final n = flashcardSanitizeNomeArquivo(nomeArquivo);
  if (n.isEmpty) return pastaImagensCard;
  return '$pastaImagensCard$n';
}

final Map<String, Future<String>> _resolvePathMemo = {};

/// Legado: resolve path no bundle via AssetManifest (antes do Storage).
Future<String> resolveImagensCardBundledAssetPath(String? nomeRaw) async {
  final nome = flashcardSanitizeNomeArquivo(nomeRaw);
  if (nome.isEmpty) return pastaImagensCard;
  return _resolvePathMemo.putIfAbsent(nome, () async {
    try {
      final raw = await rootBundle.loadString('AssetManifest.json');
      final map = json.decode(raw) as Map<String, dynamic>;
      final target = '${pastaImagensCard.toLowerCase()}${nome.toLowerCase()}';
      for (final k in map.keys) {
        if (k.toLowerCase() == target) return k;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Imagenscard] AssetManifest falhou (legado): $e');
      }
    }
    return flashcardImagemCardAssetPath(nome);
  });
}

bool _slotImagemCardIdValido(String? raw) {
  final t = (raw ?? '').trim();
  if (t.isEmpty) return false;
  if (t.contains('..')) return false;
  if (t.startsWith('http://') || t.startsWith('https://')) return true;
  final migrated = flashcardMigrateImageFieldToStorageRef(t);
  return migrated.isNotEmpty;
}

/// Imagem da pergunta (identificador no Firestore → URL no Storage).
/// [studyFullscreenTap]: na tela de estudo, toque abre [FullScreenImagePage].
Widget buildImagemPergunta(
  String? imagemPerguntaLocal, {
  double? height,
  bool studyFullscreenTap = false,
}) {
  return _StorageImagemCardSlot(
    nomeArquivo: imagemPerguntaLocal,
    height: height,
    openFullscreenOnTap: studyFullscreenTap,
  );
}

/// Imagem da resposta.
Widget buildImagemResposta(
  String? imagemRespostaLocal, {
  double? height,
  bool studyFullscreenTap = false,
}) {
  return _StorageImagemCardSlot(
    nomeArquivo: imagemRespostaLocal,
    height: height,
    openFullscreenOnTap: studyFullscreenTap,
  );
}

/// Imagem da explicação.
Widget buildImagemExplicacao(
  String? imagemExplicacaoLocal, {
  double? height,
  bool studyFullscreenTap = false,
}) {
  return _StorageImagemCardSlot(
    nomeArquivo: imagemExplicacaoLocal,
    height: height,
    openFullscreenOnTap: studyFullscreenTap,
  );
}

/// Miniatura do card com [CachedNetworkImage] (cache em disco via flutter_cache_manager).
class _FlashcardSlotCachedImage extends StatelessWidget {
  final String imageUrl;
  final double height;
  final bool openFullscreenOnTap;

  const _FlashcardSlotCachedImage({
    required this.imageUrl,
    required this.height,
    required this.openFullscreenOnTap,
  });

  @override
  Widget build(BuildContext context) {
    final memH = height.isFinite ? height.round().clamp(80, 1200) : null;

    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      height: height,
      fit: BoxFit.contain,
      fadeInDuration: const Duration(milliseconds: 150),
      memCacheHeight: memH,
      placeholder: (context, _) => SizedBox(
        height: height,
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        if (kDebugMode) {
          debugPrint('[imagenscard/Storage] CachedNetworkImage slot: $error');
        }
        return SizedBox(
          height: height,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.grey.shade700,
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Imagem indisponível (sem rede ou erro)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kFlashcardMissingAssetMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!openFullscreenOnTap) {
      return image;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FullScreenImagePage(imageUrl: imageUrl),
            ),
          );
        },
        child: Semantics(
          label: 'Ampliar imagem',
          button: true,
          child: image,
        ),
      ),
    );
  }
}

class _StorageImagemCardSlot extends StatefulWidget {
  final String? nomeArquivo;
  final double? height;
  final bool openFullscreenOnTap;

  const _StorageImagemCardSlot({
    required this.nomeArquivo,
    this.height,
    this.openFullscreenOnTap = false,
  });

  @override
  State<_StorageImagemCardSlot> createState() => _StorageImagemCardSlotState();
}

class _StorageImagemCardSlotState extends State<_StorageImagemCardSlot> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  @override
  void didUpdateWidget(covariant _StorageImagemCardSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nomeArquivo != widget.nomeArquivo) {
      _future = _resolve();
    }
  }

  Future<String> _resolve() {
    final id = (widget.nomeArquivo ?? '').trim();
    if (!_slotImagemCardIdValido(id)) {
      return Future.error(StateError('invalid image id'));
    }
    return getFlashcardImageDownloadUrl(id);
  }

  @override
  Widget build(BuildContext context) {
    if (!_slotImagemCardIdValido(widget.nomeArquivo)) {
      return const SizedBox.shrink();
    }

    final h = widget.height ?? 180;

    return FutureBuilder<String>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            height: h,
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          if (kDebugMode) {
            debugPrint(
              '[imagenscard] FutureBuilder error for "${widget.nomeArquivo}": ${snapshot.error}',
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Text(
              kFlashcardMissingAssetMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          );
        }
        final url = snapshot.data!;
        // Cache em disco: [CachedNetworkImage] + toque opcional para fullscreen na tela de estudo.
        return _FlashcardSlotCachedImage(
          imageUrl: url,
          height: h,
          openFullscreenOnTap: widget.openFullscreenOnTap,
        );
      },
    );
  }
}

/// Legado: só `assets/images/...` eram considerados válidos para embed Quill.
bool isFlashcardAssetPath(String? path) {
  if (path == null) return false;
  final p = path.trim();
  if (p.isEmpty) return false;
  final lower = p.toLowerCase();
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('gs://')) {
    return false;
  }
  return p.startsWith('assets/images/');
}

/// Exibe imagem de embed (Quill) via Storage / URL.
Widget buildFlashcardImage(String? imagemLocal, {double? height}) {
  final p = imagemLocal?.trim() ?? '';
  if (p.isEmpty) return const SizedBox.shrink();
  // MIGRADO: antes `Image.asset` + [isFlashcardAssetPath] (só assets locais).
  return _StorageImagemCardSlot(nomeArquivo: p, height: height);
}

/// Embeds Quill com `insert.image` — ref Storage ou URL.
Widget buildDeltaFlashcardImage(String imageRef) {
  return buildFlashcardImage(imageRef.trim());
}

Future<List<String>> loadFlashcardWebpPathsFromManifest() async {
  try {
    final raw = await rootBundle.loadString('AssetManifest.json');
    final map = json.decode(raw) as Map<String, dynamic>;
    return map.keys
        .where(
          (k) =>
              k.startsWith('assets/images/') &&
              k.toLowerCase().endsWith('.webp'),
        )
        .toList()
      ..sort();
  } catch (_) {
    return const [];
  }
}

Future<void> precacheFlashcardImages(
  BuildContext context,
  List<String> paths,
) async {
  for (final path in paths) {
    if (!context.mounted) return;
    if (!isFlashcardAssetPath(path)) continue;
    try {
      await precacheImage(AssetImage(path.trim()), context);
    } catch (_) {}
  }
}

/// Legado: pré-carregava `.webp` do bundle. Com Storage, não há pré-cache global.
Future<void> precacheAllBundledFlashcardImages(BuildContext context) async {
  /* MIGRADO para Firebase Storage — imagens de card não vêm mais do bundle.
  final paths = await loadFlashcardWebpPathsFromManifest();
  if (!context.mounted) return;
  await precacheFlashcardImages(context, paths);
  */
  await Future<void>.value();
}

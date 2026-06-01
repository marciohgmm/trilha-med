import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'flashcard_storage_upload_stub.dart'
    if (dart.library.io) 'flashcard_storage_upload_io.dart' as impl;

Future<void> uploadFlashcardPickedFile(Reference ref, PlatformFile f) =>
    impl.uploadFlashcardPickedFile(ref, f);

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/l10n/l10n.dart';
import '../core/network/file_upload_helper.dart';

/// What a place accepts. Each kind opens the matching picker: images → gallery or camera,
/// video → the video picker (gallery or camera), audio → the audio picker, documents → the
/// document picker (with the accepted extensions), any → every file.
enum PickKind { image, video, audio, document, any }

/// Office / PDF documents the server accepts as documents.
const documentExtensions = ['pdf', 'docx', 'pptx', 'xlsx'];

typedef PickedFile = ({String path, String name});

/// Lets the member choose the kind of file first and opens the right picker for it. With one
/// kind and no camera option the picker opens directly. Large files are not copied into memory
/// (only their path is returned; the upload streams from disk).
Future<PickedFile?> pickTypedFile(BuildContext context, {Set<PickKind> kinds = const {PickKind.image, PickKind.document}, List<String> documents = documentExtensions}) async {
  final l = context.l10n;
  final options = <(String, IconData, String)>[
    if (kinds.contains(PickKind.image)) ...[('gallery', Icons.photo_library_outlined, l.pickGallery), ('camera', Icons.photo_camera_outlined, l.pickCamera)],
    if (kinds.contains(PickKind.video)) ...[('video', Icons.video_library_outlined, l.pickVideo), ('record', Icons.videocam_outlined, l.pickRecordVideo)],
    if (kinds.contains(PickKind.audio)) ('audio', Icons.audiotrack_rounded, l.pickAudio),
    if (kinds.contains(PickKind.document)) ('document', Icons.description_outlined, l.pickDocument),
    if (kinds.contains(PickKind.any)) ('any', Icons.attach_file_rounded, l.pickAnyFile),
  ];
  final choice = options.length == 1
      ? options.first.$1
      : await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (ctx) => SafeArea(
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final (key, icon, label) in options) ListTile(key: ValueKey('pick-$key'), leading: Icon(icon), title: Text(label), onTap: () => Navigator.pop(ctx, key)),
              ]),
            ),
          ),
        );
  if (choice == null) return null;
  return pickOfKind(choice, documents: documents);
}

/// Opens one picker directly (also used when a screen shows its own choice of kinds).
Future<PickedFile?> pickOfKind(String choice, {List<String> documents = documentExtensions}) async {
  final picker = ImagePicker();
  switch (choice) {
    case 'gallery':
    case 'camera':
      final x = await picker.pickImage(source: choice == 'gallery' ? ImageSource.gallery : ImageSource.camera, maxWidth: 1600, maxHeight: 1600, imageQuality: 78);
      if (x == null) return null;
      if (kIsWeb) {
        final bytes = await x.readAsBytes();
        final path = 'web_upload_${DateTime.now().millisecondsSinceEpoch}_${x.name}';
        registerUploadBytes(path, bytes);
        registerUploadBytes(x.path, bytes);
        return (path: path, name: x.name);
      }
      return (path: x.path, name: x.name);
    case 'video':
    case 'record':
      final x = await picker.pickVideo(source: choice == 'video' ? ImageSource.gallery : ImageSource.camera);
      if (x == null) return null;
      if (kIsWeb) {
        final bytes = await x.readAsBytes();
        final path = 'web_upload_${DateTime.now().millisecondsSinceEpoch}_${x.name}';
        registerUploadBytes(path, bytes);
        registerUploadBytes(x.path, bytes);
        return (path: path, name: x.name);
      }
      return (path: x.path, name: x.name);
  }
  final res = await FilePicker.pickFiles(
    type: switch (choice) {
      'audio' => FileType.audio,
      'document' => FileType.custom,
      _ => FileType.any,
    },
    allowedExtensions: choice == 'document' ? documents : null,
  );
  if (res.isEmpty) return null;
  final f = res.first;
  final fileName = f.name;
  final filePath = f.path;
  if (kIsWeb || filePath == null) {
    final bytes = await f.readAsBytes();
    final path = 'web_upload_${DateTime.now().millisecondsSinceEpoch}_$fileName';
    registerUploadBytes(path, bytes);
    return (path: path, name: fileName);
  }
  return (path: filePath, name: fileName);
}

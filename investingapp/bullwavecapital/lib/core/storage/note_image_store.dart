import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Stores journal photos on this device. They are not uploaded to the notes API.
class NoteImageStore {
  NoteImageStore._();

  static const maxImages = 4;

  static Future<String> persist(Uint8List bytes) async {
    final jpeg = _compress(bytes);
    if (kIsWeb) {
      return 'data:image/jpeg;base64,${base64Encode(jpeg)}';
    }
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/note_images');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final file = File(
      '${folder.path}/${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(jpeg, flush: true);
    return file.path;
  }

  static Uint8List _compress(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final resized =
        decoded.width > 720 ? img.copyResize(decoded, width: 720) : decoded;
    return Uint8List.fromList(img.encodeJpg(resized, quality: 55));
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NoteAttachedImage extends StatelessWidget {
  final String source;
  final BoxFit fit;

  const NoteAttachedImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('data:')) {
      final comma = source.indexOf(',');
      final b64 = comma >= 0 ? source.substring(comma + 1) : source;
      try {
        return Image.memory(
          base64Decode(b64),
          fit: fit,
          gaplessPlayback: true,
        );
      } catch (_) {
        return const Icon(Icons.broken_image_outlined);
      }
    }
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Image.network(source, fit: fit);
    }
    if (!kIsWeb && source.isNotEmpty) {
      return Image.file(
        File(source),
        fit: fit,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
      );
    }
    return const Icon(Icons.image_outlined);
  }
}

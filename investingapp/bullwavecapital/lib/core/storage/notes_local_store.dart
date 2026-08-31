import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/trader_note_model.dart';

/// Device cache so the journal still works when the API/RDS is down.
class NotesLocalStore {
  NotesLocalStore._();

  static const _key = 'trader_notes_v1';

  static Future<List<TraderNoteModel>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic>) TraderNoteModel.fromJson(item)
          else if (item is Map) TraderNoteModel.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> write(List<TraderNoteModel> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final note in notes) note.toJson()]),
    );
  }
}

import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../core/storage/notes_local_store.dart';
import '../../../../models/trader_note_model.dart';

class NotesProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  List<TraderNoteModel> _notes = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String? _categoryFilter;
  bool _offline = false;

  List<TraderNoteModel> get notes {
    var list = _notes;
    final category = _categoryFilter;
    if (category != null && category.isNotEmpty) {
      list = list.where((n) => n.category == category).toList();
    }
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (n) =>
                n.title.toLowerCase().contains(q) ||
                n.body.toLowerCase().contains(q) ||
                n.symbol.toLowerCase().contains(q),
          )
          .toList();
    }
    return List.unmodifiable(list);
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String? get categoryFilter => _categoryFilter;
  bool get isOffline => _offline;

  List<TraderNoteModel> get pinnedNotes =>
      notes.where((n) => n.isPinned).toList();

  Future<void> load({String? category, String? search}) async {
    if (category != null) _categoryFilter = category.isEmpty ? null : category;
    if (search != null) _searchQuery = search;

    _isLoading = _notes.isEmpty;
    notifyListeners();

    final cached = await NotesLocalStore.read();
    if (cached.isNotEmpty) {
      _notes = _sorted(cached);
      _isLoading = false;
      notifyListeners();
    }

    try {
      final remote = await _api.getTraderNotes();
      _notes = _sorted(_mergeRemote(remote, _notes));
      _error = null;
      _offline = false;
      await _flushPending();
      await NotesLocalStore.write(_notes);
    } on ApiException catch (e) {
      _offline = true;
      _error = cached.isEmpty && _notes.isEmpty ? _friendlySyncError(e.message) : null;
    } catch (_) {
      _offline = true;
      _error = cached.isEmpty && _notes.isEmpty
          ? 'Could not sync notes. You can still write notes on this device.'
          : null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => load();

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  void setCategoryFilter(String? category) {
    _categoryFilter = category;
    notifyListeners();
  }

  Future<TraderNoteModel?> saveNote({
    String? id,
    required String title,
    required String body,
    String symbol = '',
    String category = 'general',
    bool isPinned = false,
  }) async {
    final now = DateTime.now();
    TraderNoteModel? existing;
    if (id != null && id.isNotEmpty) {
      for (final note in _notes) {
        if (note.id == id) {
          existing = note;
          break;
        }
      }
    }
    final localId = (id == null || id.isEmpty) ? _newLocalId() : id;
    var draft = TraderNoteModel(
      id: localId,
      title: title,
      body: body,
      symbol: symbol,
      category: category,
      isPinned: isPinned,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      pendingSync: true,
    );
    _upsert(draft);
    await NotesLocalStore.write(_notes);
    notifyListeners();

    try {
      final TraderNoteModel saved;
      if (existing == null || localId.startsWith('local-')) {
        saved = await _api.createTraderNote(
          title: title,
          body: body,
          symbol: symbol,
          category: category,
          isPinned: isPinned,
        );
      } else {
        saved = await _api.updateTraderNote(
          localId,
          title: title,
          body: body,
          symbol: symbol,
          category: category,
          isPinned: isPinned,
        );
      }
      _replace(draft.id, saved.copyWith(pendingSync: false));
      _error = null;
      _offline = false;
      await NotesLocalStore.write(_notes);
      notifyListeners();
      return saved;
    } on ApiException {
      _offline = true;
      _error = null;
      notifyListeners();
      return draft;
    } catch (_) {
      _offline = true;
      _error = null;
      notifyListeners();
      return draft;
    }
  }

  Future<bool> togglePin(TraderNoteModel note) async {
    final updated = await saveNote(
      id: note.id,
      title: note.title,
      body: note.body,
      symbol: note.symbol,
      category: note.category,
      isPinned: !note.isPinned,
    );
    return updated != null;
  }

  Future<bool> deleteNote(String id) async {
    _notes = _notes.where((n) => n.id != id).toList();
    await NotesLocalStore.write(_notes);
    notifyListeners();
    if (id.startsWith('local-')) return true;
    try {
      await _api.deleteTraderNote(id);
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _flushPending() async {
    final pending = _notes.where((n) => n.isLocalOnly || n.pendingSync).toList();
    for (final note in pending) {
      try {
        final TraderNoteModel saved;
        if (note.isLocalOnly) {
          saved = await _api.createTraderNote(
            title: note.title,
            body: note.body,
            symbol: note.symbol,
            category: note.category,
            isPinned: note.isPinned,
          );
        } else {
          saved = await _api.updateTraderNote(
            note.id,
            title: note.title,
            body: note.body,
            symbol: note.symbol,
            category: note.category,
            isPinned: note.isPinned,
          );
        }
        _replace(note.id, saved.copyWith(pendingSync: false));
      } catch (_) {
        _offline = true;
        return;
      }
    }
  }

  void _upsert(TraderNoteModel note) {
    final idx = _notes.indexWhere((n) => n.id == note.id);
    if (idx >= 0) {
      _notes = [..._notes]..[idx] = note;
    } else {
      _notes = [note, ..._notes];
    }
    _notes = _sorted(_notes);
  }

  void _replace(String oldId, TraderNoteModel note) {
    _notes = [
      for (final n in _notes)
        if (n.id == oldId) note else n,
    ];
    if (!_notes.any((n) => n.id == note.id)) {
      _notes = [note, ..._notes];
    }
    _notes = _sorted(_notes);
  }

  List<TraderNoteModel> _mergeRemote(
    List<TraderNoteModel> remote,
    List<TraderNoteModel> local,
  ) {
    final seen = <String>{};
    final merged = <TraderNoteModel>[];
    for (final note in local) {
      if (note.isLocalOnly || note.pendingSync) {
        merged.add(note);
        seen.add(note.id);
      }
    }
    for (final note in remote) {
      if (seen.contains(note.id)) continue;
      merged.add(note.copyWith(pendingSync: false));
      seen.add(note.id);
    }
    return merged;
  }

  List<TraderNoteModel> _sorted(List<TraderNoteModel> notes) {
    final copy = [...notes];
    copy.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return copy;
  }

  String _newLocalId() {
    final token = Random().nextInt(1 << 32).toRadixString(16);
    return 'local-${DateTime.now().microsecondsSinceEpoch}-$token';
  }

  String _friendlySyncError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('temporarily unavailable') ||
        lower.contains('server error') ||
        lower.contains('database') ||
        lower.contains('busy')) {
      return 'Could not sync notes. You can still write notes on this device.';
    }
    return message;
  }
}

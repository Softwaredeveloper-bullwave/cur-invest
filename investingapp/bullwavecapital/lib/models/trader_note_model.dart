class TraderNoteModel {
  final String id;
  final String title;
  final String body;
  final String symbol;
  final String category;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool pendingSync;

  const TraderNoteModel({
    required this.id,
    required this.title,
    required this.body,
    required this.symbol,
    required this.category,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
    this.pendingSync = false,
  });

  bool get isLocalOnly => id.startsWith('local-');

  TraderNoteModel copyWith({
    String? id,
    String? title,
    String? body,
    String? symbol,
    String? category,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? pendingSync,
  }) {
    return TraderNoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      symbol: symbol ?? this.symbol,
      category: category ?? this.category,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'symbol': symbol,
        'category': category,
        'isPinned': isPinned,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'pendingSync': pendingSync,
      };

  factory TraderNoteModel.fromJson(Map<String, dynamic> json) {
    bool asBool(dynamic v) => v == true || v == 'true' || v == 1;
    DateTime asDate(dynamic v) {
      if (v is DateTime) return v;
      return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    }

    return TraderNoteModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      symbol: (json['symbol'] as String? ?? '').toUpperCase(),
      category: json['category'] as String? ?? 'general',
      isPinned: asBool(json['isPinned'] ?? json['is_pinned']),
      createdAt: asDate(json['createdAt'] ?? json['created_at']),
      updatedAt: asDate(json['updatedAt'] ?? json['updated_at']),
      pendingSync: asBool(json['pendingSync'] ?? json['pending_sync']),
    );
  }

  String get preview {
    final text = body.trim();
    if (text.isEmpty) return 'No content yet';
    return text.length > 120 ? '${text.substring(0, 120)}…' : text;
  }

  String get categoryLabel {
    switch (category) {
      case 'stock':
        return 'Stock';
      case 'trade_idea':
        return 'Trade Idea';
      case 'journal':
        return 'Journal';
      default:
        return 'General';
    }
  }
}

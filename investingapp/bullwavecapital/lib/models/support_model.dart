class SupportTicketMessageModel {
  final String id;
  final String authorRole;
  final String authorName;
  final String body;
  final DateTime createdAt;

  const SupportTicketMessageModel({
    required this.id,
    required this.authorRole,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });
}

class SupportTicketModel {
  final String id;
  final String subject;
  final String status;
  final String message;
  final String resolutionNote;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;
  final List<SupportTicketMessageModel> messages;

  const SupportTicketModel({
    required this.id,
    required this.subject,
    required this.status,
    required this.message,
    required this.resolutionNote,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
    this.messages = const [],
  });
}

class SupportFaq {
  final String question;
  final String answer;

  const SupportFaq({required this.question, required this.answer});
}

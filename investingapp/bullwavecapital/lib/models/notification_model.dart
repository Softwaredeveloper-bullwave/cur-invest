class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime date;
  final bool isRead;
  final String type;
  final String referenceId;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.date,
    required this.isRead,
    required this.type,
    this.referenceId = '',
  });

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        id: id,
        title: title,
        message: message,
        date: date,
        isRead: isRead ?? this.isRead,
        type: type,
        referenceId: referenceId,
      );
}

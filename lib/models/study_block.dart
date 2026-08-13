class StudyBlock {
  final String id;
  final String subject;
  final DateTime startTime;
  final DateTime endTime;
  String status; // 'Pendente', 'Em Andamento', 'Concluído'

  StudyBlock({
    required this.id,
    required this.subject,
    required this.startTime,
    required this.endTime,
    this.status = 'Pendente',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'status': status,
      };

  factory StudyBlock.fromJson(Map<String, dynamic> json) => StudyBlock(
        id: json['id'],
        subject: json['subject'],
        startTime: DateTime.parse(json['startTime']),
        endTime: DateTime.parse(json['endTime']),
        status: json['status'],
      );
}

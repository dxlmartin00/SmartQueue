class Transaction {
  final String id;
  final String ticketNumber;
  final String serviceId;
  final String serviceName;
  final String userId;
  final String userName;
  final String userEmail;
  final String status;
  final DateTime queueDate;
  final DateTime createdAt;
  final DateTime? timeCalled;
  final DateTime? finishedAt;
  final int? waitTimeMinutes;
  final int? serviceTimeMinutes;

  Transaction({
    required this.id,
    required this.ticketNumber,
    required this.serviceId,
    required this.serviceName,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.status,
    required this.queueDate,
    required this.createdAt,
    this.timeCalled,
    this.finishedAt,
    this.waitTimeMinutes,
    this.serviceTimeMinutes,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    // Calculate wait time (from creation to being called)
    int? waitTime;
    if (json['time_called'] != null) {
      final created = DateTime.parse(json['created_at']);
      final called = DateTime.parse(json['time_called']);
      waitTime = called.difference(created).inMinutes;
    }

    // Calculate service time (from being called to finished)
    int? serviceTime;
    if (json['finished_at'] != null && json['time_called'] != null) {
      final called = DateTime.parse(json['time_called']);
      final finished = DateTime.parse(json['finished_at']);
      serviceTime = finished.difference(called).inMinutes;
    }

    return Transaction(
      id: json['id'],
      ticketNumber: json['ticket_number'],
      serviceId: json['service_id'],
      serviceName: json['services']?['name'] ?? 'Unknown Service',
      userId: json['user_id'],
      userName: json['profiles']?['full_name'] ?? 'Unknown User',
      userEmail: json['profiles']?['email'] ?? '',
      status: json['status'],
      queueDate: DateTime.parse(json['queue_date']),
      createdAt: DateTime.parse(json['created_at']),
      timeCalled: json['time_called'] != null
          ? DateTime.parse(json['time_called'])
          : null,
      finishedAt: json['finished_at'] != null
          ? DateTime.parse(json['finished_at'])
          : null,
      waitTimeMinutes: waitTime,
      serviceTimeMinutes: serviceTime,
    );
  }
}

class QueueTicket {
  final String id;
  final String serviceId;
  final String userId;
  final String ticketNumber;
  final String status;
  final DateTime queueDate;
  final DateTime createdAt;
  final DateTime? timeCalled;
  final DateTime? finishedAt;

  QueueTicket({
    required this.id,
    required this.serviceId,
    required this.userId,
    required this.ticketNumber,
    required this.status,
    required this.queueDate,
    required this.createdAt,
    this.timeCalled,
    this.finishedAt,
  });

  factory QueueTicket.fromJson(Map<String, dynamic> json) {
    return QueueTicket(
      id: json['id'],
      serviceId: json['service_id'],
      userId: json['user_id'],
      ticketNumber: json['ticket_number'],
      status: json['status'],
      queueDate: DateTime.parse(json['queue_date']),
      createdAt: DateTime.parse(json['created_at']),
      timeCalled: json['time_called'] != null ? DateTime.parse(json['time_called']) : null,
      finishedAt: json['finished_at'] != null ? DateTime.parse(json['finished_at']) : null,
    );
  }
}

class ServiceStatus {
  final int serviceWindow;  // Changed from 'window' to 'serviceWindow'
  final String? currentNumber;
  final DateTime updatedAt;

  ServiceStatus({
    required this.serviceWindow,  // Changed parameter name
    this.currentNumber, 
    required this.updatedAt
  });

  factory ServiceStatus.fromJson(Map<String, dynamic> json) {
    return ServiceStatus(
      serviceWindow: json['service_window'],  // Changed from 'window' to 'service_window'
      currentNumber: json['current_number'],
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
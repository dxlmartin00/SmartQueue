class Service {
  final String id;
  final String name;
  final int window;

  Service({required this.id, required this.name, required this.window});

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'],
      name: json['name'],
      window: json['service_window'],
    );
  }
}
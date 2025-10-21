// lib/models/booking.dart

class Booking {
  final int id;
  final String organization;
  final String contactPerson;
  final String designation;
  final String phone;
  final String whatsapp;
  final String serviceRequired;
  final String preferredTopic;
  final String medium;
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.organization,
    required this.contactPerson,
    required this.designation,
    required this.phone,
    required this.whatsapp,
    required this.serviceRequired,
    required this.preferredTopic,
    required this.medium,
    required this.createdAt,
  });

  // Factory constructor to create a Booking object from JSON
  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as int,
      organization: json['organization'] as String,
      contactPerson: json['contact_person'] as String,
      designation: json['designation'] as String,
      phone: json['phone'] as String,
      whatsapp: json['whatsapp'] as String,
      serviceRequired: json['service_required'] as String,
      preferredTopic: json['preferred_topic'] as String,
      medium: json['medium'] as String,
      // Parse the date string, handle potential errors by providing a fallback
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])?.toLocal() ??
                DateTime.now().toLocal()
          : DateTime.now().toLocal(),
    );
  }
}

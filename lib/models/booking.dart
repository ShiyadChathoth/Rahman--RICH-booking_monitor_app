// lib/models/booking.dart

import 'package:intl/intl.dart';

class Booking {
  final int id;
  final String organization;
  final String contactPerson;
  final String designation;
  final String phone;
  final String whatsapp;
  final String email; // <--- ADDED FIELD
  final String serviceRequired;
  final String preferredTopic;
  final String medium;
  final DateTime createdAt;
  final DateTime? programDate;
  final String venue;
  final bool isConfirmed; // <--- ADDED STATUS FIELD

  Booking({
    required this.id,
    required this.organization,
    required this.contactPerson,
    required this.designation,
    required this.phone,
    required this.whatsapp,
    required this.email, // <--- ADDED TO CONSTRUCTOR
    required this.serviceRequired,
    required this.preferredTopic,
    required this.medium,
    required this.createdAt,
    this.programDate,
    required this.venue,
    required this.isConfirmed, // <--- ADDED TO CONSTRUCTOR
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? dateString) {
      if (dateString == null || dateString.isEmpty) return null;
      try {
        return DateFormat('yyyy-MM-dd').parse(dateString);
      } catch (e) {
        try {
          return DateTime.tryParse(dateString)?.toLocal();
        } catch (_) {
          return null;
        }
      }
    }

    // Safely parse integer 0/1 (from DB) to boolean. Default to false if null.
    final int? confirmedInt = json['is_confirmed'] as int?;
    final bool isConfirmedStatus = confirmedInt == 1;

    return Booking(
      id: json['id'] as int? ?? 0,
      organization: json['organization'] as String? ?? '',
      contactPerson: json['contact_person'] as String? ?? '',
      designation: json['designation'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      whatsapp: json['whatsapp'] as String? ?? '',
      email: json['email'] as String? ?? '', // <--- PARSE FROM JSON
      serviceRequired: json['service_required'] as String? ?? '',
      preferredTopic: json['preferred_topic'] as String? ?? '',
      medium: json['medium'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])?.toLocal() ??
                DateTime.now().toLocal()
          : DateTime.now().toLocal(),
      programDate: parseDate(json['program_date'] as String?),
      venue: json['venue'] as String? ?? '',
      isConfirmed: isConfirmedStatus, // <--- READ STATUS FROM JSON
    );
  }
}

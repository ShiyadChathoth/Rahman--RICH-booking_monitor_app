// lib/models/booking.dart - UPDATED CODE

import 'package:intl/intl.dart'; // Import intl for date parsing

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
  final DateTime createdAt; // This corresponds to 'booking_date'
  final DateTime? programDate; // Added field (nullable)
  final String venue; // Added field

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
    this.programDate, // Updated constructor
    required this.venue, // Updated constructor
  });

  // Factory constructor to create a Booking object from JSON
  factory Booking.fromJson(Map<String, dynamic> json) {
    // Helper function to parse dates safely
    DateTime? parseDate(String? dateString) {
      if (dateString == null || dateString.isEmpty) return null;
      try {
        // Assuming date is in 'YYYY-MM-DD' format from the form/DB
        return DateFormat('yyyy-MM-dd').parse(dateString);
      } catch (e) {
        print("Error parsing date '$dateString': $e");
        // Fallback or alternative parsing if needed
        try {
          // Try parsing as ISO 8601 if the format is different
          return DateTime.tryParse(dateString)?.toLocal();
        } catch (_) {
          return null; // Return null if parsing fails
        }
      }
    }

    return Booking(
      id: json['id'] as int? ?? 0, // Provide default if null
      organization: json['organization'] as String? ?? '', // Provide default
      contactPerson: json['contact_person'] as String? ?? '', // Provide default
      designation: json['designation'] as String? ?? '', // Provide default
      phone: json['phone'] as String? ?? '', // Provide default
      whatsapp: json['whatsapp'] as String? ?? '', // Provide default
      serviceRequired:
          json['service_required'] as String? ?? '', // Provide default
      preferredTopic:
          json['preferred_topic'] as String? ?? '', // Provide default
      medium: json['medium'] as String? ?? '', // Provide default
      // Parse 'created_at' for booking_date
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])?.toLocal() ??
                DateTime.now().toLocal()
          : DateTime.now().toLocal(),
      // Parse 'program_date'
      programDate: parseDate(json['program_date'] as String?), // Updated field
      venue: json['venue'] as String? ?? '', // Updated field
    );
  }
}

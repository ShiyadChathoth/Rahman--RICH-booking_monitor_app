import 'package:intl/intl.dart';

class Booking {
  final int id;
  final String organization;
  final String contactPerson;
  final String designation;
  final String phone;
  final String whatsapp;
  final String email;
  final String serviceRequired;
  final String preferredTopic;
  final String medium;
  final DateTime
  createdAt; // Keep the property name as createdAt for consistency in the app
  final DateTime? programDate;
  final String venue;
  final bool isConfirmed;

  Booking({
    required this.id,
    required this.organization,
    required this.contactPerson,
    required this.designation,
    required this.phone,
    required this.whatsapp,
    required this.email,
    required this.serviceRequired,
    required this.preferredTopic,
    required this.medium,
    required this.createdAt, // Property name remains createdAt
    this.programDate,
    required this.venue,
    required this.isConfirmed,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? dateString) {
      if (dateString == null || dateString.isEmpty) return null;
      // First try parsing as full DateTime (which program_date might be)
      try {
        // Attempt to parse ISO8601 or similar formats directly
        return DateTime.tryParse(dateString)?.toLocal();
      } catch (_) {
        // Fallback to Date only if DateTime parse fails (less likely needed now)
        try {
          return DateFormat('yyyy-MM-dd').parse(dateString);
        } catch (e) {
          print("Error parsing program_date '$dateString': $e");
          return null;
        }
      }
    }

    final int? confirmedInt = json['is_confirmed'] as int?;
    final bool isConfirmedStatus = confirmedInt == 1;

    // ---- MODIFICATION START ----
    // Use 'booking_date' from JSON to populate the 'createdAt' property
    final String? bookingDateString = json['booking_date'] as String?;
    print("Received booking_date string: $bookingDateString"); // Debug print

    final DateTime parsedCreatedAt = bookingDateString != null
        ? DateTime.tryParse(bookingDateString)?.toLocal() ??
              DateTime.now().toLocal()
        : DateTime.now().toLocal();
    // ---- MODIFICATION END ----

    return Booking(
      id: json['id'] as int? ?? 0,
      organization: json['organization'] as String? ?? '',
      contactPerson: json['contact_person'] as String? ?? '',
      designation: json['designation'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      whatsapp: json['whatsapp'] as String? ?? '',
      email: json['email'] as String? ?? '',
      serviceRequired: json['service_required'] as String? ?? '',
      preferredTopic: json['preferred_topic'] as String? ?? '',
      medium: json['medium'] as String? ?? '',
      // Assign the parsed value using the correct JSON key to the createdAt property
      createdAt: parsedCreatedAt,
      programDate: parseDate(json['program_date'] as String?),
      venue: json['venue'] as String? ?? '',
      isConfirmed: isConfirmedStatus,
    );
  }
}

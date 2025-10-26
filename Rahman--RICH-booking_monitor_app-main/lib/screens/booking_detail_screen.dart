// lib/screens/booking_detail_screen.dart - ADDED LOGGING

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // For json.decode
import '../models/booking.dart';

class BookingDetailScreen extends StatelessWidget {
  final Booking booking;
  final VoidCallback onBookingDeleted;

  const BookingDetailScreen({
    super.key,
    required this.booking,
    required this.onBookingDeleted,
  });

  // --- Ensure this is the CORRECT public HTTPS URL ---
  final String _serverUrl = "https://pi-monitor.tailb72c55.ts.net";
  // --------------------------------------------------

  Future<void> _makeCall(BuildContext context, String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch dialler for $phoneNumber')),
        );
        print('Could not launch $launchUri');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error trying to make call: $e')));
      print('Error launching call URL: $e');
    }
  }

  Future<void> _openWhatsApp(
    BuildContext context,
    String whatsappNumber,
  ) async {
    // Clean and format number
    String cleanedNumber = whatsappNumber.replaceAll(RegExp(r'\s+|-'), '');
    if (cleanedNumber.startsWith('0')) {
      cleanedNumber = '+91${cleanedNumber.substring(1)}';
    } else if (!cleanedNumber.startsWith('+')) {
      cleanedNumber = '+91$cleanedNumber';
    }
    final Uri launchUri = Uri.parse("https://wa.me/$cleanedNumber");
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open WhatsApp chat with $cleanedNumber'),
          ),
        );
        print('Could not launch $launchUri');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error trying to open WhatsApp: $e')),
      );
      print('Error launching WhatsApp URL: $e');
    }
  }

  // --- Function to delete booking ---
  Future<void> _deleteBooking(BuildContext context) async {
    // Show confirmation dialog
    bool confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Confirm Deletion"),
            content: Text(
              "Are you sure you want to delete the booking from ${booking.organization}? This action cannot be undone.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm || !context.mounted) {
      return;
    }

    // --- ADDED LOGGING: Print the URL before making the request ---
    final deleteUrl = '$_serverUrl/booking/${booking.id}';
    print("--- Attempting DELETE Request ---");
    print("URL: $deleteUrl");
    // -------------------------------------------------------------

    try {
      final response = await http
          .delete(
            Uri.parse(deleteUrl),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              // Add any other necessary headers here (like Authorization if needed)
            },
          )
          .timeout(const Duration(seconds: 20)); // Increased timeout slightly

      if (!context.mounted) return;

      if (response.statusCode == 200) {
        print("--- DELETE Success (Status 200) ---");
        print("Response Body: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Booking from ${booking.organization} deleted successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        onBookingDeleted();
        Navigator.of(context).pop();
      } else {
        // --- ADDED LOGGING: Print status code and raw body on non-200 response ---
        print("--- DELETE Failed (Status ${response.statusCode}) ---");
        print("Raw Response Body:\n${response.body}");
        // -----------------------------------------------------------------------

        // Try to decode error, provide fallback message
        String errorMessage = 'Failed to delete booking.';
        try {
          final errorData = json.decode(
            response.body,
          ); // This might fail if body is HTML
          errorMessage +=
              ' Server said: ${errorData['message'] ?? 'Unknown error'} (Code: ${response.statusCode})';
        } catch (e) {
          // --- ADDED LOGGING: Indicate JSON decoding failed ---
          print("Failed to decode JSON response: $e");
          // -------------------------------------------------
          errorMessage +=
              ' Status code: ${response.statusCode}. Received non-JSON response (possibly HTML error page).';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
          ),
        );
        print('API Error Logged. Status: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      // Catch stack trace as well
      if (!context.mounted) return;
      // --- ADDED LOGGING: Print error and stack trace on exception ---
      print("--- DELETE Network/Exception Error ---");
      print("Error: $e");
      print("StackTrace:\n$stackTrace");
      // -----------------------------------------------------------
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Network error or exception: Could not delete booking. Error: $e',
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      print('Network Error/Exception during DELETE logged.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (rest of the build method remains the same) ...
    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            onPressed: () => _deleteBooking(context),
            tooltip: 'Delete Booking',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  "Organization",
                  booking.organization,
                  Icons.business,
                ),
                _buildDetailRow(
                  "Contact Person",
                  booking.contactPerson,
                  Icons.person,
                ),
                _buildDetailRow("Designation", booking.designation, Icons.work),
                _buildDetailRow(
                  "Service",
                  booking.serviceRequired,
                  Icons.room_service,
                ),
                _buildDetailRow("Topic", booking.preferredTopic, Icons.topic),
                _buildDetailRow(
                  "Medium",
                  booking.medium,
                  Icons.connect_without_contact,
                ),
                _buildDetailRow("Phone", booking.phone, Icons.phone),
                _buildDetailRow("WhatsApp", booking.whatsapp, Icons.message),
                _buildDetailRow(
                  "Received On",
                  // Format date robustly
                  DateFormat.yMMMd().add_jm().format(
                    booking.createdAt.toLocal(),
                  ),
                  Icons.calendar_today,
                ),
                const Divider(height: 30),
                Center(
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _makeCall(context, booking.phone),
                        icon: const Icon(Icons.call),
                        label: const Text("Make a Call"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _openWhatsApp(context, booking.whatsapp),
                        icon: const Icon(Icons.message),
                        label: const Text("Send WhatsApp Message"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Delete button within the card as well (optional)
                      OutlinedButton.icon(
                        onPressed: () => _deleteBooking(context),
                        icon: const Icon(Icons.delete),
                        label: const Text("Delete Booking"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget to build detail rows consistently
  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.indigo[400],
            size: 22,
          ), // Slightly adjusted color/size
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600, // Slightly bolder label
                    fontSize: 13, // Slightly smaller label
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : '-', // Show dash if value is empty
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

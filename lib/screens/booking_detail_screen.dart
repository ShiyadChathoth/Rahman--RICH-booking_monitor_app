// lib/screens/booking_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/booking.dart';

class BookingDetailScreen extends StatelessWidget {
  final Booking booking;
  final VoidCallback onBookingDeleted;
  final VoidCallback onBookingConfirmed; // <--- ADDED CALLBACK

  const BookingDetailScreen({
    super.key,
    required this.booking,
    required this.onBookingDeleted,
    required this.onBookingConfirmed, // <--- ADDED TO CONSTRUCTOR
  });

  final String _serverUrl = "https://pi-monitor.tailb72c55.ts.net";

  // --- Function to make call (Retained) ---
  Future<void> _makeCall(BuildContext context, String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch dialler for $phoneNumber')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error trying to make call: $e')));
    }
  }

  // --- Function to open WhatsApp (Retained) ---
  Future<void> _openWhatsApp(
    BuildContext context,
    String whatsappNumber,
  ) async {
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
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error trying to open WhatsApp: $e')),
      );
    }
  }

  // --- Function to delete booking (Retained) ---
  Future<void> _deleteBooking(BuildContext context) async {
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

    final deleteUrl = '$_serverUrl/booking/${booking.id}';

    try {
      final response = await http
          .delete(
            Uri.parse(deleteUrl),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (!context.mounted) return;

      if (response.statusCode == 200) {
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
        String errorMessage = 'Failed to delete booking.';
        try {
          final errorData = json.decode(response.body);
          errorMessage +=
              ' Server said: ${errorData['message'] ?? 'Unknown error'} (Code: ${response.statusCode})';
        } catch (e) {
          errorMessage +=
              ' Status code: ${response.statusCode}. Received non-JSON response.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Network error or exception: Could not delete booking. Error: $e',
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
  }

  // --- NEW: Function to send confirmation email ---
  Future<void> _sendConfirmationEmail(BuildContext context) async {
    if (booking.isConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking is already confirmed.'),
          backgroundColor: Colors.blueGrey,
        ),
      );
      return;
    }
    if (booking.email.isEmpty || booking.email == '-') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot send confirmation: No valid email provided in the booking.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    bool confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Confirm Booking"),
            content: Text(
              "Are you sure you want to confirm the booking from ${booking.organization} and send the confirmation email to ${booking.email}?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text(
                  "Confirm & Send",
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

    final confirmUrl = '$_serverUrl/confirm-booking/${booking.id}';

    try {
      final response = await http
          .post(
            Uri.parse(confirmUrl),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode({'email': booking.email}),
          )
          .timeout(const Duration(seconds: 20));

      if (!context.mounted) return;

      if (response.statusCode == 200) {
        // Call the callback to refresh the home screen list
        onBookingConfirmed();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Booking confirmed and email sent successfully to ${booking.email}!',
            ),
            backgroundColor: Colors.blue,
          ),
        );
        // Navigate back immediately after successful confirmation
        Navigator.of(context).pop();
      } else {
        String errorMessage = 'Failed to confirm booking.';
        try {
          final errorData = json.decode(response.body);
          errorMessage +=
              ' Server said: ${errorData['message'] ?? 'Unknown error'} (Code: ${response.statusCode})';
        } catch (_) {
          errorMessage += ' Status code: ${response.statusCode}.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Network error: Could not connect to the server or request timed out. Error: $e',
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
  }

  // Helper widget to build detail rows consistently
  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    // Determine the text color for the Status row
    Color statusValueColor = Colors.black87;
    if (label == 'Status') {
      if (value == 'CONFIRMED') {
        statusValueColor = Colors.green.shade700;
      } else if (value == 'PENDING') {
        statusValueColor = Colors.orange.shade700;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: value.isNotEmpty ? onTap : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.indigo[400], size: 22),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value.isNotEmpty ? value : '-',
                    style: TextStyle(
                      fontSize: 16,
                      color: statusValueColor,
                      // Underline only if there's a value AND an onTap action for Email ID
                      decoration:
                          (onTap != null &&
                              value.isNotEmpty &&
                              label == 'Email ID')
                          ? TextDecoration.underline
                          : TextDecoration.none,
                      decorationColor: Colors.blue,
                      fontWeight: label == 'Status'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            // Show the send icon only for the clickable Email ID row
            if (onTap != null && value.isNotEmpty && label == 'Email ID')
              const Padding(
                padding: EdgeInsets.only(left: 8.0, top: 4.0),
                child: Icon(Icons.send, size: 16, color: Colors.blue),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String formattedProgramDate = booking.programDate != null
        ? DateFormat.yMMMd().format(booking.programDate!)
        : 'Not Specified';

    final bool isConfirmed = booking.isConfirmed;
    final bool isEmailAvailable =
        booking.email.isNotEmpty && booking.email != '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking Details"),
        actions: [
          // Conditionally show Confirmation Button in AppBar
          if (!isConfirmed)
            IconButton(
              icon: const Icon(
                Icons.check_circle_outline,
                color: Colors.greenAccent,
              ),
              onPressed: () => _sendConfirmationEmail(context),
              tooltip: 'Confirm Booking & Send Email',
            ),
          // Delete Button (Retained)
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
                // --- NEW: Status Display ---
                _buildDetailRow(
                  "Status",
                  isConfirmed ? "CONFIRMED" : "PENDING",
                  isConfirmed ? Icons.check_circle_outline : Icons.pending,
                ),
                const Divider(height: 10),
                // --- END NEW ---
                _buildDetailRow("Booking ID", booking.id.toString(), Icons.tag),
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
                _buildDetailRow("Phone", booking.phone, Icons.phone),
                _buildDetailRow("WhatsApp", booking.whatsapp, Icons.message),
                // --- ADDED EMAIL DISPLAY ROW ---
                _buildDetailRow(
                  "Email ID",
                  booking.email,
                  Icons.email,
                  onTap: isEmailAvailable
                      ? () => launchUrl(Uri.parse('mailto:${booking.email}'))
                      : null, // Makes the email clickable
                ),
                // --- END ADDED EMAIL DISPLAY ROW ---
                _buildDetailRow(
                  "Service Required",
                  booking.serviceRequired,
                  Icons.room_service,
                ),
                _buildDetailRow(
                  "Preferred Topic",
                  booking.preferredTopic,
                  Icons.topic,
                ),
                _buildDetailRow("Medium", booking.medium, Icons.translate),
                _buildDetailRow("Venue", booking.venue, Icons.location_on),
                _buildDetailRow(
                  "Program Date",
                  formattedProgramDate,
                  Icons.event,
                ),
                _buildDetailRow(
                  "Booking Date",
                  DateFormat.yMMMd().add_jm().format(
                    booking.createdAt.toLocal(),
                  ),
                  Icons.calendar_today,
                ),

                const Divider(height: 30),
                Center(
                  child: Column(
                    children: [
                      // --- NEW: Confirmation Button (Large, conditional) ---
                      if (!isConfirmed)
                        ElevatedButton.icon(
                          onPressed: () => _sendConfirmationEmail(context),
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 24,
                          ),
                          label: const Text("Confirm & Email User"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      if (!isConfirmed)
                        const SizedBox(
                          height: 20,
                        ), // Add spacer only if button is shown
                      // ... (existing call and WhatsApp buttons) ...
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
                      const SizedBox(height: 10),
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
                      // --- Delete Button ---
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
}

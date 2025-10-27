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
  final VoidCallback onBookingConfirmed;

  const BookingDetailScreen({
    super.key,
    required this.booking,
    required this.onBookingDeleted,
    required this.onBookingConfirmed,
  });

  final String _serverUrl = "https://pi-monitor.tailb72c55.ts.net";

  // --- Function to make call ---
  Future<void> _makeCall(BuildContext context, String phoneNumber) async {
    // Return early if phone number is empty
    if (phoneNumber.isEmpty || phoneNumber == '-') {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number provided.')),
      );
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (!context.mounted) return; // Check context before using
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch dialler for $phoneNumber')),
        );
      }
    } catch (e) {
      if (!context.mounted) return; // Check context before using
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error trying to make call: $e')));
    }
  }

  // --- Function to open WhatsApp ---
  Future<void> _openWhatsApp(
    BuildContext context,
    String whatsappNumber,
  ) async {
    // Return early if WhatsApp number is empty
    if (whatsappNumber.isEmpty || whatsappNumber == '-') {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No WhatsApp number provided.')),
      );
      return;
    }
    String cleanedNumber = whatsappNumber.replaceAll(RegExp(r'\s+|-'), '');
    // Assume Indian numbers if not starting with '+'
    if (cleanedNumber.startsWith('0')) {
      cleanedNumber = '+91${cleanedNumber.substring(1)}';
    } else if (!cleanedNumber.startsWith('+')) {
      // Basic check to see if it might be an international number already
      // This might need refinement based on expected number formats
      if (cleanedNumber.length > 10 && !cleanedNumber.startsWith('+91')) {
        // Keep potentially international number as is if it has more than 10 digits
      } else {
        cleanedNumber = '+91$cleanedNumber'; // Default to +91
      }
    }
    final Uri launchUri = Uri.parse("https://wa.me/$cleanedNumber");
    try {
      if (await canLaunchUrl(launchUri)) {
        // Use external application mode to ensure it opens WhatsApp app
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } else {
        if (!context.mounted) return; // Check context before using
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open WhatsApp chat with $cleanedNumber. Is WhatsApp installed?',
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return; // Check context before using
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error trying to open WhatsApp: $e')),
      );
    }
  }

  // --- Function to delete booking ---
  Future<void> _deleteBooking(BuildContext context) async {
    // Show confirmation dialog before deleting
    bool confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Confirm Deletion"),
            content: Text(
              "Are you sure you want to delete the booking from ${booking.organization.isNotEmpty ? booking.organization : 'this contact'}? This action cannot be undone.",
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(false), // Return false on cancel
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pop(true), // Return true on confirm
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Delete"),
              ),
            ],
          ),
        ) ??
        false; // Default to false if dialog dismissed

    // If user cancelled or context is lost, do nothing
    if (!confirm || !context.mounted) {
      return;
    }

    final deleteUrl = '$_serverUrl/booking/${booking.id}';
    print("Attempting to delete booking at URL: $deleteUrl"); // Debug log

    try {
      final response = await http
          .delete(
            Uri.parse(deleteUrl),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (!context.mounted) return; // Check again after await

      print("Delete response status: ${response.statusCode}"); // Debug log
      print("Delete response body: ${response.body}"); // Debug log

      if (response.statusCode == 200 || response.statusCode == 204) {
        // 204 No Content is also success for DELETE
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Booking from ${booking.organization.isNotEmpty ? booking.organization : 'contact'} deleted successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        onBookingDeleted(); // Trigger refresh on the previous screen
        Navigator.of(context).pop(); // Go back to the list screen
      } else {
        // Try to parse error message from server response
        String errorMessage = 'Failed to delete booking.';
        try {
          final errorData = json.decode(response.body);
          errorMessage +=
              ' Server said: ${errorData['message'] ?? response.reasonPhrase ?? 'Unknown error'} (Code: ${response.statusCode})';
        } catch (e) {
          // Fallback if response body is not valid JSON
          errorMessage +=
              ' Status code: ${response.statusCode}. ${response.reasonPhrase ?? 'No reason provided.'}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      // Handle network errors
      if (!context.mounted) return;
      print("Error during delete request: $e"); // Debug log
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Network error or exception occurred while deleting. Error: $e',
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
  }

  // --- Function to send confirmation email ---
  Future<void> _sendConfirmationEmail(BuildContext context) async {
    // Prevent action if already confirmed
    if (booking.isConfirmed) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking is already confirmed.'),
          backgroundColor: Colors.blueGrey,
        ),
      );
      return;
    }
    // Prevent action if email is missing or invalid placeholder
    if (booking.email.isEmpty || booking.email == '-') {
      if (!context.mounted) return;
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

    // Show confirmation dialog
    bool confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Confirm Booking"),
            content: Text(
              "Are you sure you want to confirm this booking and send the confirmation email to ${booking.email}?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Confirm & Send"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm || !context.mounted) {
      return;
    }

    // Show immediate feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Attempting to confirm and send email to ${booking.email}...',
        ),
        backgroundColor: Colors.blueGrey,
        duration: const Duration(seconds: 2),
      ),
    );

    final confirmUrl = '$_serverUrl/confirm-booking/${booking.id}';
    print("Attempting confirmation at URL: $confirmUrl"); // Debug log

    try {
      final response = await http
          .post(
            Uri.parse(confirmUrl),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode({
              'email': booking.email,
            }), // Pass email if needed by backend
          )
          .timeout(const Duration(seconds: 20));

      if (!context.mounted) return; // Check after await

      print(
        "Confirmation response status: ${response.statusCode}",
      ); // Debug log
      print("Confirmation response body: ${response.body}"); // Debug log

      if (response.statusCode == 200) {
        onBookingConfirmed(); // Trigger refresh on the previous screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Booking confirmed! Email sent successfully to ${booking.email}.',
            ),
            backgroundColor: Colors.green, // Use green for success
          ),
        );
        Navigator.of(context).pop(); // Go back after success
      } else {
        // Handle server-side error during confirmation
        String errorMessage = 'Failed to confirm booking.';
        try {
          final errorData = json.decode(response.body);
          errorMessage +=
              ' Server said: ${errorData['message'] ?? response.reasonPhrase ?? 'Unknown error'} (Code: ${response.statusCode})';
        } catch (_) {
          errorMessage +=
              ' Status code: ${response.statusCode}. ${response.reasonPhrase ?? 'No reason provided.'}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      // Handle network errors
      if (!context.mounted) return;
      print("Error during confirmation request: $e"); // Debug log
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Network error occurred during confirmation. Error: $e',
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
  }

  // Helper widget to build consistent detail rows
  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    VoidCallback?
    onTap, // Optional callback for actions like call/email/whatsapp
  }) {
    // Determine text color for status row
    Color statusValueColor = Colors.black87; // Default text color
    FontWeight statusFontWeight = FontWeight.normal;
    if (label == 'Status') {
      statusValueColor = value == 'CONFIRMED'
          ? Colors
                .green
                .shade700 // Green for confirmed
          : Colors.orange.shade700; // Orange for pending
      statusFontWeight = FontWeight.bold; // Make status bold
    }

    // Determine if the value is empty or just a placeholder '-'
    final displayValue = (value.isEmpty || value == '-') ? '-' : value;
    final bool hasAction =
        onTap != null && displayValue != '-'; // Enable tap only if value exists

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: hasAction
            ? onTap
            : null, // Only allow tap if action is defined and value exists
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
                    displayValue, // Show '-' if value is empty
                    style: TextStyle(
                      fontSize: 16,
                      color: statusValueColor, // Use determined status color
                      // Underline specific tappable fields like Email
                      decoration:
                          hasAction &&
                              (label == 'Email ID' ||
                                  label == 'Phone' ||
                                  label == 'WhatsApp')
                          ? TextDecoration.underline
                          : TextDecoration.none,
                      decorationColor: Colors.blue,
                      fontWeight: statusFontWeight, // Apply bold for status
                    ),
                  ),
                ],
              ),
            ),
            // Show interaction icon for specific tappable fields
            if (hasAction)
              Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                child: Icon(
                  label == 'Email ID'
                      ? Icons.send
                      : label == 'Phone'
                      ? Icons.call_made
                      : label == 'WhatsApp'
                      ? Icons.message_outlined
                      : null, // Conditional icon
                  size: 16,
                  color: Colors.blue,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- Format Program Date to match Booking Date format ---
    final String formattedProgramDate = booking.programDate != null
        ? DateFormat.yMMMd().add_jm().format(
            booking.programDate!.toLocal(),
          ) // Apply format & ensure local
        : 'Not Specified';
    // --- End Date Formatting ---

    final bool isConfirmed = booking.isConfirmed;
    // Check if email is present and not just a placeholder
    final bool isEmailAvailable =
        booking.email.isNotEmpty && booking.email != '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking Details"),
        actions: [
          // Show Confirm button only if not already confirmed and email is available
          if (!isConfirmed && isEmailAvailable)
            IconButton(
              icon: const Icon(
                Icons.check_circle_outline,
                color: Colors.greenAccent, // Make it stand out
              ),
              onPressed: () => _sendConfirmationEmail(context),
              tooltip: 'Confirm Booking & Send Email',
            ),
          // Always show Delete button
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            onPressed: () => _deleteBooking(context),
            tooltip: 'Delete Booking',
          ),
        ],
      ),
      body: SingleChildScrollView(
        // Allows scrolling if content overflows
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
                // --- Booking Status ---
                _buildDetailRow(
                  "Status",
                  isConfirmed ? "CONFIRMED" : "PENDING",
                  isConfirmed
                      ? Icons.check_circle_outline
                      : Icons.pending_actions, // Changed pending icon
                ),
                const Divider(height: 20, thickness: 1), // Thicker divider
                // --- Booking & Contact Details ---
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
                _buildDetailRow(
                  "Designation",
                  booking.designation,
                  Icons.work_outline,
                ), // Changed icon
                _buildDetailRow(
                  "Phone",
                  booking.phone,
                  Icons.phone_android, // Changed icon
                  onTap: () =>
                      _makeCall(context, booking.phone), // Add tap action
                ),
                _buildDetailRow(
                  "WhatsApp",
                  booking.whatsapp,
                  Icons.message,
                  onTap: () => _openWhatsApp(
                    context,
                    booking.whatsapp,
                  ), // Add tap action
                ),
                _buildDetailRow(
                  "Email ID",
                  booking.email,
                  Icons.alternate_email, // Changed icon
                  onTap:
                      isEmailAvailable // Enable tap only if email is valid
                      ? () => launchUrl(Uri.parse('mailto:${booking.email}'))
                      : null,
                ),
                const Divider(height: 20, thickness: 1), // Thicker divider
                // --- Service Details ---
                _buildDetailRow(
                  "Service Required",
                  booking.serviceRequired,
                  Icons.room_service_outlined,
                ), // Changed icon
                _buildDetailRow(
                  "Preferred Topic",
                  booking.preferredTopic,
                  Icons.topic_outlined,
                ), // Changed icon
                _buildDetailRow("Medium", booking.medium, Icons.translate),
                _buildDetailRow(
                  "Venue",
                  booking.venue,
                  Icons.location_on_outlined,
                ), // Changed icon
                _buildDetailRow(
                  "Program Date",
                  formattedProgramDate, // Use the consistent formatted date
                  Icons.event_available, // Changed icon
                ),
                _buildDetailRow(
                  "Booking Date",
                  DateFormat.yMMMd().add_jm().format(
                    booking.createdAt.toLocal(),
                  ), // Target format
                  Icons.calendar_today_outlined, // Changed icon
                ),
                const Divider(height: 30), // Larger space before buttons
                // --- Action Buttons ---
                Center(
                  child: Column(
                    children: [
                      // --- Confirmation Button (Show only if not confirmed and email available) ---
                      if (!isConfirmed && isEmailAvailable)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 20.0,
                          ), // Add space below confirm button
                          child: ElevatedButton.icon(
                            onPressed: () => _sendConfirmationEmail(context),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 24,
                            ),
                            label: const Text("Confirm & Email User"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(
                                double.infinity,
                                50,
                              ), // Make button full width
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                      // --- Call Button ---
                      ElevatedButton.icon(
                        onPressed:
                            (booking.phone.isNotEmpty && booking.phone != '-')
                            ? () => _makeCall(context, booking.phone)
                            : null, // Disable if no valid phone number
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

                      // --- WhatsApp Button ---
                      ElevatedButton.icon(
                        onPressed:
                            (booking.whatsapp.isNotEmpty &&
                                booking.whatsapp != '-')
                            ? () => _openWhatsApp(context, booking.whatsapp)
                            : null, // Disable if no valid WhatsApp number
                        icon: const Icon(
                          Icons.message,
                        ), // Standard message icon
                        label: const Text("Send WhatsApp Message"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF25D366,
                          ), // WhatsApp Green
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30), // More space before delete
                      // --- Delete Button ---
                      OutlinedButton.icon(
                        onPressed: () => _deleteBooking(context),
                        icon: const Icon(Icons.delete_outline), // Changed icon
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

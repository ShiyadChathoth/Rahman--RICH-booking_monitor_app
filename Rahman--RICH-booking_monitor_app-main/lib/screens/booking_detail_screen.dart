// lib/screens/booking_detail_screen.dart - CORRECTED CODE

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // <-- ADD THIS LINE for json.decode
import '../models/booking.dart';

class BookingDetailScreen extends StatelessWidget {
  final Booking booking;
  final VoidCallback onBookingDeleted;

  const BookingDetailScreen({
    super.key,
    required this.booking,
    required this.onBookingDeleted,
  });

  // IMPORTANT: Replace with your server's actual IP address or domain
  final String _serverUrl = "http://pi-monitor.tailb72c55.ts.net:4000";

  Future<void> _makeCall(BuildContext context, String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not make a call to $phoneNumber')),
      );
      print('Could not launch $launchUri');
    }
  }

  Future<void> _openWhatsApp(
    BuildContext context,
    String whatsappNumber,
  ) async {
    final String formattedNumber = whatsappNumber.startsWith('+')
        ? whatsappNumber
        : '+91$whatsappNumber';

    final Uri launchUri = Uri.parse("https://wa.me/$formattedNumber");

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open WhatsApp chat with $whatsappNumber'),
        ),
      );
      print('Could not launch $launchUri');
    }
  }

  // --- NEW: Function to delete booking ---
  Future<void> _deleteBooking(BuildContext context) async {
    // Show a confirmation dialog
    bool confirm =
        await showDialog(
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
                child: const Text("Delete"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) {
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse('$_serverUrl/booking/${booking.id}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Booking from ${booking.organization} deleted successfully!',
            ),
          ),
        );
        onBookingDeleted();
        Navigator.of(context).pop();
      } else {
        final errorData = json.decode(
          response.body,
        ); // json.decode is now defined
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete booking: ${errorData['message'] ?? response.statusCode}',
            ),
          ),
        );
        print('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: Could not delete booking. $e')),
      );
      print('Network Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  DateFormat.yMMMd().add_jm().format(booking.createdAt),
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

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.indigo, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
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

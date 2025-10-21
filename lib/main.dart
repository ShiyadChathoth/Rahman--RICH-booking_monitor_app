// lib/main.dart - UPDATED CODE

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'services/notification_service.dart';
import 'models/booking.dart';
import 'screens/booking_detail_screen.dart';

void main() {
  runApp(const BookingMonitorApp());
}

class BookingMonitorApp extends StatelessWidget {
  const BookingMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Booking Monitor',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff0a2d57),
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String _serverUrl = "http://pi-monitor.tailb72c55.ts.net:4000";

  late final NotificationService notificationService;
  List<Booking> _bookings = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int? _lastKnownBookingId;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    notificationService = NotificationService();
    _initializeServices();
  }

  void _initializeServices() async {
    await notificationService.initNotification();
    await _fetchBookings();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    // Show loading indicator when fetching (optional, but good for UX)
    if (_bookings.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final response = await http
          .get(Uri.parse('$_serverUrl/bookings'))
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<Booking> fetchedBookings = (data['bookings'] as List)
              .map((json) => Booking.fromJson(json))
              .toList();

          // Check for new booking notification BEFORE updating _bookings
          if (fetchedBookings.isNotEmpty) {
            int newLatestId = fetchedBookings.first.id;
            if (_lastKnownBookingId != null &&
                newLatestId > _lastKnownBookingId!) {
              final newBooking = fetchedBookings.first;
              notificationService.showNotification(
                newLatestId,
                "New Booking Received!",
                "From: ${newBooking.organization}",
              );
            }
            _lastKnownBookingId = newLatestId;
          }

          setState(() {
            _bookings = fetchedBookings;
            _isLoading = false;
            _errorMessage = '';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server Error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      print('Connection Error: $e');
      setState(() {
        _errorMessage =
            'Failed to connect to the server. Make sure the server is running and the URL is correct.\nError: $e';
        _isLoading = false;
      });
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      print("Polling for new bookings...");
      _fetchBookings();
    });
  }

  // Callback function to refresh bookings after a deletion
  void _onBookingDeletedCallback() {
    _fetchBookings(); // Simply re-fetch all bookings
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Booking Monitor")),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _bookings.isEmpty) {
      // Only show full loading if no data yet
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }
    if (_bookings.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchBookings,
        child: const SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 300,
            child: Center(
              child: Text("No bookings found yet. Pull down to refresh!"),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchBookings,
      child: ListView.builder(
        itemCount: _bookings.length,
        itemBuilder: (context, index) {
          final booking = _bookings[index];

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingDetailScreen(
                      booking: booking,
                      onBookingDeleted:
                          _onBookingDeletedCallback, // Pass the callback
                    ),
                  ),
                );
              },
              leading: CircleAvatar(
                backgroundColor: const Color(0xffd4a017),
                child: Text(
                  booking.organization.isNotEmpty
                      ? booking.organization[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                booking.organization,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Contact: ${booking.contactPerson}\n'
                'Service: ${booking.serviceRequired}\n'
                'Received: ${DateFormat.yMMMd().add_jm().format(booking.createdAt)}',
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}

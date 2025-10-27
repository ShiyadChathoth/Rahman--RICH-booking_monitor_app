// lib/main.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// --- FCM/Firebase Imports ---
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
// --- End FCM Imports ---

import 'services/notification_service.dart';
import 'models/booking.dart';
import 'screens/booking_detail_screen.dart';

final String _serverUrl = "https://pi-monitor.tailb72c55.ts.net";

// --- FCM: Background Message Handler ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
  print('Message data: ${message.data}');

  if (message.notification != null) {
    print('Message also contained a notification: ${message.notification}');
    NotificationService notificationService = NotificationService();
    await notificationService.initNotification();
    notificationService.showNotification(
      message.hashCode,
      message.notification?.title ?? 'New Booking',
      message.notification?.body ?? '',
    );
  }
}
// --- End FCM ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- FCM: Initialize Firebase ---
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase Initialized Successfully");
  } catch (e) {
    print("Firebase Initialization Failed: $e");
  }

  // --- FCM: Set Background Handler ---
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // --- FCM: Request Permissions (Needed for Android 13+) ---
  await _requestNotificationPermissions();

  // --- FCM: Setup Message Handlers & Token Logic ---
  await _setupFcm();
  // --- End FCM ---

  runApp(const BookingMonitorApp());
}

// --- FCM: Helper function to request notification permissions ---
Future<void> _requestNotificationPermissions() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  try {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('User granted provisional notification permission');
    } else {
      print('User declined or has not accepted notification permission');
    }
  } catch (e) {
    print("Error requesting notification permissions: $e");
  }
}
// --- End FCM ---

// --- FCM: Function to set up listeners and handle token ---
Future<void> _setupFcm() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // 1. Get initial token and send to server
  try {
    String? fcmToken = await messaging.getToken();
    if (fcmToken != null) {
      print("Initial FCM Token: $fcmToken");
      await registerDeviceToken(fcmToken);
    } else {
      print("Failed to get initial FCM token (token is null).");
    }
  } catch (e) {
    print("Error getting initial FCM token: $e");
  }

  // 2. Listen for token refreshes and send updates to server
  messaging.onTokenRefresh
      .listen((newToken) async {
        print("FCM Token Refreshed: $newToken");
        await registerDeviceToken(newToken);
      })
      .onError((err) {
        print("Error listening for token refresh: $err");
      });

  // 3. Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Foreground message received:');
    print('Message ID: ${message.messageId}');

    if (message.notification != null) {
      NotificationService notificationService = NotificationService();
      notificationService.showNotification(
        message.hashCode,
        message.notification?.title ?? 'Notification',
        message.notification?.body ?? '',
      );
    }
  });

  // 4. Handle notification tap when app was terminated
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      print(
        "App opened via terminated state notification tap: ${message.messageId}",
      );
    }
  });

  // 5. Handle notification tap when app was in background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print(
      'App opened via background state notification tap: ${message.messageId}',
    );
  });
}
// --- End FCM ---

// --- FCM: Function to send the device token to your server ---
Future<void> registerDeviceToken(String token) async {
  final url = Uri.parse('$_serverUrl/register-device');
  print("Sending token to server at $url : $token");
  try {
    final response = await http
        .post(
          url,
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(<String, String>{'token': token}),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      print('Token registered successfully with server.');
    } else {
      print(
        'Failed to register token. Server responded with status: ${response.statusCode}',
      );
    }
  } catch (e) {
    print('Error sending token to server: $e');
  }
}
// --- End FCM ---

// --- Main App Widget ---
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

// --- Home Screen Widget ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final NotificationService notificationService;
  List<Booking> _bookings = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    notificationService = NotificationService();
    _initializeServicesAndLoadData();
  }

  void _initializeServicesAndLoadData() async {
    await notificationService.initNotification();
    await _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http
          .get(Uri.parse('$_serverUrl/bookings'))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['bookings'] is List) {
          final List<Booking> fetchedBookings = (data['bookings'] as List)
              .map((json) => Booking.fromJson(json))
              .toList();

          setState(() {
            _bookings = fetchedBookings;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage =
                'API Error: ${data['message'] ?? 'Failed to load booking data.'}';
            _isLoading = false;
            _bookings = [];
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server Error: ${response.statusCode}';
          _isLoading = false;
          _bookings = [];
        });
      }
    } catch (e) {
      if (!mounted) return;
      print('Connection Error fetching bookings: $e');
      setState(() {
        _errorMessage = 'Network Error: Could not connect to the server.';
        _isLoading = false;
        _bookings = [];
      });
    }
  }

  void _onBookingDeletedCallback() {
    _fetchBookings();
  }

  // --- NEW: _sendConfirmationEmail function for the main list view ---
  Future<void> _sendConfirmationEmailFromList(
    BuildContext context,
    Booking booking,
  ) async {
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
          content: Text('Cannot send confirmation: No valid email provided.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sending confirmation email to ${booking.contactPerson}...',
        ),
        backgroundColor: Colors.blueGrey,
        duration: const Duration(seconds: 1),
      ),
    );

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

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Refresh the list to update the status in the UI
        await _fetchBookings();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'CONFIRMED! Email sent to ${booking.contactPerson} successfully.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to confirm. Server error: ${response.statusCode}',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: Could not confirm booking. Error: $e'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
  }
  // --- END NEW FUNCTION ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Booking Monitor")),
      body: _buildBody(),
    );
  }

  // Builds the main body content based on the current state (MODIFIED)
  Widget _buildBody() {
    if (_isLoading && _bookings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchBookings,
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }
    if (_bookings.isEmpty && !_isLoading) {
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
          final String subtitleProgramDate = booking.programDate != null
              ? ' | Pgm: ${DateFormat.yMd().format(booking.programDate!)}'
              : '';

          // --- Determine leading status widget ---
          final Widget leadingStatus = CircleAvatar(
            backgroundColor: booking.isConfirmed
                ? Colors.green
                : const Color(0xffd4a017),
            child: Text(
              booking.isConfirmed
                  ? '✓'
                  : (booking.organization.isNotEmpty
                        ? booking.organization[0].toUpperCase()
                        : '?'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
          // ----------------------------------------

          // --- Determine trailing button widget ---
          final Widget? trailingButton = booking.isConfirmed
              ? null // Hide button if confirmed
              : IconButton(
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.blue,
                  ),
                  tooltip: 'Confirm Booking & Send Email',
                  onPressed: booking.email.isNotEmpty
                      ? () => _sendConfirmationEmailFromList(context, booking)
                      : null,
                );
          // ----------------------------------------

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
                      onBookingDeleted: _onBookingDeletedCallback,
                      onBookingConfirmed:
                          _fetchBookings, // Pass callback to refresh after confirm
                    ),
                  ),
                );
              },
              leading: leadingStatus, // Use the status widget
              title: Text(
                '${booking.organization.isNotEmpty ? booking.organization : '(No Organization)'} ${booking.isConfirmed ? ' (CONFIRMED)' : ''}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: booking.isConfirmed
                      ? Colors.green.shade700
                      : Colors.black,
                ),
              ),
              subtitle: Text(
                'Contact: ${booking.contactPerson.isNotEmpty ? booking.contactPerson : '-'}\n'
                'Received: ${DateFormat.yMd().add_jm().format(booking.createdAt.toLocal())}$subtitleProgramDate',
              ),
              isThreeLine: true,
              trailing: trailingButton, // Use the conditional button
            ),
          );
        },
      ),
    );
  }
}

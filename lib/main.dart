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
      // Ensure init is called before showing notification
      notificationService.initNotification().then((_) {
        notificationService.showNotification(
          message.hashCode,
          message.notification?.title ?? 'Notification',
          message.notification?.body ?? '',
        );
      });
    }
  });

  // 4. Handle notification tap when app was terminated
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      print(
        "App opened via terminated state notification tap: ${message.messageId}",
      );
      // Optional: Handle navigation
    }
  });

  // 5. Handle notification tap when app was in background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print(
      'App opened via background state notification tap: ${message.messageId}',
    );
    // Optional: Handle navigation
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
    // Check if the widget is still mounted before proceeding
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http
          .get(Uri.parse('$_serverUrl/bookings'))
          .timeout(const Duration(seconds: 15));

      // Check mount status again after the async gap
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['bookings'] is List) {
          final List<Booking> fetchedBookings = (data['bookings'] as List)
              .map((json) => Booking.fromJson(json))
              .toList();

          // Sort bookings by creation date, newest first
          fetchedBookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
          _errorMessage =
              'Server Error: ${response.statusCode} - ${response.reasonPhrase}';
          _isLoading = false;
          _bookings = [];
        });
      }
    } catch (e) {
      // Check mount status in catch block
      if (!mounted) return;
      print('Connection Error fetching bookings: $e');
      setState(() {
        // Differentiate timeout error
        _errorMessage = (e is TimeoutException)
            ? 'Network Error: Request timed out.'
            : 'Network Error: Could not connect to the server.';
        _isLoading = false;
        _bookings = [];
      });
    }
  }

  void _onBookingDeletedCallback() {
    _fetchBookings(); // Refresh list after deletion
  }

  // --- Send confirmation email function (for list view) ---
  Future<void> _sendConfirmationEmailFromList(
    BuildContext context,
    Booking booking,
  ) async {
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
    if (booking.email.isEmpty || booking.email == '-') {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot send confirmation: No valid email provided.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sending confirmation email to ${booking.contactPerson}...',
        ),
        backgroundColor: Colors.blueGrey,
        duration: const Duration(seconds: 2), // Slightly longer feedback
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

      if (!mounted) return; // Check after await

      if (response.statusCode == 200) {
        // Refresh the list immediately upon success
        await _fetchBookings(); // Await refresh

        if (!mounted) return; // Check again after second await
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
  // --- END confirmation function ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Booking Monitor")),
      body: _buildBody(), // Use helper method for body content
    );
  }

  // Builds the main body content based on the current state
  Widget _buildBody() {
    // Initial loading state
    if (_isLoading && _bookings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error state display
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                // Added icon to retry button
                onPressed: _fetchBookings,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    // Empty list state (after successful load)
    if (_bookings.isEmpty && !_isLoading) {
      // Wrap with LayoutBuilder and SingleChildScrollView for scrollable refresh
      return RefreshIndicator(
        onRefresh: _fetchBookings,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics:
                  const AlwaysScrollableScrollPhysics(), // Enable pull-down
              child: ConstrainedBox(
                // Ensure Center takes full height
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "No bookings found yet.\nPull down to refresh!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    // --- Display Booking List ---
    return RefreshIndicator(
      onRefresh: _fetchBookings, // Enable pull-to-refresh
      child: ListView.builder(
        itemCount: _bookings.length,
        itemBuilder: (context, index) {
          final booking = _bookings[index];

          // ---- ONLY CHANGE: Format programDate in subtitle ----
          final String subtitleProgramDate = booking.programDate != null
              ? ' | Pgm: ${DateFormat.yMd().add_jm().format(booking.programDate!.toLocal())}' // Apply format and ensure Local Time
              : '';
          // ---- END CHANGE ----

          // Status indicator avatar
          final Widget leadingStatus = CircleAvatar(
            backgroundColor: booking.isConfirmed
                ? Colors.green
                : const Color(0xffd4a017), // Gold-ish
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

          // Trailing confirmation button (conditional)
          final Widget? trailingButton =
              (booking.isConfirmed ||
                  booking.email.isEmpty ||
                  booking.email == '-')
              ? null // No button if confirmed or no email
              : IconButton(
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.blue,
                  ),
                  tooltip: 'Confirm Booking & Send Email',
                  // Only enable if email is valid
                  onPressed: () =>
                      _sendConfirmationEmailFromList(context, booking),
                );

          // List Tile for each booking
          return Card(
            // Using CardTheme from MaterialApp
            // margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Defined in CardTheme
            // elevation: 2, // Defined in CardTheme
            // shape: RoundedRectangleBorder( // Defined in CardTheme
            //   borderRadius: BorderRadius.circular(8),
            // ),
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingDetailScreen(
                      booking: booking,
                      onBookingDeleted: _onBookingDeletedCallback,
                      onBookingConfirmed:
                          _fetchBookings, // Pass refresh callback
                    ),
                  ),
                );
              },
              leading: leadingStatus,
              title: Text(
                '${booking.organization.isNotEmpty ? booking.organization : '(No Organization)'}${booking.isConfirmed ? ' (CONFIRMED)' : ''}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: booking.isConfirmed
                      ? Colors.green.shade700
                      : Colors.black87, // Slightly softer black
                ),
                maxLines: 1, // Ensure title doesn't wrap excessively
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                'Contact: ${booking.contactPerson.isNotEmpty ? booking.contactPerson : '-'}\n'
                'Received: ${DateFormat.yMd().add_jm().format(booking.createdAt.toLocal())}$subtitleProgramDate', // Use formatted program date
                style: TextStyle(
                  color: Colors.grey.shade600,
                ), // Subdued subtitle color
              ),
              isThreeLine: true, // Allow subtitle to wrap if needed
              trailing: trailingButton,
            ),
          );
        },
      ),
    );
  }
}

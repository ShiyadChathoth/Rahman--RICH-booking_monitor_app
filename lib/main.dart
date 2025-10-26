// lib/main.dart - FCM INTEGRATED CODE

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// --- FCM/Firebase Imports ---
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// Ensure this file exists (run `flutterfire configure`)
import 'firebase_options.dart';
// --- End FCM Imports ---

import 'services/notification_service.dart';
import 'models/booking.dart';
import 'screens/booking_detail_screen.dart';

// Define the server URL (ensure it's accessible)
// Ensure this matches the URL your server is accessible at via Tailscale/Funnel
final String _serverUrl = "https://pi-monitor.tailb72c55.ts.net";

// --- FCM: Background Message Handler ---
// This MUST be a top-level function (not inside a class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you need to initialize anything here (like Firebase again), do it first.
  // However, firebase_messaging plugin usually handles initialization for background.
  // Example: await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
  print('Message data: ${message.data}');

  if (message.notification != null) {
    print('Message also contained a notification: ${message.notification}');
    // Use flutter_local_notifications to display the notification from background
    NotificationService notificationService = NotificationService();
    // Initialize notification service for this background isolate
    await notificationService.initNotification();
    notificationService.showNotification(
      message.hashCode, // Use a hashcode or other unique ID from the message
      message.notification?.title ?? 'New Booking', // Provide default title
      message.notification?.body ?? '', // Provide default body
    );
  }
}
// --- End FCM ---

void main() async {
  // Ensure Flutter bindings are initialized before calling native code
  WidgetsFlutterBinding.ensureInitialized();

  // --- FCM: Initialize Firebase ---
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform, // Use generated options
    );
    print("Firebase Initialized Successfully");
  } catch (e) {
    print("Firebase Initialization Failed: $e");
    // Handle initialization error (e.g., show an error message or exit)
    // You might not want to continue if Firebase fails to initialize.
  }

  // --- FCM: Set Background Handler ---
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // --- FCM: Request Permissions (Needed for Android 13+) ---
  await _requestNotificationPermissions();

  // --- FCM: Setup Message Handlers & Token Logic ---
  // Call this after Firebase initialization
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
      provisional:
          false, // Set to true if you want provisional permission on iOS
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('User granted provisional notification permission');
    } else {
      print('User declined or has not accepted notification permission');
      // Optionally: Show a dialog explaining why notifications are important
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
      await registerDeviceToken(fcmToken); // Send token to your server
    } else {
      print("Failed to get initial FCM token (token is null).");
      // Optionally handle this case (e.g., retry later)
    }
  } catch (e) {
    print("Error getting initial FCM token: $e");
    // Optionally handle this case (e.g., retry later)
  }

  // 2. Listen for token refreshes and send updates to server
  messaging.onTokenRefresh
      .listen((newToken) async {
        print("FCM Token Refreshed: $newToken");
        await registerDeviceToken(
          newToken,
        ); // Send updated token to your server
      })
      .onError((err) {
        // Handle errors during token refresh
        print("Error listening for token refresh: $err");
      });

  // 3. Handle foreground messages (app is open and visible)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Foreground message received:');
    print('Message ID: ${message.messageId}');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message contained a notification: ${message.notification}');
      // Display the notification using flutter_local_notifications
      // because the system won't show it automatically in the foreground.
      NotificationService notificationService = NotificationService();
      // Assuming initNotification was called reliably at startup
      notificationService.showNotification(
        message.hashCode, // Use message hashcode as a simple unique ID
        message.notification?.title ?? 'Notification', // Fallback title
        message.notification?.body ?? '', // Fallback body
      );
    }
  });

  // 4. Handle notification tap when app was terminated
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      print(
        "App opened via terminated state notification tap: ${message.messageId}",
      );
      // TODO: Handle navigation or data based on message.data if needed
      // Example: Check message.data['bookingId'] and navigate
    }
  });

  // 5. Handle notification tap when app was in background (but not terminated)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print(
      'App opened via background state notification tap: ${message.messageId}',
    );
    // TODO: Handle navigation or data based on message.data if needed
    // Example: Check message.data['bookingId'] and navigate
  });
}
// --- End FCM ---

// --- FCM: Function to send the device token to your server ---
Future<void> registerDeviceToken(String token) async {
  // Use the correct endpoint you created on your server
  final url = Uri.parse('$_serverUrl/register-device');
  print("Sending token to server at $url : $token");
  try {
    final response = await http
        .post(
          url,
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          // Send the token in the request body as expected by your server
          body: jsonEncode(<String, String>{'token': token}),
        )
        .timeout(const Duration(seconds: 20)); // Increased timeout

    if (response.statusCode == 200) {
      print('Token registered successfully with server.');
    } else {
      // Log server errors for debugging
      print(
        'Failed to register token. Server responded with status: ${response.statusCode}',
      );
      print('Response body: ${response.body}');
      // TODO: Implement retry logic or inform the user if critical
    }
  } catch (e) {
    // Log network or other errors
    print('Error sending token to server: $e');
    // TODO: Implement retry logic or inform the user if critical
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
        primarySwatch: Colors.indigo, // Or use colorSchemeSeed
        // colorSchemeSeed: Colors.indigo, // Alternative theming
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff0a2d57), // Dark blue color
          foregroundColor: Colors.white, // Text/icon color on AppBar
          elevation: 4,
        ),
        // Consider adding other theme elements like button themes, card themes etc.
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false, // Hides the debug banner
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

  // Initializes local notification service and fetches initial data
  void _initializeServicesAndLoadData() async {
    // Initialize local notifications service (used for foreground FCM display)
    await notificationService.initNotification();
    // Fetch initial list of bookings when the screen loads
    await _fetchBookings();
  }

  // Fetches the list of bookings from the server
  Future<void> _fetchBookings() async {
    // Ensure the widget is still mounted before updating state
    if (!mounted) return;

    setState(() {
      _isLoading = true; // Show loading indicator
      _errorMessage = ''; // Clear previous errors on fetch/refresh
    });

    try {
      final response = await http
          .get(Uri.parse('$_serverUrl/bookings'))
          .timeout(const Duration(seconds: 15)); // Timeout for the request

      if (!mounted) return; // Check again after the async call completes

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Check if the server response indicates success and contains a list
        if (data['success'] == true && data['bookings'] is List) {
          final List<Booking> fetchedBookings = (data['bookings'] as List)
              .map(
                (json) => Booking.fromJson(json),
              ) // Parse JSON into Booking objects
              .toList();

          setState(() {
            _bookings = fetchedBookings; // Update the list
            _isLoading = false; // Hide loading indicator
          });
        } else {
          // Handle cases where the API call succeeded but the server reported an error
          setState(() {
            _errorMessage =
                'API Error: ${data['message'] ?? 'Failed to load booking data.'}';
            _isLoading = false;
            _bookings = []; // Clear list on API error
          });
        }
      } else {
        // Handle HTTP errors (like 404, 500, 502 etc.)
        setState(() {
          _errorMessage = 'Server Error: ${response.statusCode}';
          _isLoading = false;
          _bookings = []; // Clear list on server error
        });
      }
    } catch (e) {
      // Handle network errors (timeout, no connection etc.)
      if (!mounted) return;
      print('Connection Error fetching bookings: $e');
      setState(() {
        _errorMessage = 'Network Error: Could not connect to the server.';
        _isLoading = false;
        _bookings = []; // Clear list on network error
      });
    }
  }

  // Callback passed to detail screen to refresh list after deletion
  void _onBookingDeletedCallback() {
    _fetchBookings(); // Re-fetch the list
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Booking Monitor")),
      body: _buildBody(), // Delegate body building to a separate method
    );
  }

  // Builds the main body content based on the current state
  Widget _buildBody() {
    // Show loading indicator while fetching initial data
    if (_isLoading && _bookings.isEmpty) {
      // Show only initial loading
      return const Center(child: CircularProgressIndicator());
    }
    // Show error message and a retry button if fetching failed
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
                onPressed: _fetchBookings, // Allow user to retry fetching
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }
    // Show a message if there are no bookings, wrapped in RefreshIndicator
    if (_bookings.isEmpty && !_isLoading) {
      // Ensure not loading
      return RefreshIndicator(
        onRefresh: _fetchBookings,
        child: const SingleChildScrollView(
          // Required for RefreshIndicator to work without a list
          physics: AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 300, // Give some height for the pull-down gesture
            child: Center(
              child: Text("No bookings found yet. Pull down to refresh!"),
            ),
          ),
        ),
      );
    }
    // Display the list of bookings using RefreshIndicator and ListView
    return RefreshIndicator(
      onRefresh: _fetchBookings, // Enable pull-to-refresh
      child: ListView.builder(
        itemCount: _bookings.length,
        itemBuilder: (context, index) {
          final booking = _bookings[index];
          // Format program date nicely for subtitle, handle null case
          final String subtitleProgramDate = booking.programDate != null
              ? ' | Pgm: ${DateFormat.yMd().format(booking.programDate!)}' // e.g., 'Oct 26, 2025'
              : ''; // Empty string if no program date

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              // Navigate to detail screen on tap
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingDetailScreen(
                      booking: booking,
                      onBookingDeleted:
                          _onBookingDeletedCallback, // Pass callback
                    ),
                  ),
                );
              },
              // Leading avatar with first letter of organization
              leading: CircleAvatar(
                backgroundColor: const Color(0xffd4a017), // Gold-like color
                child: Text(
                  booking.organization.isNotEmpty
                      ? booking.organization[0]
                            .toUpperCase() // First letter
                      : '?', // Fallback
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Booking title (Organization name)
              title: Text(
                booking.organization.isNotEmpty
                    ? booking.organization
                    : '(No Organization)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              // Booking subtitle (Contact and Dates)
              subtitle: Text(
                'Contact: ${booking.contactPerson.isNotEmpty ? booking.contactPerson : '-'}\n'
                'Received: ${DateFormat.yMd().add_jm().format(booking.createdAt.toLocal())}$subtitleProgramDate',
                // Format: Oct 26, 2025 10:54 PM | Pgm: Oct 31, 2025
              ),
              isThreeLine: true, // Allows subtitle to wrap comfortably
            ),
          );
        },
      ),
    );
  }
} // End _HomeScreenState

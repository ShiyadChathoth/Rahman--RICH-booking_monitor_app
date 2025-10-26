// lib/main.dart - CORRECTED CODE

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// --- FCM/Firebase Imports ---
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// Ensure firebase_options.dart exists after running `flutterfire configure`
import 'firebase_options.dart';
// --- End FCM Imports ---

import 'services/notification_service.dart';
import 'models/booking.dart';
import 'screens/booking_detail_screen.dart';

// Define the server URL (ensure it's accessible)
final String _serverUrl = "https://pi-monitor.tailb72c55.ts.net";

// --- FCM: Background Message Handler ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you need to initialize anything here, ensure plugins are ready.
  // Example: await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
  print('Message data: ${message.data}');

  if (message.notification != null) {
    print('Message also contained a notification: ${message.notification}');
    NotificationService notificationService = NotificationService();
    // Ensure initNotification doesn't rely on BuildContext here
    await notificationService.initNotification();
    notificationService.showNotification(
      message.hashCode,
      message.notification?.title ?? 'New Message',
      message.notification?.body ?? '',
    );
  }
}
// --- End FCM ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- FCM: Initialize Firebase ---
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Use generated options
  );
  print("Firebase Initialized");

  // --- FCM: Set Background Handler ---
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // --- FCM: Request Permissions (Needed for Android 13+) ---
  await _requestNotificationPermissions();

  // --- FCM: Setup Message Handlers & Token Logic ---
  await _setupFcm();
  // --- End FCM ---

  runApp(const BookingMonitorApp());
}

// --- FCM: Helper function to request permissions ---
Future<void> _requestNotificationPermissions() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('User granted notification permission');
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    print('User granted provisional notification permission');
  } else {
    print('User declined or has not accepted notification permission');
  }
}
// --- End FCM ---

// --- FCM: Function to set up listeners and handle token ---
Future<void> _setupFcm() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // 1. Get initial token and send to server
  String? fcmToken = await messaging.getToken();
  if (fcmToken != null) {
    print("Initial FCM Token: $fcmToken");
    await registerDeviceToken(fcmToken);
  } else {
    print("Failed to get initial FCM token.");
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

  // 3. Handle foreground messages (app is open)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Foreground message received:');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message contained a notification: ${message.notification}');
      NotificationService notificationService = NotificationService();
      notificationService.initNotification().then((_) {
        notificationService.showNotification(
          message.hashCode,
          message.notification?.title ?? 'Notification',
          message.notification?.body ?? '',
        );
      });
    }
  });

  // 4. Handle notification tap when app is terminated/background
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      print(
        "App opened via terminated state notification: ${message.messageId}",
      );
      // TODO: Handle navigation based on message.data if needed
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('App opened via background state notification: ${message.messageId}');
    // TODO: Handle navigation based on message.data if needed
  });
}
// --- End FCM ---

// --- FCM: Function to send the token to your server ---
Future<void> registerDeviceToken(String token) async {
  final url = Uri.parse('$_serverUrl/register-device');
  print("Sending token to server: $token");
  try {
    final response = await http
        .post(
          url,
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(<String, String>{'token': token}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      print('Token registered successfully with server.');
    } else {
      print(
        'Failed to register token. Server responded with status: ${response.statusCode}',
      );
      print('Response body: ${response.body}');
    }
  } catch (e) {
    print('Error sending token to server: $e');
  }
}
// --- End FCM ---

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
    await _fetchBookings(); // CORRECTED TYPO HERE
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
                'API Error: ${data['message'] ?? 'Failed to load data.'}';
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
        _errorMessage =
            'Network Error: Could not connect to the server.\nPlease check your connection.';
        _isLoading = false;
        _bookings = [];
      });
    }
  }

  void _onBookingDeletedCallback() {
    _fetchBookings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Booking Monitor")),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
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
          final String subtitleProgramDate = booking.programDate != null
              ? ' | Pgm: ${DateFormat.yMd().format(booking.programDate!)}'
              : '';

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
              // --- FIX Text Widgets ---
              title: Text(
                booking.organization,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Contact: ${booking.contactPerson}\n'
                'Received: ${DateFormat.yMd().add_jm().format(booking.createdAt)}$subtitleProgramDate',
              ),
              // --- End FIX ---
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}

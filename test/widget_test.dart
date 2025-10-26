// test/widget_test.dart - CORRECTED APP WIDGET

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Import the correct main app widget
import 'package:booking_monitor_app/main.dart';

void main() {
  testWidgets('Initial UI smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Use BookingMonitorApp instead of MyApp
    await tester.pumpWidget(const BookingMonitorApp());

    // Verify that the AppBar title is present.
    expect(find.text('Live Booking Monitor'), findsOneWidget);

    // Verify initially it might show loading or no bookings text
    // This depends on how fast the initial fetch completes in a test environment
    // It's often better to test specific states after mocking HTTP calls.
    // For a simple smoke test, just finding the title might be enough.
    // expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // OR
    // expect(find.text("No bookings found yet. Pull down to refresh!"), findsOneWidget);
  });
}

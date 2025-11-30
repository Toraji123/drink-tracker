import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sobriety_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CalendarScreen UI Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Calendar displays and can be interacted with', (WidgetTester tester) async {
      // Set a large screen size to avoid overflow
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Verify calendar is displayed
      expect(find.byType(CalendarScreen), findsOneWidget);
      
      // Look for calendar-related text or widgets
      // The calendar uses TableCalendar which should be present
      expect(find.text('月間サマリー'), findsOneWidget);
    });

    testWidgets('Tapping a date opens bottom sheet', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Find today's date in the calendar and tap it
      // We'll tap where the calendar is, which should trigger the onDaySelected
      final calendarFinder = find.byType(CalendarScreen);
      expect(calendarFinder, findsOneWidget);

      // Simulate tapping somewhere in the middle of the screen (where calendar dates typically are)
      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle();

      // Verify bottom sheet is shown
      // Bottom sheet should contain drink items
      expect(find.text('ビール/酎ハイ (5%) 350ml'), findsOneWidget);
    });

    testWidgets('Adding a drink and saving updates the display', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Initial state - monthly total should be 0
      expect(find.textContaining('0.0g'), findsAtLeast(1));

      // Tap a date to open bottom sheet
      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle();

      // Find the + button for the first drink item (Beer 350ml)
      // The + button should be an IconButton with an add icon
      final addButtons = find.widgetWithIcon(IconButton, Icons.add);
      expect(addButtons, findsWidgets);

      // Tap the first + button
      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();

      // Verify quantity changed (should show 1)
      expect(find.text('1'), findsWidgets);

      // Find and tap the save/close button
      // Look for a button with text '閉じる' or check icon
      final closeButton = find.byIcon(Icons.check);
      if (closeButton.evaluate().isNotEmpty) {
        await tester.tap(closeButton);
      } else {
        // Alternative: tap outside the bottom sheet to close it
        await tester.tapAt(const Offset(200, 100));
      }
      await tester.pumpAndSettle();

      // Verify the data was saved and display updated
      // The monthly total should now show 14.0g (one beer)
      expect(find.textContaining('14.0g'), findsAtLeast(1));
    });

    testWidgets('Multiple drinks calculation is correct', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Open bottom sheet
      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle();

      // Add 2 beers (350ml)
      final addButtons = find.widgetWithIcon(IconButton, Icons.add);
      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();
      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();

      // Verify quantity shows 2
      expect(find.text('2'), findsWidgets);

      // Close the bottom sheet
      final closeButton = find.byIcon(Icons.check);
      if (closeButton.evaluate().isNotEmpty) {
        await tester.tap(closeButton);
      } else {
        await tester.tapAt(const Offset(200, 100));
      }
      await tester.pumpAndSettle();

      // Verify total is 28.0g (2 × 14g)
      expect(find.textContaining('28.0g'), findsAtLeast(1));
    });

    testWidgets('Settings page can be opened', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Find the settings icon button in the app bar
      final settingsButton = find.byIcon(Icons.settings);
      expect(settingsButton, findsOneWidget);

      // Tap the settings button
      await tester.tap(settingsButton);
      await tester.pumpAndSettle();

      // Verify settings page is displayed
      expect(find.text('設定'), findsOneWidget);
    });
  });

  group('Data Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Data persists across app restarts', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;

      // First session: add data
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle();

      final addButtons = find.widgetWithIcon(IconButton, Icons.add);
      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();

      final closeButton = find.byIcon(Icons.check);
      if (closeButton.evaluate().isNotEmpty) {
        await tester.tap(closeButton);
      } else {
        await tester.tapAt(const Offset(200, 100));
      }
      await tester.pumpAndSettle();

      // Verify data is shown
      expect(find.textContaining('14.0g'), findsAtLeast(1));

      // Simulate app restart
      await tester.pumpWidget(Container()); // Clear the widget tree
      await tester.pumpAndSettle();

      // Second session: verify data is still there
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Data should still be displayed
      expect(find.textContaining('14.0g'), findsAtLeast(1));
    });
  });
}

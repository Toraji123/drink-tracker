import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    await _configureLocalTimeZone();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
    
    // Create notification channel for Android
    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'daily_reminder_channel',
      'Daily Reminder',
      description: 'Daily reminder to log your alcohol consumption',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    // Create debug channel
    const AndroidNotificationChannel debugChannel = AndroidNotificationChannel(
      'debug_channel',
      'Debug Channel',
      description: 'Channel for debugging notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(debugChannel);
    
    await _addLog('Notification channels created');
  }

  Future<void> _configureLocalTimeZone() async {
    // tz.initializeTimeZones() is already called in main.dart
    final dynamic timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    final String timeZoneName = timeZoneInfo is String ? timeZoneInfo : timeZoneInfo.identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneName));
    await _addLog('Timezone set to $timeZoneName');
  }

  Future<void> _addLog(String message) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = DateTime.now().toString().substring(0, 19);
    final logMessage = '[$timestamp] $message';
    print('NotificationService: $message');
    
    List<String> logs = prefs.getStringList('notification_logs') ?? [];
    logs.insert(0, logMessage); // Add to beginning
    if (logs.length > 50) {
      logs = logs.sublist(0, 50); // Keep only last 50 logs
    }
    await prefs.setStringList('notification_logs', logs);
  }

  Future<List<String>> getLogs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('notification_logs') ?? [];
  }

  Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notification_logs');
  }

  Future<void> requestPermissions() async {
    if (Platform.isIOS) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final notifPermission = await androidImplementation?.requestNotificationsPermission();
      await _addLog('Notification permission: $notifPermission');
      
      final alarmPermission = await androidImplementation?.requestExactAlarmsPermission();
      await _addLog('Exact alarm permission: $alarmPermission');
    }
  }

  Future<void> scheduleDailyNotification(TimeOfDay time) async {
    await cancelNotification(); // Clear existing before scheduling new one

    final scheduledTime = _nextInstanceOfTime(time);
    await _addLog('Scheduling notification for $scheduledTime');
    await _addLog('Current time is ${tz.TZDateTime.now(tz.local)}');

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Sobriety Tracker',
      '今日の記録を付けましょう！',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder_channel',
          'Daily Reminder',
          channelDescription: 'Daily reminder to log your alcohol consumption',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    await _addLog('Notification scheduled successfully');
  }

  Future<void> scheduleTestNotificationIn1Minute() async {
    await cancelNotification();

    final now = tz.TZDateTime.now(tz.local);
    final scheduledTime = now.add(const Duration(minutes: 1));
    
    await _addLog('Scheduling 1-minute test notification...');
    await _addLog('Current time: $now');
    await _addLog('Scheduled for: $scheduledTime');

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'Test Scheduled Notification',
        'This notification was scheduled 1 minute ago',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder_channel',
            'Daily Reminder',
            channelDescription: 'Daily reminder to log your alcohol consumption',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
      );
      
      await _addLog('1-minute test scheduled successfully');
      
      // Check if notification is actually pending
      final pendingNotifications = await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
      await _addLog('Pending notifications count: ${pendingNotifications.length}');
      for (var notification in pendingNotifications) {
        await _addLog('Pending: ID=${notification.id}, Title=${notification.title}');
      }
    } catch (e) {
      await _addLog('ERROR scheduling notification: $e');
    }
  }



  Future<void> testFutureDelayedNotification() async {
    await _addLog('Starting 5-second Future.delayed test...');
    
    Future.delayed(const Duration(seconds: 5), () async {
      await _addLog('5 seconds passed (Future.delayed). Showing notification...');
      await _flutterLocalNotificationsPlugin.show(
        888,
        'Future.delayed Test',
        'This notification used Future.delayed (App must be running)',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'debug_channel',
            'Debug Channel',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      await _addLog('Future.delayed notification sent');
    });
  }

  Future<void> testZonedSchedule5Seconds() async {
    final now = tz.TZDateTime.now(tz.local);
    final scheduledTime = now.add(const Duration(seconds: 5));
    
    await _addLog('Scheduling 5-second zonedSchedule test...');
    
    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        777,
        'ZonedSchedule 5s Test',
        'This notification used zonedSchedule (System Alarm)',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'debug_channel',
            'Debug Channel',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
      );
      await _addLog('5-second zonedSchedule registered');
    } catch (e) {
      await _addLog('ERROR in 5s schedule: $e');
    }
  }

  Future<void> cancelNotification() async {
    await _flutterLocalNotificationsPlugin.cancel(0);
    await _addLog('Notification cancelled');
  }

  Future<void> showTestNotification() async {
    await _addLog('Showing test notification...');
    
    await _flutterLocalNotificationsPlugin.show(
      999, // Different ID from scheduled notification
      'Test Notification',
      'This is a test notification from Sobriety Tracker',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder_channel',
          'Daily Reminder',
          channelDescription: 'Daily reminder to log your alcohol consumption',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
    
    await _addLog('Test notification sent');
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}

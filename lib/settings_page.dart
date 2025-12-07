import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'notification_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isReminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _isLoading = true;
  List<String> _logs = [];
  String _buildVersion = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();
    final logs = await NotificationService().getLogs();
    
    setState(() {
      _isReminderEnabled = prefs.getBool('reminder_enabled') ?? false;
      final hour = prefs.getInt('reminder_hour') ?? 20;
      final minute = prefs.getInt('reminder_minute') ?? 0;
      _reminderTime = TimeOfDay(hour: hour, minute: minute);
      _logs = logs;
      _buildVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      _isLoading = false;
    });
  }

  Future<void> _refreshLogs() async {
    final logs = await NotificationService().getLogs();
    setState(() {
      _logs = logs;
    });
  }

  Future<void> _clearLogs() async {
    await NotificationService().clearLogs();
    await _refreshLogs();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_enabled', _isReminderEnabled);
    await prefs.setInt('reminder_hour', _reminderTime.hour);
    await prefs.setInt('reminder_minute', _reminderTime.minute);

    if (_isReminderEnabled) {
      // Request permissions if enabling for the first time (or re-enabling)
      await NotificationService().requestPermissions();
      await _refreshLogs(); // Refresh to see permission logs
      await NotificationService().scheduleDailyNotification(_reminderTime);
      await _refreshLogs(); // Refresh to see schedule logs
    } else {
      await NotificationService().cancelNotification();
    }
  }



  Future<void> _toggleReminder(bool value) async {
    setState(() {
      _isReminderEnabled = value;
    });
    await _saveSettings();
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked != null && picked != _reminderTime) {
      setState(() {
        _reminderTime = picked;
      });
      await _saveSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('リマインダー通知'),
                  subtitle: const Text('毎日指定した時間に通知を受け取る'),
                  value: _isReminderEnabled,
                  onChanged: _toggleReminder,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                ),
                ListTile(
                  title: const Text('通知時刻'),
                  subtitle: Text(_reminderTime.format(context)),
                  trailing: const Icon(Icons.access_time),
                  enabled: _isReminderEnabled,
                  onTap: _isReminderEnabled ? _selectTime : null,
                ),
                const Divider(),
                ListTile(
                  title: const Text('ビルド情報'),
                  subtitle: Text('バージョン: $_buildVersion'),
                ),
                const Divider(),
                ListTile(
                  title: const Text('通知ログ'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _refreshLogs,
                        tooltip: '更新',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: _clearLogs,
                        tooltip: 'クリア',
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 300,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _logs.isEmpty
                      ? const Center(
                          child: Text(
                            'ログはありません',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                _logs[index],
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Colors.greenAccent,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

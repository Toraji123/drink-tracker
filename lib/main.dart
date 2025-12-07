import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'notification_service.dart';
import 'settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ja_JP', null);
  tz.initializeTimeZones();
  await NotificationService().init();
  runApp(const MyApp());
}

// -----------------------------------------------------------------------------
// Models & Constants
// -----------------------------------------------------------------------------

class DrinkItem {
  final int id;
  final String name;
  final double alcoholAmount; // grams

  const DrinkItem({
    required this.id,
    required this.name,
    required this.alcoholAmount,
  });
}

const List<DrinkItem> kDrinkItems = [
  DrinkItem(id: 1, name: 'ビール/酎ハイ (5%) 350ml', alcoholAmount: 14.0),
  DrinkItem(id: 2, name: 'ビール/酎ハイ (5%) 500ml', alcoholAmount: 20.0),
  DrinkItem(id: 3, name: '酎ハイ (7%) 350ml', alcoholAmount: 19.6),
  DrinkItem(id: 4, name: '酎ハイ (7%) 500ml', alcoholAmount: 28.0),
  DrinkItem(id: 5, name: 'ほろよい系 (3%) 350ml', alcoholAmount: 8.4),
  DrinkItem(id: 6, name: 'ウィスキーシングル (40%) 30ml', alcoholAmount: 9.6),
  DrinkItem(id: 7, name: '日本酒1合 (15%) 180ml', alcoholAmount: 21.6),
  DrinkItem(id: 8, name: '焼酎1合 (25%) 100ml', alcoholAmount: 20.0),
  DrinkItem(id: 9, name: 'ワイングラス1杯 (12%) 120ml', alcoholAmount: 11.5),
];

const Color kBackgroundColor = Color(0xFF121212);
const Color kSurfaceColor = Color(0xFF1E1E1E);
const Color kAccentColor = Color(0xFF009688);
const Color kTextColor = Colors.white;
const Color kSubTextColor = Colors.white70;

// Marker Colors
const Color kMarkerSafe = Colors.green;
const Color kMarkerWarning = Colors.yellow;
const Color kMarkerDanger = Colors.red;
const Color kMarkerRest = Colors.grey;

// -----------------------------------------------------------------------------
// App Entry Point & Theme
// -----------------------------------------------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sobriety Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBackgroundColor,
        colorScheme: const ColorScheme.dark(
          primary: kAccentColor,
          surface: kSurfaceColor,
          onSurface: kTextColor,
        ),
        textTheme: GoogleFonts.notoSansJpTextTheme(ThemeData.dark().textTheme),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: kSurfaceColor,
          modalBackgroundColor: kSurfaceColor,
        ),
      ),
      home: const CalendarScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// Services
// -----------------------------------------------------------------------------

class AlcoholService {
  static const String _prefsKeyPrefix = 'alcohol_record_';

  Future<void> saveRecord(DateTime date, Map<int, int> items) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey(date);
    
    double totalAlcohol = 0;
    items.forEach((id, count) {
      final drink = kDrinkItems.firstWhere((d) => d.id == id, orElse: () => kDrinkItems[0]);
      totalAlcohol += drink.alcoholAmount * count;
    });

    final data = {
      'items': items.map((k, v) => MapEntry(k.toString(), v)), // JSON key must be string
      'totalAlcohol': totalAlcohol,
    };

    await prefs.setString(key, jsonEncode(data));
  }

  Future<Map<String, dynamic>?> getRecord(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey(date);
    final jsonString = prefs.getString(key);
    if (jsonString == null) return null;
    return jsonDecode(jsonString);
  }

  String _getKey(DateTime date) {
    return '$_prefsKeyPrefix${DateFormat('yyyy-MM-dd').format(date)}';
  }
}

// -----------------------------------------------------------------------------
// Main Calendar Screen
// -----------------------------------------------------------------------------

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final AlcoholService _service = AlcoholService();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, double> _alcoholHistory = {};
  
  // Monthly Summary State
  double _monthlyTotal = 0;
  int _monthlyRecords = 0;
  int _monthlySober = 0;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadMonthData(_focusedDay);
  }

  Future<void> _loadMonthData(DateTime month) async {
    // Load data for the displayed month (and a bit before/after to be safe)
    // For simplicity in this demo, we might just load everything or a range.
    // Here we'll just load the current month's data dynamically or check markers on build.
    // However, TableCalendar's eventLoader is synchronous. 
    // So we need to pre-fetch. Let's fetch +/- 60 days from focused day.
    
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('alcohol_record_'));
    
    final newHistory = <DateTime, double>{};
    
    for (var key in keys) {
      final dateStr = key.replaceFirst('alcohol_record_', '');
      try {
        final date = DateFormat('yyyy-MM-dd').parse(dateStr);
        final jsonString = prefs.getString(key);
        if (jsonString != null) {
          final data = jsonDecode(jsonString);
          newHistory[date] = (data['totalAlcohol'] as num).toDouble();
        }
      } catch (e) {
        // ignore malformed keys
      }
    }

    if (mounted) {
      setState(() {
        _alcoholHistory = newHistory;
      });
      _calculateMonthSummary(month);
    }
  }

  void _calculateMonthSummary(DateTime month) {
    double total = 0;
    int records = 0;
    int sober = 0;

    _alcoholHistory.forEach((date, amount) {
      if (date.year == month.year && date.month == month.month) {
        total += amount;
        records++;
        if (amount == 0) {
          sober++;
        }
      }
    });

    setState(() {
      _monthlyTotal = total;
      _monthlyRecords = records;
      _monthlySober = sober;
    });
  }

  List<double> _getEventsForDay(DateTime day) {
    // Normalize date to remove time
    final normalizedDate = DateTime(day.year, day.month, day.day);
    if (_alcoholHistory.containsKey(normalizedDate)) {
      return [_alcoholHistory[normalizedDate]!];
    }
    return [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => InputSheet(
        date: selectedDay,
        service: _service,
      ),
    );

    // Reload data after sheet closes
    _loadMonthData(_focusedDay);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alcohol Tracker'),
        backgroundColor: kBackgroundColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: kTextColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Monthly Summary
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryCard('Total', '${_monthlyTotal.toStringAsFixed(0)}g', ''),
                _buildSummaryCard('Records', '$_monthlyRecords', '日'),
                _buildSummaryCard('Sober', '$_monthlySober', '日'),
              ],
            ),
          ),
          TableCalendar<double>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: _onDaySelected,
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _loadMonthData(focusedDay);
            },
            eventLoader: _getEventsForDay,
            calendarStyle: const CalendarStyle(
              outsideDaysVisible: false,
              defaultTextStyle: TextStyle(color: kTextColor),
              weekendTextStyle: TextStyle(color: kSubTextColor),
              todayDecoration: BoxDecoration(
                color: kAccentColor,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(color: kTextColor, fontSize: 18),
              leftChevronIcon: Icon(Icons.chevron_left, color: kTextColor),
              rightChevronIcon: Icon(Icons.chevron_right, color: kTextColor),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return null;
                final alcohol = events.first;
                Color markerColor;
                if (alcohol == 0) {
                  markerColor = kMarkerRest;
                } else if (alcohol <= 20) {
                  markerColor = kMarkerSafe;
                } else if (alcohol <= 40) {
                  markerColor = kMarkerWarning;
                } else {
                  markerColor = kMarkerDanger;
                }

                return Positioned(
                  bottom: 1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: markerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem(kMarkerRest, '休肝日 (0g)'),
              _buildLegendItem(kMarkerSafe, '適正 (1-20g)'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem(kMarkerWarning, '注意 (21-40g)'),
              _buildLegendItem(kMarkerDanger, '過剰 (41g+)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: kSubTextColor)),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, String unit) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kSubTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: kAccentColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: const TextStyle(
                    color: kSubTextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Input Bottom Sheet
// -----------------------------------------------------------------------------

class InputSheet extends StatefulWidget {
  final DateTime date;
  final AlcoholService service;

  const InputSheet({super.key, required this.date, required this.service});

  @override
  State<InputSheet> createState() => _InputSheetState();
}

class _InputSheetState extends State<InputSheet> {
  Map<int, int> _items = {}; // {itemId: count}
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await widget.service.getRecord(widget.date);
    if (data != null && data['items'] != null) {
      final loadedItems = <int, int>{};
      (data['items'] as Map<String, dynamic>).forEach((k, v) {
        loadedItems[int.parse(k)] = v as int;
      });
      setState(() {
        _items = loadedItems;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateCount(int itemId, int delta) {
    setState(() {
      final current = _items[itemId] ?? 0;
      final next = current + delta;
      if (next <= 0) {
        _items.remove(itemId);
      } else {
        _items[itemId] = next;
      }
    });
  }

  Future<void> _saveAndClose() async {
    await widget.service.saveRecord(widget.date, _items);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _setRestDay() async {
    setState(() {
      _items.clear();
    });
    // Explicitly save as 0g (empty items results in 0g in saveRecord)
    // But we want to distinguish "no record" from "0g".
    // Our logic: saveRecord with empty items -> totalAlcohol = 0.
    // Calendar marker logic: if record exists and totalAlcohol == 0 -> Grey dot.
    // So clearing items and saving is correct for "Rest Day".
    await _saveAndClose();
  }

  double _calculateTotal() {
    double total = 0;
    _items.forEach((id, count) {
      final drink = kDrinkItems.firstWhere((d) => d.id == id);
      total += drink.alcoholAmount * count;
    });
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final totalAlcohol = _calculateTotal();
    final dateStr = DateFormat('M月d日 (E)', 'ja_JP').format(widget.date);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
      child: Column(
        children: [
          // Header
          Text(
            '$dateStr の記録',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            '合計純アルコール量: ${totalAlcohol.toStringAsFixed(1)}g',
            style: TextStyle(
              fontSize: 16,
              color: totalAlcohol > 40 ? kMarkerDanger : kAccentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          // Rest Day Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _setRestDay,
              icon: const Icon(Icons.bedtime, color: Colors.white),
              label: const Text('今日は飲まなかった (休肝日)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Drink List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: kDrinkItems.length,
                    separatorBuilder: (context, index) => const Divider(color: Colors.white12),
                    itemBuilder: (context, index) {
                      final item = kDrinkItems[index];
                      final count = _items[item.id] ?? 0;
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: const TextStyle(fontSize: 16)),
                                Text(
                                  '純アルコール: ${item.alcoholAmount}g',
                                  style: const TextStyle(fontSize: 12, color: kSubTextColor),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _updateCount(item.id, -1),
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
                          ),
                          SizedBox(
                            width: 30,
                            child: Text(
                              '$count',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _updateCount(item.id, 1),
                            icon: const Icon(Icons.add_circle_outline, color: kAccentColor),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          
          // Save Button area
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveAndClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text('保存して閉じる', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

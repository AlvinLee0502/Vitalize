import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class WaterReminderScreen extends StatefulWidget {
  const WaterReminderScreen({super.key});

  @override
  WaterReminderScreenState createState() => WaterReminderScreenState();
}

class WaterReminderScreenState extends State<WaterReminderScreen> {
  FlutterLocalNotificationsPlugin? _notificationsPlugin;
  int _startHour = 8;
  int _endHour = 20;
  int _intervalMinutes = 60;
  bool _isNotificationsEnabled = true;
  bool _isInitialized = false;
  Timer? _countdownTimer;
  Duration _timeUntilNext = Duration.zero;
  DateTime? _nextNotificationTime;
  static bool _timeZoneInitialized = false;

  Color _withAlpha(Color color, int alpha) {
    return Color.fromARGB(
      alpha,
      color.r.toInt(),
      color.g.toInt(),
      color.b.toInt(),
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _showSnackbar(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize timezone data first, if not already initialized
      if (!_timeZoneInitialized) {
        tz_data.initializeTimeZones();
        final String timeZoneName = await _getTimeZoneName();
        try {
          tz.setLocalLocation(tz.getLocation(timeZoneName));
        } catch (e) {
          tz.setLocalLocation(tz.getLocation('UTC'));
          print('Timezone error: $e, defaulting to UTC');
        }
        _timeZoneInitialized = true;
      }

      // Initialize notifications after timezone is set up
      await _initializeNotifications();
      await _loadReminderSettings();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      if (_isNotificationsEnabled) {
        _startCountdownTimer();
      }
    } catch (e) {
      _showSnackbar('Initialization error: $e');
    }
  }

  Future<String> _getTimeZoneName() async {
    try {
      return 'Asia/Singapore';
    } catch (e) {
      return 'UTC';
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();

    final now = DateTime.now();
    if (!_isNotificationsEnabled) {
      setState(() {
        _timeUntilNext = Duration.zero;
      });
      return;
    }

    // Calculate next notification time based on interval
    DateTime nextTime;
    if (now.hour < _startHour) {
      // If current time is before start hour, set next time to start hour
      nextTime = DateTime(now.year, now.month, now.day, _startHour);
    } else if (now.hour >= _endHour) {
      // If current time is after end hour, set next time to start hour of next day
      nextTime = DateTime(now.year, now.month, now.day + 1, _startHour);
    } else {
      // Calculate next interval within the same day
      nextTime = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        (now.minute ~/ (_intervalMinutes)) * _intervalMinutes + _intervalMinutes,
      );

      // If next time would be after end hour, move to next day
      if (nextTime.hour >= _endHour) {
        nextTime = DateTime(now.year, now.month, now.day + 1, _startHour);
      }
    }

    _nextNotificationTime = nextTime;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final currentTime = DateTime.now();
      if (_nextNotificationTime != null) {
        setState(() {
          _timeUntilNext = _nextNotificationTime!.difference(currentTime);
        });

        // Check if countdown reached zero
        if (_timeUntilNext.inSeconds <= 0) {
          // Calculate next notification time
          DateTime newNextTime = _nextNotificationTime!.add(Duration(minutes: _intervalMinutes));

          // If next time would be after end hour, move to next day
          if (newNextTime.hour >= _endHour) {
            newNextTime = DateTime(
              newNextTime.year,
              newNextTime.month,
              newNextTime.day + 1,
              _startHour,
            );
          }

          _nextNotificationTime = newNextTime;
        }
      }
    });
  }

  Future<void> _scheduleNotifications() async {
    if (_notificationsPlugin == null) {
      _showSnackbar('Initializing notifications...');
      await _initializeNotifications();
    }

    try {
      // Cancel any existing notifications first
      await _notificationsPlugin?.cancelAll();

      if (_startHour >= _endHour) {
        _showSnackbar('Start time must be earlier than end time.');
        return;
      }

      if (!_isNotificationsEnabled) {
        debugPrint('Notifications are disabled');
        return;
      }

      final location = tz.getLocation('Asia/Singapore');
      final now = tz.TZDateTime.now(location);
      // Calculate first notification time
      tz.TZDateTime reminderTime = tz.TZDateTime(
        location,
        now.year,
        now.month,
        now.day,
        now.hour,
        (now.minute ~/ _intervalMinutes) * _intervalMinutes + _intervalMinutes,
      );

      // Adjust if current time is outside notification hours
      if (now.hour < _startHour) {
        reminderTime = tz.TZDateTime(location, now.year, now.month, now.day, _startHour);
      } else if (now.hour >= _endHour) {
        reminderTime = tz.TZDateTime(location, now.year, now.month, now.day + 1, _startHour);
      }

      int scheduleCount = 0;
      // Schedule notifications for the next 7 days to ensure coverage
      for (int day = 0; day < 7; day++) {
        tz.TZDateTime currentTime = reminderTime.add(Duration(days: day));

        while (currentTime.hour >= _startHour &&
            currentTime.hour < _endHour &&
            scheduleCount < 100) { // Limit to prevent excessive notifications

          if (currentTime.isAfter(now)) {
            try {
              await _notificationsPlugin!.zonedSchedule(
                currentTime.millisecondsSinceEpoch ~/ 1000,
                'Time to drink water!',
                'Stay hydrated for better health.',
                currentTime,
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'water_reminder',
                    'Water Reminder',
                    priority: Priority.high,
                    importance: Importance.max,
                  ),
                ),
                androidScheduleMode: AndroidScheduleMode.exact, // Added required parameter
                uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
                matchDateTimeComponents: DateTimeComponents.time,
              );
              scheduleCount++;
            } catch (e) {
              print('Error scheduling notification for $currentTime: $e');
              continue;
            }
          }
          currentTime = currentTime.add(Duration(minutes: _intervalMinutes));
        }
      }

      if (scheduleCount > 0) {
        _startCountdownTimer();
        _showSnackbar('Successfully scheduled $scheduleCount notifications');
      } else {
        _showSnackbar('No notifications were scheduled');
      }
    } catch (e) {
      debugPrint('Error in _scheduleNotifications: $e');
      _showSnackbar('Error scheduling notifications: $e');
    }
  }

  Future<void> _initializeNotifications() async {
    try {
      _notificationsPlugin = FlutterLocalNotificationsPlugin();

      // Request notification permissions first
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      _notificationsPlugin?.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();

      const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);

      // Wait for initialization to complete
      final bool? success = await _notificationsPlugin?.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          // Handle notification tap
          debugPrint('Notification tapped: ${details.payload}');
        },
      );

      if (success ?? false) {
        debugPrint('Notifications initialized successfully');
      } else {
        debugPrint('Failed to initialize notifications');
      }
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
      rethrow;
    }
  }

  Future<void> _loadReminderSettings() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      _showSnackbar('User is not authenticated!');
      return;
    }

    try {
      final settingsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('waterReminder')
          .doc('settings');

      final docSnapshot = await settingsRef.get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null && mounted) {
          setState(() {
            _startHour = data['startHour'] ?? 8;
            _endHour = data['endHour'] ?? 20;
            _intervalMinutes = data['intervalMinutes'] ?? 60;
            _isNotificationsEnabled = data['isNotificationsEnabled'] ?? true;
          });
        }
      }
    } catch (e) {
      _showSnackbar('Error loading reminder settings: $e');
    }
  }

  Future<void> _saveReminderSettings() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      _showSnackbar('User is not authenticated!');
      return;
    }

    try {
      // Save settings to Firestore first
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('waterReminder')
          .doc('settings')
          .set({
        'startHour': _startHour,
        'endHour': _endHour,
        'intervalMinutes': _intervalMinutes,
        'isNotificationsEnabled': _isNotificationsEnabled,
      });

      // Handle notifications after saving settings
      if (_isNotificationsEnabled) {
        try {
          await _scheduleNotifications();
          _startCountdownTimer();
        } catch (e) {
          debugPrint('Error scheduling notifications: $e');
          _showSnackbar('Settings saved but notifications failed to schedule: $e');
          return;
        }
      } else {
        await _notificationsPlugin?.cancelAll();
        _countdownTimer?.cancel();
        setState(() {
          _timeUntilNext = Duration.zero;
        });
      }

      _showSnackbar('Settings saved successfully!');
    } catch (e) {
      _showSnackbar('Error saving settings: $e');
    }
  }

  Widget _buildTimeCard(String title, int hour, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: Theme.of(context).primaryColor),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntervalSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(25, 0, 0, 0),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reminder Interval',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.timer, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                '$_intervalMinutes minutes',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Slider(
            min: 15,
            max: 120,
            divisions: 7,
            value: _intervalMinutes.toDouble(),
            onChanged: (value) => setState(() => _intervalMinutes = value.toInt()),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('15m'),
              Text('30m'),
              Text('45m'),
              Text('60m'),
              Text('75m'),
              Text('90m'),
              Text('105m'),
              Text('120m'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnit(int value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color.fromARGB(25, 0, 0, 0),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSeparator() {
    return const Text(
      ':',
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildCountdownTimer() {
    if (!_isNotificationsEnabled || _timeUntilNext == Duration.zero) {
      return const SizedBox.shrink();
    }

    final hours = _timeUntilNext.inHours;
    final minutes = _timeUntilNext.inMinutes.remainder(60);
    final seconds = _timeUntilNext.inSeconds.remainder(60);
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _withAlpha(primaryColor, 204), // 0.8 opacity = 204 alpha
            primaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _withAlpha(primaryColor, 77), // 0.3 opacity = 77 alpha
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Next Reminder In',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimeUnit(hours, 'Hours'),
              _buildTimeSeparator(),
              _buildTimeUnit(minutes, 'Minutes'),
              _buildTimeSeparator(),
              _buildTimeUnit(seconds, 'Seconds'),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        title: const Text('Water Reminder'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor,
                _withAlpha(primaryColor, 204), // 0.8 opacity = 204 alpha
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About Water Reminder'),
                  content: const Text(
                    'Stay hydrated throughout the day with customizable water reminders. '
                        'Set your preferred time range and interval for notifications.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _withAlpha(primaryColor, 26), // 0.1 opacity = 26 alpha
                      _withAlpha(primaryColor, 51), // 0.2 opacity = 51 alpha
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _withAlpha(primaryColor, 51), // 0.2 opacity = 51 alpha
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.water_drop,
                        size: 40,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stay Hydrated',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Set your daily water reminder schedule',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_isNotificationsEnabled) ...[
                _buildCountdownTimer(),
                const SizedBox(height: 24),
              ],

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: _withAlpha(Colors.grey, 26), // 0.1 opacity = 26 alpha
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SwitchListTile(
                  title: const Text(
                    'Enable Reminders',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text('Get notifications to drink water'),
                  value: _isNotificationsEnabled,
                  onChanged: (value) => setState(() => _isNotificationsEnabled = value),
                ),
              ),
              const SizedBox(height: 24),

              if (_isNotificationsEnabled) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeCard(
                        'Start Time',
                        _startHour,
                        Icons.wb_sunny,
                            () async {
                          TimeOfDay? selectedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(hour: _startHour, minute: 0),
                          );
                          if (selectedTime != null) {
                            setState(() => _startHour = selectedTime.hour);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTimeCard(
                        'End Time',
                        _endHour,
                        Icons.nightlight_round,
                            () async {
                          TimeOfDay? selectedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(hour: _endHour, minute: 0),
                          );
                          if (selectedTime != null) {
                            setState(() => _endHour = selectedTime.hour);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                _buildIntervalSelector(),
                const SizedBox(height: 32),
              ],

              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    colors: [
                      primaryColor,
                      _withAlpha(primaryColor, 204), // 0.8 opacity = 204 alpha
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _withAlpha(primaryColor, 77), // 0.3 opacity = 77 alpha
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _saveReminderSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    'Save Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  final String healthProfessionalID;

  const SettingsScreen({super.key, required this.healthProfessionalID});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _darkMode = true;
  String _currency = 'MYR ';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final doc = await FirebaseFirestore.instance
        .collection('healthProfessionals')
        .doc(widget.healthProfessionalID)
        .get();

    if (doc.exists) {
      final settings = doc.data()?['settings'] ?? {};
      setState(() {
        _emailNotifications = settings['emailNotifications'] ?? true;
        _pushNotifications = settings['pushNotifications'] ?? true;
        _darkMode = settings['darkMode'] ?? true;
        _currency = settings['currency'] ?? 'MYR';
      });
    }
  }

  Future<void> _saveSettings() async {
    await FirebaseFirestore.instance
        .collection('healthProfessionals')
        .doc(widget.healthProfessionalID)
        .update({
      'settings': {
        'emailNotifications': _emailNotifications,
        'pushNotifications': _pushNotifications,
        'darkMode': _darkMode,
        'currency': _currency,
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.purple,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Email Notifications'),
            subtitle: const Text('Receive updates via email'),
            value: _emailNotifications,
            onChanged: (bool value) {
              setState(() {
                _emailNotifications = value;
              });
              _saveSettings();
            },
          ),
          SwitchListTile(
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive push notifications'),
            value: _pushNotifications,
            onChanged: (bool value) {
              setState(() {
                _pushNotifications = value;
              });
              _saveSettings();
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Appearance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Toggle dark/light theme'),
            value: _darkMode,
            onChanged: (bool value) {
              setState(() {
                _darkMode = value;
              });
              _saveSettings();
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Regional',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: const Text('Currency'),
            subtitle: Text(_currency),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Select Currency'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: const Text('MYR'),
                          onTap: () {
                            setState(() {
                              _currency = 'MYR';
                            });
                            _saveSettings();
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          title: const Text('SGD'),
                          onTap: () {
                            setState(() {
                              _currency = 'SGD';
                            });
                            _saveSettings();
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          title: const Text('USD'),
                          onTap: () {
                            setState(() {
                              _currency = 'USD';
                            });
                            _saveSettings();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
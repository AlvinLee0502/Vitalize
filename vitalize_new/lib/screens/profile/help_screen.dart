import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  // Launch email client
  Future<void> _launchEmail() async {
    const email = 'mailto:support@example.com?subject=Help%20Request&body=Hi%20Support%2C%0A%0AI%20need%20assistance%20with...';
    if (await canLaunch(email)) {
      await launch(email);
    } else {
      debugPrint('Could not launch $email');
    }
  }

  // Launch phone dialer
  Future<void> _launchPhone() async {
    const phone = 'tel:+123456789';
    if (await canLaunch(phone)) {
      await launch(phone);
    } else {
      debugPrint('Could not launch $phone');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text(
              'FAQs',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const ExpansionTile(
              title: Text('How do I reset my password?'),
              children: [
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('To reset your password, go to the login screen and click "Forgot Password". Follow the instructions sent to your email.'),
                ),
              ],
            ),
            const ExpansionTile(
              title: Text('How can I update my profile?'),
              children: [
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('You can update your profile in the "Profile" section of the app. Click the edit icon to make changes.'),
                ),
              ],
            ),
            const ExpansionTile(
              title: Text('How do I contact support?'),
              children: [
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('You can contact support using the email or phone options below.'),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text(
              'Contact Us',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.email, color: Colors.blue),
              title: const Text('Email Us'),
              subtitle: const Text('support@example.com'),
              onTap: _launchEmail,
            ),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: const Text('Call Us'),
              subtitle: const Text('+1 234 567 89'),
              onTap: _launchPhone,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RedirectHandlingScreen extends StatefulWidget {
  final String redirectUri;

  const RedirectHandlingScreen({super.key, required this.redirectUri});

  @override
  State<RedirectHandlingScreen> createState() => _RedirectHandlingScreenState();
}

class _RedirectHandlingScreenState extends State<RedirectHandlingScreen> {
  bool _isLoading = true;
  String? _authCode;
  String? _error;

  @override
  void initState() {
    super.initState();
    _handleRedirect();
  }

  Future<void> _handleRedirect() async {
    try {
      // Simulate waiting for the redirect (real implementation depends on deep link handling)
      final uri = Uri.parse(widget.redirectUri);
      if (uri.queryParameters.containsKey('code')) {
        final authCode = uri.queryParameters['code'];
        setState(() {
          _authCode = authCode;
          _isLoading = false;
        });
        // Optionally: Exchange auth code for token
        // await _exchangeAuthCode(authCode!);
      } else if (uri.queryParameters.containsKey('error')) {
        setState(() {
          _error = uri.queryParameters['error'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _exchangeAuthCode(String authCode) async {
    // Replace with your backend server's token exchange logic
    final response = await http.post(
      Uri.parse('https://api.fitbit.com/oauth2/token'),
      body: {
        'client_id': 'YOUR_CLIENT_ID',
        'grant_type': 'authorization_code',
        'code': authCode,
        'redirect_uri': 'vitalize://oauthredirect',
      },
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Basic YOUR_BASE64_ENCODED_CREDENTIALS',
      },
    );

    if (response.statusCode == 200) {
      final data = response.body; // Parse the response
      // Save tokens, navigate to the next screen, etc.
    } else {
      throw Exception('Failed to exchange auth code.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Authorization'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _authCode != null
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Authorization Successful!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Authorization Code: $_authCode',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Navigate to the next screen
                Navigator.pushNamed(context, '/home');
              },
              child: const Text('Continue'),
            ),
          ],
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Authorization Failed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'An unknown error occurred.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

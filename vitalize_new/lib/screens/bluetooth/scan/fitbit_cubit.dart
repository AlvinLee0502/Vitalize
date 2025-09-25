import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'health_stats_cubit.dart';
import 'package:intl/intl.dart';

abstract class FitbitState {}

class FitbitInitial extends FitbitState {}
class FitbitAuthenticating extends FitbitState {}
class FitbitAuthenticated extends FitbitState {
  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic> userData;
  FitbitAuthenticated(this.accessToken, this.refreshToken, this.userData);
}
class FitbitError extends FitbitState {
  final String message;
  FitbitError(this.message);
}

class FitbitCubit extends Cubit<FitbitState> {
  final FlutterAppAuth _appAuth = FlutterAppAuth();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _clientId = '23PXDQ';
  static const String _redirectUrl = 'vitalize://oauthredirect';
  static const String _discoveryUrl = 'https://www.fitbit.com/.well-known/oauth-authorization-server';

  FitbitCubit() : super(FitbitInitial());

  String get _dateStr {
    final today = DateTime.now();
    return DateFormat('yyyy-MM-dd').format(today);
  }

  Future<void> authenticateFitbit(BuildContext context) async {
    emit(FitbitAuthenticating());
    final healthStatsCubit = context.read<HealthStatsCubit>();
    try {
      debugPrint('Starting Fitbit authentication...');

      try {
        final result = await _appAuth.authorizeAndExchangeCode(
          AuthorizationTokenRequest(
            _clientId,
            _redirectUrl,
            discoveryUrl: _discoveryUrl,
            scopes: ['activity', 'heartrate'],
            promptValues: ['login', 'consent'],
            additionalParameters: {
              'expires_in': '31536000',
            },
          ),
        );

        if (result.accessToken == null) {
          throw Exception('No access token received');
        }

        await _handleAuthenticationSuccess(result, healthStatsCubit);
      } catch (discoveryError) {
        debugPrint('Discovery authentication failed, trying manual configuration: $discoveryError');

        final fallbackResult = await _appAuth.authorizeAndExchangeCode(
          AuthorizationTokenRequest(
            _clientId,
            _redirectUrl,
            serviceConfiguration: const AuthorizationServiceConfiguration(
              authorizationEndpoint: 'https://www.fitbit.com/oauth2/authorize',
              tokenEndpoint: 'https://api.fitbit.com/oauth2/token',
            ),
            scopes: ['activity', 'heartrate'],
            promptValues: ['login', 'consent'],
            additionalParameters: {
              'expires_in': '31536000',
            },
          ),
        );

        if (fallbackResult.accessToken == null) {
          throw Exception('Failed to authenticate: No access token received');
        }

        await _handleAuthenticationSuccess(fallbackResult, healthStatsCubit);
      }

    } catch (e, stackTrace) {
      debugPrint('Authentication error: $e');
      debugPrint('Stack trace: $stackTrace');
      emit(FitbitError('Authentication failed. Please try again. Error: ${e.toString()}'));
    }
  }

  Future<void> _handleAuthenticationSuccess(
      AuthorizationTokenResponse response,
      HealthStatsCubit healthStatsCubit,
      ) async {
    try {
      await _saveTokens(
        response.accessToken!,
        response.refreshToken!,
        response.accessTokenExpirationDateTime!,
      );

      final userData = await _fetchFitbitData(response.accessToken!);

      healthStatsCubit.updateFromFitbit(userData);

      emit(FitbitAuthenticated(
        response.accessToken!,
        response.refreshToken!,
        userData,
      ));

      debugPrint('Authentication completed successfully');
    } catch (e) {
      debugPrint('Error handling authentication success: $e');
      emit(FitbitError('Error processing authentication: ${e.toString()}'));
    }
  }

  Future<Map<String, dynamic>> fetchFitbitData() async {
    if (state is FitbitAuthenticated) {
      final authenticatedState = state as FitbitAuthenticated;
      return _fetchFitbitData(authenticatedState.accessToken);
    } else {
      throw Exception('Not authenticated with Fitbit');
    }
  }

  Future<Map<String, dynamic>> _fetchFitbitData(String accessToken) async {
    final activityResponse = await http.get(
      Uri.parse('https://api.fitbit.com/1/user/-/activities/date/$_dateStr.json'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    final heartRateResponse = await http.get(
      Uri.parse('https://api.fitbit.com/1/user/-/activities/heart/date/$_dateStr/1d.json'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (activityResponse.statusCode == 200 && heartRateResponse.statusCode == 200) {
      final activityData = json.decode(activityResponse.body);
      final heartRateData = json.decode(heartRateResponse.body);

      return {
        'steps': activityData['summary']['steps'] ?? 0,
        'calories': activityData['summary']['caloriesOut'] ?? 0,
        'heartRate': _extractLatestHeartRate(heartRateData) ?? 0,
      };
    } else {
      throw Exception('Failed to fetch Fitbit data');
    }
  }

  int? _extractLatestHeartRate(Map<String, dynamic> heartRateData) {
    try {
      final activities = heartRateData['activities-heart-intraday']['dataset'] as List;
      if (activities.isNotEmpty) {
        return activities.last['value'] as int;
      }
    } catch (e) {
      debugPrint('Error extracting heart rate: $e');
    }
    return null;
  }

  Future<void> _saveTokens(
      String accessToken,
      String refreshToken,
      DateTime expiresAt,
      ) async {
    try {
      await _firestore.collection('fitbit_tokens').doc('current_user').set({
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving tokens: $e');
      throw Exception('Failed to save tokens: $e');
    }
  }
}
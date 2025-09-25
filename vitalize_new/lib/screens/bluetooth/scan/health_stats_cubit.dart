import 'package:flutter_bloc/flutter_bloc.dart';

abstract class HealthStatsState {}

class HealthStatsInitial extends HealthStatsState {}

class HealthStatsLoading extends HealthStatsState {}

class HealthStatsLoaded extends HealthStatsState {
  final String formattedSteps;
  final String formattedCalories;
  final String formattedHeartRate;
  final String source;

  HealthStatsLoaded({
    required this.formattedSteps,
    required this.formattedCalories,
    required this.formattedHeartRate,
    required this.source,
  });
}

class HealthStatsError extends HealthStatsState {
  final String message;
  HealthStatsError(this.message);
}

class HealthStatsCubit extends Cubit<HealthStatsState> {
  HealthStatsCubit() : super(HealthStatsInitial());

  int _steps = 0;
  int _calories = 0;
  int _heartRate = 0;
  String _currentSource = '';

  void updateFromFitbit(Map<String, dynamic> fitbitData) {
    emit(HealthStatsLoading());

    emit(HealthStatsLoaded(
      formattedSteps: formatNumber(fitbitData['steps']),
      formattedCalories: formatNumber(fitbitData['calories']),
      formattedHeartRate: fitbitData['heartRate'].toString(),
      source: 'fitbit',
    ));
  }


  void updateFromHealthConnect(List<Map<String, dynamic>> healthConnectData) {
    try {
      emit(HealthStatsLoading());

      if (healthConnectData.isNotEmpty) {
        _steps = healthConnectData.fold<int>(
          0,
              (sum, data) => sum + (data['value'] as int? ?? 0),
        );
      }

      // Assuming HealthConnectData includes calories and heart rate
      if (healthConnectData.isNotEmpty) {
        _calories = healthConnectData.fold<int>(
          0,
              (sum, data) => sum + (data['calories'] as int? ?? 0),
        );
        _heartRate = healthConnectData.fold<int>(
          0,
              (sum, data) => sum + (data['heartRate'] as int? ?? 0),
        );
      }

      _currentSource = 'healthconnect';

      emit(HealthStatsLoaded(
        formattedSteps: formatNumber(_steps),
        formattedCalories: formatNumber(_calories),
        formattedHeartRate: _heartRate.toString(),
        source: _currentSource,
      ));
    } catch (e) {
      emit(HealthStatsError('Failed to update HealthConnect data: $e'));
    }
  }

  String formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }
}

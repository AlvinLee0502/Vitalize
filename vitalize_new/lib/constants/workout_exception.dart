class WorkoutException implements Exception {
  final String message;
  final dynamic error;

  WorkoutException(this.message, [this.error]);

  @override
  String toString() => 'WorkoutException: $message${error != null ? ' ($error)' : ''}';
}
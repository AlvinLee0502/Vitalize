class UserProfile {
  final String userId;
  final double dailyCalorieGoal;
  final double dailyProteinGoal;
  final double dailyCarbsGoal;
  final double dailyFatsGoal;
  final String name;

  UserProfile({
    required this.userId,
    required this.dailyCalorieGoal,
    required this.dailyProteinGoal,
    required this.dailyCarbsGoal,
    required this.dailyFatsGoal,
    required this.name,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] ?? '',
      dailyCalorieGoal: (json['daily_calorie_goal'] ?? 0).toDouble(),
      dailyProteinGoal: (json['daily_protein_goal'] ?? 0).toDouble(),
      dailyCarbsGoal: (json['daily_carbs_goal'] ?? 0).toDouble(),
      dailyFatsGoal: (json['daily_fats_goal'] ?? 0).toDouble(),
      name: json['name'] ?? '',
    );
  }

  bool isIncomplete() {
    return dailyCalorieGoal == 0 ||
        dailyProteinGoal == 0 ||
        dailyCarbsGoal == 0 ||
        dailyFatsGoal == 0;
  }
}
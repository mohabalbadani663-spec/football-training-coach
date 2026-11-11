enum UserRole { coach, player }

enum ExerciseCategory { technical, physical, tactical, cognitive }

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.objective,
    required this.category,
    required this.duration,
    required this.age,
    required this.players,
    required this.difficulty,
    required this.space,
    required this.equipment,
    required this.description,
    required this.instructions,
    required this.coachingPoints,
    required this.progression,
    required this.regression,
    required this.color,
    this.diagramUrl,
    this.videoUrl,
  });

  final String id;
  final String name;
  final String nameEn;
  final String objective;
  final ExerciseCategory category;
  final int duration;
  final String age;
  final String players;
  final String difficulty;
  final String space;
  final String equipment;
  final String description;
  final List<String> instructions;
  final List<String> coachingPoints;
  final String progression;
  final String regression;
  final int color;
  final String? diagramUrl;
  final String? videoUrl;
}

class TrainingSession {
  TrainingSession({
    required this.id,
    required this.title,
    required this.team,
    required this.objective,
    required this.duration,
    required this.date,
    required this.exercises,
    this.teamId,
    this.notes = '',
    this.completed = false,
  });

  final String id;
  String? teamId;
  String title;
  String team;
  String objective;
  int duration;
  DateTime date;
  List<Exercise> exercises;
  String notes;
  bool completed;
}

class WeeklyPlan {
  WeeklyPlan({
    required this.id,
    required this.teamId,
    required this.weekStart,
    required this.dayIndex,
    required this.title,
    required this.objective,
    this.sessionId,
    this.notes = '',
  });

  final String id;
  final String teamId;
  final DateTime weekStart;
  final int dayIndex;
  String title;
  String objective;
  String? sessionId;
  String notes;
}

class PlayerProgress {
  const PlayerProgress({
    required this.skillKey,
    required this.skillLabel,
    required this.progress,
  });

  final String skillKey;
  final String skillLabel;
  final int progress;
}

class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.xpReward,
    this.progress = 0,
    this.completed = false,
  });

  final String id;
  final String title;
  final String description;
  final int target;
  final int xpReward;
  final int progress;
  final bool completed;
}

class Player {
  Player({
    required this.id,
    required this.name,
    required this.position,
    required this.age,
    required this.level,
    this.notes = '',
    this.evaluations = const {},
  });

  final String id;
  String name;
  String position;
  int age;
  String level;
  String notes;
  Map<String, int> evaluations;
}

extension ExerciseCategoryLabel on ExerciseCategory {
  String get label {
    switch (this) {
      case ExerciseCategory.technical:
        return 'تقني';
      case ExerciseCategory.physical:
        return 'بدني';
      case ExerciseCategory.tactical:
        return 'تكتيكي';
      case ExerciseCategory.cognitive:
        return 'ذهني';
    }
  }
}

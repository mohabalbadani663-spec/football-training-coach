import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/demo_data.dart';
import '../models/app_models.dart';
import '../models/tenant_models.dart';

abstract class TrainingRepository {
  String? get currentUserId;
  Future<Organization?> fetchMyOrganization();
  Future<List<TeamInfo>> fetchCoachTeams();
  Future<void> invitePlayer({required String teamId, required String email});
  Future<String?> resolveCurrentTeamId();
  Future<List<Exercise>> fetchExercises();
  Future<List<TrainingSession>> fetchCoachSessions(String coachId);
  Future<List<TrainingSession>> fetchPlayerSessions(String playerId);
  Future<List<Player>> fetchTeamPlayers(String teamId);
  Future<String?> joinTeamByCode(String code);
  Future<void> saveSession({
    required String coachId,
    required TrainingSession session,
    String? teamId,
  });
  Future<List<WeeklyPlan>> fetchWeeklyPlans({required String teamId, required DateTime weekStart});
  Future<void> saveWeeklyPlan(WeeklyPlan plan);
  Future<void> deleteWeeklyPlan(String planId);
  Future<void> recordSessionCompletion({required String sessionId, required int durationSeconds, required int exercisesCompleted});
  Future<void> syncPending();
  Future<List<PlayerProgress>> fetchPlayerProgress(String playerId);
  Future<void> savePlayerProgress({
    required String playerId,
    required PlayerProgress progress,
  });
  Future<List<Challenge>> fetchPlayerChallenges(String playerId);
  Future<void> saveChallengeProgress({
    required String playerId,
    required String challengeId,
    required int progress,
    required bool completed,
  });
}

class LocalTrainingRepository implements TrainingRepository {
  @override
  String? get currentUserId => 'local-user';

  @override
  Future<Organization?> fetchMyOrganization() async =>
      const Organization(id: 'local-org', name: 'أكاديمية تجريبية', slug: 'demo');

  @override
  Future<List<TeamInfo>> fetchCoachTeams() async => const [
        TeamInfo(id: 'local-team', organizationId: 'local-org', name: 'U13 النخبة', ageGroup: 'U13', level: 'متوسط', memberCount: 18, joinCode: 'DEMO1234'),
      ];

  @override
  Future<String?> resolveCurrentTeamId() async => 'local-team';

  @override
  Future<void> invitePlayer({required String teamId, required String email}) async {}

  @override
  Future<List<Exercise>> fetchExercises() async => List.of(demoExercises);

  @override
  Future<List<TrainingSession>> fetchCoachSessions(String coachId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('training_sessions_cache');
    if (raw == null || raw.isEmpty) return List.of(demoSessions);
    try {
      final cached = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return cached.map(_localSessionFromMap).toList();
    } catch (_) {
      return List.of(demoSessions);
    }
  }

  @override
  Future<List<TrainingSession>> fetchPlayerSessions(String playerId) async =>
      List.of(demoSessions);

  @override
  Future<List<Player>> fetchTeamPlayers(String teamId) async => List.of(demoPlayers);

  @override
  Future<String?> joinTeamByCode(String code) async =>
      code.trim().isEmpty ? null : 'local-team';

  @override
  Future<void> saveSession({
    required String coachId,
    required TrainingSession session,
    String? teamId,
  }) async {
    final index = demoSessions.indexWhere((item) => item.id == session.id);
    if (index == -1) {
      demoSessions.insert(0, session);
    } else {
      demoSessions[index] = session;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'training_sessions_cache',
      jsonEncode(demoSessions.map(_localSessionToMap).toList()),
    );
  }

  @override
  Future<List<WeeklyPlan>> fetchWeeklyPlans({required String teamId, required DateTime weekStart}) async => const [];

  @override
  Future<void> saveWeeklyPlan(WeeklyPlan plan) async {}

  @override
  Future<void> deleteWeeklyPlan(String planId) async {}

  @override
  Future<void> recordSessionCompletion({required String sessionId, required int durationSeconds, required int exercisesCompleted}) async {}

  @override
  Future<void> syncPending() async {}

  @override
  Future<List<PlayerProgress>> fetchPlayerProgress(String playerId) async => const [
        PlayerProgress(skillKey: 'control', skillLabel: 'السيطرة على الكرة', progress: 78),
        PlayerProgress(skillKey: 'speed', skillLabel: 'السرعة والرشاقة', progress: 64),
        PlayerProgress(skillKey: 'finishing', skillLabel: 'الإنهاء', progress: 52),
      ];

  @override
  Future<void> savePlayerProgress({
    required String playerId,
    required PlayerProgress progress,
  }) async {}

  @override
  Future<List<Challenge>> fetchPlayerChallenges(String playerId) async => const [
        Challenge(
          id: 'weekly-three',
          title: 'أكمل 3 حصص هذا الأسبوع',
          description: 'حافظ على استمراريتك التدريبية.',
          target: 3,
          xpReward: 120,
          progress: 2,
        ),
      ];

  @override
  Future<void> saveChallengeProgress({
    required String playerId,
    required String challengeId,
    required int progress,
    required bool completed,
  }) async {}

  Map<String, dynamic> _localSessionToMap(TrainingSession session) => {
        'id': session.id,
        'title': session.title,
        'team': session.team,
        'teamId': session.teamId,
        'objective': session.objective,
        'duration': session.duration,
        'date': session.date.toIso8601String(),
        'exerciseIds': session.exercises.map((exercise) => exercise.id).toList(),
        'notes': session.notes,
        'completed': session.completed,
      };

  TrainingSession _localSessionFromMap(Map<String, dynamic> row) {
    final ids = (row['exerciseIds'] as List<dynamic>? ?? const []).cast<String>();
    final exercises = demoExercises.where((exercise) => ids.contains(exercise.id)).toList();
    return TrainingSession(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      team: row['team'] as String? ?? '',
      teamId: row['teamId'] as String?,
      objective: row['objective'] as String? ?? '',
      duration: row['duration'] as int? ?? 60,
      date: DateTime.tryParse(row['date'] as String? ?? '') ?? DateTime.now(),
      exercises: exercises,
      notes: row['notes'] as String? ?? '',
      completed: row['completed'] as bool? ?? false,
    );
  }
}

class SupabaseTrainingRepository implements TrainingRepository {
  SupabaseTrainingRepository(this.client);

  final SupabaseClient client;

  String get _userId => client.auth.currentUser?.id ??
      (throw StateError('يجب تسجيل الدخول أولًا.'));

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  Future<Organization?> fetchMyOrganization() async {
    final rows = await client.rpc('my_organization');
    if (rows is! List || rows.isEmpty) return null;
    final row = Map<String, dynamic>.from(rows.first as Map);
    return Organization(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      slug: row['slug'] as String? ?? '',
    );
  }

  @override
  Future<List<TeamInfo>> fetchCoachTeams() async {
    final rows = await client
        .from('teams')
        .select('id, organization_id, name, age_group, level, join_code, team_members(count)')
        .eq('coach_id', _userId)
        .order('created_at');
    return rows.map((row) {
      final counts = row['team_members'] as List<dynamic>? ?? const [];
      final count = counts.isEmpty ? 0 : ((counts.first as Map)['count'] as int? ?? 0);
      return TeamInfo(
        id: row['id'] as String,
        organizationId: row['organization_id'] as String? ?? '',
        name: row['name'] as String? ?? '',
        ageGroup: row['age_group'] as String?,
        level: row['level'] as String?,
        memberCount: count,
        joinCode: row['join_code'] as String?,
      );
    }).toList();
  }

  @override
  Future<String?> resolveCurrentTeamId() async {
    final teams = await fetchCoachTeams();
    return teams.isEmpty ? null : teams.first.id;
  }

  @override
  Future<String?> joinTeamByCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw ArgumentError('أدخل رمز الفريق.');
    }
    final result = await client.rpc(
      'join_team_by_code',
      params: {'p_code': normalized},
    );
    return result?.toString();
  }

  @override
  Future<void> invitePlayer({required String teamId, required String email}) async {
    final normalized = email.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
      throw ArgumentError('أدخل بريدًا إلكترونيًا صحيحًا.');
    }
    final team = await client
        .from('teams')
        .select('organization_id')
        .eq('id', teamId)
        .eq('coach_id', _userId)
        .maybeSingle();
    if (team == null || team['organization_id'] == null) {
      throw StateError('الفريق غير متاح لهذا الحساب.');
    }
    final invitation = {
      'organization_id': team['organization_id'],
      'team_id': teamId,
      'email': normalized,
      'invited_by': _userId,
      'status': 'pending',
      'expires_at': DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String(),
    };
    final existing = await client
        .from('team_invitations')
        .select('id')
        .eq('team_id', teamId)
        .ilike('email', normalized)
        .maybeSingle();
    if (existing == null) {
      await client.from('team_invitations').insert(invitation);
    } else {
      await client
          .from('team_invitations')
          .update(invitation)
          .eq('id', existing['id']);
    }
  }

  @override
  Future<List<Exercise>> fetchExercises() async {
    final rows = await client.from('exercises').select().order('name');
    return rows.map(_exerciseFromRow).toList();
  }

  @override
  Future<List<TrainingSession>> fetchCoachSessions(String coachId) async {
    final rows = await client
        .from('training_sessions')
        .select('*, teams(name), session_exercises(sort_order, duration_minutes, exercises(*))')
        .eq('coach_id', _userId)
        .order('scheduled_for', ascending: false);
    return Future.wait(rows.map(_sessionFromRow));
  }

  @override
  Future<List<TrainingSession>> fetchPlayerSessions(String playerId) async {
    // Never trust a caller-provided player id. The authenticated Supabase user
    // is the only identity allowed for player-scoped reads. RLS is the final
    // enforcement layer, while this guard keeps the client contract honest.
    if (playerId.isNotEmpty && playerId != _userId) return const [];
    final memberships = await client
        .from('team_members')
        .select('team_id')
        .eq('player_id', _userId);
    final teamIds = memberships.map((row) => row['team_id'] as String).toList();
    if (teamIds.isEmpty) return const [];
    final rows = await client
        .from('training_sessions')
        .select('*, teams(name), session_exercises(sort_order, duration_minutes, exercises(*))')
        .inFilter('team_id', teamIds)
        .order('scheduled_for', ascending: false);
    return Future.wait(rows.map(_sessionFromRow));
  }

  @override
  Future<List<Player>> fetchTeamPlayers(String teamId) async {
    var selectedTeamId = teamId;
    if (teamId == 'current-team' || teamId.isEmpty) {
      selectedTeamId = await resolveCurrentTeamId() ?? '';
    }
    if (selectedTeamId.isEmpty) return const [];
    final rows = await client
        .from('team_members')
        .select('player_id, profiles(*)')
        .eq('team_id', selectedTeamId);
    return rows
        .where((row) => row['profiles'] is Map)
        .map((row) => _playerFromRow(Map<String, dynamic>.from(row['profiles'] as Map)))
        .toList();
  }

  @override
  Future<List<WeeklyPlan>> fetchWeeklyPlans({required String teamId, required DateTime weekStart}) async {
    final rows = await client
        .from('weekly_plans')
        .select()
        .eq('team_id', teamId)
        .eq('week_start', DateTime(weekStart.year, weekStart.month, weekStart.day).toIso8601String().split('T').first)
        .order('day_index');
    return rows.map((row) => WeeklyPlan(
      id: row['id'] as String,
      teamId: row['team_id'] as String,
      weekStart: DateTime.parse(row['week_start'] as String),
      dayIndex: row['day_index'] as int,
      title: row['title'] as String? ?? '',
      objective: row['objective'] as String? ?? '',
      sessionId: row['session_id'] as String?,
      notes: row['notes'] as String? ?? '',
    )).toList();
  }

  @override
  Future<void> saveWeeklyPlan(WeeklyPlan plan) async {
    await client.from('weekly_plans').upsert({
      'id': plan.id,
      'team_id': plan.teamId,
      'coach_id': _userId,
      'week_start': DateTime(plan.weekStart.year, plan.weekStart.month, plan.weekStart.day).toIso8601String().split('T').first,
      'day_index': plan.dayIndex,
      'title': plan.title,
      'objective': plan.objective,
      'session_id': plan.sessionId,
      'notes': plan.notes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> deleteWeeklyPlan(String planId) async {
    await client.from('weekly_plans').delete().eq('id', planId);
  }

  @override
  Future<void> recordSessionCompletion({required String sessionId, required int durationSeconds, required int exercisesCompleted}) async {
    await client.from('training_completions').upsert({
      'session_id': sessionId,
      'player_id': _userId,
      'duration_seconds': durationSeconds,
      'exercises_completed': exercisesCompleted,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> syncPending() async {
    // Never block or crash application startup because of queued offline data.
    if (client.auth.currentUser == null) return;

    try {
      final pending = await _PendingSessionStore.read();
      if (pending.isEmpty) return;

      final remaining = <Map<String, dynamic>>[];
      for (final payload in pending) {
        try {
          await _savePayload(payload);
        } catch (_) {
          remaining.add(payload);
        }
      }
      await _PendingSessionStore.replace(remaining);
    } catch (_) {
      // Queue errors are intentionally isolated from the app bootstrap.
    }
  }

  @override
  Future<List<PlayerProgress>> fetchPlayerProgress(String playerId) async {
    if (playerId.isNotEmpty && playerId != _userId) return const [];
    final rows = await client
        .from('player_progress')
        .select()
        .eq('player_id', _userId)
        .order('skill_key');
    return rows
        .map(
          (row) => PlayerProgress(
            skillKey: row['skill_key'] as String,
            skillLabel: row['skill_label'] as String? ?? '',
            progress: row['progress'] as int? ?? 0,
          ),
        )
        .toList();
  }

  @override
  Future<void> savePlayerProgress({
    required String playerId,
    required PlayerProgress progress,
  }) async {
    await client.from('player_progress').upsert({
      'player_id': _userId,
      'skill_key': progress.skillKey,
      'skill_label': progress.skillLabel,
      'progress': progress.progress,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<Challenge>> fetchPlayerChallenges(String playerId) async {
    final rows = await client
        .from('challenges')
        .select('id, title, description, target, xp_reward, ends_at, player_challenges(progress, completed)')
        .or('ends_at.is.null,ends_at.gte.${DateTime.now().toIso8601String()}')
        .order('created_at', ascending: false);
    return rows.map((row) {
      final linked = (row['player_challenges'] as List<dynamic>? ?? const []);
      final state = linked.isEmpty
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(linked.first as Map);
      return Challenge(
        id: row['id'] as String,
        title: row['title'] as String? ?? '',
        description: row['description'] as String? ?? '',
        target: row['target'] as int? ?? 1,
        xpReward: row['xp_reward'] as int? ?? 0,
        progress: state['progress'] as int? ?? 0,
        completed: state['completed'] as bool? ?? false,
      );
    }).toList();
  }

  @override
  Future<void> saveChallengeProgress({
    required String playerId,
    required String challengeId,
    required int progress,
    required bool completed,
  }) async {
    await client.from('player_challenges').upsert({
      'player_id': _userId,
      'challenge_id': challengeId,
      'progress': progress,
      'completed': completed,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> saveSession({
    required String coachId,
    required TrainingSession session,
    String? teamId,
  }) async {
    final payload = await _sessionPayload(teamId: teamId, session: session);
    try {
      await _savePayload(payload);
    } on PostgrestException {
      rethrow;
    } catch (_) {
      await _PendingSessionStore.enqueue(payload);
    }
  }

  Future<Map<String, dynamic>> _sessionPayload({
    required String? teamId,
    required TrainingSession session,
  }) async {
    final requestedTeamId = teamId ?? session.teamId;
    final resolvedTeamId = requestedTeamId == 'current-team' || requestedTeamId == null || requestedTeamId.isEmpty
        ? await resolveCurrentTeamId()
        : requestedTeamId;
    final org = await fetchMyOrganization();
    if (org == null) throw StateError('لم يتم العثور على الأكاديمية المرتبطة بالحساب.');
    return {
      'id': session.id,
      'coach_id': _userId,
      'organization_id': org.id,
      'team_id': resolvedTeamId,
      'title': session.title,
      'objective': session.objective,
      'duration_minutes': session.duration,
      'scheduled_for': session.date.toIso8601String(),
      'notes': session.notes,
      'completed': session.completed,
      'updated_at': DateTime.now().toIso8601String(),
      'exercise_ids': session.exercises.map((exercise) => exercise.id).toList(),
      'exercise_durations': session.exercises.map((exercise) => exercise.duration).toList(),
    };
  }

  Future<void> _savePayload(Map<String, dynamic> payload) async {
    await client.from('training_sessions').upsert({
      'id': payload['id'],
      'coach_id': payload['coach_id'],
      'organization_id': payload['organization_id'],
      'team_id': payload['team_id'],
      'title': payload['title'],
      'objective': payload['objective'],
      'duration_minutes': payload['duration_minutes'],
      'scheduled_for': payload['scheduled_for'],
      'notes': payload['notes'],
      'completed': payload['completed'],
      'updated_at': payload['updated_at'],
    });

    await client.from('session_exercises').delete().eq('session_id', payload['id']);
    final ids = (payload['exercise_ids'] as List<dynamic>? ?? const []);
    final durations = (payload['exercise_durations'] as List<dynamic>? ?? const []);
    if (ids.isNotEmpty) {
      await client.from('session_exercises').insert([
        for (var index = 0; index < ids.length; index++)
          {
            'session_id': payload['id'],
            'exercise_id': ids[index],
            'sort_order': index,
            'duration_minutes': durations[index],
          },
      ]);
    }
  }

  Exercise _exerciseFromRow(Map<String, dynamic> row) {
    final categoryName = row['category'] as String? ?? 'technical';
    final category = ExerciseCategory.values.firstWhere(
      (item) => item.name == categoryName,
      orElse: () => ExerciseCategory.technical,
    );
    return Exercise(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      nameEn: row['name_en'] as String? ?? '',
      objective: row['objective'] as String? ?? '',
      category: category,
      duration: row['duration_minutes'] as int? ?? 10,
      age: row['age'] as String? ?? '',
      players: row['players'] as String? ?? '',
      difficulty: row['difficulty'] as String? ?? '',
      space: row['space'] as String? ?? '',
      equipment: row['equipment'] as String? ?? '',
      description: row['description'] as String? ?? '',
      instructions: _stringList(row['instructions']),
      coachingPoints: _stringList(row['coaching_points']),
      progression: row['progression'] as String? ?? '',
      regression: row['regression'] as String? ?? '',
      color: row['color'] as int? ?? 0xFF1F9D67,
      diagramUrl: row['diagram_url'] as String?,
      videoUrl: row['video_url'] as String?,
    );
  }

  Future<TrainingSession> _sessionFromRow(Map<String, dynamic> row) async {
    final linked = (row['session_exercises'] as List<dynamic>? ?? const [])
        .where((item) => item is Map && item['exercises'] is Map)
        .toList()
      ..sort((a, b) => ((a as Map)['sort_order'] as int? ?? 0)
          .compareTo((b as Map)['sort_order'] as int? ?? 0));
    final exercises = linked
        .map((item) => _exerciseFromRow(Map<String, dynamic>.from((item as Map)['exercises'] as Map)))
        .toList();
    final team = row['teams'] is Map ? Map<String, dynamic>.from(row['teams'] as Map) : null;
    return TrainingSession(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      team: team?['name'] as String? ?? '',
      teamId: row['team_id'] as String?,
      objective: row['objective'] as String? ?? '',
      duration: row['duration_minutes'] as int? ?? 60,
      date: DateTime.tryParse(row['scheduled_for'] as String? ?? '') ?? DateTime.now(),
      exercises: exercises,
      notes: row['notes'] as String? ?? '',
      completed: row['completed'] as bool? ?? false,
    );
  }

  Player _playerFromRow(Map<String, dynamic> row) => Player(
        id: row['id'] as String,
        name: row['full_name'] as String? ?? '',
        position: row['position'] as String? ?? '',
        age: row['age'] as int? ?? 0,
        level: row['level'] as String? ?? '',
      );

  List<String> _stringList(dynamic value) =>
      value is List ? value.map((item) => item.toString()).toList() : const [];
}

class _PendingSessionStore {
  static const _key = 'pending_session_sync_queue';

  static Future<List<Map<String, dynamic>>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> enqueue(Map<String, dynamic> payload) async {
    final items = await read();
    items.removeWhere((item) => item['id'] == payload['id']);
    items.add(payload);
    await replace(items);
  }

  static Future<void> replace(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items));
  }
}

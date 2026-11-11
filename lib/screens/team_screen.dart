import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../models/tenant_models.dart';
import '../services/data_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key, required this.repository});

  final TrainingRepository repository;

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  String query = '';
  late Future<List<TeamInfo>> teamsFuture;

  @override
  void initState() {
    super.initState();
    teamsFuture = widget.repository.fetchCoachTeams();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TeamInfo>>(
      future: teamsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
          return const EmptyState(
            title: 'لا يوجد فريق بعد',
            description: 'أكمل إعداد الأكاديمية لإنشاء أول فريق.',
            icon: Icons.groups_outlined,
          );
        }
        final team = snapshot.data!.first;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.13),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_rounded, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(team.name, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 5),
                        Text('${team.memberCount} لاعبًا  •  ${team.ageGroup ?? 'غير محدد'}  •  ${team.level ?? 'غير محدد'}', style: Theme.of(context).textTheme.bodyMedium),
                        if (team.joinCode != null) ...[
                          const SizedBox(height: 6),
                          Text('رمز الانضمام: ${team.joinCode}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(child: MiniStat(value: '${team.memberCount}', label: 'إجمالي اللاعبين', icon: Icons.groups_rounded)),
                const SizedBox(width: 10),
                Expanded(child: MiniStat(value: team.ageGroup ?? '-', label: 'الفئة العمرية', icon: Icons.cake_outlined, color: AppColors.info)),
              ],
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(child: Text('قائمة اللاعبين', style: Theme.of(context).textTheme.titleLarge)),
                SecondaryButton(label: 'دعوة لاعب', icon: Icons.person_add_alt_1_rounded, onPressed: () => _showAddPlayer(context, team.id)),
              ],
            ),
            const SizedBox(height: 13),
            TextField(
              onChanged: (value) => setState(() => query = value.trim()),
              decoration: const InputDecoration(hintText: 'ابحث بالاسم أو المركز...', prefixIcon: Icon(Icons.search_rounded)),
            ),
            const SizedBox(height: 14),
            _TeamPlayers(repository: widget.repository, query: query, onPlayerTap: (player) => _showPlayerDetails(context, player)),
          ],
        );
      },
    );
  }

  void _showAddPlayer(BuildContext context, String teamId) {
    final emailController = TextEditingController();
    var sending = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(5)))),
              const SizedBox(height: 22),
              Text('دعوة لاعب', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('سيُضاف اللاعب للفريق تلقائيًا بعد إنشاء حسابه بهذا البريد.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 18),
              TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined))),
              const SizedBox(height: 18),
              PrimaryButton(
                label: sending ? 'جارٍ إرسال الدعوة...' : 'إرسال الدعوة',
                icon: Icons.send_rounded,
                onPressed: sending ? null : () async {
                  setSheetState(() => sending = true);
                  try {
                    await widget.repository.invitePlayer(teamId: teamId, email: emailController.text);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('تم تسجيل الدعوة بنجاح.')));
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  } finally {
                    if (context.mounted) setSheetState(() => sending = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlayerDetails(BuildContext context, Player player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${player.position}  •  ${player.age} سنة  •  ${player.level}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            Text(
              'التقييم الأساسي',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 15),
            ...player.evaluations.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      child: ProgressBar(
                        value: entry.value / 100,
                        color: entry.value > 80
                            ? AppColors.primary
                            : AppColors.info,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${entry.value}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamPlayers extends StatefulWidget {
  const _TeamPlayers({
    required this.repository,
    required this.query,
    required this.onPlayerTap,
  });

  final TrainingRepository repository;
  final String query;
  final ValueChanged<Player> onPlayerTap;

  @override
  State<_TeamPlayers> createState() => _TeamPlayersState();
}

class _TeamPlayersState extends State<_TeamPlayers> {
  late Future<List<Player>> playersFuture;

  @override
  void initState() {
    super.initState();
    playersFuture = _loadPlayers();
  }

  @override
  void didUpdateWidget(covariant _TeamPlayers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      playersFuture = _loadPlayers();
    }
  }

  Future<List<Player>> _loadPlayers() async {
    final teamId = await widget.repository.resolveCurrentTeamId();
    if (teamId == null) return const [];
    return widget.repository.fetchTeamPlayers(teamId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Player>>(
      future: playersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          return const EmptyState(
            title: 'لا يوجد لاعبون بعد',
            description: 'أضف أول لاعب إلى فريقك.',
            icon: Icons.groups_outlined,
          );
        }
        final players = snapshot.data!
            .where(
              (player) =>
                  player.name.contains(widget.query) ||
                  player.position.contains(widget.query),
            )
            .toList();
        if (players.isEmpty) {
          return const EmptyState(
            title: 'لا توجد نتائج',
            description: 'جرّب اسمًا أو مركزًا مختلفًا.',
            icon: Icons.search_off_rounded,
          );
        }
        return Column(
          children: players
              .map(
                (player) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PlayerCard(
                    player: player,
                    onTap: () => widget.onPlayerTap(player),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.player, required this.onTap});
  final Player player;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${player.position}  •  ${player.age} سنة',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            TagPill(label: player.level, color: AppColors.info),
            const SizedBox(width: 5),
            const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/data_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class TrainingModeScreen extends StatefulWidget {
  const TrainingModeScreen({super.key, required this.session, required this.repository});
  final TrainingSession session;
  final TrainingRepository repository;

  @override
  State<TrainingModeScreen> createState() => _TrainingModeScreenState();
}

class _TrainingModeScreenState extends State<TrainingModeScreen> {
  Timer? _timer;
  int seconds = 0;
  int totalSeconds = 0;
  int current = 0;
  final completed = <int>{};
  bool running = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session.exercises.isEmpty) {
      return const Scaffold(body: Center(child: Text('لا توجد تمارين في هذه الحصة.')));
    }
    final exercise = widget.session.exercises[current];
    final total = widget.session.exercises.length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('وضع التدريب'),
        actions: [
          TextButton(
            onPressed: () => _showFinishDialog(context),
            child: const Text(
              'إنهاء',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          Row(
            children: [
              TagPill(
                label: 'التمرين ${current + 1} من $total',
                icon: Icons.layers_outlined,
              ),
              const Spacer(),
              TagPill(label: widget.session.objective, color: AppColors.info),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : completed.length / total,
              minHeight: 7,
              backgroundColor: AppColors.border,
            ),
          ),
          const SizedBox(height: 8),
          Text('التقدم: ${completed.length} من $total تمارين', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 18),
          ExerciseVisual(exercise: exercise, size: double.infinity),
          const SizedBox(height: 22),
          Text(
            exercise.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 7),
          Text(
            exercise.objective,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 22),
          _TimerCard(
            seconds: seconds,
            running: running,
            onToggle: _toggleTimer,
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تعليمات سريعة',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...exercise.instructions.map(
                  (instruction) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.chevron_left_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            instruction,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (exercise.coachingPoints.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.primary.withValues(alpha: .2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('نقاط التدريب', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...exercise.coachingPoints.map((point) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $point', style: Theme.of(context).textTheme.bodyMedium),
                  )),
                ],
              ),
            ),
          ],
          if (current < total - 1) ...[
            const SizedBox(height: 16),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              tileColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: const Icon(Icons.skip_next_rounded, color: AppColors.info),
              title: const Text('التمرين التالي'),
              subtitle: Text(widget.session.exercises[current + 1].name),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'السابق',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: current == 0
                      ? null
                      : () {
                          _timer?.cancel();
                          setState(() { current--; seconds = 0; running = false; });
                        },
                  expand: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: completed.contains(current)
                      ? 'مكتمل'
                      : 'إكمال التمرين',
                  icon: completed.contains(current)
                      ? Icons.check_rounded
                      : Icons.check_circle_outline_rounded,
                  onPressed: () {
                    _timer?.cancel();
                    setState(() {
                      completed.add(current);
                      running = false;
                      seconds = 0;
                      if (current < total - 1) current++;
                    });
                  },
                  expand: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (current < total - 1)
            TextButton.icon(
              onPressed: () {
                _timer?.cancel();
                setState(() { current++; seconds = 0; running = false; });
              },
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('التالي بدون إكمال'),
              style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            ),
        ],
      ),
    );
  }

  void _toggleTimer() {
    if (running) {
      _timer?.cancel();
      setState(() => running = false);
    } else {
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {
          seconds++;
          totalSeconds++;
        }),
      );
      setState(() => running = true);
    }
  }

  void _showFinishDialog(BuildContext context) {
    _timer?.cancel();
    setState(() => running = false);
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('إنهاء الحصة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أكملت ${completed.length} من ${widget.session.exercises.length} تمارين.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'ملاحظات المدرب',
                hintText: 'اكتب ملاحظاتك عن الحصة...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('متابعة'),
          ),
          FilledButton(
            onPressed: () async {
              widget.session.notes = notesController.text;
              widget.session.completed = true;
              try {
                await widget.repository.recordSessionCompletion(
                  sessionId: widget.session.id,
                  durationSeconds: totalSeconds,
                  exercisesCompleted: completed.length,
                );
                if (!mounted) return;
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ إكمال الحصة. حاول مرة أخرى.')));
              }
            },
            child: const Text('حفظ وإنهاء'),
          ),
        ],
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({
    required this.seconds,
    required this.running,
    required this.onToggle,
  });
  final int seconds;
  final bool running;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: onToggle,
              icon: Icon(
                running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'وقت التمرين',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 3),
              Text(
                '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            running ? 'جارٍ الآن' : 'متوقف',
            style: TextStyle(
              color: running ? AppColors.primary : AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

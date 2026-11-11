import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/data_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'exercise_detail_screen.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key, required this.repository});

  final TrainingRepository repository;

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  late final Future<List<Exercise>> exercisesFuture;
  String query = '';
  ExerciseCategory? selectedCategory;
  String? selectedDifficulty;

  @override
  void initState() {
    super.initState();
    exercisesFuture = widget.repository.fetchExercises();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Exercise>>(
      future: exercisesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const EmptyState(
            title: 'تعذر تحميل التمارين',
            description: 'تحقق من الاتصال ثم حاول مرة أخرى.',
            icon: Icons.cloud_off_rounded,
          );
        }
        final availableExercises = snapshot.data ?? const <Exercise>[];
        final difficulties = availableExercises
            .map((exercise) => exercise.difficulty.trim())
            .where((difficulty) => difficulty.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final filtered = availableExercises.where((exercise) {
          final searchable = [
            exercise.name,
            exercise.nameEn,
            exercise.objective,
            exercise.description,
            exercise.age,
            exercise.players,
            exercise.difficulty,
            exercise.space,
            exercise.equipment,
          ].join(' ').toLowerCase();
          final matchesQuery = query.isEmpty || searchable.contains(query.toLowerCase());
          final matchesCategory =
              selectedCategory == null || exercise.category == selectedCategory;
          final matchesDifficulty = selectedDifficulty == null || exercise.difficulty == selectedDifficulty;
          return matchesQuery && matchesCategory && matchesDifficulty;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                children: [
                  TextField(
                    onChanged: (value) => setState(() => query = value.trim()),
                    textDirection: TextDirection.rtl,
                    decoration: const InputDecoration(
                      hintText: 'ابحث عن تمرين أو هدف...',
                      prefixIcon: Icon(Icons.search_rounded),
                      suffixIcon: Icon(Icons.tune_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 37,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterChip(
                          label: 'الكل',
                          selected: selectedCategory == null,
                          onTap: () => setState(() => selectedCategory = null),
                        ),
                        ...ExerciseCategory.values.map(
                          (category) => _FilterChip(
                            label: category.label,
                            selected: selectedCategory == category,
                            onTap: () =>
                                setState(() => selectedCategory = category),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (difficulties.length > 1) ...[
                    const SizedBox(height: 9),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: DropdownButton<String>(
                        value: selectedDifficulty,
                        hint: const Text('كل المستويات'),
                        underline: const SizedBox.shrink(),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('كل المستويات')),
                          ...difficulties.map((difficulty) => DropdownMenuItem(value: difficulty, child: Text(difficulty))),
                        ],
                        onChanged: (value) => setState(() => selectedDifficulty = value),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(
                      title: 'لا توجد تمارين',
                      description: 'جرّب تغيير كلمة البحث أو الفلتر المحدد.',
                      icon: Icons.search_off_rounded,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) => ExerciseCard(
                        exercise: filtered[index],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ExerciseDetailScreen(exercise: filtered[index]),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        side: BorderSide(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.55)
              : AppColors.border,
        ),
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary.withValues(alpha: 0.14),
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 5),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/routine_model.dart';
import '../theme/app_theme.dart';

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final routines = provider.routines;

        return Column(
          children: [
            _buildHeader(context, provider),
            const Divider(height: 1, color: AppTheme.divider),
            Expanded(
              child: routines.isEmpty
                  ? _buildEmptyState(context, provider)
                  : _buildRoutineList(context, provider, routines),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, AppProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '루틴',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '반복되는 할 일을 관리하세요',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          
          InkWell(
            onTap: () => _showCreateRoutineDialog(context, provider),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.divider),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.add, size: 18, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.repeat_outlined,
              size: 48,
              color: AppTheme.textTertiary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              '루틴이 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '매일 반복하는 일을 루틴으로 만들어보세요',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreateRoutineDialog(context, provider),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('루틴 만들기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineList(BuildContext context, AppProvider provider, List<RoutineModel> routines) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: routines.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20),
      itemBuilder: (context, index) {
        final routine = routines[index];
        return _buildRoutineItem(context, provider, routine);
      },
    );
  }

  Widget _buildRoutineItem(BuildContext context, AppProvider provider, RoutineModel routine) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Active toggle
          GestureDetector(
            onTap: () async {
              await provider.updateRoutine(routine.copyWith(isActive: !routine.isActive));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(routine.isActive ? '루틴이 일시정지되었습니다' : '루틴이 활성화되었습니다'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: routine.isActive ? AppTheme.accent : Colors.transparent,
                border: Border.all(
                  color: routine.isActive ? AppTheme.accent : AppTheme.textTertiary,
                  width: 1.5,
                ),
                shape: BoxShape.circle,
              ),
              child: routine.isActive
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routine.text,
                  style: TextStyle(
                    fontSize: 16,
                    color: routine.isActive ? AppTheme.textPrimary : AppTheme.textTertiary,
                    decoration: routine.isActive ? null : TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.repeat, size: 12, color: AppTheme.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      _getRepetitionKr(routine),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    if (routine.estimatedTime != null) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.schedule_outlined, size: 12, color: AppTheme.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        '${routine.estimatedTime}분',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Actions
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textTertiary),
            onSelected: (value) {
              if (value == 'edit') {
                _showEditRoutineDialog(context, provider, routine);
              } else if (value == 'delete') {
                _showDeleteConfirmation(context, provider, routine);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('수정')),
              const PopupMenuItem(value: 'delete', child: Text('삭제')),
            ],
          ),
        ],
      ),
    );
  }

  String _getRepetitionKr(RoutineModel routine) {
    switch (routine.repetitionType) {
      case RepetitionType.daily:
        return '매일';
      case RepetitionType.weeklyOnce:
        if (routine.weekdays.isEmpty) return '주간';
        final days = ['', '월', '화', '수', '목', '금', '토', '일'];
        final dayNames = routine.weekdays.map((d) => days[d]).join(', ');
        return '매주 $dayNames';
      case RepetitionType.weeklyN:
        return '주 ${routine.repetitionCount}회';
    }
  }

  void _showCreateRoutineDialog(BuildContext context, AppProvider provider) {
    _showRoutineDialog(context, provider, null);
  }

  void _showEditRoutineDialog(BuildContext context, AppProvider provider, RoutineModel routine) {
    _showRoutineDialog(context, provider, routine);
  }

  void _showRoutineDialog(BuildContext context, AppProvider provider, RoutineModel? routine) {
    final textController = TextEditingController(text: routine?.text ?? '');
    int? estimatedTime = routine?.estimatedTime;
    RepetitionType repetitionType = routine?.repetitionType ?? RepetitionType.daily;
    int repetitionCount = routine?.repetitionCount ?? 1;
    Set<int> selectedWeekdays = Set.from(routine?.weekdays ?? []);
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(routine == null ? '새 루틴' : '루틴 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: textController,
                  autofocus: routine == null,
                  decoration: InputDecoration(
                    hintText: '반복할 일을 입력하세요',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.accent),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Estimated time
                const Text(
                  '예상 시간',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final time in [null, 5, 15, 30, 60])
                      InkWell(
                        onTap: () => setDialogState(() => estimatedTime = time),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: estimatedTime == time ? AppTheme.textPrimary : Colors.transparent,
                            border: Border.all(
                              color: estimatedTime == time ? AppTheme.textPrimary : AppTheme.divider,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            time == null ? '없음' : (time < 60 ? '${time}분' : '${time ~/ 60}시간'),
                            style: TextStyle(
                              fontSize: 13,
                              color: estimatedTime == time ? AppTheme.background : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Repetition type
                const Text(
                  '반복 주기',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                DropdownButton<RepetitionType>(
                  value: repetitionType,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: RepetitionType.daily, child: Text('매일')),
                    DropdownMenuItem(value: RepetitionType.weeklyOnce, child: Text('특정 요일')),
                    DropdownMenuItem(value: RepetitionType.weeklyN, child: Text('주 N회')),
                  ],
                  onChanged: (value) => setDialogState(() => repetitionType = value!),
                ),

                if (repetitionType == RepetitionType.weeklyN) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('주당 횟수: '),
                      DropdownButton<int>(
                        value: repetitionCount,
                        items: List.generate(7, (i) => i + 1)
                            .map((n) => DropdownMenuItem(value: n, child: Text('$n회')))
                            .toList(),
                        onChanged: (value) => setDialogState(() => repetitionCount = value!),
                      ),
                    ],
                  ),
                ],

                if (repetitionType != RepetitionType.daily) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '요일 선택',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final day in [(1, '월'), (2, '화'), (3, '수'), (4, '목'), (5, '금'), (6, '토'), (7, '일')])
                        GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              if (selectedWeekdays.contains(day.$1)) {
                                selectedWeekdays.remove(day.$1);
                              } else {
                                selectedWeekdays.add(day.$1);
                              }
                            });
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: selectedWeekdays.contains(day.$1) ? AppTheme.accent : Colors.transparent,
                              border: Border.all(
                                color: selectedWeekdays.contains(day.$1) ? AppTheme.accent : AppTheme.divider,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                day.$2,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: selectedWeekdays.contains(day.$1) ? Colors.white : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                if (textController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('루틴 이름을 입력해주세요'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                setDialogState(() => isSubmitting = true);

                try {
                  if (routine != null) {
                    await provider.updateRoutine(
                      routine.copyWith(
                        text: textController.text.trim(),
                        estimatedTime: estimatedTime,
                        repetitionType: repetitionType,
                        repetitionCount: repetitionCount,
                        weekdays: selectedWeekdays.toList()..sort(),
                      ),
                    );
                  } else {
                    await provider.createRoutine(
                      text: textController.text.trim(),
                      estimatedTime: estimatedTime,
                      repetitionType: repetitionType,
                      repetitionCount: repetitionCount,
                      weekdays: selectedWeekdays.toList()..sort(),
                    );
                  }

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(routine != null ? '루틴이 수정되었습니다' : '루틴이 생성되었습니다'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  setDialogState(() => isSubmitting = false);
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('오류: $e'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(routine != null ? '저장' : '생성'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, AppProvider provider, RoutineModel routine) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('루틴 삭제'),
        content: Text('"${routine.text}" 루틴을 삭제할까요?\n\n이 작업은 취소할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.deleteRoutine(routine.id);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('루틴이 삭제되었습니다'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

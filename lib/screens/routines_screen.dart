import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
                // 유효기간 표시
                if (routine.endDate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '~${DateFormat('M/d').format(routine.endDate!)}까지',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
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
    if (routine.weekdays.isEmpty) {
      return '매일';
    }
    if (routine.weekdays.length == 7) {
      return '매일';
    }
    final days = ['', '월', '화', '수', '목', '금', '토', '일'];
    final dayNames = routine.weekdays.map((d) => days[d]).join(', ');
    return '매주 $dayNames';
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
    Set<int> selectedWeekdays = Set.from(routine?.weekdays ?? []);
    DateTime startDate = routine?.startDate ?? DateTime.now();
    DateTime? endDate = routine?.endDate;
    bool hasEndDate = endDate != null;
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
                            time == null ? '없음' : (time < 60 ? '$time분' : '${time ~/ 60}시간'),
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

                // 반복 요일 선택 (드롭다운 없이 바로 표시)
                Row(
                  children: [
                    const Text(
                      '반복 요일',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const Spacer(),
                    // 전체 선택 체크박스
                    GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          if (selectedWeekdays.length == 7) {
                            selectedWeekdays.clear();
                          } else {
                            selectedWeekdays = {1, 2, 3, 4, 5, 6, 7};
                          }
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: selectedWeekdays.length == 7 ? AppTheme.accent : Colors.transparent,
                              border: Border.all(
                                color: selectedWeekdays.length == 7 ? AppTheme.accent : AppTheme.divider,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: selectedWeekdays.length == 7
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '매일',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                
                const SizedBox(height: 20),
                
                // 유효 기간
                const Text(
                  '반복 유효 기간',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                
                // 시작일
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.play_arrow, size: 20, color: AppTheme.textTertiary),
                  title: Text(
                    '시작: ${DateFormat('yyyy년 M월 d일').format(startDate)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: startDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (picked != null) {
                      setDialogState(() => startDate = picked);
                    }
                  },
                ),
                
                // 종료일
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          hasEndDate = !hasEndDate;
                          if (!hasEndDate) endDate = null;
                        });
                      },
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: hasEndDate ? AppTheme.accent : Colors.transparent,
                          border: Border.all(
                            color: hasEndDate ? AppTheme.accent : AppTheme.divider,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: hasEndDate
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(Icons.stop, size: 20, color: AppTheme.textTertiary),
                        title: Text(
                          hasEndDate 
                              ? '종료: ${DateFormat('yyyy년 M월 d일').format(endDate ?? DateTime.now())}'
                              : '종료: 무기한',
                          style: TextStyle(
                            fontSize: 14,
                            color: hasEndDate ? AppTheme.textPrimary : AppTheme.textTertiary,
                          ),
                        ),
                        onTap: hasEndDate ? () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: endDate ?? startDate.add(const Duration(days: 30)),
                            firstDate: startDate,
                            lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                          );
                          if (picked != null) {
                            setDialogState(() => endDate = picked);
                          }
                        } : null,
                      ),
                    ),
                  ],
                ),
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
                  return;
                }
                
                // 요일이 하나도 선택되지 않으면 매일로 설정
                final weekdaysList = selectedWeekdays.isEmpty 
                    ? <int>[1, 2, 3, 4, 5, 6, 7]
                    : selectedWeekdays.toList()..sort();

                setDialogState(() => isSubmitting = true);

                try {
                  if (routine != null) {
                    await provider.updateRoutine(
                      routine.copyWith(
                        text: textController.text.trim(),
                        estimatedTime: estimatedTime,
                        repetitionType: RepetitionType.weeklyOnce,
                        weekdays: weekdaysList,
                        startDate: startDate,
                        endDate: hasEndDate ? endDate : null,
                        clearEndDate: !hasEndDate,
                      ),
                    );
                  } else {
                    await provider.createRoutine(
                      text: textController.text.trim(),
                      estimatedTime: estimatedTime,
                      repetitionType: RepetitionType.weeklyOnce,
                      repetitionCount: 1,
                      weekdays: weekdaysList,
                      startDate: startDate,
                      endDate: hasEndDate ? endDate : null,
                    );
                  }

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                } catch (e) {
                  setDialogState(() => isSubmitting = false);
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

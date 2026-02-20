import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/todo_model.dart';
import '../models/routine_model.dart';
import '../services/calendar_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fullscreen_timer.dart';

class CombinedScreen extends StatefulWidget {
  const CombinedScreen({super.key});

  @override
  State<CombinedScreen> createState() => _CombinedScreenState();
}

class _CombinedScreenState extends State<CombinedScreen> {
  late ScrollController _weekScrollController;
  List<CalendarEvent> _googleEvents = [];
  
  // Todo input
  final TextEditingController _newTodoController = TextEditingController();
  final FocusNode _newTodoFocus = FocusNode();
  bool _isAddingTodo = false;
  bool _isSubmitting = false;
  
  // Inline editing
  String? _editingTodoId;
  final TextEditingController _editController = TextEditingController();
  final FocusNode _editFocus = FocusNode();
  
  // Drag reordering
  int? _dropTargetIndex;
  bool _dropAsChild = false;  // true면 하위로 들어감
  
  // Multi-select mode
  Set<String> _selectedTodoIds = {};
  bool get _isMultiSelectMode => _selectedTodoIds.isNotEmpty;
  
  // Memo input
  final TextEditingController _newMemoController = TextEditingController();
  final FocusNode _newMemoFocus = FocusNode();
  bool _isAddingMemo = false;
  bool _isSubmittingMemo = false;

  @override
  void initState() {
    super.initState();
    // Initial scroll will be set after layout
    _weekScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryLoadGoogleEvents();
      _scrollToToday();
    });
  }
  
  void _scrollToToday() {
    if (!mounted) return;
    final viewportWidth = MediaQuery.of(context).size.width;
    final todayButtonWidth = 56.0; // 오늘 버튼 너비
    final availableWidth = viewportWidth - todayButtonWidth - 24; // 좌우 패딩
    final itemWidth = 52.0; // 46 width + 6 margin
    final centerOffset = (availableWidth - itemWidth) / 2;
    final scrollTarget = (365 * itemWidth) - centerOffset;
    
    if (_weekScrollController.hasClients) {
      _weekScrollController.jumpTo(
        scrollTarget.clamp(0.0, _weekScrollController.position.maxScrollExtent),
      );
    }
  }

  @override
  void dispose() {
    _newTodoController.dispose();
    _newTodoFocus.dispose();
    _editController.dispose();
    _editFocus.dispose();
    _weekScrollController.dispose();
    _newMemoController.dispose();
    _newMemoFocus.dispose();
    super.dispose();
  }

  Future<void> _tryLoadGoogleEvents() async {
    if (!mounted) return;
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // Load events for current month range (try even without explicit calendar access)
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 1, 1);
    final end = DateTime(now.year, now.month + 2, 0, 23, 59, 59);

    try {
      await provider.loadCalendarEvents(start, end);
      if (mounted) {
        setState(() => _googleEvents = provider.calendarEvents);
      }
    } catch (e) {
      // Silently fail - calendar is optional
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final todos = provider.organizedTodos;
        final selectedDate = provider.selectedDate;
        final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());
        
        // Get calendar events for selected date (use provider's events directly)
        final allEvents = provider.calendarEvents.isNotEmpty ? provider.calendarEvents : _googleEvents;
        final dayEvents = allEvents.where((e) => DateUtils.isSameDay(e.start, selectedDate)).toList();
        
        // Calculate total estimated time
        final totalEstimatedMinutes = todos.fold<int>(0, (sum, todo) => sum + (todo.estimatedTime ?? 0));
        // Calculate total actual time
        final totalActualMinutes = todos.fold<int>(0, (sum, todo) => sum + (todo.actualTime ?? 0));

        return Column(
          children: [
            // Calendar reconnection banner
            if (provider.authService.needsCalendarReconnect)
              _buildCalendarReconnectBanner(provider),
            
            // Week view only
            _buildWeekView(provider),
            
            const Divider(height: 1, color: AppTheme.divider),
            
            // Selected date header with full date
            _buildDateHeader(selectedDate, isToday, provider),
            
            // Todo list with calendar events
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  // === CALENDAR EVENTS SECTION (일정이 있을 때만 표시, 없으면 완전히 숨김) ===
                  if (dayEvents.isNotEmpty) ...[
                    _buildSectionHeader(
                      icon: Icons.event,
                      title: '일정',
                      count: dayEvents.length,
                      color: AppTheme.accent,
                    ),
                    ...dayEvents.map((event) => _buildCalendarEventItem(event)),
                    const SizedBox(height: 16),
                  ],
                  
                  // === TODO SECTION ===
                  _buildSectionHeader(
                    icon: Icons.check_circle_outline,
                    title: '할 일',
                    count: todos.length,
                    color: AppTheme.textSecondary,
                    totalMinutes: totalEstimatedMinutes,
                    totalActualMinutes: totalActualMinutes,
                  ),
                  
                  // Multi-select action bar
                  if (_isMultiSelectMode) _buildMultiSelectActionBar(provider),
                  
                  // Todos
                  if (todos.isEmpty && !_isAddingTodo)
                    _buildEmptySectionMessage('할 일이 없습니다. 아래에서 추가하세요.')
                  else
                    ...todos.map((todo) => _buildTodoItem(context, provider, todo)),
                  
                  if (_isAddingTodo) _buildNewTodoInput(provider),
                  
                  _buildAddTodoButton(),
                  
                  // === MEMO SECTION (날짜 없는 할일 - 항상 표시) ===
                  const SizedBox(height: 16),
                  _buildSectionHeader(
                    icon: Icons.sticky_note_2_outlined,
                    title: '메모',
                    count: provider.memos.length,
                    color: Colors.orange,
                  ),
                  
                  // Memos
                  if (provider.memos.isEmpty && !_isAddingMemo)
                    _buildEmptySectionMessage('날짜 없이 기록할 메모를 추가하세요.')
                  else
                    ...provider.memos.map((memo) => _buildMemoItem(context, provider, memo)),
                  
                  if (_isAddingMemo) _buildNewMemoInput(provider),
                  
                  _buildAddMemoButton(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalendarReconnectBanner(AppProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.accentLight,
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: AppTheme.accent, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '캘린더 연결이 만료되었습니다',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final success = await provider.authService.requestCalendarAccess();
              if (success && mounted) {
                await _tryLoadGoogleEvents();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('캘린더가 다시 연결되었습니다'),
                    backgroundColor: AppTheme.accent,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('재연결', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekView(AppProvider provider) {
    final now = DateTime.now();
    final todayButtonWidth = 56.0;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          // Scrollable date buttons
          Expanded(
            child: SizedBox(
              height: 56,
              child: ListView.builder(
                controller: _weekScrollController,
                scrollDirection: Axis.horizontal,
                itemCount: 730,
                itemBuilder: (context, index) {
                  final date = now.add(Duration(days: index - 365));
                  final isToday = DateUtils.isSameDay(date, now);
                  final isSelected = DateUtils.isSameDay(date, provider.selectedDate);
                  final allEventsForDot = provider.calendarEvents.isNotEmpty ? provider.calendarEvents : _googleEvents;
                  final hasGoogleEvents = allEventsForDot.any((e) => DateUtils.isSameDay(e.start, date));
                  
                  return GestureDetector(
                    onTap: () {
                      provider.setSelectedDate(date);
                      _tryLoadGoogleEvents();
                    },
                    child: Container(
                      width: 46,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? AppTheme.accent 
                            : isToday 
                                ? AppTheme.accentLight 
                                : AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected || isToday ? AppTheme.accent : AppTheme.divider,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${date.month}/${date.day}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected 
                                  ? Colors.white 
                                  : isToday 
                                      ? AppTheme.accent 
                                      : AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            DateFormat('E', 'ko').format(date),
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected 
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : AppTheme.textTertiary,
                            ),
                          ),
                          if (hasGoogleEvents)
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : AppTheme.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Fixed "Today" button on right
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              provider.setSelectedDate(DateTime.now());
              final viewportWidth = MediaQuery.of(context).size.width;
              final availableWidth = viewportWidth - todayButtonWidth - 24;
              final itemWidth = 52.0;
              final centerOffset = (availableWidth - itemWidth) / 2;
              final scrollTarget = (365 * itemWidth) - centerOffset;
              _weekScrollController.animateTo(
                scrollTarget.clamp(0.0, _weekScrollController.position.maxScrollExtent),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            },
            child: Container(
              width: todayButtonWidth,
              height: 56,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.accent),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  '오늘',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.accent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(DateTime date, bool isToday, AppProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Text(
            DateFormat('yyyy년 M월 d일 (E)', 'ko').format(date),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          if (isToday) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '오늘',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendarEventItem(CalendarEvent event) {
    return GestureDetector(
      onTap: () => _showEditCalendarEventDialog(context, event),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.accentLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.summary,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('HH:mm').format(event.start)} - ${DateFormat('HH:mm').format(event.end)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Edit icon
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.accent),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => _showEditCalendarEventDialog(context, event),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showEditCalendarEventDialog(BuildContext dialogContext, CalendarEvent event) {
    final titleController = TextEditingController(text: event.summary);
    DateTime selectedDate = event.start;
    TimeOfDay startTime = TimeOfDay.fromDateTime(event.start);
    TimeOfDay endTime = TimeOfDay.fromDateTime(event.end);

    showDialog(
      context: dialogContext,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('일정 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 기존 일정 정보 표시
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.accentLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('기존 일정', style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
                      const SizedBox(height: 4),
                      Text(event.summary, style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text(
                        '${DateFormat('M/d HH:mm').format(event.start)} - ${DateFormat('HH:mm').format(event.end)}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: '일정 제목',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Date picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, size: 20),
                  title: Text(DateFormat('yyyy년 M월 d일').format(selectedDate)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setDialogState(() => selectedDate = date);
                  },
                ),
                
                // Start time
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time, size: 20),
                  title: Text('시작: ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}'),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: startTime,
                    );
                    if (time != null) setDialogState(() => startTime = time);
                  },
                ),
                
                // End time
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time_filled, size: 20),
                  title: Text('종료: ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}'),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: endTime,
                    );
                    if (time != null) setDialogState(() => endTime = time);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final provider = Provider.of<AppProvider>(ctx, listen: false);
                final success = await provider.deleteCalendarEvent(event.id);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(success ? '일정이 삭제되었습니다' : '삭제 실패'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  if (success) _tryLoadGoogleEvents();
                }
              },
              child: const Text('삭제', style: TextStyle(color: AppTheme.error)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                
                final provider = Provider.of<AppProvider>(ctx, listen: false);
                final newStart = DateTime(
                  selectedDate.year, selectedDate.month, selectedDate.day,
                  startTime.hour, startTime.minute,
                );
                final newEnd = DateTime(
                  selectedDate.year, selectedDate.month, selectedDate.day,
                  endTime.hour, endTime.minute,
                );
                
                final success = await provider.updateCalendarEvent(
                  eventId: event.id,
                  title: titleController.text.trim(),
                  start: newStart,
                  end: newEnd,
                );
                
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(success ? '일정이 수정되었습니다' : '수정 실패'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  if (success) _tryLoadGoogleEvents();
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
    int? totalMinutes,
    int? totalActualMinutes,
  }) {
    // Format total time
    String formatTotalTime(int minutes) {
      if (minutes >= 60) {
        final hours = minutes ~/ 60;
        final mins = minutes % 60;
        if (mins > 0) {
          return '$hours시간 $mins분';
        }
        return '$hours시간';
      }
      return '$minutes분';
    }
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.divider.withValues(alpha: 0.5), width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          // Total estimated time
          if (totalMinutes != null) ...[  
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule, size: 11, color: AppTheme.accent),
                  const SizedBox(width: 4),
                  Text(
                    formatTotalTime(totalMinutes),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Total actual time
          if (totalActualMinutes != null && totalActualMinutes > 0) ...[  
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.textTertiary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, size: 11, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    formatTotalTime(totalActualMinutes),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildEmptySectionMessage(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 13,
          color: AppTheme.textTertiary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
  
  // Multi-select action bar
  Widget _buildMultiSelectActionBar(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.accentLight,
        border: Border(
          bottom: BorderSide(color: AppTheme.accent.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          // Selected count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_selectedTodoIds.length}개',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          // Date change button
          TextButton.icon(
            onPressed: () => _changeSelectedTodosDate(context, provider),
            icon: const Icon(Icons.calendar_today, size: 16),
            label: const Text('이동'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          // Copy to date button
          TextButton.icon(
            onPressed: () => _copySelectedTodosToDate(context, provider),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('복제'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          // Complete all button
          TextButton.icon(
            onPressed: () => _completeSelectedTodos(provider),
            icon: const Icon(Icons.check_circle, size: 16),
            label: const Text('완료'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          // Delete all button
          TextButton.icon(
            onPressed: () => _deleteSelectedTodos(provider),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('삭제'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.error,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          // Cancel selection button
          IconButton(
            onPressed: _clearSelection,
            icon: const Icon(Icons.close, size: 20),
            color: AppTheme.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
  
  Future<void> _changeSelectedTodosDate(BuildContext context, AppProvider provider) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (pickedDate != null && mounted) {
      final selectedIds = _selectedTodoIds.toList();
      int updatedCount = 0;
      
      for (final id in selectedIds) {
        try {
          // Find todo from organizedTodos (which includes all visible todos)
          final allTodos = provider.organizedTodos;
          final todoIndex = allTodos.indexWhere((t) => t.id == id);
          if (todoIndex != -1) {
            final todo = allTodos[todoIndex];
            final updatedTodo = todo.copyWith(date: pickedDate);
            await provider.updateTodo(updatedTodo);
            updatedCount++;
          }
        } catch (e) {
          // Skip if todo not found
          continue;
        }
      }
      
      _clearSelection();
      
      if (mounted && updatedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$updatedCount개 할 일의 날짜가 변경되었습니다'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  Future<void> _copySelectedTodosToDate(BuildContext context, AppProvider provider) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (pickedDate != null && mounted) {
      final selectedIds = _selectedTodoIds.toList();
      int copiedCount = 0;
      
      for (final id in selectedIds) {
        try {
          // Find todo from organizedTodos
          final allTodos = provider.organizedTodos;
          final todoIndex = allTodos.indexWhere((t) => t.id == id);
          if (todoIndex != -1) {
            final todo = allTodos[todoIndex];
            // Create a new todo with the same content but different date
            await provider.createTodo(
              text: todo.text,
              estimatedTime: todo.estimatedTime,
              date: pickedDate,
            );
            copiedCount++;
          }
        } catch (e) {
          // Skip if error
          continue;
        }
      }
      
      _clearSelection();
      
      if (mounted && copiedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$copiedCount개 할 일이 복제되었습니다'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  void _toggleTodoSelection(String todoId) {
    setState(() {
      if (_selectedTodoIds.contains(todoId)) {
        _selectedTodoIds.remove(todoId);
      } else {
        _selectedTodoIds.add(todoId);
      }
    });
  }
  
  void _clearSelection() {
    setState(() {
      _selectedTodoIds.clear();
    });
  }
  
  Future<void> _completeSelectedTodos(AppProvider provider) async {
    final selectedIds = _selectedTodoIds.toList();
    for (final todoId in selectedIds) {
      final todo = provider.todos.firstWhere((t) => t.id == todoId, orElse: () => provider.todos.first);
      if (!todo.completed) {
        await provider.toggleTodoComplete(todo);
      }
    }
    _clearSelection();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedIds.length}개 할 일 완료'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
  
  Future<void> _deleteSelectedTodos(AppProvider provider) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text('선택한 ${_selectedTodoIds.length}개의 할 일을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final selectedIds = _selectedTodoIds.toList();
      for (final todoId in selectedIds) {
        await provider.deleteTodo(todoId);
      }
      _clearSelection();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedIds.length}개 할 일 삭제됨'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: AppTheme.textTertiary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            '할 일이 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '아래 버튼을 눌러 추가하세요',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoItem(BuildContext context, AppProvider provider, TodoModel todo) {
    final indentLevel = provider.getIndentLevel(todo);
    final isEditing = _editingTodoId == todo.id;
    final organizedTodos = provider.organizedTodos;
    final todoIndex = organizedTodos.indexOf(todo);
    final isDropTarget = _dropTargetIndex == todoIndex;
    
    if (isEditing) {
      return _buildInlineEditItem(provider, todo, indentLevel);
    }
    
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        if (details.data == todo.id) return false;
        return true;
      },
      onAcceptWithDetails: (details) async {
        final draggedTodoId = details.data;
        final draggedTodo = provider.todos.firstWhere((t) => t.id == draggedTodoId);
        
        // 하위로 추가 (타겟이 depth 0이고 오른쪽 영역에 드롭 - 20% 이상)
        if (_dropAsChild && indentLevel == 0) {
          // 현재 todo의 자식으로 설정
          final updatedTodo = draggedTodo.copyWith(parentId: todo.id);
          await provider.updateTodo(updatedTodo);
        } 
        // 타겟이 하위 항목(indentLevel > 0)인 경우: 같은 부모 아래로 이동
        else if (indentLevel > 0) {
          // 타겟의 부모를 드래그된 항목의 부모로 설정
          if (draggedTodo.parentId != todo.parentId) {
            final updatedTodo = draggedTodo.copyWith(parentId: todo.parentId);
            await provider.updateTodo(updatedTodo);
          }
          // 순서 변경
          final oldIndex = organizedTodos.indexOf(draggedTodo);
          if (oldIndex != todoIndex) {
            await provider.reorderTodos(oldIndex, todoIndex);
          }
        }
        // 기본: 최상위로 이동 (순서 변경) - 타겟이 최상위이고 20% 이하 영역
        else {
          // 드래그된 항목이 하위 항목이면 최상위로 이동
          if (draggedTodo.parentId != null) {
            final updatedTodo = draggedTodo.copyWith(parentId: null);
            await provider.updateTodo(updatedTodo);
          }
          // 순서 변경
          final oldIndex = organizedTodos.indexOf(draggedTodo);
          if (oldIndex != todoIndex) {
            await provider.reorderTodos(oldIndex, todoIndex);
          }
        }
        setState(() {
          _dropTargetIndex = null;
          _dropAsChild = false;
        });
      },
      onMove: (details) {
        setState(() {
          _dropTargetIndex = todoIndex;
          final dx = details.offset.dx;
          final screenWidth = MediaQuery.of(context).size.width;
          // 오른쪽 20% 이상: 하위로 (타겟이 depth 0인 경우만)
          _dropAsChild = dx > screenWidth * 0.2 && indentLevel == 0;
        });
      },
      onLeave: (_) {
        if (_dropTargetIndex == todoIndex) {
          setState(() {
            _dropTargetIndex = null;
            _dropAsChild = false;
          });
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        
        return _buildTodoItemContent(
          context, provider, todo, indentLevel,
          isHovering, _dropAsChild && isDropTarget,
        );
      },
    );
  }

  Widget _buildTodoItemContent(
    BuildContext context,
    AppProvider provider,
    TodoModel todo,
    int indentLevel,
    bool isDropTarget,
    bool dropAsChild,
  ) {
    final isSelected = _selectedTodoIds.contains(todo.id);
    
    return GestureDetector(
      onTap: () {
        if (_isMultiSelectMode) {
          // In multi-select mode, tap toggles selection
          _toggleTodoSelection(todo.id);
        } else {
          _startInlineEdit(todo);
        }
      },
      child: Container(
        padding: EdgeInsets.only(
          left: 8.0 + (indentLevel * 24),  // 드래그 핸들 공간 확보
          right: 8,
          top: 12,
          bottom: 12,
        ),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.accentLight
              : isDropTarget 
                  ? (dropAsChild ? AppTheme.accentLight : AppTheme.surface)
                  : Colors.transparent,
          border: Border(
            bottom: const BorderSide(color: AppTheme.divider, width: 0.5),
            left: isDropTarget && dropAsChild 
                ? const BorderSide(color: AppTheme.accent, width: 3)
                : isSelected
                    ? const BorderSide(color: AppTheme.accent, width: 3)
                    : BorderSide.none,
            top: isDropTarget && !dropAsChild
                ? const BorderSide(color: AppTheme.accent, width: 2)
                : BorderSide.none,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle - Only this part is draggable for reordering
            Draggable<String>(
              data: todo.id,
              axis: Axis.vertical,
              onDragStarted: () => setState(() {}),
              onDragEnd: (_) => setState(() {
                _dropTargetIndex = null;
                _dropAsChild = false;
              }),
              feedback: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accent, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.drag_indicator, color: AppTheme.accent, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          todo.text,
                          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              childWhenDragging: const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.drag_indicator, size: 20, color: AppTheme.accent),
              ),
              child: const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.drag_indicator, size: 20, color: AppTheme.textTertiary),
              ),
            ),
            const SizedBox(width: 4),
            
            // Checkbox - now for multi-select
            GestureDetector(
              onTap: () => _toggleTodoSelection(todo.id),
              child: Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppTheme.accent 
                      : todo.completed 
                          ? AppTheme.textTertiary 
                          : Colors.transparent,
                  border: Border.all(
                    color: isSelected 
                        ? AppTheme.accent 
                        : todo.completed 
                            ? AppTheme.textTertiary 
                            : AppTheme.textTertiary,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : todo.completed
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
              ),
            ),
            const SizedBox(width: 12),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo.text.isEmpty ? '제목 없음' : todo.text,
                    style: TextStyle(
                      fontSize: 16,
                      color: todo.completed ? AppTheme.textTertiary : AppTheme.textPrimary,
                      decoration: todo.completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  
                  if (todo.estimatedTime != null || todo.actualTime != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          if (todo.estimatedTime != null)
                            _buildTimeChip('${todo.estimatedTime}분', AppTheme.accentLight, AppTheme.accent),
                          if (todo.actualTime != null) ...[
                            const SizedBox(width: 8),
                            _buildTimeChip('${todo.actualTime}분 완료', AppTheme.surface, AppTheme.textSecondary),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            // Actions (hidden in multi-select mode)
            if (!_isMultiSelectMode) ...[
              if (!todo.completed) ...[
                IconButton(
                  icon: Icon(
                    todo.timerStartedAt != null ? Icons.pause : Icons.play_arrow_outlined,
                    size: 22,
                  ),
                  color: AppTheme.accent,
                  onPressed: () => _showFullscreenTimer(context, provider, todo),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                PopupMenuButton<int>(
                  icon: const Icon(Icons.schedule_outlined, size: 20, color: AppTheme.textTertiary),
                  padding: EdgeInsets.zero,
                  onSelected: (minutes) async {
                    if (minutes == -1) {
                      await provider.firestoreService.updateTodo(
                        todo.copyWith(estimatedTime: null),
                      );
                    } else {
                      final current = todo.estimatedTime ?? 0;
                      await provider.updateTodoEstimatedTime(todo, current + minutes);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 5, child: Text('+5분')),
                    const PopupMenuItem(value: 10, child: Text('+10분')),
                    const PopupMenuItem(value: 30, child: Text('+30분')),
                    const PopupMenuItem(value: 60, child: Text('+1시간')),
                    if (todo.estimatedTime != null)
                      const PopupMenuItem(value: -1, child: Text('시간 삭제')),
                  ],
                ),
              ],
              // Undo complete button for completed todos
              if (todo.completed)
                IconButton(
                  icon: const Icon(Icons.undo, size: 20),
                  color: AppTheme.textSecondary,
                  onPressed: () {
                    provider.toggleTodoComplete(todo);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('완료 취소됨'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  tooltip: '완료 취소',
                ),
              // More menu (calendar, routine, complete, delete)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textTertiary),
                padding: EdgeInsets.zero,
                onSelected: (value) => _handleTodoAction(context, provider, todo, value),
                itemBuilder: (context) => [
                  if (!todo.completed)
                    const PopupMenuItem(value: 'complete', child: Text('완료하기')),
                  const PopupMenuItem(value: 'calendar', child: Text('캘린더에 추가')),
                  const PopupMenuItem(value: 'routine', child: Text('루틴으로 만들기')),
                  const PopupMenuItem(value: 'delete', child: Text('삭제')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInlineEditItem(AppProvider provider, TodoModel todo, int indentLevel) {
    return Container(
      padding: EdgeInsets.only(
        left: 8.0 + (indentLevel * 24),
        right: 8,
        top: 12,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: const Border(
          bottom: BorderSide(color: AppTheme.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Drag Handle placeholder (disabled during edit)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.drag_indicator, size: 20, color: AppTheme.textTertiary),
          ),
          const SizedBox(width: 4),
          // Checkbox - clickable during edit (cancels edit and selects)
          GestureDetector(
            onTap: () {
              _cancelInlineEdit();
              _toggleTodoSelection(todo.id);
            },
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.accent, width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _editController,
              focusNode: _editFocus,
              autofocus: true,
              style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _saveInlineEdit(provider, todo),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check, color: AppTheme.accent),
            onPressed: () => _saveInlineEdit(provider, todo),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textTertiary),
            onPressed: _cancelInlineEdit,
          ),
        ],
      ),
    );
  }

  void _startInlineEdit(TodoModel todo) {
    setState(() {
      _editingTodoId = todo.id;
      _editController.text = todo.text;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _editFocus.requestFocus();
        _editController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _editController.text.length,
        );
      }
    });
  }

  void _cancelInlineEdit() {
    setState(() {
      _editingTodoId = null;
      _editController.clear();
    });
  }

  Future<void> _saveInlineEdit(AppProvider provider, TodoModel todo) async {
    final text = _editController.text.trim();
    if (text.isNotEmpty) {
      await provider.updateTodoText(todo, text);
    }
    _cancelInlineEdit();
  }

  Widget _buildTimeChip(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildNewTodoInput(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.accent, width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _newTodoController,
              focusNode: _newTodoFocus,
              autofocus: true,
              enabled: !_isSubmitting,
              style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: _isSubmitting ? '생성 중...' : '할 일을 입력하세요',
                hintStyle: const TextStyle(color: AppTheme.textTertiary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (text) => _submitNewTodo(provider, text),
            ),
          ),
          if (_isSubmitting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.check, size: 22),
              color: AppTheme.accent,
              onPressed: () => _submitNewTodo(provider, _newTodoController.text),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              color: AppTheme.textTertiary,
              onPressed: _cancelAddingTodo,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddTodoButton() {
    return InkWell(
      onTap: _startAddingTodo,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.add,
                size: 16,
                color: AppTheme.accent.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '할 일 추가',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.accent.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startAddingTodo() {
    setState(() => _isAddingTodo = true);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _newTodoFocus.requestFocus();
    });
  }

  void _cancelAddingTodo() {
    setState(() {
      _isAddingTodo = false;
      _isSubmitting = false;
      _newTodoController.clear();
    });
  }

  Future<void> _submitNewTodo(AppProvider provider, String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      _cancelAddingTodo();
      return;
    }
    
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    
    try {
      await provider.createTodo(text: trimmedText);
      
      if (mounted) {
        _newTodoController.clear();
        setState(() => _isSubmitting = false);
        
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && _isAddingTodo) _newTodoFocus.requestFocus();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showFullscreenTimer(BuildContext context, AppProvider provider, TodoModel todo) {
    if (todo.timerStartedAt == null) {
      provider.startTimer(todo);
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => FullscreenTimer(todo: todo),
      ),
    );
  }

  void _handleTodoAction(BuildContext context, AppProvider provider, TodoModel todo, String action) {
    switch (action) {
      case 'complete':
        provider.toggleTodoComplete(todo);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('할 일 완료'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
        break;
      case 'delete':
        provider.deleteTodo(todo.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('할 일 삭제됨'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
        break;
      case 'calendar':
        _showAddToCalendarDialog(context, provider, todo);
        break;
      case 'routine':
        _showMakeRoutineDialog(context, provider, todo);
        break;
    }
  }

  void _showEditTodoDialog(BuildContext context, AppProvider provider, TodoModel todo) {
    final controller = TextEditingController(text: todo.text);
    int? estimatedTime = todo.estimatedTime;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('할 일 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '할 일 내용',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '예상 시간',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final time in [null, 5, 15, 30, 60])
                      InkWell(
                        onTap: () => setDialogState(() => estimatedTime = time),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: estimatedTime == time ? AppTheme.textPrimary : Colors.transparent,
                            border: Border.all(
                              color: estimatedTime == time ? AppTheme.textPrimary : AppTheme.divider,
                            ),
                            borderRadius: BorderRadius.circular(4),
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isNotEmpty) {
                  final updatedTodo = todo.copyWith(
                    text: controller.text.trim(),
                    estimatedTime: estimatedTime,
                  );
                  await provider.firestoreService.updateTodo(updatedTodo);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToCalendarDialog(BuildContext context, AppProvider provider, TodoModel todo) {
    DateTime selectedDate = provider.selectedDate;
    TimeOfDay selectedTime = const TimeOfDay(hour: 14, minute: 0);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('캘린더에 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(todo.text, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, size: 20),
                title: Text(DateFormat('yyyy년 M월 d일').format(selectedDate)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    locale: const Locale('ko'),
                  );
                  if (date != null) setDialogState(() => selectedDate = date);
                },
              ),
              
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time, size: 20),
                title: Text(selectedTime.format(context)),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (time != null) setDialogState(() => selectedTime = time);
                },
              ),
              
              if (todo.estimatedTime != null)
                Text(
                  '소요 시간: ${todo.estimatedTime}분',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                final success = await provider.addTodoToCalendar(
                  todo: todo,
                  date: selectedDate,
                  startHour: selectedTime.hour,
                  startMinute: selectedTime.minute,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    // 캘린더 이벤트 즉시 새로고침
                    _tryLoadGoogleEvents();
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? '캘린더에 추가되었습니다' : '추가 실패. 다시 로그인하여 권한을 부여해주세요.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMakeRoutineDialog(BuildContext context, AppProvider provider, TodoModel todo) {
    String repetitionType = 'daily';
    int repetitionCount = 1;
    Set<int> selectedWeekdays = {};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('루틴 만들기'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(todo.text, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                
                DropdownButton<String>(
                  value: repetitionType,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('매일')),
                    DropdownMenuItem(value: 'weeklyOnce', child: Text('주간 (특정 요일)')),
                    DropdownMenuItem(value: 'weeklyN', child: Text('주간 (n회)')),
                  ],
                  onChanged: (value) => setDialogState(() => repetitionType = value!),
                ),
                
                if (repetitionType == 'weeklyN') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('주당 횟수: '),
                      DropdownButton<int>(
                        value: repetitionCount,
                        items: List.generate(7, (i) => i + 1)
                            .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                            .toList(),
                        onChanged: (value) => setDialogState(() => repetitionCount = value!),
                      ),
                    ],
                  ),
                ],
                
                if (repetitionType != 'daily') ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
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
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: selectedWeekdays.contains(day.$1) ? AppTheme.accent : Colors.transparent,
                              border: Border.all(
                                color: selectedWeekdays.contains(day.$1) ? AppTheme.accent : AppTheme.divider,
                              ),
                              borderRadius: BorderRadius.circular(4),
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
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await provider.convertTodoToRoutine(
                    todo,
                    repetitionType: repetitionType == 'daily'
                        ? RepetitionType.daily
                        : repetitionType == 'weeklyOnce'
                            ? RepetitionType.weeklyOnce
                            : RepetitionType.weeklyN,
                    repetitionCount: repetitionCount,
                    weekdays: selectedWeekdays.toList()..sort(),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('루틴이 생성되었습니다'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('실패: $e'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('생성'),
            ),
          ],
        ),
      ),
    );
  }
  
  // ============ MEMO WIDGETS ============
  
  Widget _buildMemoItem(BuildContext context, AppProvider provider, TodoModel memo) {
    final isEditing = _editingTodoId == memo.id;
    final isSelected = _selectedTodoIds.contains(memo.id);
    
    if (isEditing) {
      return _buildInlineMemoEditItem(provider, memo);
    }
    
    return GestureDetector(
      onTap: () {
        if (_isMultiSelectMode) {
          _toggleTodoSelection(memo.id);
        } else {
          _startInlineEdit(memo);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.withValues(alpha: 0.1) : Colors.transparent,
          border: Border(
            bottom: const BorderSide(color: AppTheme.divider, width: 0.5),
            left: isSelected
                ? const BorderSide(color: Colors.orange, width: 3)
                : BorderSide.none,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox for multi-select
            GestureDetector(
              onTap: () => _toggleTodoSelection(memo.id),
              child: Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Colors.orange 
                      : memo.completed 
                          ? AppTheme.textTertiary 
                          : Colors.transparent,
                  border: Border.all(
                    color: isSelected 
                        ? Colors.orange 
                        : memo.completed 
                            ? AppTheme.textTertiary 
                            : Colors.orange.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : memo.completed
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
              ),
            ),
            const SizedBox(width: 12),
            
            // Content
            Expanded(
              child: Text(
                memo.text.isEmpty ? '메모 없음' : memo.text,
                style: TextStyle(
                  fontSize: 16,
                  color: memo.completed ? AppTheme.textTertiary : AppTheme.textPrimary,
                  decoration: memo.completed ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            
            // Actions
            if (!_isMultiSelectMode) ...[
              // Assign date button (날짜 할당)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textTertiary),
                padding: EdgeInsets.zero,
                onSelected: (value) => _handleMemoAction(context, provider, memo, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'assignDate',
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('날짜 할당'),
                      ],
                    ),
                  ),
                  if (!memo.completed)
                    const PopupMenuItem(
                      value: 'complete',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 18, color: Colors.green),
                          SizedBox(width: 8),
                          Text('완료하기'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                        SizedBox(width: 8),
                        Text('삭제'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildInlineMemoEditItem(AppProvider provider, TodoModel memo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        border: const Border(
          bottom: BorderSide(color: AppTheme.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orange, width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _editController,
              focusNode: _editFocus,
              autofocus: true,
              style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _saveInlineEdit(provider, memo),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check, color: Colors.orange),
            onPressed: () => _saveInlineEdit(provider, memo),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textTertiary),
            onPressed: _cancelInlineEdit,
          ),
        ],
      ),
    );
  }
  
  void _handleMemoAction(BuildContext context, AppProvider provider, TodoModel memo, String action) {
    switch (action) {
      case 'assignDate':
        _showAssignDateDialog(context, provider, memo);
        break;
      case 'complete':
        provider.toggleTodoComplete(memo);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('메모 완료'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
        break;
      case 'delete':
        provider.deleteTodo(memo.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('메모 삭제됨'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
        break;
    }
  }
  
  void _showAssignDateDialog(BuildContext context, AppProvider provider, TodoModel memo) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ko'),
    );
    
    if (pickedDate != null && mounted) {
      await provider.assignDateToMemo(memo, pickedDate);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('메모가 ${pickedDate.month}/${pickedDate.day} 할 일로 이동되었습니다'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  Widget _buildNewMemoInput(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        border: const Border(
          bottom: BorderSide(color: AppTheme.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orange, width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _newMemoController,
              focusNode: _newMemoFocus,
              autofocus: true,
              enabled: !_isSubmittingMemo,
              style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: _isSubmittingMemo ? '생성 중...' : '메모를 입력하세요',
                hintStyle: const TextStyle(color: AppTheme.textTertiary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (text) => _submitNewMemo(provider, text),
            ),
          ),
          if (_isSubmittingMemo)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.check, size: 22),
              color: Colors.orange,
              onPressed: () => _submitNewMemo(provider, _newMemoController.text),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              color: AppTheme.textTertiary,
              onPressed: _cancelAddingMemo,
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildAddMemoButton() {
    return InkWell(
      onTap: _startAddingMemo,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.add,
                size: 16,
                color: Colors.orange.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '메모 추가',
              style: TextStyle(
                fontSize: 16,
                color: Colors.orange.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _startAddingMemo() {
    setState(() => _isAddingMemo = true);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _newMemoFocus.requestFocus();
    });
  }
  
  void _cancelAddingMemo() {
    setState(() {
      _isAddingMemo = false;
      _isSubmittingMemo = false;
      _newMemoController.clear();
    });
  }
  
  Future<void> _submitNewMemo(AppProvider provider, String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      _cancelAddingMemo();
      return;
    }
    
    if (_isSubmittingMemo) return;
    setState(() => _isSubmittingMemo = true);
    
    try {
      await provider.createMemo(text: trimmedText);
      
      if (mounted) {
        _newMemoController.clear();
        setState(() => _isSubmittingMemo = false);
        
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && _isAddingMemo) _newMemoFocus.requestFocus();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingMemo = false);
      }
    }
  }
}

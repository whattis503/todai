import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/todo_model.dart';
import '../models/routine_model.dart';
import '../services/calendar_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fullscreen_timer.dart';

enum CalendarViewMode { month, week }

class CombinedScreen extends StatefulWidget {
  const CombinedScreen({super.key});

  @override
  State<CombinedScreen> createState() => _CombinedScreenState();
}

class _CombinedScreenState extends State<CombinedScreen> {
  CalendarViewMode _viewMode = CalendarViewMode.month;
  late PageController _monthPageController;
  late ScrollController _weekScrollController;
  DateTime _focusedDate = DateTime.now();
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

  @override
  void initState() {
    super.initState();
    _monthPageController = PageController(initialPage: 500);
    _weekScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryLoadGoogleEvents();
    });
  }

  @override
  void dispose() {
    _newTodoController.dispose();
    _newTodoFocus.dispose();
    _editController.dispose();
    _editFocus.dispose();
    _monthPageController.dispose();
    _weekScrollController.dispose();
    super.dispose();
  }

  Future<void> _tryLoadGoogleEvents() async {
    if (!mounted) return;
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (!provider.authService.hasCalendarAccess) return;
    
    DateTime start, end;
    if (_viewMode == CalendarViewMode.month) {
      start = DateTime(_focusedDate.year, _focusedDate.month, 1);
      end = DateTime(_focusedDate.year, _focusedDate.month + 1, 0, 23, 59, 59);
    } else {
      final weekStart = _focusedDate.subtract(Duration(days: _focusedDate.weekday - 1));
      start = DateTime(weekStart.year, weekStart.month, weekStart.day);
      end = start.add(const Duration(days: 7));
    }

    try {
      await provider.loadCalendarEvents(start, end);
      if (mounted) {
        setState(() => _googleEvents = provider.calendarEvents);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final todos = provider.organizedTodos;
        final selectedDate = provider.selectedDate;
        final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());

        return Column(
          children: [
            // Calendar section
            _buildCalendarSection(provider),
            
            const Divider(height: 1, color: AppTheme.divider),
            
            // Selected date header
            _buildDateHeader(selectedDate, isToday, provider),
            
            // Todo list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  if (todos.isEmpty && !_isAddingTodo)
                    _buildEmptyState()
                  else
                    ...todos.map((todo) => _buildTodoItem(context, provider, todo)),
                  
                  if (_isAddingTodo) _buildNewTodoInput(provider),
                  
                  _buildAddTodoButton(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalendarSection(AppProvider provider) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Text(
                DateFormat('yyyy년 M월').format(_focusedDate),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              // View mode toggle
              _buildViewModeToggle(),
            ],
          ),
        ),
        
        // Calendar view
        if (_viewMode == CalendarViewMode.month)
          _buildMonthView(provider)
        else
          _buildWeekView(provider),
      ],
    );
  }

  Widget _buildViewModeToggle() {
    return Row(
      children: [
        _buildToggleButton('월', CalendarViewMode.month),
        const SizedBox(width: 8),
        _buildToggleButton('주', CalendarViewMode.week),
      ],
    );
  }

  Widget _buildToggleButton(String label, CalendarViewMode mode) {
    final isSelected = _viewMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _viewMode = mode);
        _tryLoadGoogleEvents();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.textPrimary : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppTheme.textPrimary : AppTheme.divider,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? AppTheme.background : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthView(AppProvider provider) {
    return SizedBox(
      height: 280,
      child: PageView.builder(
        controller: _monthPageController,
        onPageChanged: (index) {
          final monthOffset = index - 500;
          final now = DateTime.now();
          setState(() {
            _focusedDate = DateTime(now.year, now.month + monthOffset, 1);
          });
          _tryLoadGoogleEvents();
        },
        itemBuilder: (context, index) {
          final monthOffset = index - 500;
          final now = DateTime.now();
          final monthDate = DateTime(now.year, now.month + monthOffset, 1);
          return _buildMonthGrid(provider, monthDate);
        },
      ),
    );
  }

  Widget _buildMonthGrid(AppProvider provider, DateTime monthDate) {
    final firstDay = DateTime(monthDate.year, monthDate.month, 1);
    final lastDay = DateTime(monthDate.year, monthDate.month + 1, 0);
    final startWeekday = firstDay.weekday;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: ['월', '화', '수', '목', '금', '토', '일'].map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          
          // Days grid
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: 42,
              itemBuilder: (context, index) {
                final dayOffset = index - (startWeekday - 1);
                if (dayOffset < 1 || dayOffset > lastDay.day) {
                  return const SizedBox();
                }
                
                final date = DateTime(monthDate.year, monthDate.month, dayOffset);
                final isToday = DateUtils.isSameDay(date, DateTime.now());
                final isSelected = DateUtils.isSameDay(date, provider.selectedDate);
                final hasGoogleEvents = _googleEvents.any((e) => DateUtils.isSameDay(e.start, date));
                
                return GestureDetector(
                  onTap: () {
                    provider.setSelectedDate(date);
                    _showDatePopup(context, provider, date);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppTheme.accent 
                          : isToday 
                              ? AppTheme.accentLight 
                              : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayOffset',
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected 
                                ? Colors.white 
                                : isToday 
                                    ? AppTheme.accent 
                                    : AppTheme.textPrimary,
                            fontWeight: isToday || isSelected ? FontWeight.w600 : FontWeight.w400,
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
        ],
      ),
    );
  }

  Widget _buildWeekView(AppProvider provider) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        controller: _weekScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          // Infinite scroll: index 0 = today, negative = past, positive = future
          final date = DateTime.now().add(Duration(days: index - 365));
          final isToday = DateUtils.isSameDay(date, DateTime.now());
          final isSelected = DateUtils.isSameDay(date, provider.selectedDate);
          
          return GestureDetector(
            onTap: () {
              provider.setSelectedDate(date);
            },
            child: Container(
              width: 50,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
                    DateFormat('E', 'ko').format(date).substring(0, 1),
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected 
                          ? Colors.white 
                          : AppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected 
                          ? Colors.white 
                          : isToday 
                              ? AppTheme.accent 
                              : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDatePopup(BuildContext context, AppProvider provider, DateTime date) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Consumer<AppProvider>(
          builder: (context, provider, _) {
            final todos = provider.organizedTodos;
            final dayEvents = _googleEvents.where((e) => DateUtils.isSameDay(e.start, date)).toList();
            
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormat('M월 d일 (E)', 'ko').format(date),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Google Calendar events
                  if (dayEvents.isNotEmpty) ...[
                    const Text(
                      'Google 캘린더',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...dayEvents.map((event) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event, size: 16, color: AppTheme.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.summary,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                Text(
                                  '${DateFormat('HH:mm').format(event.start)} - ${DateFormat('HH:mm').format(event.end)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 16),
                  ],
                  
                  // Todos
                  const Text(
                    '할 일',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  if (todos.isEmpty)
                    const Text(
                      '할 일이 없습니다',
                      style: TextStyle(color: AppTheme.textTertiary),
                    )
                  else
                    ...todos.take(5).map((todo) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: todo.completed ? AppTheme.accent : Colors.transparent,
                              border: Border.all(
                                color: todo.completed ? AppTheme.accent : AppTheme.textTertiary,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: todo.completed
                                ? const Icon(Icons.check, size: 12, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              todo.text,
                              style: TextStyle(
                                fontSize: 14,
                                decoration: todo.completed ? TextDecoration.lineThrough : null,
                                color: todo.completed ? AppTheme.textTertiary : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (todo.estimatedTime != null)
                            Text(
                              '${todo.estimatedTime}분',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    )),
                  
                  if (todos.length > 5)
                    Text(
                      '외 ${todos.length - 5}개 더보기',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDateHeader(DateTime date, bool isToday, AppProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isToday ? '오늘' : DateFormat('EEEE', 'ko').format(date),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                DateFormat('yyyy년 M월 d일').format(date),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Today button
          if (!isToday)
            GestureDetector(
              onTap: () => provider.setSelectedDate(DateTime.now()),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.accent),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '오늘',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
    
    if (isEditing) {
      return _buildInlineEditItem(provider, todo, indentLevel);
    }
    
    return GestureDetector(
      onTap: () => _startInlineEdit(todo),
      child: Container(
        padding: EdgeInsets.only(
          left: 20.0 + (indentLevel * 24),
          right: 8,
          top: 12,
          bottom: 12,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.divider, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            GestureDetector(
              onTap: () => provider.toggleTodoComplete(todo),
              child: Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: todo.completed ? AppTheme.accent : Colors.transparent,
                  border: Border.all(
                    color: todo.completed ? AppTheme.accent : AppTheme.textTertiary,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: todo.completed
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
            
            // Actions
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
                    // Clear time - explicitly set to null
                    await provider.firestoreService.updateTodo(
                      todo.copyWith(estimatedTime: null),
                    );
                  } else {
                    final current = todo.estimatedTime ?? 0;
                    await provider.updateTodoEstimatedTime(todo, current + minutes);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 1, child: Text('+1분')),
                  const PopupMenuItem(value: 5, child: Text('+5분')),
                  const PopupMenuItem(value: 10, child: Text('+10분')),
                  const PopupMenuItem(value: 30, child: Text('+30분')),
                  if (todo.estimatedTime != null)
                    const PopupMenuItem(value: -1, child: Text('시간 삭제')),
                ],
              ),
            ],
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textTertiary),
              padding: EdgeInsets.zero,
              onSelected: (value) => _handleTodoAction(context, provider, todo, value),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('수정')),
                const PopupMenuItem(value: 'calendar', child: Text('캘린더에 추가')),
                const PopupMenuItem(value: 'routine', child: Text('루틴으로 만들기')),
                const PopupMenuItem(value: 'delete', child: Text('삭제')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineEditItem(AppProvider provider, TodoModel todo, int indentLevel) {
    return Container(
      padding: EdgeInsets.only(
        left: 20.0 + (indentLevel * 24),
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
          // Checkbox
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.accent, width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          
          // Edit field
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
          
          // Save button
          IconButton(
            icon: const Icon(Icons.check, color: AppTheme.accent),
            onPressed: () => _saveInlineEdit(provider, todo),
          ),
          
          // Cancel button
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('할 일이 추가되었습니다'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('추가 실패: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
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
      case 'edit':
        _showEditTodoDialog(context, provider, todo);
        break;
      case 'calendar':
        _showAddToCalendarDialog(context, provider, todo);
        break;
      case 'routine':
        _showMakeRoutineDialog(context, provider, todo);
        break;
      case 'delete':
        provider.deleteTodo(todo.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('삭제되었습니다'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
                  // Update both text and estimated time
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
}

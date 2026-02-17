import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/todo_model.dart';
import '../models/routine_model.dart';
import '../theme/app_theme.dart';
import '../widgets/fullscreen_timer.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final TextEditingController _newTodoController = TextEditingController();
  final FocusNode _newTodoFocus = FocusNode();
  bool _isAddingTodo = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _newTodoController.dispose();
    _newTodoFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final date = provider.selectedDate;
        final todos = provider.organizedTodos;
        final isToday = DateUtils.isSameDay(date, DateTime.now());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _buildHeader(context, date, isToday, provider),
            
            const Divider(height: 1, color: AppTheme.divider),
            
            // Todo list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  // Empty state or todos
                  if (todos.isEmpty && !_isAddingTodo)
                    _buildEmptyState()
                  else
                    ...todos.map((todo) => _buildTodoItem(context, provider, todo)),
                  
                  // New todo input
                  if (_isAddingTodo) _buildNewTodoInput(provider),
                  
                  // Add todo button
                  _buildAddTodoButton(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, DateTime date, bool isToday, AppProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? 'Today' : DateFormat('EEEE').format(date),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMMM d, yyyy').format(date),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          
          // Date navigation
          Row(
            children: [
              _buildDateButton(
                icon: Icons.chevron_left,
                onTap: () => provider.setSelectedDate(
                  date.subtract(const Duration(days: 1)),
                ),
              ),
              const SizedBox(width: 8),
              _buildDateButton(
                icon: Icons.today_outlined,
                onTap: () => provider.setSelectedDate(DateTime.now()),
              ),
              const SizedBox(width: 8),
              _buildDateButton(
                icon: Icons.chevron_right,
                onTap: () => provider.setSelectedDate(
                  date.add(const Duration(days: 1)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.divider),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18, color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 56,
            color: AppTheme.textTertiary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 20),
          const Text(
            'No tasks for today',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap below to add your first task',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoItem(BuildContext context, AppProvider provider, TodoModel todo) {
    final indentLevel = provider.getIndentLevel(todo);
    
    return Container(
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
                // Text
                Text(
                  todo.text.isEmpty ? 'Untitled' : todo.text,
                  style: TextStyle(
                    fontSize: 16,
                    color: todo.completed ? AppTheme.textTertiary : AppTheme.textPrimary,
                    decoration: todo.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                
                // Time info
                if (todo.estimatedTime != null || todo.actualTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        if (todo.estimatedTime != null)
                          _buildTimeChip('${todo.estimatedTime}min', AppTheme.accentLight, AppTheme.accent),
                        if (todo.actualTime != null) ...[
                          const SizedBox(width: 8),
                          _buildTimeChip('${todo.actualTime}min done', AppTheme.surface, AppTheme.textSecondary),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // Actions - only for incomplete todos
          if (!todo.completed) ...[
            // Start timer
            IconButton(
              icon: Icon(
                todo.timerStartedAt != null ? Icons.pause : Icons.play_arrow_outlined,
                size: 22,
              ),
              color: AppTheme.accent,
              onPressed: () => _showFullscreenTimer(context, provider, todo),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              tooltip: 'Start Timer',
            ),
            // Time preset buttons
            PopupMenuButton<int>(
              icon: const Icon(Icons.schedule_outlined, size: 20, color: AppTheme.textTertiary),
              padding: EdgeInsets.zero,
              tooltip: 'Set Time',
              onSelected: (minutes) async {
                if (minutes < 0) {
                  // Clear time
                  await provider.updateTodoEstimatedTime(todo, null);
                } else {
                  final current = todo.estimatedTime ?? 0;
                  await provider.updateTodoEstimatedTime(todo, current + minutes);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 5, child: Text('+5 min')),
                const PopupMenuItem(value: 10, child: Text('+10 min')),
                const PopupMenuItem(value: 30, child: Text('+30 min')),
                const PopupMenuItem(value: 60, child: Text('+1 hour')),
                if (todo.estimatedTime != null)
                  const PopupMenuItem(value: -1, child: Text('Clear time')),
              ],
            ),
          ],
          // More options
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textTertiary),
            padding: EdgeInsets.zero,
            onSelected: (value) => _handleTodoAction(context, provider, todo, value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'calendar', child: Text('Add to Calendar')),
              const PopupMenuItem(value: 'routine', child: Text('Make Routine')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
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
                hintText: _isSubmitting ? 'Creating...' : 'What needs to be done?',
                hintStyle: const TextStyle(color: AppTheme.textTertiary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (text) => _submitNewTodo(provider, text),
              textInputAction: TextInputAction.done,
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
              tooltip: 'Add',
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              color: AppTheme.textTertiary,
              onPressed: _cancelAddingTodo,
              tooltip: 'Cancel',
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
              'Add a task',
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
      if (mounted) {
        _newTodoFocus.requestFocus();
      }
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
      // Close input if empty
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
        
        // Keep input open for continuous adding - request focus after state update
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && _isAddingTodo) {
            _newTodoFocus.requestFocus();
          }
        });
        
        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task added'),
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
            content: Text('Failed to create task: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showFullscreenTimer(BuildContext context, AppProvider provider, TodoModel todo) {
    // Start timer in provider if not already started
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
            content: Text('Task deleted'),
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
          title: const Text('Edit Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Task description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Estimated time',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final time in [5, 15, 30, 60, null])
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
                            time == null ? 'None' : (time < 60 ? '${time}m' : '${time ~/ 60}h'),
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
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isNotEmpty) {
                  await provider.updateTodoText(todo, controller.text.trim());
                  await provider.updateTodoEstimatedTime(todo, estimatedTime);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
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
          title: const Text('Add to Calendar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(todo.text, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, size: 20),
                title: Text(DateFormat('MMM d, yyyy').format(selectedDate)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setDialogState(() => selectedDate = date);
                  }
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
                  if (time != null) {
                    setDialogState(() => selectedTime = time);
                  }
                },
              ),
              
              if (todo.estimatedTime != null)
                Text(
                  'Duration: ${todo.estimatedTime} min',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
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
                      content: Text(success ? 'Added to calendar' : 'Failed to add. Please sign out and sign in again to grant calendar access.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Add'),
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
          title: const Text('Create Routine'),
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
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weeklyOnce', child: Text('Weekly (specific days)')),
                    DropdownMenuItem(value: 'weeklyN', child: Text('Weekly (n times)')),
                  ],
                  onChanged: (value) => setDialogState(() => repetitionType = value!),
                ),
                
                if (repetitionType == 'weeklyN') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Times per week: '),
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
                      for (final day in [(1, 'M'), (2, 'T'), (3, 'W'), (4, 'T'), (5, 'F'), (6, 'S'), (7, 'S')])
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
              child: const Text('Cancel'),
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
                        content: Text('Routine created'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create routine: $e'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

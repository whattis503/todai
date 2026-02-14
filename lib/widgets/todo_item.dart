import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/todo_model.dart';
import '../theme/app_theme.dart';

class TodoItem extends StatefulWidget {
  final TodoModel todo;
  final int indentLevel;
  final VoidCallback onToggle;
  final Function(String) onTextChanged;
  final VoidCallback onDelete;
  final VoidCallback onIndent;
  final VoidCallback onOutdent;
  final Function(int?) onEstimatedTimeChanged;
  final VoidCallback onStartTimer;
  final VoidCallback onAddToCalendar;
  final VoidCallback onMakeRoutine;
  final VoidCallback onNewTodoBelow;

  const TodoItem({
    super.key,
    required this.todo,
    required this.indentLevel,
    required this.onToggle,
    required this.onTextChanged,
    required this.onDelete,
    required this.onIndent,
    required this.onOutdent,
    required this.onEstimatedTimeChanged,
    required this.onStartTimer,
    required this.onAddToCalendar,
    required this.onMakeRoutine,
    required this.onNewTodoBelow,
  });

  @override
  State<TodoItem> createState() => _TodoItemState();
}

class _TodoItemState extends State<TodoItem> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isEditing = false;
  bool _showActions = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.todo.text);
    _focusNode = FocusNode();
    
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isEditing) {
        _saveText();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TodoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.todo.text != widget.todo.text && !_isEditing) {
      _controller.text = widget.todo.text;
    }
  }

  void _saveText() {
    if (_controller.text != widget.todo.text) {
      widget.onTextChanged(_controller.text);
    }
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _showActions = true),
      onExit: (_) => setState(() => _showActions = false),
      child: GestureDetector(
        onTap: () {
          setState(() => _isEditing = true);
          _focusNode.requestFocus();
        },
        child: Container(
          padding: EdgeInsets.only(
            left: 20 + (widget.indentLevel * 24),
            right: 8,
            top: 8,
            bottom: 8,
          ),
          decoration: BoxDecoration(
            color: _isEditing ? AppTheme.surface : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              GestureDetector(
                onTap: widget.onToggle,
                child: Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: widget.todo.completed
                        ? AppTheme.accent
                        : Colors.transparent,
                    border: Border.all(
                      color: widget.todo.completed
                          ? AppTheme.accent
                          : AppTheme.textTertiary,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: widget.todo.completed
                      ? const Icon(
                          Icons.check,
                          size: 10,
                          color: Colors.white,
                        )
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
                    KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: (event) {
                        if (event is KeyDownEvent) {
                          if (event.logicalKey == LogicalKeyboardKey.enter) {
                            _saveText();
                            widget.onNewTodoBelow();
                          } else if (event.logicalKey == LogicalKeyboardKey.tab) {
                            if (HardwareKeyboard.instance.isShiftPressed) {
                              widget.onOutdent();
                            } else {
                              widget.onIndent();
                            }
                          } else if (event.logicalKey == LogicalKeyboardKey.backspace &&
                              _controller.text.isEmpty) {
                            widget.onDelete();
                          }
                        }
                      },
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          decoration: widget.todo.completed
                              ? TextDecoration.lineThrough
                              : null,
                          color: widget.todo.completed
                              ? AppTheme.textTertiary
                              : AppTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter task...',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintStyle: TextStyle(
                            color: AppTheme.textTertiary.withValues(alpha: 0.5),
                          ),
                        ),
                        maxLines: null,
                        onSubmitted: (_) {
                          _saveText();
                          widget.onNewTodoBelow();
                        },
                      ),
                    ),

                    // Time info
                    if (widget.todo.estimatedTime != null ||
                        widget.todo.actualTime != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            if (widget.todo.estimatedTime != null)
                              _buildTimeChip(
                                '${widget.todo.estimatedTime}min',
                                isEstimated: true,
                              ),
                            if (widget.todo.actualTime != null) ...[
                              if (widget.todo.estimatedTime != null)
                                const SizedBox(width: 8),
                              _buildTimeChip(
                                '${widget.todo.actualTime}min actual',
                                isEstimated: false,
                              ),
                            ],
                          ],
                        ),
                      ),

                    // Time buttons (when editing)
                    if (_isEditing && !widget.todo.completed)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final minutes in [1, 5, 10, 30])
                              _buildAddTimeButton(minutes),
                            if (widget.todo.estimatedTime != null)
                              _buildClearTimeButton(),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Actions
              if (_showActions || _isEditing)
                _buildActionButtons()
              else if (!widget.todo.completed)
                _buildStartButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeChip(String text, {required bool isEstimated}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isEstimated ? AppTheme.accentLight : AppTheme.surface,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: isEstimated ? AppTheme.accent : AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildAddTimeButton(int minutes) {
    return GestureDetector(
      onTap: () {
        final current = widget.todo.estimatedTime ?? 0;
        widget.onEstimatedTimeChanged(current + minutes);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.divider, width: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          '+${minutes}m',
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildClearTimeButton() {
    return GestureDetector(
      onTap: () => widget.onEstimatedTimeChanged(null),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.divider, width: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
        child: const Text(
          'Clear',
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return GestureDetector(
      onTap: widget.onStartTimer,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.divider, width: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
        child: const Icon(
          Icons.play_arrow_outlined,
          size: 14,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.todo.completed) ...[
          _buildActionButton(
            Icons.play_arrow_outlined,
            widget.onStartTimer,
            tooltip: 'Start timer',
          ),
          _buildActionButton(
            Icons.calendar_today_outlined,
            widget.onAddToCalendar,
            tooltip: 'Add to calendar',
          ),
          _buildActionButton(
            Icons.repeat_outlined,
            widget.onMakeRoutine,
            tooltip: 'Make routine',
          ),
        ],
        PopupMenuButton<String>(
          icon: const Icon(
            Icons.more_vert,
            size: 14,
            color: AppTheme.textTertiary,
          ),
          padding: EdgeInsets.zero,
          itemBuilder: (context) => [
            if (!widget.todo.completed)
              const PopupMenuItem(
                value: 'indent',
                child: Text('Indent'),
              ),
            if (widget.indentLevel > 0)
              const PopupMenuItem(
                value: 'outdent',
                child: Text('Outdent'),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'indent':
                widget.onIndent();
                break;
              case 'outdent':
                widget.onOutdent();
                break;
              case 'delete':
                widget.onDelete();
                break;
            }
          },
        ),
      ],
    );
  }

  Widget _buildActionButton(
    IconData icon,
    VoidCallback onTap, {
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(right: 2),
          child: Icon(
            icon,
            size: 14,
            color: AppTheme.textTertiary,
          ),
        ),
      ),
    );
  }
}

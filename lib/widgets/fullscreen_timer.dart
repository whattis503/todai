import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/todo_model.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class FullscreenTimer extends StatefulWidget {
  final TodoModel todo;

  const FullscreenTimer({super.key, required this.todo});

  @override
  State<FullscreenTimer> createState() => _FullscreenTimerState();
}

class _FullscreenTimerState extends State<FullscreenTimer> {
  late Timer _timer;
  late TodoModel _todo;
  int _elapsedSeconds = 0;
  bool _isPaused = false;
  bool _isOvertime = false;

  @override
  void initState() {
    super.initState();
    _todo = widget.todo;
    
    // Calculate initial elapsed time
    _elapsedSeconds = _todo.timerPausedDuration;
    if (_todo.timerStartedAt != null) {
      _elapsedSeconds += DateTime.now().difference(_todo.timerStartedAt!).inSeconds;
    }
    
    // Start the timer
    _startInternalTimer();
    
    // Start timer in Firestore if not already started
    if (_todo.timerStartedAt == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<AppProvider>(context, listen: false).startTimer(_todo);
      });
    }
    
    // Keep screen awake
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _startInternalTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) {
        setState(() {
          _elapsedSeconds++;
          _checkOvertime();
        });
      }
    });
  }

  void _checkOvertime() {
    if (_todo.estimatedTime != null) {
      final estimatedSeconds = _todo.estimatedTime! * 60;
      if (_elapsedSeconds > estimatedSeconds && !_isOvertime) {
        setState(() => _isOvertime = true);
        HapticFeedback.mediumImpact();
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatOvertimeText() {
    if (_todo.estimatedTime == null) return '';
    
    final estimatedSeconds = _todo.estimatedTime! * 60;
    if (_elapsedSeconds <= estimatedSeconds) return '';
    
    final overtime = _elapsedSeconds - estimatedSeconds;
    return '+${_formatTime(overtime)}';
  }

  double _getProgress() {
    if (_todo.estimatedTime == null) return 0;
    
    final estimatedSeconds = _todo.estimatedTime! * 60;
    if (estimatedSeconds == 0) return 0;
    
    return (_elapsedSeconds / estimatedSeconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _getProgress();
    final overtimeText = _formatOvertimeText();
    
    return Scaffold(
      backgroundColor: _isOvertime 
          ? AppTheme.overtime.withValues(alpha: 0.1)
          : AppTheme.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Spacer(),
                  
                  // Todo text
                  Text(
                    _todo.text,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: _isOvertime ? AppTheme.overtime : AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const Spacer(),
                  
                  // Timer display
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w200,
                      color: _isOvertime ? AppTheme.overtime : AppTheme.textPrimary,
                      letterSpacing: -2,
                      fontFamily: 'system-ui',
                    ),
                    child: Text(_formatTime(_elapsedSeconds)),
                  ),
                  
                  // Overtime indicator
                  if (overtimeText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        overtimeText,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          color: AppTheme.overtime,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 32),
                  
                  // Progress bar (if estimated time exists)
                  if (_todo.estimatedTime != null) ...[
                    _buildProgressBar(progress),
                    const SizedBox(height: 12),
                    Text(
                      '${(_elapsedSeconds / 60).toStringAsFixed(0)} / ${_todo.estimatedTime} min',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _isOvertime ? AppTheme.overtime : AppTheme.textTertiary,
                      ),
                    ),
                  ],
                  
                  // Paused indicator
                  if (_isPaused)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.divider),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          'PAUSED',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  
                  const Spacer(flex: 2),
                  
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Pause/Resume button
                      _buildActionButton(
                        _isPaused ? 'Resume' : 'Pause',
                        _isPaused ? Icons.play_arrow_outlined : Icons.pause_outlined,
                        _togglePause,
                        isPrimary: false,
                      ),
                      
                      const SizedBox(width: 24),
                      
                      // Complete button
                      _buildActionButton(
                        'Complete',
                        Icons.check,
                        _complete,
                        isPrimary: true,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Reset and Exit buttons row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Reset timer button
                      GestureDetector(
                        onTap: _resetTimer,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh, size: 16, color: AppTheme.textTertiary),
                              const SizedBox(width: 6),
                              Text(
                                'Reset',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 24),
                      
                      // Exit (pause and save)
                      GestureDetector(
                        onTap: _exitAndPause,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.exit_to_app, size: 16, color: AppTheme.textTertiary),
                              const SizedBox(width: 6),
                              Text(
                                'Exit',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return Container(
      height: 2,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.divider,
        borderRadius: BorderRadius.circular(1),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: _isOvertime ? AppTheme.overtime : AppTheme.accent,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onTap, {
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.textPrimary : Colors.transparent,
          border: Border.all(
            color: isPrimary ? AppTheme.textPrimary : AppTheme.divider,
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isPrimary ? AppTheme.background : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isPrimary ? AppTheme.background : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (_isPaused) {
      provider.pauseTimer(_todo);
    } else {
      provider.startTimer(_todo);
    }
  }

  void _complete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Task'),
        content: Text(
          'Mark "${_todo.text}" as complete?\n\n'
          'Time recorded: ${(_elapsedSeconds / 60).round()} minutes',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveAndExit(completed: true);
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  void _resetTimer() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Timer'),
        content: const Text(
          '타이머를 0부터 다시 시작하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performReset();
            },
            child: const Text('초기화'),
          ),
        ],
      ),
    );
  }
  
  void _performReset() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // Reset the timer in Firestore
    provider.resetTimer(_todo);
    
    // Reset local state
    setState(() {
      _elapsedSeconds = 0;
      _isPaused = false;
      _isOvertime = false;
    });
    
    // Restart the timer
    provider.startTimer(_todo);
  }
  
  void _exitAndPause() {
    // Pause and save current time, then exit without popup
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // Update todo with current elapsed time
    final updatedTodo = _todo.copyWith(
      timerPausedDuration: _elapsedSeconds,
      clearTimerStartedAt: true,
    );
    provider.pauseTimerWithDuration(updatedTodo, _elapsedSeconds);
    
    // Exit immediately
    Navigator.pop(context);
  }

  void _saveAndExit({required bool completed}) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    if (completed) {
      // Create a fresh todo reference with updated timer data
      final updatedTodo = _todo.copyWith(
        timerPausedDuration: _elapsedSeconds,
        clearTimerStartedAt: true,
      );
      provider.completeTimer(updatedTodo);
    } else {
      provider.pauseTimer(_todo);
    }
    
    Navigator.pop(context);
  }
}

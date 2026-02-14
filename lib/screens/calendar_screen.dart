import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../services/calendar_service.dart';
import '../theme/app_theme.dart';

enum CalendarViewMode { month, week, day }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarViewMode _viewMode = CalendarViewMode.month;
  DateTime _focusedDate = DateTime.now();
  List<CalendarEvent> _googleEvents = [];
  bool _isLoading = false;
  bool _showGoogleCalendar = false;

  @override
  void initState() {
    super.initState();
    // Try to load Google Calendar events in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryLoadGoogleEvents();
    });
  }

  Future<void> _tryLoadGoogleEvents() async {
    if (!mounted) return;
    
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // Check if we have calendar access - silently skip if not available
    if (!provider.authService.hasCalendarAccess) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _googleEvents = [];
          _showGoogleCalendar = false;
        });
      }
      return;
    }
    
    setState(() => _isLoading = true);
    
    DateTime start, end;
    switch (_viewMode) {
      case CalendarViewMode.month:
        start = DateTime(_focusedDate.year, _focusedDate.month, 1);
        end = DateTime(_focusedDate.year, _focusedDate.month + 1, 0, 23, 59, 59);
        break;
      case CalendarViewMode.week:
        final weekStart = _focusedDate.subtract(Duration(days: _focusedDate.weekday - 1));
        start = DateTime(weekStart.year, weekStart.month, weekStart.day);
        end = start.add(const Duration(days: 7));
        break;
      case CalendarViewMode.day:
        start = DateTime(_focusedDate.year, _focusedDate.month, _focusedDate.day);
        end = start.add(const Duration(days: 1));
        break;
    }

    try {
      await provider.loadCalendarEvents(start, end);
      if (mounted) {
        setState(() {
          _googleEvents = provider.calendarEvents;
          _isLoading = false;
          _showGoogleCalendar = _googleEvents.isNotEmpty;
        });
      }
    } catch (e) {
      // Silently handle calendar errors - this is an optional feature
      if (mounted) {
        setState(() {
          _isLoading = false;
          _googleEvents = [];
          _showGoogleCalendar = false;
          // Don't set error - calendar is optional
        });
      }
    }
  }

  Future<void> _requestCalendarAccess() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final success = await provider.authService.requestCalendarAccess();
      
      if (success) {
        await _tryLoadGoogleEvents();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Calendar access granted!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Calendar sync requires re-login. Sign out and back in.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Silently handle - calendar is optional
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            _buildHeader(provider),
            const Divider(height: 1, color: AppTheme.divider),
            _buildViewModeSelector(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.textSecondary,
                      ),
                    )
                  : _buildCalendarView(provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(AppProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Calendar',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMMM yyyy').format(_focusedDate),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          
          // Google Calendar sync button
          if (!provider.authService.hasCalendarAccess)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: _requestCalendarAccess,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.accent),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync, size: 14, color: AppTheme.accent),
                      const SizedBox(width: 4),
                      Text(
                        'Sync',
                        style: TextStyle(fontSize: 12, color: AppTheme.accent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          Row(
            children: [
              _buildNavButton(Icons.chevron_left, () => _navigate(-1)),
              const SizedBox(width: 8),
              _buildNavButton(Icons.today_outlined, () {
                setState(() => _focusedDate = DateTime.now());
                _tryLoadGoogleEvents();
              }),
              const SizedBox(width: 8),
              _buildNavButton(Icons.chevron_right, () => _navigate(1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
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

  Widget _buildViewModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: CalendarViewMode.values.map((mode) {
          final isSelected = _viewMode == mode;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() => _viewMode = mode);
                _tryLoadGoogleEvents();
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.textPrimary : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? AppTheme.textPrimary : AppTheme.divider,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  mode.name[0].toUpperCase() + mode.name.substring(1),
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? AppTheme.background : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarView(AppProvider provider) {
    switch (_viewMode) {
      case CalendarViewMode.month:
        return _buildMonthView(provider);
      case CalendarViewMode.week:
        return _buildWeekView(provider);
      case CalendarViewMode.day:
        return _buildDayView(provider);
    }
  }

  Widget _buildMonthView(AppProvider provider) {
    final firstDay = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final lastDay = DateTime(_focusedDate.year, _focusedDate.month + 1, 0);
    final startWeekday = firstDay.weekday;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          
          // Days grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: 42,
              itemBuilder: (context, index) {
                final dayOffset = index - (startWeekday - 1);
                if (dayOffset < 1 || dayOffset > lastDay.day) {
                  return const SizedBox();
                }
                
                final date = DateTime(_focusedDate.year, _focusedDate.month, dayOffset);
                final isToday = DateUtils.isSameDay(date, DateTime.now());
                final hasGoogleEvents = _googleEvents.any((e) => DateUtils.isSameDay(e.start, date));
                
                return InkWell(
                  onTap: () {
                    provider.setSelectedDate(date);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Viewing ${DateFormat('MMM d').format(date)} - switch to Today tab'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isToday ? AppTheme.accentLight : null,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayOffset',
                          style: TextStyle(
                            fontSize: 14,
                            color: isToday ? AppTheme.accent : AppTheme.textPrimary,
                            fontWeight: isToday ? FontWeight.w500 : FontWeight.w400,
                          ),
                        ),
                        if (hasGoogleEvents)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: const BoxDecoration(
                              color: AppTheme.accent,
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
          
          // Google Calendar status
          if (_showGoogleCalendar && _googleEvents.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${_googleEvents.length} Google Calendar events this month',
                style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeekView(AppProvider provider) {
    final weekStart = _focusedDate.subtract(Duration(days: _focusedDate.weekday - 1));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      itemBuilder: (context, index) {
        final date = weekStart.add(Duration(days: index));
        final dayGoogleEvents = _googleEvents.where((e) => DateUtils.isSameDay(e.start, date)).toList();
        final isToday = DateUtils.isSameDay(date, DateTime.now());

        return InkWell(
          onTap: () {
            provider.setSelectedDate(date);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isToday ? AppTheme.accentLight : null,
              border: Border.all(color: AppTheme.divider),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('E').format(date),
                      style: TextStyle(
                        fontSize: 12,
                        color: isToday ? AppTheme.accent : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('d').format(date),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isToday ? FontWeight.w500 : FontWeight.w400,
                        color: isToday ? AppTheme.accent : AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Tap to view todos',
                      style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                    ),
                  ],
                ),
                if (dayGoogleEvents.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'No Google Calendar events',
                      style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                    ),
                  )
                else
                  ...dayGoogleEvents.map((event) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _buildEventCard(event),
                  )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDayView(AppProvider provider) {
    final dayGoogleEvents = _googleEvents.where((e) => DateUtils.isSameDay(e.start, _focusedDate)).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEEE, MMMM d').format(_focusedDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  provider.setSelectedDate(_focusedDate);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Switch to Today tab to see todos'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text('View Todos'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          const Text(
            'Google Calendar Events',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          
          Expanded(
            child: dayGoogleEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy_outlined,
                          size: 48,
                          color: AppTheme.textTertiary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          provider.authService.hasCalendarAccess
                              ? 'No Google Calendar events'
                              : 'Sync with Google Calendar to see events',
                          style: const TextStyle(color: AppTheme.textTertiary),
                        ),
                        if (!provider.authService.hasCalendarAccess) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _requestCalendarAccess,
                            icon: const Icon(Icons.sync, size: 18),
                            label: const Text('Sync Calendar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.textPrimary,
                              foregroundColor: AppTheme.background,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView(
                    children: dayGoogleEvents.map((event) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildEventCard(event, detailed: true),
                    )).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(CalendarEvent event, {bool detailed = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentLight,
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event, size: 14, color: AppTheme.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.summary,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${DateFormat('HH:mm').format(event.start)} - ${DateFormat('HH:mm').format(event.end)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          if (detailed && event.description != null) ...[
            const SizedBox(height: 8),
            Text(
              event.description!,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _navigate(int direction) {
    setState(() {
      switch (_viewMode) {
        case CalendarViewMode.month:
          _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + direction, 1);
          break;
        case CalendarViewMode.week:
          _focusedDate = _focusedDate.add(Duration(days: 7 * direction));
          break;
        case CalendarViewMode.day:
          _focusedDate = _focusedDate.add(Duration(days: direction));
          break;
      }
    });
    _tryLoadGoogleEvents();
  }
}

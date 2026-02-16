import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/todo_model.dart';
import '../models/routine_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/calendar_service.dart';
import '../services/gemini_service.dart';

class AppProvider extends ChangeNotifier {
  final bool firebaseInitialized;
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final CalendarService _calendarService = CalendarService();
  final GeminiService _geminiService = GeminiService();
  
  AppProvider({this.firebaseInitialized = false});

  User? _user;
  List<TodoModel> _todos = [];
  List<RoutineModel> _routines = [];
  List<CalendarEvent> _calendarEvents = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _error;
  
  StreamSubscription<List<TodoModel>>? _todosSubscription;
  StreamSubscription<List<RoutineModel>>? _routinesSubscription;

  // Getters
  User? get user => _user;
  List<TodoModel> get todos => _todos;
  List<RoutineModel> get routines => _routines;
  List<CalendarEvent> get calendarEvents => _calendarEvents;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  AuthService get authService => _authService;
  FirestoreService get firestoreService => _firestoreService;
  CalendarService get calendarService => _calendarService;
  GeminiService get geminiService => _geminiService;

  // Get todos organized with hierarchy
  List<TodoModel> get organizedTodos {
    final rootTodos = _todos.where((t) => t.parentId == null).toList();
    final List<TodoModel> result = [];
    
    for (final todo in rootTodos) {
      result.add(todo);
      _addChildren(todo.id, result, 1);
    }
    
    return result;
  }

  void _addChildren(String parentId, List<TodoModel> result, int depth) {
    final children = _todos.where((t) => t.parentId == parentId).toList();
    for (final child in children) {
      result.add(child);
      _addChildren(child.id, result, depth + 1);
    }
  }

  int getIndentLevel(TodoModel todo) {
    int level = 0;
    String? currentParentId = todo.parentId;
    while (currentParentId != null) {
      level++;
      final parent = _todos.firstWhere(
        (t) => t.id == currentParentId,
        orElse: () => todo,
      );
      if (parent.id == todo.id) break;
      currentParentId = parent.parentId;
    }
    return level;
  }

  // Initialize
  Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint('AppProvider: Initializing... Firebase: $firebaseInitialized');
    }
    
    _isLoading = true;
    // Don't notify here - avoid calling notifyListeners before widget is built
    
    // If Firebase is not initialized, just set loading to false and return
    if (!firebaseInitialized) {
      if (kDebugMode) {
        debugPrint('AppProvider: Firebase not initialized, showing login screen');
      }
      // Delay to allow widget to build first
      Future.delayed(const Duration(milliseconds: 100), () {
        _isLoading = false;
        notifyListeners();
      });
      return;
    }
    
    try {
      // Load saved Gemini API key
      await _geminiService.loadApiKey();
      // Load stored calendar token
      await _authService.loadStoredToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AppProvider: Error loading saved data: $e');
      }
    }
    
    try {
      _authService.authStateChanges.listen((user) async {
        if (kDebugMode) {
          debugPrint('AppProvider: Auth state changed - user: ${user?.uid}');
        }
        
        _user = user;
        _isLoading = false;
        
        if (user != null) {
          try {
            _firestoreService.setUserId(user.uid);
            _loadTodos();
            _loadRoutines();
            
            try {
              await _generateRoutineTodos();
            } catch (e) {
              if (kDebugMode) {
                debugPrint('AppProvider: Error generating routine todos: $e');
              }
            }
            
            // Auto-load calendar events after login
            try {
              final now = DateTime.now();
              final start = DateTime(now.year, now.month - 1, 1);
              final end = DateTime(now.year, now.month + 2, 0, 23, 59, 59);
              await loadCalendarEvents(start, end);
            } catch (e) {
              if (kDebugMode) {
                debugPrint('AppProvider: Error loading calendar events: $e');
              }
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('AppProvider: Error setting up user data: $e');
            }
          }
        } else {
          _todos = [];
          _routines = [];
          _calendarEvents = [];
          _todosSubscription?.cancel();
          _routinesSubscription?.cancel();
        }
        notifyListeners();
      }, onError: (error) {
        if (kDebugMode) {
          debugPrint('AppProvider: Auth state stream error: $error');
        }
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AppProvider: Error setting up auth listener: $e');
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  // Auth
  Future<bool> signIn() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle();
      _isLoading = false;
      if (user == null) {
        _error = _authService.lastError ?? 'Sign in failed. Please check Firebase console for authorized domains.';
      }
      notifyListeners();
      return user != null;
    } catch (e) {
      _isLoading = false;
      _error = 'Sign in error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    _todos = [];
    _routines = [];
    notifyListeners();
  }

  // Date selection
  void setSelectedDate(DateTime date) {
    if (kDebugMode) {
      debugPrint('AppProvider: Setting selected date to $date');
    }
    _selectedDate = date;
    _loadTodos();
    notifyListeners();
  }

  // Todos
  void _loadTodos() {
    if (kDebugMode) {
      debugPrint('AppProvider: Loading todos for $_selectedDate');
    }
    
    _todosSubscription?.cancel();
    _todosSubscription = _firestoreService
        .getTodosForDate(_selectedDate)
        .listen(
          (todos) {
            if (kDebugMode) {
              debugPrint('AppProvider: Received ${todos.length} todos');
            }
            _todos = todos;
            notifyListeners();
          },
          onError: (error) {
            if (kDebugMode) {
              debugPrint('AppProvider: Todo stream error: $error');
            }
            _error = 'Failed to load todos: $error';
            notifyListeners();
          },
        );
  }

  Future<void> createTodo({
    required String text,
    int? estimatedTime,
    String? parentId,
  }) async {
    if (kDebugMode) {
      debugPrint('AppProvider: Creating todo "$text"');
    }
    
    final maxOrder = _todos.isEmpty 
        ? 0 
        : _todos.map((t) => t.order).reduce((a, b) => a > b ? a : b) + 1;
    
    await _firestoreService.createTodo(
      text: text,
      date: _selectedDate,
      estimatedTime: estimatedTime,
      parentId: parentId,
      order: maxOrder,
    );
  }

  Future<void> updateTodo(TodoModel todo) async {
    await _firestoreService.updateTodo(todo);
  }

  Future<void> deleteTodo(String todoId) async {
    // Also delete children
    final children = _todos.where((t) => t.parentId == todoId).toList();
    for (final child in children) {
      await deleteTodo(child.id);
    }
    await _firestoreService.deleteTodo(todoId);
  }

  Future<void> toggleTodoComplete(TodoModel todo) async {
    final updatedTodo = todo.copyWith(completed: !todo.completed);
    await _firestoreService.updateTodo(updatedTodo);
  }

  Future<void> updateTodoText(TodoModel todo, String text) async {
    final updatedTodo = todo.copyWith(text: text);
    await _firestoreService.updateTodo(updatedTodo);
  }

  Future<void> updateTodoEstimatedTime(TodoModel todo, int? minutes) async {
    final updatedTodo = todo.copyWith(estimatedTime: minutes);
    await _firestoreService.updateTodo(updatedTodo);
  }

  Future<void> updateTodoActualTime(TodoModel todo, int minutes) async {
    final updatedTodo = todo.copyWith(actualTime: minutes);
    await _firestoreService.updateTodo(updatedTodo);
  }

  Future<void> reorderTodos(int oldIndex, int newIndex) async {
    final List<TodoModel> updatedTodos = List.from(organizedTodos);
    final item = updatedTodos.removeAt(oldIndex);
    updatedTodos.insert(newIndex, item);
    await _firestoreService.updateTodoOrder(updatedTodos);
  }

  Future<void> indentTodo(TodoModel todo) async {
    // depth 1 이상이면 더 이상 하위로 못감
    if (getIndentLevel(todo) >= 1) return;
    
    final index = organizedTodos.indexOf(todo);
    if (index > 0) {
      final potentialParent = organizedTodos[index - 1];
      // 부모도 depth 0이어야 함
      if (getIndentLevel(potentialParent) == 0) {
        final updatedTodo = todo.copyWith(parentId: potentialParent.id);
        await _firestoreService.updateTodo(updatedTodo);
      }
    }
  }

  Future<void> outdentTodo(TodoModel todo) async {
    if (todo.parentId != null) {
      // 최상위로 이동 (parentId를 null로)
      final updatedTodo = todo.copyWith(parentId: null);
      await _firestoreService.updateTodo(updatedTodo);
    }
  }

  // Timer
  Future<void> startTimer(TodoModel todo) async {
    final updatedTodo = todo.copyWith(timerStartedAt: DateTime.now());
    await _firestoreService.updateTodo(updatedTodo);
  }

  Future<void> pauseTimer(TodoModel todo) async {
    if (todo.timerStartedAt != null) {
      final elapsed = DateTime.now().difference(todo.timerStartedAt!).inSeconds;
      final updatedTodo = todo.copyWith(
        clearTimerStartedAt: true,
        timerPausedDuration: todo.timerPausedDuration + elapsed,
      );
      await _firestoreService.updateTodo(updatedTodo);
    }
  }
  
  Future<void> pauseTimerWithDuration(TodoModel todo, int totalSeconds) async {
    final updatedTodo = todo.copyWith(
      clearTimerStartedAt: true,
      timerPausedDuration: totalSeconds,
    );
    await _firestoreService.updateTodo(updatedTodo);
  }
  
  Future<void> resetTimer(TodoModel todo) async {
    final updatedTodo = todo.copyWith(
      clearTimerStartedAt: true,
      timerPausedDuration: 0,
    );
    await _firestoreService.updateTodo(updatedTodo);
  }

  Future<void> completeTimer(TodoModel todo) async {
    int totalSeconds = todo.timerPausedDuration;
    if (todo.timerStartedAt != null) {
      totalSeconds += DateTime.now().difference(todo.timerStartedAt!).inSeconds;
    }
    
    final updatedTodo = todo.copyWith(
      completed: true,
      actualTime: (totalSeconds / 60).round(),
      clearTimerStartedAt: true,
      timerPausedDuration: 0,
    );
    await _firestoreService.updateTodo(updatedTodo);
  }

  // Routines
  void _loadRoutines() {
    if (kDebugMode) {
      debugPrint('AppProvider: Loading routines');
    }
    
    _routinesSubscription?.cancel();
    _routinesSubscription = _firestoreService
        .getRoutines()
        .listen(
          (routines) {
            if (kDebugMode) {
              debugPrint('AppProvider: Received ${routines.length} routines');
            }
            _routines = routines;
            notifyListeners();
          },
          onError: (error) {
            if (kDebugMode) {
              debugPrint('AppProvider: Routines stream error: $error');
            }
          },
        );
  }

  Future<void> _generateRoutineTodos() async {
    await _firestoreService.generateTodosFromRoutines(_selectedDate);
  }

  Future<void> createRoutine({
    required String text,
    int? estimatedTime,
    RepetitionType repetitionType = RepetitionType.daily,
    int repetitionCount = 1,
    List<int> weekdays = const [],
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await _firestoreService.createRoutine(
      text: text,
      estimatedTime: estimatedTime,
      repetitionType: repetitionType,
      repetitionCount: repetitionCount,
      weekdays: weekdays,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<void> updateRoutine(RoutineModel routine) async {
    await _firestoreService.updateRoutine(routine);
  }

  Future<void> deleteRoutine(String routineId) async {
    await _firestoreService.deleteRoutine(routineId);
  }

  Future<void> convertTodoToRoutine(TodoModel todo, {
    RepetitionType repetitionType = RepetitionType.daily,
    int repetitionCount = 1,
    List<int> weekdays = const [],
  }) async {
    await createRoutine(
      text: todo.text,
      estimatedTime: todo.estimatedTime,
      repetitionType: repetitionType,
      repetitionCount: repetitionCount,
      weekdays: weekdays,
    );
  }

  // Calendar
  Future<void> loadCalendarEvents(DateTime start, DateTime end) async {
    try {
      final token = await _authService.getAccessToken();
      if (kDebugMode) {
        debugPrint('AppProvider: loadCalendarEvents - token available: ${token != null && token.isNotEmpty}');
      }
      if (token != null && token.isNotEmpty) {
        _calendarService.setAccessToken(token);
        _calendarEvents = await _calendarService.getEvents(
          timeMin: start,
          timeMax: end,
        );
        if (kDebugMode) {
          debugPrint('AppProvider: Loaded ${_calendarEvents.length} calendar events');
        }
        notifyListeners();
      } else {
        // No token available - clear events and continue silently
        if (kDebugMode) {
          debugPrint('AppProvider: No calendar token available');
        }
        _calendarEvents = [];
        notifyListeners();
      }
    } catch (e) {
      // Calendar is optional - don't propagate errors
      if (kDebugMode) {
        debugPrint('AppProvider: Calendar load error (ignored): $e');
      }
      _calendarEvents = [];
      notifyListeners();
    }
  }

  Future<bool> addTodoToCalendar({
    required TodoModel todo,
    required DateTime date,
    required int startHour,
    required int startMinute,
  }) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null || token.isEmpty) return false;
      
      _calendarService.setAccessToken(token);
      return await _calendarService.addTodoToCalendar(
        todo: todo,
        date: date,
        startHour: startHour,
        startMinute: startMinute,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AppProvider: Add to calendar error: $e');
      }
      return false;
    }
  }
  
  Future<bool> updateCalendarEvent({
    required String eventId,
    required String title,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null || token.isEmpty) return false;
      
      _calendarService.setAccessToken(token);
      return await _calendarService.updateEvent(
        eventId: eventId,
        title: title,
        start: start,
        end: end,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AppProvider: Update calendar event error: $e');
      }
      return false;
    }
  }
  
  Future<bool> deleteCalendarEvent(String eventId) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null || token.isEmpty) return false;
      
      _calendarService.setAccessToken(token);
      return await _calendarService.deleteEvent(eventId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AppProvider: Delete calendar event error: $e');
      }
      return false;
    }
  }

  // AI
  bool get hasGeminiApiKey => _geminiService.hasApiKey;
  
  Future<void> setGeminiApiKey(String key) async {
    await _geminiService.setApiKey(key);
    notifyListeners();
  }

  Future<List<FunctionCall>> parseAIRequest(String message) async {
    return _geminiService.parseUserRequest(message);
  }

  Future<String> executeAIFunctionCalls(List<FunctionCall> calls) async {
    final results = <String>[];
    
    for (final call in calls) {
      try {
        switch (call.name) {
          // === TODO FUNCTIONS ===
          case 'createTodo':
            final dateStr = call.arguments['date'] as String?;
            DateTime targetDate = _selectedDate;
            if (dateStr != null) {
              targetDate = DateTime.parse(dateStr);
            }
            final oldDate = _selectedDate;
            _selectedDate = targetDate;
            await createTodo(
              text: call.arguments['text'] ?? '',
              estimatedTime: call.arguments['estimatedTime'] as int?,
            );
            _selectedDate = oldDate;
            results.add('✅ 할 일 생성: "${call.arguments['text']}"');
            break;
            
          case 'updateTodo':
            final searchText = call.arguments['searchText'] as String?;
            if (searchText != null) {
              final todo = _findTodoByText(searchText);
              if (todo != null) {
                final updated = todo.copyWith(
                  text: call.arguments['newText'] as String? ?? todo.text,
                  estimatedTime: call.arguments['estimatedTime'] as int? ?? todo.estimatedTime,
                  completed: call.arguments['completed'] as bool? ?? todo.completed,
                );
                await updateTodo(updated);
                results.add('✅ 할 일 수정: "$searchText"');
              } else {
                results.add('❌ 할 일을 찾을 수 없음: "$searchText"');
              }
            }
            break;
            
          case 'deleteTodo':
            final searchText = call.arguments['searchText'] as String?;
            if (searchText != null) {
              final todo = _findTodoByText(searchText);
              if (todo != null) {
                await deleteTodo(todo.id);
                results.add('✅ 할 일 삭제: "$searchText"');
              } else {
                results.add('❌ 할 일을 찾을 수 없음: "$searchText"');
              }
            }
            break;
            
          case 'completeTodo':
            final searchText = call.arguments['searchText'] as String?;
            if (searchText != null) {
              final todo = _findTodoByText(searchText);
              if (todo != null) {
                await toggleTodoComplete(todo);
                results.add('✅ 할 일 완료: "$searchText"');
              } else {
                results.add('❌ 할 일을 찾을 수 없음: "$searchText"');
              }
            }
            break;
            
          // === ROUTINE FUNCTIONS ===
          case 'createRoutine':
            final typeStr = call.arguments['repetitionType'] as String? ?? 'daily';
            RepetitionType type = RepetitionType.daily;
            if (typeStr == 'weeklyOnce') type = RepetitionType.weeklyOnce;
            if (typeStr == 'weeklyN') type = RepetitionType.weeklyN;
            
            await createRoutine(
              text: call.arguments['text'] ?? '',
              estimatedTime: call.arguments['estimatedTime'] as int?,
              repetitionType: type,
              repetitionCount: call.arguments['repetitionCount'] as int? ?? 1,
              weekdays: (call.arguments['weekdays'] as List<dynamic>?)?.cast<int>() ?? [],
            );
            results.add('✅ 루틴 생성: "${call.arguments['text']}"');
            break;
            
          case 'updateRoutine':
            final searchText = call.arguments['searchText'] as String?;
            if (searchText != null) {
              final routine = _findRoutineByText(searchText);
              if (routine != null) {
                final typeStr = call.arguments['repetitionType'] as String?;
                RepetitionType? type;
                if (typeStr == 'daily') type = RepetitionType.daily;
                if (typeStr == 'weeklyOnce') type = RepetitionType.weeklyOnce;
                if (typeStr == 'weeklyN') type = RepetitionType.weeklyN;
                
                final updated = routine.copyWith(
                  text: call.arguments['newText'] as String? ?? routine.text,
                  estimatedTime: call.arguments['estimatedTime'] as int? ?? routine.estimatedTime,
                  repetitionType: type ?? routine.repetitionType,
                  weekdays: (call.arguments['weekdays'] as List<dynamic>?)?.cast<int>() ?? routine.weekdays,
                );
                await updateRoutine(updated);
                results.add('✅ 루틴 수정: "$searchText"');
              } else {
                results.add('❌ 루틴을 찾을 수 없음: "$searchText"');
              }
            }
            break;
            
          case 'deleteRoutine':
            final searchText = call.arguments['searchText'] as String?;
            if (searchText != null) {
              final routine = _findRoutineByText(searchText);
              if (routine != null) {
                await deleteRoutine(routine.id);
                results.add('✅ 루틴 삭제: "$searchText"');
              } else {
                results.add('❌ 루틴을 찾을 수 없음: "$searchText"');
              }
            }
            break;
            
          // === CALENDAR FUNCTIONS ===
          case 'createCalendarEvent':
            final title = call.arguments['title'] as String? ?? '';
            final dateStr = call.arguments['date'] as String?;
            final startTimeStr = call.arguments['startTime'] as String?;
            final endTimeStr = call.arguments['endTime'] as String?;
            
            if (dateStr != null && startTimeStr != null && endTimeStr != null) {
              final date = DateTime.parse(dateStr);
              final startParts = startTimeStr.split(':');
              final endParts = endTimeStr.split(':');
              
              final start = DateTime(date.year, date.month, date.day,
                int.parse(startParts[0]), int.parse(startParts[1]));
              final end = DateTime(date.year, date.month, date.day,
                int.parse(endParts[0]), int.parse(endParts[1]));
              
              final success = await createCalendarEvent(
                title: title,
                start: start,
                end: end,
                description: call.arguments['description'] as String?,
              );
              results.add(success ? '✅ 일정 생성: "$title"' : '❌ 일정 생성 실패');
            }
            break;
            
          case 'updateCalendarEvent':
            final searchText = call.arguments['searchText'] as String?;
            if (searchText != null) {
              final event = _findCalendarEventByText(searchText);
              if (event != null) {
                DateTime newStart = event.start;
                DateTime newEnd = event.end;
                String newTitle = call.arguments['newTitle'] as String? ?? event.summary;
                
                final dateStr = call.arguments['date'] as String?;
                final startTimeStr = call.arguments['startTime'] as String?;
                final endTimeStr = call.arguments['endTime'] as String?;
                
                if (dateStr != null) {
                  final date = DateTime.parse(dateStr);
                  newStart = DateTime(date.year, date.month, date.day, newStart.hour, newStart.minute);
                  newEnd = DateTime(date.year, date.month, date.day, newEnd.hour, newEnd.minute);
                }
                if (startTimeStr != null) {
                  final parts = startTimeStr.split(':');
                  newStart = DateTime(newStart.year, newStart.month, newStart.day,
                    int.parse(parts[0]), int.parse(parts[1]));
                }
                if (endTimeStr != null) {
                  final parts = endTimeStr.split(':');
                  newEnd = DateTime(newEnd.year, newEnd.month, newEnd.day,
                    int.parse(parts[0]), int.parse(parts[1]));
                }
                
                final success = await updateCalendarEvent(
                  eventId: event.id,
                  title: newTitle,
                  start: newStart,
                  end: newEnd,
                );
                results.add(success ? '✅ 일정 수정: "$searchText"' : '❌ 일정 수정 실패');
              } else {
                results.add('❌ 일정을 찾을 수 없음: "$searchText"');
              }
            }
            break;
            
          case 'deleteCalendarEvent':
            final searchText = call.arguments['searchText'] as String?;
            if (searchText != null) {
              final event = _findCalendarEventByText(searchText);
              if (event != null) {
                final success = await deleteCalendarEvent(event.id);
                results.add(success ? '✅ 일정 삭제: "$searchText"' : '❌ 일정 삭제 실패');
              } else {
                results.add('❌ 일정을 찾을 수 없음: "$searchText"');
              }
            }
            break;
            
          // === CONVERSION FUNCTIONS ===
          case 'todoToCalendar':
            final searchText = call.arguments['searchText'] as String?;
            final dateStr = call.arguments['date'] as String?;
            final startTimeStr = call.arguments['startTime'] as String?;
            
            if (searchText != null && dateStr != null && startTimeStr != null) {
              final todo = _findTodoByText(searchText);
              if (todo != null) {
                final date = DateTime.parse(dateStr);
                final parts = startTimeStr.split(':');
                final success = await addTodoToCalendar(
                  todo: todo,
                  date: date,
                  startHour: int.parse(parts[0]),
                  startMinute: int.parse(parts[1]),
                );
                results.add(success ? '✅ 할 일 → 캘린더: "$searchText"' : '❌ 캘린더 추가 실패');
              } else {
                results.add('❌ 할 일을 찾을 수 없음: "$searchText"');
              }
            }
            break;
            
          case 'todoToRoutine':
            final searchText = call.arguments['searchText'] as String?;
            if (searchText != null) {
              final todo = _findTodoByText(searchText);
              if (todo != null) {
                final typeStr = call.arguments['repetitionType'] as String? ?? 'daily';
                RepetitionType type = RepetitionType.daily;
                if (typeStr == 'weeklyOnce') type = RepetitionType.weeklyOnce;
                if (typeStr == 'weeklyN') type = RepetitionType.weeklyN;
                
                await convertTodoToRoutine(
                  todo,
                  repetitionType: type,
                  repetitionCount: call.arguments['repetitionCount'] as int? ?? 1,
                  weekdays: (call.arguments['weekdays'] as List<dynamic>?)?.cast<int>() ?? [],
                );
                results.add('✅ 할 일 → 루틴: "$searchText"');
              } else {
                results.add('❌ 할 일을 찾을 수 없음: "$searchText"');
              }
            }
            break;
            
          // === GREETING ===
          case 'greeting':
            results.add(call.arguments['message'] as String? ?? '안녕하세요!');
            break;
            
          case 'error':
            results.add('❌ ${call.description}');
            break;
        }
      } catch (e) {
        results.add('❌ 오류: ${call.name} - $e');
      }
    }
    
    return results.join('\n');
  }
  
  // Helper methods for finding items by text
  TodoModel? _findTodoByText(String searchText) {
    final lower = searchText.toLowerCase();
    return _todos.cast<TodoModel?>().firstWhere(
      (t) => t!.text.toLowerCase().contains(lower),
      orElse: () => null,
    );
  }
  
  RoutineModel? _findRoutineByText(String searchText) {
    final lower = searchText.toLowerCase();
    return _routines.cast<RoutineModel?>().firstWhere(
      (r) => r!.text.toLowerCase().contains(lower),
      orElse: () => null,
    );
  }
  
  CalendarEvent? _findCalendarEventByText(String searchText) {
    final lower = searchText.toLowerCase();
    return _calendarEvents.cast<CalendarEvent?>().firstWhere(
      (e) => e!.summary.toLowerCase().contains(lower),
      orElse: () => null,
    );
  }
  
  // Create calendar event directly
  Future<bool> createCalendarEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
  }) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null || token.isEmpty) return false;
      
      _calendarService.setAccessToken(token);
      return await _calendarService.createEvent(
        summary: title,
        startTime: start,
        endTime: end,
        description: description,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AppProvider: Create calendar event error: $e');
      }
      return false;
    }
  }

  @override
  void dispose() {
    _todosSubscription?.cancel();
    _routinesSubscription?.cancel();
    super.dispose();
  }
}

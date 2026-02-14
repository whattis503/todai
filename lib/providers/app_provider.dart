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
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AppProvider: Error loading Gemini API key: $e');
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
    final index = organizedTodos.indexOf(todo);
    if (index > 0) {
      final potentialParent = organizedTodos[index - 1];
      final updatedTodo = todo.copyWith(parentId: potentialParent.id);
      await _firestoreService.updateTodo(updatedTodo);
    }
  }

  Future<void> outdentTodo(TodoModel todo) async {
    if (todo.parentId != null) {
      final parent = _todos.firstWhere((t) => t.id == todo.parentId);
      final updatedTodo = todo.copyWith(parentId: parent.parentId);
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
  }) async {
    await _firestoreService.createRoutine(
      text: text,
      estimatedTime: estimatedTime,
      repetitionType: repetitionType,
      repetitionCount: repetitionCount,
      weekdays: weekdays,
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
      if (token != null && token.isNotEmpty) {
        _calendarService.setAccessToken(token);
        _calendarEvents = await _calendarService.getEvents(
          timeMin: start,
          timeMax: end,
        );
        notifyListeners();
      } else {
        // No token available - clear events and continue silently
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

  // AI
  bool get hasGeminiApiKey => _geminiService.hasApiKey;
  
  Future<void> setGeminiApiKey(String key) async {
    await _geminiService.setApiKey(key);
    notifyListeners();
  }

  Future<List<FunctionCall>> parseAIRequest(String message) async {
    return _geminiService.parseUserRequest(message);
  }

  Future<void> executeAIFunctionCalls(List<FunctionCall> calls) async {
    for (final call in calls) {
      switch (call.name) {
        case 'createTodo':
          await createTodo(
            text: call.arguments['text'] ?? '',
            estimatedTime: call.arguments['estimatedTime'],
          );
          break;
        case 'createRoutine':
          await createRoutine(
            text: call.arguments['text'] ?? '',
            estimatedTime: call.arguments['estimatedTime'],
            repetitionType: RepetitionType.values.firstWhere(
              (e) => e.name == (call.arguments['repetitionType'] ?? 'daily'),
              orElse: () => RepetitionType.daily,
            ),
            repetitionCount: call.arguments['repetitionCount'] ?? 1,
            weekdays: (call.arguments['weekdays'] as List<dynamic>?)?.cast<int>() ?? [],
          );
          break;
        case 'deleteTodo':
          if (call.arguments['todoId'] != null) {
            await deleteTodo(call.arguments['todoId']);
          }
          break;
        case 'updateTodo':
          final todoId = call.arguments['todoId'];
          if (todoId != null) {
            final todo = _todos.firstWhere((t) => t.id == todoId);
            final updated = todo.copyWith(
              text: call.arguments['text'],
              estimatedTime: call.arguments['estimatedTime'],
              completed: call.arguments['completed'],
            );
            await updateTodo(updated);
          }
          break;
      }
    }
  }

  @override
  void dispose() {
    _todosSubscription?.cancel();
    _routinesSubscription?.cancel();
    super.dispose();
  }
}

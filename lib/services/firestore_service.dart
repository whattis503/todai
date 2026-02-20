import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/todo_model.dart';
import '../models/routine_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  String? _userId;
  
  void setUserId(String userId) {
    _userId = userId;
    if (kDebugMode) {
      debugPrint('FirestoreService: User ID set to $userId');
    }
  }

  // ============ TODOS ============
  
  CollectionReference<Map<String, dynamic>>? get _todosCollection {
    if (_userId == null) {
      if (kDebugMode) {
        debugPrint('FirestoreService: _todosCollection accessed but userId is null');
      }
      return null;
    }
    return _db.collection('users').doc(_userId).collection('todos');
  }

  Stream<List<TodoModel>> getTodosForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    if (kDebugMode) {
      debugPrint('FirestoreService: Getting todos for date $startOfDay to $endOfDay');
      debugPrint('FirestoreService: User ID is $_userId');
    }
    
    // Check if user is logged in
    final collection = _todosCollection;
    if (collection == null) {
      if (kDebugMode) {
        debugPrint('FirestoreService: Returning empty stream - no user');
      }
      return Stream.value(<TodoModel>[]);
    }
    
    // Simplified query - just get all todos and filter in memory
    // This avoids complex index requirements
    return collection
        .snapshots()
        .map((snapshot) {
          if (kDebugMode) {
            debugPrint('FirestoreService: Received ${snapshot.docs.length} total documents');
          }
          
          final allTodos = snapshot.docs
              .map((doc) {
                try {
                  return TodoModel.fromFirestore(doc.data(), doc.id);
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('FirestoreService: Error parsing todo ${doc.id}: $e');
                  }
                  return null;
                }
              })
              .whereType<TodoModel>()
              .toList();
          
          // Filter by date in memory (exclude memos - items without date)
          final todosForDate = allTodos.where((todo) {
            if (todo.date == null) return false; // 메모는 제외
            final todoDate = DateTime(todo.date!.year, todo.date!.month, todo.date!.day);
            return todoDate.isAtSameMomentAs(startOfDay);
          }).toList();
          
          if (kDebugMode) {
            debugPrint('FirestoreService: Filtered to ${todosForDate.length} todos for date');
          }
          
          todosForDate.sort((a, b) => a.order.compareTo(b.order));
          return todosForDate;
        })
        .handleError((error) {
          if (kDebugMode) {
            debugPrint('FirestoreService: Stream error: $error');
          }
          return <TodoModel>[];
        });
  }

  // 메모 가져오기 (날짜가 없는 할일들)
  Stream<List<TodoModel>> getMemos() {
    if (kDebugMode) {
      debugPrint('FirestoreService: Getting memos (todos without date)');
    }
    
    final collection = _todosCollection;
    if (collection == null) {
      return Stream.value(<TodoModel>[]);
    }
    
    return collection
        .snapshots()
        .map((snapshot) {
          final memos = snapshot.docs
              .map((doc) {
                try {
                  return TodoModel.fromFirestore(doc.data(), doc.id);
                } catch (e) {
                  return null;
                }
              })
              .whereType<TodoModel>()
              .where((todo) => todo.date == null) // 날짜가 없는 것만 (메모)
              .toList();
          
          if (kDebugMode) {
            debugPrint('FirestoreService: Found ${memos.length} memos');
          }
          
          memos.sort((a, b) => a.order.compareTo(b.order));
          return memos;
        })
        .handleError((error) {
          if (kDebugMode) {
            debugPrint('FirestoreService: Memos stream error: $error');
          }
          return <TodoModel>[];
        });
  }
  
  // 메모 생성 (날짜 없는 할일)
  Future<TodoModel> createMemo({
    required String text,
    int? estimatedTime,
    int order = 0,
  }) async {
    final collection = _todosCollection;
    if (collection == null) {
      throw Exception('User not logged in');
    }
    final docRef = collection.doc();
    final now = DateTime.now();
    
    if (kDebugMode) {
      debugPrint('FirestoreService: Creating memo "$text"');
    }
    
    final memo = TodoModel(
      id: docRef.id,
      text: text,
      createdAt: now,
      date: null, // 메모는 날짜가 없음
      estimatedTime: estimatedTime,
      order: order,
    );
    
    await docRef.set(memo.toFirestore());
    
    if (kDebugMode) {
      debugPrint('FirestoreService: Memo created with ID ${docRef.id}');
    }
    
    return memo;
  }

  Future<TodoModel> createTodo({
    required String text,
    DateTime? date, // nullable로 변경
    int? estimatedTime,
    String? parentId,
    int order = 0,
  }) async {
    final collection = _todosCollection;
    if (collection == null) {
      throw Exception('User not logged in');
    }
    final docRef = collection.doc();
    final now = DateTime.now();
    final todoDate = date != null ? DateTime(date.year, date.month, date.day) : null;
    
    if (kDebugMode) {
      debugPrint('FirestoreService: Creating todo "$text" for date $todoDate');
    }
    
    final todo = TodoModel(
      id: docRef.id,
      text: text,
      createdAt: now,
      date: todoDate, // nullable
      estimatedTime: estimatedTime,
      parentId: parentId,
      order: order,
    );
    
    await docRef.set(todo.toFirestore());
    
    if (kDebugMode) {
      debugPrint('FirestoreService: Todo created with ID ${docRef.id}');
    }
    
    return todo;
  }

  Future<void> updateTodo(TodoModel todo) async {
    final collection = _todosCollection;
    if (collection == null) return;
    await collection.doc(todo.id).update(todo.toFirestore());
  }

  Future<void> deleteTodo(String todoId) async {
    final collection = _todosCollection;
    if (collection == null) return;
    await collection.doc(todoId).delete();
  }

  Future<void> updateTodoOrder(List<TodoModel> todos) async {
    final collection = _todosCollection;
    if (collection == null) return;
    final batch = _db.batch();
    for (int i = 0; i < todos.length; i++) {
      batch.update(collection.doc(todos[i].id), {'order': i});
    }
    await batch.commit();
  }

  // Roll over incomplete todos to next day
  Future<void> rollOverIncompleteTodos() async {
    final collection = _todosCollection;
    if (collection == null) return;
    
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final startOfYesterday = DateTime(yesterday.year, yesterday.month, yesterday.day);
    final endOfYesterday = startOfYesterday.add(const Duration(days: 1));
    
    final snapshot = await collection
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYesterday))
        .where('date', isLessThan: Timestamp.fromDate(endOfYesterday))
        .where('completed', isEqualTo: false)
        .get();

    final today = DateTime.now();
    final batch = _db.batch();

    for (final doc in snapshot.docs) {
      final todo = TodoModel.fromFirestore(doc.data(), doc.id);
      final newDocRef = collection.doc();
      
      final newTodo = todo.copyWith(
        id: newDocRef.id,
        date: DateTime(today.year, today.month, today.day),
        isRolledOver: true,
        clearTimerStartedAt: true,
        timerPausedDuration: 0,
      );
      
      batch.set(newDocRef, newTodo.toFirestore());
    }

    await batch.commit();
  }

  // ============ ROUTINES ============
  
  CollectionReference<Map<String, dynamic>>? get _routinesCollection {
    if (_userId == null) {
      if (kDebugMode) {
        debugPrint('FirestoreService: _routinesCollection accessed but userId is null');
      }
      return null;
    }
    return _db.collection('users').doc(_userId).collection('routines');
  }

  Stream<List<RoutineModel>> getRoutines() {
    if (kDebugMode) {
      debugPrint('FirestoreService: Getting routines for user $_userId');
    }
    
    final collection = _routinesCollection;
    if (collection == null) {
      if (kDebugMode) {
        debugPrint('FirestoreService: Returning empty routines stream - no user');
      }
      return Stream.value(<RoutineModel>[]);
    }
    
    return collection
        .snapshots()
        .map((snapshot) {
          if (kDebugMode) {
            debugPrint('FirestoreService: Received ${snapshot.docs.length} routines');
          }
          
          final routines = snapshot.docs
              .map((doc) {
                try {
                  return RoutineModel.fromFirestore(doc.data(), doc.id);
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('FirestoreService: Error parsing routine ${doc.id}: $e');
                  }
                  return null;
                }
              })
              .whereType<RoutineModel>()
              .toList();
          
          // Sort by createdAt in memory
          routines.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return routines;
        })
        .handleError((error) {
          if (kDebugMode) {
            debugPrint('FirestoreService: Routines stream error: $error');
          }
          return <RoutineModel>[];
        });
  }

  Future<RoutineModel> createRoutine({
    required String text,
    int? estimatedTime,
    RepetitionType repetitionType = RepetitionType.daily,
    int repetitionCount = 1,
    List<int> weekdays = const [],
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final collection = _routinesCollection;
    if (collection == null) {
      throw Exception('User not logged in');
    }
    final docRef = collection.doc();
    
    final routine = RoutineModel(
      id: docRef.id,
      text: text,
      estimatedTime: estimatedTime,
      repetitionType: repetitionType,
      repetitionCount: repetitionCount,
      weekdays: weekdays,
      createdAt: DateTime.now(),
      startDate: startDate,
      endDate: endDate,
    );
    
    await docRef.set(routine.toFirestore());
    return routine;
  }

  Future<void> updateRoutine(RoutineModel routine) async {
    final collection = _routinesCollection;
    if (collection == null) return;
    await collection.doc(routine.id).update(routine.toFirestore());
  }

  Future<void> deleteRoutine(String routineId) async {
    final collection = _routinesCollection;
    if (collection == null) return;
    await collection.doc(routineId).delete();
  }

  // Generate todos from routines for a specific date
  Future<void> generateTodosFromRoutines(DateTime date) async {
    try {
      final routinesCol = _routinesCollection;
      final todosCol = _todosCollection;
      if (routinesCol == null || todosCol == null) return;
      
      final routinesSnapshot = await routinesCol.get();
      final routines = routinesSnapshot.docs
          .map((doc) => RoutineModel.fromFirestore(doc.data(), doc.id))
          .where((r) => r.shouldGenerateTodoForDate(date))
          .toList();

      // Check which routines already have todos for this date
      final startOfDay = DateTime(date.year, date.month, date.day);
      
      // Get all todos and filter in memory
      final existingTodosSnapshot = await todosCol.get();
      final existingTexts = existingTodosSnapshot.docs
          .map((doc) => TodoModel.fromFirestore(doc.data(), doc.id))
          .where((todo) {
            if (todo.date == null) return false; // 메모 제외
            final todoDate = DateTime(todo.date!.year, todo.date!.month, todo.date!.day);
            return todoDate.isAtSameMomentAs(startOfDay);
          })
          .map((todo) => todo.text)
          .toSet();

      final batch = _db.batch();
      int order = existingTexts.length;

      for (final routine in routines) {
        if (!existingTexts.contains(routine.text)) {
          final docRef = todosCol.doc();
          final todo = TodoModel(
            id: docRef.id,
            text: routine.text,
            createdAt: DateTime.now(),
            date: startOfDay,
            estimatedTime: routine.estimatedTime,
            order: order++,
          );
          batch.set(docRef, todo.toFirestore());
        }
      }

      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error generating todos from routines: $e');
      }
    }
  }
}

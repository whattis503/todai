import 'package:cloud_firestore/cloud_firestore.dart';

class TodoModel {
  final String id;
  final String text;
  final bool completed;
  final DateTime createdAt;
  final DateTime date;
  final int? estimatedTime; // minutes
  final int? actualTime; // minutes
  final String? parentId;
  final int order;
  final bool isRolledOver;
  final DateTime? timerStartedAt;
  final int timerPausedDuration; // seconds

  TodoModel({
    required this.id,
    required this.text,
    this.completed = false,
    required this.createdAt,
    required this.date,
    this.estimatedTime,
    this.actualTime,
    this.parentId,
    this.order = 0,
    this.isRolledOver = false,
    this.timerStartedAt,
    this.timerPausedDuration = 0,
  });

  factory TodoModel.fromFirestore(Map<String, dynamic> data, String id) {
    return TodoModel(
      id: id,
      text: data['text'] as String? ?? '',
      completed: data['completed'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      estimatedTime: data['estimatedTime'] as int?,
      actualTime: data['actualTime'] as int?,
      parentId: data['parentId'] as String?,
      order: data['order'] as int? ?? 0,
      isRolledOver: data['isRolledOver'] as bool? ?? false,
      timerStartedAt: (data['timerStartedAt'] as Timestamp?)?.toDate(),
      timerPausedDuration: data['timerPausedDuration'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'completed': completed,
      'createdAt': Timestamp.fromDate(createdAt),
      'date': Timestamp.fromDate(date),
      'estimatedTime': estimatedTime,
      'actualTime': actualTime,
      'parentId': parentId,
      'order': order,
      'isRolledOver': isRolledOver,
      'timerStartedAt': timerStartedAt != null ? Timestamp.fromDate(timerStartedAt!) : null,
      'timerPausedDuration': timerPausedDuration,
    };
  }

  TodoModel copyWith({
    String? id,
    String? text,
    bool? completed,
    DateTime? createdAt,
    DateTime? date,
    Object? estimatedTime = _sentinel,
    Object? actualTime = _sentinel,
    Object? parentId = _sentinel,
    int? order,
    bool? isRolledOver,
    DateTime? timerStartedAt,
    int? timerPausedDuration,
    bool clearTimerStartedAt = false,
  }) {
    return TodoModel(
      id: id ?? this.id,
      text: text ?? this.text,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      date: date ?? this.date,
      estimatedTime: estimatedTime == _sentinel 
          ? this.estimatedTime 
          : estimatedTime as int?,
      actualTime: actualTime == _sentinel 
          ? this.actualTime 
          : actualTime as int?,
      parentId: parentId == _sentinel 
          ? this.parentId 
          : parentId as String?,
      order: order ?? this.order,
      isRolledOver: isRolledOver ?? this.isRolledOver,
      timerStartedAt: clearTimerStartedAt ? null : (timerStartedAt ?? this.timerStartedAt),
      timerPausedDuration: timerPausedDuration ?? this.timerPausedDuration,
    );
  }
}

// Sentinel value to distinguish between "not provided" and "explicitly null"
const _sentinel = Object();

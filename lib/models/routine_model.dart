import 'package:cloud_firestore/cloud_firestore.dart';

enum RepetitionType {
  daily,
  weeklyOnce,
  weeklyN,
}

class RoutineModel {
  final String id;
  final String text;
  final int? estimatedTime;
  final RepetitionType repetitionType;
  final int repetitionCount; // for weeklyN
  final List<int> weekdays; // 1=Monday, 7=Sunday
  final bool isActive;
  final DateTime createdAt;

  RoutineModel({
    required this.id,
    required this.text,
    this.estimatedTime,
    this.repetitionType = RepetitionType.daily,
    this.repetitionCount = 1,
    this.weekdays = const [],
    this.isActive = true,
    required this.createdAt,
  });

  factory RoutineModel.fromFirestore(Map<String, dynamic> data, String id) {
    return RoutineModel(
      id: id,
      text: data['text'] as String? ?? '',
      estimatedTime: data['estimatedTime'] as int?,
      repetitionType: RepetitionType.values.firstWhere(
        (e) => e.name == (data['repetitionType'] as String? ?? 'daily'),
        orElse: () => RepetitionType.daily,
      ),
      repetitionCount: data['repetitionCount'] as int? ?? 1,
      weekdays: (data['weekdays'] as List<dynamic>?)?.cast<int>() ?? [],
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'estimatedTime': estimatedTime,
      'repetitionType': repetitionType.name,
      'repetitionCount': repetitionCount,
      'weekdays': weekdays,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  RoutineModel copyWith({
    String? id,
    String? text,
    int? estimatedTime,
    RepetitionType? repetitionType,
    int? repetitionCount,
    List<int>? weekdays,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return RoutineModel(
      id: id ?? this.id,
      text: text ?? this.text,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      repetitionType: repetitionType ?? this.repetitionType,
      repetitionCount: repetitionCount ?? this.repetitionCount,
      weekdays: weekdays ?? this.weekdays,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool shouldGenerateTodoForDate(DateTime date) {
    if (!isActive) return false;

    switch (repetitionType) {
      case RepetitionType.daily:
        return true;
      case RepetitionType.weeklyOnce:
        return weekdays.contains(date.weekday);
      case RepetitionType.weeklyN:
        return weekdays.contains(date.weekday);
    }
  }

  String get repetitionDescription {
    switch (repetitionType) {
      case RepetitionType.daily:
        return 'Every day';
      case RepetitionType.weeklyOnce:
        return 'Once a week (${_weekdayNames()})';
      case RepetitionType.weeklyN:
        return '$repetitionCount times a week (${_weekdayNames()})';
    }
  }

  String _weekdayNames() {
    const names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays.map((d) => names[d]).join(', ');
  }
}

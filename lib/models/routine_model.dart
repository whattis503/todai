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
  final DateTime? startDate; // 시작일 (null이면 createdAt)
  final DateTime? endDate; // 종료일 (null이면 무한히)

  RoutineModel({
    required this.id,
    required this.text,
    this.estimatedTime,
    this.repetitionType = RepetitionType.daily,
    this.repetitionCount = 1,
    this.weekdays = const [],
    this.isActive = true,
    required this.createdAt,
    this.startDate,
    this.endDate,
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
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
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
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
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
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
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
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }

  bool shouldGenerateTodoForDate(DateTime date) {
    if (!isActive) return false;
    
    // 시작일 체크
    final effectiveStartDate = startDate ?? createdAt;
    final dateOnly = DateTime(date.year, date.month, date.day);
    final startOnly = DateTime(effectiveStartDate.year, effectiveStartDate.month, effectiveStartDate.day);
    
    if (dateOnly.isBefore(startOnly)) return false;
    
    // 종료일 체크 (종료일도 포함)
    if (endDate != null) {
      final endOnly = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (dateOnly.isAfter(endOnly)) return false;
    }

    switch (repetitionType) {
      case RepetitionType.daily:
        return weekdays.isEmpty || weekdays.contains(date.weekday);
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

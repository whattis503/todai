import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'web_storage_stub.dart' if (dart.library.html) 'web_storage_web.dart' as web_storage;

class FunctionCall {
  final String name;
  final Map<String, dynamic> arguments;
  final String description;

  FunctionCall({
    required this.name,
    required this.arguments,
    required this.description,
  });
}

class GeminiService {
  static const String _apiKeyKey = 'gemini_api_key';
  static const String _webStorageKey = 'todai_gemini_api_key';
  String? _apiKey;
  
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;
  
  // Load API key from storage on initialization
  Future<void> loadApiKey() async {
    try {
      if (kIsWeb) {
        final webKey = web_storage.getItem(_webStorageKey);
        if (webKey != null && webKey.isNotEmpty) {
          _apiKey = webKey;
          return;
        }
      }
      
      final prefs = await SharedPreferences.getInstance();
      _apiKey = prefs.getString(_apiKeyKey);
      
      if (_apiKey != null && kIsWeb) {
        web_storage.setItem(_webStorageKey, _apiKey!);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GeminiService: Error loading API key: $e');
      }
    }
  }
  
  Future<void> setApiKey(String key) async {
    _apiKey = key;
    try {
      if (kIsWeb) {
        web_storage.setItem(_webStorageKey, key);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_apiKeyKey, key);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GeminiService: Error saving API key: $e');
      }
    }
  }
  
  Future<void> clearApiKey() async {
    _apiKey = null;
    try {
      if (kIsWeb) {
        web_storage.removeItem(_webStorageKey);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_apiKeyKey);
    } catch (_) {}
  }

  String _getTodayDate() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  String _getTomorrowDate() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)));
  }

  String _getNextMondayDate() {
    final now = DateTime.now();
    final daysUntilMonday = (8 - now.weekday) % 7;
    final nextMonday = now.add(Duration(days: daysUntilMonday == 0 ? 7 : daysUntilMonday));
    return DateFormat('yyyy-MM-dd').format(nextMonday);
  }

  Future<List<FunctionCall>> parseUserRequest(String userMessage) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return [
        FunctionCall(
          name: 'error',
          arguments: {},
          description: 'API 키가 설정되지 않았습니다. 설정에서 Gemini API 키를 입력해주세요.',
        ),
      ];
    }

    try {
      final today = _getTodayDate();
      final tomorrow = _getTomorrowDate();
      final nextMonday = _getNextMondayDate();
      final now = DateTime.now();
      final weekdayNames = ['', '월', '화', '수', '목', '금', '토', '일'];
      final currentWeekday = weekdayNames[now.weekday];
      
      final prompt = '''You are a smart assistant for "Todai", a todo and calendar management app.
Today's date is: $today ($currentWeekday요일, Korea Standard Time, GMT+9)
Tomorrow's date is: $tomorrow
Next Monday: $nextMonday

Based on the user's request, determine which function calls are needed.
You can call multiple functions if needed.

=== AVAILABLE FUNCTIONS ===

## TODO FUNCTIONS
1. createTodo: Create a new todo
   - text (required): Todo title
   - estimatedTime (optional): Estimated minutes
   - date (optional): YYYY-MM-DD format. Default is today ($today)

2. updateTodo: Update existing todo (requires knowing the todo)
   - searchText (required): Text to find the todo
   - newText (optional): New title
   - estimatedTime (optional): New estimated time
   - completed (optional): true/false

3. deleteTodo: Delete a todo
   - searchText (required): Text to find and delete

4. completeTodo: Mark todo as complete
   - searchText (required): Text to find the todo

## ROUTINE FUNCTIONS
5. createRoutine: Create a recurring routine
   - text (required): Routine title
   - estimatedTime (optional): Estimated minutes
   - repetitionType (required): "daily", "weeklyOnce", or "weeklyN"
   - repetitionCount (optional): Times per week (for weeklyN)
   - weekdays (optional): Array of 1-7 (Mon=1, Sun=7)

6. updateRoutine: Update existing routine
   - searchText (required): Text to find the routine
   - newText (optional): New title
   - estimatedTime (optional): New estimated time
   - repetitionType (optional): New type
   - weekdays (optional): New weekdays

7. deleteRoutine: Delete a routine
   - searchText (required): Text to find and delete

## CALENDAR FUNCTIONS (Google Calendar)
8. createCalendarEvent: Create calendar event
   - title (required): Event title
   - date (required): YYYY-MM-DD format
   - startTime (required): HH:MM format (24h)
   - endTime (required): HH:MM format (24h)
   - description (optional): Event description

9. updateCalendarEvent: Update calendar event
   - searchText (required): Title to find the event
   - newTitle (optional): New title
   - date (optional): New date
   - startTime (optional): New start time
   - endTime (optional): New end time

10. deleteCalendarEvent: Delete calendar event
    - searchText (required): Title to find and delete

## CONVERSION FUNCTIONS
11. todoToCalendar: Add a todo to calendar
    - searchText (required): Todo text to find
    - date (required): YYYY-MM-DD
    - startTime (required): HH:MM

12. todoToRoutine: Convert todo to routine
    - searchText (required): Todo text to find
    - repetitionType (required): "daily", "weeklyOnce", or "weeklyN"
    - weekdays (optional): For weekly types

=== EXAMPLES ===
User: "내일 2시에 회의 일정 추가해줘"
Response: [{"name": "createCalendarEvent", "arguments": {"title": "회의", "date": "$tomorrow", "startTime": "14:00", "endTime": "15:00"}}]

User: "운동하기 30분 할일 추가"
Response: [{"name": "createTodo", "arguments": {"text": "운동하기", "estimatedTime": 30}}]

User: "다음주 월요일에 보고서 작성 할일"
Response: [{"name": "createTodo", "arguments": {"text": "보고서 작성", "date": "$nextMonday"}}]

User: "매일 아침 운동 루틴 만들어줘"
Response: [{"name": "createRoutine", "arguments": {"text": "아침 운동", "repetitionType": "daily"}}]

User: "주 3회 운동 루틴"
Response: [{"name": "createRoutine", "arguments": {"text": "운동", "repetitionType": "weeklyN", "repetitionCount": 3}}]

User: "월수금 영어 공부 루틴"
Response: [{"name": "createRoutine", "arguments": {"text": "영어 공부", "repetitionType": "weeklyOnce", "weekdays": [1, 3, 5]}}]

User: "회의 일정 3시로 변경해줘"
Response: [{"name": "updateCalendarEvent", "arguments": {"searchText": "회의", "startTime": "15:00", "endTime": "16:00"}}]

User: "운동하기 완료"
Response: [{"name": "completeTodo", "arguments": {"searchText": "운동하기"}}]

User: "운동하기 할일 삭제"
Response: [{"name": "deleteTodo", "arguments": {"searchText": "운동하기"}}]

User: "운동하기를 캘린더에 오후 2시에 추가"
Response: [{"name": "todoToCalendar", "arguments": {"searchText": "운동하기", "date": "$today", "startTime": "14:00"}}]

User: "안녕" or "반가워" or just greeting
Response: [{"name": "greeting", "arguments": {"message": "안녕하세요! 무엇을 도와드릴까요? 할 일 추가, 일정 관리, 루틴 설정 등을 할 수 있어요."}}]

=== USER REQUEST ===
$userMessage

=== RESPONSE FORMAT ===
Respond ONLY with a JSON array. No other text.
[{"name": "functionName", "arguments": {...}}]
''';

      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$_apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {
            'temperature': 0.1,
            'maxOutputTokens': 2048,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '[]';
        
        if (kDebugMode) {
          debugPrint('GeminiService: Response: $text');
        }
        
        final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(text);
        if (jsonMatch == null) {
          return [
            FunctionCall(
              name: 'greeting',
              arguments: {'message': '죄송합니다. 요청을 이해하지 못했어요. 다시 말씀해 주시겠어요?'},
              description: '응답 파싱 실패',
            ),
          ];
        }
        
        final List<dynamic> calls = json.decode(jsonMatch.group(0)!);
        
        return calls.map((call) {
          final name = call['name'] as String;
          final args = call['arguments'] as Map<String, dynamic>? ?? {};
          
          return FunctionCall(
            name: name,
            arguments: args,
            description: _generateDescription(name, args),
          );
        }).toList();
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
        return [
          FunctionCall(
            name: 'error',
            arguments: {},
            description: 'API 오류: $errorMessage',
          ),
        ];
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GeminiService: Error: $e');
      }
      return [
        FunctionCall(
          name: 'error',
          arguments: {},
          description: '요청 처리 중 오류: $e',
        ),
      ];
    }
  }

  String _generateDescription(String name, Map<String, dynamic> args) {
    switch (name) {
      // Todo functions
      case 'createTodo':
        final text = args['text'] ?? '';
        final time = args['estimatedTime'];
        final date = args['date'];
        String desc = '할 일 생성: "$text"';
        if (time != null) desc += ' ($time분)';
        if (date != null) desc += ' [$date]';
        return desc;
      case 'updateTodo':
        return '할 일 수정: "${args['searchText']}"';
      case 'deleteTodo':
        return '할 일 삭제: "${args['searchText']}"';
      case 'completeTodo':
        return '할 일 완료: "${args['searchText']}"';
        
      // Routine functions
      case 'createRoutine':
        final text = args['text'] ?? '';
        final type = args['repetitionType'] ?? 'daily';
        String typeKr = '매일';
        if (type == 'weeklyOnce') typeKr = '주간';
        if (type == 'weeklyN') typeKr = '주 ${args['repetitionCount'] ?? 1}회';
        return '루틴 생성: "$text" ($typeKr)';
      case 'updateRoutine':
        return '루틴 수정: "${args['searchText']}"';
      case 'deleteRoutine':
        return '루틴 삭제: "${args['searchText']}"';
        
      // Calendar functions
      case 'createCalendarEvent':
        final title = args['title'] ?? '';
        final date = args['date'] ?? '';
        final start = args['startTime'] ?? '';
        return '일정 생성: "$title" ($date $start)';
      case 'updateCalendarEvent':
        return '일정 수정: "${args['searchText']}"';
      case 'deleteCalendarEvent':
        return '일정 삭제: "${args['searchText']}"';
        
      // Conversion functions
      case 'todoToCalendar':
        return '할 일 → 캘린더: "${args['searchText']}" (${args['date']} ${args['startTime']})';
      case 'todoToRoutine':
        return '할 일 → 루틴: "${args['searchText']}"';
        
      // Greeting
      case 'greeting':
        return args['message'] ?? '안녕하세요!';
        
      case 'error':
        return args['message'] ?? '오류가 발생했습니다.';
        
      default:
        return '작업: $name';
    }
  }
}

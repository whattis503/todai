import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String? _apiKey;
  
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;
  
  // Load API key from storage on initialization
  Future<void> loadApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _apiKey = prefs.getString(_apiKeyKey);
      if (kDebugMode) {
        debugPrint('GeminiService: API key loaded: ${_apiKey != null}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GeminiService: Error loading API key: $e');
      }
    }
  }
  
  // Save API key to storage
  Future<void> setApiKey(String key) async {
    _apiKey = key;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_apiKeyKey, key);
      if (kDebugMode) {
        debugPrint('GeminiService: API key saved');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GeminiService: Error saving API key: $e');
      }
    }
  }
  
  // Clear API key
  Future<void> clearApiKey() async {
    _apiKey = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_apiKeyKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GeminiService: Error clearing API key: $e');
      }
    }
  }

  Future<List<FunctionCall>> parseUserRequest(String userMessage) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return [
        FunctionCall(
          name: 'error',
          arguments: {},
          description: 'API 키가 설정되지 않았습니다. 설정 버튼을 눌러 Gemini API 키를 입력해주세요.',
        ),
      ];
    }

    try {
      if (kDebugMode) {
        debugPrint('GeminiService: Sending request to Gemini API');
      }
      
      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [
            {
              'parts': [
                {
                  'text': '''You are a helpful assistant for a todo app. 
Based on the user's request, determine which function calls are needed.
Parse the request and extract relevant information.

User request: $userMessage

Respond with a JSON array of function calls in this format:
[{"name": "functionName", "arguments": {...}}]

Available functions:
- createTodo: Create a todo with text (required), estimatedTime (minutes, optional), date (YYYY-MM-DD, optional)
- createRoutine: Create a routine with text, estimatedTime, repetitionType (daily/weeklyOnce/weeklyN), repetitionCount, weekdays (array of 1-7)
- deleteTodo: Delete a todo by todoId
- updateTodo: Update a todo by todoId with text, estimatedTime, completed

Examples:
- "아침 운동 30분" -> [{"name": "createTodo", "arguments": {"text": "아침 운동", "estimatedTime": 30}}]
- "매일 운동하기 루틴" -> [{"name": "createRoutine", "arguments": {"text": "운동하기", "repetitionType": "daily"}}]

Only respond with the JSON array, no other text.'''
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'maxOutputTokens': 1024,
          },
        }),
      );

      if (kDebugMode) {
        debugPrint('GeminiService: Response status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '[]';
        
        if (kDebugMode) {
          debugPrint('GeminiService: Response text: $text');
        }
        
        // Extract JSON from response
        final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(text);
        if (jsonMatch == null) {
          if (kDebugMode) {
            debugPrint('GeminiService: No JSON found in response');
          }
          return [];
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
        if (kDebugMode) {
          debugPrint('GeminiService: API error: ${response.statusCode}');
          debugPrint('GeminiService: Response body: ${response.body}');
        }
        
        // Check for specific error messages
        try {
          final errorData = json.decode(response.body);
          final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
          return [
            FunctionCall(
              name: 'error',
              arguments: {},
              description: 'API 오류: $errorMessage',
            ),
          ];
        } catch (_) {
          return [
            FunctionCall(
              name: 'error',
              arguments: {},
              description: 'API 오류가 발생했습니다. (${response.statusCode})',
            ),
          ];
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GeminiService: Error parsing user request: $e');
      }
      return [
        FunctionCall(
          name: 'error',
          arguments: {},
          description: '요청 처리 중 오류가 발생했습니다: $e',
        ),
      ];
    }
  }

  String _generateDescription(String name, Map<String, dynamic> args) {
    switch (name) {
      case 'createTodo':
        final text = args['text'] ?? '이름 없음';
        final time = args['estimatedTime'];
        return '할 일 생성: "$text"${time != null ? ' ($time분)' : ''}';
      case 'createRoutine':
        final text = args['text'] ?? '이름 없음';
        final type = args['repetitionType'] ?? 'daily';
        final typeKr = type == 'daily' ? '매일' : type == 'weeklyOnce' ? '주간' : '주 N회';
        return '루틴 생성: "$text" ($typeKr)';
      case 'deleteTodo':
        return '할 일 삭제: ${args['todoId']}';
      case 'updateTodo':
        return '할 일 수정: ${args['todoId']}';
      default:
        return '알 수 없는 작업: $name';
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/todo_model.dart';

class CalendarEvent {
  final String id;
  final String summary;
  final DateTime start;
  final DateTime end;
  final String? description;

  CalendarEvent({
    required this.id,
    required this.summary,
    required this.start,
    required this.end,
    this.description,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    DateTime parseDateTime(Map<String, dynamic>? dateTime) {
      if (dateTime == null) return DateTime.now();
      if (dateTime['dateTime'] != null) {
        return DateTime.parse(dateTime['dateTime']);
      }
      if (dateTime['date'] != null) {
        return DateTime.parse(dateTime['date']);
      }
      return DateTime.now();
    }

    return CalendarEvent(
      id: json['id'] ?? '',
      summary: json['summary'] ?? 'No title',
      start: parseDateTime(json['start']),
      end: parseDateTime(json['end']),
      description: json['description'],
    );
  }
}

class CalendarService {
  final String _baseUrl = 'https://www.googleapis.com/calendar/v3';
  String? _accessToken;
  String? _lastError;
  
  String? get lastError => _lastError;

  void setAccessToken(String token) {
    _accessToken = token;
    if (kDebugMode) {
      debugPrint('CalendarService: Access token set (length: ${token.length})');
    }
  }

  Future<List<CalendarEvent>> getEvents({
    required DateTime timeMin,
    required DateTime timeMax,
  }) async {
    _lastError = null;
    
    if (_accessToken == null || _accessToken!.isEmpty) {
      _lastError = 'No access token available';
      if (kDebugMode) {
        debugPrint('CalendarService: No access token available for calendar');
      }
      return [];
    }

    try {
      final uri = Uri.parse(
        '$_baseUrl/calendars/primary/events'
        '?timeMin=${timeMin.toUtc().toIso8601String()}'
        '&timeMax=${timeMax.toUtc().toIso8601String()}'
        '&singleEvents=true'
        '&orderBy=startTime'
        '&maxResults=100',
      );
      
      if (kDebugMode) {
        debugPrint('CalendarService: Fetching events from ${timeMin.toIso8601String()} to ${timeMax.toIso8601String()}');
      }
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];
        
        if (kDebugMode) {
          debugPrint('CalendarService: Successfully fetched ${items.length} events');
        }
        
        return items.map((item) => CalendarEvent.fromJson(item)).toList();
      } else if (response.statusCode == 401) {
        _lastError = 'Authentication expired. Please sign out and sign in again.';
        if (kDebugMode) {
          debugPrint('CalendarService: 401 Unauthorized - token may be invalid');
          debugPrint('Response: ${response.body}');
        }
        return [];
      } else if (response.statusCode == 403) {
        _lastError = 'Calendar access denied. Please grant calendar permissions.';
        if (kDebugMode) {
          debugPrint('CalendarService: 403 Forbidden - missing calendar permission');
          debugPrint('Response: ${response.body}');
        }
        return [];
      } else {
        _lastError = 'Calendar API error: ${response.statusCode}';
        if (kDebugMode) {
          debugPrint('CalendarService: API error ${response.statusCode}');
          debugPrint('Response: ${response.body}');
        }
        return [];
      }
    } catch (e) {
      _lastError = 'Network error: $e';
      if (kDebugMode) {
        debugPrint('CalendarService: Error fetching calendar events: $e');
      }
      return [];
    }
  }

  Future<bool> createEvent({
    required String summary,
    required DateTime startTime,
    required DateTime endTime,
    String? description,
  }) async {
    _lastError = null;
    
    if (_accessToken == null || _accessToken!.isEmpty) {
      _lastError = 'No access token available';
      if (kDebugMode) {
        debugPrint('CalendarService: No access token available');
      }
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/calendars/primary/events'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'summary': summary,
          'description': description,
          'start': {
            'dateTime': startTime.toIso8601String(),
            'timeZone': 'Asia/Seoul',
          },
          'end': {
            'dateTime': endTime.toIso8601String(),
            'timeZone': 'Asia/Seoul',
          },
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (kDebugMode) {
          debugPrint('CalendarService: Event created successfully');
        }
        return true;
      } else {
        _lastError = 'Failed to create event: ${response.statusCode}';
        if (kDebugMode) {
          debugPrint('CalendarService: Error creating event: ${response.statusCode}');
          debugPrint('Response: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      _lastError = 'Network error: $e';
      if (kDebugMode) {
        debugPrint('CalendarService: Error creating calendar event: $e');
      }
      return false;
    }
  }

  Future<bool> addTodoToCalendar({
    required TodoModel todo,
    required DateTime date,
    required int startHour,
    required int startMinute,
  }) async {
    final startTime = DateTime(
      date.year,
      date.month,
      date.day,
      startHour,
      startMinute,
    );
    
    final duration = todo.estimatedTime ?? 30;
    final endTime = startTime.add(Duration(minutes: duration));

    return createEvent(
      summary: todo.text,
      startTime: startTime,
      endTime: endTime,
      description: 'Created from Todai',
    );
  }
}

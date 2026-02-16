// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// Web implementation using localStorage
String? getItem(String key) => html.window.localStorage[key];
void setItem(String key, String value) => html.window.localStorage[key] = value;
void removeItem(String key) => html.window.localStorage.remove(key);

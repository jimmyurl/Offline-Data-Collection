import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:data_collection/pages/collected_data.dart';

class DataProvider with ChangeNotifier {
  static const String _storageKey = 'collected_data';
  static const String _apiUrl = 'https://your-api-endpoint.com/data';

  final List<CollectedData> _items = [];
  bool _isOnline = false;
  final SharedPreferences _prefs;

  DataProvider(this._prefs);

  List<CollectedData> get items => _items;
  bool get isOnline => _isOnline;

  void updateOnlineStatus(bool online) {
    _isOnline = online;
    if (_isOnline) {
      _syncData();
    }
    notifyListeners();
  }

  Future<void> loadData() async {
    try {
      final String? storedData = _prefs.getString(_storageKey);
      if (storedData != null) {
        final List<dynamic> decodedData = json.decode(storedData);
        _items.clear();
        _items.addAll(
          decodedData.map((item) => CollectedData.fromJson(item)).toList(),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  Future<void> addData(CollectedData data) async {
    _items.add(data);
    await _saveToLocal();
    if (_isOnline) {
      _syncData();
    }
    notifyListeners();
  }

  Future<void> _saveToLocal() async {
    try {
      final String encodedData = json.encode(
        _items.map((item) => item.toJson()).toList(),
      );
      await _prefs.setString(_storageKey, encodedData);
    } catch (e) {
      debugPrint('Error saving data: $e');
    }
  }

  Future<void> _syncData() async {
    final unsyncedItems = _items.where((item) => !item.isSynced).toList();

    for (var item in unsyncedItems) {
      try {
        final response = await http.post(
          Uri.parse(_apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(item.toJson()),
        );

        if (response.statusCode == 200) {
          item.markAsSynced();
          await _saveToLocal();
        } else {
          debugPrint('Failed to sync item: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Error syncing data: $e');
      }
    }
    notifyListeners();
  }
}

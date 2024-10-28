import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

// Enhanced data model
class CollectedData {
  final int? id;
  final String title;
  final String description;
  final String location;
  final DateTime timestamp;
  bool isSynced;
  final String? imageLocalPath;
  final String? category;
  final double? latitude;
  final double? longitude;
  final String status;
  final Map<String, dynamic>? additionalFields;

  CollectedData({
    this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.timestamp,
    this.isSynced = false,
    this.imageLocalPath,
    this.category,
    this.latitude,
    this.longitude,
    this.status = 'pending',
    this.additionalFields,
  });

  // Base method for converting to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'timestamp': timestamp.toIso8601String(),
      'isSynced': isSynced ? 1 : 0, // SQLite uses 1/0 for booleans
      'imageLocalPath': imageLocalPath,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'additionalFields':
          additionalFields != null ? jsonEncode(additionalFields) : null,
    };
  }

  // Use toMap for JSON serialization
  Map<String, dynamic> toJson() => toMap();

  // Base method for creating instance from Map
  factory CollectedData.fromMap(Map<String, dynamic> map) {
    return CollectedData(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      location: map['location'],
      timestamp: DateTime.parse(map['timestamp']),
      isSynced: map['isSynced'] == 1, // Convert SQLite 1/0 to boolean
      imageLocalPath: map['imageLocalPath'],
      category: map['category'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      status: map['status'] ?? 'pending',
      additionalFields: map['additionalFields'] != null
          ? jsonDecode(map['additionalFields'])
          : null,
    );
  }

  // Use fromMap for JSON deserialization
  factory CollectedData.fromJson(Map<String, dynamic> json) =>
      CollectedData.fromMap(json);

  void markAsSynced() {
    isSynced = true;
  }

  CollectedData copyWith({
    int? id,
    String? title,
    String? description,
    String? location,
    DateTime? timestamp,
    bool? isSynced,
    String? imageLocalPath,
    String? category,
    double? latitude,
    double? longitude,
    String? status,
    Map<String, dynamic>? additionalFields,
  }) {
    return CollectedData(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      timestamp: timestamp ?? this.timestamp,
      isSynced: isSynced ?? this.isSynced,
      imageLocalPath: imageLocalPath ?? this.imageLocalPath,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      additionalFields: additionalFields ?? this.additionalFields,
    );
  }
}

// Enhanced database helper
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('collected_data.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE collected_data(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        location TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        isSynced INTEGER NOT NULL,
        imageLocalPath TEXT,
        category TEXT,
        latitude REAL,
        longitude REAL,
        status TEXT NOT NULL,
        additionalFields TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns for version 2
      await db
          .execute('ALTER TABLE collected_data ADD COLUMN imageLocalPath TEXT');
      await db.execute('ALTER TABLE collected_data ADD COLUMN category TEXT');
      await db.execute('ALTER TABLE collected_data ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE collected_data ADD COLUMN longitude REAL');
      await db.execute(
          'ALTER TABLE collected_data ADD COLUMN status TEXT NOT NULL DEFAULT "pending"');
      await db.execute(
          'ALTER TABLE collected_data ADD COLUMN additionalFields TEXT');
    }
  }

  Future<int> insert(CollectedData data) async {
    final db = await database;
    return await db.insert('collected_data', data.toMap());
  }

  Future<List<CollectedData>> getUnsyncedData() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'collected_data',
      where: 'isSynced = ?',
      whereArgs: [0],
    );
    return List.generate(maps.length, (i) => CollectedData.fromMap(maps[i]));
  }

  Future<int> markAsSynced(int id) async {
    final db = await database;
    return await db.update(
      'collected_data',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<CollectedData>> getAllData() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('collected_data');
    return List.generate(maps.length, (i) => CollectedData.fromMap(maps[i]));
  }

  Future<int> deleteData(int id) async {
    final db = await database;
    return await db.delete(
      'collected_data',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

// Enhanced data provider with sync features
class DataProvider with ChangeNotifier {
  final List<CollectedData> _items = [];
  bool _isOnline = false;
  bool _isSyncing = false;
  final ImagePicker _imagePicker = ImagePicker();

  List<CollectedData> get items => [..._items];
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  Future<void> loadData() async {
    final data = await DatabaseHelper.instance.getAllData();
    _items.clear();
    _items.addAll(data);
    notifyListeners();
  }

  Future<void> initializeConnectivity() async {
    final connectivity = await Connectivity().checkConnectivity();
    _isOnline = connectivity != ConnectivityResult.none;

    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      _isOnline = results.any((result) => result != ConnectivityResult.none);
      if (_isOnline) {
        syncData();
      }
      notifyListeners();
    });
  }

  String? validateTitle(String? value) {
    if (value == null || value.isEmpty) {
      return 'Title is required';
    }
    if (value.length < 3) {
      return 'Title must be at least 3 characters';
    }
    return null;
  }

  String? validateDescription(String? value) {
    if (value == null || value.isEmpty) {
      return 'Description is required';
    }
    return null;
  }

  Future<String?> captureImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String localPath = join(appDir.path, fileName);

        await File(image.path).copy(localPath);
        return localPath;
      }
      return null;
    } catch (e) {
      print('Error capturing image: $e');
      return null;
    }
  }

  Future<void> syncData() async {
    if (!_isOnline || _isSyncing) return;

    try {
      _isSyncing = true;
      notifyListeners();

      final unsyncedData = await DatabaseHelper.instance.getUnsyncedData();

      for (var data in unsyncedData) {
        try {
          String? imageUrl;
          if (data.imageLocalPath != null) {
            final File imageFile = File(data.imageLocalPath!);
            if (await imageFile.exists()) {
              // TODO: Implement image upload to server
              // imageUrl = await uploadImage(imageFile);
            }
          }

          // TODO: Implement actual API call
          // await apiService.syncData(
          //   data.toMap(),
          //   imageUrl: imageUrl,
          // );

          await DatabaseHelper.instance.markAsSynced(data.id!);
        } catch (e) {
          print('Error syncing item ${data.id}: $e');
        }
      }

      await loadData();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void startPeriodicSync() {
    Future.doWhile(() async {
      if (_isOnline && !_isSyncing) {
        await syncData();
      }
      await Future.delayed(const Duration(minutes: 15));
      return true;
    });
  }

  Future<bool> addData(CollectedData data) async {
    if (validateTitle(data.title) != null ||
        validateDescription(data.description) != null) {
      return false;
    }

    await DatabaseHelper.instance.insert(data);
    await loadData();

    if (_isOnline) {
      syncData();
    }

    return true;
  }

  Future<void> deleteData(int id) async {
    await DatabaseHelper.instance.deleteData(id);
    await loadData();
    notifyListeners();
  }
}

// Form widget for data collection
class DataCollectionForm extends StatefulWidget {
  @override
  _DataCollectionFormState createState() => _DataCollectionFormState();
}

class _DataCollectionFormState extends State<DataCollectionForm> {
  final _formKey = GlobalKey<FormState>();
  String? _title;
  String? _description;
  String? _location;
  DateTime _timestamp = DateTime.now();
  String? _imageLocalPath;
  String? _category;
  double? _latitude;
  double? _longitude;
  String _status = 'pending';
  Map<String, dynamic>? _additionalFields = {};

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            decoration: InputDecoration(labelText: 'Title'),
            validator: (value) =>
                Provider.of<DataProvider>(context, listen: false)
                    .validateTitle(value),
            onSaved: (value) {
              _title = value;
            },
          ),
          TextFormField(
            decoration: InputDecoration(labelText: 'Description'),
            validator: (value) =>
                Provider.of<DataProvider>(context, listen: false)
                    .validateDescription(value),
            onSaved: (value) {
              _description = value;
            },
          ),
          TextFormField(
            decoration: InputDecoration(labelText: 'Location'),
            onSaved: (value) {
              _location = value;
            },
          ),
          // Additional fields and image capture button can go here
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState?.validate() == true) {
                _formKey.currentState?.save();

                final collectedData = CollectedData(
                  title: _title!,
                  description: _description!,
                  location: _location!,
                  timestamp: _timestamp,
                  imageLocalPath: _imageLocalPath,
                  category: _category,
                  latitude: _latitude,
                  longitude: _longitude,
                  status: _status,
                  additionalFields: _additionalFields,
                );

                final success =
                    await Provider.of<DataProvider>(context, listen: false)
                        .addData(collectedData);

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Data successfully saved!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Validation failed.')),
                  );
                }
              }
            },
            child: Text('Save Data'),
          ),
        ],
      ),
    );
  }
}

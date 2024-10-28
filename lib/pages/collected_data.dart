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
  final bool isSynced;
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'timestamp': timestamp.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
      'imageLocalPath': imageLocalPath,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'additionalFields':
          additionalFields != null ? jsonEncode(additionalFields) : null,
    };
  }

  factory CollectedData.fromMap(Map<String, dynamic> map) {
    return CollectedData(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      location: map['location'],
      timestamp: DateTime.parse(map['timestamp']),
      isSynced: map['isSynced'] == 1,
      imageLocalPath: map['imageLocalPath'],
      category: map['category'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      status: map['status'],
      additionalFields: map['additionalFields'] != null
          ? jsonDecode(map['additionalFields'])
          : null,
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

  // Form validation
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

  // Image handling
  Future<String?> captureImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        // Save image to app's local storage
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

  // Enhanced sync functionality
  Future<void> syncData() async {
    if (!_isOnline || _isSyncing) return;

    try {
      _isSyncing = true;
      notifyListeners();

      final unsyncedData = await DatabaseHelper.instance.getUnsyncedData();

      for (var data in unsyncedData) {
        try {
          // Prepare image data if exists
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
          // Could implement retry logic here
        }
      }

      await loadData();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Periodic sync attempt
  void startPeriodicSync() {
    Future.doWhile(() async {
      if (_isOnline && !_isSyncing) {
        await syncData();
      }
      await Future.delayed(const Duration(minutes: 15));
      return true; // Continue the loop
    });
  }

  // Enhanced data addition with validation
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
}

// Form widget for data collection
class DataCollectionForm extends StatefulWidget {
  @override
  _DataCollectionFormState createState() => _DataCollectionFormState();
}

class _DataCollectionFormState extends State<DataCollectionForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _imageLocalPath;
  String? _selectedCategory;
  final List<String> _categories = ['General', 'Important', 'Urgent'];

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);

    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(labelText: 'Title'),
            validator: dataProvider.validateTitle,
          ),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(labelText: 'Description'),
            validator: dataProvider.validateDescription,
            maxLines: 3,
          ),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            items: _categories.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCategory = value;
              });
            },
            decoration: InputDecoration(labelText: 'Category'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final imagePath = await dataProvider.captureImage();
              setState(() {
                _imageLocalPath = imagePath;
              });
            },
            icon: Icon(Icons.camera_alt),
            label: Text('Capture Image'),
          ),
          if (_imageLocalPath != null)
            Image.file(
              File(_imageLocalPath!),
              height: 200,
              fit: BoxFit.cover,
            ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final success = await dataProvider.addData(
                  CollectedData(
                    title: _titleController.text,
                    description: _descriptionController.text,
                    location: 'Current Location', // TODO: Implement location
                    timestamp: DateTime.now(),
                    imageLocalPath: _imageLocalPath,
                    category: _selectedCategory,
                  ),
                );

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Data saved successfully')),
                  );
                  // Clear form
                  _titleController.clear();
                  _descriptionController.clear();
                  setState(() {
                    _imageLocalPath = null;
                    _selectedCategory = null;
                  });
                }
              }
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

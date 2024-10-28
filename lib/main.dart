import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:data_collection/pages/collected_data.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => DataProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Offline Data Collection',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _setupConnectivity();
    Provider.of<DataProvider>(context, listen: false).loadData();
  }

  Future<void> _setupConnectivity() async {
    final connectivity = Connectivity();

    // Check initial connection status
    final result = await connectivity.checkConnectivity();
    Provider.of<DataProvider>(context, listen: false)
        .updateOnlineStatus(result != ConnectivityResult.none);

    // Listen for connectivity changes
    connectivity.onConnectivityChanged.listen((result) {
      Provider.of<DataProvider>(context, listen: false)
          .updateOnlineStatus(result != ConnectivityResult.none);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Data Collection'),
        actions: [
          Consumer<DataProvider>(
            builder: (context, provider, child) {
              return Icon(
                provider.isOnline ? Icons.wifi : Icons.wifi_off,
                color: provider.isOnline ? Colors.green : Colors.red,
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Consumer<DataProvider>(
        builder: (context, provider, child) {
          return ListView.builder(
            itemCount: provider.items.length,
            itemBuilder: (context, index) {
              final item = provider.items[index];
              return ListTile(
                title: Text(item.title),
                subtitle: Text(item.description),
                trailing: Icon(
                  item.isSynced ? Icons.cloud_done : Icons.cloud_upload,
                  color: item.isSynced ? Colors.green : Colors.orange,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDataDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddDataDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final data = CollectedData(
                title: titleController.text,
                description: descriptionController.text,
                location: locationController.text,
                timestamp: DateTime.now(),
              );
              Provider.of<DataProvider>(context, listen: false).addData(data);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

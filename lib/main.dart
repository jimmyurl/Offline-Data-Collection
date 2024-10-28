import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:data_collection/pages/collected_data.dart'; // This imports 'CollectedData'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:data_collection/pages/data_provider.dart'
    as provider; // Adding a prefix to avoid name conflict

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ChangeNotifierProvider(
      create: (_) => provider.DataProvider(
          prefs), // Using the prefixed 'provider.DataProvider'
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
    // Setup connectivity and load data after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupConnectivity();
      Provider.of<provider.DataProvider>(context, listen: false)
          .loadData(); // Referencing the prefixed 'DataProvider'
    });
  }

  Future<void> _setupConnectivity() async {
    final connectivity = Connectivity();

    final result = await connectivity.checkConnectivity();
    if (!mounted) return;
    Provider.of<provider.DataProvider>(context, listen: false)
        .updateOnlineStatus(result != ConnectivityResult.none);

    connectivity.onConnectivityChanged.listen((result) {
      if (!mounted) return;
      Provider.of<provider.DataProvider>(context, listen: false)
          .updateOnlineStatus(result != ConnectivityResult.none);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF009688), // Set AppBar color here
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 40,
            ),
          ],
        ),
        actions: [
          Consumer<provider.DataProvider>(
            builder: (context, provider, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Icon(
                  provider.isOnline ? Icons.wifi : Icons.wifi_off,
                  color: provider.isOnline ? Colors.green : Colors.red,
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<provider.DataProvider>(
        builder: (context, provider, child) {
          if (provider.items.isEmpty) {
            return const Center(
              child: Text('No data collected yet'),
            );
          }

          return ListView.builder(
            itemCount: provider.items.length,
            itemBuilder: (context, index) {
              final item = provider.items[index];
              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: ListTile(
                  title: Text(item.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.description),
                      const SizedBox(height: 4),
                      Text(
                        'Location: ${item.location}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Date: ${item.timestamp.toString().split('.')[0]}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  trailing: Icon(
                    item.isSynced ? Icons.cloud_done : Icons.cloud_upload,
                    color: item.isSynced ? Colors.green : Colors.orange,
                  ),
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
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: Image.asset('assets/icons/home.png',
                width: 24, height: 24), // Home icon
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/icons/assessments.png',
                width: 24, height: 24), // Home icon
            label: 'Assessments',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/icons/uploads.png',
                width: 24, height: 24), // Uploads icon
            label: 'Uploads',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/icons/profile.png',
                width: 24, height: 24), // Profile icon
            label: 'Profile',
          ),
        ],
        currentIndex: 0, // Set the current index based on the selected tab
        selectedItemColor:
            const Color(0xFF009688), // Change selected item color
        unselectedItemColor:
            Colors.grey, // Optional: set the unselected item color
        onTap: (index) {
          // Handle navigation based on the index
          // You can implement navigation logic here
        },
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter title',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter description',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'Enter location',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (titleController.text.isEmpty ||
                  descriptionController.text.isEmpty ||
                  locationController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all fields'),
                  ),
                );
                return;
              }

              final data = CollectedData(
                title: titleController.text,
                description: descriptionController.text,
                location: locationController.text,
                timestamp: DateTime.now(),
              );

              Provider.of<provider.DataProvider>(context,
                      listen: false) // Using prefixed 'DataProvider'
                  .addData(data);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

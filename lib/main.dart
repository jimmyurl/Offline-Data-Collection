import 'package:data_collection/pages/collected_data.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (BuildContext context) => DataProvider(),
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
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Setup connectivity and load data after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      dataProvider.initializeConnectivity();
      dataProvider.loadData();
      dataProvider.startPeriodicSync();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF009688),
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
          Consumer<DataProvider>(
            builder:
                (BuildContext context, DataProvider provider, Widget? child) {
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
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          CollectedDataList(),
          Center(child: Text('Assessments')),
          Center(child: Text('Uploads')),
          Center(child: Text('Profile')),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDataCollectionForm(context),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: ImageIcon(AssetImage('assets/icons/assessments.png')),
          label: 'Assessments',
        ),
        BottomNavigationBarItem(
          icon: ImageIcon(AssetImage('assets/icons/uploads.png')),
          label: 'Uploads',
        ),
        BottomNavigationBarItem(
          icon: ImageIcon(AssetImage('assets/icons/profile.png')),
          label: 'Profile',
        ),
      ],
      currentIndex: _selectedIndex,
      selectedItemColor: const Color(0xFF009688),
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
    );
  }

  void _showDataCollectionForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16.0,
          right: 16.0,
          top: 16.0,
        ),
        child: const DataCollectionForm(),
      ),
    );
  }
}

import 'package:data_collection/pages/collected_data.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => DataProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: DataCollectionForm(), // or wherever you're using it
        ),
      ),
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
      Provider.of<DataProvider>(context, listen: false)
          .initializeConnectivity();
      Provider.of<DataProvider>(context, listen: false).loadData();
      Provider.of<DataProvider>(context, listen: false).startPeriodicSync();
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
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Image.asset('assets/icons/assessments.png',
              width: 24, height: 24),
          label: 'Assessments',
        ),
        BottomNavigationBarItem(
          icon: Image.asset('assets/icons/uploads.png', width: 24, height: 24),
          label: 'Uploads',
        ),
        BottomNavigationBarItem(
          icon: Image.asset('assets/icons/profile.png', width: 24, height: 24),
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
      builder: (context) => Padding(
        padding: EdgeInsets.all(16.0),
        child: DataCollectionForm(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'loginpage.dart';
import 'add_poll_page.dart';
import 'pollPage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SplashWrapper());
}

// SplashWrapper will show splash first, then MyApp
class SplashWrapper extends StatelessWidget {
  const SplashWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Show splash for 3 seconds, then navigate to MyApp
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MyApp()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child:SizedBox(
          child: Image.asset("assets/ASKMATE.png",
              width: 200, height: 200, fit: BoxFit.cover)  ,
        )
      )
    );
  }
}

// Keep your existing MyApp exactly the same
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<String?> _getSavedRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('role');
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Polling System',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: FutureBuilder<String?>(
        future: _getSavedRole(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text('Error loading role: ${snapshot.error}'),
              ),
            );
          }

          final storedRole = snapshot.data;
          final user = FirebaseAuth.instance.currentUser;

          if (user == null) return const LoginPage();
          if (storedRole == 'admin') return const AddPollPage();
          if (storedRole == 'user') return const PollPage();

          return const LoginPage();
        },
      ),
    );
  }
}

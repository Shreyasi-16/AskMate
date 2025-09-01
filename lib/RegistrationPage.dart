import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'add_poll_page.dart';
import 'pollPage.dart';

class RegistrationPage extends StatefulWidget {
  final String? prefillEmail;
  final String? prefillRole;

  const RegistrationPage({super.key, this.prefillEmail, this.prefillRole});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String _role = 'user';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefillEmail != null) _email.text = widget.prefillEmail!;
    if (widget.prefillRole != null) _role = widget.prefillRole!;
  }

  Future<void> _register() async {
    final email = _email.text.trim();
    final pass = _password.text;
    final confirm = _confirm.text;

    if (email.isEmpty || pass.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill all fields')));
      return;
    }
    if (pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() => _loading = true);

    try {
      // Check existing email in Firestore
      final q = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: email).limit(1).get();
      if (q.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account already exists. Please login.')));
        return;
      }

      // Create auth user
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);

      // Save user doc with role
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'email': email,
        'role': _role,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Save role + uid locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('role', _role);
      await prefs.setString('uid', cred.user!.uid);

      // Navigate to respective page
      if (!mounted) return;
      if (_role == 'admin') {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AddPollPage()), (r) => false);
      } else {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PollPage()), (r) => false);
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration error: ${e.message}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(controller: _password, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 12),
            TextField(controller: _confirm, decoration: const InputDecoration(labelText: 'Confirm Password'), obscureText: true),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Role:'),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _role,
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('User')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? 'user'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _loading ? null : _register, child: _loading ? const CircularProgressIndicator() : const Text('Register')),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Already have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }
}

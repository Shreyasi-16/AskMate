import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widget/logout_button.dart';
import 'chart_admin.dart';
class AddPollPage extends StatefulWidget {
  const AddPollPage({super.key});

  @override
  State<AddPollPage> createState() => _AddPollPageState();
}

class _AddPollPageState extends State<AddPollPage> {
  final _question = TextEditingController();
  final _op1 = TextEditingController();
  final _op2 = TextEditingController();
  final _op3 = TextEditingController();

  bool _saving = false;
  DateTime? _startTime;
  DateTime? _endTime;
  String? _editingPollId;

  User? get _user => FirebaseAuth.instance.currentUser;

  Future<void> _pickDateTime({required bool isStart}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    final dateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isStart) {
        _startTime = dateTime;
      } else {
        _endTime = dateTime;
      }
    });
  }

  Future<void> _addOrUpdatePoll() async {
    final q = _question.text.trim();
    final a = _op1.text.trim();
    final b = _op2.text.trim();
    final c = _op3.text.trim();

    if (q.isEmpty ||
        a.isEmpty ||
        b.isEmpty ||
        c.isEmpty ||
        _startTime == null ||
        _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill all fields and select start/end time')),
      );
      return;
    }

    if (_endTime!.isBefore(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      if (_editingPollId != null) {
        await FirebaseFirestore.instance
            .collection('polls')
            .doc(_editingPollId)
            .update({
          'question': q,
          'op1': a,
          'op2': b,
          'op3': c,
          'startTime': Timestamp.fromDate(_startTime!),
          'endTime': Timestamp.fromDate(_endTime!),
        });

        // ✅ Reset form after update
        _editingPollId = null;
        _question.clear();
        _op1.clear();
        _op2.clear();
        _op3.clear();
        setState(() {
          _startTime = null;
          _endTime = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poll updated successfully')),
        );
      } else {
        // Add new poll
        await FirebaseFirestore.instance.collection('polls').add({
          'question': q,
          'op1': a,
          'op2': b,
          'op3': c,
          'votes': {}, // uid -> option
          'createdBy': _user?.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'startTime': Timestamp.fromDate(_startTime!),
          'endTime': Timestamp.fromDate(_endTime!),
        });
      }

      _question.clear();
      _op1.clear();
      _op2.clear();
      _op3.clear();
      setState(() {
        _startTime = null;
        _endTime = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving poll: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editPoll(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      _editingPollId = doc.id;
      _question.text = data['question'] ?? '';
      _op1.text = data['op1'] ?? '';
      _op2.text = data['op2'] ?? '';
      _op3.text = data['op3'] ?? '';
      _startTime = (data['startTime'] as Timestamp?)?.toDate();
      _endTime = (data['endTime'] as Timestamp?)?.toDate();
    });
  }

  Future<Map<String, String>> _getUserVoteEmails(Map<String, dynamic> votes) async {
    Map<String, String> map = {};
    for (var uid in votes.keys) {
      try {
        final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
        map[doc.data()?['email'] ?? uid] = votes[uid];
      } catch (_) {
        map[uid] = votes[uid];
      }
    }
    return map;
  }

  @override
  void dispose() {
    _question.dispose();
    _op1.dispose();
    _op2.dispose();
    _op3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    String formatDateTime(DateTime? dt) {
      if (dt == null) return 'Select';
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Admin - Manage Polls')),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text('Admin'),
              accountEmail: Text(user?.email ?? ''),
              currentAccountPicture:
              const CircleAvatar(child: Icon(Icons.person)),
            ),
            ListTile(
              leading: const Icon(Icons.poll, color: Colors.blue),
              title: const Text('Poll Stats'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChartAdminPage(),
                  ),
                );
              },
            ),
            const Spacer(),
            const LogoutButton(),
          ],
        ),
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            // Add/Edit Poll Form
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _question,
                    decoration: const InputDecoration(labelText: 'Poll Question'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _op1,
                    decoration: const InputDecoration(labelText: 'Option 1'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _op2,
                    decoration: const InputDecoration(labelText: 'Option 2'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _op3,
                    decoration: const InputDecoration(labelText: 'Option 3'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => _pickDateTime(isStart: true),
                        child: Text('Start: ${formatDateTime(_startTime)}'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => _pickDateTime(isStart: false),
                        child: Text('End: ${formatDateTime(_endTime)}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _saving ? null : _addOrUpdatePoll,
                    child: _saving
                        ? const CircularProgressIndicator()
                        : Text(_editingPollId != null
                        ? 'Update Poll'
                        : 'Add Poll'),
                  ),
                ],
              ),
            ),
            const Divider(),

            // List admin's polls
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Your Polls',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('polls')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('You have not created any polls yet.'),
                  );
                }

                final docs = snap.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['createdBy'] == user?.uid;
                }).toList();

                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('You have not created any polls yet.'),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final votes = Map<String, dynamic>.from(data['votes'] ?? {});
                    final opList = [data['op1'], data['op2'], data['op3']]
                        .whereType<String>()
                        .toList();

                    // Vote counts
                    final voteCounts = {for (var op in opList) op: 0};
                    votes.values.forEach((v) {
                      if (voteCounts.containsKey(v)) {
                        voteCounts[v] = voteCounts[v]! + 1;
                      }
                    });

                    return FutureBuilder<Map<String, String>>(
                      future: _getUserVoteEmails(votes),
                      builder: (context, snapshot) {
                        final userVotes = snapshot.data ?? {};
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['question'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                    'Start: ${data['startTime']?.toDate().toLocal().toString()}'),
                                Text(
                                    'End: ${data['endTime']?.toDate().toLocal().toString()}'),
                                const SizedBox(height: 8),
                                ...opList.map((op) =>
                                    Text('$op: ${voteCounts[op]}')),
                                const SizedBox(height: 8),
                                DropdownButton<String>(
                                  hint: const Text('View who voted'),
                                  items: userVotes.entries
                                      .map(
                                        (e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Text('${e.key} → ${e.value}'),
                                    ),
                                  )
                                      .toList(),
                                  onChanged: (_) {},
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      tooltip: 'Edit',
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue),
                                      onPressed: () => _editPoll(doc),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete',
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () async {
                                        await FirebaseFirestore.instance
                                            .collection('polls')
                                            .doc(doc.id)
                                            .delete();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text('Poll deleted')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

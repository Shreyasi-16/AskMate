import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'widget/logout_button.dart';
import 'chart_page.dart'; // 👈 make sure chart_page.dart exists

class PollPage extends StatelessWidget {
  const PollPage({super.key});

  Future<bool> _hasVoted(String uid, String pollId) async {
    final pollSnap = await FirebaseFirestore.instance.collection('polls').doc(pollId).get();
    if (!pollSnap.exists) return false;
    final votes = Map<String, dynamic>.from(pollSnap['votes'] ?? {});
    return votes.containsKey(uid);
  }

  Future<void> _vote(BuildContext context, String pollId, String option) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to vote')));
      return;
    }
    final uid = user.uid;
    final voted = await _hasVoted(uid, pollId);
    if (voted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have already voted on this poll')));
      return;
    }

    final pollRef = FirebaseFirestore.instance.collection('polls').doc(pollId);
    try {
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final pollSnap = await txn.get(pollRef);
        if (!pollSnap.exists) throw 'Poll not found';
        final startTime = pollSnap['startTime'] as Timestamp?;
        final endTime = pollSnap['endTime'] as Timestamp?;
        final now = Timestamp.now();

        if (startTime == null ||
            endTime == null ||
            now.compareTo(startTime) < 0 ||
            now.compareTo(endTime) > 0) {
          throw 'This poll is not active';
        }

        final currentVotes = Map<String, dynamic>.from(pollSnap['votes'] ?? {});
        currentVotes[uid] = option; // save user vote
        txn.update(pollRef, {'votes': currentVotes});
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vote recorded')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Vote failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final now = Timestamp.now();

    return Scaffold(
      appBar: AppBar(title: const Text('User - Polls')),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text('User'),
              accountEmail: Text(user?.email ?? ''),
              currentAccountPicture: const CircleAvatar(child: Icon(Icons.person)),
            ),
            const Spacer(),
            const LogoutButton(),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('polls')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('No polls available'));
          }

          final allDocs = snap.data!.docs;

          final activeDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final start = data['startTime'] as Timestamp?;
            final end = data['endTime'] as Timestamp?;
            return start != null && end != null &&
                now.compareTo(start) >= 0 && now.compareTo(end) <= 0;
          }).toList();

          final notActiveDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final start = data['startTime'] as Timestamp?;
            return start != null && now.compareTo(start) < 0;
          }).toList();

          final expiredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final end = data['endTime'] as Timestamp?;
            return end != null && now.compareTo(end) > 0;
          }).toList();

          return ListView(
            children: [
              if (activeDocs.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("Active Polls", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ...activeDocs.map((doc) => _buildPollCard(context, doc, user, true)),

              if (notActiveDocs.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("Upcoming Polls", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ...notActiveDocs.map((doc) => _buildPollCard(context, doc, user, false)),

              if (expiredDocs.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("Expired Polls", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ...expiredDocs.map((doc) => _buildPollCard(context, doc, user, false)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPollCard(BuildContext context, QueryDocumentSnapshot doc, User? user, bool isActive) {
    final data = doc.data() as Map<String, dynamic>;
    final votesMap = Map<String, dynamic>.from(data['votes'] ?? {});
    final opList = <String>[
      data['op1'] ?? '',
      data['op2'] ?? '',
      data['op3'] ?? '',
    ].where((s) => s.isNotEmpty).toList();

    final voteCounts = {for (var op in opList) op: 0};
    votesMap.values.forEach((v) {
      if (voteCounts.containsKey(v)) voteCounts[v] = voteCounts[v]! + 1;
    });

    final hasVoted = user != null && votesMap.containsKey(user.uid);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChartPage(pollId: doc.id), // 👈 navigate to chart_page.dart
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['question'] ?? '',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Start: ${data['startTime']?.toDate().toLocal().toString().split(' ')[0]}'),
            Text('End: ${data['endTime']?.toDate().toLocal().toString().split(' ')[0]}'),
            const SizedBox(height: 8),
            Text(
              'Total votes: ${voteCounts.values.fold<int>(0, (sum, val) => sum + val)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...opList.map((opt) {
              final count = voteCounts[opt] ?? 0;
              final totalVotes = voteCounts.values.fold<int>(0, (sum, val) => sum + val);
              final percent = totalVotes == 0 ? 0.0 : count / totalVotes;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(opt)),
                        Text('$count votes (${(percent * 100).toStringAsFixed(1)}%)'),
                        const SizedBox(width: 12),
                        if (isActive)
                          ElevatedButton(
                            onPressed: hasVoted ? null : () => _vote(context, doc.id, opt),
                            child: const Text('Vote'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percent,
                      minHeight: 8,
                      backgroundColor: Colors.grey[300],
                      color: isActive ? Colors.blue : Colors.grey,
                    ),
                  ],
                ),
              );
            }).toList(),
          ]),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ChartAdminPage extends StatefulWidget {
  const ChartAdminPage({super.key});

  @override
  State<ChartAdminPage> createState() => _ChartAdminPageState();
}

// Chart data model
class PollData {
  final String period;
  final int count;
  PollData(this.period, this.count);
}

class _ChartAdminPageState extends State<ChartAdminPage> {
  DateTime _selectedDate = DateTime.now();
  String _selectedView = "Day"; // track which view is active
  int _dayCount = 0;
  final user = FirebaseAuth.instance.currentUser;
  List<QueryDocumentSnapshot> _polls = [];

  @override
  void initState() {
    super.initState();
    _fetchCounts();
  }

  Future<void> _fetchCounts() async {
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    if (!userDoc.exists) return;
    final role = userDoc.data()?['role'] ?? 'user';

    if (role != 'admin') {
      setState(() {
        _dayCount = 0;
        _polls = [];
      });
      return;
    }

    final pollsSnapshot = await FirebaseFirestore.instance
        .collection('polls')
        .where('createdBy', isEqualTo: user!.uid)
        .get();

    _polls = pollsSnapshot.docs;

    // Day count
    int day = 0;
    final selectedLocalDate =
    DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    for (var doc in _polls) {
      final ts = doc.get('createdAt') as Timestamp?;
      if (ts == null) continue;
      final createdAt = ts.toDate();
      final createdLocalDate =
      DateTime(createdAt.year, createdAt.month, createdAt.day);
      if (createdLocalDate == selectedLocalDate) day++;
    }

    setState(() {
      _dayCount = day;
    });
  }

  List<DateTime> _getCurrentWeek(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (index) => monday.add(Duration(days: index)));
  }

  void _goToPreviousDay() {
    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
    _fetchCounts();
  }

  void _goToNextDay() {
    setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
    _fetchCounts();
  }

  void _goToPreviousWeek() {
    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 7)));
    _fetchCounts();
  }

  void _goToNextWeek() {
    setState(() => _selectedDate = _selectedDate.add(const Duration(days: 7)));
    _fetchCounts();
  }

  void _goToPreviousMonth() {
    setState(() =>
    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1));
    _fetchCounts();
  }

  void _goToNextMonth() {
    setState(() =>
    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1));
    _fetchCounts();
  }

  void _goToPreviousYear() {
    setState(() => _selectedDate = DateTime(_selectedDate.year - 1));
    _fetchCounts();
  }

  void _goToNextYear() {
    setState(() => _selectedDate = DateTime(_selectedDate.year + 1));
    _fetchCounts();
  }

  // Chart widget showing only the selected view
  Widget _buildPollChart(String view) {
    List<PollData> data = [];

    if (view == "Day") {
      data = [PollData(DateFormat('MMM d').format(_selectedDate), _dayCount)];
    } else if (view == "Week") {
      final weekDays = _getCurrentWeek(_selectedDate);
      final endOfWeek = weekDays.last.add(const Duration(days: 1));

      // inside _buildPollChart("Week")
      data = weekDays.map((d) {
        final key = DateFormat('EEE d').format(d);
        int count = 0;

        // normalize start and end of this day
        final dayStart = DateTime(d.year, d.month, d.day);
        final dayEnd = dayStart.add(const Duration(days: 1));

        for (var doc in _polls) {
          final ts = doc.get('createdAt') as Timestamp?;
          if (ts == null) continue;

          // convert Firestore timestamp to local date at midnight
          final createdAt = ts.toDate().toLocal();
          final createdDate = DateTime(createdAt.year, createdAt.month, createdAt.day);

          if (!createdDate.isBefore(dayStart) && createdDate.isBefore(dayEnd)) {
            count++;
          }
        }
        return PollData(key, count);
      }).toList();

    }
    else if (view == "Month") {
      final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
      Map<int, int> counts = {};
      for (int d = 1; d <= lastDay.day; d++) counts[d] = 0;
      for (var doc in _polls) {
        final ts = doc.get('createdAt') as Timestamp?;
        if (ts == null) continue;
        final createdAt = ts.toDate();
        if (createdAt.year == _selectedDate.year &&
            createdAt.month == _selectedDate.month) {
          counts[createdAt.day] = (counts[createdAt.day] ?? 0) + 1;
        }
      }
      data = counts.entries.map((e) => PollData(e.key.toString(), e.value)).toList();
    } else if (view == "Year") {
      Map<int, int> counts = {};
      for (int m = 1; m <= 12; m++) counts[m] = 0;
      for (var doc in _polls) {
        final ts = doc.get('createdAt') as Timestamp?;
        if (ts == null) continue;
        final createdAt = ts.toDate();
        if (createdAt.year == _selectedDate.year) {
          counts[createdAt.month] = (counts[createdAt.month] ?? 0) + 1;
        }
      }
      data = counts.entries
          .map((e) => PollData(DateFormat('MMM').format(DateTime(0, e.key)), e.value))
          .toList();
    }

    return Center(
      child: SizedBox(
        height: 550,
        child: SfCartesianChart(
          primaryXAxis: CategoryAxis(),
          primaryYAxis: NumericAxis(
            minimum: 0,
            interval: 1,
            title: AxisTitle(text: 'Number of Polls'),
          ),
          zoomPanBehavior: ZoomPanBehavior(
            enablePanning: true,
            enablePinching: true,
            zoomMode: ZoomMode.x,
            maximumZoomLevel: 0.1,
          ),
          series: [
            ColumnSeries<PollData, String>(
              dataSource: data,
              xValueMapper: (PollData poll, _) => poll.period,
              yValueMapper: (PollData poll, _) => poll.count,
              color: const Color.fromARGB(255, 0, 128, 128),
              dataLabelSettings: const DataLabelSettings(isVisible: true),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Poll Stats"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildViewButton("Day"),
              const SizedBox(width: 10),
              _buildViewButton("Week"),
              const SizedBox(width: 10),
              _buildViewButton("Month"),
              const SizedBox(width: 10),
              _buildViewButton("Year"),
            ],
          ),
          Expanded(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Navigation row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_selectedView == "Day") ...[
                      IconButton(onPressed: _goToPreviousDay, icon: const Icon(Icons.chevron_left)),
                      Text(DateFormat('EEEE, MMMM d').format(_selectedDate),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: _goToNextDay, icon: const Icon(Icons.chevron_right)),
                    ] else if (_selectedView == "Week") ...[
                      IconButton(onPressed: _goToPreviousWeek, icon: const Icon(Icons.chevron_left)),
                      Text(
                        "Week of ${DateFormat('MMM d').format(_getCurrentWeek(_selectedDate).first)} - ${DateFormat('MMM d').format(_getCurrentWeek(_selectedDate).last)}",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(onPressed: _goToNextWeek, icon: const Icon(Icons.chevron_right)),
                    ] else if (_selectedView == "Month") ...[
                      IconButton(onPressed: _goToPreviousMonth, icon: const Icon(Icons.chevron_left)),
                      Text(DateFormat('MMMM yyyy').format(_selectedDate),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: _goToNextMonth, icon: const Icon(Icons.chevron_right)),
                    ] else if (_selectedView == "Year") ...[
                      IconButton(onPressed: _goToPreviousYear, icon: const Icon(Icons.chevron_left)),
                      Text(DateFormat('yyyy').format(_selectedDate),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: _goToNextYear, icon: const Icon(Icons.chevron_right)),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                // Chart
                Expanded(
                  child: _buildPollChart(_selectedView), // week chart will now show day-wise counts
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildViewButton(String view) {
    final isSelected = _selectedView == view;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.teal : Colors.grey[300],
        foregroundColor: isSelected ? Colors.white : Colors.black,
      ),
      onPressed: () {
        setState(() => _selectedView = view);
        _fetchCounts();
      },
      child: Text(view),
    );
  }
}

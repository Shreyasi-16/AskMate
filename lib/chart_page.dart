import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
// chart page for user
class ChartPage extends StatelessWidget {
  final String pollId;

  const ChartPage({super.key, required this.pollId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Poll Results")),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection("polls").doc(pollId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Poll not found"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final question = data["question"] ?? "Poll Question";
          final votesMap = Map<String, dynamic>.from(data["votes"] ?? {});
          final options = <String>[
            data["op1"] ?? "",
            data["op2"] ?? "",
            data["op3"] ?? "",
          ].where((o) => o.isNotEmpty).toList();

          // count votes
          final Map<String, int> voteCounts = {for (var o in options) o: 0};
          votesMap.values.forEach((v) {
            if (voteCounts.containsKey(v)) {
              voteCounts[v] = voteCounts[v]! + 1;
            }
          });

          final chartData = voteCounts.entries
              .map((e) => _VoteData(e.key, e.value))
              .toList();

          final totalVotes = voteCounts.values.fold<int>(0, (a, b) => a + b);

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(
                    question,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Pie Chart
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SfCircularChart(
                        title: ChartTitle(text: "Pie Chart"),
                        legend: Legend(isVisible: true),
                        series: <PieSeries<_VoteData, String>>[
                          PieSeries<_VoteData, String>(
                            dataSource: chartData,
                            xValueMapper: (d, _) => d.option,
                            yValueMapper: (d, _) => d.votes,
                            dataLabelMapper: (d, _) =>
                            "${d.option} (${d.votes})",
                            dataLabelSettings:
                            const DataLabelSettings(isVisible: true),
                          )
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Bar Chart
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SfCartesianChart(
                        title: ChartTitle(text: "Bar Chart"),
                        primaryXAxis: CategoryAxis(),
                        primaryYAxis: NumericAxis(
                          minimum: 0,
                          interval: 1,
                        ),
                        series: [
                          ColumnSeries<_VoteData, String>(
                            dataSource: chartData,
                            xValueMapper: (d, _) => d.option,
                            yValueMapper: (d, _) => d.votes,
                            dataLabelSettings:
                            const DataLabelSettings(isVisible: true),
                          )
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    "Total Votes: $totalVotes",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VoteData {
  final String option;
  final int votes;
  _VoteData(this.option, this.votes);
}

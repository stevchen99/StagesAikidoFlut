import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:grouped_list/grouped_list.dart';

class Stage {
  final String id;
  final DateTime date;
  final String place;
  final String stageName;
  final double cost;
  final String dept;

  Stage({
    required this.id,
    required this.date,
    required this.place,
    required this.stageName,
    required this.cost,
    required this.dept,
  });

  factory Stage.fromJson(Map<String, dynamic> json) {
    return Stage(
      id: json['_id'],
      date: DateTime.parse(json['date']),
      place: json['place'],
      stageName: json['stageName'],
      cost: (json['cost'] as num).toDouble(),
      dept: json['dept'],
    );
  }
}

class StageAgendaPage extends StatefulWidget {
  const StageAgendaPage({super.key});

  @override
  State<StageAgendaPage> createState() => _StageAgendaPageState();
}

class _StageAgendaPageState extends State<StageAgendaPage> {
  List<Stage> stages = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchStages();
  }

  Future<void> fetchStages() async {
    // IMPORTANT: CHANGE THIS URL BASED ON YOUR DEVICE
    // Android Emulator: 'http://10.0.2.2:3000/api/stages'
    // iOS Simulator:    'http://localhost:3000/api/stages'
    // Physical Phone:   'http://YOUR_PC_IP:3000/api/stages'
    const String url = 'https://mern-back-stage-aikido.vercel.app/api/stages'; 

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        setState(() {
          stages = body.map((item) => Stage.fromJson(item)).toList();
          isLoading = false;
        });
      } else {
        print("Server Error: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Connection Error: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda 2025-2026', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : GroupedListView<Stage, String>(
              elements: stages,
              groupBy: (element) => DateFormat('yyyy-MM').format(element.date),
              groupSeparatorBuilder: (String groupByValue) {
                DateTime date = DateFormat('yyyy-MM').parse(groupByValue);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    DateFormat('MMMM yyyy').format(date).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                );
              },
              itemBuilder: (context, Stage stage) => AgendaItem(stage: stage),
              itemComparator: (item1, item2) => item1.date.compareTo(item2.date), // Sort dates
              useStickyGroupSeparators: true,
              floatingHeader: true,
              order: GroupedListOrder.ASC, // Oldest date at top
            ),
    );
  }
}

class AgendaItem extends StatelessWidget {
  final Stage stage;
  const AgendaItem({super.key, required this.stage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date
          Column(
            children: [
              Text(
                DateFormat('dd').format(stage.date),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                DateFormat('E').format(stage.date).toUpperCase(),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stage.stageName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(stage.place, style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
          ),
          // Dept Bubble
          Container(
             margin: const EdgeInsets.only(left: 8),
             padding: const EdgeInsets.all(6),
             decoration: BoxDecoration(
               color: Colors.blue.shade50,
               borderRadius: BorderRadius.circular(6)
             ),
             child: Text(stage.dept, style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
          )
        ],
      ),
    );
  }
}

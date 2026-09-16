import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:url_launcher/url_launcher.dart';

class Stage {
  final String id;
  final DateTime date;
  final String address;
  final String? link;
  final String stageName;
  final double cost;
  final String dept;

  Stage({
    required this.id,
    required this.date,
    required this.address,
    this.link,
    required this.stageName,
    required this.cost,
    required this.dept,
  });

  factory Stage.fromJson(Map<String, dynamic> json) {
    return Stage(
      id: json['_id'],
      date: DateTime.parse(json['date']),
      address: json['address'] ?? '',
      link: json['link'],
      stageName: json['stageName'] ?? '',
      cost: json['cost'] != null ? (json['cost'] as num).toDouble() : 0.0,
      dept: json['dept'] ?? '',
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
              itemComparator: (item1, item2) => item1.date.compareTo(item2.date),
              useStickyGroupSeparators: true,
              floatingHeader: true,
              order: GroupedListOrder.ASC,
            ),
    );
  }
}

class AgendaItem extends StatelessWidget {
  final Stage stage;

  const AgendaItem({super.key, required this.stage});

  // Helper method to format address into a single line (Rue, Ville)
  String _formatSingleLineAddress(String fullAddress) {
    if (fullAddress.isEmpty) return '';
    
    List<String> parts = fullAddress
        .split(RegExp(r'[,\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (parts.isEmpty) return fullAddress;
    
    if (parts.length >= 2) {
      return '${parts[0]}, ${parts[1]}';
    }
    return parts[0];
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

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
                
                // Address Row (Single line, truncated with ellipsis if long)
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _formatSingleLineAddress(stage.address),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ),
                  ],
                ),

                // Link Row
                if (stage.link != null && stage.link!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _launchURL(stage.link!),
                    child: Row(
                      children: [
                        const Icon(Icons.link, size: 14, color: Colors.indigo),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            stage.link!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.indigo,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Price & Dept Badges
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cost Bubble
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${stage.cost.toStringAsFixed(2)} €',
                  style: TextStyle(
                    color: Colors.green.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),

              // Dept Bubble
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  stage.dept,
                  style: TextStyle(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
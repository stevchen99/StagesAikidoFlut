import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:url_launcher/url_launcher.dart';

class Enseignant {
  final String firstName;
  final String lastName;

  Enseignant({required this.firstName, required this.lastName});

  factory Enseignant.fromJson(Map<String, dynamic> json) {
    return Enseignant(
      firstName: json['firstName']?.toString() ?? json['prenom']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? json['nom']?.toString() ?? '',
    );
  }

  String get fullName => '$firstName $lastName'.trim();
}

class Stage {
  final String id;
  final DateTime date;
  final String address;
  final String? link;
  final String stageName;
  final double cost;
  final String dept;
  final List<Enseignant> enseignants;

  Stage({
    required this.id,
    required this.date,
    required this.address,
    this.link,
    required this.stageName,
    required this.cost,
    required this.dept,
    required this.enseignants,
  });

  factory Stage.fromJson(Map<String, dynamic> json) {
    // Parse teachers array safely
    final List<dynamic> enseignantsList = (json['enseignants'] as List<dynamic>?) ?? [];
    final List<Enseignant> parsedEnseignants = enseignantsList
        .where((item) => item is Map)
        .map((item) => Enseignant.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();

    // Extract raw date field prioritizing dateDebut then date
    dynamic rawDate = json['dateDebut'] ?? json['date'];

    // Handle Mongoose / MongoDB nested date objects like {"$date": "2025-10-12T00:00:00Z"}
    if (rawDate is Map) {
      rawDate = rawDate['\$date'] ?? rawDate['date'];
    }

    DateTime parsedDate = DateTime.now();

    if (rawDate != null) {
      String dateStr = rawDate.toString().trim();

      // Handle DD/MM/YYYY or DD-MM-YYYY formats from French APIs
      if (RegExp(r'^\d{2}[/-]\d{2}[/-]\d{4}').hasMatch(dateStr)) {
        try {
          List<String> parts = dateStr.contains('/') ? dateStr.split('/') : dateStr.split('-');
          int day = int.parse(parts[0]);
          int month = int.parse(parts[1]);
          int year = int.parse(parts[2].substring(0, 4));
          parsedDate = DateTime(year, month, day);
        } catch (_) {}
      } 
      // Handle standard ISO-8601 strings or Milliseconds
      else {
        parsedDate = DateTime.tryParse(dateStr) ?? 
            (rawDate is int ? DateTime.fromMillisecondsSinceEpoch(rawDate) : DateTime.now());
      }
    }

    return Stage(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? UniqueKey().toString(),
      date: parsedDate,
      address: json['adresseComplete']?.toString() ?? json['address']?.toString() ?? json['place']?.toString() ?? '',
      link: json['url']?.toString() ?? json['link']?.toString(),
      stageName: json['titre']?.toString() ?? json['stageName']?.toString() ?? '',
      cost: json['cost'] != null ? (json['cost'] as num).toDouble() : 0.0,
      dept: json['dept']?.toString() ?? json['departement']?.toString() ?? '',
      enseignants: parsedEnseignants,
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
    const String primaryApiUrl = 'https://mern-back-stage-aikido.vercel.app/api/stages';
    const String secondaryApiUrl = 'https://api.stages-aikido.fr/public/stages';

    try {
      final responses = await Future.wait([
        http.get(Uri.parse(primaryApiUrl)).catchError((_) => http.Response('[]', 500)),
        http.get(Uri.parse(secondaryApiUrl)).catchError((_) => http.Response('[]', 500)),
      ]);

      List<Stage> combinedStages = [];

      // Primary API
      if (responses[0].statusCode == 200) {
        dynamic decoded1 = jsonDecode(responses[0].body);
        if (decoded1 is List) {
          for (var item in decoded1) {
            if (item is Map) {
              combinedStages.add(Stage.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
      }

      // Secondary API (FFAB only)
      if (responses[1].statusCode == 200) {
        dynamic decoded2 = jsonDecode(responses[1].body);
        if (decoded2 is List) {
          for (var item in decoded2) {
            if (item is Map && item['federation'] == 'FFAB') {
              combinedStages.add(Stage.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
      }

      setState(() {
        stages = combinedStages;
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching stages: $e");
      }
    } finally {
      setState(() {
        isLoading = false;
      });
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
          : stages.isEmpty
              ? const Center(child: Text('Aucun stage disponible'))
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

  Future<void> _openMap(BuildContext context, String address) async {
    if (address.isEmpty) return;

    final String encodedAddress = Uri.encodeComponent(address);
    final Uri mapUri;

    final TargetPlatform platform = Theme.of(context).platform;

    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      mapUri = Uri.parse('https://maps.apple.com/?q=$encodedAddress');
    } else {
      mapUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');
    }

    if (await canLaunchUrl(mapUri)) {
      await launchUrl(mapUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedAddress = _formatSingleLineAddress(stage.address);
    final firstTeacher = stage.enseignants.isNotEmpty ? stage.enseignants.first.fullName : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Column
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

          // Stage Info Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  stage.stageName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),

                // 1st Enseignant
                if (firstTeacher != null && firstTeacher.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.grey.shade700),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          firstTeacher,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 4),

                // Map Address
                if (stage.address.isNotEmpty)
                  InkWell(
                    onTap: () => _openMap(context, stage.address),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.indigo.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            formattedAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: TextStyle(
                              color: Colors.indigo.shade600,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Right Column: Price, Dept, Inscription Link
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cost Bubble
                  if (stage.cost > 0)
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
                  if (stage.dept.isNotEmpty)
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

              // Inscription Link (Bottom Right)
              if (stage.link != null && stage.link!.isNotEmpty) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _launchURL(stage.link!),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link, size: 14, color: Colors.indigo),
                      SizedBox(width: 4),
                      Text(
                        'Inscription',
                        style: TextStyle(
                          color: Colors.indigo,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
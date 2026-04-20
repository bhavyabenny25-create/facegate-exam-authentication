import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api.dart';

class AdminViewDetailsScreen extends StatefulWidget {
  const AdminViewDetailsScreen({super.key});

  @override
  State<AdminViewDetailsScreen> createState() => _AdminViewDetailsScreenState();
}

class _AdminViewDetailsScreenState extends State<AdminViewDetailsScreen> {
  // Brand Colors
  final Color primaryColor = const Color(0xFF56054A);
  final Color secondaryColor = const Color(0xFFD1C4E9);

  List allData = [];
  Map<String, List> filteredGroupedData = {};
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchMasterData();
  }

  Future<void> fetchMasterData() async {
    try {
      final res = await http.get(Uri.parse("${Api.baseUrl}/admin-master-view"));
      if (res.statusCode == 200) {
        List data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            allData = data;
            _groupData(data);
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> syncAllVisibleExams() async {
    setState(() => isLoading = true);
    try {
      Set<int> examIds = allData
          .map((e) => int.tryParse(e['exam_id']?.toString() ?? '0') ?? 0)
          .where((id) => id != 0)
          .toSet();

      for (int id in examIds) {
        await http.post(Uri.parse("${Api.baseUrl}/sync-exam-absentees/$id"));
      }

      await fetchMasterData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All absentees recorded successfully!")),
        );
      }
    } catch (e) {
      debugPrint("Sync Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _groupData(List data) {
    Map<String, List> groups = {};
    for (var item in data) {
      String exam = item['exam_name']?.toString() ?? "Archived Exam";
      if (!groups.containsKey(exam)) {
        groups[exam] = [];
      }
      groups[exam]!.add(item);
    }

    if (mounted) {
      setState(() {
        filteredGroupedData = groups;
      });
    }
  }

  void filterSearch(String query) {
    final searchLower = query.toLowerCase().trim();

    if (searchLower.isEmpty) {
      _groupData(allData);
      return;
    }

    List filteredList = allData.where((item) {
      final name = (item['name'] ?? "").toString().toLowerCase();
      final reg = (item['reg_no'] ?? "").toString().toLowerCase();
      final exam = (item['exam_name'] ?? "").toString().toLowerCase();
      final staff = (item['staff_name'] ?? "").toString().toLowerCase();

      return name.contains(searchLower) ||
          reg.contains(searchLower) ||
          exam.contains(searchLower) ||
          staff.contains(searchLower);
    }).toList();

    _groupData(filteredList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Master Exam Report", style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Record Absentees Now",
            onPressed: syncAllVisibleExams,
            icon: const Icon(Icons.sync_problem),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchMasterData,
          )
        ],
      ),
      body: Column(
        children: [
          // Header Search Section
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: TextField(
              controller: searchController,
              onChanged: filterSearch,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search student, exam, or staff...",
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white70),
                    onPressed: () {
                      searchController.clear();
                      filterSearch("");
                    })
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          isLoading
              ? Expanded(child: Center(child: CircularProgressIndicator(color: primaryColor)))
              : Expanded(
            child: RefreshIndicator(
              color: primaryColor,
              onRefresh: fetchMasterData,
              child: filteredGroupedData.isEmpty
                  ? const Center(child: Text("No records found", style: TextStyle(color: Colors.grey)))
                  : ListView(
                padding: const EdgeInsets.all(16),
                children: filteredGroupedData.keys.map((examName) {
                  List students = filteredGroupedData[examName]!;
                  String displayDate = students.isNotEmpty
                      ? (students[0]['exam_date'] ?? "N/A")
                      : "N/A";

                  int presentCount = students
                      .where((s) => s['status'].toString().toUpperCase() == 'PRESENT')
                      .length;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 25),
                    elevation: 4,
                    shadowColor: primaryColor.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Group Header
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: secondaryColor.withOpacity(0.3),
                            border: Border(bottom: BorderSide(color: secondaryColor)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(examName,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                            fontSize: 16)),
                                    Text("Date: $displayDate",
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: primaryColor.withOpacity(0.7))),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "P: $presentCount / T: ${students.length}",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              )
                            ],
                          ),
                        ),
                        // Data Table Section
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 25,
                            headingRowHeight: 45,
                            headingTextStyle: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            columns: const [
                              DataColumn(label: Text('Student')),
                              DataColumn(label: Text('Dept/Sem')),
                              DataColumn(label: Text('Center/Room')),
                              DataColumn(label: Text('Staff')),
                              DataColumn(label: Text('Status')),
                            ],
                            rows: students.map((s) {
                              String status = s['status'].toString().toUpperCase();
                              return DataRow(cells: [
                                DataCell(Text("${s['name']}\n${s['reg_no']}",
                                    style: const TextStyle(fontSize: 11))),
                                DataCell(Text("${s['student_dept']}\nSem: ${s['semester']}",
                                    style: const TextStyle(fontSize: 11))),
                                DataCell(Text("${s['exam_center']}\n${s['classroom']} (S: ${s['seat_no']})",
                                    style: const TextStyle(fontSize: 11))),
                                DataCell(Text("${s['staff_name']}\n${s['staff_dept']}",
                                    style: const TextStyle(fontSize: 11))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (status == 'PRESENT' ? Colors.green : Colors.red).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: status == 'PRESENT' ? Colors.green[700] : Colors.red[700],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
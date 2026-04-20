import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'allocation_details_screen.dart';
import 'api.dart';

class ExamListScreen extends StatefulWidget {
  const ExamListScreen({super.key});

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  List exams = [];
  bool isLoading = true;

  // 🎨 Deep Plum Theme (UI Only)
  final Color primaryLavender = const Color(0xFF56054A); // Deep Plum
  final Color softLavender = const Color(0xFFF3EDF9);
  final Color lightLavender = const Color(0xFFE6E1FF);

  @override
  void initState() {
    super.initState();
    fetchExams();
  }

  Future<void> fetchExams() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse("${Api.baseUrl}/admin/exams"));
      if (res.statusCode == 200) {
        setState(() {
          exams = jsonDecode(res.body);
          isLoading = false;
        });
      } else {
        final errorMsg = jsonDecode(res.body)['error'] ?? "Failed to load";
        throw errorMsg;
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> deleteExam(int examId) async {
    try {
      final res = await http.delete(Uri.parse("${Api.baseUrl}/admin/delete-exam/$examId"));
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Exam deleted successfully"), backgroundColor: Colors.green),
        );
        fetchExams();
      } else {
        throw "Failed to delete";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> runAllocation(int examId, String status, String subjectName) async {
    if (status == "allocated") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AllocationDetailsScreen(
            examId: examId,
            subjectName: subjectName,
          ),
        ),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final res = await http.post(Uri.parse("${Api.baseUrl}/admin/allocate/$subjectName"));
      if (res.statusCode == 200) {
        await fetchExams();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Allocation Successful!"), backgroundColor: Colors.green),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AllocationDetailsScreen(
              examId: examId,
              subjectName: subjectName,
            ),
          ),
        );
      } else {
        throw jsonDecode(res.body)['error'] ?? "Allocation failed";
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Exam Management",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: primaryLavender,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: fetchExams,
            icon: const Icon(Icons.refresh, color: Colors.white),
          )
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryLavender))
          : exams.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "No exams scheduled",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryLavender,
                foregroundColor: Colors.white,
              ),
              onPressed: fetchExams,
              child: const Text("Refresh List"),
            ),
          ],
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(8.0),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingRowColor: WidgetStateProperty.all(lightLavender),
                columns: const [
                  DataColumn(label: Text('Subject Name')),
                  DataColumn(label: Text('Subject Code')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Dept')),
                  DataColumn(label: Text('Sem')),
                  DataColumn(label: Text('Students')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Action')),
                  DataColumn(label: Text('Delete')),
                ],
                rows: exams.map((exam) {
                  bool isAllocated = exam['status'] == "allocated";
                  String currentSubjectName = exam['subject_name'] ?? 'N/A';

                  return DataRow(cells: [
                    DataCell(Text(currentSubjectName)),
                    DataCell(Text(exam['subject_code'] ?? 'N/A')),
                    DataCell(Text(exam['date'] ?? '')),
                    DataCell(Text(exam['dept'] ?? 'N/A')),
                    DataCell(Text(exam['sem'].toString())),
                    DataCell(Center(child: Text(exam['total_students'].toString()))),

                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isAllocated
                            ? const Color(0xFFE8F5E9)
                            : softLavender,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isAllocated ? "Allocated" : "Not Allocated",
                        style: TextStyle(
                          color: isAllocated
                              ? Colors.green[800]
                              : primaryLavender,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    )),

                    DataCell(
                      ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(primaryLavender),
                          foregroundColor: WidgetStateProperty.all(Colors.white),
                          overlayColor: WidgetStateProperty.all(
                            primaryLavender.withOpacity(0.2),
                          ), // removes blue splash
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          elevation: WidgetStateProperty.all(0),
                        ),
                        onPressed: () => runAllocation(
                            exam['id'],
                            exam['status'],
                            currentSubjectName),
                        child: Text(
                            isAllocated ? "View Allocation" : "Allocate"),
                      ),
                    ),

                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.delete_forever,
                            color: Colors.redAccent),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(10)),
                              title: const Text("Delete Exam?"),
                              content: const Text(
                                  "This will permanently remove this exam entry."),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx),
                                  child: Text("Cancel",
                                      style: TextStyle(
                                          color: primaryLavender)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    deleteExam(exam['id']);
                                  },
                                  child: const Text("Delete",
                                      style:
                                      TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
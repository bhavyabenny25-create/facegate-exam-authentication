import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api.dart';

class AddSemesterScreen extends StatefulWidget {
  final int studentId;
  const AddSemesterScreen({super.key, required this.studentId});

  @override
  State<AddSemesterScreen> createState() => _AddSemesterScreenState();
}

class _AddSemesterScreenState extends State<AddSemesterScreen> {
  // Define the brand colors
  final Color primaryColor = const Color(0xFF56054A);
  final Color secondaryColor = const Color(0xFFD1C4E9);

  final semesterController = TextEditingController();
  final subjectNameController = TextEditingController();
  final subjectCodeController = TextEditingController();
  final examDateController = TextEditingController();
  final examCenterController = TextEditingController();
  final departmentController = TextEditingController();

  List existingSubjects = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchStudentSubjects();
  }

  Future<void> fetchStudentSubjects() async {
    try {
      final response = await http.get(
        Uri.parse("${Api.baseUrl}/get-student-subjects/${widget.studentId}"),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            existingSubjects = jsonDecode(response.body);
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> saveSemesterDetails() async {
    try {
      final response = await http.post(
        Uri.parse("${Api.baseUrl}/add-semester-subject/${widget.studentId}"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "semester": semesterController.text,
          "subject_name": subjectNameController.text,
          "subject_code": subjectCodeController.text,
          "exam_date": examDateController.text,
          "exam_center": examCenterController.text,
          "department": departmentController.text,
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Semester details added!")),
        );
        semesterController.clear();
        subjectNameController.clear();
        subjectCodeController.clear();
        examDateController.clear();
        examCenterController.clear();
        departmentController.clear();
        fetchStudentSubjects();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> deleteSubject(String subjectCode) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Subject"),
        content: Text("Are you sure you want to remove $subjectCode?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await http.delete(
          Uri.parse("${Api.baseUrl}/delete-student-subject/${widget.studentId}/$subjectCode"),
        );
        if (res.statusCode == 200) {
          fetchStudentSubjects();
        }
      } catch (e) {
        debugPrint("Delete error: $e");
      }
    }
  }

  Widget buildTextField(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryColor), // Changed to Primary Color
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFE),
      appBar: AppBar(
        title: const Text("Semester Management", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor, // Changed to Primary Color
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              width: double.infinity,
              decoration: BoxDecoration(
                color: primaryColor, // Changed to Primary Color
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 5,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: buildTextField(semesterController, "Sem", Icons.school)),
                          const SizedBox(width: 8),
                          Expanded(child: buildTextField(departmentController, "Dept", Icons.business)),
                        ],
                      ),
                      buildTextField(subjectNameController, "Subject Name", Icons.book),
                      buildTextField(subjectCodeController, "Subject Code", Icons.code),
                      buildTextField(examDateController, "Date (YYYY-MM-DD)", Icons.calendar_month),
                      buildTextField(examCenterController, "Exam Center", Icons.location_on),
                      ElevatedButton.icon(
                        onPressed: saveSemesterDetails,
                        icon: const Icon(Icons.add_task),
                        label: const Text("Save Subject"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor, // Changed to Primary Color
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.list_alt, color: primaryColor), // Changed to Primary Color
                  const SizedBox(width: 8),
                  const Text("Your Registered Subjects", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            isLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: existingSubjects.length,
              itemBuilder: (context, index) {
                final item = existingSubjects[index];

                String rawDate = item['exam_date']?.toString() ?? "";
                String cleanDate = "";

                if (rawDate.contains(',')) {
                  String afterComma = rawDate.split(',').last.trim();
                  cleanDate = afterComma.length >= 11 ? afterComma.substring(0, 11) : afterComma;
                }
                else if (rawDate.length >= 10) {
                  cleanDate = rawDate.substring(0, 10);
                } else {
                  cleanDate = rawDate;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: secondaryColor, // Changed to Secondary Color
                      child: Text(item['semester'].toString(), style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(item['subject_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Code: ${item['subject_code']}\nDate: $cleanDate"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                      onPressed: () => deleteSubject(item['subject_code']),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
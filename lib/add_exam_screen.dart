import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api.dart';

class AddExamScreen extends StatefulWidget {
  const AddExamScreen({super.key});

  @override
  State<AddExamScreen> createState() => _AddExamScreenState();
}

class _AddExamScreenState extends State<AddExamScreen> {
  // Brand Colors
  final Color primaryColor = const Color(0xFF56054A);
  final Color secondaryColor = const Color(0xFFD1C4E9);

  final subjectCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  final dateCtrl = TextEditingController();
  final deptCtrl = TextEditingController();
  final semCtrl = TextEditingController();

  Future<void> saveExam() async {
    if (subjectCtrl.text.isEmpty ||
        codeCtrl.text.isEmpty ||
        dateCtrl.text.isEmpty ||
        deptCtrl.text.isEmpty ||
        semCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    try {
      final res = await http.post(
        Uri.parse("${Api.baseUrl}/admin/add-exam"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "subject_name": subjectCtrl.text.trim(),
          "subject_code": codeCtrl.text.trim(),
          "exam_date": dateCtrl.text,
          "department": deptCtrl.text.trim(),
          "semester": semCtrl.text.trim(),
        }),
      );

      if (res.statusCode == 201) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Exam Added Successfully")));
      } else {
        final errorBody = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${errorBody['error'] ?? res.statusCode}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Connection failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Keep background pure white for a clean look
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Add Exam", style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header design element
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Create New Exam",
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 5),
                  Text("Enter details to schedule the arrangement",
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                shadowColor: primaryColor.withOpacity(0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: subjectCtrl,
                        label: "Subject Name",
                        hint: "e.g. Data Structures",
                        icon: Icons.book_outlined,
                      ),
                      const SizedBox(height: 15),
                      _buildTextField(
                        controller: codeCtrl,
                        label: "Subject Code",
                        hint: "e.g. DS101",
                        icon: Icons.code,
                      ),
                      const SizedBox(height: 15),
                      _buildTextField(
                        controller: dateCtrl,
                        label: "Exam Date",
                        hint: "Select Date",
                        icon: Icons.calendar_today,
                        readOnly: true,
                        onTap: () async {
                          DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(primary: primaryColor),
                                  ),
                                  child: child!,
                                );
                              });
                          if (picked != null) {
                            setState(() => dateCtrl.text = picked.toString().split(' ')[0]);
                          }
                        },
                      ),
                      const SizedBox(height: 15),
                      _buildTextField(
                        controller: deptCtrl,
                        label: "Department",
                        hint: "e.g. BCA",
                        icon: Icons.business,
                      ),
                      const SizedBox(height: 15),
                      _buildTextField(
                        controller: semCtrl,
                        label: "Semester",
                        hint: "Enter 1 for S1, 2 for S2, etc.",
                        icon: Icons.school_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: saveExam,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 5,
                          ),
                          child: const Text("Calculate & Save Exam",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method for consistent beautiful text fields
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryColor),
        labelStyle: TextStyle(color: primaryColor.withOpacity(0.8)),
        filled: true,
        fillColor: secondaryColor.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }
}
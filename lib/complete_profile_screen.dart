import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String baseUrl = "http://192.168.147.85:5000";

class CompleteProfileScreen extends StatefulWidget {
  final int userId;

  const CompleteProfileScreen({
    super.key,
    required this.userId, required studentId,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final TextEditingController deptCtrl = TextEditingController();
  final TextEditingController dobCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();

  String courseType = "regular";
  bool submitting = false;

  Future<void> submit() async {
    if (deptCtrl.text.isEmpty ||
        dobCtrl.text.isEmpty ||
        phoneCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => submitting = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/student/complete-profile"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": widget.userId,
          "department": deptCtrl.text.trim(),
          "course_type": courseType,
          "date_of_birth": dobCtrl.text.trim(),
          "phone": phoneCtrl.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context, true); // ✅ return success
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? "Failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Complete Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: deptCtrl,
              decoration: const InputDecoration(labelText: "Department"),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: courseType,
              items: const [
                DropdownMenuItem(value: "regular", child: Text("Regular")),
                DropdownMenuItem(value: "supplementary", child: Text("Supplementary")),
              ],
              onChanged: (v) => setState(() => courseType = v!),
              decoration: const InputDecoration(labelText: "Course Type"),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: dobCtrl,
              readOnly: true,
              decoration: const InputDecoration(labelText: "Date of Birth"),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2000),
                  firstDate: DateTime(1960),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  dobCtrl.text =
                  "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                }
              },
            ),
            const SizedBox(height: 10),

            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "Phone Number"),
            ),
            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: submitting ? null : submit,
              child: submitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Save Profile"),
            ),
          ],
        ),
      ),
    );
  }
}
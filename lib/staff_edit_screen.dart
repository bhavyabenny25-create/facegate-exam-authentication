import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api.dart';
import 'admit_card_screen.dart';

class StaffEditScreen extends StatefulWidget {
  final int userId;
  const StaffEditScreen({super.key, required this.userId});

  @override
  State<StaffEditScreen> createState() => _StaffEditScreenState();
}

class _StaffEditScreenState extends State<StaffEditScreen> {
  // Brand Colors
  final Color primaryColor = const Color(0xFF56054A);
  final Color secondaryColor = const Color(0xFFD1C4E9);
  final Color bgColor = const Color(0xFFFBFBFE);

  final TextEditingController noteController = TextEditingController();
  Map? roomData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    noteController.addListener(() {
      if (mounted) setState(() {});
    });
    fetchData();
  }

  // --- LOGIC PRESERVED ---
  Future<void> fetchData() async {
    try {
      final res = await http.get(Uri.parse("${Api.baseUrl}/staff-room-students/${widget.userId}"));
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            roomData = jsonDecode(res.body);
            if (roomData?['notes'] != null) {
              noteController.text = roomData!['notes'].toString();
            } else {
              noteController.clear();
            }
            isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> saveNotes() async {
    try {
      final res = await http.post(
        Uri.parse("${Api.baseUrl}/update-staff-notes"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": widget.userId,
          "notes": noteController.text,
        }),
      );

      if (res.statusCode == 200) {
        await fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Notes updated successfully ✅")),
          );
          FocusScope.of(context).unfocus();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to save notes ❌")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Server error. Please try again.")),
        );
      }
    }
  }
  // --- END LOGIC ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Edit Attendance", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
        children: [
          // Top Legend/Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            color: primaryColor.withOpacity(0.05),
            child: Row(
              children: [
                Icon(Icons.people_outline, color: primaryColor, size: 20),
                const SizedBox(width: 10),
                const Text(
                  "Student Roster",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Text(
                  "${roomData?['students']?.length ?? 0} Total",
                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: roomData?['students']?.length ?? 0,
              itemBuilder: (context, i) {
                var s = roomData!['students'][i];
                bool isPresent = s['status']?.toString().toLowerCase() == 'present';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: isPresent ? Colors.green.shade50 : Colors.red.shade50,
                      child: Icon(
                        isPresent ? Icons.check_circle : Icons.cancel,
                        color: isPresent ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(
                      s['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(
                      "Reg: ${s['register_number']}",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    trailing: Icon(Icons.chevron_right, color: primaryColor.withOpacity(0.4)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdmitCardScreen(
                            userId: 0,
                            regNo: s['register_number'],
                            subjectName: s['exam_name'],
                            allocationId: s['allocation_id'],
                            isEditMode: true,
                          ),
                        ),
                      ).then((_) => fetchData());
                    },
                  ),
                );
              },
            ),
          ),

          // Bottom Management Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Room Notes",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: "Add room description or illness notes...",
                    fillColor: bgColor,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: noteController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.redAccent),
                      onPressed: () => _confirmDelete(),
                    )
                        : null,
                  ),
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: saveNotes,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Save Room Updates",
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Clear Notes?"),
        content: const Text("This will permanently remove the notes from the system."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                noteController.clear();
              });
              saveNotes();
            },
            child: const Text("Clear", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }
}
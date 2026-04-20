import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api.dart';

class AllocationDetailsScreen extends StatefulWidget {
  final int examId;
  final String subjectName;

  const AllocationDetailsScreen({
    super.key,
    required this.examId,
    required this.subjectName,
  });

  @override
  State<AllocationDetailsScreen> createState() => _AllocationDetailsScreenState();
}

class _AllocationDetailsScreenState extends State<AllocationDetailsScreen> {
  List details = [];
  bool isLoading = true;

  // 🎨 Plum Colors
  final Color primaryPlum = const Color(0xFF56054A);
  final Color accentPlum = const Color(0xFF7B1FA2);

  @override
  void initState() {
    super.initState();
    fetchDetails();
  }

  Future<void> fetchDetails() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse("${Api.baseUrl}/admin/allocation-details/${widget.subjectName}"),
      );
      if (res.statusCode == 200) {
        setState(() => details = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint("Error fetching details: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _editRoomStaff(String roomName, String currentStaffName) {
    TextEditingController controller = TextEditingController(text: currentStaffName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Update Staff for $roomName"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "This will change the staff for ALL students in this room.",
              style: TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "New Staff Name",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: primaryPlum)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPlum,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                final response = await http.post(
                  Uri.parse("${Api.baseUrl}/admin/update-room-staff"),
                  body: jsonEncode({
                    "room_name": roomName,
                    "subject_name": widget.subjectName,
                    "new_staff_name": controller.text,
                  }),
                  headers: {"Content-Type": "application/json"},
                );

                if (response.statusCode == 200) {
                  if (mounted) Navigator.pop(ctx);
                  fetchDetails();
                } else {
                  debugPrint("Update failed: ${response.body}");
                }
              } catch (e) {
                debugPrint("Error updating staff: $e");
              }
            },
            child: const Text("Update Room"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subjectName),
        backgroundColor: primaryPlum,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryPlum))
          : Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: accentPlum.withOpacity(0.1),
            child: Row(
              children: [
                Icon(Icons.group, color: primaryPlum),
                const SizedBox(width: 10),
                Text(
                  "Total Students: ${details.length}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: details.isEmpty
                ? const Center(child: Text("No students allocated yet."))
                : ListView.builder(
              itemCount: details.length,
              itemBuilder: (context, i) {
                final item = details[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: primaryPlum,
                      child: Text(
                        "${i + 1}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      item['student_name'] ?? 'Unnamed',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text("Room: ${item['room_name']} | Seat: ${item['seat_number']}"),
                        Text(
                          "Staff: ${item['staff_name']}",
                          style: TextStyle(
                            color: accentPlum,
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.edit_note, color: primaryPlum),
                      onPressed: () => _editRoomStaff(
                        item['room_name'],
                        item['staff_name'] ?? "",
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
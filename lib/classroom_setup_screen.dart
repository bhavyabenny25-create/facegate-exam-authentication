import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api.dart';

class ClassroomSetupScreen extends StatefulWidget {
  const ClassroomSetupScreen({super.key});

  @override
  State<ClassroomSetupScreen> createState() => _ClassroomSetupScreenState();
}

class _ClassroomSetupScreenState extends State<ClassroomSetupScreen> {
  // Brand Colors
  final Color primaryColor = const Color(0xFF56054A);
  final Color secondaryColor = const Color(0xFFD1C4E9);

  final roomCtrl = TextEditingController();
  final capacityCtrl = TextEditingController();
  List rooms = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchRooms();
  }

  Future<void> fetchRooms() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse("${Api.baseUrl}/admin/classrooms"));
      if (res.statusCode == 200) {
        setState(() => rooms = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint("Fetch error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> addRoom() async {
    if (roomCtrl.text.isEmpty || capacityCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    try {
      final res = await http.post(
        Uri.parse("${Api.baseUrl}/admin/add-classroom"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "room_number": roomCtrl.text.trim().toUpperCase(),
          "capacity": int.parse(capacityCtrl.text),
        }),
      );

      if (res.statusCode == 201) {
        roomCtrl.clear();
        capacityCtrl.clear();
        fetchRooms();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Classroom added!")),
        );
      } else {
        final error = jsonDecode(res.body);
        throw error['error'] ?? "Failed to add room";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> toggleRoomStatus(int roomId, bool currentStatus) async {
    try {
      final res = await http.post(
        Uri.parse("${Api.baseUrl}/admin/toggle-classroom/$roomId"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"is_active": !currentStatus}),
      );
      if (res.statusCode == 200) {
        fetchRooms();
      }
    } catch (e) {
      debugPrint("Toggle error: $e");
    }
  }

  Future<void> deleteRoom(int roomId) async {
    try {
      final res = await http.delete(Uri.parse("${Api.baseUrl}/admin/delete-room/$roomId"));

      if (res.statusCode == 200) {
        fetchRooms();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Room deleted successfully")),
        );
      } else {
        final errorData = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${errorData['error']}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection error.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // This ensures the background is white even if the phone is in Dark Mode
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Classroom Setup", style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: secondaryColor.withOpacity(0.2), // Light lavender card background
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: secondaryColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    TextField(
                      controller: roomCtrl,
                      decoration: InputDecoration(
                        labelText: "Room Number",
                        labelStyle: TextStyle(color: primaryColor),
                        prefixIcon: Icon(Icons.meeting_room, color: primaryColor),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor.withOpacity(0.5))),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: capacityCtrl,
                      decoration: InputDecoration(
                        labelText: "Capacity",
                        labelStyle: TextStyle(color: primaryColor),
                        prefixIcon: Icon(Icons.people, color: primaryColor),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor.withOpacity(0.5))),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor, width: 2)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: addRoom,
                        child: const Text("Add Classroom", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : rooms.isEmpty
                ? const Center(child: Text("No classrooms added yet.", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: rooms.length,
              itemBuilder: (context, i) {
                final room = rooms[i];
                bool isActive = room['is_active'] ?? false;
                return Card(
                  color: secondaryColor.withOpacity(0.1),
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: secondaryColor.withOpacity(0.5)),
                  ),
                  child: ListTile(
                    title: Text("Room: ${room['room_number']}",
                        style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                    subtitle: Text("Capacity: ${room['capacity']} seats"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          activeColor: primaryColor,
                          value: isActive,
                          onChanged: (val) => toggleRoomStatus(room['id'], isActive),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _confirmDelete(room['id']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  void _confirmDelete(int roomId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text("Delete Room?", style: TextStyle(color: primaryColor)),
        content: const Text("Are you sure? This will fail if the room is currently used for an exam."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancel", style: TextStyle(color: primaryColor))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              deleteRoom(roomId);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}
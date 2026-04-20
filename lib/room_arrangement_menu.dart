import 'package:flutter/material.dart';
import 'classroom_setup_screen.dart';
import 'add_exam_screen.dart';
import 'exam_list_screen.dart';

class RoomArrangementMenu extends StatelessWidget {
  const RoomArrangementMenu({super.key});

  // Defining the custom colors locally
  final Color primaryColor = const Color(0xFF56054A);
  final Color secondaryColor = const Color(0xFFD1C4E9);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Room Arrangement"),
        // Changed from indigo to Primary Color
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _menuItem(context, "Classroom Setup", Icons.meeting_room, const ClassroomSetupScreen()),
          const SizedBox(height: 10),
          _menuItem(context, "Add Exam", Icons.note_add, const AddExamScreen()),
          const SizedBox(height: 10),
          _menuItem(context, "Exam List", Icons.assignment, const ExamListScreen()),
        ],
      ),
    );
  }

  Widget _menuItem(BuildContext context, String title, IconData icon, Widget screen) {
    return ListTile(
      // Icons now use the Primary Color
      leading: Icon(icon, color: primaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: primaryColor),
      // Changed tile color from grey to a subtle version of your Secondary Color
      tileColor: secondaryColor.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
    );
  }
}
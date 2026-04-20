import 'package:flutter/material.dart';
import 'admin_profile_screen.dart';
import 'pre_registration_screen.dart';
// 1. Make sure this import matches your filename exactly
import 'room_arrangement_menu.dart';
import 'admin_view_details_screen.dart';
class AdminDashboard extends StatelessWidget {
  final Map adminData;
  const AdminDashboard({super.key, required this.adminData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Control Panel"),
        backgroundColor: const Color(0xFF56054A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          children: [
            _adminTile(context, Icons.person, "Profile", Colors.blue,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminProfileScreen(adminData: adminData)))),

            _adminTile(context, Icons.how_to_reg, "Pre Registration", Colors.green,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PreRegistrationScreen()))),

            // 2. Updated this line to navigate to the Room Arrangement Menu
            _adminTile(context, Icons.grid_view, "Room Arrangement", Colors.orange,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomArrangementMenu()))),

            _adminTile(context, Icons.table_chart, "View Details", Colors.red,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminViewDetailsScreen()))),

          ],
        ),
      ),
    );
  }

  Widget _adminTile(BuildContext context, IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
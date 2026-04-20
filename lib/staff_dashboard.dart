import 'package:flutter/material.dart';
import 'staff_profile_screen.dart';
import 'staff_details_screen.dart';
import 'staff_edit_screen.dart';

class StaffDashboard extends StatelessWidget {
  final Map staffData;
  const StaffDashboard({super.key, required this.staffData});

  // Brand Colors
  final Color primaryColor = const Color(0xFF56054A);
  final Color secondaryColor = const Color(0xFFD1C4E9);
  final Color bgColor = const Color(0xFFFBFBFE);

  @override
  Widget build(BuildContext context) {
    final dynamic rawId = staffData['user_id'];

    // Error Handling UI
    if (rawId == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const Text("System Error"),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 16),
                Text(
                  "Authentication Error",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor),
                ),
                const SizedBox(height: 8),
                Text(
                  "User ID was not provided by the server.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final int userId = rawId is int ? rawId : int.parse(rawId.toString());

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Staff Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Elegant Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: secondaryColor,
                  child: Icon(Icons.person_pin, size: 50, color: primaryColor),
                ),
                const SizedBox(height: 12),
                Text(
                  "Welcome, ${staffData['name'] ?? 'Staff Member'}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  staffData['email'] ?? "Staff Portal",
                  style: TextStyle(color: secondaryColor.withOpacity(0.8), fontSize: 14),
                ),
              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  "Administrative Actions",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                _dashboardTile(
                  context,
                  Icons.account_circle_outlined,
                  "My Profile",
                  "View and manage your account",
                      () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => StaffProfileScreen(userId: userId)),
                  ),
                ),
                _dashboardTile(
                  context,
                  Icons.badge_outlined,
                  "Staff Details",
                  "Academic and employment info",
                      () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => StaffDetailsScreen(userId: userId)),
                  ),
                ),
                _dashboardTile(
                  context,
                  Icons.edit_note_rounded,
                  "Edit / Update",
                  "Modify your current information",
                      () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => StaffEditScreen(userId: userId)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardTile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: secondaryColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: primaryColor, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        trailing: Icon(Icons.chevron_right, color: primaryColor.withOpacity(0.5)),
        onTap: onTap,
      ),
    );
  }
}
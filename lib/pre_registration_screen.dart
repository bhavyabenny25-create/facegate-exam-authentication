import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api.dart';

class PreRegistrationScreen extends StatefulWidget {
  const PreRegistrationScreen({super.key});

  @override
  State<PreRegistrationScreen> createState() => _PreRegistrationScreenState();
}

class _PreRegistrationScreenState extends State<PreRegistrationScreen> {
  // Defining your custom colors
  final Color primaryColor = const Color(0xFF56054A);
  final Color secondaryColor = const Color(0xFFD1C4E9);

  List allUsers = [];
  List filteredUsers = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future fetchUsers() async {
    final res = await http.get(Uri.parse("${Api.baseUrl}/admin/all-users"));
    if (res.statusCode == 200) {
      setState(() {
        allUsers = jsonDecode(res.body);
        filteredUsers = allUsers;
      });
    }
  }

  void filterUsers(String query) {
    setState(() {
      filteredUsers = allUsers
          .where((user) =>
          user['name'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void showEditDialog(Map user) {
    final nameCtrl = TextEditingController(text: user['name']);
    final emailCtrl = TextEditingController(text: user['email']);
    final deptCtrl = TextEditingController(text: user['dept'] ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text("Edit ${user['role']}", style: TextStyle(color: primaryColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: "Name", labelStyle: TextStyle(color: primaryColor))),
            TextField(controller: emailCtrl, decoration: InputDecoration(labelText: "Email", labelStyle: TextStyle(color: primaryColor))),
            TextField(controller: deptCtrl, decoration: InputDecoration(labelText: "Department", labelStyle: TextStyle(color: primaryColor))),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: primaryColor))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () async {
              await http.post(
                Uri.parse("${Api.baseUrl}/admin/update-user"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                  "id": user['id'],
                  "role": user['role'],
                  "name": nameCtrl.text,
                  "email": emailCtrl.text,
                  "dept": deptCtrl.text,
                  "reg_no": user['reg_no'] ?? ""
                }),
              );
              Navigator.pop(context);
              fetchUsers();
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pre Registration List", style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // --- SEARCH BAR SECTION ---
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: searchController,
              onChanged: (value) => filterUsers(value),
              decoration: InputDecoration(
                hintText: "Search by name...",
                prefixIcon: Icon(Icons.search, color: primaryColor),
                filled: true,
                fillColor: secondaryColor.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: primaryColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // --- LIST SECTION ---
          Expanded(
            child: ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (context, i) {
                final u = filteredUsers[i];
                return ListTile(
                  leading: CircleAvatar(
                    // Using primary color for users and orange for staff
                    backgroundColor: u['role'] == "Staff" ? Colors.orange : primaryColor,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(u['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${u['role']} - ${u['dept'] ?? 'N/A'}"),
                  trailing: IconButton(
                    // Changed from blue to your primary color
                    icon: Icon(Icons.edit, color: primaryColor),
                    onPressed: () => showEditDialog(u),
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
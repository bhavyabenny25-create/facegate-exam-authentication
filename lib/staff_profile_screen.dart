import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'api.dart';

class StaffProfileScreen extends StatelessWidget {
  final int userId;
  const StaffProfileScreen({super.key, required this.userId});

  final Color primaryColor = const Color(0xFF56054A);
  final Color secondaryColor = const Color(0xFFD1C4E9);
  final Color bgColor = const Color(0xFFFBFBFE);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: FutureBuilder(
        future: http.get(Uri.parse("${Api.baseUrl}/staff-profile-full/$userId")),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.statusCode != 200) {
            return const Center(child: Text("Error loading profile"));
          }

          final d = jsonDecode(snapshot.data!.body);

          return SingleChildScrollView(
            child: Column(
              children: [
                // THE FIXED HEADER
                // THE FIXED HEADER
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 80, bottom: 40),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(40),
                          bottomRight: Radius.circular(40),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            (d['name'] ?? "Staff Member").toString().toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            d['department'] ?? "Academic Dept",
                            style: TextStyle(
                              color: secondaryColor.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Back Button (unchanged)
                    Positioned(
                      top: 45,
                      left: 10,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),

                // Details section remains the same
                _buildDetailsSection(d),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailsSection(Map d) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      child: Column(
        children: [
          _infoTile("Email Address", d['email'], Icons.email_outlined),
          _infoTile("Contact Number", d['phone'], Icons.phone_android_outlined),
          _infoTile("Department", d['department'], Icons.business_outlined),
          _infoTile("Date of Birth", d['date_of_birth'], Icons.cake_outlined),
        ],
      ),
    );
  }

  Widget _infoTile(String label, dynamic value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: ListTile(
        leading: Icon(icon, color: primaryColor),
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value?.toString() ?? "Not Provided",
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
    );
  }
}
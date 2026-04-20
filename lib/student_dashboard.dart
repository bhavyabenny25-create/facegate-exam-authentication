import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'api.dart';
import 'add_semester_screen.dart';
import 'exam_hall_screen.dart';
import 'admit_card_screen.dart';

class StudentDashboard extends StatefulWidget {
  final Map studentData;
  const StudentDashboard({super.key, required this.studentData});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  // Brand Colors
  final Color primaryColor = const Color(0xFF56054A);
  final Color secondaryColor = const Color(0xFFD1C4E9);
  final Color bgColor = const Color(0xFFFBFBFE);

  late bool isProfileCompleted;
  late int userId;
  String? profileImageUrl;

  final deptController = TextEditingController();
  final phoneController = TextEditingController();
  final dobController = TextEditingController();
  String selectedCourseType = "regular";

  @override
  void initState() {
    super.initState();
    isProfileCompleted = widget.studentData['profile_completed'] ?? false;
    profileImageUrl = widget.studentData['dashboard_pic'];
    userId = widget.studentData['student_id'] ??
        widget.studentData['user_id'] ??
        widget.studentData['id'] ?? 0;
  }

  // --- LOGIC PRESERVED ---
  Future<void> _updateProfilePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse("${Api.baseUrl}/upload-profile-pic/$userId"),
        );
        request.files.add(await http.MultipartFile.fromPath('file', image.path));
        var response = await request.send();
        if (response.statusCode == 200) {
          var resData = await http.Response.fromStream(response);
          var jsonRes = jsonDecode(resData.body);
          setState(() { profileImageUrl = jsonRes['path']; });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Picture Updated!")));
        }
      } catch (e) { debugPrint("Upload Error: $e"); }
    }
  }
  // --- END LOGIC ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          // Elegant Sleek Header
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryColor, primaryColor.withOpacity(0.8)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    _buildProfileImage(),
                    const SizedBox(height: 12),
                    Text(
                      (widget.studentData['name'] ?? "Student").toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      widget.studentData['email'] ?? "",
                      style: TextStyle(color: secondaryColor.withOpacity(0.7), fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        "ID: ${widget.studentData['register_number'] ?? "N/A"}",
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Quick Access",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2D3142)),
                  ),
                  const SizedBox(height: 4),
                  Container(width: 40, height: 3, decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 25),

                  // Refined Grid Layout
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          _buildModernCard(
                            context,
                            "Add Semester",
                            Icons.add_chart_rounded,
                            constraints.maxWidth / 2 - 10,
                                () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddSemesterScreen(studentId: userId))),
                          ),
                          _buildModernCard(
                            context,
                            "Exam Hall",
                            Icons.location_on_outlined,
                            constraints.maxWidth / 2 - 10,
                                () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamHallScreen(studentId: userId))),
                          ),
                          _buildModernCard(
                            context,
                            "Admit Card",
                            Icons.badge_outlined,
                            constraints.maxWidth / 2 - 10,
                                () {
                              if (userId == 0) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Valid ID not found.")));
                              } else {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => AdmitCardScreen(userId: userId)));
                              }
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 2),
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: secondaryColor,
            backgroundImage: profileImageUrl != null
                ? NetworkImage("${Api.baseUrl}/$profileImageUrl?${DateTime.now().millisecondsSinceEpoch}")
                : null,
            child: profileImageUrl == null ? Icon(Icons.person, size: 45, color: primaryColor) : null,
          ),
        ),
        GestureDetector(
          onTap: _updateProfilePicture,
          child: Container(
            height: 32, width: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
            child: Icon(Icons.edit, size: 16, color: primaryColor),
          ),
        ),
      ],
    );
  }

  Widget _buildModernCard(BuildContext context, String title, IconData icon, double width, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: secondaryColor.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: primaryColor, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D3142)),
            ),
          ],
        ),
      ),
    );
  }
}
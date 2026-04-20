import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'api.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Brand Colors
  final Color primaryColor = const Color(0xFF56054A);
  final Color secondaryColor = const Color(0xFFD1C4E9);

  String role = "student";

  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  final registerNumber = TextEditingController();
  final department = TextEditingController();
  final phone = TextEditingController();
  final dob = TextEditingController();

  File? photo;

  Future<void> pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        photo = File(pickedFile.path);
      });
    }
  }

  void register() async {
    if (password.text != confirmPassword.text) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    if (photo == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please select a photo")));
      return;
    }

    if (department.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Department is required")));
      return;
    }

    try {
      String endpoint = role == "student" ? "/register/student" : "/register/staff";

      var request = http.MultipartRequest(
        "POST",
        Uri.parse("${Api.baseUrl}$endpoint"),
      );

      request.fields.addAll({
        "name": name.text,
        "email": email.text,
        "password": password.text,
        "department": department.text,
      });

      if (role == "student") {
        request.fields["register_number"] = registerNumber.text;
      } else {
        request.fields["phone"] = phone.text;
        request.fields["dob"] = dob.text;
      }

      request.files.add(await http.MultipartFile.fromPath("photo", photo!.path));

      final response = await request.send();

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Registration Successful!")));
        Navigator.pop(context);
      } else {
        final resBody = await response.stream.bytesToString();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Registration failed: $resBody"))
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An error occurred: $e"))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Create Account", style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header Accent
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                const Text("Join the Portal",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                // Role Selector inside header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio(
                        value: "student",
                        groupValue: role,
                        onChanged: (v) => setState(() => role = v!),
                        activeColor: secondaryColor,
                      ),
                      const Text("Student", style: TextStyle(color: Colors.white)),
                      const SizedBox(width: 10),
                      Radio(
                        value: "staff",
                        groupValue: role,
                        onChanged: (v) => setState(() => role = v!),
                        activeColor: secondaryColor,
                      ),
                      const Text("Staff", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Photo Picker
                Center(
                  child: GestureDetector(
                    onTap: pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 55,
                          backgroundColor: secondaryColor,
                          child: CircleAvatar(
                            radius: 52,
                            backgroundColor: Colors.white,
                            backgroundImage: photo != null ? FileImage(photo!) : null,
                            child: photo == null
                                ? Icon(Icons.person_add_alt_1, size: 40, color: primaryColor)
                                : null,
                          ),
                        ),
                        PositionImagePlus(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                _buildInputField(name, "Full Name", Icons.person_outline),
                _buildInputField(email, "Email Address", Icons.email_outlined),
                _buildInputField(password, "Password", Icons.lock_outline, isPassword: true),
                _buildInputField(confirmPassword, "Confirm Password", Icons.lock_reset, isPassword: true),
                _buildInputField(department, "Department", Icons.business_outlined),

                if (role == "student")
                  _buildInputField(registerNumber, "Register Number", Icons.assignment_ind_outlined),

                if (role == "staff") ...[
                  _buildInputField(phone, "Phone Number", Icons.phone_android_outlined),
                  _buildInputField(dob, "Date of Birth (YYYY-MM-DD)", Icons.calendar_today_outlined),
                ],

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 4,
                    ),
                    child: const Text("Create Account",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget for consistent UI
  Widget _buildInputField(TextEditingController controller, String label, IconData icon, {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryColor),
          filled: true,
          fillColor: secondaryColor.withOpacity(0.1),
          labelStyle: TextStyle(color: primaryColor.withOpacity(0.7)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
        ),
      ),
    );
  }

  Widget PositionImagePlus() {
    return Positioned(
      bottom: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
        child: const Icon(Icons.add, color: Colors.white, size: 20),
      ),
    );
  }
}
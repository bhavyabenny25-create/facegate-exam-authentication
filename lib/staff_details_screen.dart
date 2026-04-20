import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'api.dart';

class StaffDetailsScreen extends StatefulWidget {
  final int userId;
  const StaffDetailsScreen({super.key, required this.userId});

  @override
  State<StaffDetailsScreen> createState() => _StaffDetailsScreenState();
}

class _StaffDetailsScreenState extends State<StaffDetailsScreen> {
  Map? roomData;
  bool isLoading = true;

  final Color darkPlum = const Color(0xFF56054A);
  final Color lightPlum = const Color(0xFFD1C4E9);

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      final res = await http.get(Uri.parse("${Api.baseUrl}/staff-room-students/${widget.userId}"));
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            roomData = jsonDecode(res.body);
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

  Future<void> _startFaceAuth(String targetRegNo, String studentName) async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 100,
      maxWidth: 1200,
    );

    if (photo == null) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text("Verify $studentName"),
        content: Text("Proceed to verify identity of $studentName?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _processRecognition(photo, targetRegNo);
              },
              child: const Text("Verify Now")
          )
        ],
      ),
    );
  }

  Future<void> _processRecognition(XFile photo, String regNo) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator())
    );

    try {
      final bytes = await photo.readAsBytes();
      String base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse("${Api.baseUrl}/verify-face-attendance"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "register_number": regNo,
          "image_base64": base64Image,
          "staff_id": widget.userId
        }),
      ).timeout(const Duration(seconds: 25));

      if (!mounted) return;
      Navigator.pop(context);

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['success'] == true) {
        _showStatusDialog("Verified ✅", result['message'], Colors.green);
        Future.delayed(const Duration(milliseconds: 500), () {
          fetchData();
        });
      } else {
        _showStatusDialog("Failed ❌", result['message'] ?? "Face mismatch", Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showStatusDialog("Error", "Server connection timed out.", Colors.orange);
    }
  }

  void _showStatusDialog(String title, String message, Color color) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
            title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            content: Text(message),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(roomData != null ? "Room: ${roomData!['room_name']}" : "Attendance List"),
        backgroundColor: darkPlum, // was blueGrey[900]
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: lightPlum, // was blueGrey[50]
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Invigilator In-Charge:",
                  style: TextStyle(fontSize: 12, color: darkPlum), // was blueGrey
                ),
                Text(
                  roomData?['staff_name'] ?? 'N/A',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: roomData?['students']?.length ?? 0,
              itemBuilder: (context, i) {
                var s = roomData!['students'][i];
                bool isPresent = s['status']?.toString().toLowerCase() == 'present';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  elevation: isPresent ? 0 : 3,
                  color: isPresent ? Colors.green[50] : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isPresent ? Colors.green : Colors.transparent, width: 1.5),
                  ),
                  child: ListTile(
                    onTap: isPresent ? null : () => _startFaceAuth(s['register_number'], s['name']),
                    leading: CircleAvatar(
                      backgroundColor: isPresent ? Colors.green : lightPlum, // was blueGrey[100]
                      child: isPresent
                          ? const Icon(Icons.check, color: Colors.white)
                          : Text(
                        s['seat_number'].toString(),
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                    title: Text(
                      s['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isPresent ? Colors.green[900] : Colors.black87,
                      ),
                    ),
                    subtitle: Text("Reg No: ${s['register_number']}\nSubject: ${s['exam_name']}"),
                    trailing: isPresent
                        ? const Icon(Icons.check_circle, color: Colors.green, size: 32)
                        : Icon(Icons.camera_alt_rounded, color: darkPlum), // was blue
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
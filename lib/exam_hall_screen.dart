import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api.dart';

class ExamHallScreen extends StatefulWidget {
  final int studentId;
  const ExamHallScreen({super.key, required this.studentId});

  @override
  State<ExamHallScreen> createState() => _ExamHallScreenState();
}

class _ExamHallScreenState extends State<ExamHallScreen> {
  List allStudents = [];
  List filteredStudents = [];
  bool isLoading = true;
  bool hasExam = true;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future fetchData() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse("${Api.baseUrl}/exam-hall-arrangements/${widget.studentId}"));
      if (res.statusCode == 200) {
        final responseData = jsonDecode(res.body);
        if (responseData['status'] == 'no_exam') {
          setState(() { hasExam = false; isLoading = false; });
        } else {
          setState(() {
            allStudents = responseData['data'];
            filteredStudents = allStudents;
            hasExam = true;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD1C4E9), // UPDATED
      appBar: AppBar(
        title: const Text("Exam Hall Notice", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF56054A), // UPDATED
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF56054A))) // UPDATED
          : !hasExam
          ? _buildNoExamView()
          : _buildMainView(),
    );
  }

  Widget _buildNoExamView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.celebration, size: 80, color: Colors.green),
          ),
          const SizedBox(height: 20),
          const Text("Relax, Da!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF56054A))), // UPDATED
          const Text("You have no exams today. 😹", style: TextStyle(fontSize: 16, color: Colors.purple)),
        ],
      ),
    );
  }

  Widget _buildMainView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF56054A), // UPDATED
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
          ),
          child: TextField(
            controller: searchController,
            onChanged: (val) {
              setState(() {
                filteredStudents = allStudents.where((s) => s['name'].toLowerCase().contains(val.toLowerCase())).toList();
              });
            },
            decoration: InputDecoration(
              hintText: "Search student names...",
              prefixIcon: const Icon(Icons.search, color: Color(0xFF56054A)), // UPDATED
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Text("${filteredStudents.length} Students Allocated", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filteredStudents.length,
            itemBuilder: (context, i) {
              final s = filteredStudents[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF56054A).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), // UPDATED
                    child: const Icon(Icons.airline_seat_recline_extra, color: Color(0xFF56054A)), // UPDATED
                  ),
                  title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        _infoChip(Icons.room, s['room'], Colors.orange),
                        const SizedBox(width: 8),
                        _infoChip(Icons.event_seat, s['seat'], Colors.purple),
                      ],
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("Staff", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(s['staff'], style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
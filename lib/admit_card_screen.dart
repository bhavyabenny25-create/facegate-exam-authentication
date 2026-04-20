import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AdmitCardScreen extends StatefulWidget {
  final int userId;
  final String? regNo;
  final bool isEditMode;
  final String? subjectName;
  final int? allocationId;

  const AdmitCardScreen({
    super.key,
    required this.userId,
    this.regNo,
    this.isEditMode = false,
    this.subjectName,
    this.allocationId,
  });

  @override
  State<AdmitCardScreen> createState() => _AdmitCardScreenState();
}

class _AdmitCardScreenState extends State<AdmitCardScreen> {
  Map? data;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAdmitCard();
  }

  Future<void> fetchAdmitCard() async {
    try {
      String url = widget.regNo != null
          ? "${Api.baseUrl}/get-admit-card-by-reg/${widget.regNo}"
          : "${Api.baseUrl}/get-admit-card/${widget.userId}";

      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            data = jsonDecode(res.body);
            isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _toggleAttendance(String subjectName, String currentStatus) async {
    String normalizedStatus = currentStatus.toUpperCase();
    String nextStatus = (normalizedStatus == "PRESENT") ? "ABSENT" : "PRESENT";

    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Change to $nextStatus"),
        content: Text("Do you want to mark $subjectName as $nextStatus?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Set $nextStatus"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await http.post(
          Uri.parse("${Api.baseUrl}/update-attendance-manual"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "allocation_id": widget.allocationId,
            "register_number": data!['reg_no'],
            "subject_name": subjectName,
            "status": nextStatus
          }),
        );

        if (res.statusCode == 200) {
          fetchAdmitCard();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Marked as $nextStatus ✅")),
            );
          }
        }
      } catch (e) {
        debugPrint("Update error: $e");
      }
    }
  }

  Future<void> printAdmitCard() async {
    if (data == null || data!['semesters'] == null) return;
    final pdf = pw.Document();

    for (var sem in data!['semesters']) {
      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text(data!['university'] ?? "UNIVERSITY", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
              pw.Center(child: pw.Text("${sem['title']} UG EXAMINATION 2026", style: pw.TextStyle(fontSize: 14))),
              pw.SizedBox(height: 10),
              pw.Row(children: [
                pw.Text("Name: ${data!['name']}\nReg No: ${data!['reg_no']}\nDept: ${data!['dept']}"),
              ]),
              pw.Divider(),
              pw.Text("Center: ${sem['center']}"),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                data: <List<String>>[
                  <String>['Date', 'Subject', 'Status'],
                  ...sem['exams'].map((s) => [
                    s['date'].toString(),
                    s['subject_name'].toString(),
                    s['status'].toString()
                  ])
                ],
              ),
            ],
          ),
        ),
      );
    }
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: Text(widget.isEditMode ? "Verify & Edit Card" : "Virtual Hall Ticket"),
        foregroundColor: Colors.white,
        elevation: 6,
        backgroundColor: const Color(0xFF56054A), // Solid Deep Plum (Gradient Removed)
        actions: [
          IconButton(onPressed: printAdmitCard, icon: const Icon(Icons.print))
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (data == null || data!['semesters'] == null)
          ? const Center(child: Text("No Admit Card Data Available"))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ...data!['semesters'].map<Widget>((sem) {
              return _buildAdmitCardBox(sem);
            }).toList(),
          ],
        ),
      ),
    );
  }

  // EVERYTHING BELOW IS 100% UNTOUCHED

  // EVERYTHING BELOW IS 100% UNTOUCHED

  Widget _buildAdmitCardBox(Map sem) {
    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.5)),
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Text(data!['university'] ?? "UNIVERSITY OF CALICUT", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text("${sem['title']} UG EXAMINATION 2026", textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 90,
                decoration: BoxDecoration(border: Border.all(color: Colors.black)),
                child: data!['photo'] != null
                    ? Image.network(data!['photo'], fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.person, size: 40))
                    : const Icon(Icons.person, size: 40),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ticketRow("Name", data!['name'] ?? "N/A"),
                    _ticketRow("Reg No", data!['reg_no'] ?? "N/A"),
                    _ticketRow("Dept", data!['dept'] ?? "N/A"),
                    _ticketRow("Center", sem['center'] ?? "N/A"),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 15),
          Table(
            border: TableBorder.all(color: Colors.black),
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(1),
            },
            children: [
              const TableRow(
                children: [
                  Padding(padding: EdgeInsets.all(5), child: Text("Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  Padding(padding: EdgeInsets.all(5), child: Text("Subject", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  Padding(padding: EdgeInsets.all(5), child: Text("Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                ],
              ),
              ...sem['exams'].map<TableRow>((e) {
                String statusText = e['status'].toString().toUpperCase();
                bool isPresent = statusText == 'PRESENT';
                Color statusColor = isPresent ? Colors.green : (statusText == 'N/A' ? Colors.blue : Colors.red);

                return TableRow(
                  decoration: BoxDecoration(
                    color: isPresent ? Colors.green[50] : Colors.transparent,
                  ),
                  children: [
                    Padding(padding: EdgeInsets.all(5), child: Text(e['date'] ?? "", style: const TextStyle(fontSize: 10))),
                    Padding(padding: EdgeInsets.all(5), child: Text(e['subject_name'] ?? "", style: const TextStyle(fontSize: 10))),
                    Padding(
                      padding: const EdgeInsets.all(5),
                      child: InkWell(
                        onTap: (widget.isEditMode)
                            ? () => _toggleAttendance(e['subject_name'], statusText)
                            : null,
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            decoration: (widget.isEditMode) ? TextDecoration.underline : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
          const SizedBox(height: 20),
          const Align(alignment: Alignment.bottomRight, child: Text("Controller of Examinations", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)))
        ],
      ),
    );
  }

  Widget _ticketRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 12),
          children: [
            TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
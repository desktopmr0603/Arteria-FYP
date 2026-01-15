import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class ExportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fetch all user data and generate PDF
  Future<Uint8List> generateBPReportPdf() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    
    debugPrint('ExportService: Starting PDF generation for user ${user.uid}');
    
    try {
      // Fetch user profile
      debugPrint('ExportService: Fetching user profile...');
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      debugPrint('ExportService: User data fetched: ${userData.keys.toList()}');

      // Fetch all BP readings
      debugPrint('ExportService: Fetching BP readings...');
      final readingsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('readings')
          .orderBy('date', descending: true)
          .get();
      debugPrint('ExportService: Found ${readingsSnapshot.docs.length} readings');

      final readings = readingsSnapshot.docs.map((doc) {
        final data = doc.data();
        // Safely parse numbers to int
        int parseToInt(dynamic value) {
          if (value == null) return 0;
          if (value is int) return value;
          if (value is double) return value.toInt();
          if (value is num) return value.toInt();
          if (value is String) return int.tryParse(value) ?? 0;
          return 0;
        }

        return {
          'systolic': parseToInt(data['systolic']),
          'diastolic': parseToInt(data['diastolic']),
          'date': data['date'] is Timestamp
              ? (data['date'] as Timestamp).toDate()
              : DateTime.now(),
        };
      }).toList();

      debugPrint('ExportService: Building PDF document...');
      final pdfBytes = await _buildPdf(userData, readings);
      debugPrint('ExportService: PDF generated successfully, size: ${pdfBytes.length} bytes');
      return pdfBytes;
    } catch (e, stackTrace) {
      debugPrint('ExportService ERROR: $e');
      debugPrint(stackTrace.toString());
      throw Exception('Failed to generate PDF: $e');
    }
  }

  Future<Uint8List> _buildPdf(
    Map<String, dynamic> userData,
    List<Map<String, dynamic>> readings,
  ) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final now = DateTime.now();

    // User info
    String userName = (userData['fullName'] ?? '').toString().trim();
    if (userName.isEmpty) {
      userName = (userData['firstName'] ?? '').toString().trim();
    }
    if (userName.isEmpty) {
      userName = 'User';
    }

    final age = (userData['age']?.toString() ?? '').isEmpty ? '—' : userData['age'].toString();
    final gender = (userData['gender'] ?? '').toString().trim().isEmpty ? '—' : userData['gender'].toString();
    final height = (userData['height']?.toString() ?? '').isEmpty ? '—' : userData['height'].toString();
    final weight = (userData['weight']?.toString() ?? '').isEmpty ? '—' : userData['weight'].toString();

    // Calculate statistics
    int totalSystolic = 0;
    int totalDiastolic = 0;
    for (final r in readings) {
      totalSystolic += (r['systolic'] as int? ?? 0);
      totalDiastolic += (r['diastolic'] as int? ?? 0);
    }
    final avgSystolic = readings.isNotEmpty ? totalSystolic ~/ readings.length : 0;
    final avgDiastolic = readings.isNotEmpty ? totalDiastolic ~/ readings.length : 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(userName, now, dateFormat),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // Profile Summary Card
          _buildProfileCard(userName, age, gender, height, weight),
          pw.SizedBox(height: 24),

          // Statistics Summary
          if (readings.isNotEmpty) ...[
            _buildStatisticsCard(readings, avgSystolic, avgDiastolic, dateFormat),
            pw.SizedBox(height: 24),
          ],

          // Readings Table
          _buildReadingsSection(readings, dateFormat, timeFormat),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(String userName, DateTime now, DateFormat dateFormat) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 20),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFE0E0E0), width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Arteria',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFFE63946),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Blood Pressure Health Report',
                style: pw.TextStyle(
                  fontSize: 14,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Generated: ${dateFormat.format(now)}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
              pw.Text(
                'Patient: $userName',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
      ),
    );
  }

  pw.Widget _buildProfileCard(
    String name,
    String age,
    String gender,
    String height,
    String weight,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8F9FA),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE0E0E0)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Patient Profile',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF1A1A1A),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _infoItem('Name', name),
              _infoItem('Age', '$age years'),
              _infoItem('Gender', gender),
              _infoItem('Height', '$height cm'),
              _infoItem('Weight', '$weight kg'),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _infoItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _buildStatisticsCard(
    List<Map<String, dynamic>> readings,
    int avgSystolic,
    int avgDiastolic,
    DateFormat dateFormat,
  ) {
    final firstDate = readings.isNotEmpty ? readings.last['date'] as DateTime : DateTime.now();
    final lastDate = readings.isNotEmpty ? readings.first['date'] as DateTime : DateTime.now();
    final avgCategory = _getCategory(avgSystolic, avgDiastolic);

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFFF5F5),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE63946), width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _statItem('Total Readings', '${readings.length}'),
          _statItem('Average BP', '$avgSystolic/$avgDiastolic mmHg'),
          _statItem('Average Category', avgCategory),
          _statItem('Date Range', '${dateFormat.format(firstDate)} - ${dateFormat.format(lastDate)}'),
        ],
      ),
    );
  }

  pw.Widget _statItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFFE63946),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ],
    );
  }

  pw.Widget _buildReadingsSection(
    List<Map<String, dynamic>> readings,
    DateFormat dateFormat,
    DateFormat timeFormat,
  ) {
    if (readings.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(40),
        child: pw.Center(
          child: pw.Text(
            'No blood pressure readings recorded yet.',
            style: pw.TextStyle(fontSize: 14, color: PdfColors.grey600),
          ),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Blood Pressure Readings',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFF1A1A1A),
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE0E0E0), width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8F9FA)),
              children: [
                _tableHeader('Date & Time'),
                _tableHeader('Systolic'),
                _tableHeader('Diastolic'),
                _tableHeader('Category'),
              ],
            ),
            // Data rows
            ...readings.map((r) {
              final date = r['date'] as DateTime;
              final systolic = r['systolic'] as int? ?? 0;
              final diastolic = r['diastolic'] as int? ?? 0;
              final category = _getCategory(systolic, diastolic);
              final categoryColor = _getCategoryColor(category);

              return pw.TableRow(
                children: [
                  _tableCell('${dateFormat.format(date)} ${timeFormat.format(date)}'),
                  _tableCell('$systolic mmHg'),
                  _tableCell('$diastolic mmHg'),
                  _tableCellColored(category, categoryColor),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  pw.Widget _tableHeader(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _tableCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  pw.Widget _tableCellColored(String text, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color),
      ),
    );
  }

  String _getCategory(int systolic, int diastolic) {
    if (systolic < 120 && diastolic < 80) return 'Normal';
    if (systolic < 130 && diastolic < 80) return 'Elevated';
    if (systolic < 140 || diastolic < 90) return 'Stage 1 Hypertension';
    if (systolic >= 140 || diastolic >= 90) return 'Stage 2 Hypertension';
    if (systolic > 180 || diastolic > 120) return 'Hypertensive Crisis';
    return 'Unknown';
  }

  PdfColor _getCategoryColor(String category) {
    switch (category) {
      case 'Normal':
        return const PdfColor.fromInt(0xFF4CAF50);
      case 'Elevated':
        return const PdfColor.fromInt(0xFFFF9800);
      case 'Stage 1 Hypertension':
        return const PdfColor.fromInt(0xFFFF5722);
      case 'Stage 2 Hypertension':
        return const PdfColor.fromInt(0xFFE63946);
      case 'Hypertensive Crisis':
        return const PdfColor.fromInt(0xFF9C27B0);
      default:
        return PdfColors.grey700;
    }
  }
}

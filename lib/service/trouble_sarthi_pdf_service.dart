// lib/service/trouble_sarthi_pdf_service.dart
// ignore_for_file: unused_local_variable

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'
    show BorderRadius, BuildContext, Color, Colors, EdgeInsets, FontWeight,
    RoundedRectangleBorder, ScaffoldMessenger, SnackBar, SnackBarBehavior,
    Text, TextStyle, CircularProgressIndicator;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const _kBgColor   = PdfColor.fromInt(0xFF1B3A2D);
const _kBgLight   = PdfColor.fromInt(0xFF224433);
const _kGold      = PdfColor.fromInt(0xFFC9A84C);
const _kGoldLight = PdfColor.fromInt(0xFFE2C97E);
const _kWhite     = PdfColors.white;
const _kWhite70   = PdfColor.fromInt(0xB3FFFFFF);
const _kWhite40   = PdfColor.fromInt(0x66FFFFFF);
const _kRowAlt    = PdfColor.fromInt(0xFF1E3D28);
// Receipt-style cream palette
const _kCream     = PdfColor.fromInt(0xFFF5EDD8);
const _kCreamDark = PdfColor.fromInt(0xFFD9C9A3);
const _kTextDark  = PdfColor.fromInt(0xFF1A1A1A);
const _kTextGrey  = PdfColor.fromInt(0xFF555555);

/// FIX 3 — PdfColor has no .withOpacity(); use this instead
PdfColor _op(PdfColor c, double alpha) => PdfColor(c.red, c.green, c.blue, alpha);

class TroubleSarthiPdfService {
  TroubleSarthiPdfService._();

  static Future<void> downloadUserData(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _showSnack(context, 'Preparing your data...', color: const PdfColor.fromInt(0xFF7C3AED));
    try {
      final userSnap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userSnap.data() ?? {};
      final bookingsSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      final bookings = bookingsSnap.docs.map((d) => d.data()).toList();
      Map<String, dynamic> latestBooking = {};
      Map<String, dynamic> helperData   = {};
      if (bookings.isNotEmpty) {
        latestBooking = bookings.first;
        final helperId = latestBooking['helperId'] as String?;
        if (helperId != null && helperId.isNotEmpty) {
          final hSnap = await FirebaseFirestore.instance.collection('helpers').doc(helperId).get();
          helperData = hSnap.data() ?? {};
        }
      }
      // FIX 1: Uint8List return type
      final Uint8List pdfBytes = await _buildPdf(
        user: user, userData: userData, bookings: bookings,
        latestBooking: latestBooking, helperData: helperData,
      );
      final fileName = 'TroubleSarthi_${user.uid.substring(0, 6)}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
    } catch (e) {
      if (context.mounted) _showSnack(context, 'Failed: $e', color: const PdfColor.fromInt(0xFFDC2626));
    }
  }

  // FIX 1: Uint8List not List<int>
  static Future<Uint8List> _buildPdf({
    required User user,
    required Map<String, dynamic> userData,
    required List<Map<String, dynamic>> bookings,
    required Map<String, dynamic> latestBooking,
    required Map<String, dynamic> helperData,
  }) async {
    final pdf = pw.Document(title: 'TroubleSarthi Data', author: 'TroubleSarthi');

    pw.Font? boldFont;
    pw.Font? regularFont;
    pw.Font? samanFont;          // brand-name font (receipt style)
    try {
      boldFont    = await PdfGoogleFonts.notoSansBold();
      regularFont = await PdfGoogleFonts.notoSansRegular();
    } catch (_) {}
    try {
      final samanData = await rootBundle.load('assets/fonts/SAMAN___.TTF');
      samanFont = pw.Font.ttf(samanData);
    } catch (_) {
      samanFont = null;          // gracefully falls back to default
    }
    final theme = pw.ThemeData.withFont(base: regularFont, bold: boldFont);

    String s(dynamic v, [String fb = '—']) => (v != null && v.toString().isNotEmpty) ? v.toString() : fb;
    String fd(dynamic v) { if (v == null) return '—'; if (v is Timestamp) return DateFormat('dd MMM yyyy, hh:mm a').format(v.toDate()); return v.toString(); }
    String rs(dynamic v) { final n = (v as num?)?.toDouble() ?? 0; return 'Rs. ${n.toStringAsFixed(2)}'; }
    String tier(double t) { if (t >= 5000) return 'Platinum'; if (t >= 2000) return 'Gold'; if (t >= 500) return 'Silver'; return 'Bronze'; }

    final dName    = s(userData['name'] ?? user.displayName);
    final phone    = s(userData['phone'] ?? userData['phoneNumber']);
    final email    = s(user.email);
    final address  = s(userData['address'] ?? '${s(userData['area'])}, Surat, Gujarat, India');
    final custId   = s(userData['userId'] ?? user.uid.substring(0, 8).toUpperCase());
    final svcType  = s(latestBooking['serviceType']   ?? latestBooking['service']);
    final bkgId    = s(latestBooking['bookingId']     ?? latestBooking['id']);
    final bkgDate  = fd(latestBooking['createdAt']    ?? latestBooking['bookingDate']);
    final hName    = s(latestBooking['helperName']    ?? helperData['name']);
    final status   = s(latestBooking['status'], 'Pending');
    final svcFee   = (latestBooking['pricePerVisit'] ?? latestBooking['totalAmount'] ?? 0) as num;
    final platFee  = (latestBooking['platformFee']   ?? (svcFee * 0.05)) as num;
    final total    = svcFee + platFee;
    final payMeth  = s(latestBooking['paymentMethod'], 'Cash');
    final txnId    = s(latestBooking['transactionId'] ?? latestBooking['txnId']);
    final problem  = s(latestBooking['problemDescription'] ?? latestBooking['description']);
    final diag     = s(latestBooking['diagnosis']);
    final work     = s(latestBooking['workPerformed'] ?? latestBooking['notes']);
    final parts    = s(latestBooking['partsUsed']);
    final dur      = s(latestBooking['timeTaken']     ?? latestBooking['duration']);
    final cat      = s(latestBooking['category']      ?? latestBooking['serviceCategory']);
    final prio     = s(latestBooking['priority'], 'Normal');
    final hId      = s(helperData['uid']              ?? latestBooking['helperId']);
    final hExp     = s(helperData['experience'], '0');
    final hSkills  = (helperData['services'] as List?)?.join(', ') ?? s(helperData['skills']);
    final hRating  = ((helperData['rating'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1);
    double totalSpend = 0;
    final Map<String, int> catCnt = {};
    for (final b in bookings) {
      totalSpend += ((b['pricePerVisit'] ?? b['totalAmount'] ?? 0) as num).toDouble();
      final c = (b['category'] ?? b['serviceType'] ?? 'Other').toString();
      catCnt[c] = (catCnt[c] ?? 0) + 1;
    }
    String mostUsed = '—';
    if (catCnt.isNotEmpty) mostUsed = catCnt.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final loyalty = tier(totalSpend);
    final billing = bookings.take(5).map((b) => [fd(b['createdAt'] ?? b['bookingDate']), s(b['serviceType'] ?? b['service']), rs(b['pricePerVisit'] ?? b['totalAmount'] ?? 0), s(b['status'], 'Pending')]).toList();
    final allRows = bookings.take(10).map((b) => [fd(b['createdAt'] ?? b['bookingDate']), s(b['serviceType'] ?? b['service']), rs(b['pricePerVisit'] ?? b['totalAmount'] ?? 0), s(b['status'], 'Pending'), s(b['helperName'] ?? b['helperId'])]).toList();
    final hjobs   = bookings.where((b) => b['helperId'] == latestBooking['helperId']).take(5).map((b) => [fd(b['createdAt'] ?? b['bookingDate']), s(b['serviceType'] ?? b['service']), s(b['status'], 'Pending')]).toList();

    // ── builders ──────────────────────────────────────────────────────────────
    // ── builders ──────────────────────────────────────────────────────────────

    /// Cream panel — used for content cards (matches receipt light sections)
    pw.BoxDecoration panel() => const pw.BoxDecoration(
      color:  _kCream,
      border: pw.Border.fromBorderSide(pw.BorderSide(color: _kCreamDark, width: 0.8)),
    );

    /// Dark panel — used for notes / T&C where dark bg is intentional
    pw.BoxDecoration panelDark() => pw.BoxDecoration(
      color:  _kBgLight,
      border: pw.Border.all(color: _op(_kGold, 0.35), width: 0.8),
    );

    /// Header — Saman brand font + receipt-style gold side-line title
    pw.Widget hdr(String t) => pw.Container(
      width:      double.infinity,
      decoration: const pw.BoxDecoration(color: _kBgColor),
      padding:    const pw.EdgeInsets.fromLTRB(28, 24, 28, 18),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        // Brand name in Saman font (identical to receipt)
        pw.Text(
          'trouble sarthi',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: samanFont, fontSize: 46, color: _kWhite),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'On-Demand Helper Service for Your Troubles',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(color: _kWhite70, fontSize: 10, letterSpacing: 1),
        ),
        pw.SizedBox(height: 18),
        // Page-title row with flanking gold rules (receipt pattern)
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
          pw.Container(width: 60, height: 1, color: _kGold),
          pw.SizedBox(width: 12),
          pw.Text(
            t.toUpperCase(),
            style: pw.TextStyle(color: _kGold, fontSize: 11, fontWeight: pw.FontWeight.bold, letterSpacing: 2.5),
          ),
          pw.SizedBox(width: 12),
          pw.Container(width: 60, height: 1, color: _kGold),
        ]),
        pw.SizedBox(height: 6),
      ]),
    );

    /// Footer — unchanged layout, kept dark green
    pw.Widget ftr(int n) => pw.Container(
      width:   double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 10),
      color:   _kBgColor,
      child: pw.Column(children: [
        pw.Container(height: 0.5, color: _kGold),
        pw.SizedBox(height: 6),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Phone: +91 98753221  |  Email: contact@troublesarthi.com',
              style: pw.TextStyle(color: _kWhite40, fontSize: 7.5)),
          pw.Text('Page $n of 6', style: pw.TextStyle(color: _kWhite40, fontSize: 7.5)),
        ]),
        pw.SizedBox(height: 4),
        pw.Text(
          'This is an electronic document and does not require a physical signature.',
          style: pw.TextStyle(color: _kWhite40, fontSize: 7),
          textAlign: pw.TextAlign.center,
        ),
      ]),
    );

    /// Section header — full-width dark-green bar with gold caps (receipt table-title style)
    pw.Widget sh(String t) => pw.Container(
      width:      double.infinity,
      margin:     const pw.EdgeInsets.only(top: 14, bottom: 6),
      padding:    const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const pw.BoxDecoration(color: _kBgColor),
      child: pw.Text(
        t.toUpperCase(),
        style: pw.TextStyle(color: _kGold, fontSize: 9.5, fontWeight: pw.FontWeight.bold, letterSpacing: 2),
      ),
    );

    /// Key-value row — dark text on cream panels; gold highlight for important values
    pw.Widget kv(String k, String v, {bool hi = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(
          width: 155,
          child: pw.Text(k, style: pw.TextStyle(
            color: _kTextGrey, fontSize: 10, fontWeight: pw.FontWeight.bold,
          )),
        ),
        if (hi)
          pw.Container(
            padding:    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: const pw.BoxDecoration(color: _kGold),
            child: pw.Text(v, style: pw.TextStyle(
              color: _kBgColor, fontSize: 9.5, fontWeight: pw.FontWeight.bold,
            )),
          )
        else
          pw.Expanded(child: pw.Text(v, style: pw.TextStyle(
            color: _kTextDark, fontSize: 10,
          ))),
      ]),
    );

    /// Table — receipt style: dark-green header with gold text, cream alternating rows
    pw.Widget tbl(List<String> hs, List<List<String>> rows) => pw.Table(
      border: pw.TableBorder.all(color: _kCreamDark, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kBgLight),
          children: hs.map((h) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: pw.Text(h, style: pw.TextStyle(
              color: _kGoldLight, fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 1,
            )),
          )).toList(),
        ),
        ...rows.asMap().entries.map((e) => pw.TableRow(
          decoration: pw.BoxDecoration(color: e.key.isOdd ? _kCreamDark : _kCream),
          children: e.value.map((c) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(c, style: pw.TextStyle(color: _kTextDark, fontSize: 8.5)),
          )).toList(),
        )),
      ],
    );

    pw.PageTheme pt() => pw.PageTheme(
      pageFormat: PdfPageFormat.a4, theme: theme,
      buildBackground: (_) => pw.FullPage(ignoreMargins: true, child: pw.Container(color: _kBgColor)),
      margin: pw.EdgeInsets.zero,
    );

    // PAGE 1
    pdf.addPage(pw.Page(pageTheme: pt(), build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      hdr('Customer Overview'),
      pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 10), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        sh('User Information'),
        pw.Container(padding: const pw.EdgeInsets.all(12), decoration: panel(), child: pw.Column(children: [kv('Full Name', dName), kv('Address', address), kv('Phone', phone), kv('Email', email), kv('Customer ID', custId)])),
        sh('Service Summary'),
        pw.Container(padding: const pw.EdgeInsets.all(12), decoration: panel(), child: pw.Column(children: [kv('Service', svcType), kv('Booking ID', bkgId), kv('Date & Time', bkgDate), kv('Helper', hName), kv('Status', status, hi: true)])),
        sh('Payment Summary'),
        pw.Container(padding: const pw.EdgeInsets.all(12), decoration: panel(), child: pw.Column(children: [kv('Service Fee', rs(svcFee)), kv('Platform Charges', rs(platFee)), kv('Total Paid', rs(total), hi: true), kv('Payment Method', payMeth, hi: true)])),
      ]))),
      ftr(1),
    ])));

    // PAGE 2
    pdf.addPage(pw.Page(pageTheme: pt(), build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      hdr('Service Details'),
      pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 10), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        sh('Detailed Service Breakdown'),
        pw.Container(padding: const pw.EdgeInsets.all(12), decoration: panel(), child: pw.Column(children: [kv('Problem Reported', problem), kv('Diagnosis', diag), kv('Work Performed', work), kv('Parts / Tools Used', parts), kv('Time Spent', dur), kv('Service Category', cat), kv('Priority Level', prio, hi: true)])),
      ]))),
      ftr(2),
    ])));

    // PAGE 3
    pdf.addPage(pw.Page(pageTheme: pt(), build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      hdr('Helper Details'),
      pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 10), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        sh('Technician / Helper Profile'),
        pw.Container(padding: const pw.EdgeInsets.all(12), decoration: panel(), child: pw.Column(children: [kv('Helper Name', hName), kv('Helper ID', hId), kv('Experience', '$hExp years'), kv('Skills', hSkills), kv('Rating', '$hRating / 5.0', hi: true), kv('Contact', '****${phone.length > 4 ? phone.substring(phone.length - 4) : phone}  (masked)')])),
        if (hjobs.isNotEmpty) ...[sh('Recent Jobs by This Helper'), tbl(['Date', 'Service', 'Status'], hjobs)],
      ]))),
      ftr(3),
    ])));

    // PAGE 4
    pdf.addPage(pw.Page(pageTheme: pt(), build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      hdr('Payment History'),
      pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 10), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        sh('Transaction Details'),
        pw.Container(padding: const pw.EdgeInsets.all(12), decoration: panel(), child: pw.Column(children: [kv('Transaction ID', txnId), kv('Payment Method', payMeth), kv('Payment Status', s(latestBooking['paymentStatus'], 'Successful'), hi: true)])),
        sh('Payment Breakdown'),
        tbl(['Item', 'Amount'], [['Service Fee', rs(svcFee)], ['Platform Fee', rs(platFee)], ['Discount', rs(latestBooking['discount'] ?? 0)], ['Tax', rs(latestBooking['tax'] ?? 0)], ['Total', rs(total)]]),
        sh('Billing History (Last 5 Bookings)'),
        billing.isNotEmpty ? tbl(['Date', 'Service', 'Amount', 'Status'], billing) : pw.Text('No bookings found.', style: pw.TextStyle(color: _kWhite70, fontSize: 9)),
        pw.SizedBox(height: 10),
        pw.Container(padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(color: _kBgLight, border: pw.Border.all(color: _op(_kGold, 0.2), width: 0.5), borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Text('Refund Policy: Refunds processed within 5-7 business days. Contact support@troublesarthi.com.', style: pw.TextStyle(color: _kWhite70, fontSize: 8.5, fontStyle: pw.FontStyle.italic))),
      ]))),
      ftr(4),
    ])));

    // PAGE 5
    pdf.addPage(pw.Page(pageTheme: pt(), build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      hdr('Customer History & Insights'),
      pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 10), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        sh('Account Insights'),
        pw.Container(padding: const pw.EdgeInsets.all(12), decoration: panel(), child: pw.Column(children: [kv('Total Bookings', '${bookings.length}'), kv('Total Spending', rs(totalSpend), hi: true), kv('Most Used Category', mostUsed), kv('Loyalty Status', loyalty, hi: true), kv('Completed', '${bookings.where((b) => (b['status'] ?? '').toString().toLowerCase() == 'completed').length}'), kv('Cancelled', '${bookings.where((b) => (b['status'] ?? '').toString().toLowerCase() == 'cancelled').length}')])),
        sh('Full Booking History (Latest 10)'),
        allRows.isNotEmpty ? tbl(['Date', 'Service', 'Amount', 'Status', 'Helper'], allRows) : pw.Text('No booking history found.', style: pw.TextStyle(color: _kWhite70, fontSize: 9)),
      ]))),
      ftr(5),
    ])));

    // PAGE 6
    pdf.addPage(pw.Page(pageTheme: pt(), build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      hdr('Notes & Support'),
      pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 10), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        sh('Support Information'),
        pw.Container(padding: const pw.EdgeInsets.all(12), decoration: panel(), child: pw.Column(children: [kv('Support Email', 'support@troublesarthi.com'), kv('Support Phone', '+91 98753221'), kv('Working Hours', 'Mon-Sat, 9 AM - 8 PM IST'), kv('Website', 'www.troublesarthi.com')])),
        sh('Terms & Conditions'),
        pw.Container(padding: const pw.EdgeInsets.all(12), decoration: pw.BoxDecoration(color: _kBgLight, border: pw.Border.all(color: _op(_kGold, 0.2), width: 0.5), borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _bp('1. TroubleSarthi acts as a platform connecting users and service providers.'),
              _bp('2. We do not guarantee availability of helpers at all times.'),
              _bp('3. Payments are subject to our refund policy outlined above.'),
              _bp('4. Users must provide accurate information when booking services.'),
              _bp('5. TroubleSarthi is not liable for damages caused by third-party helpers.'),
              _bp('6. This document is auto-generated and valid without a physical signature.'),
            ])),
        sh('Disclaimer'),
        pw.Container(padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(color: _kBgLight, border: pw.Border.all(color: _op(_kGold, 0.2), width: 0.5), borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Text('This data export was generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())} for UID: ${user.uid}. Keep it confidential. Contact support@troublesarthi.com.', style: pw.TextStyle(color: _kWhite70, fontSize: 8.5, fontStyle: pw.FontStyle.italic, lineSpacing: 2))),
        pw.Spacer(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
          pw.Text('Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}  |  TroubleSarthi v2.4.1 (Indigo)', style: pw.TextStyle(color: _kWhite40, fontSize: 8)),
        ]),
      ]))),
      ftr(6),
    ])));

    return pdf.save();
  }

  static pw.Widget _bp(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(width: 5, height: 5, margin: const pw.EdgeInsets.only(top: 3, right: 6), decoration: const pw.BoxDecoration(color: _kGold, shape: pw.BoxShape.circle)),
      pw.Expanded(child: pw.Text(text, style: pw.TextStyle(color: _kWhite70, fontSize: 8.5, lineSpacing: 1.5))),
    ]),
  );

  // FIX 2: TextStyle, FontWeight, Color, EdgeInsets all imported above
  static void _showSnack(BuildContext ctx, String msg, {PdfColor color = _kGold}) {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: Color(((color.red * 255).round() << 16) | ((color.green * 255).round() << 8) | (color.blue * 255).round() | 0xFF000000),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    ));
  }
}
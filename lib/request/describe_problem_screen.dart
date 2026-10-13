// lib/screens/request/describe_problem_screen.dart
// Step 1 of the new booking flow (customer):
// pick subcategory → describe the problem (text in English/Hindi/Gujarati,
// photos, voice note) → choose a time → confirm address → send to helpers
// within 5 km, who reply with their price.

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/app_config.dart';
import '../../core/cloudinary.dart';
import '../../core/job_api.dart';
import '../../core/job_media_widgets.dart';
import '../../core/job_models.dart';
import '../../core/service_catalog.dart';
import '../../service/firestore_service.dart';
import 'request_pitches_screen.dart';

const _purple = Color(0xFF7C3AED);
const _ink = Color(0xFF111827);
const _muted = Color(0xFF6B7280);
const _maxPhotos = AppConfig.maxPhotos;
const _maxAudioSec = AppConfig.maxAudioSeconds;

// ─── Strings (en / hi / gu) ────────────────────────────────────────────────

const Map<String, Map<String, String>> _t = {
  'en': {
    'title': 'Describe your problem',
    'lang': 'Write in',
    'what': 'What needs fixing?',
    'hint': 'Example: Bathroom tap is leaking and the water heater is not heating.',
    'photos': 'Photos (optional)',
    'camera': 'Camera',
    'gallery': 'Gallery',
    'voice': 'Voice note (optional)',
    'recordHint': 'Tap to record, up to 2 minutes',
    'recording': 'Recording… tap to stop',
    'when': 'When do you need it?',
    'now': 'As soon as possible',
    'schedule': 'Pick a time',
    'today': 'Today',
    'tomorrow': 'Tomorrow',
    'where': 'Where?',
    'gps': 'Use my current location',
    'house': 'House / flat no.',
    'landmark': 'Landmark (optional)',
    'submit': 'Get price quotes',
    'note': 'Helpers within 5 km will send their price. You choose one. '
        'You pay the helper directly (cash or UPI) after the work is done.',
    'errDesc': 'Please describe the problem (at least 10 characters).',
    'errLoc': 'Please set the service location.',
    'errHouse': 'Please enter the house / flat number.',
    'errSlot': 'Please pick a time slot.',
    'uploading': 'Uploading photos and voice note…',
    'sending': 'Sending to nearby helpers…',
    'noLoc': 'No location yet. Tap below to use your current location.',
    'micDenied': 'Microphone permission is needed to record a voice note.',
  },
  'hi': {
    'title': 'अपनी समस्या बताएं',
    'lang': 'भाषा',
    'what': 'क्या ठीक करवाना है?',
    'hint': 'उदाहरण: बाथरूम का नल टपक रहा है और गीज़र गर्म नहीं हो रहा।',
    'photos': 'फ़ोटो (वैकल्पिक)',
    'camera': 'कैमरा',
    'gallery': 'गैलरी',
    'voice': 'वॉइस नोट (वैकल्पिक)',
    'recordHint': 'रिकॉर्ड करने के लिए टैप करें, 2 मिनट तक',
    'recording': 'रिकॉर्डिंग… रोकने के लिए टैप करें',
    'when': 'कब चाहिए?',
    'now': 'जल्द से जल्द',
    'schedule': 'समय चुनें',
    'today': 'आज',
    'tomorrow': 'कल',
    'where': 'कहाँ?',
    'gps': 'मेरी मौजूदा लोकेशन',
    'house': 'मकान / फ्लैट नंबर',
    'landmark': 'लैंडमार्क (वैकल्पिक)',
    'submit': 'कीमत प्रस्ताव पाएं',
    'note': '5 किमी के अंदर के हेल्पर अपनी कीमत भेजेंगे। आप एक चुनें। '
        'काम पूरा होने के बाद सीधे हेल्पर को (नकद या UPI) भुगतान करें।',
    'errDesc': 'कृपया समस्या लिखें (कम से कम 10 अक्षर)।',
    'errLoc': 'कृपया सेवा का स्थान चुनें।',
    'errHouse': 'कृपया मकान / फ्लैट नंबर लिखें।',
    'errSlot': 'कृपया समय चुनें।',
    'uploading': 'फ़ोटो और वॉइस नोट अपलोड हो रहे हैं…',
    'sending': 'पास के हेल्पर को भेज रहे हैं…',
    'noLoc': 'लोकेशन नहीं मिली। नीचे टैप करके मौजूदा लोकेशन लें।',
    'micDenied': 'वॉइस नोट के लिए माइक्रोफ़ोन की अनुमति चाहिए।',
  },
  'gu': {
    'title': 'તમારી સમસ્યા જણાવો',
    'lang': 'ભાષા',
    'what': 'શું રિપેર કરાવવું છે?',
    'hint': 'ઉદાહરણ: બાથરૂમનો નળ ટપકે છે અને ગીઝર ગરમ થતું નથી.',
    'photos': 'ફોટો (વૈકલ્પિક)',
    'camera': 'કૅમેરા',
    'gallery': 'ગૅલરી',
    'voice': 'વૉઇસ નોટ (વૈકલ્પિક)',
    'recordHint': 'રેકોર્ડ કરવા ટૅપ કરો, 2 મિનિટ સુધી',
    'recording': 'રેકોર્ડિંગ… રોકવા ટૅપ કરો',
    'when': 'ક્યારે જોઈએ?',
    'now': 'બને એટલું જલદી',
    'schedule': 'સમય પસંદ કરો',
    'today': 'આજે',
    'tomorrow': 'આવતીકાલે',
    'where': 'ક્યાં?',
    'gps': 'મારું હાલનું સ્થાન',
    'house': 'મકાન / ફ્લેટ નંબર',
    'landmark': 'લેન્ડમાર્ક (વૈકલ્પિક)',
    'submit': 'ભાવ પ્રસ્તાવ મેળવો',
    'note': '5 કિમીની અંદરના હેલ્પર તેમનો ભાવ મોકલશે. તમે એક પસંદ કરો. '
        'કામ પૂરું થયા પછી સીધા હેલ્પરને (રોકડ અથવા UPI) ચૂકવો.',
    'errDesc': 'કૃપા કરી સમસ્યા લખો (ઓછામાં ઓછા 10 અક્ષર).',
    'errLoc': 'કૃપા કરી સેવાનું સ્થાન પસંદ કરો.',
    'errHouse': 'કૃપા કરી મકાન / ફ્લેટ નંબર લખો.',
    'errSlot': 'કૃપા કરી સમય પસંદ કરો.',
    'uploading': 'ફોટો અને વૉઇસ નોટ અપલોડ થઈ રહ્યા છે…',
    'sending': 'નજીકના હેલ્પરને મોકલી રહ્યા છીએ…',
    'noLoc': 'સ્થાન મળ્યું નથી. નીચે ટૅપ કરી હાલનું સ્થાન લો.',
    'micDenied': 'વૉઇસ નોટ માટે માઇક્રોફોનની પરવાનગી જોઈએ.',
  },
};

class DescribeProblemScreen extends StatefulWidget {
  final ServiceSubcategory subcategory;
  final Color color;
  const DescribeProblemScreen({super.key, required this.subcategory, this.color = _purple});

  @override
  State<DescribeProblemScreen> createState() => _DescribeProblemScreenState();
}

class _Picked {
  final String localPath;
  String? uploadedUrl;
  _Picked(this.localPath);
}

class _DescribeProblemScreenState extends State<DescribeProblemScreen> {
  late final String _jobId = JobApi.instance.newJobId();
  String _lang = 'en';

  final _desc = TextEditingController();
  final _house = TextEditingController();
  final _landmark = TextEditingController();

  final List<_Picked> _photos = [];
  final _picker = ImagePicker();

  // Voice note
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  int _recSeconds = 0;
  Timer? _recTimer;
  String? _audioLocal;
  int _audioSeconds = 0;
  String? _audioUploaded;

  // Time
  bool _isNow = true;
  DateTime _day = DateUtils.dateOnly(DateTime.now());
  int? _slotStartHour; // 8, 10, …, 18

  // Location
  double? _lat;
  double? _lng;
  String _addressLine = '';
  String _areaName = '';
  bool _locLoading = true;

  // Submit
  bool _busy = false;
  String _busyText = '';
  String? _error;

  String t(String k) => _t[_lang]?[k] ?? _t['en']![k] ?? k;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _loadSavedLocation();
  }

  @override
  void dispose() {
    _recTimer?.cancel();
    _recorder.dispose();
    _desc.dispose();
    _house.dispose();
    _landmark.dispose();
    super.dispose();
  }

  Future<void> _loadLanguage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final d = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final l = d.data()?['lang'];
      if (mounted && (l == 'hi' || l == 'gu')) setState(() => _lang = l as String);
    } catch (_) {}
  }

  Future<void> _setLanguage(String l) async {
    setState(() => _lang = l);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    // Remember it; the server also uses it for notification language.
    FirebaseFirestore.instance.collection('users').doc(uid).set({'lang': l}, SetOptions(merge: true));
  }

  // ─── Location ────────────────────────────────────────────────────────────

  Future<void> _loadSavedLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final loc = await FirestoreService.instance.fetchActiveLocation(uid);
      if (loc != null && loc.latitude != 0 && loc.longitude != 0 && mounted) {
        setState(() {
          _lat = loc.latitude;
          _lng = loc.longitude;
          _addressLine =
              [loc.primaryLine, loc.secondaryLine].where((s) => s.trim().isNotEmpty).join(', ');
          _areaName = loc.subLocality.isNotEmpty ? loc.subLocality : loc.city;
        });
      }
    }
    if (mounted) setState(() => _locLoading = false);
  }

  Future<void> _useGps() async {
    setState(() {
      _locLoading = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
        throw 'Turn on location (GPS) and try again.';
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        throw 'Location permission is needed to find helpers near you.';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 20));
      String line = '';
      String area = '';
      try {
        final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (marks.isNotEmpty) {
          final m = marks.first;
          line = [m.street, m.subLocality, m.locality, m.postalCode]
              .whereType<String>()
              .where((s) => s.trim().isNotEmpty)
              .toSet()
              .join(', ');
          area = (m.subLocality?.isNotEmpty ?? false) ? m.subLocality! : (m.locality ?? '');
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _addressLine = line.isNotEmpty
            ? line
            : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        _areaName = area;
      });
    } on TimeoutException {
      if (mounted) setState(() => _error = 'Could not get your location. Move outdoors and try again.');
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _locLoading = false);
    }
  }

  // ─── Photos ──────────────────────────────────────────────────────────────

  Future<void> _addPhoto(ImageSource src) async {
    if (_photos.length >= _maxPhotos) return;
    try {
      if (src == ImageSource.camera) {
        final x = await _picker.pickImage(source: src, maxWidth: 1600, imageQuality: 75);
        if (x != null) setState(() => _photos.add(_Picked(x.path)));
      } else {
        final xs = await _picker.pickMultiImage(maxWidth: 1600, imageQuality: 75);
        final room = _maxPhotos - _photos.length;
        setState(() => _photos.addAll(xs.take(room).map((x) => _Picked(x.path))));
      }
    } catch (_) {
      _snack('Could not open the camera or gallery.');
    }
  }

  // ─── Voice note ──────────────────────────────────────────────────────────

  Future<void> _toggleRecord() async {
    if (_recording) {
      await _stopRecording();
      return;
    }
    if (!await _recorder.hasPermission()) {
      _snack(t('micDenied'));
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 22050, numChannels: 1),
      path: path,
    );
    setState(() {
      _recording = true;
      _recSeconds = 0;
      _audioLocal = null;
      _audioUploaded = null;
    });
    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recSeconds++);
      if (_recSeconds >= _maxAudioSec) _stopRecording();
    });
  }

  Future<void> _stopRecording() async {
    _recTimer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      if (path != null && _recSeconds >= 1) {
        _audioLocal = path;
        _audioSeconds = _recSeconds;
      }
    });
  }

  // ─── Time slot ───────────────────────────────────────────────────────────

  static const _slotHours = [8, 10, 12, 14, 16, 18];

  bool _slotAvailable(DateTime day, int hour) =>
      DateTime(day.year, day.month, day.day, hour).isAfter(DateTime.now().add(const Duration(minutes: 70)));

  JobSlot? get _slot {
    if (_isNow) {
      final n = DateTime.now();
      return JobSlot(isNow: true, start: n, end: n.add(const Duration(hours: 2)));
    }
    final h = _slotStartHour;
    if (h == null || !_slotAvailable(_day, h)) return null;
    final s = DateTime(_day.year, _day.month, _day.day, h);
    return JobSlot(isNow: false, start: s, end: s.add(const Duration(hours: 2)));
  }

  // ─── Submit ──────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final desc = _desc.text.trim();
    String? err;
    if (desc.length < 10) {
      err = t('errDesc');
    } else if (_lat == null || _lng == null || _addressLine.isEmpty) {
      err = t('errLoc');
    } else if (_house.text.trim().isEmpty) {
      err = t('errHouse');
    } else if (_slot == null) {
      err = t('errSlot');
    } else if (_recording) {
      await _stopRecording();
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _error = 'Please sign in again.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _busyText = t('uploading');
    });

    try {
      // 1. Upload photos and voice note to Cloudinary (skips files already
      //    uploaded on an earlier attempt).
      final folder = 'jobs/$uid/$_jobId';
      for (final p in _photos) {
        p.uploadedUrl ??= await Cloudinary.upload(File(p.localPath), folder: folder);
      }
      if (_audioLocal != null) {
        _audioUploaded ??= await Cloudinary.upload(File(_audioLocal!), folder: folder);
      }

      // 2. Save the request; nearby helpers are alerted by the notification Worker.
      if (mounted) setState(() => _busyText = t('sending'));
      final exists = await FirebaseFirestore.instance.collection('jobs').doc(_jobId).get().then((d) => d.exists, onError: (_) => false);
      if (!exists) {
        await JobApi.instance.createJobRequest(
          jobId: _jobId,
          subcategory: widget.subcategory,
          description: desc,
          language: _lang,
          photoUrls: _photos.map((p) => p.uploadedUrl!).toList(),
          audioUrl: _audioUploaded,
          audioDurationSec: _audioSeconds,
          slot: _slot!,
          addressLine: _addressLine,
          houseNo: _house.text.trim(),
          landmark: _landmark.text.trim(),
          areaName: _areaName,
          lat: _lat!,
          lng: _lng!,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => RequestPitchesScreen(jobId: _jobId),
      ));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on CloudinaryException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  // ─── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7FB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _ink,
          elevation: 0.5,
          titleSpacing: 0,
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(widget.subcategory.icon, color: c, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.subcategory.name(_lang),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text(t('title'), style: const TextStyle(fontSize: 12, color: _muted)),
              ]),
            ),
          ]),
        ),
        body: Stack(children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _languageRow(c),
              const SizedBox(height: 12),
              _card(t('what'), Icons.edit_note_rounded, c, [
                TextField(
                  controller: _desc,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _input(t('hint')),
                ),
              ]),
              _card(t('photos'), Icons.photo_camera_outlined, c, [_photoRow(c)]),
              _card(t('voice'), Icons.mic_none_rounded, c, [_voiceRow(c)]),
              _card(t('when'), Icons.schedule_rounded, c, [_timePicker(c)]),
              _card(t('where'), Icons.location_on_outlined, c, [_locationBox(c)]),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline_rounded, color: c, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t('note'), style: const TextStyle(color: Color(0xFF374151), height: 1.35))),
                ]),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
              ],
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -2))],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: c,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      const SizedBox(width: 10),
                      Flexible(child: Text(_busyText, overflow: TextOverflow.ellipsis)),
                    ])
                        : Text(t('submit'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _languageRow(Color c) => Row(children: [
    Text(t('lang'), style: const TextStyle(color: _muted, fontWeight: FontWeight.w600)),
    const SizedBox(width: 10),
    for (final l in const [('en', 'English'), ('hi', 'हिंदी'), ('gu', 'ગુજરાતી')]) ...[
      ChoiceChip(
        label: Text(l.$2),
        selected: _lang == l.$1,
        onSelected: _busy ? null : (_) => _setLanguage(l.$1),
        selectedColor: c.withValues(alpha: 0.15),
        labelStyle: TextStyle(color: _lang == l.$1 ? c : _ink, fontWeight: FontWeight.w600),
        side: BorderSide(color: _lang == l.$1 ? c : const Color(0xFFE5E7EB)),
        backgroundColor: Colors.white,
        showCheckmark: false,
      ),
      const SizedBox(width: 6),
    ],
  ]);

  Widget _card(String title, IconData icon, Color c, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: c, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
      ]),
      const SizedBox(height: 12),
      ...children,
    ]),
  );

  InputDecoration _input(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
  );

  Widget _photoRow(Color c) => SizedBox(
    height: 86,
    child: ListView(scrollDirection: Axis.horizontal, children: [
      for (var i = 0; i < _photos.length; i++)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(_photos[i].localPath), width: 86, height: 86, fit: BoxFit.cover),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: _busy ? null : () => setState(() => _photos.removeAt(i)),
                child: const CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ]),
        ),
      if (_photos.length < _maxPhotos) ...[
        _addTile(Icons.photo_camera_outlined, t('camera'), c, () => _addPhoto(ImageSource.camera)),
        const SizedBox(width: 8),
        _addTile(Icons.photo_library_outlined, t('gallery'), c, () => _addPhoto(ImageSource.gallery)),
      ],
    ]),
  );

  Widget _addTile(IconData icon, String label, Color c, VoidCallback onTap) => InkWell(
    onTap: _busy ? null : onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.35)),
        color: c.withValues(alpha: 0.04),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: c),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
      ]),
    ),
  );

  Widget _voiceRow(Color c) {
    if (_audioLocal != null && !_recording) {
      return Row(children: [
        Expanded(child: VoiceNotePlayer(localFilePath: _audioLocal, color: c)),
        IconButton(
          tooltip: 'Delete',
          onPressed: _busy
              ? null
              : () => setState(() {
            _audioLocal = null;
            _audioUploaded = null;
            _audioSeconds = 0;
          }),
          icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
        ),
      ]);
    }
    final mm = (_recSeconds ~/ 60).toString();
    final ss = (_recSeconds % 60).toString().padLeft(2, '0');
    return InkWell(
      onTap: _busy ? null : _toggleRecord,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _recording ? const Color(0xFFFEE2E2) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _recording ? const Color(0xFFDC2626) : c,
            child: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_recording ? t('recording') : t('recordHint'),
                style: TextStyle(color: _recording ? const Color(0xFFB91C1C) : _muted, fontWeight: FontWeight.w600)),
          ),
          if (_recording) Text('$mm:$ss / 2:00', style: const TextStyle(color: Color(0xFFB91C1C))),
        ]),
      ),
    );
  }

  Widget _timePicker(Color c) {
    final days = List.generate(7, (i) => DateUtils.dateOnly(DateTime.now()).add(Duration(days: i)));
    String dayLabel(DateTime d) {
      final today = DateUtils.dateOnly(DateTime.now());
      if (d == today) return t('today');
      if (d == today.add(const Duration(days: 1))) return t('tomorrow');
      return DateFormat('EEE d').format(d);
    }

    String slotLabel(int h) {
      String f(int x) => x == 12 ? '12 PM' : x > 12 ? '${x - 12} PM' : '$x AM';
      return '${f(h)} – ${f(h + 2)}';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _bigChoice(t('now'), Icons.flash_on_rounded, _isNow, c, () => setState(() => _isNow = true))),
        const SizedBox(width: 10),
        Expanded(
            child: _bigChoice(t('schedule'), Icons.event_rounded, !_isNow, c, () => setState(() => _isNow = false))),
      ]),
      if (!_isNow) ...[
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final d in days)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(dayLabel(d)),
                  selected: _day == d,
                  showCheckmark: false,
                  onSelected: (_) => setState(() {
                    _day = d;
                    if (_slotStartHour != null && !_slotAvailable(d, _slotStartHour!)) _slotStartHour = null;
                  }),
                  selectedColor: c.withValues(alpha: 0.15),
                  labelStyle: TextStyle(color: _day == d ? c : _ink, fontWeight: FontWeight.w600),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: _day == d ? c : const Color(0xFFE5E7EB)),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final h in _slotHours)
            ChoiceChip(
              label: Text(slotLabel(h)),
              selected: _slotStartHour == h,
              showCheckmark: false,
              onSelected: _slotAvailable(_day, h) ? (_) => setState(() => _slotStartHour = h) : null,
              selectedColor: c.withValues(alpha: 0.15),
              disabledColor: const Color(0xFFF3F4F6),
              labelStyle: TextStyle(
                color: !_slotAvailable(_day, h)
                    ? const Color(0xFFBDBDBD)
                    : _slotStartHour == h
                    ? c
                    : _ink,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: Colors.white,
              side: BorderSide(color: _slotStartHour == h ? c : const Color(0xFFE5E7EB)),
            ),
        ]),
      ],
    ]);
  }

  Widget _bigChoice(String label, IconData icon, bool selected, Color c, VoidCallback onTap) => InkWell(
    onTap: _busy ? null : onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: selected ? c.withValues(alpha: 0.10) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? c : Colors.transparent, width: 1.5),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 18, color: selected ? c : _muted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(color: selected ? c : _ink, fontWeight: FontWeight.w700)),
        ),
      ]),
    ),
  );

  Widget _locationBox(Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (_locLoading)
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 3),
      )
    else
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.place_rounded, color: _lat == null ? _muted : c),
        const SizedBox(width: 8),
        Expanded(
          child: Text(_lat == null ? t('noLoc') : _addressLine,
              style: TextStyle(color: _lat == null ? _muted : _ink, height: 1.35)),
        ),
      ]),
    const SizedBox(height: 8),
    OutlinedButton.icon(
      onPressed: _busy || _locLoading ? null : _useGps,
      icon: const Icon(Icons.my_location_rounded, size: 18),
      label: Text(t('gps')),
      style: OutlinedButton.styleFrom(
        foregroundColor: c,
        side: BorderSide(color: c.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    const SizedBox(height: 12),
    TextField(controller: _house, maxLength: 100, decoration: _input(t('house')).copyWith(counterText: '')),
    const SizedBox(height: 8),
    TextField(
        controller: _landmark, maxLength: 150, decoration: _input(t('landmark')).copyWith(counterText: '')),
  ]);
}
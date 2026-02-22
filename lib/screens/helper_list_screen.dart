import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SUB-SERVICE MODEL  (mirrors home screen's _SubService)
// ─────────────────────────────────────────────────────────────────────────────

class SubServiceItem {
  final String name;
  final IconData icon;
  const SubServiceItem(this.name, this.icon);
}

// ─────────────────────────────────────────────────────────────────────────────
// FIREBASE HELPER MODEL
// ─────────────────────────────────────────────────────────────────────────────

class FirebaseHelper {
  final String id;
  final String name;
  final String specialty;
  final String location;
  final double rating;
  final int reviews;
  final int experienceYears;
  final int jobsDone;
  final double startingPrice;
  final double distanceKm;
  final bool isOnline;
  final bool isBusy;
  final String? nextSlot;
  final String about;
  final List<String> skills;
  final String serviceType; // matches Firestore 'serviceType' field

  const FirebaseHelper({
    required this.id,
    required this.name,
    required this.specialty,
    required this.location,
    required this.rating,
    required this.reviews,
    required this.experienceYears,
    required this.jobsDone,
    required this.startingPrice,
    required this.distanceKm,
    required this.isOnline,
    this.isBusy = false,
    this.nextSlot,
    required this.about,
    required this.skills,
    required this.serviceType,
  });

  /// Build from Firestore document
  factory FirebaseHelper.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FirebaseHelper(
      id: doc.id,
      name: d['name'] ?? '',
      specialty: d['specialty'] ?? d['serviceType'] ?? '',
      location: d['location'] ?? 'Surat, Gujarat',
      rating: (d['rating'] ?? 0.0).toDouble(),
      reviews: (d['reviews'] ?? d['completedJobs'] ?? 0) as int,
      experienceYears: int.tryParse(
          (d['experience'] ?? '0').toString().replaceAll(RegExp(r'[^0-9]'), '')) ??
          0,
      jobsDone: (d['completedJobs'] ?? 0) as int,
      startingPrice: (d['pricePerHour'] ?? d['startingPrice'] ?? 0).toDouble(),
      distanceKm: (d['distanceKm'] ?? 1.0).toDouble(),
      isOnline: d['isAvailable'] ?? false,
      isBusy: d['isBusy'] ?? false,
      nextSlot: d['nextSlot'] as String?,
      about: d['about'] ??
          'Experienced professional offering quality service in ${d['serviceType'] ?? 'this category'}.',
      skills: List<String>.from(d['skills'] ?? []),
      serviceType: d['serviceType'] ?? '',
    );
  }

  /// First letter of name for avatar
  String get avatarInitial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER LIST SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class HelperListScreen extends StatefulWidget {
  /// The specific sub-service tapped (e.g. "Plumber", "Laptop Repair")
  final String serviceName;

  /// The parent category title (e.g. "Home Services", "Technical Services")
  final String categoryName;

  /// All sub-services in the parent category — used for the sidebar
  final List<SubServiceItem> subServices;

  final Color serviceColor;
  final Color serviceBgColor;
  final String categoryEmoji;

  const HelperListScreen({
    super.key,
    required this.serviceName,
    required this.categoryName,
    required this.subServices,
    required this.serviceColor,
    required this.serviceBgColor,
    required this.categoryEmoji,
  });

  @override
  State<HelperListScreen> createState() => _HelperListScreenState();
}

class _HelperListScreenState extends State<HelperListScreen> {
  late int _selectedSubIndex;
  String _sortBy = 'Nearest';

  /// Currently selected sub-service name (drives Firestore query)
  String get _activeService =>
      widget.subServices[_selectedSubIndex].name;

  @override
  void initState() {
    super.initState();
    // Default sidebar selection = the service that was tapped
    _selectedSubIndex = widget.subServices
        .indexWhere((s) => s.name == widget.serviceName);
    if (_selectedSubIndex < 0) _selectedSubIndex = 0;
  }

  // ── Firestore stream for helpers filtered by serviceType ──────────────────
  Stream<List<FirebaseHelper>> _helpersStream(String serviceType) {
    return FirebaseFirestore.instance
        .collection('helpers')
        .where('serviceType', isEqualTo: serviceType)
        .snapshots()
        .map((snap) => snap.docs.map(FirebaseHelper.fromFirestore).toList());
  }

  List<FirebaseHelper> _sorted(List<FirebaseHelper> list) {
    final copy = List<FirebaseHelper>.from(list);
    switch (_sortBy) {
      case 'Rating':
        copy.sort((a, b) => b.rating.compareTo(a.rating));
      case 'Price':
        copy.sort((a, b) => a.startingPrice.compareTo(b.startingPrice));
      case 'Nearest':
      default:
        copy.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    }
    return copy;
  }

  void _openProfile(FirebaseHelper helper) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => HelperProfileSheet(
        helper: helper,
        serviceColor: widget.serviceColor,
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text('Sort Helpers',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937))),
              const SizedBox(height: 12),
              for (final opt in ['Nearest', 'Rating', 'Price'])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Radio<String>(
                    value: opt,
                    groupValue: _sortBy,
                    activeColor: widget.serviceColor,
                    onChanged: (v) {
                      setState(() => _sortBy = v!);
                      Navigator.pop(context);
                    },
                  ),
                  title: Text(opt,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F8),
        body: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            _TopBar(
              title: widget.categoryName,
              onBack: () => Navigator.pop(context),
              onFilter: _showSortSheet,
            ),

            // ── Body: sidebar + helper list ───────────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Sidebar: actual sub-services of this category ─────
                  _SideBar(
                    items: widget.subServices,
                    selected: _selectedSubIndex,
                    serviceColor: widget.serviceColor,
                    onSelect: (i) => setState(() => _selectedSubIndex = i),
                  ),

                  // ── Helper cards from Firebase ────────────────────────
                  Expanded(
                    child: StreamBuilder<List<FirebaseHelper>>(
                      stream: _helpersStream(_activeService),
                      builder: (context, snap) {
                        // ── Loading ──────────────────────────────────────
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF7C3AED)),
                          );
                        }

                        // ── Error ────────────────────────────────────────
                        if (snap.hasError) {
                          return _ErrorState(error: snap.error.toString());
                        }

                        final helpers = _sorted(snap.data ?? []);
                        final onlineCount =
                            helpers.where((h) => !h.isBusy).length;

                        // ── Empty state (no Firebase data yet) ───────────
                        if (helpers.isEmpty) {
                          return _EmptyState(
                            serviceName: _activeService,
                            serviceColor: widget.serviceColor,
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                              child: Row(
                                children: [
                                  const Text(
                                    'AVAILABLE HELPERS',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF9CA3AF),
                                        letterSpacing: 1.2),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: widget.serviceColor
                                          .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$onlineCount Nearby',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: widget.serviceColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Helper list
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    14, 0, 14, 100),
                                physics: const ClampingScrollPhysics(),
                                itemCount: helpers.length,
                                separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                                itemBuilder: (_, i) => RepaintBoundary(
                                  child: _HelperCard(
                                    helper: helpers[i],
                                    serviceColor: widget.serviceColor,
                                    onTap: () => _openProfile(helpers[i]),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack, onFilter;

  const _TopBar(
      {required this.title, required this.onBack, required this.onFilter});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 20, color: Color(0xFF1F2937)),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937))),
              ),
              IconButton(
                onPressed: onFilter,
                icon: const Icon(Icons.tune_rounded,
                    size: 22, color: Color(0xFF4B5563)),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR  — shows the ACTUAL sub-services of the selected category
// ─────────────────────────────────────────────────────────────────────────────

class _SideBar extends StatelessWidget {
  final List<SubServiceItem> items;
  final int selected;
  final Color serviceColor;
  final ValueChanged<int> onSelect;

  const _SideBar({
    required this.items,
    required this.selected,
    required this.serviceColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      color: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        physics: const ClampingScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final active = i == selected;
          final item = items[i];
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: active
                    ? serviceColor.withOpacity(0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: active
                    ? Border.all(color: serviceColor.withOpacity(0.25))
                    : null,
              ),
              child: Column(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: active
                          ? serviceColor.withOpacity(0.15)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon,
                        size: 22,
                        color: active ? serviceColor : const Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 5),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      item.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w700,
                        color: active ? serviceColor : const Color(0xFF9CA3AF),
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _HelperCard extends StatefulWidget {
  final FirebaseHelper helper;
  final Color serviceColor;
  final VoidCallback onTap;

  const _HelperCard(
      {required this.helper, required this.serviceColor, required this.onTap});

  @override
  State<_HelperCard> createState() => _HelperCardState();
}

class _HelperCardState extends State<_HelperCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.helper;
    final color = widget.serviceColor;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_pressed ? 0.97 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(_pressed ? 0.10 : 0.05),
              blurRadius: _pressed ? 6 : 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar + Info ─────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Stack(
                    children: [
                      Container(
                        width: 62, height: 62,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: color.withOpacity(0.2), width: 1.5),
                        ),
                        child: Center(
                          child: Text(h.avatarInitial,
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: color)),
                        ),
                      ),
                      if (h.isOnline && !h.isBusy)
                        Positioned(
                          right: 2, bottom: 2,
                          child: Container(
                            width: 12, height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A),
                              shape: BoxShape.circle,
                              border:
                              Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(h.name,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937)),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.star_rounded,
                                size: 15, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 2),
                            Text(h.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937))),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${h.specialty} • ${h.experienceYears} yrs exp',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF6B7280)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 12, color: color),
                            const SizedBox(width: 3),
                            Text(
                              '${h.distanceKm.toStringAsFixed(1)} KM AWAY',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF9CA3AF),
                                  letterSpacing: 0.3),
                            ),
                            const SizedBox(width: 8),
                            Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                    color: Color(0xFFD1D5DB),
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text(
                              '${h.reviews} REVIEWS',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF9CA3AF),
                                  letterSpacing: 0.3),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              const SizedBox(height: 10),

              // ── Price + Action ────────────────────────────────────────
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.isBusy ? 'NEXT SLOT' : 'STARTING AT',
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9CA3AF),
                            letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 2),
                      h.isBusy
                          ? Text(h.nextSlot ?? 'Soon',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937)))
                          : Text('₹${h.startingPrice.toInt()}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937))),
                    ],
                  ),
                  const Spacer(),

                  // Busy badge
                  if (h.isBusy) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 12, color: Color(0xFFDC2626)),
                          SizedBox(width: 4),
                          Text('BUSY NOW',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFDC2626),
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Book / Notify button
                  GestureDetector(
                    onTap: widget.onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 11),
                      decoration: BoxDecoration(
                        color: h.isBusy ? const Color(0xFFF3F4F6) : color,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: h.isBusy
                            ? []
                            : [
                          BoxShadow(
                              color: color.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Text(
                        h.isBusy ? 'Notify Me' : 'Book Now',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: h.isBusy
                              ? const Color(0xFF6B7280)
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE  (no helpers found in Firestore for this service)
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String serviceName;
  final Color serviceColor;
  const _EmptyState(
      {required this.serviceName, required this.serviceColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: serviceColor.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child:
              Icon(Icons.search_off_rounded, size: 38, color: serviceColor),
            ),
            const SizedBox(height: 20),
            Text('No helpers yet for\n"$serviceName"',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Be the first to register as a helper\nor check back soon.',
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF9CA3AF), height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 16),
            const Text('Could not load helpers',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937))),
            const SizedBox(height: 8),
            Text(error,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF9CA3AF)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER PROFILE BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class HelperProfileSheet extends StatelessWidget {
  final FirebaseHelper helper;
  final Color serviceColor;

  const HelperProfileSheet(
      {super.key, required this.helper, required this.serviceColor});

  @override
  Widget build(BuildContext context) {
    final h = helper;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      snap: true,
      snapSizes: const [0.88, 0.95],
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 30,
                offset: Offset(0, -4))
          ],
        ),
        child: Column(
          children: [
            // ── Scrollable body ───────────────────────────────────────────
            Expanded(
              child: CustomScrollView(
                controller: scrollCtrl,
                physics: const ClampingScrollPhysics(),
                slivers: [
                  // Drag handle
                  SliverToBoxAdapter(
                    child: Center(
                      child: Container(
                        margin:
                        const EdgeInsets.only(top: 10, bottom: 4),
                        width: 42, height: 4,
                        decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                  ),

                  // Toolbar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                  color: Color(0xFFF3F4F6),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded,
                                  size: 18, color: Color(0xFF4B5563)),
                            ),
                          ),
                          const Expanded(
                            child: Text('Helper Profile',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937))),
                          ),
                          GestureDetector(
                            onTap: () {},
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                  color: Color(0xFFF3F4F6),
                                  shape: BoxShape.circle),
                              child: Icon(Icons.share_rounded,
                                  size: 18, color: serviceColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                      child:
                      Divider(height: 1, color: Color(0xFFF3F4F6))),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // Avatar
                  SliverToBoxAdapter(
                    child: Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 96, height: 96,
                            decoration: BoxDecoration(
                              color: serviceColor.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: serviceColor.withOpacity(0.3),
                                  width: 3),
                            ),
                            child: Center(
                              child: Text(h.avatarInitial,
                                  style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: serviceColor)),
                            ),
                          ),
                          if (h.isOnline)
                            Positioned(
                              right: 4, bottom: 4,
                              child: Container(
                                width: 18, height: 18,
                                decoration: BoxDecoration(
                                  color: h.isBusy
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF16A34A),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Name + specialty + location
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      child: Column(
                        children: [
                          Text(h.name,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937)),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.verified_rounded,
                                  size: 15, color: serviceColor),
                              const SizedBox(width: 5),
                              Text(h.specialty,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: serviceColor)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 14, color: Color(0xFF9CA3AF)),
                              const SizedBox(width: 4),
                              Text(h.location,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF9CA3AF))),
                            ],
                          ),
                          if (h.isBusy) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.schedule_rounded,
                                      size: 14, color: Color(0xFFDC2626)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'BUSY NOW • Next: ${h.nextSlot ?? ""}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFDC2626)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Stats row
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                      const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Row(
                        children: [
                          _StatBubble(
                            label: 'RATING',
                            top: h.rating.toStringAsFixed(1),
                            mid: '★',
                            midColor: const Color(0xFFF59E0B),
                            bottom: '${h.reviews} Reviews',
                          ),
                          const SizedBox(width: 10),
                          _StatBubble(
                            label: 'EXPERIENCE',
                            top: '${h.experienceYears}+',
                            mid: 'Years',
                            midColor: serviceColor,
                            bottom: 'Expert Level',
                          ),
                          const SizedBox(width: 10),
                          _StatBubble(
                            label: 'JOBS',
                            top: '${h.jobsDone}+',
                            mid: 'Done',
                            midColor: const Color(0xFF16A34A),
                            bottom: '100% Success',
                          ),
                        ],
                      ),
                    ),
                  ),

                  // About
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                      const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.handyman_rounded,
                                  size: 20, color: serviceColor),
                              const SizedBox(width: 8),
                              const Text('About Expertise',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937))),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(h.about,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF4B5563),
                                  height: 1.6)),
                        ],
                      ),
                    ),
                  ),

                  // Skills
                  if (h.skills.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                        const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.workspace_premium_rounded,
                                    size: 20, color: serviceColor),
                                const SizedBox(width: 8),
                                const Text('Skills & Specialties',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1F2937))),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: h.skills
                                  .map((s) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: serviceColor
                                      .withOpacity(0.08),
                                  borderRadius:
                                  BorderRadius.circular(20),
                                  border: Border.all(
                                      color: serviceColor
                                          .withOpacity(0.2)),
                                ),
                                child: Text(s,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: serviceColor)),
                              ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Pricing
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                      const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: serviceColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: serviceColor.withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.currency_rupee_rounded,
                                size: 20, color: serviceColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text('Starting Price',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: serviceColor,
                                          fontWeight: FontWeight.w600)),
                                  const Text(
                                      'Final price depends on job complexity',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF9CA3AF))),
                                ],
                              ),
                            ),
                            Text('₹${h.startingPrice.toInt()}',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: serviceColor)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),

            // ── Fixed Book Now button ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 16,
                      offset: Offset(0, -4))
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      // TODO: implement booking flow
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Booking ${h.name}...'),
                        backgroundColor: serviceColor,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ));
                    },
                    icon: const Icon(Icons.calendar_month_rounded,
                        size: 20, color: Colors.white),
                    label: Text(
                      h.isBusy ? 'Notify Me When Available' : 'Book Now',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      h.isBusy ? const Color(0xFF6B7280) : serviceColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT BUBBLE
// ─────────────────────────────────────────────────────────────────────────────

class _StatBubble extends StatelessWidget {
  final String top, mid, bottom, label;
  final Color midColor;

  const _StatBubble({
    required this.top,
    required this.mid,
    required this.bottom,
    required this.label,
    required this.midColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
        const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9CA3AF),
                    letterSpacing: 0.8)),
            const SizedBox(height: 6),
            Text(top,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937))),
            const SizedBox(height: 2),
            Text(mid,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: midColor)),
            const SizedBox(height: 2),
            Text(bottom,
                style: const TextStyle(
                    fontSize: 9, color: Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }
}
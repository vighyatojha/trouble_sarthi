import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SUB-SERVICE ITEM
// ─────────────────────────────────────────────────────────────────────────────

class SubServiceItem {
  final String name;
  final IconData icon;
  const SubServiceItem(this.name, this.icon);
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE TYPE ALIAS MAP
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, String> _kServiceTypeAliases = {
  'plumber'          : 'Plumbing',
  'electrician'      : 'Electrical',
  'carpenter'        : 'Carpentry',
  'painter'          : 'Painting',
  'cleaner'          : 'Cleaning',
  'ac repair'        : 'AC Repair',
  'ro repair'        : 'RO Repair',
  'appliance repair' : 'Appliance Repair',
  'car mechanic'     : 'Car Mechanic',
  'bike mechanic'    : 'Bike Mechanic',
  'towing service'   : 'Towing Service',
  'puncture repair'  : 'Puncture Repair',
  'car wash'         : 'Car Wash',
  'mobile repair'    : 'Mobile Repair',
  'laptop repair'    : 'Laptop Repair',
  'cctv install'     : 'CCTV Install',
  'wifi install'     : 'WiFi Install',
  'software help'    : 'Software Help',
  'deep cleaning'    : 'Deep Cleaning',
  'pest control'     : 'Pest Control',
};

String _resolveServiceType(String sidebarName) {
  final key = sidebarName.trim().toLowerCase();
  final resolved = _kServiceTypeAliases[key] ?? sidebarName;
  debugPrint('[Firestore] "$sidebarName" → querying serviceType == "$resolved"');
  return resolved;
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER LIST SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class HelperListScreen extends StatefulWidget {
  final String serviceName;
  final String categoryName;
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
  String _sortBy = 'Rating';

  String get _activeService => widget.subServices[_selectedSubIndex].name;

  @override
  void initState() {
    super.initState();
    _selectedSubIndex = widget.subServices
        .indexWhere((s) => s.name == widget.serviceName);
    if (_selectedSubIndex < 0) _selectedSubIndex = 0;
  }

  Stream<List<HelperModel>> _helpersStream(String sidebarName) {
    final queryValue = _resolveServiceType(sidebarName);
    return FirebaseFirestore.instance
        .collection('helpers')
        .where('serviceType', isEqualTo: queryValue)
        .snapshots()
        .map((snap) {
      debugPrint('[Firestore] got ${snap.docs.length} doc(s) for "$queryValue"');
      return snap.docs.map((doc) {
        try {
          return HelperModel.fromFirestore(
              doc.data() as Map<String, dynamic>, doc.id);
        } catch (e) {
          debugPrint('[Firestore] parse error for ${doc.id}: $e');
          return null;
        }
      }).whereType<HelperModel>().toList();
    });
  }

  List<HelperModel> _sorted(List<HelperModel> list) {
    final copy = List<HelperModel>.from(list);
    switch (_sortBy) {
      case 'Rating':
        copy.sort((a, b) => b.rating.compareTo(a.rating));
      case 'Price':
        copy.sort((a, b) => a.pricePerHour.compareTo(b.pricePerHour));
      case 'Experience':
        copy.sort((a, b) {
          int parse(String s) =>
              int.tryParse(RegExp(r'(\d+)').firstMatch(s)?.group(1) ?? '0') ?? 0;
          return parse(b.experience).compareTo(parse(a.experience));
        });
    }
    return copy;
  }

  void _openProfile(HelperModel helper) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _HelperProfileSheet(
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
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Sort By',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937))),
                const SizedBox(height: 12),
                for (final opt in ['Rating', 'Price', 'Experience'])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Radio<String>(
                      value: opt,
                      groupValue: _sortBy,
                      activeColor: widget.serviceColor,
                      onChanged: (v) {
                        setState(() => _sortBy = v!);
                        setSheet(() {});
                        Navigator.pop(ctx);
                      },
                    ),
                    title: Text(opt,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
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
        backgroundColor: const Color(0xFFF2F4F8),
        body: Column(
          children: [
            _TopBar(
              title: widget.categoryName,
              serviceColor: widget.serviceColor,
              onBack: () => Navigator.pop(context),
              onFilter: _showSortSheet,
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SideBar(
                    items: widget.subServices,
                    selected: _selectedSubIndex,
                    serviceColor: widget.serviceColor,
                    onSelect: (i) =>
                        setState(() => _selectedSubIndex = i),
                  ),
                  Expanded(
                    child: StreamBuilder<List<HelperModel>>(
                      stream: _helpersStream(_activeService),
                      builder: (context, snap) {
                        if (snap.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 36, height: 36,
                                  child: CircularProgressIndicator(
                                    color: widget.serviceColor,
                                    strokeWidth: 3,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text('Finding helpers…',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: widget.serviceColor
                                            .withOpacity(0.7),
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          );
                        }
                        if (snap.hasError) {
                          return _ErrorState(
                              error: snap.error.toString());
                        }
                        final helpers = _sorted(snap.data ?? []);
                        if (helpers.isEmpty) {
                          return _EmptyState(
                            serviceName: _activeService,
                            serviceColor: widget.serviceColor,
                          );
                        }
                        final availableCount =
                            helpers.where((h) => h.isAvailable).length;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  14, 16, 14, 10),
                              child: Row(
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'AVAILABLE HELPERS',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.grey.shade500,
                                            letterSpacing: 1.2),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${helpers.length} found nearby',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1F2937)),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: widget.serviceColor
                                          .withOpacity(0.1),
                                      borderRadius:
                                      BorderRadius.circular(20),
                                      border: Border.all(
                                          color: widget.serviceColor
                                              .withOpacity(0.2)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6, height: 6,
                                          decoration: BoxDecoration(
                                            color: widget.serviceColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          '$availableCount Nearby',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: widget.serviceColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    14, 0, 14, 100),
                                physics: const ClampingScrollPhysics(),
                                itemCount: helpers.length,
                                separatorBuilder: (_, __) =>
                                const SizedBox(height: 14),
                                itemBuilder: (_, i) => RepaintBoundary(
                                  child: _HelperCard(
                                    helper: helpers[i],
                                    serviceColor: widget.serviceColor,
                                    onTap: () =>
                                        _openProfile(helpers[i]),
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
  final Color serviceColor;
  final VoidCallback onBack, onFilter;

  const _TopBar({
    required this.title,
    required this.serviceColor,
    required this.onBack,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 20, color: Color(0xFF1F2937)),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937))),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.search_rounded,
                    size: 22, color: Color(0xFF4B5563)),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              GestureDetector(
                onTap: onFilter,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: serviceColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.tune_rounded,
                      size: 20, color: serviceColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR
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
      width: 78,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10),
        physics: const ClampingScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final active = i == selected;
          final item = items[i];
          return GestureDetector(
            onTap: () => onSelect(i),
            child: Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(
                      vertical: 3, horizontal: 6),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active
                        ? serviceColor.withOpacity(0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          color: active
                              ? serviceColor.withOpacity(0.15)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(item.icon,
                            size: 22,
                            color: active
                                ? serviceColor
                                : const Color(0xFF9CA3AF)),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 3),
                        child: Text(
                          item.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            color: active
                                ? serviceColor
                                : const Color(0xFFB0B8C8),
                            letterSpacing: 0.4,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (active)
                  Positioned(
                    left: 0, top: 8, bottom: 8,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: serviceColor,
                        borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(4)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER CARD  — matches reference design
// Layout: name+badge+specialty top-left, circular photo top-right
//         star rating + availability pill mid-left
//         phone + location bottom-left, BOOK NOW button bottom-right
//         price + jobs chips at very bottom
// ─────────────────────────────────────────────────────────────────────────────

class _HelperCard extends StatefulWidget {
  final HelperModel helper;
  final Color serviceColor;
  final VoidCallback onTap;

  const _HelperCard({
    required this.helper,
    required this.serviceColor,
    required this.onTap,
  });

  @override
  State<_HelperCard> createState() => _HelperCardState();
}

class _HelperCardState extends State<_HelperCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.helper;
    final color = widget.serviceColor;
    final initial = h.name.isNotEmpty ? h.name[0].toUpperCase() : '?';

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_pressed ? 0.97 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_pressed ? 0.04 : 0.07),
              blurRadius: _pressed ? 4 : 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: info left + circular photo right ───────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name + verified check
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                h.name,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111827),
                                    letterSpacing: -0.3),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 18, height: 18,
                              decoration: BoxDecoration(
                                color: h.isAvailable
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF9CA3AF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded,
                                  size: 11, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),

                        // Specialty description
                        Text(
                          '${h.serviceType} specialist • ${h.experience} exp',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),

                        // Star rating + availability pill
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 16,
                                color: Color(0xFFFBBF24)),
                            const SizedBox(width: 3),
                            Text(
                              h.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937)),
                            ),
                            Text(
                              ' Rating',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade400),
                            ),
                            const SizedBox(width: 8),
                            _AvailabilityPill(
                                isAvailable: h.isAvailable),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Circular profile photo
                  Container(
                    width: 82, height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.08),
                      border: Border.all(
                          color: color.withOpacity(0.15), width: 2),
                    ),
                    child: h.profileImage != null
                        ? ClipOval(
                      child: Image.network(
                        h.profileImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(initial,
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: color)),
                        ),
                      ),
                    )
                        : Center(
                      child: Text(initial,
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: color)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.shade100),
              const SizedBox(height: 12),

              // ── Row 2: phone + location left | BOOK NOW right ─────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (h.phoneNumber.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(Icons.phone_outlined,
                                  size: 13,
                                  color: Colors.grey.shade500),
                              const SizedBox(width: 5),
                              Text(
                                h.phoneNumber,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                        ],
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 13,
                                color: Colors.grey.shade500),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                h.location,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // BOOK NOW button (matches reference: green, rounded, BOOK/NOW stacked)
                  GestureDetector(
                    onTap: widget.onTap,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 13),
                      decoration: BoxDecoration(
                        color: h.isAvailable
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: h.isAvailable
                            ? [
                          BoxShadow(
                              color: const Color(0xFF16A34A)
                                  .withOpacity(0.28),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ]
                            : [],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            h.isAvailable ? 'BOOK' : 'NOTIFY',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: h.isAvailable
                                  ? Colors.white
                                  : const Color(0xFF9CA3AF),
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            h.isAvailable ? 'NOW' : 'ME',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: h.isAvailable
                                  ? Colors.white
                                  : const Color(0xFF9CA3AF),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Row 3: price chip + jobs chip ─────────────────────────
              Row(
                children: [
                  _InfoChip(
                    label: 'Starting at ₹${h.pricePerHour.toInt()}/hr',
                    color: color,
                    bgColor: color.withOpacity(0.08),
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    label: '${h.completedJobs} jobs done',
                    color: Colors.grey.shade600,
                    bgColor: const Color(0xFFF3F4F6),
                    icon: Icons.check_circle_outline_rounded,
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
// SMALL REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _AvailabilityPill extends StatelessWidget {
  final bool isAvailable;
  const _AvailabilityPill({required this.isAvailable});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isAvailable
            ? const Color(0xFFEFF6FF)
            : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAvailable
              ? const Color(0xFFBFDBFE)
              : const Color(0xFFFED7AA),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAvailable
                ? Icons.access_time_rounded
                : Icons.block_rounded,
            size: 10,
            color: isAvailable
                ? const Color(0xFF3B82F6)
                : const Color(0xFFF97316),
          ),
          const SizedBox(width: 4),
          Text(
            isAvailable ? 'Available' : 'Busy',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isAvailable
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFFF97316),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color, bgColor;
  final IconData? icon;

  const _InfoChip({
    required this.label,
    required this.color,
    required this.bgColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER PROFILE SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _HelperProfileSheet extends StatelessWidget {
  final HelperModel helper;
  final Color serviceColor;

  const _HelperProfileSheet(
      {required this.helper, required this.serviceColor});

  @override
  Widget build(BuildContext context) {
    final h = helper;
    final color = serviceColor;
    final initial = h.name.isNotEmpty ? h.name[0].toUpperCase() : '?';

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
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
                color: Color(0x14000000),
                blurRadius: 30,
                offset: Offset(0, -4))
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                controller: scrollCtrl,
                physics: const ClampingScrollPhysics(),
                slivers: [
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
                                  size: 18,
                                  color: Color(0xFF4B5563)),
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
                          const SizedBox(width: 36),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                      child: Divider(
                          height: 1, color: Color(0xFFF3F4F6))),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // Profile card — same layout as list card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.07),
                                blurRadius: 16,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(h.name,
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight:
                                                FontWeight.bold,
                                                color:
                                                Color(0xFF111827))),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 20, height: 20,
                                        decoration: BoxDecoration(
                                          color: h.isAvailable
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFF9CA3AF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                            Icons.check_rounded,
                                            size: 12,
                                            color: Colors.white),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${h.serviceType} specialist with ${h.experience} of experience.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                        height: 1.5),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          size: 16,
                                          color: Color(0xFFFBBF24)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${h.rating.toStringAsFixed(1)} Rating',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1F2937)),
                                      ),
                                      const SizedBox(width: 10),
                                      _AvailabilityPill(
                                          isAvailable: h.isAvailable),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  if (h.phoneNumber.isNotEmpty)
                                    Row(
                                      children: [
                                        Icon(Icons.phone_outlined,
                                            size: 14,
                                            color: Colors.grey.shade500),
                                        const SizedBox(width: 6),
                                        Text(h.phoneNumber,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color:
                                                Colors.grey.shade700,
                                                fontWeight:
                                                FontWeight.w500)),
                                      ],
                                    ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on_outlined,
                                          size: 14,
                                          color: Colors.grey.shade500),
                                      const SizedBox(width: 6),
                                      Text(h.location,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                              fontWeight:
                                              FontWeight.w500)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Container(
                              width: 90, height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.withOpacity(0.08),
                                border: Border.all(
                                    color: color.withOpacity(0.15),
                                    width: 2),
                              ),
                              child: h.profileImage != null
                                  ? ClipOval(
                                  child: Image.network(
                                      h.profileImage!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          Center(
                                            child: Text(initial,
                                                style: TextStyle(
                                                    fontSize: 30,
                                                    fontWeight:
                                                    FontWeight
                                                        .bold,
                                                    color: color)),
                                          )))
                                  : Center(
                                child: Text(initial,
                                    style: TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                        color: color)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // Stats row
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                      const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Row(
                        children: [
                          _StatBubble(
                            label: 'RATING',
                            value: h.rating.toStringAsFixed(1),
                            sub: 'out of 5',
                            color: const Color(0xFFFBBF24),
                            icon: Icons.star_rounded,
                          ),
                          const SizedBox(width: 10),
                          _StatBubble(
                            label: 'EXPERIENCE',
                            value: h.experience,
                            sub: 'in field',
                            color: color,
                            icon: Icons.workspace_premium_rounded,
                          ),
                          const SizedBox(width: 10),
                          _StatBubble(
                            label: 'JOBS',
                            value: '${h.completedJobs}',
                            sub: 'completed',
                            color: const Color(0xFF16A34A),
                            icon: Icons.check_circle_outline_rounded,
                          ),
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
                            const Text('Skills & Specialties',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937))),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: h.skills
                                  .map((s) => Container(
                                padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6),
                                decoration: BoxDecoration(
                                  color:
                                  color.withOpacity(0.08),
                                  borderRadius:
                                  BorderRadius.circular(20),
                                  border: Border.all(
                                      color: color
                                          .withOpacity(0.2)),
                                ),
                                child: Text(s,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight:
                                        FontWeight.w600,
                                        color: color)),
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
                          color: color.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: color.withOpacity(0.12)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.currency_rupee_rounded,
                                size: 22, color: color),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text('Price per Hour',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: color,
                                          fontWeight:
                                          FontWeight.w600)),
                                  const Text(
                                      'Final price depends on job complexity',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color:
                                          Color(0xFF9CA3AF))),
                                ],
                              ),
                            ),
                            Text('₹${h.pricePerHour.toInt()}',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: color)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                      child: SizedBox(height: 20)),
                ],
              ),
            ),

            // Book Now button
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
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(
                        content: Text(h.isAvailable
                            ? 'Booking ${h.name}…'
                            : 'You will be notified when ${h.name} is available'),
                        backgroundColor: color,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12)),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ));
                    },
                    icon: Icon(
                        h.isAvailable
                            ? Icons.calendar_month_rounded
                            : Icons.notifications_outlined,
                        size: 20,
                        color: Colors.white),
                    label: Text(
                      h.isAvailable
                          ? 'Book Now'
                          : 'Notify Me When Available',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: h.isAvailable
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF6B7280),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(28)),
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
  final String label, value, sub;
  final Color color;
  final IconData icon;

  const _StatBubble({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0F0F0)),
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
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(sub,
                style: const TextStyle(
                    fontSize: 9, color: Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
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
                  shape: BoxShape.circle),
              child: Icon(Icons.search_off_rounded,
                  size: 38, color: serviceColor),
            ),
            const SizedBox(height: 20),
            Text('No helpers for\n"$serviceName"',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
                'Check back soon or try a different service.',
                style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                    height: 1.5),
                textAlign: TextAlign.center),
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
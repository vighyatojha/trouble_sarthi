import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import '../service/location_controller.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Color(0xFF1A1A2E)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text('Maps only work on mobile'),
        ),
      );
    }
    return const _MobileLocationPicker();
  }
}

class _MobileLocationPicker extends StatefulWidget {
  const _MobileLocationPicker();

  @override
  State<_MobileLocationPicker> createState() => _MobileLocationPickerState();
}

class _MobileLocationPickerState extends State<_MobileLocationPicker>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final LocationController _controller = LocationController();

  late AnimationController _pinCtrl;
  late Animation<double> _pinBounce;

  final TextEditingController _searchCtrl = TextEditingController();
  List<Location> _suggestions = [];
  bool _showSuggestions = false;
  bool _isSearching = false;

  // ✅ SATELLITE TOGGLE STATE
  MapType _mapType = MapType.normal;

  static const _initialCamera = CameraPosition(
    target: LatLng(21.1702, 72.8311), // Surat
    zoom: 15.0,
  );

  @override
  void initState() {
    super.initState();
    _pinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pinBounce = Tween<double>(begin: 0, end: -14)
        .animate(CurvedAnimation(parent: _pinCtrl, curve: Curves.easeOut));

    _controller.initialize().then((_) => _animateToLocation());
    _controller.addListener(_rebuild);
  }

  void _rebuild() {
    if (!mounted) return;
    if (_controller.isLoading) {
      _pinCtrl.forward();
    } else {
      _pinCtrl.reverse();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _controller.dispose();
    _pinCtrl.dispose();
    _mapController?.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController c) {
    _mapController = c;
    _applyMapStyle(c);
    _animateToLocation();
  }

  void _animateToLocation() {
    final loc = _controller.currentLocation;
    if (loc == null || _mapController == null) return;
    _mapController!.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: LatLng(loc.latitude, loc.longitude), zoom: 15),
    ));
  }

  void _applyMapStyle(GoogleMapController c) {
    if (_mapType == MapType.normal) {
      c.setMapStyle('''[
        {"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},
        {"featureType":"transit","elementType":"labels","stylers":[{"visibility":"off"}]}
      ]''');
    }
  }

  void _onCameraMove(CameraPosition _) {
    if (!_pinCtrl.isAnimating) _pinCtrl.forward();
  }

  void _onCameraIdle() {
    if (_mapController == null) return;
    final size = MediaQuery.of(context).size;
    final sheetHeight = size.height * 0.38;
    final visibleMapHeight = size.height - sheetHeight;

    _mapController!
        .getLatLng(ScreenCoordinate(
      x: (size.width / 2).round(),
      y: (visibleMapHeight / 2).round(),
    ))
        .then((center) => _controller.onCameraIdle(center));
  }

  Future<void> _goToCurrent() async {
    await _controller.fetchCurrentLocation();
    final loc = _controller.currentLocation;
    if (loc == null || _mapController == null) return;
    _mapController!.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: LatLng(loc.latitude, loc.longitude), zoom: 16),
    ));
  }

  Future<void> _onSearch(String query) async {
    if (query.length < 3) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await locationFromAddress(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _showSuggestions = results.isNotEmpty;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _showSuggestions = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSuggestion(Location loc) {
    FocusScope.of(context).unfocus();
    setState(() => _showSuggestions = false);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(loc.latitude, loc.longitude), 16),
    );
    _controller.onCameraIdle(LatLng(loc.latitude, loc.longitude));
  }

  Future<void> _confirm() async {
    final ok = await _controller.confirmLocation();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(ok ? Icons.check_circle : Icons.error_outline,
            color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Text(
          ok ? 'Location saved!' : (_controller.errorMessage ?? 'Save failed.'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ]),
      backgroundColor: ok ? const Color(0xFF6B5CE7) : Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
    if (ok) Navigator.pop(context, _controller.selectedLocation);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final sheetH = size.height * 0.38;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // MAP
          GoogleMap(
            initialCameraPosition: _initialCamera,
            onMapCreated: _onMapCreated,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            padding: EdgeInsets.only(bottom: sheetH),
            mapType: _mapType, // ✅ THIS CONTROLS SATELLITE/NORMAL
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
              ),
            },
          ),

          // CENTER PIN
          Positioned(
            left: 0,
            right: 0,
            top: ((size.height - sheetH) / 2) - 56,
            child: IgnorePointer(
              child: Center(
                child: AnimatedBuilder(
                  animation: _pinBounce,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, _pinBounce.value),
                    child: const _MapPin(),
                  ),
                ),
              ),
            ),
          ),

          // SEARCH BAR
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Icon(Icons.arrow_back_ios_rounded,
                                color: Color(0xFF1A1A2E), size: 20),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: _onSearch,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1A1A2E)),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Search your location...',
                              hintStyle: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 14),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: _isSearching
                              ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFF6B5CE7)))
                              : GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _showSuggestions = false);
                            },
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                  color: Color(0xFFDEE2E6),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded,
                                  color: Color(0xFF6C757D), size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_showSuggestions && _suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _suggestions.length.clamp(0, 4),
                        separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFF1F3F5)),
                        itemBuilder: (_, i) {
                          final loc = _suggestions[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.location_on_rounded,
                                color: Color(0xFF6B5CE7), size: 20),
                            title: Text(
                              '${loc.latitude.toStringAsFixed(4)}, '
                                  '${loc.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            onTap: () => _selectSuggestion(loc),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // "SET LOCATION" BUBBLE
          Positioned(
            left: 0,
            right: 0,
            top: ((size.height - sheetH) / 2) - 96,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B5CE7),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6B5CE7).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text('Set Location',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          letterSpacing: 0.3)),
                ),
              ),
            ),
          ),

          // ✅✅✅ SATELLITE TOGGLE BUTTON (TOP BUTTON) ✅✅✅
          Positioned(
            right: 16,
            bottom: sheetH + 80, // Above GPS button
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _mapType = _mapType == MapType.normal
                        ? MapType.satellite
                        : MapType.normal;
                  });
                  if (_mapType == MapType.normal) {
                    _applyMapStyle(_mapController!);
                  }
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _mapType == MapType.normal
                        ? Icons.satellite_alt
                        : Icons.map_outlined,
                    color: const Color(0xFF6B5CE7),
                    size: 26,
                  ),
                ),
              ),
            ),
          ),

          // GPS BUTTON (BOTTOM BUTTON)
          Positioned(
            right: 16,
            bottom: sheetH + 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _goToCurrent,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _controller.isLoading
                      ? const Center(
                      child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Color(0xFF6B5CE7))))
                      : const Icon(Icons.my_location_rounded,
                      color: Color(0xFF6B5CE7), size: 26),
                ),
              ),
            ),
          ),

          // BOTTOM SHEET
          Align(
            alignment: Alignment.bottomCenter,
            child: _BottomSheet(
              address: _controller.displayAddress,
              subAddress: _controller.displaySubAddress,
              isLoading: _controller.isLoading,
              isSaving: _controller.isSaving,
              selectedLabel: _controller.selectedLabel,
              onLabelSelected: _controller.selectLabel,
              onChangeTap: _goToCurrent,
              onConfirm: _confirm,
              safeBottom: safeBottom,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin();
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF6B5CE7),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF6B5CE7).withOpacity(0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 26),
        ),
        CustomPaint(size: const Size(16, 10), painter: _TailPainter()),
        Container(
          width: 10,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(size.width / 2 - 6, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width / 2 + 6, 0)
        ..close(),
      Paint()..color = const Color(0xFF6B5CE7),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _BottomSheet extends StatelessWidget {
  final String address, subAddress, selectedLabel;
  final bool isLoading, isSaving;
  final ValueChanged<String> onLabelSelected;
  final VoidCallback onChangeTap, onConfirm;
  final double safeBottom;

  const _BottomSheet({
    required this.address,
    required this.subAddress,
    required this.isLoading,
    required this.isSaving,
    required this.selectedLabel,
    required this.onLabelSelected,
    required this.onChangeTap,
    required this.onConfirm,
    required this.safeBottom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Color(0x1A000000), blurRadius: 30, offset: Offset(0, -8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFDEE2E6),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B5CE7).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.location_on_rounded,
                      color: Color(0xFF6B5CE7), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CURRENT LOCATION',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFADB5BD),
                              letterSpacing: 1.2)),
                      const SizedBox(height: 4),
                      isLoading
                          ? _Shimmer(width: 200, height: 18)
                          : Text(address,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E),
                              height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      isLoading
                          ? _Shimmer(width: 140, height: 13)
                          : Text(subAddress,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6C757D))),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onChangeTap,
                  style: TextButton.styleFrom(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  child: const Text('Change',
                      style: TextStyle(
                          color: Color(0xFF6B5CE7),
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _Chip(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    value: 'home',
                    selected: selectedLabel == 'home',
                    onTap: () => onLabelSelected('home')),
                const SizedBox(width: 10),
                _Chip(
                    icon: Icons.work_rounded,
                    label: 'Office',
                    value: 'office',
                    selected: selectedLabel == 'office',
                    onTap: () => onLabelSelected('office')),
                const SizedBox(width: 10),
                _Chip(
                    icon: Icons.add_rounded,
                    label: 'Add',
                    value: 'custom',
                    selected: selectedLabel == 'custom',
                    onTap: () => onLabelSelected('custom')),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.only(left: 24, right: 24, bottom: safeBottom + 20),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isSaving ? null : onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B5CE7),
                  disabledBackgroundColor:
                  const Color(0xFF6B5CE7).withOpacity(0.55),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
                child: isSaving
                    ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Confirm Location',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded,
                        size: 20, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6B5CE7).withOpacity(0.1)
              : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected ? const Color(0xFF6B5CE7) : const Color(0xFFE9ECEF),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color:
                selected ? const Color(0xFF6B5CE7) : const Color(0xFF6C757D)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected
                        ? const Color(0xFF6B5CE7)
                        : const Color(0xFF495057))),
          ],
        ),
      ),
    );
  }
}

class _Shimmer extends StatefulWidget {
  final double width, height;
  const _Shimmer({required this.width, required this.height});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        duration: const Duration(milliseconds: 900), vsync: this)
      ..repeat(reverse: true);
    _a = Tween<double>(begin: 0.3, end: 0.8)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) => Container(
      width: widget.width,
      height: widget.height,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: Color.lerp(
            const Color(0xFFE9ECEF), const Color(0xFFF8F9FA), _a.value),
        borderRadius: BorderRadius.circular(6),
      ),
    ),
  );
}
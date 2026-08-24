import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:demo_cst/screens/supervisor/site_entry_page.dart';
import 'package:demo_cst/services/location_service.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/app_storage_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

class SupervisorVerificationPage extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;

  const SupervisorVerificationPage({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<SupervisorVerificationPage> createState() =>
      _SupervisorVerificationPageState();
}

class _SupervisorVerificationPageState
    extends State<SupervisorVerificationPage> {
  Position? _currentPosition;
  File? _selectedImage;
  bool _locationChecked = false;
  bool _locationValid = false;
  String? _locationError;
  String? _photoError;
  bool _isLoading = false;

  List<Map<String, dynamic>> _assignedSites = [];
  Map<String, dynamic>? _selectedSite;
  double? _siteLat;
  double? _siteLng;
  double? _distanceFromSite;
  final double _allowedDistance = 100.0;

  Color get primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    _fetchAssignedSites();
  }

  Future<void> _fetchAssignedSites() async {
    setState(() => _isLoading = true);
    try {
      final query = await FirestoreService.getCollection('siteSupervisorMap')
          .where('Supervisor ID', isEqualTo: widget.supervisorId)
          .get();

      List<Map<String, dynamic>> sites = [];
      for (var doc in query.docs) {
        final siteId = doc['site']?.toString() ?? '';
        if (siteId.isEmpty) continue;

        final siteDoc = await FirestoreService.getCollection('Site').doc(siteId).get();
        if (siteDoc.exists) {
          final siteData = siteDoc.data()!;
          sites.add({
            'siteId': siteId,
            'siteName': siteData['location'] ?? siteData['siteName'] ?? siteId,
            'latitude': siteData['latitude'],
            'longitude': siteData['longitude'],
            'location': siteData['location'] ?? '',
          });
        }
      }

      // If no mapping found by ID, attempt lookup by supervisor name
      if (sites.isEmpty) {
        final nameQuery = await FirestoreService.getCollection('Site')
            .where('supervisor', isEqualTo: widget.supervisorName)
            .get();

        for (var doc in nameQuery.docs) {
          final data = doc.data();
          sites.add({
            'siteId': doc.id,
            'siteName': data['location'] ?? data['siteName'] ?? doc.id,
            'latitude': data['latitude'],
            'longitude': data['longitude'],
            'location': data['location'] ?? '',
          });
        }
      }

      if (mounted) {
        setState(() {
          _assignedSites = sites;
          if (sites.isNotEmpty) {
            _selectedSite = sites[0];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Failed to fetch assigned sites: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    if (_selectedSite == null) {
      AppTheme.showErrorToast(context, 'Please select an assigned site first.');
      return;
    }

    setState(() {
      _locationChecked = false;
      _locationError = null;
      _isLoading = true;
    });

    try {
      final rawLat = _selectedSite!['latitude'];
      final rawLng = _selectedSite!['longitude'];

      if (rawLat == null || rawLng == null) {
        setState(() {
          _locationError = 'Site coordinates not configured in master database.';
          _isLoading = false;
        });
        return;
      }

      _siteLat = (rawLat as num).toDouble();
      _siteLng = (rawLng as num).toDouble();

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'GPS Location services are disabled on your device.';
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      final hasPermission = await LocationService.handleLocationPermission(context);
      if (!hasPermission) {
        if (mounted) {
          setState(() {
            _locationError = 'Location permission is required for site verification.';
            _isLoading = false;
          });
        }
        return;
      }

      Position? tempPosition;
      try {
        tempPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        tempPosition = await Geolocator.getLastKnownPosition();
        tempPosition ??= await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 5),
          ),
        );
      }

      final position = tempPosition;
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        _siteLat!,
        _siteLng!,
      );
      final match = distance <= _allowedDistance;

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _locationChecked = true;
          _distanceFromSite = distance;
          _locationValid = match;
          _locationError = _locationValid
              ? null
              : 'You are currently ${distance.toStringAsFixed(0)}m away. You must be within $_allowedDistance meters of the site.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Failed to acquire accurate GPS position: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    setState(() {
      _photoError = null;
      _isLoading = true;
    });

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        if (mounted) {
          setState(() {
            _selectedImage = File(pickedFile.path);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _photoError = 'No photo captured.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _photoError = 'Error accessing camera: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _uploadPhotoWithMetadata() async {
    if (_selectedImage == null || _currentPosition == null) return null;

    try {
      final url = await AppStorageService.uploadSupervisorVerificationPhoto(
        supervisorId: widget.supervisorId,
        imageFile: _selectedImage!,
        siteId: _selectedSite?['siteId'],
      );

      if (url == null || url.isEmpty) {
        throw Exception('Storage upload returned empty URL');
      }

      await FirestoreService.getCollection('supervisorPhotoLogs').add({
        'photoUrl': url,
        'timestamp': FieldValue.serverTimestamp(),
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'supervisorId': widget.supervisorId,
        'supervisorName': widget.supervisorName,
        'siteId': _selectedSite?['siteId'],
      });

      return url;
    } catch (e) {
      if (mounted) {
        setState(() {
          _photoError = 'Photo upload failed: $e';
        });
      }
      return null;
    }
  }

  void _verifyAndContinue() async {
    if (!_locationChecked || !_locationValid) {
      AppTheme.showErrorToast(
        context,
        _locationError ?? 'Please verify your GPS location at the site first.',
      );
      return;
    }

    if (_selectedImage == null) {
      AppTheme.showErrorToast(context, 'Site presence photo verification required.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _uploadPhotoWithMetadata();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SiteEntryPage(
            userName: widget.supervisorName,
            userDetails: {
              'supervisorId': widget.supervisorId,
              'siteId': _selectedSite?['siteId'],
              'location': _selectedSite?['location'],
              'siteName': _selectedSite?['siteName'],
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        AppTheme.showErrorToast(context, 'Verification failed. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _proceedDirectly() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SiteEntryPage(
          userName: widget.supervisorName,
          userDetails: {
            'supervisorId': widget.supervisorId,
            'siteId': _selectedSite?['siteId'],
            'location': _selectedSite?['location'],
            'siteName': _selectedSite?['siteName'],
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Supervisor Expense & Site Verification',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                darkAccent,
                Color.alphaBlend(
                  primaryColor.withValues(alpha: 0.35),
                  darkAccent,
                ),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: _selectedSite != null ? _proceedDirectly : null,
            icon: const Icon(Icons.bolt_rounded, size: 16, color: Colors.white70),
            label: const Text(
              'FAST ENTRY',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 680),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 1. Header Information Banner ──────────────────────────
                  _buildHeaderBanner(darkAccent),
                  const SizedBox(height: 16),

                  // ── 2. Site Selection Card ────────────────────────────────
                  _buildSiteSelectorCard(darkAccent),
                  const SizedBox(height: 16),

                  // ── 3. Step 1: Geofence Location Verification Card ─────────
                  _buildGeofenceCard(darkAccent),
                  const SizedBox(height: 16),

                  // ── 4. Step 2: Site Photo Verification Card ───────────────
                  _buildPhotoVerificationCard(darkAccent),
                  const SizedBox(height: 24),

                  // ── 5. Main Action Button ─────────────────────────────────
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _verifyAndContinue,
                      icon: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified_user_rounded, size: 20),
                      label: Text(
                        _isLoading ? 'VERIFYING PRESENCE...' : 'VERIFY & ENTER SITE EXPENSES',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(Color darkAccent) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, darkAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.security_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Site Presence Verification',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: darkAccent,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Supervisor: ${widget.supervisorName} (${widget.supervisorId.isNotEmpty ? widget.supervisorId : "ACTIVE"})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteSelectorCard(Color darkAccent) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_city_rounded, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Assigned Construction Site',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: darkAccent,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Color(0xFFF1F5F9), height: 1),
          ),
          if (_assignedSites.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Map<String, dynamic>>(
                  value: _selectedSite,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                  items: _assignedSites.map((site) {
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: site,
                      child: Text(
                        site['siteName'] ?? site['siteId'],
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (site) {
                    setState(() {
                      _selectedSite = site;
                      _locationChecked = false;
                      _locationValid = false;
                      _distanceFromSite = null;
                      _locationError = null;
                    });
                  },
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No sites assigned to this supervisor account.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGeofenceCard(Color darkAccent) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.gps_fixed_rounded, color: Color(0xFF0284C7), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Step 1: Geofence Location Check',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: darkAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Ensure you are physically on site within 100 meters to verify attendance and expense entries.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
          ),
          const SizedBox(height: 14),

          // Location check button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _getCurrentLocation,
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: const Text(
                'Check GPS Location',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),

          // Feedback Status
          if (_locationChecked) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _locationValid ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _locationValid ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _locationValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: _locationValid ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _locationValid ? 'Location Verified & Matched' : 'Location Mismatch',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _locationValid ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                        ),
                        if (_distanceFromSite != null)
                          Text(
                            'Distance to site center: ${_distanceFromSite!.toStringAsFixed(1)} meters',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: _locationValid ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_locationError != null && !_locationChecked) ...[
            const SizedBox(height: 10),
            Text(
              _locationError!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoVerificationCard(Color darkAccent) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF8B5CF6), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Step 2: Site Presence Photo',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: darkAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Capture a live photo from the site to complete daily attendance and expense logging.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
          ),
          const SizedBox(height: 14),

          // Photo capture button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickImage,
              icon: const Icon(Icons.photo_camera_rounded, size: 18),
              label: Text(
                _selectedImage == null ? 'Capture Live Site Photo' : 'Retake Site Photo',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),

          if (_selectedImage != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Image.file(
                    _selectedImage!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 14),
                        SizedBox(width: 4),
                        Text(
                          'PHOTO CAPTURED',
                          style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_photoError != null) ...[
            const SizedBox(height: 10),
            Text(
              _photoError!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
            ),
          ],
        ],
      ),
    );
  }
}

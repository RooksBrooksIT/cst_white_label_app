import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:demo_cst/screens/site_entry_page.dart';
import 'package:demo_cst/services/location_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:demo_cst/services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';

class SupervisorVerificationPage extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;

  const SupervisorVerificationPage(
      {super.key, required this.supervisorId, required this.supervisorName});

  @override
  _SupervisorVerificationPageState createState() =>
      _SupervisorVerificationPageState();
}

class _SupervisorVerificationPageState extends State<SupervisorVerificationPage>
    with TickerProviderStateMixin {
  Position? _currentPosition;
  File? _selectedImage;
  bool _locationChecked = false;
  bool _locationValid = false;
  String? _locationError;
  String? _photoError;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  List<Map<String, dynamic>> _assignedSites = [];
  Map<String, dynamic>? _selectedSite;
  double? _siteLat;
  double? _siteLng;
  double? _distanceFromSite;
  final double _allowedDistance = 100.0;

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
    _tabController = TabController(length: 1, vsync: this);
    _fetchAssignedSites();
  }

  Future<void> _fetchAssignedSites() async {
    try {
      final query = await FirestoreService
          .getCollection('siteSupervisorMap')
          .where('supervisor', isEqualTo: widget.supervisorName)
          .get();
      List<Map<String, dynamic>> sites = [];
      for (var doc in query.docs) {
        final siteId = doc['site'];
        final siteDoc = await FirestoreService
            .getCollection('Site')
            .doc(siteId)
            .get();
        if (siteDoc.exists) {
          final siteData = siteDoc.data()!;
          sites.add({
            'siteId': siteId,
            'siteName': siteData['location'] ?? siteId,
            'latitude': siteData['latitude'],
            'longitude': siteData['longitude'],
            'location': siteData['location'] ?? '',
          });
        }
      }
      if (mounted) {
        setState(() {
          _assignedSites = sites;
          if (sites.isNotEmpty) {
            _selectedSite = sites[0];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Failed to fetch assigned sites: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (mounted) {
      setState(() {
        _locationChecked = false;
        _locationError = null;
        _isLoading = true;
      });
    }

    try {
      if (_selectedSite == null) {
        if (mounted) {
          setState(() {
            _locationError = 'Please select a site.';
            _isLoading = false;
          });
        }
        return;
      }
      _siteLat = (_selectedSite!['latitude'] as num).toDouble();
      _siteLng = (_selectedSite!['longitude'] as num).toDouble();

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationError = 'Location services are disabled.';
            _isLoading = false;
          });
        }
        return;
      }

      final hasPermission = await LocationService.handleLocationPermission(context);
      if (!hasPermission) {
        if (mounted) {
          setState(() {
            _locationError = 'Location permissions are required.';
            _isLoading = false;
          });
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        _siteLat!,
        _siteLng!,
      );
      bool match =
          _isWithinAllowedDistance(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _locationChecked = true;
          _distanceFromSite = distance;
          _locationValid = match;
          _locationError = _locationValid
              ? null
              : 'You must be at the project Site (within $_allowedDistance meters)';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Failed to get location: $e';
          _isLoading = false;
        });
      }
    }
  }

  bool _isWithinAllowedDistance(double lat, double lng) {
    if (_siteLat == null || _siteLng == null) return false;
    double distance =
        Geolocator.distanceBetween(lat, lng, _siteLat!, _siteLng!);
    return distance <= _allowedDistance;
  }

  Future<void> _pickImage() async {
    if (mounted) {
      setState(() {
        _photoError = null;
        _isLoading = true;
      });
    }

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);

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
            _photoError = 'No photo selected.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _photoError = 'Error capturing image: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _uploadPhotoWithMetadata() async {
    if (_selectedImage == null || _currentPosition == null) return null;

    try {
      final fileName =
          'supervisor_photos/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(_selectedImage!);
      final url = await ref.getDownloadURL();

      await FirestoreService.getCollection('supervisorPhotoLogs').add({
        'photoUrl': url,
        'timestamp': FieldValue.serverTimestamp(),
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'username': widget.supervisorName,
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
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    if (!_locationChecked || !_locationValid) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _showErrorDialog(_locationError ?? 'Location verification required.');
      return;
    }

    if (_selectedImage == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _showErrorDialog('Photo upload required.');
      return;
    }

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
            },
          ),
        ),
      );
      return;
    } catch (e) {
      _showErrorDialog('Verification failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Verification Failed'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _skipVerification() {
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
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Supervisor Verification',
      onBack: () => Navigator.pop(context),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _skipVerification,
          child: Text(
            'SKIP',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
      
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: TabBarView(
          controller: _tabController,
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_assignedSites.isNotEmpty)
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedSite,
                      items: _assignedSites.map((site) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: site,
                          child: Text(
                            site['siteName'] ?? site['siteId'],
                            style: const TextStyle(fontSize: 16),
                          ),
                        );
                      }).toList(),
                      onChanged: (site) {
                        if (mounted) {
                          setState(() {
                            _selectedSite = site;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Select Site',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  if (_assignedSites.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'No sites assigned to you.',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 16),
                      ),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _getCurrentLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Check Location',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_locationChecked)
                    Column(
                      children: [
                        Text(
                          _locationValid
                              ? '✅ Location verified'
                              : '❌ Location mismatch',
                          style: TextStyle(
                            color: _locationValid ? Colors.green : Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        if (_distanceFromSite != null)
                          Text(
                            'Distance: ${_distanceFromSite!.toStringAsFixed(2)} meters',
                            style: const TextStyle(fontSize: 14),
                          ),
                      ],
                    ),
                  if (_locationError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _locationError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14),
                      ),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _pickImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Take Photo',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_selectedImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _selectedImage!,
                        height: 220,
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (_photoError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _photoError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14),
                      ),
                    ),
                  const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _verifyAndContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                
                                strokeWidth: 3,
                              ),
                            )
                          : const Text(
                              'Verify & Continue to Site Entry',
                              style: TextStyle(
                                  
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
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

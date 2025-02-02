import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'donate_screen.dart';
import 'request_screen.dart';
import 'profile_screen.dart';
import 'feed_screen.dart';
import '../utils/animations.dart';
import 'recipe_screen.dart';
import '../widgets/donation_action_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' show cos, sqrt, asin, log;
import 'donation_details_screen.dart';
import 'donations_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  bool _isLoading = true;
  final _searchController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final Completer<GoogleMapController> _controller = Completer();
  Set<Circle> _circles = {};
  LatLng? _currentLocation;
  Timer? _refreshTimer;
  final double _radiusInKm = 10.0;

  final List<Widget> _screens = [
    const FeedScreen(),
    const DonateScreen(),
    const RequestScreen(),
    const RecipeScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _initializeMap();
    _animationController.forward();
    
    // Refresh donations every 2 minutes instead of 1
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _fetchNearbyDonations();
    });
  }

  Future<void> _initializeMap() async {
    await _checkLocationPermission();
    await _getCurrentLocation();
    _initializeMarkers();
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required to show nearby food locations'),
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoading = false;
        _currentLocation = LatLng(position.latitude, position.longitude);
        _circles = {
          Circle(
            circleId: const CircleId('radius'),
            center: _currentLocation!,
            radius: _radiusInKm * 1000, // Convert km to meters
            fillColor: Colors.blue.withOpacity(0.1),
            strokeColor: Colors.blue,
            strokeWidth: 1,
          ),
        };
      });

      if (_mapController != null) {
        // Calculate the zoom level based on the circle radius
        final double zoomLevel = 14.5 - log(_radiusInKm) / log(2);
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _currentLocation!,
              zoom: zoomLevel,
            ),
          ),
        );
      }
      _fetchNearbyDonations();
    } catch (e) {
      print("Error getting location: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _initializeMarkers() {
    // Add current location marker if available
    if (_currentPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(title: 'You are here'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }
  }

  BitmapDescriptor _getMarkerIcon(String type) {
    switch (type) {
      case 'fridge':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case 'foodbank':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case 'restaurant':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }

  Future<void> _searchLocation() async {
    try {
      List<Location> locations = await locationFromAddress(_searchController.text);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final newPosition = LatLng(location.latitude, location.longitude);
        
        setState(() {
          _markers.add(
            Marker(
              markerId: MarkerId(_searchController.text),
              position: newPosition,
              infoWindow: InfoWindow(title: _searchController.text),
            ),
          );
        });

        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: newPosition,
              zoom: 15,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching location: $e')),
        );
      }
    }
  }

  Future<void> _fetchNearbyDonations() async {
    if (_currentLocation == null) {
      print('Current location is null, skipping donation fetch');
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('active_donations')
          .get();

      if (!mounted) return;

      Set<Marker> newMarkers = {};
      
      // Add current location marker
      newMarkers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          zIndex: 1,
        ),
      );

      // Add donation markers
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['location'] == null) continue;
        
        final location = data['location'] as Map<String, dynamic>;
        if (location['latitude'] == null || location['longitude'] == null) continue;

        final donationLocation = LatLng(
          location['latitude'] as double,
          location['longitude'] as double,
        );

        // Check if donation is within radius
        final distance = _calculateDistance(_currentLocation!, donationLocation);
        if (distance <= _radiusInKm) {
          // Check if this is the current user's donation
          final isCurrentUserDonation = data['userId'] == currentUser.uid;

          newMarkers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: donationLocation,
              icon: isCurrentUserDonation 
                  ? BitmapDescriptor.defaultMarker  // Black for current user's donations
                  : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),  // Green for other users' donations
              zIndex: 2,
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (context) => Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Food Image
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Hero(
                            tag: 'food_image_${data['foodItem']}',
                            child: Image.network(
                              data['imageUrl'] ?? 'https://firebasestorage.googleapis.com/v0/b/hunger-donatefood.appspot.com/o/default_food_image.jpg?alt=media',
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 150,
                                  color: Colors.grey[200],
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.restaurant, size: 40, color: Colors.grey[400]),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Food Image',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Hero(
                                      tag: 'food_name_${data['foodItem']}',
                                      child: Material(
                                        color: Colors.transparent,
                                        child: Text(
                                          data['foodItem'],
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: data['price'] == 'Free' 
                                          ? Colors.green.withOpacity(0.1)
                                          : Theme.of(context).primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      data['price'],
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: data['price'] == 'Free' 
                                            ? Colors.green 
                                            : Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'By ${data['donor']}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${data['quantity']} • ${data['startTime']} - ${data['endTime']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DonationDetailsScreen(
                                          donationId: doc.id,
                                          donationData: data,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    backgroundColor: Theme.of(context).primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'View Details',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            ],
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

      if (mounted) {
        setState(() {
          _markers = newMarkers;
        });
      }
    } catch (e) {
      print('Error fetching donations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error loading donations. Please try again.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Calculate distance between two points in km
  double _calculateDistance(LatLng point1, LatLng point2) {
    var p = 0.017453292519943295; // Math.PI / 180
    var c = cos;
    var a = 0.5 -
        c((point2.latitude - point1.latitude) * p) / 2 +
        c(point1.latitude * p) *
            c(point2.latitude * p) *
            (1 - c((point2.longitude - point1.longitude) * p)) /
            2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  void _showFullScreenMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
      appBar: AppBar(
            title: const Text('Nearby Donations'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? const LatLng(0, 0),
              zoom: 14.5,
            ),
            onMapCreated: (controller) {
              controller.setMapStyle('''
                [
                  {
                    "featureType": "poi",
                    "elementType": "labels",
                    "stylers": [{"visibility": "off"}]
                  },
                  {
                    "featureType": "transit",
                    "elementType": "labels",
                    "stylers": [{"visibility": "off"}]
                  }
                ]
              ''');
              controller.animateCamera(
                CameraUpdate.newLatLngZoom(
                  _currentLocation!,
                  14.5,
                ),
              );
            },
            markers: _markers,
            circles: _circles,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
            compassEnabled: true,
            minMaxZoomPreference: const MinMaxZoomPreference(10, 18),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Welcome and Search Section
          StaggeredSlideTransition(
            animation: _fadeAnimation,
            index: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${user?.displayName?.split(' ')[0] ?? 'User'}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              "Let's combat hunger together!",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedIndex = 4; // Navigate to profile
                          });
                        },
                        child: Hero(
                          tag: 'profile_image',
                          child: CircleAvatar(
                            radius: 24,
                            backgroundImage: user?.photoURL != null
                                ? NetworkImage(user!.photoURL!)
                                : null,
                            child: user?.photoURL == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: (_) => _searchLocation(),
                      decoration: InputDecoration(
                        hintText: 'Search for food donations',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _searchLocation,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Map Section
          StaggeredSlideTransition(
            animation: _fadeAnimation,
            index: 1,
            child: GestureDetector(
              onTap: _showFullScreenMap,
              child: Container(
                height: 250,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _currentLocation ?? const LatLng(37.7749, -122.4194),
                          zoom: 14.5,
                        ),
                        onMapCreated: (controller) {
                          _controller.complete(controller);
                          setState(() {
                            _mapController = controller;
                            // Apply custom map style to hide unnecessary elements
                            controller.setMapStyle('''
                              [
                                {
                                  "featureType": "poi",
                                  "elementType": "labels",
                                  "stylers": [{"visibility": "off"}]
                                },
                                {
                                  "featureType": "transit",
                                  "elementType": "labels",
                                  "stylers": [{"visibility": "off"}]
                                }
                              ]
                            ''');
                          });
                          // Initialize markers after map is created
                          _fetchNearbyDonations();
                        },
                        markers: _markers,
                        circles: _circles,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        compassEnabled: false,
                        tiltGesturesEnabled: false,
                        rotateGesturesEnabled: false,
                        zoomGesturesEnabled: false,
                        scrollGesturesEnabled: false,
                        mapType: MapType.normal,
                        minMaxZoomPreference: const MinMaxZoomPreference(10, 18),
                      ),
                    ),
                    // Add refresh and fullscreen buttons
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton.small(
                            onPressed: () async {
                              setState(() {
                                _isLoading = true;
                              });
                              await _getCurrentLocation();
                              await _fetchNearbyDonations();
                              setState(() {
                                _isLoading = false;
                              });
                            },
                            heroTag: 'refresh_map',
                            child: _isLoading 
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton.small(
                            onPressed: _showFullScreenMap,
                            heroTag: 'fullscreen_map',
                            child: const Icon(Icons.fullscreen),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Action Buttons
          StaggeredSlideTransition(
            animation: _fadeAnimation,
            index: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedIndex = 1;
                        });
                        // Trigger the donation dialog in the next frame
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            showDialog(
                              context: context,
                              builder: (context) => DonationActionDialog(
                                onCreateNew: () {
                                  Navigator.pop(context);
                                  // Show create donation dialog
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Create Donation'),
                                      content: const Text('Donation creation form will be implemented here.'),
        actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                onManage: () {
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Donate Food',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
            onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DonationsListScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.volunteer_activism),
                      label: const Text('Receive Food'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Available Donations Section (Free items only)
          StaggeredSlideTransition(
            animation: _fadeAnimation,
            index: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Available Donation's Near You",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_currentLocation != null)
                        Text(
                          'Within ${_radiusInKm.toStringAsFixed(1)} km',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildAvailableDonations(),
                ],
              ),
            ),
          ),

          // New to Buy Section (Paid items only)
          StaggeredSlideTransition(
            animation: _fadeAnimation,
            index: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'New to Buy',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildNewToBuy(),
                ],
              ),
            ),
          ),

          // Statistics Cards Section
          StaggeredSlideTransition(
            animation: _fadeAnimation,
            index: 5,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Active Users Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[400]!, Colors.blue[600]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.people,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '1,234',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Active Users',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Total Donations Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green[400]!, Colors.green[600]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.volunteer_activism,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '5,678',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Total Donations',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFoodDonationCard(String donationId, Map<String, dynamic> data, {bool isPaidSection = false}) {
    final bool isPaid = data['price'] != 'Free';
    // Don't show paid items in free section and vice versa
    if (isPaidSection != isPaid) return const SizedBox.shrink();

    return Container(
      width: 180,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          Hero(
            tag: 'food_image_${data['foodItem']}',
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                image: DecorationImage(
                  image: NetworkImage(
                    data['imageUrl'] ?? 'https://firebasestorage.googleapis.com/v0/b/hunger-donatefood.appspot.com/o/default_food_image.jpg?alt=media',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // Content Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title and Info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'food_name_${data['foodItem']}',
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            data['foodItem'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['donor'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data['quantity'],
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),

                  // Price and Action Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? Theme.of(context).primaryColor.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          data['price'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isPaid
                                ? Theme.of(context).primaryColor
                                : Colors.green,
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DonationDetailsScreen(
                                  donationId: donationId,
                                  donationData: data,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isPaid ? 'Buy' : 'Claim',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
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
        ],
      ),
    );
  }

  Widget _buildAvailableDonations() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('active_donations')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Something went wrong',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // Filter out current user's donations and paid donations
        final donations = snapshot.data?.docs
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['userId'] != currentUser.uid && data['price'] == 'Free';
            })
            .take(5)
            .toList() ?? [];
        
        if (donations.isEmpty) {
          return Center(
            child: Column(
              children: [
                Icon(Icons.no_food, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No active donations nearby',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: donations.length,
            itemBuilder: (context, index) {
              final doc = donations[index];
              final data = doc.data() as Map<String, dynamic>;
              return Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 0 : 16,
                  right: index == donations.length - 1 ? 0 : 0,
                ),
                child: _buildFoodDonationCard(doc.id, data),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildNewToBuy() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('active_donations')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Something went wrong',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // Filter for paid donations only
        final donations = snapshot.data?.docs
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['userId'] != currentUser.uid && data['price'] != 'Free';
            })
            .take(5)
            .toList() ?? [];
        
        if (donations.isEmpty) {
          return Center(
            child: Column(
              children: [
                Icon(Icons.shopping_bag, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No items available to buy',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: donations.length,
            itemBuilder: (context, index) {
              final doc = donations[index];
              final data = doc.data() as Map<String, dynamic>;
              return Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 0 : 16,
                  right: index == donations.length - 1 ? 0 : 0,
                ),
                child: _buildFoodDonationCard(doc.id, data, isPaidSection: true),
              );
            },
          ),
        );
      },
    );
  }

  Color _getLocationColor(String type) {
    switch (type) {
      case 'fridge':
        return Colors.blue;
      case 'foodbank':
        return Colors.green;
      case 'restaurant':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getLocationIcon(String type) {
    switch (type) {
      case 'fridge':
        return Icons.kitchen;
      case 'foodbank':
        return Icons.store;
      case 'restaurant':
        return Icons.restaurant;
      default:
        return Icons.place;
    }
  }

  Widget _wrapWithAnimation(Widget screen, int index) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(index),
        child: screen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _wrapWithAnimation(
        _selectedIndex == 0 ? _buildHomeContent() : _screens[_selectedIndex],
        _selectedIndex,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            // Reset animation controller for home screen content
            if (index == 0) {
              _animationController.reset();
              _animationController.forward();
            }
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.volunteer_activism),
            label: 'Donate',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.food_bank),
            label: 'Request',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Recipe',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mapController?.dispose();
    _searchController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }
} 
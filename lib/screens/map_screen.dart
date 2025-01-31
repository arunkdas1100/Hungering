import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

const kGoogleApiKey = "AIzaSyA5wfaEXqzrxeTzv0dKfd3XQtNy1f0wfCs";
final homeScaffoldKey = GlobalKey<ScaffoldState>();
final searchScaffoldKey = GlobalKey<ScaffoldState>();

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  final _searchController = TextEditingController();
  MapType _currentMapType = MapType.normal;
  
  // Example food locations (replace with real data from your backend)
  final List<Map<String, dynamic>> _foodLocations = [
    {
      'id': '1',
      'title': 'Community Fridge',
      'type': 'fridge',
      'position': const LatLng(37.7749, -122.4194),
      'description': 'Available 24/7, maintained by local community',
    },
    {
      'id': '2',
      'title': 'Food Bank Central',
      'type': 'foodbank',
      'position': const LatLng(37.7839, -122.4084),
      'description': 'Open Mon-Fri 9AM-5PM',
    },
    {
      'id': '3',
      'title': 'Restaurant Donation Point',
      'type': 'restaurant',
      'position': const LatLng(37.7939, -122.4184),
      'description': 'Surplus food available after 8PM',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _checkLocationPermission();
    await _getCurrentLocation();
    _initializeMarkers();
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isDenied) {
      // Handle permission denied
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required to show nearby food locations'),
        ),
      );
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
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _initializeMarkers() {
    // Add markers for food locations
    for (var location in _foodLocations) {
      _markers.add(
        Marker(
          markerId: MarkerId(location['id']),
          position: location['position'],
          infoWindow: InfoWindow(
            title: location['title'],
            snippet: location['description'],
          ),
          icon: _getMarkerIcon(location['type']),
        ),
      );
    }
    
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching location: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      key: homeScaffoldKey,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(37.7749, -122.4194),
              zoom: 14,
            ),
            onMapCreated: (controller) {
              setState(() {
                _mapController = controller;
              });
            },
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapType: _currentMapType,
            zoomControlsEnabled: true,
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search location...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onSubmitted: (_) => _searchLocation(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _searchLocation,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Community Fridges', true),
                          _buildFilterChip('Food Banks', true),
                          _buildFilterChip('Restaurants', true),
                          _buildFilterChip('Donation Points', true),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'add_location',
            onPressed: () => _addNewLocation(),
            child: const Icon(Icons.add_location),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'my_location',
            onPressed: () => _goToMyLocation(),
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    if (_currentPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 15,
          ),
        ),
      );
    }
  }

  void _addNewLocation() {
    // TODO: Implement adding new food donation location
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Location'),
        content: const Text('This feature will be implemented soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isActive) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isActive,
        onSelected: (bool selected) {
          // TODO: Implement filter functionality
        },
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Add this method to calculate distance between two points
  double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  // Add this method to show route to selected location
  void _showRouteToLocation(LatLng destination) {
    final origin = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final distance = _calculateDistance(origin, destination);
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Distance: ${(distance / 1000).toStringAsFixed(2)} km',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Open in Google Maps
                final url = 'https://www.google.com/maps/dir/?api=1&origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}';
                launchUrl(Uri.parse(url));
              },
              child: const Text('Get Directions'),
            ),
          ],
        ),
      ),
    );
  }

  // Add clustering for markers when they are close together
  void _updateMarkerClusters() {
    final zoom = _mapController?.zoom ?? 14;
    if (zoom < 13) {  // Cluster markers when zoomed out
      // Group nearby markers
      final clusters = <LatLng, List<Marker>>{};
      for (var marker in _markers) {
        var added = false;
        for (var center in clusters.keys) {
          if (_calculateDistance(center, marker.position) < 2000) { // 2km radius
            clusters[center]!.add(marker);
            added = true;
            break;
          }
        }
        if (!added) {
          clusters[marker.position] = [marker];
        }
      }
      
      // Create cluster markers
      setState(() {
        _markers.clear();
        clusters.forEach((center, markers) {
          if (markers.length > 1) {
            _markers.add(
              Marker(
                markerId: MarkerId('cluster_${center.latitude}'),
                position: center,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
                infoWindow: InfoWindow(
                  title: '${markers.length} locations',
                  snippet: 'Tap to zoom in',
                ),
                onTap: () {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(center, 15),
                  );
                },
              ),
            );
          } else {
            _markers.add(markers.first);
          }
        });
      });
    }
  }

  void _showLocationDetails(Map<String, dynamic> location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.8,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: controller,
            children: [
              Text(
                location['title'],
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(location['description']),
              const SizedBox(height: 16),
              if (_currentPosition != null)
                Text(
                  'Distance: ${(_calculateDistance(
                    LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    location['position'],
                  ) / 1000).toStringAsFixed(2)} km',
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _showRouteToLocation(location['position']),
                child: const Text('Get Directions'),
              ),
              // Add more details like:
              // - Available food items
              // - Operating hours
              // - Contact information
              // - Photos
              // - Reviews/Ratings
            ],
          ),
        ),
      ),
    );
  }

  // Add map style controls
  void _changeMapStyle() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Normal'),
            onTap: () {
              setState(() => _currentMapType = MapType.normal);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.satellite),
            title: const Text('Satellite'),
            onTap: () {
              setState(() => _currentMapType = MapType.satellite);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.terrain),
            title: const Text('Terrain'),
            onTap: () {
              setState(() => _currentMapType = MapType.terrain);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
} 
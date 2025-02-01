import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import './location_picker_dialog.dart';
import '../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DonationFormDialog extends StatefulWidget {
  const DonationFormDialog({super.key});

  @override
  State<DonationFormDialog> createState() => _DonationFormDialogState();
}

class _DonationFormDialogState extends State<DonationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _organizationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _foodItemController = TextEditingController();
  final _quantityController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _amountController = TextEditingController();

  bool _isFree = true;
  DateTime _startTime = DateTime.now().add(const Duration(minutes: 30));
  DateTime _endTime = DateTime.now().add(const Duration(hours: 2));
  LatLng? _selectedLocation;
  bool _isLoading = false;
  GoogleMapController? _mapController;

  final String _pixabayApiKey = '48590142-c8b8b7020e19f571b5c296fff';
  String? _foodImageUrl;

  @override
  void dispose() {
    _nameController.dispose();
    _organizationController.dispose();
    _phoneController.dispose();
    _foodItemController.dispose();
    _quantityController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _amountController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation!, 15),
      );
    } catch (e) {
      // Handle location error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to get current location')),
        );
      }
    }
  }

  Future<String?> _getFoodImage(String foodItem) async {
    try {
      final searchTerm = Uri.encodeComponent(foodItem);
      final response = await http.get(
        Uri.parse(
          'https://pixabay.com/api/?key=$_pixabayApiKey&q=$searchTerm&image_type=photo&category=food&per_page=3&safesearch=true'
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['hits'] != null && data['hits'].isNotEmpty) {
          return data['hits'][0]['largeImageURL'];
        }
      }
      
      // Fallback to a default food image
      return 'https://cdn.pixabay.com/photo/2017/02/15/10/39/food-2068217_1280.jpg';
    } catch (e) {
      print('Error fetching image: $e');
      return 'https://cdn.pixabay.com/photo/2017/02/15/10/39/food-2068217_1280.jpg';
    }
  }

  Future<void> _submitDonation() async {
    if (_formKey.currentState!.validate() && _selectedLocation != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Get food image URL first
        _foodImageUrl = await _getFoodImage(_foodItemController.text);

        // Get the current user ID (you'll need to pass this from your auth system)
        final userId = 'user123'; // TODO: Replace with actual user ID

        // Create donation data
        final donationData = {
          'foodItem': _foodItemController.text,
          'quantity': _quantityController.text,
          'donor': _organizationController.text.isNotEmpty
              ? _organizationController.text
              : _nameController.text,
          'price': _isFree ? 'Free' : '₹${_amountController.text}',
          'startTime': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
          'endTime': '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
          'location': {
            'latitude': _selectedLocation!.latitude,
            'longitude': _selectedLocation!.longitude,
          },
          'status': 'Active',
          'phoneNumber': _phoneController.text,
          'notes': _notesController.text,
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
          'imageUrl': _foodImageUrl, // Store the image URL with the donation
        };

        // Start a batch write
        final batch = FirebaseFirestore.instance.batch();

        // Create references
        final userDonationRef = FirebaseFirestore.instance
            .collection('donation')
            .doc(userId)
            .collection('user_donations')
            .doc();

        final activeDonationRef = FirebaseFirestore.instance
            .collection('active_donations')
            .doc(userDonationRef.id);

        // Add to user's donations
        batch.set(userDonationRef, donationData);

        // Add to active donations
        batch.set(activeDonationRef, {
          ...donationData,
          'donationId': userDonationRef.id,
        });

        // Commit the batch
        await batch.commit();

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Donation created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit donation: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pickup location on the map')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Donation'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _organizationController,
                decoration: const InputDecoration(
                  labelText: 'Organization Name (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _foodItemController,
                decoration: const InputDecoration(
                  labelText: 'Food Item',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the food item';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity (e.g., "5 portions", "2 kg")',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the quantity';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: _selectedLocation != null
                          ? GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: _selectedLocation!,
                                zoom: 15,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('pickup'),
                                  position: _selectedLocation!,
                                  infoWindow: const InfoWindow(title: 'Pickup Location'),
                                ),
                              },
                              zoomControlsEnabled: false,
                              zoomGesturesEnabled: false,
                              scrollGesturesEnabled: false,
                              rotateGesturesEnabled: false,
                              tiltGesturesEnabled: false,
                              myLocationEnabled: false,
                              myLocationButtonEnabled: false,
                              mapToolbarEnabled: false,
                            )
                          : const Center(
                              child: Text('No location selected'),
                            ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () async {
                          final location = await showDialog<LatLng>(
                            context: context,
                            builder: (context) => LocationPickerDialog(
                              initialLocation: _selectedLocation,
                            ),
                          );
                          if (location != null) {
                            setState(() {
                              _selectedLocation = location;
                            });
                          }
                        },
                        child: Container(
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _selectedLocation != null ? Icons.edit_location : Icons.add_location,
                                size: 32,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedLocation != null ? 'Change Location' : 'Set Pickup Location',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to select pickup location on map',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Collection Time Window'),
                      subtitle: Text(
                        'From ${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')} '
                        'to ${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.access_time),
                              label: const Text('Start Time'),
                              onPressed: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(_startTime),
                                );
                                if (time != null) {
                                  setState(() {
                                    _startTime = DateTime(
                                      DateTime.now().year,
                                      DateTime.now().month,
                                      DateTime.now().day,
                                      time.hour,
                                      time.minute,
                                    );
                                    // Ensure end time is after start time
                                    if (_endTime.isBefore(_startTime)) {
                                      _endTime = _startTime.add(const Duration(hours: 1));
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.access_time),
                              label: const Text('End Time'),
                              onPressed: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(_endTime),
                                );
                                if (time != null) {
                                  final selectedTime = DateTime(
                                    DateTime.now().year,
                                    DateTime.now().month,
                                    DateTime.now().day,
                                    time.hour,
                                    time.minute,
                                  );
                                  if (selectedTime.isAfter(_startTime)) {
                                    setState(() {
                                      _endTime = selectedTime;
                                    });
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('End time must be after start time'),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Free Donation'),
                      value: _isFree,
                      onChanged: (value) {
                        setState(() {
                          _isFree = value;
                          if (value) {
                            _amountController.clear();
                          }
                        });
                      },
                    ),
                    if (!_isFree) ...[
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _amountController,
                          decoration: const InputDecoration(
                            labelText: 'Price (₹)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.currency_rupee),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (!_isFree) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter the price';
                              }
                              final price = double.tryParse(value);
                              if (price == null || price <= 0) {
                                return 'Please enter a valid price';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes',
                  border: OutlineInputBorder(),
                  hintText: 'Any special instructions or details',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitDonation,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Submit Donation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'donations';

  // Create a new donation
  Future<String> createDonation(Map<String, dynamic> donationData) async {
    try {
      // Convert LatLng to GeoPoint for Firestore
      final location = donationData['location'] as Map<String, dynamic>;
      final geoPoint = GeoPoint(location['latitude'] as double, location['longitude'] as double);
      
      // Create a new document with server timestamp
      final docRef = await _firestore.collection(_collectionName).add({
        ...donationData,
        'location': geoPoint,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create donation: $e');
    }
  }

  // Get all donations for a specific user
  Stream<QuerySnapshot> getUserDonations(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Update an existing donation
  Future<void> updateDonation(String donationId, Map<String, dynamic> updates) async {
    try {
      // If location is being updated, convert to GeoPoint
      if (updates.containsKey('location')) {
        final location = updates['location'] as Map<String, dynamic>;
        updates['location'] = GeoPoint(location['latitude'] as double, location['longitude'] as double);
      }

      await _firestore.collection(_collectionName).doc(donationId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update donation: $e');
    }
  }

  // Delete a donation
  Future<void> deleteDonation(String donationId) async {
    try {
      await _firestore.collection(_collectionName).doc(donationId).delete();
    } catch (e) {
      throw Exception('Failed to delete donation: $e');
    }
  }

  // Get a single donation by ID
  Future<DocumentSnapshot> getDonation(String donationId) {
    return _firestore.collection(_collectionName).doc(donationId).get();
  }

  // Convert Firestore data to app model
  Map<String, dynamic> convertFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final geoPoint = data['location'] as GeoPoint;
    
    return {
      'id': doc.id,
      ...data,
      'location': LatLng(geoPoint.latitude, geoPoint.longitude).toJson(),
      'createdAt': (data['createdAt'] as Timestamp).toDate().toIso8601String(),
      'updatedAt': (data['updatedAt'] as Timestamp).toDate().toIso8601String(),
    };
  }
} 
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import 'package:my_boarding_house_partner/models/property_model.dart';

class PropertyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fetch properties for current landlord
  Future<List<Property>> fetchPropertiesForLandlord() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      final querySnapshot = await _firestore.collection('Properties').where('landlordId', isEqualTo: user.uid).get();

      return querySnapshot.docs.map((doc) => Property.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch properties: $e');
    }
  }

  // Fetch all properties (for admin)
  Future<List<Property>> fetchAllProperties({String? filterBy, dynamic filterValue}) async {
    try {
      Query query = _firestore.collection('Properties');

      // Apply filter if provided
      if (filterBy != null && filterValue != null) {
        query = query.where(filterBy, isEqualTo: filterValue);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs.map((doc) => Property.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch properties: $e');
    }
  }

  // Fetch a specific property
  Future<Property> fetchPropertyById(String propertyId) async {
    try {
      final docSnapshot = await _firestore.collection('Properties').doc(propertyId).get();

      if (!docSnapshot.exists) {
        throw Exception('Property not found');
      }

      return Property.fromFirestore(docSnapshot);
    } catch (e) {
      throw Exception('Failed to fetch property: $e');
    }
  }

  // Create a new property
  Future<String> createProperty(Map<String, dynamic> propertyData, List<File> images) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Upload images
      List<String> imageUrls = [];
      for (var image in images) {
        String imageUrl = await _uploadImage(image);
        imageUrls.add(imageUrl);
      }

      // Add necessary fields to property data
      propertyData['landlordId'] = user.uid;
      propertyData['photos'] = imageUrls;
      propertyData['isVerified'] = false; // Admin needs to verify
      propertyData['createdAt'] = FieldValue.serverTimestamp();
      propertyData['updatedAt'] = FieldValue.serverTimestamp();

      // Ensure location fields are properly set
      _processLocationData(propertyData);

      // Create property document
      final docRef = await _firestore.collection('Properties').add(propertyData);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create property: $e');
    }
  }

  // Update a property
  Future<void> updateProperty(String propertyId, Map<String, dynamic> propertyData, {List<File>? newImages}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if this property belongs to the current user
      final docSnapshot = await _firestore.collection('Properties').doc(propertyId).get();

      if (!docSnapshot.exists) {
        throw Exception('Property not found');
      }

      final existingProperty = Property.fromFirestore(docSnapshot);
      if (existingProperty.landlordId != user.uid) {
        throw Exception('You are not authorized to update this property');
      }

      // Upload new images if provided
      if (newImages != null && newImages.isNotEmpty) {
        List<String> existingImageUrls = List<String>.from(existingProperty.photos);

        for (var image in newImages) {
          String imageUrl = await _uploadImage(image);
          existingImageUrls.add(imageUrl);
        }

        propertyData['photos'] = existingImageUrls;
      }

      // Add update timestamp
      propertyData['updatedAt'] = FieldValue.serverTimestamp();

      // If property is being updated, set to unverified for admin review
      propertyData['isVerified'] = false;

      // Ensure location fields are properly set
      _processLocationData(propertyData);

      // Update property document
      await _firestore.collection('Properties').doc(propertyId).update(propertyData);
    } catch (e) {
      throw Exception('Failed to update property: $e');
    }
  }

  // Delete a property
  Future<void> deleteProperty(String propertyId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if this property belongs to the current user
      final docSnapshot = await _firestore.collection('Properties').doc(propertyId).get();

      if (!docSnapshot.exists) {
        throw Exception('Property not found');
      }

      final existingProperty = Property.fromFirestore(docSnapshot);
      if (existingProperty.landlordId != user.uid) {
        throw Exception('You are not authorized to delete this property');
      }

      // First, check if there are any active bookings
      final bookingsSnapshot = await _firestore.collection('Bookings').where('propertyId', isEqualTo: propertyId).where('status', whereIn: ['pending', 'confirmed', 'active']).get();

      if (bookingsSnapshot.docs.isNotEmpty) {
        throw Exception('Cannot delete property with active bookings');
      }

      // Delete all rooms and bed spaces (subcollections)
      final roomsSnapshot = await _firestore.collection('Properties').doc(propertyId).collection('Rooms').get();

      final batch = _firestore.batch();

      // Delete rooms and their bed spaces
      for (var roomDoc in roomsSnapshot.docs) {
        final bedSpacesSnapshot = await _firestore.collection('Properties').doc(propertyId).collection('Rooms').doc(roomDoc.id).collection('BedSpaces').get();

        for (var bedSpaceDoc in bedSpacesSnapshot.docs) {
          batch.delete(bedSpaceDoc.reference);
        }

        batch.delete(roomDoc.reference);
      }

      // Delete the property document
      batch.delete(_firestore.collection('Properties').doc(propertyId));

      // Commit the batch
      await batch.commit();

      // Note: We're not deleting the images from storage for now
      // as they might be shared or used elsewhere
    } catch (e) {
      throw Exception('Failed to delete property: $e');
    }
  }

  // Helper method to process location data
  void _processLocationData(Map<String, dynamic> propertyData) {
    // Check if latitude and longitude are provided
    if (propertyData.containsKey('latitude') && propertyData.containsKey('longitude')) {
      double? lat = propertyData['latitude'];
      double? lng = propertyData['longitude'];

      if (lat != null && lng != null) {
        // Create GeoPoint if not already set
        if (!propertyData.containsKey('location')) {
          propertyData['location'] = GeoPoint(lat, lng);
        }

        // Make sure city and zipCode are included
        if (!propertyData.containsKey('city') && propertyData.containsKey('address')) {
          // Try to extract city from address
          List<String> addressParts = propertyData['address'].toString().split(',');
          if (addressParts.length > 1) {
            propertyData['city'] = addressParts[addressParts.length - 2].trim();
          }
        }

        if (!propertyData.containsKey('zipCode') && propertyData.containsKey('address')) {
          // Try to extract zipCode from address
          List<String> addressParts = propertyData['address'].toString().split(',');
          if (addressParts.length > 0) {
            final lastPart = addressParts[addressParts.length - 1].trim();
            final zipMatch = RegExp(r'\d{5}').firstMatch(lastPart);
            if (zipMatch != null) {
              propertyData['zipCode'] = zipMatch.group(0);
            }
          }
        }

        // Set country if not provided
        if (!propertyData.containsKey('country')) {
          // Default to Zambia since we're restricting to Zambia
          propertyData['country'] = 'Zambia';
        }

        // Set province if not provided and can be extracted from address
        if (!propertyData.containsKey('province') && propertyData.containsKey('address')) {
          List<String> addressParts = propertyData['address'].toString().split(',');
          if (addressParts.length >= 4) {
            propertyData['province'] = addressParts[addressParts.length - 2].trim();
          }
        }
      }
    }
  }

  // Helper method to upload an image to Firebase Storage
  Future<String> _uploadImage(File image) async {
    try {
      final String fileName = '${const Uuid().v4()}.jpg';
      final Reference ref = _storage.ref().child('properties').child(fileName);

      final UploadTask uploadTask = ref.putFile(image);
      final TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // Add a room to a property
  Future<String> addRoom(String propertyId, Map<String, dynamic> roomData, List<File> images) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if this property belongs to the current user
      final propertyDoc = await _firestore.collection('Properties').doc(propertyId).get();

      if (!propertyDoc.exists) {
        throw Exception('Property not found');
      }

      final property = Property.fromFirestore(propertyDoc);
      if (property.landlordId != user.uid) {
        throw Exception('You are not authorized to add rooms to this property');
      }

      // Upload images
      List<String> imageUrls = [];
      for (var image in images) {
        String imageUrl = await _uploadImage(image);
        imageUrls.add(imageUrl);
      }

      // Add necessary fields to room data
      roomData['propertyId'] = propertyId;
      roomData['photos'] = imageUrls;
      roomData['createdAt'] = FieldValue.serverTimestamp();

      // Create room document
      final roomRef = await _firestore.collection('Properties').doc(propertyId).collection('Rooms').add(roomData);

      // Update property stats
      await _firestore.collection('Properties').doc(propertyId).update({'totalRooms': FieldValue.increment(1), 'updatedAt': FieldValue.serverTimestamp()});

      return roomRef.id;
    } catch (e) {
      throw Exception('Failed to add room: $e');
    }
  }

  // Add a bed space to a room
  Future<String> addBedSpace(String propertyId, String roomId, Map<String, dynamic> bedSpaceData, List<File> images) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if this property belongs to the current user
      final propertyDoc = await _firestore.collection('Properties').doc(propertyId).get();

      if (!propertyDoc.exists) {
        throw Exception('Property not found');
      }

      final property = Property.fromFirestore(propertyDoc);
      if (property.landlordId != user.uid) {
        throw Exception('You are not authorized to add bed spaces to this property');
      }

      // Upload images
      List<String> imageUrls = [];
      for (var image in images) {
        String imageUrl = await _uploadImage(image);
        imageUrls.add(imageUrl);
      }

      // Add necessary fields to bed space data
      bedSpaceData['propertyId'] = propertyId;
      bedSpaceData['roomId'] = roomId;
      bedSpaceData['photos'] = imageUrls;
      bedSpaceData['status'] = 'available'; // Initial status
      bedSpaceData['createdAt'] = FieldValue.serverTimestamp();

      // Create bed space document
      final bedSpaceRef = await _firestore.collection('Properties').doc(propertyId).collection('Rooms').doc(roomId).collection('BedSpaces').add(bedSpaceData);

      // Update room stats
      await _firestore.collection('Properties').doc(propertyId).collection('Rooms').doc(roomId).update({'totalBedSpaces': FieldValue.increment(1)});

      // Update property stats
      double price = (bedSpaceData['price'] as num).toDouble();
      await _firestore.collection('Properties').doc(propertyId).update({'totalBedSpaces': FieldValue.increment(1), 'minPrice': property.minPrice == 0 || price < property.minPrice ? price : property.minPrice, 'updatedAt': FieldValue.serverTimestamp()});

      return bedSpaceRef.id;
    } catch (e) {
      throw Exception('Failed to add bed space: $e');
    }
  }

  // Update room details
  Future<void> updateRoom(String propertyId, String roomId, Map<String, dynamic> roomData, {List<File>? newImages}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if this property belongs to the current user
      final propertyDoc = await _firestore.collection('Properties').doc(propertyId).get();

      if (!propertyDoc.exists) {
        throw Exception('Property not found');
      }

      final property = Property.fromFirestore(propertyDoc);
      if (property.landlordId != user.uid) {
        throw Exception('You are not authorized to update this room');
      }

      // Get current room data to merge with updates
      final roomDoc = await _firestore.collection('Properties').doc(propertyId).collection('Rooms').doc(roomId).get();
      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      // Upload new images if provided
      if (newImages != null && newImages.isNotEmpty) {
        List<String> existingImageUrls = List<String>.from(roomDoc.data()?['photos'] ?? []);

        for (var image in newImages) {
          String imageUrl = await _uploadImage(image);
          existingImageUrls.add(imageUrl);
        }

        roomData['photos'] = existingImageUrls;
      }

      // Add update timestamp
      roomData['updatedAt'] = FieldValue.serverTimestamp();

      // Update room document
      await _firestore.collection('Properties').doc(propertyId).collection('Rooms').doc(roomId).update(roomData);

      // Also update property updatedAt timestamp
      await _firestore.collection('Properties').doc(propertyId).update({'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw Exception('Failed to update room: $e');
    }
  }

  // Delete a room and all its bed spaces
  Future<void> deleteRoom(String propertyId, String roomId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if this property belongs to the current user
      final propertyDoc = await _firestore.collection('Properties').doc(propertyId).get();

      if (!propertyDoc.exists) {
        throw Exception('Property not found');
      }

      final property = Property.fromFirestore(propertyDoc);
      if (property.landlordId != user.uid) {
        throw Exception('You are not authorized to delete this room');
      }

      // Get the room document
      final roomDoc = await _firestore.collection('Properties').doc(propertyId).collection('Rooms').doc(roomId).get();
      if (!roomDoc.exists) {
        throw Exception('Room not found');
      }

      // First, check if there are any booked bed spaces
      final bedSpacesSnapshot = await _firestore.collection('Properties').doc(propertyId).collection('Rooms').doc(roomId).collection('BedSpaces').where('status', isEqualTo: 'booked').get();

      if (bedSpacesSnapshot.docs.isNotEmpty) {
        throw Exception('Cannot delete room with booked bed spaces');
      }

      // Get all bed spaces in this room
      final allBedSpacesSnapshot = await _firestore.collection('Properties').doc(propertyId).collection('Rooms').doc(roomId).collection('BedSpaces').get();
      final totalBedSpaces = allBedSpacesSnapshot.docs.length;

      // Start a batch operation
      final batch = _firestore.batch();

      // Delete all bed spaces
      for (var bedSpaceDoc in allBedSpacesSnapshot.docs) {
        batch.delete(bedSpaceDoc.reference);
      }

      // Delete the room document
      batch.delete(_firestore.collection('Properties').doc(propertyId).collection('Rooms').doc(roomId));

      // Update property stats (decrement totalRooms and totalBedSpaces)
      batch.update(_firestore.collection('Properties').doc(propertyId), {'totalRooms': FieldValue.increment(-1), 'totalBedSpaces': FieldValue.increment(-totalBedSpaces), 'updatedAt': FieldValue.serverTimestamp()});

      // Commit the batch
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete room: $e');
    }
  }

  // Update bed space details
  Future<void> updateBedSpace(String propertyId, String roomId, String bedSpaceId, Map<String, dynamic> bedSpaceData, {List<File>? newImages}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if this property belongs to the current user
      final propertyDoc = await _firestore.collection('Properties').doc(propertyId).get();

      if (!propertyDoc.exists) {
        throw Exception('Property not found');
      }

      final property = Property.fromFirestore(propertyDoc);
      if (property.landlordId != user.uid) {
        throw Exception('You are not authorized to update this bed space');
      }

      // Get current bed space to get photos
      final bedSpaceDoc = await _firestore.collection('Properties').doc(propertyId).collection('Rooms').doc(roomId).collection('BedSpaces').doc(bedSpaceId).get();

      if (!bedSpaceDoc.exists) {
        throw Exception('Bed space not found');
      }

      // Upload new images if provided
      if (newImages != null && newImages.isNotEmpty) {
        List<String> existingImageUrls = List<String>.from(bedSpaceDoc.data()?['photos'] ?? []);

        for (var image in newImages) {
          String imageUrl = await _uploadImage(image);
          existingImageUrls.add(imageUrl);
        }

        bedSpaceData['photos'] = existingImageUrls;
      }

      // Add update timestamp
      bedSpaceData['updatedAt'] = FieldValue.serverTimestamp();

      // Check if price changed
      if (bedSpaceData.containsKey('price')) {
        double newPrice = (bedSpaceData['price'] as num).toDouble();
        double oldPrice = (bedSpaceDoc.data()?['price'] as num).toDouble();

        // If price decreased, check if it affects property's minPrice
        if (newPrice < oldPrice) {
          // Get all bed spaces to recalculate min price
          final allBedSpacesSnapshot = await _firestore.collection('Properties').doc(propertyId).collection('Rooms').get();

          double currentMin = double.infinity;
          for (var roomDoc in allBedSpacesSnapshot.docs) {
            final bedSpacesInRoom = await _firestore.collection('Properties').doc(propertyId).collection('Rooms').doc(roomDoc.id).collection('BedSpaces').get();

            for (var bsDoc in bedSpacesInRoom.docs) {
              if (bsDoc.id != bedSpaceId) {
                // Skip the current one being updated
                double bsPrice = (bsDoc.data()['price'] as num).toDouble();
                if (bsPrice < currentMin) {
                  currentMin = bsPrice;
                }
              }
            }
          }

          // If new price is the minimum or there are no other bed spaces
          if (newPrice < currentMin || currentMin == double.infinity) {
            await _firestore.collection('Properties').doc(propertyId).update({'minPrice': newPrice, 'updatedAt': FieldValue.serverTimestamp()});
          }
        }
      }

      // Update bed space document
      await _firestore.collection('Properties').doc(propertyId).collection('Rooms').doc(roomId).collection('BedSpaces').doc(bedSpaceId).update(bedSpaceData);
    } catch (e) {
      throw Exception('Failed to update bed space: $e');
    }
  }

  // Delete a bed space
  Future<void> deleteBedSpace(String propertyId, String roomId, String bedSpaceId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if this property belongs to the current user
      final propertyDoc = await _firestore.collection('Properties').doc(propertyId).get();

      if (!propertyDoc.exists) {
        throw Exception('Property not found');
      }

      final property = Property.fromFirestore(propertyDoc);
      if (property.landlordId != user.uid) {
        throw Exception('You are not authorized to delete this bed space');
      }

      // Get the bed space document
      final bedSpaceDoc = await _firestore.collection('Properties').doc(propertyId).collection('Rooms').doc(roomId).collection('BedSpaces').doc(bedSpaceId).get();

      if (!bedSpaceDoc.exists) {
        throw Exception('Bed space not found');
      }

      // Check if bed space is booked
      if (bedSpaceDoc.data()?['status'] == 'booked') {
        throw Exception('Cannot delete a booked bed space');
      }

      // Delete bed space document
      await _firestore.collection('Properties').doc(propertyId).collection('Rooms').doc(roomId).collection('BedSpaces').doc(bedSpaceId).delete();

      // Update room stats
      await _firestore.collection('Properties').doc(propertyId).collection('Rooms').doc(roomId).update({'totalBedSpaces': FieldValue.increment(-1)});

      // Update property stats
      await _firestore.collection('Properties').doc(propertyId).update({'totalBedSpaces': FieldValue.increment(-1), 'updatedAt': FieldValue.serverTimestamp()});

      // Check if we need to update minPrice
      double deletedPrice = (bedSpaceDoc.data()?['price'] as num).toDouble();
      if (deletedPrice == property.minPrice) {
        // Recalculate minPrice across all remaining bed spaces
        double newMinPrice = double.infinity;
        final roomsSnapshot = await _firestore.collection('Properties').doc(propertyId).collection('Rooms').get();

        for (var roomDoc in roomsSnapshot.docs) {
          final bedSpacesSnapshot = await _firestore.collection('Properties').doc(propertyId).collection('Rooms').doc(roomDoc.id).collection('BedSpaces').get();

          for (var bsDoc in bedSpacesSnapshot.docs) {
            double price = (bsDoc.data()['price'] as num).toDouble();
            if (price < newMinPrice) {
              newMinPrice = price;
            }
          }
        }

        // Update property with new minPrice (or 0 if no bed spaces left)
        await _firestore.collection('Properties').doc(propertyId).update({'minPrice': newMinPrice != double.infinity ? newMinPrice : 0});
      }
    } catch (e) {
      throw Exception('Failed to delete bed space: $e');
    }
  }

  // Fetch rooms for a property
  Future<List<Room>> fetchRoomsForProperty(String propertyId) async {
    try {
      final querySnapshot = await _firestore.collection('Properties').doc(propertyId).collection('Rooms').get();

      return querySnapshot.docs.map((doc) => Room.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch rooms: $e');
    }
  }

  // Fetch bed spaces for a room
  Future<List<BedSpace>> fetchBedSpacesForRoom(String propertyId, String roomId) async {
    try {
      final querySnapshot = await _firestore.collection('Properties').doc(propertyId).collection('Rooms').doc(roomId).collection('BedSpaces').get();

      return querySnapshot.docs.map((doc) => BedSpace.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch bed spaces: $e');
    }
  }

  // Admin methods

  // Verify a property (admin only)
  Future<void> verifyProperty(String propertyId, bool isVerified) async {
    try {
      await _firestore.collection('Properties').doc(propertyId).update({'isVerified': isVerified, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw Exception('Failed to update property verification: $e');
    }
  }

  // Get property statistics for admin dashboard
  Future<Map<String, dynamic>> getPropertyStatistics() async {
    try {
      final querySnapshot = await _firestore.collection('Properties').get();

      int totalProperties = querySnapshot.docs.length;
      int verifiedProperties = 0;
      int pendingProperties = 0;
      int totalBedSpaces = 0;
      int occupiedBedSpaces = 0;

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data();

        // Count verified/pending properties
        if (data['isVerified'] == true) {
          verifiedProperties++;
        } else {
          pendingProperties++;
        }

        // Count bed spaces
        totalBedSpaces += (data['totalBedSpaces'] as int?) ?? 0;
        occupiedBedSpaces += (data['occupiedBedSpaces'] as int?) ?? 0;
      }

      // Calculate occupancy rate
      double occupancyRate = totalBedSpaces > 0 ? (occupiedBedSpaces / totalBedSpaces) * 100 : 0;

      return {'totalProperties': totalProperties, 'verifiedProperties': verifiedProperties, 'pendingProperties': pendingProperties, 'totalBedSpaces': totalBedSpaces, 'occupiedBedSpaces': occupiedBedSpaces, 'occupancyRate': occupancyRate};
    } catch (e) {
      throw Exception('Failed to get property statistics: $e');
    }
  }
}

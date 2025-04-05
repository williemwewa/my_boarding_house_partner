import 'package:cloud_firestore/cloud_firestore.dart';

class Property {
  final String id;
  final String name;
  final String description;
  final String address;
  final String propertyType;
  final List<String> photos;
  final List<String> amenities;
  final List<String> rules;
  final String landlordId;
  final bool isActive;
  final bool isVerified;
  final int totalRooms;
  final int totalBedSpaces;
  final int occupiedBedSpaces;
  final double minPrice;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? latitude;
  final double? longitude;

  Property({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.propertyType,
    required this.photos,
    required this.amenities,
    required this.rules,
    required this.landlordId,
    required this.isActive,
    required this.isVerified,
    required this.totalRooms,
    required this.totalBedSpaces,
    required this.occupiedBedSpaces,
    required this.minPrice,
    required this.createdAt,
    required this.updatedAt,
    this.latitude,
    this.longitude,
  });

  factory Property.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle GeoPoint if available
    double? latitude, longitude;
    if (data['location'] != null) {
      final GeoPoint location = data['location'] as GeoPoint;
      latitude = location.latitude;
      longitude = location.longitude;
    }

    // Handle Timestamps
    Timestamp createdTimestamp = data['createdAt'] as Timestamp? ?? Timestamp.now();
    Timestamp updatedTimestamp = data['updatedAt'] as Timestamp? ?? Timestamp.now();

    return Property(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      address: data['address'] ?? '',
      propertyType: data['propertyType'] ?? 'Apartment',
      photos: List<String>.from(data['photos'] ?? []),
      amenities: List<String>.from(data['amenities'] ?? []),
      rules: List<String>.from(data['rules'] ?? []),
      landlordId: data['landlordId'] ?? '',
      isActive: data['isActive'] ?? false,
      isVerified: data['isVerified'] ?? false,
      totalRooms: data['totalRooms'] ?? 0,
      totalBedSpaces: data['totalBedSpaces'] ?? 0,
      occupiedBedSpaces: data['occupiedBedSpaces'] ?? 0,
      minPrice: (data['minPrice'] ?? 0).toDouble(),
      createdAt: createdTimestamp.toDate(),
      updatedAt: updatedTimestamp.toDate(),
      latitude: latitude,
      longitude: longitude,
    );
  }

  Map<String, dynamic> toMap() {
    GeoPoint? location;
    if (latitude != null && longitude != null) {
      location = GeoPoint(latitude!, longitude!);
    }

    return {
      'name': name,
      'description': description,
      'address': address,
      'propertyType': propertyType,
      'photos': photos,
      'amenities': amenities,
      'rules': rules,
      'landlordId': landlordId,
      'isActive': isActive,
      'isVerified': isVerified,
      'totalRooms': totalRooms,
      'totalBedSpaces': totalBedSpaces,
      'occupiedBedSpaces': occupiedBedSpaces,
      'minPrice': minPrice,
      'updatedAt': FieldValue.serverTimestamp(),
      if (location != null) 'location': location,
    };
  }

  // Create a copy with updated fields
  Property copyWith({
    String? name,
    String? description,
    String? address,
    String? propertyType,
    List<String>? photos,
    List<String>? amenities,
    List<String>? rules,
    bool? isActive,
    bool? isVerified,
    int? totalRooms,
    int? totalBedSpaces,
    int? occupiedBedSpaces,
    double? minPrice,
    double? latitude,
    double? longitude,
  }) {
    return Property(
      id: this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      propertyType: propertyType ?? this.propertyType,
      photos: photos ?? this.photos,
      amenities: amenities ?? this.amenities,
      rules: rules ?? this.rules,
      landlordId: this.landlordId,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      totalRooms: totalRooms ?? this.totalRooms,
      totalBedSpaces: totalBedSpaces ?? this.totalBedSpaces,
      occupiedBedSpaces: occupiedBedSpaces ?? this.occupiedBedSpaces,
      minPrice: minPrice ?? this.minPrice,
      createdAt: this.createdAt,
      updatedAt: DateTime.now(),
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

class Room {
  final String id;
  final String propertyId;
  final String name;
  final String description;
  final String roomType;
  final int totalBedSpaces;
  final List<String> photos;
  final List<String> amenities;
  final double area;

  Room({required this.id, required this.propertyId, required this.name, required this.description, required this.roomType, required this.totalBedSpaces, required this.photos, required this.amenities, required this.area});

  factory Room.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Room(
      id: doc.id,
      propertyId: data['propertyId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      roomType: data['roomType'] ?? 'Single',
      totalBedSpaces: data['totalBedSpaces'] ?? 0,
      photos: List<String>.from(data['photos'] ?? []),
      amenities: List<String>.from(data['amenities'] ?? []),
      area: (data['area'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'propertyId': propertyId, 'name': name, 'description': description, 'roomType': roomType, 'totalBedSpaces': totalBedSpaces, 'photos': photos, 'amenities': amenities, 'area': area};
  }
}

class BedSpace {
  final String id;
  final String roomId;
  final String propertyId;
  final String name;
  final double price;
  final String priceUnit; // per month, semester, etc.
  final String description;
  final String status; // available, booked, maintenance
  final List<String> features;
  final List<String> photos;

  BedSpace({required this.id, required this.roomId, required this.propertyId, required this.name, required this.price, required this.priceUnit, required this.description, required this.status, required this.features, required this.photos});

  factory BedSpace.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return BedSpace(
      id: doc.id,
      roomId: data['roomId'] ?? '',
      propertyId: data['propertyId'] ?? '',
      name: data['name'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      priceUnit: data['priceUnit'] ?? 'per month',
      description: data['description'] ?? '',
      status: data['status'] ?? 'available',
      features: List<String>.from(data['features'] ?? []),
      photos: List<String>.from(data['photos'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {'roomId': roomId, 'propertyId': propertyId, 'name': name, 'price': price, 'priceUnit': priceUnit, 'description': description, 'status': status, 'features': features, 'photos': photos};
  }
}

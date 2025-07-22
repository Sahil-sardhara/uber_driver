import 'dart:io';

class UserData {
  String? username;
  String? email;
  String? carModel;
  String? carColor;
  String? carNumber;
  File? profileImage; // To store the picked image locally

  UserData({
    this.username,
    this.email,
    this.carModel,
    this.carColor,
    this.carNumber,
    this.profileImage,
  });

  // Factory constructor to create UserData from Firebase snapshot
  factory UserData.fromFirebase(Map<dynamic, dynamic>? data, String? email) {
    return UserData(
      username: data?['name'],
      email: email,
      carModel: data?['carModel'],
      carColor: data?['carColor'],
      carNumber: data?['carNumber'],
      // profileImage cannot be directly loaded from Firebase here, handle separately
    );
  }

  // Method to convert UserData to a map for Firebase update
  Map<String, dynamic> toMap() {
    return {
      'name': username,
      'carModel': carModel,
      'carColor': carColor,
      'carNumber': carNumber,
      // Do not include profileImage here, as it's a File object
    };
  }
}
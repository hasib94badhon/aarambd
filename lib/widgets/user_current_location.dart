// import 'package:location/location.dart' as loc;
// import 'package:geocoding/geocoding.dart';
// import 'package:location/location.dart';


// void getUserLocation() async {
//   loc.Location location = loc.Location();

//   bool _serviceEnabled;
//   PermissionStatus _permissionGranted;
//   LocationData _locationData;

//   _serviceEnabled = await location.serviceEnabled();
//   if (!_serviceEnabled) {
//     _serviceEnabled = await location.requestService();
//     if (!_serviceEnabled) return;
//   }

//   _permissionGranted = await location.hasPermission();
//   if (_permissionGranted == PermissionStatus.denied) {
//     _permissionGranted = await location.requestPermission();
//     if (_permissionGranted != PermissionStatus.granted) return;
//   }

//   _locationData = await location.getLocation();
//   double? lat = _locationData.latitude;
//   double? lon = _locationData.longitude;

//   print("Latitude: $lat, Longitude: $lon");

//   // Reverse Geocoding
//   List<Placemark> placemarks = await placemarkFromCoordinates(lat!, lon!);
//   Placemark place = placemarks[0];

//   String address =
//       "${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.country}";

//   print("Address: $address");
// }





import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import 'package:aaram_bd/config.dart';

class LocationService {
  final String host = Config.host;
  final loc.Location location = loc.Location();

  Future<void> updateUserLocationFromStorage() async {
  String? userId = await Config.getLoggedInUser();
  if (userId == null) {
    print("User ID not found in SharedPreferences");
    return;
  }
  await updateUserLocation(userId);
}


  Future<void> updateUserLocation(String userId) async {
    bool _serviceEnabled;
    loc.PermissionStatus _permissionGranted;
    loc.LocationData _locationData;

    // Step 1: Check location service
    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) return;
    }

    // Step 2: Check permission
    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == loc.PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != loc.PermissionStatus.granted) return;
    }

    // Step 3: Get coordinates
    _locationData = await location.getLocation();
    double? lat = _locationData.latitude;
    double? lon = _locationData.longitude;

    if (lat == null || lon == null) return;

    print("Latitude: $lat, Longitude: $lon");

    // Step 4: Reverse geocode to address
    List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
    Placemark place = placemarks[0];

    String address =
        "${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.country}";
    print("Address: $address");

    // Step 5: Send to API
    final url = Uri.parse('$host/update_last_location'); // Replace with your actual host IP

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "user_id": userId,
          "lat": lat.toString(),
          "lon": lon.toString(),
          "address": address,
        }),
      );

      if (response.statusCode == 200) {
        print("Location successfully posted.");
      } else {
        print("Failed to post location: ${response.body}");
      }
    } catch (e) {
      print("Error posting location: $e");
    }
  }
}

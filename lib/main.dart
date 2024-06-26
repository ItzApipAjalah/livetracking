import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart'; // Import services untuk clipboard
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http; // Import http untuk request HTTP

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Location Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LiveLocationTracker(),
    );
  }
}

class LiveLocationTracker extends StatefulWidget {
  @override
  _LiveLocationTrackerState createState() => _LiveLocationTrackerState();
}

class _LiveLocationTrackerState extends State<LiveLocationTracker> {
  LatLng? _currentPosition;
  final MapController _mapController = MapController();
  bool _loading = true;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _startUpdatingLocation();
    _uploadLocationToApi(); // Panggil method untuk mengunggah lokasi saat aplikasi dibuka
  }

  void _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(
            'ic_launcher'); // Sesuaikan dengan nama ikon yang ada

    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void _startUpdatingLocation() {
    _timer = Timer.periodic(Duration(minutes: 1), (timer) {
      _getCurrentLocation();
      _uploadLocationToApi(); // Panggil method untuk mengunggah lokasi setiap menit
    });

    // Also immediately fetch the current location
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _loading = false;
    });

    _mapController.move(_currentPosition!, 15.0);

    // Tampilkan notifikasi jika lokasi berubah
    _showNotification();
  }

  void _showNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'location_update_channel',
      'Location Updates',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: false,
      // Tidak ada pengaturan ikon di sini
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      'Location Update',
      'Your location has been updated',
      platformChannelSpecifics,
      payload: 'Location Update',
    );
  }

  void _moveToCurrentLocation() {
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, 15.0);
    }
  }

  void _copyLocationUrl() {
    if (_currentPosition != null) {
      final url =
          'https://www.google.com/maps?q=${_currentPosition!.latitude},${_currentPosition!.longitude}';
      Clipboard.setData(ClipboardData(text: url)).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location URL copied to clipboard')),
        );
      });
    }
  }

  Future<void> _uploadLocationToApi() async {
    try {
      final url = 'https://localhost:3000/api/maps/upload';
      final response = await http.post(
        Uri.parse(url),
        body: {
          'maps_url':
              'https://www.google.com/maps?q=${_currentPosition!.latitude},${_currentPosition!.longitude}',
        },
      );

      if (response.statusCode == 200) {
        print('Location uploaded successfully');
      } else {
        print('Failed to upload location. Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading location: $e');
    }
  }

  @override
  void dispose() {
    _timer.cancel(); // Hentikan timer saat widget di dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Location Tracker'),
        actions: [
          IconButton(
            icon: Icon(Icons.copy),
            onPressed: _copyLocationUrl,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _currentPosition == null
              ? Center(child: Text('Unable to determine location'))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: _currentPosition,
                    zoom: 15.0,
                    minZoom: 5.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                      subdomains: ['a', 'b', 'c'],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 80.0,
                          height: 80.0,
                          point: _currentPosition!,
                          builder: (ctx) => Container(
                            child: Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 50.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _moveToCurrentLocation,
        child: Icon(Icons.my_location),
      ),
    );
  }
}

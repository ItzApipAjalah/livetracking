import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart'; // Import services for clipboard
import 'package:http/http.dart' as http; // Import http for HTTP requests
import 'package:geocoding/geocoding.dart'; // Import geocoding for reverse geocoding
import 'package:shared_preferences/shared_preferences.dart'; // Import shared preferences for persistent storage

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
  LatLng? _fakePosition;
  String? _currentCountry;
  String? _currentCity;
  String? _currentDateTime;
  final MapController _mapController = MapController();
  bool _loading = true;
  bool _uploadLocation = false;
  bool _useFakeLocation = false;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _startUpdatingLocation();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _uploadLocation = prefs.getBool('uploadLocation') ?? false;
      _useFakeLocation = prefs.getBool('useFakeLocation') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('uploadLocation', _uploadLocation);
    prefs.setBool('useFakeLocation', _useFakeLocation);
  }

  void _startUpdatingLocation() {
    _timer = Timer.periodic(Duration(minutes: 1), (timer) {
      _getCurrentLocation();
      if (_uploadLocation) {
        _uploadLocationToApi(); // Call method to upload location every minute if enabled
      }
    });

    // Also immediately fetch the current location
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    if (_useFakeLocation && _fakePosition != null) {
      setState(() {
        _currentPosition = _fakePosition;
        _loading = false;
        _currentDateTime = DateTime.now()
            .toLocal()
            .toString(); // Get the current date and time
      });

      _mapController.move(_currentPosition!, 15.0);
      _getAddressFromLatLng(_currentPosition!);
      return;
    }

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
      _currentDateTime =
          DateTime.now().toLocal().toString(); // Get the current date and time
    });

    _mapController.move(_currentPosition!, 15.0);
    _getAddressFromLatLng(_currentPosition!);
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        setState(() {
          _currentCountry = placemarks.first.country;
          _currentCity = placemarks.first.locality;
        });
      }
    } catch (e) {
      print(e);
    }
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
    _timer.cancel(); // Stop the timer when the widget is disposed
    super.dispose();
  }

  void _selectFakeLocation(LatLng position) {
    setState(() {
      _fakePosition = position;
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Location Tracker'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => SettingsPage(
                          _uploadLocation,
                          _useFakeLocation,
                          (uploadLocation, useFakeLocation) {
                            setState(() {
                              _uploadLocation = uploadLocation;
                              _useFakeLocation = useFakeLocation;
                            });
                            _saveSettings();
                          },
                          _selectFakeLocation,
                        )),
              );
            },
          ),
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
              : Column(
                  children: [
                    Expanded(
                      child: FlutterMap(
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
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Latitude: ${_currentPosition!.latitude.toStringAsFixed(5)}'),
                          Text(
                              'Longitude: ${_currentPosition!.longitude.toStringAsFixed(5)}'),
                          if (_currentCountry != null)
                            Text('Country: $_currentCountry'),
                          if (_currentCity != null) Text('City: $_currentCity'),
                          if (_currentDateTime != null)
                            Text('Current Date and Time: $_currentDateTime'),
                        ],
                      ),
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

class SettingsPage extends StatefulWidget {
  final bool uploadLocation;
  final bool useFakeLocation;
  final Function(bool, bool) onSettingsChanged;
  final Function(LatLng) onFakeLocationSelected;

  SettingsPage(
    this.uploadLocation,
    this.useFakeLocation,
    this.onSettingsChanged,
    this.onFakeLocationSelected,
  );

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _uploadLocation;
  late bool _useFakeLocation;

  @override
  void initState() {
    super.initState();
    _uploadLocation = widget.uploadLocation;
    _useFakeLocation = widget.useFakeLocation;
  }

  void _openFakeLocationSelector() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FakeLocationSelectorPage(widget.onFakeLocationSelected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text('Upload Location to API'),
            value: _uploadLocation,
            onChanged: (value) {
              setState(() {
                _uploadLocation = value;
              });
              widget.onSettingsChanged(_uploadLocation, _useFakeLocation);
            },
          ),
          SwitchListTile(
            title: Text('Use Fake Location'),
            value: _useFakeLocation,
            onChanged: (value) {
              setState(() {
                _useFakeLocation = value;
              });
              widget.onSettingsChanged(_uploadLocation, _useFakeLocation);
            },
          ),
          ListTile(
            title: Text('Select Fake Location'),
            trailing: Icon(Icons.map),
            onTap: _openFakeLocationSelector,
          ),
        ],
      ),
    );
  }
}

class FakeLocationSelectorPage extends StatefulWidget {
  final Function(LatLng) onLocationSelected;

  FakeLocationSelectorPage(this.onLocationSelected);

  @override
  _FakeLocationSelectorPageState createState() =>
      _FakeLocationSelectorPageState();
}

class _FakeLocationSelectorPageState extends State<FakeLocationSelectorPage> {
  LatLng? _selectedPosition;
  final MapController _mapController = MapController();

  void _onMapTap(TapPosition tapPosition, LatLng position) {
    setState(() {
      _selectedPosition = position;
    });
  }

  void _confirmSelection() {
    if (_selectedPosition != null) {
      widget.onLocationSelected(_selectedPosition!);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Fake Location'),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: _confirmSelection,
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          center: LatLng(0, 0),
          zoom: 2.0,
          onTap: _onMapTap,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: ['a', 'b', 'c'],
          ),
          if (_selectedPosition != null)
            MarkerLayer(
              markers: [
                Marker(
                  width: 80.0,
                  height: 80.0,
                  point: _selectedPosition!,
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
    );
  }
}

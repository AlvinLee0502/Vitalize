import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vibration/vibration.dart';
import 'jogging_record_screen.dart';
import 'run_summary_screen.dart';

class WalkScreen extends StatefulWidget {
  const WalkScreen({super.key});

  @override
  State<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends State<WalkScreen> {
  GoogleMapController? _mapController;
  bool _isTracking = false;
  bool _isPaused = false;
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;
  final List<LatLng> _path = [];
  LatLng? _currentPosition;
  double _distance = 0.0;
  double _calories = 0.0;
  bool _isLocationError = false;
  String _statusMessage = 'Initializing...';
  Marker? _currentMarker;
  double _pace = 0.0;
  String _mapStyle = '';
  bool _isMapStyleLoaded = false;

  final List<Polyline> _polylines = [];
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _loadMapStyle();
  }

  Future<void> _loadMapStyle() async {
    try {
      _mapStyle = await rootBundle.loadString('assets/map_style.json');
      setState(() => _isMapStyleLoaded = true);
    } catch (e) {
      debugPrint('Error loading map style: $e');
    }
  }

  Future<void> _initializeLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLocationError = true;
          _statusMessage = 'Location services are disabled. Please enable them.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLocationError = true;
            _statusMessage = 'Location permission denied';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLocationError = true;
          _statusMessage = 'Location permissions permanently denied';
        });
        return;
      }

      // Get initial position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      setState(() {
        _isLocationError = false;
        _currentPosition = LatLng(position.latitude, position.longitude);
        _currentMarker = Marker(
          markerId: const MarkerId('current_location'),
          position: _currentPosition!,
          infoWindow: const InfoWindow(title: 'Current Location'),
        );
        _statusMessage = 'Ready to track';
      });

      _moveCamera(_currentPosition!);
      // Start listening to location updates
      _startLocationUpdates();
    } catch (e) {
      setState(() {
        _isLocationError = true;
        _statusMessage = 'Error: ${e.toString()}';
      });
    }
  }

  void _startLocationUpdates() {
    _positionStreamSubscription?.cancel();

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5, // Update every 5 meters for better battery life
      ),
    ).listen(
          (Position position) {
        final newPosition = LatLng(position.latitude, position.longitude);

        setState(() {
          _currentPosition = newPosition;
          _currentMarker = Marker(
            markerId: const MarkerId('current_location'),
            position: newPosition,
            infoWindow: const InfoWindow(title: 'Current Location'),
          );

          if (_isTracking && !_isPaused) {
            if (_path.isNotEmpty) {
              final distance = Geolocator.distanceBetween(
                _path.last.latitude,
                _path.last.longitude,
                newPosition.latitude,
                newPosition.longitude,
              );

              // Only add point if distance is significant
              if (distance >= 5) {
                _path.add(newPosition);
                _distance += distance;
                _updatePolylines();
              }
            } else {
              _path.add(newPosition);
              _updatePolylines();
            }
          }
        });

        if (_isTracking && !_isPaused) {
          _moveCamera(newPosition);
        }
      },
      onError: (error) {
        setState(() {
          _isLocationError = true;
          _statusMessage = 'Location Error: $error';
        });
      },
    );
  }

  void _updatePolylines() {
    _polylines.clear();
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('walk_path'),
        points: _path,
        color: Colors.blue,
        width: 5,
      ),
    );
  }

  void _moveCamera(LatLng position) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(position),
    );
  }

  void _startTracking() {
    if (_isLocationError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable location services to start tracking')),
      );
      return;
    }

    setState(() {
      if (!_isPaused) {
        _path.clear();
        _elapsedTime = Duration.zero;
        _distance = 0.0;
        _calories = 0.0;
        _pace = 0.0;
        _polylines.clear();
      }
      _isTracking = true;
      _isPaused = false;
      _statusMessage = 'Tracking started...';
    });

    Vibration.vibrate(duration: 100);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isTracking && !_isPaused) {
        setState(() {
          _elapsedTime += const Duration(seconds: 1);
          _calories = _calculateCalories();
          _pace = _calculatePace();
        });
      }
    });
  }

  double _calculateCalories() {
    // Improved calorie calculation (approximate)
    // Using MET value of 3.5 for walking
    const met = 3.5;
    const weight = 70; // Average weight in kg (can be made configurable)
    return (met * weight * _elapsedTime.inHours);
  }

  double _calculatePace() {
    if (_distance == 0) return 0;
    // Convert to minutes per kilometer
    return (_elapsedTime.inSeconds / 60) / (_distance / 1000);
  }

  void _pauseTracking() {
    setState(() {
      _isPaused = true;
      _statusMessage = 'Paused';
    });
    Vibration.vibrate(duration: 50);
  }

  void _resumeTracking() {
    setState(() {
      _isPaused = false;
      _statusMessage = 'Tracking resumed...';
    });
    Vibration.vibrate(duration: 100);
  }

  Future<void> _stopTracking() async {
    if (_isTracking) {
      await _saveTrackingData();
      setState(() {
        _isTracking = false;
        _statusMessage = 'Track saved';
      });
      _timer?.cancel();

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RunSummaryScreen(
            totalDistance: _distance,
            totalTime: _elapsedTime,
            totalCalories: _calories,
            path: _path,
            speedData: _generateSpeedData(),
          ),
        ),
      );
    }
  }

  List<double> _generateSpeedData() {
    if (_path.length < 2) {
      return [];
    }

    List<double> speeds = [];
    for (int i = 0; i < _path.length - 1; i++) {
      final distance = Geolocator.distanceBetween(
        _path[i].latitude,
        _path[i].longitude,
        _path[i + 1].latitude,
        _path[i + 1].longitude,
      );

      final speed = distance;

      if (speed >= 0) {
        speeds.add(speed);
      }
    }

    return speeds;
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _saveTrackingData() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/jogging_data.json');
    final data = {
      'path': _path.map((e) => {'lat': e.latitude, 'lng': e.longitude}).toList(),
      'distance': _distance,
      'time': _elapsedTime.inSeconds,
      'calories': _calories,
    };

    if (await file.exists()) {
      final content = await file.readAsString();
      final jsonData = jsonDecode(content) as List<dynamic>;
      jsonData.add(data);
      await file.writeAsString(jsonEncode(jsonData));
    } else {
      await file.writeAsString(jsonEncode([data]));
    }
  }

  Widget _buildTrackingControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: !_isTracking
              ? _startTracking
              : (_isPaused ? _resumeTracking : _pauseTracking),
          child: Text(!_isTracking
              ? 'Start'
              : (_isPaused ? 'Resume' : 'Pause')),
        ),
        if (_isTracking)
          ElevatedButton(
            onPressed: _stopTracking,
            child: const Text('Stop'),
          ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, String unit) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(unit, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  Widget _buildZoomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          onPressed: () =>
              _mapController?.animateCamera(
                CameraUpdate.zoomIn(),
              ),
          child: const Icon(Icons.zoom_in),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          onPressed: () =>
              _mapController?.animateCamera(
                CameraUpdate.zoomOut(),
              ),
          child: const Icon(Icons.zoom_out),
        ),
      ],
    );
  }

  Widget _buildRecenterButton() {
    return FloatingActionButton(
      onPressed: () =>
      _currentPosition != null
          ? _moveCamera(_currentPosition!)
          : null,
      child: const Icon(Icons.my_location),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Walk Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.access_time),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const JoggingRecordScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLocationError
              ? const Center(
            child: Text(
              'Location services are required to use this feature.',
              textAlign: TextAlign.center,
            ),
          )
              : (_isMapStyleLoaded
              ? GoogleMap(
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            initialCameraPosition: CameraPosition(
              target: _currentPosition ?? const LatLng(0, 0),
              zoom: 16.0,
            ),
            mapType: MapType.normal,
            markers: _currentMarker != null ? {_currentMarker!} : {},
            polylines: _polylines.toSet(),
            onMapCreated: (controller) {
              _mapController = controller;
              if (_isMapStyleLoaded && _mapStyle.isNotEmpty) {
                _mapStyle;
              }
            },
          )
              : const Center(
            child: CircularProgressIndicator(),
          )),
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Text(
              _statusMessage,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Positioned(
            top: 100,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard(
                    'Time', _formatDuration(_elapsedTime), 'hh:mm:ss'),
                _buildStatCard(
                    'Distance', (_distance / 1000).toStringAsFixed(2), 'km'),
                _buildStatCard(
                    'Calories', _calories.toStringAsFixed(0), 'kcal'),
                _buildStatCard('Pace', _pace.toStringAsFixed(2), 'min/km'),
              ],
            ),
          ),
          Positioned(
            bottom: 32,
            left: 32,
            right: 32,
            child: _buildTrackingControls(),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: _buildZoomControls(),
          ),
          Positioned(
            bottom: 100,
            right: 16,
            child: _buildRecenterButton(),
          ),
        ],
      ),
    );
  }
}
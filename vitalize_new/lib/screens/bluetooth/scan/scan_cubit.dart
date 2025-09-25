import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// First define the states
abstract class ScanStates {}

class ScanDevicesInitialState extends ScanStates {}
class ScanDevicesLoadingState extends ScanStates {}
class ScanDevicesSuccessState extends ScanStates {}
class ScanDevicesErrorState extends ScanStates {
  final String error;
  ScanDevicesErrorState(this.error);
}

class ScanCubit extends Cubit<ScanStates> {
  ScanCubit() : super(ScanDevicesInitialState());

  final List<Map<String, dynamic>> devicesList = [];
  bool isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  // Static method to get the cubit instance
  static ScanCubit get(BuildContext context) => BlocProvider.of<ScanCubit>(context);

  Future<void> startScanning(BuildContext context) async {
    if (isScanning) return;

    try {
      bool permissionsGranted = await _checkAndRequestPermissions();
      if (!permissionsGranted) {
        // Check individual permissions to give more specific error message
        String missingPermissions = '';
        if (!await Permission.bluetooth.isGranted) missingPermissions += 'Bluetooth, ';
        if (!await Permission.bluetoothScan.isGranted) missingPermissions += 'Bluetooth Scan, ';
        if (!await Permission.bluetoothConnect.isGranted) missingPermissions += 'Bluetooth Connect, ';
        if (!await Permission.location.isGranted) missingPermissions += 'Location, ';

        emit(ScanDevicesErrorState('Missing permissions: ${missingPermissions.substring(0, missingPermissions.length - 2)}'));
        return;
      }

      emit(ScanDevicesLoadingState());
      devicesList.clear();
      isScanning = true;


      await FlutterBluePlus.turnOn();

      _scanSubscription = FlutterBluePlus.scanResults.listen(
              (results) {
            for (ScanResult r in results) {
              bool deviceExists = devicesList.any(
                      (device) => device['mac'] == r.device.remoteId.toString()
              );
              if (!deviceExists) {
                devicesList.add({
                  'name': r.device.platformName,
                  'mac': r.device.remoteId.toString(),
                  'device': r.device,
                });
              }
            }
            emit(ScanDevicesSuccessState());
          },
          onError: (error) {
            print('Scan error: $error');
            emit(ScanDevicesErrorState(error.toString()));
          }
      );
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    } catch (e) {
      print('Exception in startScanning: $e');
      emit(ScanDevicesErrorState(e.toString()));
    }
  }

  Future<bool> _checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      // List of required permissions
      final permissions = [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ];

      // Request permissions
      final statuses = await permissions.request();

      // Check if all permissions are granted
      final allGranted = statuses.values.every((status) => status.isGranted);

      // If any permission is permanently denied, show a dialog
      if (statuses.values.any((status) => status.isPermanentlyDenied)) {
        // Direct user to app settings
        openAppSettings();
        return false;
      }

      return allGranted;
    }

    return true;
  }


  Future<void> stopScanning() async {
    try {
      await _scanSubscription?.cancel();
      await FlutterBluePlus.stopScan();
      isScanning = false;
      emit(ScanDevicesSuccessState());
    } catch (e) {
      emit(ScanDevicesErrorState(e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _scanSubscription?.cancel();
    await stopScanning();
    return super.close();
  }
}
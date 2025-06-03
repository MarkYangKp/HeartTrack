import 'dart:async';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/health_data.dart';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  final StreamController<HealthData> _dataController = StreamController<HealthData>.broadcast();
  Stream<HealthData> get dataStream => _dataController.stream;

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _targetCharacteristic;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // 模拟数据定时器
  Timer? _simulationTimer;

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<bool> connectToDevice([String? deviceId]) async {
    try {
      // 检查蓝牙权限
      bool hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        return false;
      }

      // 检查蓝牙是否开启
      if (!await FlutterBluePlus.isOn) {
        return false;
      }

      // TODO: 实现真实的设备连接逻辑
      // 这里可以扫描设备并连接到指定的健康监测设备
      /*
      // 扫描设备
      await FlutterBluePlus.startScan(timeout: Duration(seconds: 4));
      
      // 监听扫描结果
      var subscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (r.device.name == "YourHealthDevice") {
            _connectedDevice = r.device;
            break;
          }
        }
      });

      await FlutterBluePlus.stopScan();
      subscription.cancel();

      if (_connectedDevice != null) {
        await _connectedDevice!.connect();
        List<BluetoothService> services = await _connectedDevice!.discoverServices();
        
        // 找到目标服务和特征
        for (BluetoothService service in services) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == "your-characteristic-uuid") {
              _targetCharacteristic = characteristic;
              await characteristic.setNotifyValue(true);
              characteristic.value.listen(_handleBluetoothData);
              break;
            }
          }
        }
      }
      */

      // 模拟连接成功
      await Future.delayed(const Duration(seconds: 2));
      _isConnected = true;
      return true;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      _simulationTimer?.cancel();
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
      _isConnected = false;
    } catch (e) {
      // 处理断开连接错误
    }
  }

  // 启动数据模拟（用于测试）
  void startDataSimulation() {
    if (!_isConnected) return;
    
    _simulationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isConnected) {
        timer.cancel();
        return;
      }
      
      final random = Random();
      final healthData = HealthData(
        heartRate: 60 + random.nextInt(40), // 60-100 BPM
        oxygenSaturation: 95 + random.nextInt(5), // 95-99%
        timestamp: DateTime.now(),
      );
      
      _dataController.add(healthData);
    });
  }

  // 处理真实蓝牙数据的方法
  void _handleBluetoothData(List<int> data) {
    try {
      // TODO: 根据你的设备协议解析数据
      // 这里需要根据具体的蓝牙设备数据格式来解析
      
      // 示例解析逻辑（需要根据实际设备调整）
      if (data.length >= 4) {
        int heartRate = data[0];
        int oxygenSaturation = data[1];
        
        final healthData = HealthData(
          heartRate: heartRate,
          oxygenSaturation: oxygenSaturation,
          timestamp: DateTime.now(),
        );
        
        _dataController.add(healthData);
      }
    } catch (e) {
      // 处理数据解析错误
      print('蓝牙数据解析错误: $e');
    }
  }

  // 检查蓝牙状态
  Future<bool> isBluetoothEnabled() async {
    return await FlutterBluePlus.isOn;
  }

  // 获取已配对的设备列表
  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      return await FlutterBluePlus.bondedDevices;
    } catch (e) {
      return [];
    }
  }

  void dispose() {
    _simulationTimer?.cancel();
    _dataController.close();
  }
}

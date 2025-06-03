import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fble;
import 'package:permission_handler/permission_handler.dart';
import '../models/health_data.dart';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  final StreamController<HealthData> _dataController = StreamController<HealthData>.broadcast();
  Stream<HealthData> get dataStream => _dataController.stream;

  fble.BluetoothDevice? _connectedDevice;
  fble.BluetoothCharacteristic? _targetCharacteristic;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // 扫描结果流控制器
  StreamSubscription<List<fble.ScanResult>>? _scanSubscription;
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
        print('蓝牙权限不足');
        return false;
      }

      // 检查蓝牙是否开启
      if (!await fble.FlutterBluePlus.isOn) {
        print('蓝牙未开启');
        return false;
      }

      // 扫描并连接到MAX设备
      bool deviceFound = await _scanAndConnectToMAX();
      if (!deviceFound) {
        print('未找到MAX设备');
        return false;
      }

      _isConnected = true;
      return true;
    } catch (e) {
      print('连接设备时出错: $e');
      _isConnected = false;
      return false;
    }
  }

  Future<bool> _scanAndConnectToMAX() async {
    try {
      // 开始扫描
      await fble.FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      
      bool deviceFound = false;
      
      // 监听扫描结果
      _scanSubscription = fble.FlutterBluePlus.scanResults.listen((results) async {
        for (fble.ScanResult result in results) {
          print('发现设备: ${result.device.platformName}');
          
          // 查找名为"MAX"的设备
          if (result.device.platformName == "MAX") {
            print('找到MAX设备，正在连接...');
            _connectedDevice = result.device;
            deviceFound = true;
            
            try {
              // 连接设备
              await _connectedDevice!.connect(timeout: const Duration(seconds: 15));
              print('成功连接到MAX设备');
              
              // 发现服务
              List<fble.BluetoothService> services = await _connectedDevice!.discoverServices();
              print('发现 ${services.length} 个服务');
              
              // 查找可用的特征
              for (fble.BluetoothService service in services) {
                print('服务UUID: ${service.uuid}');
                for (fble.BluetoothCharacteristic characteristic in service.characteristics) {
                  print('特征UUID: ${characteristic.uuid}');
                  
                  // 检查特征是否支持通知
                  if (characteristic.properties.notify || characteristic.properties.indicate) {
                    _targetCharacteristic = characteristic;
                    
                    // 启用通知
                    await characteristic.setNotifyValue(true);
                    
                    // 监听数据
                    characteristic.lastValueStream.listen(_handleBluetoothData);
                    
                    print('已设置数据监听');
                    break;
                  }
                }
                if (_targetCharacteristic != null) break;
              }
              
            } catch (e) {
              print('连接MAX设备失败: $e');
              deviceFound = false;
            }
            
            break;
          }
        }
      });

      // 等待扫描完成
      await Future.delayed(const Duration(seconds: 10));
      await fble.FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      
      return deviceFound;
    } catch (e) {
      print('扫描设备时出错: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      _simulationTimer?.cancel();
      _scanSubscription?.cancel();
      
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
      
      _isConnected = false;
      _connectedDevice = null;
      _targetCharacteristic = null;
      print('设备已断开连接');
    } catch (e) {
      print('断开连接时出错: $e');
    }
  }

  // 启动数据模拟（用于测试）
  void startDataSimulation() {
    if (!_isConnected) return;
    
    // 如果有真实设备连接，优先使用真实数据
    if (_targetCharacteristic != null) {
      print('正在使用真实设备数据');
      return;
    }
    
    // 否则使用模拟数据
    print('正在使用模拟数据');
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
      // 将字节数据转换为字符串
      String dataString = utf8.decode(data);
      print('收到蓝牙数据: $dataString');
      
      // 移除换行符并解析数据格式: a=%d, b=%d\r\n
      String cleanData = dataString.replaceAll(RegExp(r'[\r\n]'), '');
      print('清理后的数据: $cleanData');
      
      // 解析数据格式: a=%d, b=%d
      RegExp regExp = RegExp(r'a=(\d+),\s*b=(\d+)');
      Match? match = regExp.firstMatch(cleanData);
      
      if (match != null) {
        int heartRate = int.parse(match.group(1)!);
        int oxygenSaturation = int.parse(match.group(2)!);
        
        print('解析数据 - 心率: $heartRate, 血氧: $oxygenSaturation');
        
        final healthData = HealthData(
          heartRate: heartRate,
          oxygenSaturation: oxygenSaturation,
          timestamp: DateTime.now(),
        );
        
        _dataController.add(healthData);
      } else {
        print('数据格式不匹配: $cleanData');
      }
    } catch (e) {
      print('蓝牙数据解析错误: $e');
    }
  }

  // 检查蓝牙状态
  Future<bool> isBluetoothEnabled() async {
    return await fble.FlutterBluePlus.isOn;
  }

  // 获取已配对的设备列表
  Future<List<fble.BluetoothDevice>> getPairedDevices() async {
    try {
      return await fble.FlutterBluePlus.bondedDevices;
    } catch (e) {
      return [];
    }
  }

  void dispose() {
    _simulationTimer?.cancel();
    _scanSubscription?.cancel();
    _dataController.close();
  }
}

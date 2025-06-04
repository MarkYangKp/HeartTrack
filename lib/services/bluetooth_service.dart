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
      // 防止重复连接
      if (_isConnected && _connectedDevice != null) {
        print('设备已连接，跳过重复连接');
        return true;
      }

      // 开始扫描
      await fble.FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      
      bool deviceFound = false;
      
      // 监听扫描结果
      _scanSubscription = fble.FlutterBluePlus.scanResults.listen((results) async {
        for (fble.ScanResult result in results) {
          print('发现设备: ${result.device.platformName}');
          
          // 查找名为"MAX"的设备
          if (result.device.platformName == "MAX" && !deviceFound) {
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
              
              // 详细检查所有特征
              await _analyzeAllCharacteristics(services);
              
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

  // 分析所有特征的详细信息
  Future<void> _analyzeAllCharacteristics(List<fble.BluetoothService> services) async {
    for (fble.BluetoothService service in services) {
      print('=== 服务UUID: ${service.uuid} ===');
      
      for (fble.BluetoothCharacteristic characteristic in service.characteristics) {
        print('特征UUID: ${characteristic.uuid}');
        print('  属性: read=${characteristic.properties.read}, '
              'write=${characteristic.properties.write}, '
              'notify=${characteristic.properties.notify}, '
              'indicate=${characteristic.properties.indicate}');
        
        try {
          // 优先设置通知特征
          if (characteristic.properties.notify || characteristic.properties.indicate) {
            _targetCharacteristic = characteristic;
            await characteristic.setNotifyValue(true);
            characteristic.lastValueStream.listen(_handleBluetoothData);
            print('  ✓ 已设置通知监听');
          }
          // 如果特征支持读取，尝试读取一次
          else if (characteristic.properties.read) {
            try {
              List<int> value = await characteristic.read();
              if (value.isNotEmpty) {
                print('  读取到数据: ${utf8.decode(value)}');
                _handleBluetoothData(value);
              }
            } catch (e) {
              print('  读取特征失败: $e');
            }
          }
          
        } catch (e) {
          print('  设置特征监听失败: $e');
        }
      }
    }
    
    // 如果没有找到通知特征，启动定时读取
    if (_targetCharacteristic == null) {
      print('未找到通知特征，启动定时读取模式');
      _startPeriodicRead(services);
    }
  }

  // 定时读取数据（备用方案）
  void _startPeriodicRead(List<fble.BluetoothService> services) {
    // 找到所有可读特征
    List<fble.BluetoothCharacteristic> readableCharacteristics = [];
    
    for (fble.BluetoothService service in services) {
      for (fble.BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.read) {
          readableCharacteristics.add(characteristic);
        }
      }
    }
    
    if (readableCharacteristics.isEmpty) {
      print('没有找到可读特征，启动模拟数据');
      startDataSimulation();
      return;
    }
    
    // 定时读取所有可读特征
    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!_isConnected) {
        timer.cancel();
        return;
      }
      
      for (fble.BluetoothCharacteristic characteristic in readableCharacteristics) {
        try {
          List<int> value = await characteristic.read();
          if (value.isNotEmpty) {
            print('定时读取到数据: ${utf8.decode(value)}');
            _handleBluetoothData(value);
          }
        } catch (e) {
          // 静默处理读取错误
        }
      }
    });
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
      if (data.isEmpty) return;
      
      // 将字节数据转换为字符串
      String dataString = utf8.decode(data);
      print('收到蓝牙数据: $dataString');
      
      // 移除换行符并解析数据格式: a=%d, b=%d\r\n
      String cleanData = dataString.replaceAll(RegExp(r'[\r\n]'), '');
      print('清理后的数据: $cleanData');
      
      // 尝试多种数据格式解析
      HealthData? healthData = _parseHealthData(cleanData);
      
      if (healthData != null) {
        _dataController.add(healthData);
      } else {
        print('无法解析的数据格式: $cleanData');
        // 如果无法解析，尝试将数据作为原始数值处理
        _tryParseRawData(data);
      }
    } catch (e) {
      print('蓝牙数据解析错误: $e');
      // 尝试将原始字节作为数值处理
      _tryParseRawData(data);
    }
  }

  // 解析健康数据的多种格式
  HealthData? _parseHealthData(String cleanData) {
    // 格式1: a=%d, b=%d
    RegExp regExp1 = RegExp(r'a=(\d+),\s*b=(\d+)');
    Match? match1 = regExp1.firstMatch(cleanData);
    if (match1 != null) {
      int heartRate = int.parse(match1.group(1)!);
      int oxygenSaturation = int.parse(match1.group(2)!);
      print('解析数据格式1 - 心率: $heartRate, 血氧: $oxygenSaturation');
      return HealthData(
        heartRate: heartRate,
        oxygenSaturation: oxygenSaturation,
        timestamp: DateTime.now(),
      );
    }
    
    // 格式2: HR:%d,SPO2:%d
    RegExp regExp2 = RegExp(r'HR:(\d+),SPO2:(\d+)');
    Match? match2 = regExp2.firstMatch(cleanData);
    if (match2 != null) {
      int heartRate = int.parse(match2.group(1)!);
      int oxygenSaturation = int.parse(match2.group(2)!);
      print('解析数据格式2 - 心率: $heartRate, 血氧: $oxygenSaturation');
      return HealthData(
        heartRate: heartRate,
        oxygenSaturation: oxygenSaturation,
        timestamp: DateTime.now(),
      );
    }
    
    // 格式3: 纯数字，用逗号分隔
    RegExp regExp3 = RegExp(r'(\d+),(\d+)');
    Match? match3 = regExp3.firstMatch(cleanData);
    if (match3 != null) {
      int heartRate = int.parse(match3.group(1)!);
      int oxygenSaturation = int.parse(match3.group(2)!);
      print('解析数据格式3 - 心率: $heartRate, 血氧: $oxygenSaturation');
      return HealthData(
        heartRate: heartRate,
        oxygenSaturation: oxygenSaturation,
        timestamp: DateTime.now(),
      );
    }
    
    return null;
  }

  // 尝试解析原始字节数据
  void _tryParseRawData(List<int> data) {
    if (data.length >= 2) {
      // 假设前两个字节分别是心率和血氧
      int heartRate = data[0];
      int oxygenSaturation = data[1];
      
      // 验证数据合理性
      if (heartRate > 0 && heartRate < 200 && oxygenSaturation > 50 && oxygenSaturation <= 100) {
        print('解析原始字节数据 - 心率: $heartRate, 血氧: $oxygenSaturation');
        final healthData = HealthData(
          heartRate: heartRate,
          oxygenSaturation: oxygenSaturation,
          timestamp: DateTime.now(),
        );
        _dataController.add(healthData);
      }
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

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

  // 添加debug消息流控制器
  final StreamController<String> _debugController = StreamController<String>.broadcast();
  Stream<String> get debugStream => _debugController.stream;

  fble.BluetoothDevice? _connectedDevice;
  fble.BluetoothCharacteristic? _targetCharacteristic;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // 目标设备MAC地址
  static const String _targetDeviceAddress = "C4:24:06:02:12:1A";

  // 扫描结果流控制器
  StreamSubscription<List<fble.ScanResult>>? _scanSubscription;
  Timer? _simulationTimer;

  // 添加debug消息发送方法
  void _debugPrint(String message) {
    print(message); // 保留控制台输出
    _debugController.add('[${DateTime.now().toString().substring(11, 19)}] $message');
  }

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
        _debugPrint('蓝牙权限不足');
        return false;
      }

      // 检查蓝牙是否开启
      if (!await fble.FlutterBluePlus.isOn) {
        _debugPrint('蓝牙未开启');
        return false;
      }

      // 扫描并连接到指定MAC地址的设备
      bool deviceFound = await _scanAndConnectToTargetDevice();
      if (!deviceFound) {
        _debugPrint('未找到目标设备 (地址: $_targetDeviceAddress)');
        return false;
      }

      _isConnected = true;
      return true;
    } catch (e) {
      _debugPrint('连接设备时出错: $e');
      _isConnected = false;
      return false;
    }
  }

  Future<bool> _scanAndConnectToTargetDevice() async {
    try {
      // 防止重复连接
      if (_isConnected && _connectedDevice != null) {
        _debugPrint('设备已连接，跳过重复连接 (地址: ${_connectedDevice!.remoteId})');
        return true;
      }

      // 开始扫描
      await fble.FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
      _debugPrint('开始扫描蓝牙设备... (目标地址: $_targetDeviceAddress)');
      
      bool deviceFound = false;
      
      // 监听扫描结果
      _scanSubscription = fble.FlutterBluePlus.scanResults.listen((results) async {
        for (fble.ScanResult result in results) {
          String deviceAddress = result.device.remoteId.toString().toUpperCase();
          String deviceName = result.device.platformName.isNotEmpty ? result.device.platformName : "未知设备";
          
          _debugPrint('发现设备: $deviceName (地址: $deviceAddress)');
          
          // 查找指定MAC地址的设备
          if (deviceAddress == _targetDeviceAddress.toUpperCase() && !deviceFound) {
            _debugPrint('找到目标设备，正在连接... (地址: $deviceAddress, 名称: $deviceName)');
            _connectedDevice = result.device;
            deviceFound = true;
            
            try {
              // 连接设备
              await _connectedDevice!.connect(timeout: const Duration(seconds: 15));
              _debugPrint('成功连接到目标设备 (地址: ${_connectedDevice!.remoteId}, 名称: $deviceName)');
              
              // 发现服务
              List<fble.BluetoothService> services = await _connectedDevice!.discoverServices();
              _debugPrint('发现 ${services.length} 个服务');
              
              // 详细检查所有特征
              await _analyzeAllCharacteristics(services);
              
            } catch (e) {
              _debugPrint('连接目标设备失败 (地址: $deviceAddress): $e');
              deviceFound = false;
            }
            
            break;
          }
        }
      });

      // 等待扫描完成
      await Future.delayed(const Duration(seconds: 15));
      await fble.FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      
      if (!deviceFound) {
        _debugPrint('扫描完成，未找到目标设备 (地址: $_targetDeviceAddress)');
      }
      
      return deviceFound;
    } catch (e) {
      _debugPrint('扫描设备时出错: $e');
      return false;
    }
  }

  // 分析所有特征的详细信息
  Future<void> _analyzeAllCharacteristics(List<fble.BluetoothService> services) async {
    for (fble.BluetoothService service in services) {
      _debugPrint('=== 服务UUID: ${service.uuid} ===');
      
      for (fble.BluetoothCharacteristic characteristic in service.characteristics) {
        _debugPrint('特征UUID: ${characteristic.uuid}');
        _debugPrint('  属性: read=${characteristic.properties.read}, '
              'write=${characteristic.properties.write}, '
              'notify=${characteristic.properties.notify}, '
              'indicate=${characteristic.properties.indicate}');
        
        try {
          // 优先设置通知特征
          if (characteristic.properties.notify || characteristic.properties.indicate) {
            _targetCharacteristic = characteristic;
            await characteristic.setNotifyValue(true);
            characteristic.lastValueStream.listen(_handleBluetoothData);
            _debugPrint('  ✓ 已设置通知监听');
          }
          // 如果特征支持读取，尝试读取一次
          else if (characteristic.properties.read) {
            try {
              List<int> value = await characteristic.read();
              if (value.isNotEmpty) {
                _debugPrint('  读取到数据: ${utf8.decode(value)}');
                _handleBluetoothData(value);
              }
            } catch (e) {
              _debugPrint('  读取特征失败: $e');
            }
          }
          
        } catch (e) {
          _debugPrint('  设置特征监听失败: $e');
        }
      }
    }
    
    // 如果没有找到通知特征，启动定时读取
    if (_targetCharacteristic == null) {
      _debugPrint('未找到通知特征，启动定时读取模式');
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
      _debugPrint('没有找到可读特征，连接失败');
      _isConnected = false;
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
            _debugPrint('定时读取到数据: ${utf8.decode(value)}');
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
        _debugPrint('正在断开设备连接 (地址: ${_connectedDevice!.remoteId})');
        await _connectedDevice!.disconnect();
      }
      
      _isConnected = false;
      _connectedDevice = null;
      _targetCharacteristic = null;
      _debugPrint('设备已断开连接');
    } catch (e) {
      _debugPrint('断开连接时出错: $e');
    }
  }

  // 启动数据模拟（用于测试）
  void startDataSimulation() {
    // 移除模拟数据功能
    _debugPrint('模拟数据功能已禁用');
  }

  // 处理真实蓝牙数据的方法
  void _handleBluetoothData(List<int> data) {
    try {
      if (data.isEmpty) return;
      
      // 将字节数据转换为字符串
      String dataString = utf8.decode(data);
      _debugPrint('收到蓝牙数据: $dataString');
      
      // 移除换行符并解析数据格式: a=%d, b=%d\r\n
      String cleanData = dataString.replaceAll(RegExp(r'[\r\n]'), '');
      _debugPrint('清理后的数据: $cleanData');
      
      // 尝试多种数据格式解析
      HealthData? healthData = _parseHealthData(cleanData);
      
      if (healthData != null) {
        _dataController.add(healthData);
      } else {
        _debugPrint('无法解析的数据格式: $cleanData');
        // 如果无法解析，尝试将数据作为原始数值处理
        _tryParseRawData(data);
      }
    } catch (e) {
      _debugPrint('蓝牙数据解析错误: $e');
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
      _debugPrint('解析数据格式1 - 心率: $heartRate, 血氧: $oxygenSaturation');
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
      _debugPrint('解析数据格式2 - 心率: $heartRate, 血氧: $oxygenSaturation');
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
      _debugPrint('解析数据格式3 - 心率: $heartRate, 血氧: $oxygenSaturation');
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
        _debugPrint('解析原始字节数据 - 心率: $heartRate, 血氧: $oxygenSaturation');
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

  // 添加清除debug信息的方法
  void clearDebugMessages() {
    _debugController.add('--- Debug信息已清除 ---');
  }

  void dispose() {
    _simulationTimer?.cancel();
    _scanSubscription?.cancel();
    _dataController.close();
    _debugController.close(); // 关闭debug流控制器
  }
}

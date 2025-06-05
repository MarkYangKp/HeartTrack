import 'package:flutter/material.dart';
import 'dart:async';
import '../models/health_data.dart';
import '../services/bluetooth_service.dart';
import '../services/database_service.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({Key? key}) : super(key: key);

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen>
    with TickerProviderStateMixin {
  final BluetoothService _bluetoothService = BluetoothService();
  final DatabaseService _databaseService = DatabaseService();
  StreamSubscription<HealthData>? _dataSubscription;
  StreamSubscription<String>? _debugSubscription; // 添加debug订阅
  
  HealthData? _currentData;
  bool _isMonitoring = false;
  bool _showDebug = false; // 控制debug区域显示
  List<String> _debugMessages = []; // 存储debug消息
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // 监听debug信息流
    _debugSubscription = _bluetoothService.debugStream.listen((message) {
      setState(() {
        _debugMessages.add(message);
        // 限制消息数量，避免内存溢出
        if (_debugMessages.length > 100) {
          _debugMessages.removeAt(0);
        }
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dataSubscription?.cancel();
    _debugSubscription?.cancel(); // 取消debug订阅
    super.dispose();
  }

  Future<void> _startMonitoring() async {
    if (!_bluetoothService.isConnected) {
      // 显示连接进度
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在连接设备 C4:24:06:02:12:1A...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      bool connected = await _bluetoothService.connectToDevice();
      if (!connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('设备连接失败 (地址: C4:24:06:02:12:1A)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('设备连接成功!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    setState(() => _isMonitoring = true);
    _pulseController.repeat(reverse: true);
    
    _bluetoothService.startDataSimulation();
    _dataSubscription = _bluetoothService.dataStream.listen((data) {
      setState(() => _currentData = data);
      _databaseService.insertHealthData(data);
    });
  }

  void _stopMonitoring() {
    setState(() => _isMonitoring = false);
    _pulseController.stop();
    _dataSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('实时监测', style: TextStyle(color: Colors.cyan)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.cyan),
        actions: [
          // 添加debug切换按钮
          IconButton(
            onPressed: () {
              setState(() {
                _showDebug = !_showDebug;
              });
            },
            icon: Icon(
              _showDebug ? Icons.bug_report : Icons.bug_report_outlined,
              color: _showDebug ? Colors.green : Colors.cyan,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            colors: [
              Colors.cyan.withOpacity(0.1),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildStatusCard(),
                const SizedBox(height: 30),
                _buildDataCards(),
                if (_showDebug) ...[
                  const SizedBox(height: 20),
                  _buildDebugArea(),
                ],
                const Spacer(),
                _buildControlButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 添加debug信息显示区域
  Widget _buildDebugArea() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Debug信息',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${_debugMessages.length}条',
                      style: TextStyle(
                        color: Colors.green.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _debugMessages.clear();
                        });
                        _bluetoothService.clearDebugMessages();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red.withOpacity(0.5)),
                        ),
                        child: const Text(
                          '清除',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _debugMessages.isEmpty
                ? const Center(
                    child: Text(
                      '暂无调试信息',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    reverse: true, // 最新消息在底部
                    padding: const EdgeInsets.all(8),
                    itemCount: _debugMessages.length,
                    itemBuilder: (context, index) {
                      final reverseIndex = _debugMessages.length - 1 - index;
                      final message = _debugMessages[reverseIndex];
                      
                      // 根据消息类型设置颜色
                      Color messageColor = Colors.white;
                      if (message.contains('错误') || message.contains('失败')) {
                        messageColor = Colors.red;
                      } else if (message.contains('成功') || message.contains('✓')) {
                        messageColor = Colors.green;
                      } else if (message.contains('发现') || message.contains('数据')) {
                        messageColor = Colors.cyan;
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          message,
                          style: TextStyle(
                            color: messageColor,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isMonitoring ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isMonitoring ? Colors.green : Colors.red,
                    boxShadow: _isMonitoring
                        ? [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Text(
            _isMonitoring ? '正在监测...' : '设备未连接',
            style: TextStyle(
              color: _isMonitoring ? Colors.green : Colors.red,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCards() {
    return Row(
      children: [
        Expanded(child: _buildDataCard('心率', '${_currentData?.heartRate ?? '--'}', 'BPM', Colors.red)),
        const SizedBox(width: 16),
        Expanded(child: _buildDataCard('血氧', '${_currentData?.oxygenSaturation ?? '--'}', '%', Colors.blue)),
      ],
    );
  }

  Widget _buildDataCard(String title, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.2),
            Colors.black.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton() {
    return GestureDetector(
      onTap: _isMonitoring ? _stopMonitoring : _startMonitoring,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              _isMonitoring ? Colors.red : Colors.cyan,
              (_isMonitoring ? Colors.red : Colors.cyan).withOpacity(0.3),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: (_isMonitoring ? Colors.red : Colors.cyan).withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Icon(
          _isMonitoring ? Icons.stop : Icons.play_arrow,
          size: 50,
          color: Colors.white,
        ),
      ),
    );
  }
}

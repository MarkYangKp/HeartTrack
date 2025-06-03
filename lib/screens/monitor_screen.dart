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
  
  HealthData? _currentData;
  bool _isMonitoring = false;
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startMonitoring() async {
    if (!_bluetoothService.isConnected) {
      bool connected = await _bluetoothService.connectToDevice();
      if (!connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备连接失败')),
        );
        return;
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
                const Spacer(),
                _buildControlButton(),
              ],
            ),
          ),
        ),
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

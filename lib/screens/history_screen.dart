import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/health_data.dart';
import '../services/database_service.dart';
import '../widgets/health_chart.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<HealthData> _healthData = [];
  bool _isLoading = true;
  int _selectedDays = 7;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _databaseService.getRecentHealthData(_selectedDays);
    setState(() {
      _healthData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('历史数据', style: TextStyle(color: Colors.cyan)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.cyan),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.filter_list, color: Colors.cyan),
            color: Colors.grey[900],
            onSelected: (days) {
              _selectedDays = days;
              _loadData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 7, child: Text('最近7天', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 30, child: Text('最近30天', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 90, child: Text('最近3个月', style: TextStyle(color: Colors.white))),
            ],
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
            : _healthData.isEmpty
                ? const Center(
                    child: Text(
                      '暂无数据',
                      style: TextStyle(color: Colors.cyan, fontSize: 18),
                    ),
                  )
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 20),
          HealthChart(data: _healthData, type: 'heartRate'),
          const SizedBox(height: 20),
          HealthChart(data: _healthData, type: 'oxygenSaturation'),
          const SizedBox(height: 20),
          _buildDataList(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    if (_healthData.isEmpty) return const SizedBox();
    
    final avgHeartRate = _healthData.map((e) => e.heartRate).reduce((a, b) => a + b) / _healthData.length;
    final avgOxygen = _healthData.map((e) => e.oxygenSaturation).reduce((a, b) => a + b) / _healthData.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.cyan.withOpacity(0.2),
            Colors.black.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '最近${_selectedDays}天平均值',
            style: const TextStyle(
              color: Colors.cyan,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('心率', '${avgHeartRate.round()}', 'BPM', Colors.red),
              _buildSummaryItem('血氧', '${avgOxygen.round()}', '%', Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, String unit, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(color: color, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          unit,
          style: TextStyle(color: color.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDataList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '详细记录',
              style: TextStyle(
                color: Colors.cyan,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _healthData.length,
            separatorBuilder: (context, index) => Divider(
              color: Colors.cyan.withOpacity(0.2),
              height: 1,
            ),
            itemBuilder: (context, index) {
              final data = _healthData[index];
              return ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Colors.cyan.withOpacity(0.3), Colors.transparent],
                    ),
                  ),
                  child: const Icon(Icons.favorite, color: Colors.red),
                ),
                title: Text(
                  DateFormat('MM-dd HH:mm').format(data.timestamp),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '心率: ${data.heartRate} BPM',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${data.oxygenSaturation}',
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      '血氧',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

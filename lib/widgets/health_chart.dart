import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/health_data.dart';

class HealthChart extends StatelessWidget {
  final List<HealthData> data;
  final String type; // 'heartRate' or 'oxygenSaturation'

  const HealthChart({
    Key? key,
    required this.data,
    required this.type,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.grey[900]!.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.cyan.withOpacity(0.3)),
        ),
        child: Center(
          child: Text(
            '暂无${type == 'heartRate' ? '心率' : '血氧'}数据',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
        ),
      );
    }

    return Container(
      height: 300,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.grey[900]!.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              type == 'heartRate' ? '心率趋势' : '血氧趋势',
              style: TextStyle(
                color: Colors.cyan,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: type == 'heartRate' ? 10 : 2,
                    verticalInterval: _getVerticalInterval(),
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.cyan.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.cyan.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: _getBottomTitleInterval(),
                        getTitlesWidget: bottomTitleWidgets,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: type == 'heartRate' ? 20 : 2,
                        getTitlesWidget: leftTitleWidgets,
                        reservedSize: 42,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                  ),
                  minX: 0,
                  maxX: data.length.toDouble() - 1,
                  minY: _getMinY(),
                  maxY: _getMaxY(),
                  lineBarsData: _getLineBarsData(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 计算垂直网格线间隔
  double _getVerticalInterval() {
    if (data.length <= 5) return 1;
    if (data.length <= 10) return 2;
    if (data.length <= 20) return 4;
    return (data.length / 5).ceil().toDouble();
  }

  // 计算底部标题间隔
  double _getBottomTitleInterval() {
    if (data.length <= 6) return 1;
    if (data.length <= 12) return 2;
    if (data.length <= 24) return 4;
    return (data.length / 6).ceil().toDouble();
  }

  List<LineChartBarData> _getLineBarsData() {
    if (type == 'heartRate') {
      return [
        LineChartBarData(
          spots: data.asMap().entries.map((entry) {
            return FlSpot(entry.key.toDouble(), entry.value.heartRate.toDouble());
          }).toList(),
          isCurved: true,
          gradient: LinearGradient(colors: [Colors.red, Colors.pink]),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [Colors.red.withOpacity(0.3), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ];
    } else {
      return [
        LineChartBarData(
          spots: data.asMap().entries.map((entry) {
            return FlSpot(entry.key.toDouble(), entry.value.oxygenSaturation.toDouble());
          }).toList(),
          isCurved: true,
          gradient: LinearGradient(colors: [Colors.blue, Colors.lightBlue]),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [Colors.blue.withOpacity(0.3), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ];
    }
  }

  double _getMinY() {
    if (type == 'heartRate') {
      if (data.isEmpty) return 50;
      return data.map((e) => e.heartRate).reduce((a, b) => a < b ? a : b).toDouble() - 10;
    } else {
      if (data.isEmpty) return 90;
      return data.map((e) => e.oxygenSaturation).reduce((a, b) => a < b ? a : b).toDouble() - 5;
    }
  }

  double _getMaxY() {
    if (type == 'heartRate') {
      if (data.isEmpty) return 100;
      return data.map((e) => e.heartRate).reduce((a, b) => a > b ? a : b).toDouble() + 10;
    } else {
      return 100; // 血氧饱和度最大值为100%
    }
  }

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    return Text(
      value.toInt().toString(),
      style: TextStyle(
        color: Colors.cyan.withOpacity(0.8),
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      textAlign: TextAlign.left,
    );
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index < 0 || index >= data.length) return const Text('');
    
    final timestamp = data[index].timestamp;
    final timeFormat = _getTimeFormat();
    final timeString = DateFormat(timeFormat).format(timestamp);
    
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Transform.rotate(
        angle: -0.5, // 轻微倾斜以节省空间
        child: Text(
          timeString,
          style: TextStyle(
            color: Colors.cyan.withOpacity(0.8),
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // 根据数据时间跨度选择合适的时间格式
  String _getTimeFormat() {
    if (data.isEmpty) return 'HH:mm';
    
    final firstTime = data.last.timestamp; // 数据是按时间倒序排列的
    final lastTime = data.first.timestamp;
    final duration = lastTime.difference(firstTime);
    
    if (duration.inHours < 24) {
      return 'HH:mm'; // 同一天显示时:分
    } else if (duration.inDays < 7) {
      return 'MM-dd\nHH:mm'; // 一周内显示月-日 时:分
    } else {
      return 'MM-dd'; // 超过一周只显示月-日
    }
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
                    verticalInterval: 1,
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
                        reservedSize: 30,
                        interval: 1,
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
      return data.map((e) => e.heartRate).reduce((a, b) => a < b ? a : b).toDouble() - 10;
    } else {
      return data.map((e) => e.oxygenSaturation).reduce((a, b) => a < b ? a : b).toDouble() - 5;
    }
  }

  double _getMaxY() {
    if (type == 'heartRate') {
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
    if (value.toInt() >= data.length) return const Text('');
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        '${value.toInt() + 1}',
        style: TextStyle(
          color: Colors.cyan.withOpacity(0.8),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

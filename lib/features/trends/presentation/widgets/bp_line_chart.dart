import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:arteria/features/trends/domain/entities/trend_data.dart';

import 'package:arteria/l10n/app_localizations.dart';

class BPLineChart extends StatelessWidget {
  final List<TrendData> data;
  final bool isSimpleView;
  final Color? primaryColor;
  final Color? secondaryColor;

  const BPLineChart({
    super.key,
    required this.data,
    this.isSimpleView = false,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultPrimaryColor = primaryColor ?? Colors.red.shade700;
    final defaultSecondaryColor = secondaryColor ?? Colors.blue.shade700;
    final l10n = AppLocalizations.of(context)!;

    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 64, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text(
              l10n.trendsNoDataYet,
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.trendsStartRecording,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 20,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.dividerColor.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (value) => FlLine(
            color: theme.dividerColor.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: _calculateInterval(),
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < data.length) {
                  final date = data[value.toInt()].timestamp;
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8,
                    child: Text(
                      '${date.day}/${date.month}',
                      style: const TextStyle(
                        color: Color(0xff68737d),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 20,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                axisSide: meta.axisSide,
                space: 8,
                child: Text(
                  '${value.toInt()}',
                  style: const TextStyle(
                    color: Color(0xff67727d),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              reservedSize: 40,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xff37434d), width: 1),
        ),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: _calculateMinY(),
        maxY: _calculateMaxY(),
        lineBarsData: [
          LineChartBarData(
            spots: _createSystolicSpots(),
            isCurved: true,
            color: defaultPrimaryColor,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 8,
                    color: defaultPrimaryColor,
                    strokeWidth: 3,
                    strokeColor: Colors.white,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  defaultPrimaryColor.withValues(alpha: 0.2),
                  defaultPrimaryColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          LineChartBarData(
            spots: _createDiastolicSpots(),
            isCurved: true,
            color: defaultSecondaryColor,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 8,
                    color: defaultSecondaryColor,
                    strokeWidth: 3,
                    strokeColor: Colors.white,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  defaultSecondaryColor.withValues(alpha: 0.2),
                  defaultSecondaryColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 12,
            tooltipBorder: BorderSide(color: theme.dividerColor, width: 1),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final isSystolic =
                    spot.bar == LineChartBarData(spots: _createSystolicSpots());
                return LineTooltipItem(
                  '${isSystolic ? l10n.trendsSystolic : l10n.trendsDiastolic}: ${spot.y.toInt()} mmHg',
                  TextStyle(
                    color: isSystolic
                        ? defaultPrimaryColor
                        : defaultSecondaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
        ),
      ),
    );
  }

  List<FlSpot> _createSystolicSpots() {
    return data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.systolic.toDouble());
    }).toList();
  }

  List<FlSpot> _createDiastolicSpots() {
    return data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.diastolic.toDouble());
    }).toList();
  }

  double _calculateMinY() {
    if (data.isEmpty) return 0;
    final minValue = data
        .map((d) => d.diastolic < d.systolic ? d.diastolic : d.systolic)
        .reduce((a, b) => a < b ? a : b);
    return (minValue - 20).toDouble().clamp(0, double.infinity);
  }

  double _calculateMaxY() {
    if (data.isEmpty) return 200;
    final maxValue = data
        .map((d) => d.diastolic > d.systolic ? d.diastolic : d.systolic)
        .reduce((a, b) => a > b ? a : b);
    return (maxValue + 20).toDouble();
  }

  double _calculateInterval() {
    final dataLength = data.length;
    if (dataLength <= 7) return 1;
    if (dataLength <= 14) return 2;
    if (dataLength <= 30) return 5;
    return 7;
  }
}

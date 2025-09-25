import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math' show min, max;

class AnalyticsDashboard extends StatefulWidget {
  const AnalyticsDashboard({super.key});

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? selectedMetric;

  // Color scheme
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFF64B5F6);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkCardColor = Color(0xFF1E1E1E);
  static const Color darkTextColor = Color(0xFFE0E0E0);

  // Sample data structure for historical data
  final Map<String, List<Map<String, dynamic>>> historicalData = {
    'totalUsers': [
      {'date': '2024-01', 'value': 12000},
      {'date': '2024-02', 'value': 13200},
      {'date': '2024-03', 'value': 14100},
      {'date': '2024-04', 'value': 15420},
    ],
    'totalHealthPros': [
      {'date': '2024-01', 'value': 180},
      {'date': '2024-02', 'value': 210},
      {'date': '2024-03', 'value': 228},
      {'date': '2024-04', 'value': 245},
    ],
    'totalMealPlans': [
      {'date': '2024-01', 'value': 650},
      {'date': '2024-02', 'value': 720},
      {'date': '2024-03', 'value': 810},
      {'date': '2024-04', 'value': 892},
    ],
    'totalWorkouts': [
      {'date': '2024-01', 'value': 980},
      {'date': '2024-02', 'value': 1050},
      {'date': '2024-03', 'value': 1180},
      {'date': '2024-04', 'value': 1256},
    ],
    'totalPremiumUsers': [
      {'date': '2024-01', 'value': 2800},
      {'date': '2024-02', 'value': 3100},
      {'date': '2024-03', 'value': 3280},
      {'date': '2024-04', 'value': 3450},
    ],
  };

  Stream<DocumentSnapshot> getAnalyticsStream() {
    return _firestore.collection('analytics').doc('dashboard').snapshots();
  }

  List<Color> gradientColors = [
    primaryColor,
    secondaryColor,
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: getAnalyticsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};

        return Container(
          color: darkBackground,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Analytics Overview',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: darkTextColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        children: [
                          _buildMetricCard(
                            'Total Users',
                            data['totalUsers'] ?? 15420,
                            Icons.people,
                            Colors.blue,
                            '+12%',
                            'totalUsers',
                          ),
                          _buildMetricCard(
                            'Health Professionals',
                            data['totalHealthPros'] ?? 245,
                            Icons.medical_services,
                            Colors.green,
                            '+8%',
                            'totalHealthPros',
                          ),
                          _buildMetricCard(
                            'Meal Plans',
                            data['totalMealPlans'] ?? 892,
                            Icons.restaurant_menu,
                            Colors.orange,
                            '+15%',
                            'totalMealPlans',
                          ),
                          _buildMetricCard(
                            'Total Workouts',
                            data['totalWorkouts'] ?? 1256,
                            Icons.fitness_center,
                            Colors.purple,
                            '+10%',
                            'totalWorkouts',
                          ),
                          _buildMetricCard(
                            'Premium Users',
                            data['totalPremiumUsers'] ?? 3450,
                            Icons.star,
                            Colors.amber,
                            '+18%',
                            'totalPremiumUsers',
                          ),
                        ],
                      ),
                      if (selectedMetric != null) ...[
                        const SizedBox(height: 24),
                        _buildDetailedAnalytics(selectedMetric!),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(String title, int value, IconData icon, Color color,
      String growth, String metricId) {
    return InkWell(
      onTap: () {
        setState(() {
          selectedMetric = metricId;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: darkCardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selectedMetric == metricId ? color : Colors.transparent,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25), // Using withAlpha instead of withOpacity
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    growth,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              NumberFormat.compact().format(value),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: darkTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedAnalytics(String metric) {
    final data = historicalData[metric] ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkCardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historical Data - ${_getMetricTitle(metric)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkTextColor,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[800],
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= data.length) return const Text('');
                        return Text(
                          data[value.toInt()]['date'].toString().substring(5, 7),
                          style: const TextStyle(
                            color: darkTextColor,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: _calculateInterval(data),
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          NumberFormat.compact().format(value),
                          style: const TextStyle(
                            color: darkTextColor,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: false,
                ),
                minX: 0,
                maxX: (data.length - 1).toDouble(),
                minY: _getMinY(data),
                maxY: _getMaxY(data),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        entry.value['value'].toDouble(),
                      );
                    }).toList(),
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: gradientColors,
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: primaryColor,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: gradientColors
                            .map((color) => color.withAlpha(51)) // Using withAlpha instead of withOpacity
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildAnalyticsSummary(data),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSummary(List<Map<String, dynamic>> data) {
    final currentValue = data.last['value'];
    final previousValue = data[data.length - 2]['value'];
    final growthRate = ((currentValue - previousValue) / previousValue * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(
                'Current',
                NumberFormat.compact().format(currentValue),
                Icons.arrow_upward,
              ),
              _buildSummaryItem(
                'Growth',
                '$growthRate%',
                Icons.trending_up,
              ),
              _buildSummaryItem(
                'Previous',
                NumberFormat.compact().format(previousValue),
                Icons.history,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[400]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: darkTextColor,
          ),
        ),
      ],
    );
  }

  String _getMetricTitle(String metric) {
    switch (metric) {
      case 'totalUsers':
        return 'Total Users';
      case 'totalHealthPros':
        return 'Health Professionals';
      case 'totalMealPlans':
        return 'Meal Plans';
      case 'totalWorkouts':
        return 'Total Workouts';
      case 'totalPremiumUsers':
        return 'Premium Users';
      default:
        return '';
    }
  }

  double _getMinY(List<Map<String, dynamic>> data) {
    final values = data.map((e) => e['value'] as num).toList();
    return (values.reduce(min) * 0.8).toDouble();
  }

  double _getMaxY(List<Map<String, dynamic>> data) {
    final values = data.map((e) => e['value'] as num).toList();
    return (values.reduce(max) * 1.2).toDouble();
  }

  double _calculateInterval(List<Map<String, dynamic>> data) {
    final maxValue = _getMaxY(data);
    final minValue = _getMinY(data);
    final difference = maxValue - minValue;

    final roughInterval = difference / 5;

    if (roughInterval <= 10) return 2;
    if (roughInterval <= 50) return 10;
    if (roughInterval <= 100) return 20;
    if (roughInterval <= 500) return 100;
    if (roughInterval <= 1000) return 200;
    return 500;
  }

  Future<void> fetchHistoricalData() async {
    try {
      // Store context before async gap
      final context = this.context;

      final historicalSnapshot = await _firestore
          .collection('analytics_history')
          .orderBy('timestamp', descending: true)
          .limit(6)
          .get();

      if (!mounted) return;

      // Process historical data
      final newHistoricalData = <String, List<Map<String, dynamic>>>{};

      for (var doc in historicalSnapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        final monthYear = DateFormat('yyyy-MM').format(timestamp);

        void updateMetric(String metricName, dynamic value) {
          newHistoricalData[metricName] ??= [];
          newHistoricalData[metricName]!.add({
            'date': monthYear,
            'value': value ?? 0,
          });
        }

        updateMetric('totalUsers', data['totalUsers']);
        updateMetric('totalHealthPros', data['totalHealthPros']);
        updateMetric('totalMealPlans', data['totalMealPlans']);
        updateMetric('totalWorkouts', data['totalWorkouts']);
        updateMetric('totalPremiumUsers', data['totalPremiumUsers']);
      }

      setState(() {
        // Uncomment when using real data
        // historicalData = newHistoricalData;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analytics data updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating analytics: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Future<void> _handleRefresh() async {
    await fetchHistoricalData();
  }

  @override
  void dispose() {
    // Clean up any controllers or subscriptions here
    super.dispose();
  }
}

/*
  // Additional utility methods for data processing and formatting
  String _formatValue(num value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  Color _getGrowthColor(double growth) {
    if (growth > 0) {
      return Colors.green;
    } else if (growth < 0) {
      return Colors.red;
    }
    return Colors.grey;
  }

  // Method to calculate period-over-period growth
  double _calculateGrowth(List<Map<String, dynamic>> data) {
    if (data.length < 2) return 0;
    final currentValue = data.last['value'] as num;
    final previousValue = data[data.length - 2]['value'] as num;
    return ((currentValue - previousValue) / previousValue * 100);
  }

  // Method to export analytics data
  Future<void> _exportAnalytics() async {
    // Implementation for exporting analytics data
    // This could generate a CSV or PDF report
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // Fetch all necessary data
      final analyticsData = await _firestore
          .collection('analytics')
          .doc('dashboard')
          .get();

      // Process data and create export
      // This is a placeholder for actual export logic
      await Future.delayed(const Duration(seconds: 2)); // Simulate processing

      // Hide loading indicator
      Navigator.pop(context);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analytics exported successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Hide loading indicator
      Navigator.pop(context);

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting analytics: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method to handle refresh
  Future<void> _handleRefresh() async {
    try {
      await fetchHistoricalData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analytics refreshed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing analytics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Build a floating action button for export functionality
  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _exportAnalytics,
      backgroundColor: primaryColor,
      child: const Icon(Icons.download),
    );
  }

  // Add refresh indicator wrapper
  Widget _wrapWithRefreshIndicator(Widget child) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: primaryColor,
      backgroundColor: darkCardColor,
      child: child,
    );
  }
*/

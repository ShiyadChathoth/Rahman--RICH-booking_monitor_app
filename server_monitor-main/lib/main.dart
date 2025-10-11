import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:workmanager/workmanager.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- MODELS ---
class Service {
  final String name;
  bool isRunning;
  bool isLoading;

  Service({required this.name, this.isRunning = false, this.isLoading = false});

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(name: json['name'], isRunning: json['is_running'] ?? false);
  }
}

// --- CONFIGURATION ---
const String baseApiUrl = "http://100.107.25.48:5000/api";
const String statsEndpoint = "$baseApiUrl/stats";
const String servicesEndpoint = "$baseApiUrl/services";
const String addServiceEndpoint = "$baseApiUrl/service/add";
const String removeServiceEndpoint = "$baseApiUrl/service/remove";
const double tempWarning = 60.0;
const double tempCritical = 80.0;
const appGroupId = 'group.pi_monitor';
const iOSWidgetName = 'PiMonitorWidget';
const androidWidgetName = 'PiMonitorWidgetProvider';
const serverStatusKey = 'last_server_status_is_online';
// NEW KEY for local persistence
const String hiddenServicesKey = 'local_hidden_services';

// --- NOTIFICATION SETUP ---
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _showServerDownNotification() async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'pi_monitor_channel',
        'Server Alerts',
        channelDescription: 'Notifications for Pi Monitor server status',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );
  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    0,
    'Raspberry Pi Monitor Alert',
    'The server is offline or unreachable.',
    platformChannelSpecifics,
  );
}

// --- BACKGROUND TASK ---
@pragma("vm:entry-point")
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool wasOnline = prefs.getBool(serverStatusKey) ?? true;

    try {
      final stats = await PiStats.fromApi();
      await prefs.setBool(serverStatusKey, true);
      await HomeWidget.saveWidgetData<bool>('server_is_online', true);
      await HomeWidget.saveWidgetData<String>('cpu_temp', stats.cpuTempText);
      await HomeWidget.saveWidgetData<String>(
        'cpu_temp_raw',
        stats.cpuTemp.toString(),
      );
      await HomeWidget.saveWidgetData<String>('cpu_text', stats.cpuUsageText);
      await HomeWidget.saveWidgetData<int>(
        'cpu_percent',
        stats.cpuUsage.round(),
      );
      await HomeWidget.saveWidgetData<String>('ram_text', stats.ramUsageText);
      await HomeWidget.saveWidgetData<int>(
        'ram_percent',
        stats.ramPercent.round(),
      );
      await HomeWidget.saveWidgetData<String>('disk_text', stats.diskUsageText);
      await HomeWidget.saveWidgetData<int>(
        'disk_percent',
        stats.diskPercent.round(),
      );
    } catch (e) {
      if (wasOnline) {
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        await flutterLocalNotificationsPlugin.initialize(
          const InitializationSettings(android: initializationSettingsAndroid),
        );
        await _showServerDownNotification();
      }
      await prefs.setBool(serverStatusKey, false);
      await HomeWidget.saveWidgetData<bool>('server_is_online', false);
    }

    await HomeWidget.updateWidget(
      iOSName: iOSWidgetName,
      androidName: androidWidgetName,
    );

    return Future.value(true);
  });
}

// --- MAIN ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: initializationSettingsAndroid),
  );

  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  Workmanager().registerPeriodicTask(
    "pi-monitor-widget-updater",
    "updatePiMonitorWidget",
    frequency: const Duration(minutes: 15),
  );
  runApp(const PiMonitorApp());
}

// --- DATA MODELS ---
class PiStats {
  final double cpuTemp;
  final double cpuUsage;
  final double ramPercent;
  final double ramUsedGb;
  final double ramTotalGb;
  final double diskPercent;
  final double diskUsedGb;
  final double diskTotalGb;

  PiStats({
    required this.cpuTemp,
    required this.cpuUsage,
    required this.ramPercent,
    required this.ramUsedGb,
    required this.ramTotalGb,
    required this.diskPercent,
    required this.diskUsedGb,
    required this.diskTotalGb,
  });

  factory PiStats.fromJson(Map<String, dynamic> json) {
    return PiStats(
      cpuTemp: (json['cpu_temp'] as num? ?? 0.0).toDouble(),
      cpuUsage: (json['cpu_usage'] as num? ?? 0.0).toDouble(),
      ramPercent: (json['ram_percent'] as num? ?? 0.0).toDouble(),
      ramUsedGb: (json['ram_used_gb'] as num? ?? 0.0).toDouble(),
      ramTotalGb: (json['ram_total_gb'] as num? ?? 0.0).toDouble(),
      diskPercent: (json['disk_percent'] as num? ?? 0.0).toDouble(),
      diskUsedGb: (json['disk_used_gb'] as num? ?? 0.0).toDouble(),
      diskTotalGb: (json['disk_total_gb'] as num? ?? 0.0).toDouble(),
    );
  }

  String get cpuTempText => '${cpuTemp.toStringAsFixed(1)}°C';
  String get cpuUsageText => '${cpuUsage.round()}%';
  String get ramUsageText =>
      '${ramUsedGb.toStringAsFixed(1)} GB / ${ramTotalGb.toStringAsFixed(1)} GB (${ramPercent.round()}%)';
  String get diskUsageText =>
      '${diskUsedGb.toStringAsFixed(1)} GB / ${diskTotalGb.toStringAsFixed(1)} GB (${diskPercent.round()}%)';

  static Future<PiStats> fromApi() async {
    final response = await http
        .get(Uri.parse(statsEndpoint))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return PiStats.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load stats (Status: ${response.statusCode})');
    }
  }
}

// --- APP ---
class PiMonitorApp extends StatelessWidget {
  const PiMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pi Health Monitor',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF2c2f33),
        primaryColor: const Color(0xFF7289da),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
      ),
      home: const MonitorScreen(),
    );
  }
}

// --- MAIN SCREEN ---
class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  Future<PiStats>? _statsFuture;
  Timer? _timer;
  List<Service> _services = [];
  bool _isLoadingServices = true;
  // NEW: Set to store service names hidden locally by the user
  Set<String> _hiddenServices = {};

  @override
  void initState() {
    super.initState();
    // Load local data before fetching remote data
    _loadHiddenServices().then((_) {
      _fetchInitialData();
    });

    _updateWidget();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchData();
      _fetchServiceStatuses();
    });
    HomeWidget.setAppGroupId(appGroupId);
  }

  // NEW: Function to load hidden services from SharedPreferences
  Future<void> _loadHiddenServices() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _hiddenServices = prefs.getStringList(hiddenServicesKey)?.toSet() ?? {};
      });
    }
  }

  // NEW: Function to save hidden services to SharedPreferences
  Future<void> _saveHiddenServices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(hiddenServicesKey, _hiddenServices.toList());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    _fetchData();
    // Now that _hiddenServices is loaded, fetch and filter the list
    await _fetchServiceList();
  }

  void _fetchData() {
    if (mounted) {
      setState(() {
        _statsFuture = PiStats.fromApi();
      });
    }
  }

  Future<void> _fetchServiceList() async {
    if (!mounted) return;
    setState(() => _isLoadingServices = true);
    try {
      final response = await http.get(Uri.parse(servicesEndpoint));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        var services = (data['services'] as List)
            .map((serviceJson) => Service.fromJson(serviceJson))
            .toList();

        // MODIFIED: Filter out services that are in the local hidden set
        services = services
            .where((s) => !_hiddenServices.contains(s.name))
            .toList();

        if (mounted) {
          setState(() {
            _services = services;
          });
        }
      } else {
        throw Exception(
          'Failed to load services list (Status: ${response.statusCode})',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Error loading services: ${e.toString()}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingServices = false);
      }
    }
  }

  Future<void> _fetchServiceStatuses() async {
    try {
      final response = await http.get(Uri.parse(servicesEndpoint));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final updatedServices = (data['services'] as List);
        if (mounted) {
          setState(() {
            for (var service in _services) {
              final updated = updatedServices.firstWhere(
                (s) => s['name'] == service.name,
                orElse: () => null,
              );
              if (updated != null && !service.isLoading) {
                service.isRunning = updated['is_running'];
              }
            }
          });
        }
      }
    } catch (e) {
      // Silently fail, main fetch will show connection error
    }
  }

  Future<void> _toggleService(Service service, bool value) async {
    if (!mounted) return;
    setState(() => service.isLoading = true);

    final action = value ? 'start' : 'stop';
    final url = Uri.parse('$baseApiUrl/service/${service.name}/$action');

    try {
      final response = await http
          .post(url)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_formatServiceName(service.name)} request sent.',
              ),
            ),
          );
        }
      } else {
        String errorText = 'Unknown error (Status: ${response.statusCode})';
        try {
          final errorData = jsonDecode(response.body);
          errorText = errorData['error'] ?? errorText;
        } on FormatException {
          errorText =
              'Server error or unexpected response format (Status: ${response.statusCode})';
        }
        throw Exception(errorText);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Error: ${e.toString()}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    } finally {
      Future.delayed(const Duration(seconds: 3), () {
        _fetchServiceStatuses().then((_) {
          if (mounted) {
            setState(() => service.isLoading = false);
          }
        });
      });
    }
  }

  Future<void> _addService(String serviceName) async {
    if (!mounted) return;
    try {
      final response = await http
          .post(
            Uri.parse(addServiceEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'service_name': serviceName}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // NEW: If a service is added back, ensure it is removed from the hidden list
        if (_hiddenServices.contains(serviceName)) {
          _hiddenServices.remove(serviceName);
          await _saveHiddenServices();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              content: Text(data['message']),
            ),
          );
        }
        await _fetchServiceList();
      } else {
        String errorText =
            'Failed to add service (Status: ${response.statusCode}).';
        try {
          final errorData = jsonDecode(response.body);
          errorText = errorData['message'] ?? errorText;
        } on FormatException {
          errorText =
              'Server error or unexpected response format (Status: ${response.statusCode})';
        }
        throw Exception(errorText);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Error: ${e.toString()}'),
          ),
        );
      }
    }
  }

  // MODIFIED: This function performs local-only, persistent removal.
  Future<void> _removeService(String serviceName) async {
    if (!mounted) return;

    // 1. Add the service name to the hidden set
    _hiddenServices.add(serviceName);

    // 2. Save the updated set to local storage
    await _saveHiddenServices();

    // 3. Remove the service from the local, currently displayed list
    setState(() {
      final index = _services.indexWhere((s) => s.name == serviceName);
      if (index != -1) {
        _services.removeAt(index);
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            '${_formatServiceName(serviceName)} removed from app monitor list only. This change is permanent across restarts.',
          ),
        ),
      );
    }
  }

  void _showAddServiceDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF36393f),
          title: const Text('Add New Service'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'e.g., my-service.service',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Remember to add sudo permissions on the server for this service.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final serviceName = controller.text.trim();
                if (serviceName.isNotEmpty) {
                  _addService(serviceName);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showRemoveConfirmationDialog(Service service) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF36393f),
          title: const Text('Remove Service'),
          content: Text(
            'Are you sure you want to remove ${_formatServiceName(service.name)} from the app\'s monitor list? It will remain configured on the Raspberry Pi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                _removeService(service.name);
                Navigator.of(context).pop();
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  String _formatServiceName(String name) {
    return name.replaceFirst('.service', '');
  }

  Future<void> _updateWidget() async {
    try {
      await PiStats.fromApi();
      await HomeWidget.saveWidgetData<bool>('server_is_online', true);
    } catch (e) {
      await HomeWidget.saveWidgetData<bool>('server_is_online', false);
    }
    await HomeWidget.updateWidget(
      iOSName: iOSWidgetName,
      androidName: androidWidgetName,
    );
  }

  Color _getUsageColor(double percentage) {
    if (percentage < 50) return Colors.green;
    if (percentage < 80) return Colors.yellow;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF36393f),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 4,
              ),
            ],
          ),
          child: FutureBuilder<PiStats>(
            future: _statsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _services.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError &&
                  _services.isEmpty &&
                  snapshot.connectionState != ConnectionState.waiting) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(isOnline: false),
                    const SizedBox(height: 20),
                    AlertCard(
                      message:
                          "SERVER DOWN: Cannot reach the API. Error: ${snapshot.error.toString()}",
                      color: Colors.red,
                    ),
                  ],
                );
              }

              final piStats = snapshot.data;
              return RefreshIndicator(
                onRefresh: _fetchInitialData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(isOnline: snapshot.hasData),
                      const SizedBox(height: 20),
                      if (piStats != null && piStats.cpuTemp >= tempCritical)
                        const AlertCard(
                          message: "CRITICAL: Temperature is very high!",
                          color: Colors.red,
                        )
                      else if (piStats != null &&
                          piStats.cpuTemp >= tempWarning)
                        AlertCard(
                          message: "WARNING: Temperature is high.",
                          color: Colors.yellow.shade700,
                        ),
                      if (piStats != null) ...[
                        const SizedBox(height: 10),
                        _buildTempDisplay(piStats.cpuTempText),
                        const SizedBox(height: 20),
                        MetricIndicator(
                          label: "CPU Usage",
                          value: piStats.cpuUsage,
                          valueText: piStats.cpuUsageText,
                          color: _getUsageColor(piStats.cpuUsage),
                        ),
                        MetricIndicator(
                          label: "RAM Usage",
                          value: piStats.ramPercent,
                          valueText: piStats.ramUsageText,
                          color: _getUsageColor(piStats.ramPercent),
                        ),
                        MetricIndicator(
                          label: "Disk Usage",
                          value: piStats.diskPercent,
                          valueText: piStats.diskUsageText,
                          color: _getUsageColor(piStats.diskPercent),
                        ),
                      ],
                      const SizedBox(height: 20),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Services",
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: _showAddServiceDialog,
                            tooltip: 'Add New Service',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _isLoadingServices
                          ? const CircularProgressIndicator()
                          : _services.isEmpty
                          ? const Text('No services configured.')
                          : Column(
                              children: _services
                                  .map(
                                    (service) => ListTile(
                                      title: Text(
                                        _formatServiceName(service.name),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          service.isLoading
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                )
                                              : Switch(
                                                  value: service.isRunning,
                                                  onChanged: (value) =>
                                                      _toggleService(
                                                        service,
                                                        value,
                                                      ),
                                                ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.redAccent,
                                            ),
                                            onPressed: () =>
                                                _showRemoveConfirmationDialog(
                                                  service,
                                                ),
                                            tooltip: 'Remove Service',
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({required bool isOnline}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.developer_board,
          color: Theme.of(context).primaryColor,
          size: 30,
        ),
        const SizedBox(width: 15),
        const Expanded(
          child: Text(
            "Raspberry Pi Monitor",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 15),
        StatusIndicator(isOnline: isOnline),
      ],
    );
  }

  Widget _buildTempDisplay(String? tempText) {
    final tempValue = double.tryParse(
      tempText?.replaceAll('°C', '').trim() ?? '',
    );
    final tempColor = tempValue == null
        ? Colors.white
        : tempValue >= tempCritical
        ? Colors.red
        : tempValue >= tempWarning
        ? Colors.yellow.shade700
        : Colors.green;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "CPU Temperature: ",
          style: TextStyle(fontSize: 18, color: Colors.white70),
        ),
        Text(
          tempText ?? "-- °C",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: tempColor,
          ),
        ),
      ],
    );
  }
}

// --- HELPER WIDGETS ---
class MetricIndicator extends StatelessWidget {
  final String label;
  final double? value;
  final String? valueText;
  final Color color;

  const MetricIndicator({
    super.key,
    required this.label,
    this.value,
    this.valueText,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              Text(
                valueText ?? "--",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearPercentIndicator(
            percent: (value ?? 0) / 100.0,
            lineHeight: 15,
            barRadius: const Radius.circular(5),
            backgroundColor: const Color(0xFF4a4d52),
            progressColor: color,
          ),
        ],
      ),
    );
  }
}

class StatusIndicator extends StatelessWidget {
  final bool isOnline;
  const StatusIndicator({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? Colors.green : Colors.red,
        boxShadow: [
          BoxShadow(
            color: (isOnline ? Colors.green : Colors.red).withOpacity(0.7),
            blurRadius: 5,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class AlertCard extends StatelessWidget {
  final String message;
  final Color color;
  const AlertCard({super.key, required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 16,
        ),
      ),
    );
  }
}

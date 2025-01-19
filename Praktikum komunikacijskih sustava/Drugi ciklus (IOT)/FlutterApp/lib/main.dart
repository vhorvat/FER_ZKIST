import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ThingsBoard App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _customerId;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final loginResponse = await _loginUser(
          _emailController.text,
          _passwordController.text,
        );
        if (loginResponse != null) {
          // Extract token and customer ID
          final token = loginResponse['token'];
          _customerId = loginResponse['customerId'];

          print('Login Successful:');
          print('Token: $token');
          print('Customer ID: $_customerId');

          // Navigate to device list
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    DeviceListScreen(token: token, customerId: _customerId!)),
          );
        } else {
          setState(() {
            _errorMessage = 'Login failed. Invalid credentials.';
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _loginUser(String email, String password) async {
    const String baseUrl = 'http://iot.leonunger.from.hr';
    final loginUrl = '$baseUrl/api/auth/login';
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({'username': email, 'password': password});

    print('Login Request:');
    print('URL: $loginUrl');
    print('Headers: $headers');
    print('Body: $body');

    final loginResponse = await http.post(
      Uri.parse(loginUrl),
      headers: headers,
      body: body,
    );

    print('Login Response:');
    print('Status Code: ${loginResponse.statusCode}');
    print('Body: ${loginResponse.body}');

    if (loginResponse.statusCode == 200) {
      final responseData = jsonDecode(loginResponse.body);
      final token = responseData['token'];

      // Fetch user details to get customer ID
      final userDetails = await _fetchUserDetails(baseUrl, token);
      if (userDetails != null) {
        return {
          'token': token,
          'customerId': userDetails['customerId'],
        };
      } else {
        throw Exception('Failed to fetch user details.');
      }
    } else {
      throw Exception('Failed to login: ${loginResponse.body}');
    }
  }

  Future<Map<String, dynamic>?> _fetchUserDetails(String baseUrl, String token) async {
    final userUrl = '$baseUrl/api/auth/user';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    print('Fetch User Details Request:');
    print('URL: $userUrl');
    print('Headers: $headers');

    final userResponse = await http.get(
      Uri.parse(userUrl),
      headers: headers,
    );

    print('Fetch User Details Response:');
    print('Status Code: ${userResponse.statusCode}');
    print('Body: ${userResponse.body}');

    if (userResponse.statusCode == 200) {
      final userDetails = jsonDecode(userResponse.body);
      return {
        'customerId': userDetails['customerId']['id'],
      };
    } else {
      throw Exception('Failed to fetch user details: ${userResponse.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeviceListScreen extends StatefulWidget {
  final String token;
  final String customerId;

  const DeviceListScreen({super.key, required this.token, required this.customerId});

  @override
  _DeviceListScreenState createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  late Future<List<Device>> _devicesFuture;

  @override
  void initState() {
    super.initState();
    print('DeviceListScreen initState:');
    print('Token: ${widget.token}');
    print('Customer ID: ${widget.customerId}');
    _devicesFuture = _fetchDevices();
  }

  Future<List<Device>> _fetchDevices() async {
    const String baseUrl = 'http://iot.leonunger.from.hr';
    final url = '$baseUrl/api/customer/${widget.customerId}/devices?pageSize=10&page=0';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${widget.token}',
    };

    print('Device List Request:');
    print('URL: $url');
    print('Headers: $headers');

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    print('Device List Response:');
    print('Status Code: ${response.statusCode}');
    print('Body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List<dynamic> devicesJson = responseData['data'];
      return devicesJson.map((json) => Device.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch devices: ${response.body}');
    }
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: FutureBuilder<List<Device>>(
        future: _devicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final devices = snapshot.data!;
            return ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  title: Text(device.name),
                  subtitle: Text('Type: ${device.type}'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DeviceDetailsScreen(
                          token: widget.token,
                          deviceId: device.id,
                          deviceName: device.name,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          } else {
            return const Center(child: Text('No devices found.'));
          }
        },
      ),
    );
  }
}

class Device {
  final String id;
  final String name;
  final String type;

  Device({required this.id, required this.name, required this.type});

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id']['id'],
      name: json['name'],
      type: json['type'],
    );
  }
}

class DeviceDetailsScreen extends StatefulWidget {
  final String token;
  final String deviceId;
  final String deviceName;

  const DeviceDetailsScreen({super.key, required this.token, required this.deviceId, required this.deviceName});

  @override
  _DeviceDetailsScreenState createState() => _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends State<DeviceDetailsScreen> {
  late Future<Map<String, dynamic>> _telemetryFuture;

  @override
  void initState() {
    super.initState();
    _telemetryFuture = _fetchTelemetry();
  }

  Future<Map<String, dynamic>> _fetchTelemetry() async {
    const String baseUrl = 'http://iot.leonunger.from.hr';
    final url = '$baseUrl/api/plugins/telemetry/DEVICE/${widget.deviceId}/values/timeseries?keys=temperature,humidity&limit=10';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${widget.token}',
    };

    print('Telemetry Request:');
    print('URL: $url');
    print('Headers: $headers');

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    print('Telemetry Response:');
    print('Status Code: ${response.statusCode}');
    print('Body: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch telemetry: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Telemetry for ${widget.deviceName}')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _telemetryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final telemetryData = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: telemetryData.entries.map((entry) {
                final key = entry.key;
                final values = entry.value as List<dynamic>;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      key,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    for (final value in values)
                      if (value != null && value is Map<String, dynamic> && value.containsKey('ts') && value.containsKey('value'))
                        Text(
                          '${DateTime.fromMillisecondsSinceEpoch(value['ts'])}: ${value['value']}',
                          style: const TextStyle(fontSize: 16),
                        )
                      else
                        const Text(
                          'No data available',
                          style: TextStyle(fontSize: 16),
                        ),
                    const SizedBox(height: 16),
                  ],
                );
              }).toList(),
            );
          } else {
            return const Center(child: Text('No telemetry data found.'));
          }
        },
      ),
    );
  }
}
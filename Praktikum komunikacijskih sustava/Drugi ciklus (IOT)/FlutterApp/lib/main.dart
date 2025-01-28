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
        scaffoldBackgroundColor: Colors.white,
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
          final token = loginResponse['token'];
          _customerId = loginResponse['customerId'];

          print('Login Successful:');
          print('Token: $token');
          print('Customer ID: $_customerId');

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
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 100),
            Image.asset(
              'assets/images/logo.png',
              height: 200,
            ),
            SizedBox(height: 1),
            Padding(
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
          ],
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
        title: const Text('Dostupni senzori:'),
        backgroundColor: Colors.white,
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
  late Future<List<dynamic>> _sharedAttributesFuture;
  final TextEditingController _desiredTempController = TextEditingController();
  bool _isUpdating = false;
  String? _updateMessage;
  bool _controlBoolean = false;

  @override
  void initState() {
    super.initState();
    _telemetryFuture = _fetchTelemetry();
    _sharedAttributesFuture = _fetchSharedAttributes();
  }

  @override
  void dispose() {
    _desiredTempController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() {
    setState(() {
      _telemetryFuture = _fetchTelemetry();
      _sharedAttributesFuture = _fetchSharedAttributes();
    });
    return Future.value();
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

  Future<List<dynamic>> _fetchSharedAttributes() async {
    const String baseUrl = 'http://iot.leonunger.from.hr';
    final url = '$baseUrl/api/plugins/telemetry/DEVICE/${widget.deviceId}/values/attributes/SHARED_SCOPE';
    final headers = {
      'Content-Type': 'application/json',
      'x-authorization': 'Bearer ${widget.token}',
    };

    print('Shared Attributes Request:');
    print('URL: $url');
    print('Headers: $headers');
    print('Device ID: ${widget.deviceId}');

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    print('Shared Attributes Response:');
    print('Status Code: ${response.statusCode}');
    print('Body: ${response.body}');

    if (response.statusCode == 200) {
      try {
        final attributes = jsonDecode(response.body) as List<dynamic>;
        for (var attribute in attributes) {
          if (attribute['key'] == 'controlBoolean') {
            _controlBoolean = attribute['value'] == true;
          }
        }
        return attributes;
      } catch (e) {
        print('Error decoding Shared Attributes JSON: $e');
        print('Response body was: ${response.body}');
        throw Exception('Failed to decode shared attributes: $e');
      }
    } else {
      throw Exception('Failed to fetch shared attributes: ${response.body}');
    }
  }


  Future<void> _updateDesiredTemp() async {
    setState(() {
      _isUpdating = true;
      _updateMessage = null;
    });
    const String baseUrl = 'http://iot.leonunger.from.hr';
    final url = '$baseUrl/api/plugins/telemetry/DEVICE/${widget.deviceId}/SHARED_SCOPE';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${widget.token}',
    };
    final desiredTemp = _desiredTempController.text;
    final body = jsonEncode({'desiredTemp': desiredTemp});

    print('Update Desired Temp Request:');
    print('URL: $url');
    print('Headers: $headers');
    print('Body: $body');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      print('Update Desired Temp Response:');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        setState(() {
          _updateMessage = 'Desired temperature updated successfully!';
        });
        _refreshData();
      } else {
        setState(() {
          _updateMessage = 'Failed to update desired temperature: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _updateMessage = 'Error updating desired temperature: $e';
      });
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _updateControlBoolean(bool value) async {
    setState(() {
      _isUpdating = true;
      _updateMessage = null;
    });
    const String baseUrl = 'http://iot.leonunger.from.hr';
    final url = '$baseUrl/api/plugins/telemetry/DEVICE/${widget.deviceId}/SHARED_SCOPE';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${widget.token}',
    };
    final body = jsonEncode({'controlBoolean': value});

    print('Update controlBoolean Request:');
    print('URL: $url');
    print('Headers: $headers');
    print('Body: $body');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      print('Update controlBoolean Response:');
      print('Status Code: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        setState(() {
          _controlBoolean = value;
          _updateMessage = 'Manual override updated successfully!';
        });
        _refreshData();
      } else {
        setState(() {
          _updateMessage = 'Failed to update manual override: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _updateMessage = 'Error updating manual override: $e';
      });
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold( appBar: AppBar(
      title: Text('${widget.deviceName}'),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _refreshData,
        ),
      ],
    ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: Image.asset(
                        'assets/images/pool.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Temperature:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        FutureBuilder<Map<String, dynamic>>(
                          future: _telemetryFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const CircularProgressIndicator();
                            } else if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            } else if (snapshot.hasData) {
                              final telemetryData = snapshot.data!;
                              if (telemetryData.containsKey('temperature')) {
                                final temperatureValues = telemetryData['temperature'] as List<dynamic>;
                                if (temperatureValues.isNotEmpty) {
                                  final latestTemperature = temperatureValues.last;
                                  return Text(
                                    latestTemperature != null && latestTemperature is Map<String, dynamic> && latestTemperature.containsKey('value')
                                        ? '${latestTemperature['value']} °C'
                                        : 'No temperature data',
                                    style: const TextStyle(fontSize: 16),
                                  );
                                } else {
                                  return const Text('No temperature data');
                                }
                              } else {
                                return const Text('No temperature data');
                              }
                            } else {
                              return const Text('No temperature data');
                            }
                          },
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          'Heater active:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        FutureBuilder<List<dynamic>>(
                          future: _sharedAttributesFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const CircularProgressIndicator();
                            } else if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            } else if (snapshot.hasData) {
                              final sharedAttributes = snapshot.data!;
                              String controlBooleanValue = 'No data';
                              for (var attribute in sharedAttributes) {
                                if (attribute['key'] == 'controlBoolean') {
                                  controlBooleanValue = attribute['value'].toString();
                                  break;
                                }
                              }
                              return Text(
                                controlBooleanValue,
                                style: const TextStyle(fontSize: 16),
                              );
                            } else {
                              return const Text('No data');
                            }
                          },
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          'Desired temperature:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        FutureBuilder<List<dynamic>>(
                          future: _sharedAttributesFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const CircularProgressIndicator();
                            } else if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            } else if (snapshot.hasData) {
                              final sharedAttributes = snapshot.data!;
                              String desiredTempValue = 'No data';
                              for (var attribute in sharedAttributes) {
                                if (attribute['key'] == 'desiredTemp') {
                                  desiredTempValue = attribute['value'].toString();
                                  break;
                                }
                              }
                              return Text(
                                desiredTempValue,
                                style: const TextStyle(fontSize: 16),
                              );
                            } else {
                              return const Text('No data');
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Manual heater override:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.normal),
                ),
                Switch(
                  value: _controlBoolean,
                  onChanged: _isUpdating ? null : (value) => _updateControlBoolean(value),
                ),
              ],
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _desiredTempController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Desired Temperature',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isUpdating ? null : _updateDesiredTemp,
              child: _isUpdating
                  ? const CircularProgressIndicator()
                  : const Text('Update Desired Temperature'),
            ),


            if (_updateMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Text(
                  _updateMessage!,
                  style: TextStyle(
                    color: _updateMessage!.startsWith('Failed') || _updateMessage!.startsWith('Error') ? Colors.red : Colors.green,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
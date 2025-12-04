import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;

class DeliveryScreen extends StatefulWidget {
  final Map<String, dynamic> paquete;

  const DeliveryScreen({Key? key, required this.paquete}) : super(key: key);

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  File? _fotoLocal;
  Uint8List? _fotoWeb;
  String? _fotoNombre;
  double? _gpsLat;
  double? _gpsLng;
  final TextEditingController _gpsLatController = TextEditingController();
  final TextEditingController _gpsLngController = TextEditingController();
  bool _isGettingLocation = false;
  bool _isSending = false;
  String _message = '';
  bool _isMobile = false;
  late MapController _mapController;

  final String apiUrl = 'http://10.127.57.108:8000';

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _checkPlatform();
    _getLocation();
  }

  void _checkPlatform() {
    try {
      _isMobile = Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      _isMobile = false;
    }
  }

  Future<void> _getLocation() async {
    if (!_isMobile) return;

    setState(() {
      _isGettingLocation = true;
    });

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _gpsLat = position.latitude;
        _gpsLng = position.longitude;
        _gpsLatController.text = _gpsLat.toString();
        _gpsLngController.text = _gpsLng.toString();
        _isGettingLocation = false;
      });

      _mapController.move(LatLng(_gpsLat!, _gpsLng!), 15.0);
    } catch (e) {
      setState(() {
        _message = 'Error al obtener ubicación: $e';
        _isGettingLocation = false;
      });
    }
  }

  Future<void> _tomarFoto() async {
    if (_isMobile) {
      try {
        final photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );

        if (photo != null) {
          setState(() {
            _fotoLocal = File(photo.path);
            _fotoNombre = photo.name;
            _message = '';
          });
        }
      } catch (e) {
        setState(() {
          _message = 'Error al capturar foto: $e';
        });
      }
    }
  }

  Future<void> _seleccionarDaleria() async {
    if (_isMobile) {
      try {
        final photo = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );

        if (photo != null) {
          setState(() {
            _fotoLocal = File(photo.path);
            _fotoNombre = photo.name;
            _message = '';
          });
        }
      } catch (e) {
        setState(() {
          _message = 'Error al seleccionar foto: $e';
        });
      }
    } else {
      html.FileUploadInputElement uploadInput = html.FileUploadInputElement()
        ..accept = 'image/*';
      uploadInput.click();

      uploadInput.onChange.listen((e) {
        final files = uploadInput.files;
        if (files!.isNotEmpty) {
          final file = files[0];
          final reader = html.FileReader();
          reader.readAsArrayBuffer(file);

          reader.onLoad.listen((e) {
            setState(() {
              _fotoWeb = reader.result as Uint8List;
              _fotoNombre = file.name;
              _message = '';
            });
          });
        }
      });
    }
  }

  Future<void> _entregarPaquete() async {
    if (_fotoLocal == null && _fotoWeb == null) {
      setState(() {
        _message = 'Por favor selecciona una foto';
      });
      return;
    }

    double? lat, lng;
    if (_isMobile) {
      lat = _gpsLat;
      lng = _gpsLng;
    } else {
      try {
        lat = double.parse(_gpsLatController.text);
        lng = double.parse(_gpsLngController.text);
      } catch (e) {
        setState(() {
          _message = 'Por favor ingresa coordenadas GPS válidas';
        });
        return;
      }
    }

    if (lat == null || lng == null) {
      setState(() {
        _message = 'Por favor ingresa la ubicación GPS';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _message = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$apiUrl/paquetes/${widget.paquete['id']}/entregar'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['gps_lat'] = lat.toString();
      request.fields['gps_lng'] = lng.toString();

      if (_fotoLocal != null) {
        request.files.add(
          await http.MultipartFile.fromPath('foto', _fotoLocal!.path),
        );
      } else if (_fotoWeb != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'foto',
            _fotoWeb!,
            filename: _fotoNombre ?? 'foto.jpg',
          ),
        );
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        setState(() {
          _message = 'Paquete entregado exitosamente';
        });
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pop(context, true);
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _message = 'Sesión expirada';
        });
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
      } else {
        setState(() {
          _message = 'Error al entregar paquete (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Error: $e';
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool puedeEntregar =
        (_fotoLocal != null || _fotoWeb != null) &&
        _gpsLat != null &&
        _gpsLng != null &&
        !_isSending;

    return Scaffold(
      appBar: AppBar(title: const Text('Entregar Paquete')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Descripción: ${widget.paquete['descripcion']}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Dirección: ${widget.paquete['direccion']}'),
              const SizedBox(height: 24),

              Card(
                child: SizedBox(
                  height: 300,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(
                        _gpsLat ?? 19.4326,
                        _gpsLng ?? -99.1332,
                      ),
                      initialZoom: 15.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=5Zrwfm4hC5UgCGsqTSjA',
                        userAgentPackageName: 'com.example.paquexpress_app',
                      ),
                      MarkerLayer(
                        markers: [
                          if (_gpsLat != null && _gpsLng != null)
                            Marker(
                              point: LatLng(_gpsLat!, _gpsLng!),
                              width: 80,
                              height: 80,
                              child: Column(
                                children: const [
                                  Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                  Text(
                                    'Ubicación actual',
                                    style: TextStyle(
                                      fontSize: 10,
                                      backgroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ubicación GPS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_isMobile)
                        if (_isGettingLocation)
                          const CircularProgressIndicator()
                        else if (_gpsLat != null && _gpsLng != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Latitud: ${_gpsLat?.toStringAsFixed(6)}'),
                              Text('Longitud: ${_gpsLng?.toStringAsFixed(6)}'),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _getLocation,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Actualizar'),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              const Text('No se pudo obtener ubicación'),
                              ElevatedButton(
                                onPressed: _getLocation,
                                child: const Text('Intentar de nuevo'),
                              ),
                            ],
                          )
                      else
                        Column(
                          children: [
                            TextField(
                              controller: _gpsLatController,
                              decoration: const InputDecoration(
                                labelText: 'Latitud GPS',
                                border: OutlineInputBorder(),
                                hintText: '19.4326',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _gpsLngController,
                              decoration: const InputDecoration(
                                labelText: 'Longitud GPS',
                                border: OutlineInputBorder(),
                                hintText: '-99.1332',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Foto de Entrega',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_fotoLocal != null && _isMobile)
                        Column(
                          children: [
                            Image.file(
                              _fotoLocal!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _tomarFoto,
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text('Otra foto'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _seleccionarDaleria,
                                    icon: const Icon(Icons.image),
                                    label: const Text('Galería'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      else if (_fotoWeb != null && !_isMobile)
                        Column(
                          children: [
                            Image.memory(
                              _fotoWeb!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            const SizedBox(height: 12),
                            Text('Archivo: $_fotoNombre'),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _seleccionarDaleria,
                              icon: const Icon(Icons.image),
                              label: const Text('Seleccionar otra'),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            const Icon(Icons.image_not_supported, size: 60),
                            const SizedBox(height: 12),
                            if (_isMobile)
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _tomarFoto,
                                      icon: const Icon(Icons.camera_alt),
                                      label: const Text('Cámara'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _seleccionarDaleria,
                                      icon: const Icon(Icons.image),
                                      label: const Text('Galería'),
                                    ),
                                  ),
                                ],
                              )
                            else
                              ElevatedButton.icon(
                                onPressed: _seleccionarDaleria,
                                icon: const Icon(Icons.image),
                                label: const Text('Seleccionar foto'),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (_message.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _message.contains('exitoso')
                        ? Colors.green[100]
                        : Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _message,
                    style: TextStyle(
                      color: _message.contains('exitoso')
                          ? Colors.green[900]
                          : Colors.red[900],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: puedeEntregar
                      ? () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Confirmar entrega'),
                                content: const Text(
                                  '¿Seguro que quieres marcar este paquete como entregado?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Sí, entregar'),
                                  ),
                                ],
                              );
                            },
                          );

                          if (ok == true && !_isSending) {
                            await _entregarPaquete();
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSending
                      ? const CircularProgressIndicator()
                      : const Text(
                          'Marcar como Entregado',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _gpsLatController.dispose();
    _gpsLngController.dispose();
    _mapController.dispose();
    super.dispose();
  }
}

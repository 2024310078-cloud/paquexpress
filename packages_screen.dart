import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'delivery_screen.dart';
import 'package_detail_screen.dart';

class PackagesScreen extends StatefulWidget {
  const PackagesScreen({Key? key}) : super(key: key);

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  List<dynamic> _paquetes = [];
  bool _isLoading = true;
  String _errorMessage = '';
  bool _soloPendientes = true;
  String _searchText = '';

  final String apiUrl = 'http://10.127.57.108:8000';

  @override
  void initState() {
    super.initState();
    _loadPaquetes();
  }

  Future<void> _loadPaquetes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        setState(() {
          _errorMessage = 'Sesión no válida. Inicia sesión de nuevo.';
          _isLoading = false;
        });
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
        return;
      }

      final response = await http.get(
        Uri.parse('$apiUrl/paquetes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _paquetes = data;
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _errorMessage = 'Sesión expirada. Inicia sesión de nuevo.';
          _isLoading = false;
        });
        await prefs.clear();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
      } else {
        setState(() {
          _errorMessage = 'Error al cargar paquetes (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _abrirEnMaps(String direccion) async {
    final encoded = Uri.encodeComponent(direccion);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encoded',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No se pudo abrir Maps')));
    }
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> paquetesFiltrados = _soloPendientes
        ? _paquetes.where((p) => p['estatus'] != 'entregado').toList()
        : List<dynamic>.from(_paquetes);

    if (_searchText.isNotEmpty) {
      final query = _searchText.toLowerCase();
      paquetesFiltrados = paquetesFiltrados.where((p) {
        final desc = (p['descripcion'] ?? '').toString().toLowerCase();
        final dir = (p['direccion'] ?? '').toString().toLowerCase();
        return desc.contains(query) || dir.contains(query);
      }).toList();
    }

    final totalPendientes = _paquetes
        .where((p) => p['estatus'] != 'entregado')
        .length;
    final totalEntregados = _paquetes
        .where((p) => p['estatus'] == 'entregado')
        .length;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pendientes: $totalPendientes  ·  Entregados: $totalEntregados',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar por descripción o dirección',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchText = value;
                  });
                },
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('Solo pendientes', style: TextStyle(fontSize: 11)),
                  Switch(
                    value: _soloPendientes,
                    onChanged: (value) {
                      setState(() {
                        _soloPendientes = value;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: paquetesFiltrados.isEmpty
              ? const Center(child: Text('No hay paquetes'))
              : ListView.builder(
                  itemCount: paquetesFiltrados.length,
                  itemBuilder: (context, index) {
                    final paquete = paquetesFiltrados[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(paquete['descripcion']),
                        subtitle: Text(paquete['direccion']),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.map),
                              onPressed: () {
                                final direccion = (paquete['direccion'] ?? '')
                                    .toString();
                                if (direccion.isNotEmpty) {
                                  _abrirEnMaps(direccion);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.info_outline),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PackageDetailScreen(paquete: paquete),
                                  ),
                                );
                              },
                            ),
                            Chip(
                              label: Text(paquete['estatus']),
                              backgroundColor: paquete['estatus'] == 'entregado'
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ],
                        ),
                        onTap: () {
                          if (paquete['estatus'] != 'entregado') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    DeliveryScreen(paquete: paquete),
                              ),
                            ).then((result) {
                              if (result == true) {
                                _loadPaquetes();
                              }
                            });
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

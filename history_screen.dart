import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _historial = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _filtro = 'todos'; // 'hoy', 'semana', 'todos'

  final String apiUrl = 'http://10.127.57.108:8000';

  @override
  void initState() {
    super.initState();
    _loadHistorial();
  }

  Future<void> _loadHistorial() async {
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

      final now = DateTime.now();
      String query = '';

      if (_filtro == 'hoy') {
        final d =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        query = '?desde=$d&hasta=$d';
      } else if (_filtro == 'semana') {
        final inicioSemana = now.subtract(Duration(days: now.weekday - 1));
        final finSemana = inicioSemana.add(const Duration(days: 6));
        String f(DateTime x) =>
            '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
        query = '?desde=${f(inicioSemana)}&hasta=${f(finSemana)}';
      }

      final response = await http.get(
        Uri.parse('$apiUrl/historial$query'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _historial = data;
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
          _errorMessage = 'Error al cargar historial (${response.statusCode})';
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Todos'),
                selected: _filtro == 'todos',
                onSelected: (v) {
                  if (v) {
                    setState(() {
                      _filtro = 'todos';
                      _isLoading = true;
                    });
                    _loadHistorial();
                  }
                },
              ),
              ChoiceChip(
                label: const Text('Hoy'),
                selected: _filtro == 'hoy',
                onSelected: (v) {
                  if (v) {
                    setState(() {
                      _filtro = 'hoy';
                      _isLoading = true;
                    });
                    _loadHistorial();
                  }
                },
              ),
              ChoiceChip(
                label: const Text('Esta semana'),
                selected: _filtro == 'semana',
                onSelected: (v) {
                  if (v) {
                    setState(() {
                      _filtro = 'semana';
                      _isLoading = true;
                    });
                    _loadHistorial();
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _historial.isEmpty
              ? const Center(child: Text('No hay entregas en este rango'))
              : ListView.builder(
                  itemCount: _historial.length,
                  itemBuilder: (context, index) {
                    final p = _historial[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(p['descripcion'] ?? ''),
                        subtitle: Text(
                          '${p['direccion'] ?? ''}\nEntregado: ${p['fecha_entrega'] ?? ''}',
                        ),
                        isThreeLine: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PackageDetailScreen(paquete: p),
                            ),
                          );
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

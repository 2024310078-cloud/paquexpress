import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class PackageDetailScreen extends StatelessWidget {
  final Map<String, dynamic> paquete;

  const PackageDetailScreen({Key? key, required this.paquete})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double? lat = paquete['gps_lat'] != null
        ? (paquete['gps_lat'] as num).toDouble()
        : null;
    final double? lng = paquete['gps_lng'] != null
        ? (paquete['gps_lng'] as num).toDouble()
        : null;
    final String? fotoUrl = paquete['foto_url'];

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del Paquete')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              paquete['descripcion'] ?? '',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Dirección: ${paquete['direccion'] ?? ''}'),
            const SizedBox(height: 8),
            Text('Estatus: ${paquete['estatus'] ?? ''}'),
            const SizedBox(height: 8),
            if (paquete['fecha_entrega'] != null)
              Text('Fecha de entrega: ${paquete['fecha_entrega']}'),
            const SizedBox(height: 16),

            // Foto
            if (fotoUrl != null && fotoUrl.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Foto de entrega',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Image.network(
                    fotoUrl,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(height: 16),
                ],
              )
            else
              const Text('Sin foto registrada.'),

            const SizedBox(height: 8),

            // Mapa
            if (lat != null && lng != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ubicación de entrega',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 250,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(lat, lng),
                        initialZoom: 16,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=5Zrwfm4hC5UgCGsqTSjA',
                          userAgentPackageName: 'com.example.paquexpress_app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(lat, lng),
                              width: 60,
                              height: 60,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              const Text('Sin ubicación registrada para este paquete.'),
          ],
        ),
      ),
    );
  }
}

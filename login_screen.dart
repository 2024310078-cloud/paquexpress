import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  final String apiUrl = 'http://10.127.57.108:8000';

  bool _validarCampos() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    print('VALIDAR: "$email" / "$password"');

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Ingresa email y contraseña';
      });
      return false;
    }

    // Validación simple de formato de email
    if (!email.contains('@') || !email.contains('.')) {
      setState(() {
        _errorMessage = 'Ingresa un email válido';
      });
      return false;
    }

    if (password.length < 4) {
      setState(() {
        _errorMessage = 'La contraseña es muy corta';
      });
      return false;
    }

    return true;
  }

  Future<void> _login() async {
    if (!_validarCampos()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        final agenteId = data['agente_id'];
        final nombre = data['nombre'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        await prefs.setString('token', token);
        await prefs.setInt('agente_id', agenteId);
        await prefs.setString('nombre', nombre);

        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else if (response.statusCode == 401) {
        setState(() {
          _errorMessage = 'Email o contraseña incorrectos';
        });
      } else {
        setState(() {
          _errorMessage = 'Error en el servidor (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paquexpress Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            if (_errorMessage.isNotEmpty)
              Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Iniciar Sesión'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

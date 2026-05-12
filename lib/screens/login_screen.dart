import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _selectedRol;
  final _codeController = TextEditingController();
  bool _obscure = true;

  static const _roles = [
    {'value': kRolCoordinador, 'label': 'Coordinador Proceso'},
    {'value': kRolEncargado, 'label': 'Encargado Cuarto Frío'},
    {'value': kRolSupervisor, 'label': 'Supervisor Despacho'},
  ];

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _login() {
    if (_selectedRol == null) {
      _showError('Selecciona un rol');
      return;
    }
    final success =
        context.read<AuthProvider>().login(_codeController.text.trim());
    if (!success) {
      _showError('Código incorrecto');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.ac_unit, size: 64, color: cs.primary),
                    const SizedBox(height: 8),
                    Text(
                      'Cuarto Frío',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold, color: cs.primary),
                    ),
                    Text(
                      'Inventario de Aves',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 32),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Rol',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.people),
                      ),
                      initialValue: _selectedRol,
                      items: _roles
                          .map((r) => DropdownMenuItem(
                                value: r['value'],
                                child: Text(r['label']!),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedRol = v),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _codeController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Código de acceso',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      onFieldSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _login,
                        icon: const Icon(Icons.login),
                        label: const Text('Ingresar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

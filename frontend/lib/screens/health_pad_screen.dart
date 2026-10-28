import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HealthPadScreen extends StatelessWidget {
  const HealthPadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        title: const Text('Health PAD'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sensors_off_rounded,
                  size: 64,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Equipamento PAD Não Conectado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'A integração física com o leitor RFID e feedback por hardware não faz parte desta versão do MVP. Os testes e validações acontecem no modo manual ou simulado.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 36),
              ElevatedButton.icon(
                onPressed: null, // Desabilitado conforme RF-034
                icon: const Icon(Icons.sync_disabled_rounded),
                label: const Text('Testar Conectividade (Desabilitado)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

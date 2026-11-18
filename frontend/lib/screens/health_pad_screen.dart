import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/braillepad_ble_service.dart';
import '../theme/app_theme.dart';

class HealthPadScreen extends StatelessWidget {
  const HealthPadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ble = BraillepadBleService.instance;

    return AnimatedBuilder(
      animation: ble,
      builder: (context, _) {
        final isConnected = ble.connected;
        final color = isConnected ? Colors.green.shade700 : Colors.grey.shade600;

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
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 28),
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: isConnected
                          ? Colors.green.shade50
                          : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isConnected
                          ? Icons.bluetooth_connected_rounded
                          : Icons.bluetooth_disabled_rounded,
                      size: 62,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isConnected
                      ? 'Equipamento PAD Conectado'
                      : 'Equipamento PAD Não Conectado',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  ble.status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                if (isConnected && ble.deviceId != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Identificador: ${ble.deviceId}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                if (isConnected) ...[
                  const SizedBox(height: 28),
                  const Text(
                    'Última ficha RFID lida',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 20,
                      ),
                      child: ble.lastReading == null
                          ? const Center(
                        child: Text(
                          'Aproxime uma ficha do leitor RFID no BRAILLEPAD.\n'
                              'Selecione Leitor RFID ou um dos jogos no dispositivo.',
                          textAlign: TextAlign.center,
                        ),
                      )
                          : Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            ble.lastReading!.isRegistered
                                ? ble.lastReading!.value!
                                : '?',
                            style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryOrange,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ble.lastReading!.isRegistered
                                ? '${ble.lastReading!.kind} ${ble.lastReading!.value}'
                                : 'Ficha não cadastrada',
                            style: const TextStyle(fontSize: 17),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'UID: ${ble.lastReading!.uid}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                if (!isConnected)
                  ElevatedButton.icon(
                    onPressed: ble.busy ? null : () => ble.scan(),
                    icon: Icon(ble.scanning
                        ? Icons.sync_rounded
                        : Icons.bluetooth_searching_rounded),
                    label: Text(ble.scanning
                        ? 'Buscando BRAILLEPAD...'
                        : 'Buscar BRAILLEPAD'),
                  ),
                if (ble.connecting) ...[
                  const SizedBox(height: 18),
                  const LinearProgressIndicator(),
                ],
                if (isConnected)
                  OutlinedButton.icon(
                    onPressed: ble.connecting ? null : () => ble.disconnect(),
                    icon: const Icon(Icons.bluetooth_disabled_rounded),
                    label: const Text('Desconectar'),
                  ),
                if (!isConnected && ble.foundDevices.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const Text(
                    'Dispositivos encontrados',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final BluetoothDevice device in ble.foundDevices)
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.bluetooth_rounded,
                          color: AppTheme.primaryOrange,
                        ),
                        title: const Text('BRAILLEPAD'),
                        subtitle: Text(device.remoteId.str),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        enabled: !ble.busy,
                        onTap: ble.busy ? null : () => ble.connect(device),
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Conexão local via Bluetooth Low Energy (BLE).',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
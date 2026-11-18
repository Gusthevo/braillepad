import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Uma leitura fisica recebida por notificacao BLE do ESP32-C3.
class BraillepadRfidReading {
  final String uid;
  final String? value;
  final DateTime receivedAt;

  const BraillepadRfidReading({
    required this.uid,
    required this.value,
    required this.receivedAt,
  });

  bool get isRegistered => value != null && value!.isNotEmpty;
  bool get isNumber => isRegistered && int.tryParse(value!) != null;
  String get kind => !isRegistered ? 'Nao cadastrada' : (isNumber ? 'Numero' : 'Letra');

  /// Pacote: versao(1), uidLen, uidBytes, valueLen, asciiValue.
  /// Sempre <=15 bytes para funcionar mesmo com MTU BLE padrao.
  static BraillepadRfidReading? decode(List<int> data) {
    if (data.length < 3 || data.first != 1) return null;
    final uidLen = data[1];
    if (uidLen < 1 || uidLen > 10 || data.length < 3 + uidLen) return null;
    final valueLen = data[2 + uidLen];
    if (valueLen > 2 || data.length != 3 + uidLen + valueLen) return null;
    final uid = data.sublist(2, 2 + uidLen)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    final value = valueLen == 0
        ? null
        : String.fromCharCodes(data.sublist(3 + uidLen));
    return BraillepadRfidReading(
      uid: uid,
      value: value,
      receivedAt: DateTime.now(),
    );
  }
}

/// Conexao BLE com o ESP32-C3 BRAILLEPAD.
/// A instancia e compartilhada para a conexao continuar ativa ao sair da tela.
class BraillepadBleService extends ChangeNotifier {
  BraillepadBleService._();
  static final BraillepadBleService instance = BraillepadBleService._();

  static final Guid serviceUuid =
  Guid('3f0c5e20-7a91-4fbd-9ea4-1a96f2d834b0');
  static final Guid statusUuid =
  Guid('3f0c5e21-7a91-4fbd-9ea4-1a96f2d834b0');
  static final Guid rfidUuid =
  Guid('3f0c5e22-7a91-4fbd-9ea4-1a96f2d834b0');

  final Map<String, BluetoothDevice> _foundDevices = {};
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<bool>? _scanningSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;
  StreamSubscription<List<int>>? _rfidSubscription;
  // Eventos para as telas de execucao de atividades. O stream e broadcast
  // para permitir que varias telas observem leituras sem duplicar a conexao.
  final StreamController<String> _rfidController =
  StreamController<String>.broadcast();
  BraillepadRfidReading? _lastReading;
  BluetoothDevice? _connectedDevice;

  bool _scanning = false;
  bool _connecting = false;
  bool _connected = false;
  String _status = 'Equipamento PAD não conectado';

  List<BluetoothDevice> get foundDevices =>
      List.unmodifiable(_foundDevices.values);
  bool get scanning => _scanning;
  bool get connecting => _connecting;
  bool get connected => _connected;
  bool get busy => _scanning || _connecting;
  String get status => _status;
  String? get deviceId => _connectedDevice?.remoteId.str;
  BraillepadRfidReading? get lastReading => _lastReading;
  // A tela de execucao espera a letra/numero diretamente como String.
  Stream<String> get rfidStream => _rfidController.stream;

  void _updateStatus(String value) {
    _status = value;
    notifyListeners();
  }

  Future<bool> _requestPermissions() async {
    if (kIsWeb || !Platform.isAndroid) {
      _updateStatus('Conexão BLE disponível nesta versão apenas no Android.');
      return false;
    }

    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    if (sdk >= 31) {
      final result = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
      if (result.values.any((value) => !value.isGranted)) {
        _updateStatus('Permita Dispositivos próximos nas configurações do app.');
        return false;
      }
    } else {
      final location = await Permission.locationWhenInUse.request();
      if (!location.isGranted) {
        _updateStatus('Permita a localização para buscar BLE no Android 11 ou anterior.');
        return false;
      }
    }
    return true;
  }

  void _listenToAdapter() {
    _adapterSubscription ??= FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.off && _connected) {
        _connected = false;
        _connectedDevice = null;
        _rfidSubscription?.cancel();
        _rfidSubscription = null;
        _updateStatus('Bluetooth do celular desligado.');
      }
    });
  }

  Future<void> scan() async {
    if (busy || connected) return;
    try {
      if (!await FlutterBluePlus.isSupported) {
        _updateStatus('Este celular não oferece Bluetooth BLE.');
        return;
      }
      if (!await _requestPermissions()) return;
      _listenToAdapter();
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        _updateStatus('Ative o Bluetooth do celular e tente novamente.');
        return;
      }

      _foundDevices.clear();
      _scanning = true;
      _updateStatus('Procurando BRAILLEPAD...');

      await _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.onScanResults.listen(
            (results) {
          for (final result in results) {
            // Procura pelo nome ou pelo UUID anunciado, sem depender
            // de um filtro nativo que pode ocultar o BRAILLEPAD.
            final name = result.advertisementData.advName.trim().toUpperCase();
            final platformName = result.device.platformName.trim().toUpperCase();
            final hasService = result.advertisementData.serviceUuids.contains(serviceUuid);

            if (name == 'BRAILLEPAD' || platformName == 'BRAILLEPAD' || hasService) {
              _foundDevices[result.device.remoteId.str] = result.device;
            }
          }
          notifyListeners();
        },
        onError: (Object e) => _updateStatus('Falha na busca BLE: $e'),
      );

      await _scanningSubscription?.cancel();
      // Inscrever apos iniciar o scan evita tratar o estado inicial false
      // como se a busca tivesse terminado.
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 12),
      );
      _scanningSubscription = FlutterBluePlus.isScanning.listen((isScanning) {
        if (!isScanning && _scanning) {
          _scanning = false;
          _updateStatus(_foundDevices.isEmpty
              ? 'BRAILLEPAD não encontrado. Tente novamente.'
              : 'Selecione o BRAILLEPAD para conectar.');
        }
      });
    } catch (e) {
      _scanning = false;
      _updateStatus('Não foi possível procurar o dispositivo: $e');
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    if (_connecting || _connected) return;
    _connecting = true;
    _scanning = false;
    _updateStatus('Conectando ao BRAILLEPAD...');

    try {
      await FlutterBluePlus.stopScan();
      await _connectionSubscription?.cancel();
      _connectedDevice = device;
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && _connected) {
          _connected = false;
          _connectedDevice = null;
          _rfidSubscription?.cancel();
          _rfidSubscription = null;
          _updateStatus('BRAILLEPAD desconectado.');
        }
      });

      // Licenca para pesquisa/educacao sem fins lucrativos.
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
      );
      final services = await device.discoverServices();
      BluetoothCharacteristic? statusCharacteristic;
      BluetoothCharacteristic? rfidCharacteristic;
      for (final service in services) {
        if (service.uuid != serviceUuid) continue;
        for (final characteristic in service.characteristics) {
          if (characteristic.uuid == statusUuid) {
            statusCharacteristic = characteristic;
          } else if (characteristic.uuid == rfidUuid) {
            rfidCharacteristic = characteristic;
          }
        }
      }
      if (statusCharacteristic == null) {
        throw StateError('Serviço GATT do BRAILLEPAD ausente.');
      }

      final response = utf8.decode(await statusCharacteristic.read());
      if (response.trim() != 'READY') {
        throw StateError('Resposta BLE inesperada: $response');
      }

      if (rfidCharacteristic == null) {
        throw StateError('Caracteristica RFID BLE ausente. Grave o novo firmware no ESP32.');
      }
      // Registra o listener antes de habilitar NOTIFY, evitando perder eventos.
      await _rfidSubscription?.cancel();
      _lastReading = null;
      _rfidSubscription = rfidCharacteristic.onValueReceived.listen((bytes) {
        final reading = BraillepadRfidReading.decode(bytes);
        if (reading != null) {
          _lastReading = reading;
          notifyListeners(); // HealthPadScreen e atualizada automaticamente
          // Leituras nao cadastradas continuam visiveis no Health Pad,
          // mas nao devem ser registradas como respostas de atividades.
          if (reading.isRegistered) {
            _rfidController.add(reading.value!.trim().toUpperCase());
          }
        }
      });
      await rfidCharacteristic.setNotifyValue(true);

      _connected = true;
      _updateStatus('BRAILLEPAD conectado e pronto. Aproxime uma ficha RFID.');
    } catch (e) {
      _connected = false;
      _connectedDevice = null;
      await _rfidSubscription?.cancel();
      _rfidSubscription = null;
      await _connectionSubscription?.cancel();
      _connectionSubscription = null;
      try {
        await device.disconnect();
      } catch (_) {}
      _updateStatus('Erro ao conectar ao BRAILLEPAD: $e');
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (_connecting) return;
    final device = _connectedDevice;
    _connectedDevice = null;
    _connected = false;
    _updateStatus('Equipamento PAD desconectado.');
    await _rfidSubscription?.cancel();
    _rfidSubscription = null;
    try {
      await device?.disconnect();
    } catch (e) {
      _updateStatus('Falha ao desconectar: $e');
    } finally {
      await _connectionSubscription?.cancel();
      _connectionSubscription = null;
    }
  }
}
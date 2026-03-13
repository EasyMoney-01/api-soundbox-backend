import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../models/device_model.dart';
import '../services/database_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with TickerProviderStateMixin {
  List<DeviceModel> _devices = [];
  bool _isScanning = false;
  double _scanProgress = 0.0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final TextEditingController _ipController = TextEditingController();

  static const List<int> _commonPorts = [80, 8080, 9000, 3000, 5000];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 0.7, end: 1.0).animate(_pulseController);
    _loadDevices();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    final devices = await DatabaseService.instance.getAllDevices();
    setState(() => _devices = devices);
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _scanProgress = 0.0;
    });

    await DatabaseService.instance.clearAllDevices();
    final found = <DeviceModel>[];
    const uuid = Uuid();

    final subnet = _getSubnet();
    const totalHosts = 20;

    for (int i = 1; i <= totalHosts; i++) {
      final ip = '$subnet.$i';
      setState(() => _scanProgress = i / totalHosts);

      for (final port in _commonPorts) {
        final isOnline = await _checkHost(ip, port);
        if (isOnline) {
          final device = DeviceModel(
            id: uuid.v4(),
            ip: ip,
            port: port,
            isOnline: true,
            discoveredAt: DateTime.now(),
          );
          found.add(device);
          await DatabaseService.instance.insertDevice(device);
          setState(() => _devices = List.from(found));
          break;
        }
      }
      await Future.delayed(const Duration(milliseconds: 30));
    }

    setState(() {
      _isScanning = false;
      _scanProgress = 1.0;
    });
  }

  Future<bool> _checkHost(String ip, int port) async {
    try {
      final socket = await Socket.connect(ip, port,
          timeout: const Duration(milliseconds: 300));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  String _getSubnet() {
    return '192.168.1';
  }

  void _addManualDevice() {
    showDialog(
      context: context,
      builder: (ctx) => _ManualDeviceDialog(
        onAdd: (ip, port) async {
          const uuid = Uuid();
          final device = DeviceModel(
            id: uuid.v4(),
            ip: ip,
            port: port,
            isOnline: true,
            discoveredAt: DateTime.now(),
          );
          await DatabaseService.instance.insertDevice(device);
          _loadDevices();
        },
      ),
    );
  }

  Future<void> _clearDevices() async {
    await DatabaseService.instance.clearAllDevices();
    setState(() => _devices = []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.primaryBlue,
            expandedHeight: 160,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppTheme.blueGradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(
                            'Network Scanner',
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          if (_devices.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.white),
                              onPressed: _clearDevices,
                            ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline,
                                color: Colors.white),
                            onPressed: _addManualDevice,
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Text(
                          '${_devices.length} device${_devices.length == 1 ? '' : 's'} found',
                          style: GoogleFonts.roboto(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildScanControls(),
                  if (_isScanning) ...[
                    const SizedBox(height: 16),
                    _buildScanProgress(),
                  ],
                  const SizedBox(height: 16),
                  if (_devices.isEmpty && !_isScanning)
                    _buildEmptyState()
                  else
                    ..._devices.map(_buildDeviceCard),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanControls() {
    return PaytmCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isScanning ? 'Scanning network...' : 'Scan Local Network',
                  style: GoogleFonts.roboto(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Detect UPI Soundbox devices on 192.168.1.x',
                  style: GoogleFonts.roboto(
                      fontSize: 12, color: AppTheme.textGrey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isScanning ? _pulseAnimation.value : 1.0,
                child: SizedBox(
                  width: 110,
                  height: 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _isScanning ? null : AppTheme.paytmGradient,
                      color: _isScanning ? Colors.grey.shade200 : null,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _isScanning
                          ? null
                          : [
                              BoxShadow(
                                color: AppTheme.accentOrange.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _isScanning ? null : _startScan,
                        child: Center(
                          child: _isScanning
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.accentOrange,
                                  ),
                                )
                              : Text(
                                  'SCAN',
                                  style: GoogleFonts.roboto(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScanProgress() {
    return PaytmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Scanning hosts...',
                  style: GoogleFonts.roboto(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textDark)),
              Text('${(_scanProgress * 100).toInt()}%',
                  style: GoogleFonts.roboto(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _scanProgress,
              backgroundColor: AppTheme.divider,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return PaytmCard(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.wifi_find,
              size: 64, color: AppTheme.textGrey.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text('No devices found',
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textGrey,
              )),
          const SizedBox(height: 8),
          Text(
            'Tap SCAN to discover UPI Soundbox devices\nor add one manually using the + button',
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(
                fontSize: 13, color: AppTheme.textGrey.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(DeviceModel device) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PaytmCard(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: device.isOnline
                    ? AppTheme.successGreen.withOpacity(0.1)
                    : AppTheme.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.router,
                color: device.isOnline
                    ? AppTheme.successGreen
                    : AppTheme.errorRed,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.address,
                    style: GoogleFonts.robotoMono(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Discovered ${_timeAgo(device.discoveredAt)}',
                    style: GoogleFonts.roboto(
                        fontSize: 12, color: AppTheme.textGrey),
                  ),
                ],
              ),
            ),
            StatusBadge(
              label: device.isOnline ? 'ONLINE' : 'OFFLINE',
              isSuccess: device.isOnline,
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _ManualDeviceDialog extends StatefulWidget {
  final Function(String ip, int port) onAdd;
  const _ManualDeviceDialog({required this.onAdd});

  @override
  State<_ManualDeviceDialog> createState() => _ManualDeviceDialogState();
}

class _ManualDeviceDialogState extends State<_ManualDeviceDialog> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '80');
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Add Device Manually',
          style: GoogleFonts.roboto(fontWeight: FontWeight.w700)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'IP Address',
                hintText: '192.168.1.1',
                prefixIcon: Icon(Icons.router),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final parts = v.split('.');
                if (parts.length != 4) return 'Invalid IP';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                prefixIcon: Icon(Icons.cable),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final p = int.tryParse(v);
                if (p == null || p < 1 || p > 65535) return 'Invalid port';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onAdd(
                _ipController.text.trim(),
                int.parse(_portController.text.trim()),
              );
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

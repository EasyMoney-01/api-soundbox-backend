import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../models/transaction_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<TransactionModel> _transactions = [];
  List<TransactionModel> _filtered = [];
  bool _isLoading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final txns = await DatabaseService.instance.getAllTransactions();
    setState(() {
      _transactions = txns;
      _applyFilter(_filter);
      _isLoading = false;
    });
  }

  void _applyFilter(String filter) {
    setState(() {
      _filter = filter;
      switch (filter) {
        case 'success':
          _filtered = _transactions.where((t) => t.isSuccess).toList();
          break;
        case 'failed':
          _filtered = _transactions.where((t) => !t.isSuccess).toList();
          break;
        default:
          _filtered = List.from(_transactions);
      }
    });
  }

  Future<void> _deleteTransaction(String id) async {
    await DatabaseService.instance.deleteTransaction(id);
    _load();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear History',
            style: GoogleFonts.roboto(fontWeight: FontWeight.w700)),
        content:
            const Text('Are you sure? This will delete all transaction history.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseService.instance.clearAllTransactions();
      _load();
    }
  }

  double get _totalSuccess => _transactions
      .where((t) => t.isSuccess)
      .fold(0.0, (sum, t) => sum + t.amount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryBlue,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppTheme.primaryBlue,
              expandedHeight: 180,
              actions: [
                if (_transactions.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined,
                        color: Colors.white),
                    onPressed: _clearAll,
                    tooltip: 'Clear all',
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(gradient: AppTheme.blueGradient),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Transaction History',
                              style: GoogleFonts.roboto(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              )),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildHeaderStat(
                                  '${_transactions.length}', 'Total'),
                              const SizedBox(width: 20),
                              _buildHeaderStat(
                                  '${_transactions.where((t) => t.isSuccess).length}',
                                  'Success'),
                              const SizedBox(width: 20),
                              _buildHeaderStat(
                                  '₹${_totalSuccess.toStringAsFixed(0)}',
                                  'Injected'),
                            ],
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildFilterChips(),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                ),
              )
            else if (_filtered.isEmpty)
              SliverFillRemaining(
                child: _buildEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == 0 || !_isSameDay(
                          _filtered[index].createdAt,
                          _filtered[index - 1].createdAt)) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (index != 0) const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                _formatDateHeader(_filtered[index].createdAt),
                                style: GoogleFonts.roboto(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textGrey,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            _buildTxnCard(_filtered[index]),
                          ],
                        );
                      }
                      return _buildTxnCard(_filtered[index]);
                    },
                    childCount: _filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: GoogleFonts.roboto(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            )),
        Text(label,
            style: GoogleFonts.roboto(
                color: Colors.white.withOpacity(0.75), fontSize: 12)),
      ],
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'all', 'label': 'All'},
      {'key': 'success', 'label': 'Success'},
      {'key': 'failed', 'label': 'Failed'},
    ];
    return Row(
      children: filters.map((f) {
        final isSelected = _filter == f['key'];
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => _applyFilter(f['key']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.divider,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Text(
                f['label']!,
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textGrey,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTxnCard(TransactionModel txn) {
    final vendorColors = {
      'paytm': const Color(0xFF0066CC),
      'phonepe': const Color(0xFF5F259F),
      'gpay': const Color(0xFF4285F4),
      'bharatpe': const Color(0xFF00C853),
      'generic': const Color(0xFF607D8B),
    };
    final vendorIcons = {
      'paytm': '₹',
      'phonepe': 'P',
      'gpay': 'G',
      'bharatpe': 'B',
      'generic': 'U',
    };
    final color =
        vendorColors[txn.vendor] ?? AppTheme.primaryBlue;
    final icon = vendorIcons[txn.vendor] ?? '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key(txn.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppTheme.errorRed,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
        ),
        confirmDismiss: (_) async {
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              title: Text('Delete',
                  style: GoogleFonts.roboto(fontWeight: FontWeight.w700)),
              content: const Text('Delete this transaction?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorRed),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
        },
        onDismissed: (_) => _deleteTransaction(txn.id),
        child: PaytmCard(
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(icon,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          txn.vendor.toUpperCase(),
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: txn.isSuccess ? 'SUCCESS' : 'FAILED',
                          isSuccess: txn.isSuccess,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      txn.targetIP,
                      style: GoogleFonts.robotoMono(
                          fontSize: 12, color: AppTheme.textGrey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('hh:mm a').format(txn.createdAt),
                      style: GoogleFonts.roboto(
                          fontSize: 11,
                          color: AppTheme.textGrey.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${txn.amount.toStringAsFixed(2)}',
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: txn.isSuccess
                      ? AppTheme.successGreen
                      : AppTheme.errorRed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 72, color: AppTheme.textGrey.withOpacity(0.35)),
          const SizedBox(height: 16),
          Text('No transactions yet',
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textGrey,
              )),
          const SizedBox(height: 8),
          Text(
            'Injected payments will appear here',
            style: GoogleFonts.roboto(
                fontSize: 13,
                color: AppTheme.textGrey.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    if (_isSameDay(dt, now)) return 'TODAY';
    if (_isSameDay(dt, now.subtract(const Duration(days: 1)))) return 'YESTERDAY';
    return DateFormat('dd MMM yyyy').format(dt).toUpperCase();
  }
}

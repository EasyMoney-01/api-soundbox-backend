class TransactionModel {
  final String id;
  final String vendor;
  final double amount;
  final String targetIP;
  final bool isSuccess;
  final String status;
  final String? errorMessage;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.vendor,
    required this.amount,
    required this.targetIP,
    required this.isSuccess,
    required this.status,
    this.errorMessage,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'vendor': vendor,
        'amount': amount,
        'targetIP': targetIP,
        'isSuccess': isSuccess ? 1 : 0,
        'status': status,
        'errorMessage': errorMessage,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TransactionModel.fromMap(Map<String, dynamic> map) => TransactionModel(
        id: map['id'],
        vendor: map['vendor'],
        amount: map['amount'],
        targetIP: map['targetIP'],
        isSuccess: map['isSuccess'] == 1,
        status: map['status'],
        errorMessage: map['errorMessage'],
        createdAt: DateTime.parse(map['createdAt']),
      );
}

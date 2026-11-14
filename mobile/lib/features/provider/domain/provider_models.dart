typedef Json = Map<String, dynamic>;

int _int(Object? v) => (v as num?)?.toInt() ?? 0;
String _str(Object? v) => v as String? ?? '';
DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);

/// Identity check states, as the API sends them. Empty means not started.
abstract final class CheckStatus {
  static const none = '';
  static const pending = 'PENDING';
  static const approved = 'APPROVED';
  static const rejected = 'REJECTED';
}

/// Weekday keys the API uses, Sunday first as in Nepal's week.
const weekdays = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];

const weekdayNames = {
  'sun': 'Sunday',
  'mon': 'Monday',
  'tue': 'Tuesday',
  'wed': 'Wednesday',
  'thu': 'Thursday',
  'fri': 'Friday',
  'sat': 'Saturday',
};

class Availability {
  const Availability({required this.weekly, required this.daysOff});

  factory Availability.fromJson(Json j) => Availability(
    weekly: {
      for (final e in ((j['weekly'] as Json?) ?? const {}).entries)
        e.key: (e.value as List).cast<String>().toSet(),
    },
    daysOff: ((j['days_off'] as List?) ?? const []).cast<String>().toList(),
  );

  final Map<String, Set<String>> weekly;
  final List<String> daysOff;

  int get slotCount => weekly.values.fold(0, (n, s) => n + s.length);

  Json toJson() => {
    'weekly': {
      for (final e in weekly.entries)
        if (e.value.isNotEmpty) e.key: e.value.toList(),
    },
    'days_off': daysOff,
  };
}

/// The parts of the signed-in user that the provider tools need.
class MyProviderState {
  const MyProviderState({
    required this.id,
    required this.verified,
    required this.checkStatus,
    required this.checkReason,
    required this.availability,
    this.online = false,
    this.name = '',
    this.bio = '',
  });

  factory MyProviderState.fromJson(Json j) {
    final v = j['verification'] as Json?;
    final p = j['provider_profile'] as Json?;
    return MyProviderState(
      online: p?['is_online'] == true,
      name: _str(j['display_name']),
      bio: _str(p?['bio']),
      id: _str(j['id']),
      verified: j['is_verified'] == true,
      checkStatus: _str(v?['status']),
      checkReason: _str(v?['reason']),
      availability: j['availability'] == null
          ? null
          : Availability.fromJson(j['availability'] as Json),
    );
  }

  final String id;
  final bool verified;
  final String checkStatus;
  final String checkReason;
  final Availability? availability;

  /// Whether the provider is receiving job alerts.
  final bool online;
  final String name;
  final String bio;
}

abstract final class DocumentKind {
  static const front = 'citizenship_front';
  static const back = 'citizenship_back';
  static const certificate = 'certificate';
}

class ProviderDocument {
  const ProviderDocument({
    required this.id,
    required this.kind,
    required this.label,
    required this.type,
    required this.createdAt,
  });

  factory ProviderDocument.fromJson(Json j) => ProviderDocument(
    id: _str(j['id']),
    kind: _str(j['kind']),
    label: _str(j['label']),
    type: _str(j['type']),
    createdAt: _date(j['created_at'])!,
  );

  final String id;
  final String kind;
  final String label;
  final String type;
  final DateTime createdAt;

  bool get isImage => type.startsWith('image/');
}

class GalleryPhoto {
  const GalleryPhoto({required this.id, required this.caption});

  factory GalleryPhoto.fromJson(Json j) =>
      GalleryPhoto(id: _str(j['id']), caption: _str(j['caption']));

  final String id;
  final String caption;
}

abstract final class PayoutMethod {
  static const bank = 'bank';
  static const esewa = 'esewa';
  static const khalti = 'khalti';
}

class PayoutDestination {
  const PayoutDestination({
    required this.method,
    this.bankName = '',
    this.accountName = '',
    this.accountNumber = '',
    this.walletId = '',
  });

  factory PayoutDestination.fromJson(Json j) => PayoutDestination(
    method: _str(j['method']),
    bankName: _str(j['bank_name']),
    accountName: _str(j['account_name']),
    accountNumber: _str(j['account_number']),
    walletId: _str(j['wallet_id']),
  );

  final String method;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String walletId;

  Json toJson() => {
    'method': method,
    if (bankName.isNotEmpty) 'bank_name': bankName,
    if (accountName.isNotEmpty) 'account_name': accountName,
    if (accountNumber.isNotEmpty) 'account_number': accountNumber,
    if (walletId.isNotEmpty) 'wallet_id': walletId,
  };

  /// "eSewa 9812345678" or "NIC Asia ••••8901".
  String get summary => switch (method) {
    PayoutMethod.esewa => 'eSewa $walletId',
    PayoutMethod.khalti => 'Khalti $walletId',
    _ =>
      '$bankName ••••${accountNumber.length > 4 ? accountNumber.substring(accountNumber.length - 4) : accountNumber}',
  };
}

abstract final class WithdrawalStatus {
  static const pending = 'PENDING';
  static const paid = 'PAID';
  static const rejected = 'REJECTED';
}

class Withdrawal {
  const Withdrawal({
    required this.id,
    required this.userId,
    required this.amountPaisa,
    required this.destination,
    required this.status,
    required this.reference,
    required this.reason,
    required this.createdAt,
    required this.decidedAt,
  });

  factory Withdrawal.fromJson(Json j) => Withdrawal(
    id: _str(j['id']),
    userId: _str(j['user_id']),
    amountPaisa: _int(j['amount_paisa']),
    destination: PayoutDestination.fromJson(j['destination'] as Json),
    status: _str(j['status']),
    reference: _str(j['reference']),
    reason: _str(j['reason']),
    createdAt: _date(j['created_at'])!,
    decidedAt: _date(j['decided_at']),
  );

  final String id;
  final String userId;
  final int amountPaisa;
  final PayoutDestination destination;
  final String status;
  final String reference;
  final String reason;
  final DateTime createdAt;
  final DateTime? decidedAt;
}

class EarningsMonth {
  const EarningsMonth({
    required this.month,
    required this.earnedPaisa,
    required this.jobs,
  });

  factory EarningsMonth.fromJson(Json j) => EarningsMonth(
    month: _str(j['month']),
    earnedPaisa: _int(j['earned_paisa']),
    jobs: _int(j['jobs']),
  );

  /// "2026-11".
  final String month;
  final int earnedPaisa;
  final int jobs;
}

class JobPayment {
  const JobPayment({
    required this.jobId,
    required this.categoryId,
    required this.pricePaisa,
    required this.earnedPaisa,
    required this.commissionPaisa,
    required this.at,
  });

  factory JobPayment.fromJson(Json j) => JobPayment(
    jobId: _str(j['job_id']),
    categoryId: _int(j['category_id']),
    pricePaisa: _int(j['price_paisa']),
    earnedPaisa: _int(j['earned_paisa']),
    commissionPaisa: _int(j['commission_paisa']),
    at: _date(j['at'])!,
  );

  final String jobId;
  final int categoryId;
  final int pricePaisa;
  final int earnedPaisa;
  final int commissionPaisa;
  final DateTime at;
}

class Earnings {
  const Earnings({
    required this.availablePaisa,
    required this.onHoldPaisa,
    required this.withdrawingPaisa,
    required this.totalEarnedPaisa,
    required this.thisMonthPaisa,
    required this.commissionPaidPaisa,
    required this.jobsPaid,
    required this.verified,
    required this.minWithdrawalPaisa,
    required this.months,
    required this.payments,
    required this.withdrawals,
  });

  factory Earnings.fromJson(Json j) => Earnings(
    availablePaisa: _int(j['available_paisa']),
    onHoldPaisa: _int(j['on_hold_paisa']),
    withdrawingPaisa: _int(j['withdrawing_paisa']),
    totalEarnedPaisa: _int(j['total_earned_paisa']),
    thisMonthPaisa: _int(j['this_month_paisa']),
    commissionPaidPaisa: _int(j['commission_paid_paisa']),
    jobsPaid: _int(j['jobs_paid']),
    verified: j['verified'] == true,
    minWithdrawalPaisa: _int(j['min_withdrawal_paisa']),
    months: [
      for (final m in (j['months'] as List?) ?? const [])
        EarningsMonth.fromJson(m as Json),
    ],
    payments: [
      for (final p in (j['payments'] as List?) ?? const [])
        JobPayment.fromJson(p as Json),
    ],
    withdrawals: [
      for (final w in (j['withdrawals'] as List?) ?? const [])
        Withdrawal.fromJson(w as Json),
    ],
  );

  final int availablePaisa;
  final int onHoldPaisa;
  final int withdrawingPaisa;
  final int totalEarnedPaisa;
  final int thisMonthPaisa;
  final int commissionPaidPaisa;
  final int jobsPaid;
  final bool verified;
  final int minWithdrawalPaisa;
  final List<EarningsMonth> months;
  final List<JobPayment> payments;
  final List<Withdrawal> withdrawals;

  bool get hasWaitingWithdrawal =>
      withdrawals.any((w) => w.status == WithdrawalStatus.pending);
}

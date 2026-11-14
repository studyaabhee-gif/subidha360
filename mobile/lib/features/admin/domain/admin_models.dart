/// Read-only shapes for the back office. Hand-written rather than generated,
/// because admins only ever read these and never send them back.
library;

typedef Json = Map<String, dynamic>;

int _int(Object? v) => (v as num?)?.toInt() ?? 0;
double _double(Object? v) => (v as num?)?.toDouble() ?? 0;
String _str(Object? v) => v as String? ?? '';
DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);
List<T> _list<T>(Object? v, T Function(Json) f) =>
    ((v as List?) ?? const []).map((e) => f(e as Json)).toList();

class PageOf<T> {
  const PageOf({
    required this.items,
    required this.page,
    required this.hasMore,
  });

  factory PageOf.fromJson(Json j, T Function(Json) item) => PageOf(
    items: _list(j['items'], item),
    page: _int(j['page']),
    hasMore: j['has_more'] == true,
  );

  final List<T> items;
  final int page;
  final bool hasMore;
}

class Person {
  const Person({required this.id, required this.name, required this.phone});

  factory Person.fromJson(Json? j) => Person(
    id: _str(j?['id']),
    name: _str(j?['name']),
    phone: _str(j?['phone']),
  );

  final String id;
  final String name;
  final String phone;

  String get label => name.isNotEmpty
      ? name
      : phone.isNotEmpty
      ? phone
      : 'Unknown';
}

class Suspension {
  const Suspension({required this.reason, required this.by, required this.at});

  factory Suspension.fromJson(Json j) => Suspension(
    reason: _str(j['reason']),
    by: _str(j['by']),
    at: _date(j['at'])!,
  );

  final String reason;
  final String by;
  final DateTime at;
}

class UserRow {
  const UserRow({
    required this.id,
    required this.phone,
    required this.name,
    required this.isProvider,
    required this.isVerified,
    required this.isAdmin,
    required this.suspension,
    required this.check,
    required this.online,
    required this.rating,
    required this.reviewCount,
    required this.jobsCompleted,
    required this.createdAt,
  });

  factory UserRow.fromJson(Json j) => UserRow(
    id: _str(j['id']),
    phone: _str(j['phone']),
    name: _str(j['name']),
    isProvider: j['is_provider'] == true,
    isVerified: j['is_verified'] == true,
    isAdmin: j['is_admin'] == true,
    suspension: j['suspension'] == null
        ? null
        : Suspension.fromJson(j['suspension'] as Json),
    check: _str(j['check']),
    online: j['online'] == true,
    rating: _double(j['rating']),
    reviewCount: _int(j['review_count']),
    jobsCompleted: _int(j['jobs_completed']),
    createdAt: _date(j['created_at'])!,
  );

  final String id;
  final String phone;
  final String name;
  final bool isProvider;
  final bool isVerified;
  final bool isAdmin;
  final Suspension? suspension;

  /// Identity check: "", PENDING, APPROVED or REJECTED.
  final String check;
  final bool online;
  final double rating;
  final int reviewCount;
  final int jobsCompleted;
  final DateTime createdAt;

  String get label => name.isNotEmpty ? name : 'No name yet';
}

class ProviderProfileInfo {
  const ProviderProfileInfo({
    required this.categoryIds,
    required this.bio,
    required this.yearsExperience,
  });

  factory ProviderProfileInfo.fromJson(Json j) => ProviderProfileInfo(
    categoryIds: ((j['category_ids'] as List?) ?? const [])
        .map((e) => (e as num).toInt())
        .toList(),
    bio: _str(j['bio']),
    yearsExperience: _int(j['years_experience']),
  );

  final List<int> categoryIds;
  final String bio;
  final int yearsExperience;
}

class ReviewRow {
  const ReviewRow({
    required this.jobId,
    required this.rating,
    required this.tags,
    required this.comment,
    required this.createdAt,
  });

  factory ReviewRow.fromJson(Json j) => ReviewRow(
    jobId: _str(j['job_id']),
    rating: _int(j['rating']),
    tags: ((j['tags'] as List?) ?? const []).cast<String>(),
    comment: _str(j['comment']),
    createdAt: _date(j['created_at'])!,
  );

  final String jobId;
  final int rating;
  final List<String> tags;
  final String comment;
  final DateTime createdAt;
}

class UserDetail {
  const UserDetail({
    required this.user,
    required this.profile,
    required this.balancePaisa,
    required this.activeJobs,
    required this.jobs,
    required this.transactions,
    required this.reviews,
    required this.actions,
    required this.checkReason,
    required this.checkSubmittedAt,
    required this.documents,
    required this.withdrawals,
    required this.availability,
    required this.risk,
    required this.flags,
  });

  factory UserDetail.fromJson(Json j) => UserDetail(
    risk: (j['risk'] as Json?) ?? const {},
    flags: ((j['flags'] as List?) ?? const []).cast<Json>(),
    checkReason: _str((j['verification'] as Json?)?['reason']),
    checkSubmittedAt: _date((j['verification'] as Json?)?['submitted_at']),
    documents: _list(j['documents'], AdminDocument.fromJson),
    withdrawals: _list(j['withdrawals'], WithdrawalRow.fromJson),
    availability: j['availability'] as Json?,
    user: UserRow.fromJson(j['user'] as Json),
    profile: j['provider_profile'] == null
        ? null
        : ProviderProfileInfo.fromJson(j['provider_profile'] as Json),
    balancePaisa: _int(j['balance_paisa']),
    activeJobs: _int(j['active_jobs']),
    jobs: _list(j['jobs'], JobRow.fromJson),
    transactions: _list(j['transactions'], EntryRow.fromJson),
    reviews: _list(j['reviews_received'], ReviewRow.fromJson),
    actions: _list(j['actions'], AdminAction.fromJson),
  );

  final UserRow user;
  final ProviderProfileInfo? profile;
  final int balancePaisa;
  final int activeJobs;
  final List<JobRow> jobs;
  final List<EntryRow> transactions;
  final List<ReviewRow> reviews;
  final List<AdminAction> actions;
  final String checkReason;
  final DateTime? checkSubmittedAt;
  final List<AdminDocument> documents;
  final List<WithdrawalRow> withdrawals;
  final Json? availability;

  /// flags_open, flags_total, disputes and cancellations.
  final Json risk;

  /// Raw flag rows; read them with FlagRow.fromJson.
  final List<Json> flags;
}

class JobRow {
  const JobRow({
    required this.id,
    required this.status,
    required this.category,
    required this.description,
    required this.address,
    required this.seeker,
    required this.provider,
    required this.escrowPaisa,
    required this.bidCount,
    required this.disputed,
    required this.needsReview,
    required this.claimOpen,
    required this.createdAt,
  });

  factory JobRow.fromJson(Json j) => JobRow(
    id: _str(j['id']),
    status: _str(j['status']),
    category: _str(j['category']),
    description: _str(j['description']),
    address: _str(j['address']),
    seeker: Person.fromJson(j['seeker'] as Json?),
    provider: j['provider'] == null
        ? null
        : Person.fromJson(j['provider'] as Json),
    escrowPaisa: _int(j['escrow_amount_paisa']),
    bidCount: _int(j['bid_count']),
    disputed: j['disputed'] == true,
    needsReview: j['needs_review'] == true,
    claimOpen: j['claim_open'] == true,
    createdAt: _date(j['created_at'])!,
  );

  final String id;
  final String status;
  final String category;
  final String description;
  final String address;
  final Person seeker;
  final Person? provider;
  final int escrowPaisa;
  final int bidCount;
  final bool disputed;
  final bool needsReview;
  final bool claimOpen;
  final DateTime createdAt;

  /// Something an admin has to decide.
  bool get needsAction =>
      disputed || needsReview || claimOpen || status == 'MANUAL_FALLBACK';
}

class BidRow {
  const BidRow({
    required this.id,
    required this.provider,
    required this.amountPaisa,
    required this.status,
    required this.partsIncluded,
    required this.note,
    required this.createdAt,
  });

  factory BidRow.fromJson(Json j) => BidRow(
    id: _str(j['id']),
    provider: Person.fromJson(j['provider'] as Json?),
    amountPaisa: _int(j['amount_paisa']),
    status: _str(j['status']),
    partsIncluded: j['parts_included'] == true,
    note: _str(j['note']),
    createdAt: _date(j['created_at'])!,
  );

  final String id;
  final Person provider;
  final int amountPaisa;
  final String status;
  final bool partsIncluded;
  final String note;
  final DateTime createdAt;
}

class MessageRow {
  const MessageRow({
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  factory MessageRow.fromJson(Json j) => MessageRow(
    senderId: _str(j['sender_id']),
    body: _str(j['body']),
    createdAt: _date(j['created_at'])!,
  );

  final String senderId;
  final String body;
  final DateTime createdAt;
}

/// The parts of the raw job record that the detail page shows.
class JobRecord {
  const JobRecord({
    required this.raw,
    required this.serviceId,
    required this.preferredDate,
    required this.preferredSlot,
    required this.dispute,
    required this.cancellation,
    required this.claim,
    required this.resolution,
    required this.escrowReviewDueAt,
    required this.autoReleaseAt,
    required this.seekerConfirmedAt,
    required this.providerConfirmedAt,
    required this.photoCount,
    required this.lat,
    required this.lng,
  });

  factory JobRecord.fromJson(Json j) {
    final coords = (j['job_location'] as Json?)?['coordinates'] as List?;
    return JobRecord(
      raw: j,
      serviceId: _str(j['service_id']),
      preferredDate: _str(j['preferred_date']),
      preferredSlot: _str(j['preferred_slot']),
      dispute: j['dispute'] as Json?,
      cancellation: j['cancellation'] as Json?,
      claim: j['warranty_claim'] as Json?,
      resolution: j['escrow_resolution'] as Json?,
      escrowReviewDueAt: _date(j['escrow_review_due_at']),
      autoReleaseAt: _date(j['auto_release_at']),
      seekerConfirmedAt: _date(j['seeker_confirmed_at']),
      providerConfirmedAt: _date(j['provider_confirmed_at']),
      photoCount: ((j['photo_ids'] as List?) ?? const []).length,
      lng: coords == null ? null : _double(coords[0]),
      lat: coords == null ? null : _double(coords[1]),
    );
  }

  final Json raw;
  final String serviceId;
  final String preferredDate;
  final String preferredSlot;
  final Json? dispute;
  final Json? cancellation;
  final Json? claim;
  final Json? resolution;
  final DateTime? escrowReviewDueAt;
  final DateTime? autoReleaseAt;
  final DateTime? seekerConfirmedAt;
  final DateTime? providerConfirmedAt;
  final int photoCount;
  final double? lat;
  final double? lng;
}

class JobDetail {
  const JobDetail({
    required this.record,
    required this.summary,
    required this.bids,
    required this.messages,
    required this.ledger,
    required this.review,
    required this.actions,
  });

  factory JobDetail.fromJson(Json j) => JobDetail(
    record: JobRecord.fromJson(j['job'] as Json),
    summary: JobRow.fromJson(j['summary'] as Json),
    bids: _list(j['bids'], BidRow.fromJson),
    messages: _list(j['messages'], MessageRow.fromJson),
    ledger: _list(j['ledger'], EntryRow.fromJson),
    review: j['review'] == null
        ? null
        : ReviewRow.fromJson(j['review'] as Json),
    actions: _list(j['actions'], AdminAction.fromJson),
  );

  final JobRecord record;
  final JobRow summary;
  final List<BidRow> bids;
  final List<MessageRow> messages;
  final List<EntryRow> ledger;
  final ReviewRow? review;
  final List<AdminAction> actions;
}

class EntryRow {
  const EntryRow({
    required this.id,
    required this.group,
    required this.account,
    required this.userId,
    required this.userName,
    required this.amountPaisa,
    required this.type,
    required this.jobId,
    required this.createdAt,
  });

  factory EntryRow.fromJson(Json j) => EntryRow(
    id: _str(j['id']),
    group: _str(j['group']),
    account: _str(j['account']),
    userId: _str(j['user_id']),
    userName: _str(j['user_name']),
    amountPaisa: _int(j['amount_paisa']),
    type: _str(j['type']),
    jobId: _str(j['job_id']),
    createdAt: _date(j['created_at'])!,
  );

  final String id;
  final String group;
  final String account;
  final String userId;
  final String userName;
  final int amountPaisa;
  final String type;
  final String jobId;
  final DateTime createdAt;

  /// "Wallet", "Job escrow", "Commission" or "Payment gateway".
  String get accountLabel {
    if (account.startsWith('user:')) {
      return userName.isNotEmpty ? '$userName (wallet)' : 'Wallet';
    }
    if (account.startsWith('escrow:')) return 'Job escrow';
    if (account == 'system:commission') return 'Commission';
    if (account.startsWith('external:')) return 'Payment gateway';
    return account;
  }
}

class Money {
  const Money({
    required this.commissionPaisa,
    required this.escrowHeldPaisa,
    required this.walletsPaisa,
    required this.withdrawalsWaitingPaisa,
    required this.toppedUpPaisa,
    required this.booksBalancePaisa,
    required this.mismatched,
    required this.unbalanced,
    required this.healthy,
  });

  factory Money.fromJson(Json j) => Money(
    commissionPaisa: _int(j['commission_paisa']),
    escrowHeldPaisa: _int(j['escrow_held_paisa']),
    walletsPaisa: _int(j['wallets_paisa']),
    withdrawalsWaitingPaisa: _int(j['withdrawals_waiting_paisa']),
    toppedUpPaisa: _int(j['topped_up_paisa']),
    booksBalancePaisa: _int(j['books_balance_paisa']),
    mismatched: ((j['mismatched_accounts'] as List?) ?? const [])
        .cast<String>(),
    unbalanced: ((j['unbalanced_postings'] as List?) ?? const [])
        .cast<String>(),
    healthy: j['healthy'] == true,
  );

  final int commissionPaisa;
  final int escrowHeldPaisa;
  final int walletsPaisa;
  final int withdrawalsWaitingPaisa;
  final int toppedUpPaisa;
  final int booksBalancePaisa;
  final List<String> mismatched;
  final List<String> unbalanced;
  final bool healthy;
}

class Day {
  const Day({
    required this.date,
    required this.posted,
    required this.completed,
    required this.cancelled,
    required this.newUsers,
    required this.gmvPaisa,
    required this.commissionPaisa,
    required this.payoutsPaisa,
    required this.refundsPaisa,
    required this.topUpsPaisa,
    required this.withdrawalsPaisa,
  });

  factory Day.fromJson(Json j) => Day(
    withdrawalsPaisa: _int(j['withdrawals_paisa']),
    date: _str(j['date']),
    posted: _int(j['jobs_posted']),
    completed: _int(j['jobs_completed']),
    cancelled: _int(j['jobs_cancelled']),
    newUsers: _int(j['new_users']),
    gmvPaisa: _int(j['gmv_paisa']),
    commissionPaisa: _int(j['commission_paisa']),
    payoutsPaisa: _int(j['payouts_paisa']),
    refundsPaisa: _int(j['refunds_paisa']),
    topUpsPaisa: _int(j['top_ups_paisa']),
  );

  final String date;
  final int posted;
  final int completed;
  final int cancelled;
  final int newUsers;
  final int gmvPaisa;
  final int commissionPaisa;
  final int payoutsPaisa;
  final int refundsPaisa;
  final int topUpsPaisa;
  final int withdrawalsPaisa;
}

class Overview {
  const Overview({
    required this.users,
    required this.providers,
    required this.verifiedProviders,
    required this.suspended,
    required this.newThisWeek,
    required this.jobsByStatus,
    required this.disputes,
    required this.cancellationReviews,
    required this.guaranteeClaims,
    required this.unmatched,
    required this.unverifiedProviders,
    required this.identityChecks,
    required this.withdrawals,
    required this.support,
    required this.flags,
    required this.money,
    required this.last30,
    required this.days,
  });

  factory Overview.fromJson(Json j) {
    final u = j['users'] as Json;
    final a = j['attention'] as Json;
    return Overview(
      users: _int(u['total']),
      providers: _int(u['providers']),
      verifiedProviders: _int(u['verified_providers']),
      suspended: _int(u['suspended']),
      newThisWeek: _int(u['new_this_week']),
      jobsByStatus: {
        for (final e in ((j['jobs_by_status'] as Json?) ?? const {}).entries)
          e.key: _int(e.value),
      },
      disputes: _int(a['disputes']),
      cancellationReviews: _int(a['cancellation_reviews']),
      guaranteeClaims: _int(a['guarantee_claims']),
      unmatched: _int(a['unmatched_jobs']),
      unverifiedProviders: _int(a['unverified_providers']),
      identityChecks: _int(a['identity_checks']),
      withdrawals: _int(a['withdrawals']),
      support: _int(a['support']),
      flags: _int(a['flags']),
      money: Money.fromJson(j['money'] as Json),
      last30: Day.fromJson(j['last_30_days'] as Json),
      days: _list(j['days'], Day.fromJson),
    );
  }

  final int users;
  final int providers;
  final int verifiedProviders;
  final int suspended;
  final int newThisWeek;
  final Map<String, int> jobsByStatus;
  final int disputes;
  final int cancellationReviews;
  final int guaranteeClaims;
  final int unmatched;
  final int unverifiedProviders;
  final int identityChecks;
  final int withdrawals;
  final int support;
  final int flags;
  final Money money;
  final Day last30;
  final List<Day> days;

  int get needsAction =>
      disputes +
      cancellationReviews +
      guaranteeClaims +
      unmatched +
      identityChecks +
      withdrawals +
      support +
      flags;

  int status(String s) => jobsByStatus[s] ?? 0;
}

class CategoryRow {
  const CategoryRow({
    required this.id,
    required this.name,
    required this.posted,
    required this.completed,
    required this.cancelled,
    required this.valuePaisa,
  });

  factory CategoryRow.fromJson(Json j) => CategoryRow(
    id: _int(j['category_id']),
    name: _str(j['name']),
    posted: _int(j['jobs_posted']),
    completed: _int(j['jobs_completed']),
    cancelled: _int(j['jobs_cancelled']),
    valuePaisa: _int(j['completed_value_paisa']),
  );

  final int id;
  final String name;
  final int posted;
  final int completed;
  final int cancelled;
  final int valuePaisa;
}

class ProviderRow {
  const ProviderRow({
    required this.person,
    required this.completed,
    required this.valuePaisa,
    required this.rating,
    required this.verified,
  });

  factory ProviderRow.fromJson(Json j) => ProviderRow(
    person: Person.fromJson(j),
    completed: _int(j['jobs_completed']),
    valuePaisa: _int(j['completed_value_paisa']),
    rating: _double(j['rating']),
    verified: j['verified'] == true,
  );

  final Person person;
  final int completed;
  final int valuePaisa;
  final double rating;
  final bool verified;
}

class Report {
  const Report({
    required this.from,
    required this.to,
    required this.totals,
    required this.days,
    required this.categories,
    required this.topProviders,
  });

  factory Report.fromJson(Json j) => Report(
    from: _str(j['from']),
    to: _str(j['to']),
    totals: Day.fromJson(j['totals'] as Json),
    days: _list(j['days'], Day.fromJson),
    categories: _list(j['categories'], CategoryRow.fromJson),
    topProviders: _list(j['top_providers'], ProviderRow.fromJson),
  );

  final String from;
  final String to;
  final Day totals;
  final List<Day> days;
  final List<CategoryRow> categories;
  final List<ProviderRow> topProviders;
}

class AdminAction {
  const AdminAction({
    required this.id,
    required this.adminId,
    required this.adminName,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.detail,
    required this.at,
  });

  factory AdminAction.fromJson(Json j) => AdminAction(
    id: _str(j['id']),
    adminId: _str(j['admin_id']),
    adminName: _str(j['admin_name']),
    action: _str(j['action']),
    targetType: _str(j['target_type']),
    targetId: _str(j['target_id']),
    detail: _str(j['detail']),
    at: _date(j['at'])!,
  );

  final String id;
  final String adminId;
  final String adminName;
  final String action;
  final String targetType;
  final String targetId;
  final String detail;
  final DateTime at;

  String get label => switch (action) {
    'user.suspend' => 'Suspended an account',
    'user.unsuspend' => 'Lifted a suspension',
    'provider.verify' => 'Verified a provider',
    'provider.unverify' => 'Removed verification',
    'job.resolve_escrow' => 'Decided a payment',
    'job.close_claim' => 'Closed a guarantee claim',
    'provider.check_approve' => 'Approved an identity check',
    'provider.check_reject' => 'Rejected an identity check',
    'withdrawal.paid' => 'Sent a withdrawal',
    'withdrawal.refused' => 'Refused a withdrawal',
    'support.close' => 'Closed a support conversation',
    'flag.review' => 'Reviewed a flag',
    'catalog.service' => 'Changed a service',
    'catalog.category' => 'Changed a category',
    'settings.save' => 'Changed the helpline',
    _ => action,
  };
}

class AdminDocument {
  const AdminDocument({
    required this.id,
    required this.kind,
    required this.label,
    required this.type,
    required this.createdAt,
  });

  factory AdminDocument.fromJson(Json j) => AdminDocument(
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

  String get title => switch (kind) {
    'citizenship_front' => 'Citizenship card, front',
    'citizenship_back' => 'Citizenship card, back',
    _ => label.isEmpty ? 'Certificate' : 'Certificate: $label',
  };
}

class WithdrawalRow {
  const WithdrawalRow({
    required this.id,
    required this.userId,
    required this.person,
    required this.verified,
    required this.amountPaisa,
    required this.method,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    required this.walletId,
    required this.status,
    required this.reference,
    required this.reason,
    required this.createdAt,
    required this.decidedAt,
  });

  factory WithdrawalRow.fromJson(Json j) {
    final d = (j['destination'] as Json?) ?? const {};
    return WithdrawalRow(
      id: _str(j['id']),
      userId: _str(j['user_id']),
      person: Person.fromJson(j['person'] as Json?),
      verified: j['verified'] == true,
      amountPaisa: _int(j['amount_paisa']),
      method: _str(d['method']),
      bankName: _str(d['bank_name']),
      accountName: _str(d['account_name']),
      accountNumber: _str(d['account_number']),
      walletId: _str(d['wallet_id']),
      status: _str(j['status']),
      reference: _str(j['reference']),
      reason: _str(j['reason']),
      createdAt: _date(j['created_at'])!,
      decidedAt: _date(j['decided_at']),
    );
  }

  final String id;
  final String userId;
  final Person person;
  final bool verified;
  final int amountPaisa;
  final String method;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String walletId;
  final String status;
  final String reference;
  final String reason;
  final DateTime createdAt;
  final DateTime? decidedAt;

  /// Everything an admin needs to make the transfer.
  String get sendTo => switch (method) {
    'esewa' => 'eSewa $walletId, $accountName',
    'khalti' => 'Khalti $walletId, $accountName',
    _ => '$bankName, account $accountNumber, $accountName',
  };
}

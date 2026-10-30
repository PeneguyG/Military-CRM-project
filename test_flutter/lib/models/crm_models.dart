/// Contact lifecycle states shown in the app. Legacy database states are
/// normalized to [archived] when records are loaded.
enum ContactStatus { active, archived }

// A sentinel distinguishes omitted nullable fields from explicit nulls.
const _unset = Object();

/// Parses date-only follow-ups as local calendar dates to avoid time-zone
/// conversion moving a scheduled day backward or forward.
DateTime _parseFollowUpDate(String value) {
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    final parts = value.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }
  return DateTime.parse(value);
}

class Organization {
  const Organization({
    this.id,
    required this.name,
    this.industry = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.notes = '',
    this.isArchived = false,
  });
  final int? id;
  final String name, industry, address, phone, email, notes;
  final bool isArchived;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'industry': industry,
    'address': address,
    'phone': phone,
    'email': email,
    'notes': notes,
    'is_archived': isArchived ? 1 : 0,
  };
  factory Organization.fromMap(Map<String, Object?> m) => Organization(
    id: m['id'] as int?,
    name: m['name'] as String,
    industry: m['industry'] as String? ?? '',
    address: m['address'] as String? ?? '',
    phone: m['phone'] as String? ?? '',
    email: m['email'] as String? ?? '',
    notes: m['notes'] as String? ?? '',
    isArchived: m['is_archived'] == 1,
  );
  Organization copyWith({
    Object? id = _unset,
    String? name,
    String? industry,
    String? address,
    String? phone,
    String? email,
    String? notes,
    bool? isArchived,
  }) => Organization(
    id: identical(id, _unset) ? this.id : id as int?,
    name: name ?? this.name,
    industry: industry ?? this.industry,
    address: address ?? this.address,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    notes: notes ?? this.notes,
    isArchived: isArchived ?? this.isArchived,
  );
}

class Contact {
  const Contact({
    this.id,
    this.organizationId,
    required this.firstName,
    required this.lastName,
    this.title = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.spouseName = '',
    this.childrenInfo = '',
    this.photoPath,
    this.notes = '',
    this.talkingPoints = '',
    ContactStatus status = ContactStatus.active,
    bool isArchived = false,
  }) : status = status == ContactStatus.archived || isArchived
           ? ContactStatus.archived
           : ContactStatus.active,
       isArchived = status == ContactStatus.archived || isArchived;
  final int? id, organizationId;
  final String firstName,
      lastName,
      title,
      phone,
      email,
      address,
      spouseName,
      childrenInfo,
      notes,
      talkingPoints;
  final String? photoPath;
  final ContactStatus status;
  final bool isArchived;
  String get fullName => '$firstName $lastName'.trim();
  Map<String, Object?> toMap() => {
    'id': id,
    'organization_id': organizationId,
    'first_name': firstName,
    'last_name': lastName,
    'title': title,
    'phone': phone,
    'email': email,
    'address': address,
    'spouse_name': spouseName,
    'children_info': childrenInfo,
    'photo_path': photoPath,
    'notes': notes,
    'talking_points': talkingPoints,
    'status': status.name,
    'is_archived': isArchived ? 1 : 0,
  };
  factory Contact.fromMap(Map<String, Object?> m) {
    final storedStatus = m['status'] as String? ?? 'active';
    // Older databases used Inactive and Deceased. Treat those legacy records
    // as archived so they remain available in the Archive tab, not Contacts.
    final isArchived =
        m['is_archived'] == 1 ||
        storedStatus == 'archived' ||
        storedStatus == 'inactive' ||
        storedStatus == 'deceased';

    return Contact(
      id: m['id'] as int?,
      organizationId: m['organization_id'] as int?,
      firstName: m['first_name'] as String,
      lastName: m['last_name'] as String,
      title: m['title'] as String? ?? '',
      phone: m['phone'] as String? ?? '',
      email: m['email'] as String? ?? '',
      address: m['address'] as String? ?? '',
      spouseName: m['spouse_name'] as String? ?? '',
      childrenInfo: m['children_info'] as String? ?? '',
      photoPath: m['photo_path'] as String?,
      notes: m['notes'] as String? ?? '',
      talkingPoints: m['talking_points'] as String? ?? '',
      status: isArchived ? ContactStatus.archived : ContactStatus.active,
      isArchived: isArchived,
    );
  }
  Contact copyWith({
    Object? id = _unset,
    Object? organizationId = _unset,
    String? firstName,
    String? lastName,
    String? title,
    String? phone,
    String? email,
    String? address,
    String? spouseName,
    String? childrenInfo,
    Object? photoPath = _unset,
    String? notes,
    String? talkingPoints,
    ContactStatus? status,
    bool? isArchived,
  }) {
    // A status change also changes the archive flag, and callers that use the
    // older archive flag still receive the corresponding new status.
    final nextStatus =
        status ??
        (isArchived == null
            ? this.status
            : isArchived
            ? ContactStatus.archived
            : ContactStatus.active);
    final nextIsArchived =
        isArchived ??
        (status == null ? this.isArchived : status == ContactStatus.archived);

    return Contact(
      id: identical(id, _unset) ? this.id : id as int?,
      organizationId: identical(organizationId, _unset)
          ? this.organizationId
          : organizationId as int?,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      title: title ?? this.title,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      spouseName: spouseName ?? this.spouseName,
      childrenInfo: childrenInfo ?? this.childrenInfo,
      photoPath: identical(photoPath, _unset)
          ? this.photoPath
          : photoPath as String?,
      notes: notes ?? this.notes,
      talkingPoints: talkingPoints ?? this.talkingPoints,
      status: nextStatus,
      isArchived: nextIsArchived,
    );
  }
}

class InteractionLog {
  const InteractionLog({
    this.id,
    required this.contactId,
    this.organizationId,
    required this.date,
    required this.type,
    required this.summary,
    this.followUpDate,
    this.followUpReason = '',
    this.followUpCompleted = false,
  });
  static const types = ['Call', 'Text', 'In-Person', 'Email'];
  final int? id, organizationId;
  final int contactId;
  final DateTime date;
  final String type, summary;
  final String followUpReason;
  final DateTime? followUpDate;
  final bool followUpCompleted;
  Map<String, Object?> toMap() => {
    'id': id,
    'contact_id': contactId,
    'organization_id': organizationId,
    'date': date.toIso8601String(),
    'type': type,
    'summary': summary,
    'follow_up_date': followUpDate?.toIso8601String(),
    'follow_up_reason': followUpReason,
    'follow_up_completed': followUpCompleted ? 1 : 0,
  };
  factory InteractionLog.fromMap(Map<String, Object?> m) {
    final followUpDate = m['follow_up_date']?.toString();
    final rawDate = m['date']?.toString();
    return InteractionLog(
      id: m['id'] as int?,
      contactId: m['contact_id'] as int,
      organizationId: m['organization_id'] as int?,
      // Older database rows can contain NULL in optional interaction columns.
      // Keep one incomplete legacy row from breaking the entire Home page.
      date: rawDate == null || rawDate.isEmpty
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.parse(rawDate),
      type: m['type']?.toString() ?? 'Call',
      summary: m['summary']?.toString() ?? '',
      followUpDate: followUpDate == null
          ? null
          : _parseFollowUpDate(followUpDate),
      followUpReason: m['follow_up_reason']?.toString() ?? '',
      followUpCompleted: m['follow_up_completed'] == 1,
    );
  }
  InteractionLog copyWith({
    Object? id = _unset,
    int? contactId,
    Object? organizationId = _unset,
    DateTime? date,
    String? type,
    String? summary,
    Object? followUpDate = _unset,
    String? followUpReason,
    bool? followUpCompleted,
  }) => InteractionLog(
    id: identical(id, _unset) ? this.id : id as int?,
    contactId: contactId ?? this.contactId,
    organizationId: identical(organizationId, _unset)
        ? this.organizationId
        : organizationId as int?,
    date: date ?? this.date,
    type: type ?? this.type,
    summary: summary ?? this.summary,
    followUpDate: identical(followUpDate, _unset)
        ? this.followUpDate
        : followUpDate as DateTime?,
    followUpReason: followUpReason ?? this.followUpReason,
    followUpCompleted: followUpCompleted ?? this.followUpCompleted,
  );
}

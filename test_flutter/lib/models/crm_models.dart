import '../utils/utc_time.dart';
import '../utils/rich_text_content.dart';
import '../utils/soundex_helper.dart';
import 'dart:convert';
import 'dart:typed_data';

/// Contact work states; archived contacts are kept out of active lists.
enum ContactStatus { active, inactive, archived }

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

String _joinAddressParts(Iterable<Object?> parts) => parts
    .map((part) => part?.toString().trim() ?? '')
    .where((part) => part.isNotEmpty)
    .join(', ');

class _AddressComponents {
  const _AddressComponents({
    required this.line1,
    required this.line2,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
    required this.formatted,
  });

  final String line1, line2, city, state, postalCode, country, formatted;
}

_AddressComponents _addressComponentsFromMap(Map<String, Object?> map) {
  final legacyAddress = map['address']?.toString().trim() ?? '';
  final rawLine1 = map['address_line1']?.toString().trim() ?? '';
  final line2 = map['address_line2']?.toString().trim() ?? '';
  final city = map['city']?.toString().trim() ?? '';
  final state = map['state']?.toString().trim() ?? '';
  final postalCode = map['postal_code']?.toString().trim() ?? '';
  final country = map['country']?.toString().trim() ?? '';
  final hasStructuredAddress = [
    rawLine1,
    line2,
    city,
    state,
    postalCode,
    country,
  ].any((part) => part.isNotEmpty);
  final line1 = rawLine1.isNotEmpty || hasStructuredAddress
      ? rawLine1
      : legacyAddress;
  final formatted = _joinAddressParts([
    line1,
    line2,
    city,
    state,
    postalCode,
    country,
  ]);
  return _AddressComponents(
    line1: line1,
    line2: line2,
    city: city,
    state: state,
    postalCode: postalCode,
    country: country,
    formatted: formatted.isEmpty ? legacyAddress : formatted,
  );
}

class Organization {
  const Organization({
    this.id,
    this.latitude,
    this.longitude,
    this.coordinateSource = '',
    required this.name,
    this.industry = '',
    String address = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.city = '',
    this.state = '',
    this.postalCode = '',
    this.country = '',
    this.phone = '',
    this.email = '',
    this.notes = '',
    this.logoBytes,
    this.isArchived = false,
  }) : _legacyAddress = address;
  final double? latitude, longitude;
  final String coordinateSource;
  final int? id;
  final String name, industry, phone, email, notes;
  final String addressLine1, addressLine2, city, state, postalCode, country;
  final String _legacyAddress;
  final Uint8List? logoBytes;
  final bool isArchived;

  String get _effectiveAddressLine1 =>
      addressLine1.isNotEmpty ||
          addressLine2.isNotEmpty ||
          city.isNotEmpty ||
          state.isNotEmpty ||
          postalCode.isNotEmpty ||
          country.isNotEmpty
      ? addressLine1
      : _legacyAddress;

  String get address {
    final formatted = _joinAddressParts([
      _effectiveAddressLine1,
      addressLine2,
      city,
      state,
      postalCode,
      country,
    ]);
    return formatted.isEmpty ? _legacyAddress : formatted;
  }

  String get addressDetails {
    final street = _joinAddressParts([_effectiveAddressLine1, addressLine2]);
    final details = [
      if (street.isNotEmpty) 'Address: $street',
      if (city.isNotEmpty) 'City: $city',
      if (state.isNotEmpty) 'State / Province: $state',
      if (country.isNotEmpty) 'Country: $country',
      if (postalCode.isNotEmpty) 'ZIP / Postal code: $postalCode',
    ].join('\n');
    return details.isEmpty ? _legacyAddress : details;
  }

  String get searchText =>
      '$name $industry $address ${RichTextContent.plainText(notes)}';
  String get soundexIndex => SoundexHelper.encodePhrase(searchText);

  Map<String, Object?> toMap() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'coordinate_source': coordinateSource,
    'soundex_index': soundexIndex,
    'name': name,
    'industry': industry,
    'address': address,
    'address_line1': _effectiveAddressLine1,
    'address_line2': addressLine2,
    'city': city,
    'state': state,
    'postal_code': postalCode,
    'country': country,
    'phone': phone,
    'email': email,
    'notes': notes,
    'logo_blob': logoBytes,
    'is_archived': isArchived ? 1 : 0,
  };
  factory Organization.fromMap(Map<String, Object?> m) {
    final address = _addressComponentsFromMap(m);
    return Organization(
      id: m['id'] as int?,
      latitude: _coordinate(m['latitude']),
      longitude: _coordinate(m['longitude']),
      coordinateSource: m['coordinate_source'] as String? ?? '',
      name: m['name'] as String,
      industry: m['industry'] as String? ?? '',
      address: address.formatted,
      addressLine1: address.line1,
      addressLine2: address.line2,
      city: address.city,
      state: address.state,
      postalCode: address.postalCode,
      country: address.country,
      phone: m['phone'] as String? ?? '',
      email: m['email'] as String? ?? '',
      notes: m['notes'] as String? ?? '',
      logoBytes: _readPhotoBytes(m['logo_blob']),
      isArchived: m['is_archived'] == 1,
    );
  }
  Organization copyWith({
    Object? id = _unset,
    Object? latitude = _unset,
    Object? longitude = _unset,
    String? coordinateSource,
    String? name,
    String? industry,
    String? address,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? phone,
    String? email,
    String? notes,
    Object? logoBytes = _unset,
    bool? isArchived,
  }) {
    final addressFieldsChanged =
        addressLine1 != null ||
        addressLine2 != null ||
        city != null ||
        state != null ||
        postalCode != null ||
        country != null;
    return Organization(
      id: identical(id, _unset) ? this.id : id as int?,
      latitude: identical(latitude, _unset)
          ? this.latitude
          : _coordinate(latitude),
      longitude: identical(longitude, _unset)
          ? this.longitude
          : _coordinate(longitude),
      coordinateSource: coordinateSource ?? this.coordinateSource,
      name: name ?? this.name,
      industry: industry ?? this.industry,
      address: address ?? (addressFieldsChanged ? '' : _legacyAddress),
      addressLine1:
          addressLine1 ?? (address == null ? this.addressLine1 : address),
      addressLine2: addressLine2 ?? (address == null ? this.addressLine2 : ''),
      city: city ?? (address == null ? this.city : ''),
      state: state ?? (address == null ? this.state : ''),
      postalCode: postalCode ?? (address == null ? this.postalCode : ''),
      country: country ?? (address == null ? this.country : ''),
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      logoBytes: identical(logoBytes, _unset)
          ? this.logoBytes
          : logoBytes as Uint8List?,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}

class ChildRecord {
  const ChildRecord({required this.name, this.age});

  final String name;
  final int? age;

  Map<String, Object?> toMap() => {'name': name, 'age': age};

  factory ChildRecord.fromMap(Map<String, Object?> map) {
    final rawAge = map['age'];
    return ChildRecord(
      name: map['name'] as String? ?? '',
      age: rawAge is int ? rawAge : int.tryParse(rawAge?.toString() ?? ''),
    );
  }

  static List<ChildRecord> decodeMany(Object? encoded) {
    if (encoded is! String || encoded.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map) ChildRecord.fromMap(Map<String, Object?>.from(item)),
      ];
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }
}

class ProfileTagDefinition {
  const ProfileTagDefinition({
    this.id,
    required this.category,
    required this.value,
    required this.label,
    required this.colorValue,
    this.isBuiltIn = false,
  });

  final int? id;
  final String category;
  final String value;
  final String label;
  final int colorValue;
  final bool isBuiltIn;

  Map<String, Object?> toMap() => {
    'id': id,
    'category': category,
    'value': value,
    'label': label,
    'color_value': colorValue,
    'is_builtin': isBuiltIn ? 1 : 0,
  };

  factory ProfileTagDefinition.fromMap(Map<String, Object?> map) =>
      ProfileTagDefinition(
        id: map['id'] as int?,
        category: map['category']?.toString() ?? 'custom',
        value: map['value']?.toString() ?? '',
        label: map['label']?.toString() ?? '',
        colorValue: map['color_value'] as int? ?? 0xFF616161,
        isBuiltIn: map['is_builtin'] == 1,
      );

  ProfileTagDefinition copyWith({String? label, int? colorValue}) =>
      ProfileTagDefinition(
        id: id,
        category: category,
        value: value,
        label: label ?? this.label,
        colorValue: colorValue ?? this.colorValue,
        isBuiltIn: isBuiltIn,
      );
}

List<int> decodeIntList(Object? encoded) {
  if (encoded is! String || encoded.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(encoded);
    if (decoded is! List) return const [];
    final ids = <int>[];
    for (final item in decoded) {
      if (item is int) {
        ids.add(item);
      } else {
        final id = int.tryParse(item.toString());
        if (id != null) ids.add(id);
      }
    }
    return ids;
  } on FormatException {
    return const [];
  } on TypeError {
    return const [];
  }
}

class ContactPhoneNumber {
  const ContactPhoneNumber({required this.label, required this.number});

  final String label;
  final String number;

  Map<String, Object?> toMap() => {'label': label, 'number': number};

  factory ContactPhoneNumber.fromMap(Map<Object?, Object?> map) =>
      ContactPhoneNumber(
        label: map['label']?.toString() ?? 'Other',
        number: map['number']?.toString() ?? '',
      );

  static List<ContactPhoneNumber> decodeMany(Object? value) {
    Object? decoded = value;
    if (value is String) {
      try {
        decoded = jsonDecode(value);
      } on FormatException {
        return const [];
      }
    }
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map)
          ContactPhoneNumber.fromMap(item.cast<Object?, Object?>()),
    ];
  }
}

class ContactEmailAddress {
  const ContactEmailAddress({required this.label, required this.address});

  final String label;
  final String address;

  Map<String, Object?> toMap() => {'label': label, 'address': address};

  factory ContactEmailAddress.fromMap(Map<Object?, Object?> map) =>
      ContactEmailAddress(
        label: map['label']?.toString() ?? 'Other',
        address: map['address']?.toString() ?? '',
      );

  static List<ContactEmailAddress> decodeMany(Object? value) {
    Object? decoded = value;
    if (value is String) {
      try {
        decoded = jsonDecode(value);
      } on FormatException {
        return const [];
      }
    }
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map)
          ContactEmailAddress.fromMap(item.cast<Object?, Object?>()),
    ];
  }
}

class Contact {
  const Contact({
    this.id,
    this.latitude,
    this.longitude,
    this.coordinateSource = '',
    this.organizationId,
    this.prefix = '',
    required this.firstName,
    this.middleName = '',
    required this.lastName,
    this.suffix = '',
    this.militaryBranch = '',
    this.militaryRank = '',
    this.preferredContactMethod = '',
    this.lifeStatus = 'alive',
    this.customTagIds = const [],
    this.title = '',
    this.phone = '',
    this.phoneLabel = 'Mobile',
    this.additionalPhones = const [],
    this.email = '',
    this.emailLabel = 'Primary',
    this.additionalEmails = const [],
    String address = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.city = '',
    this.state = '',
    this.postalCode = '',
    this.country = '',
    this.spouseName = '',
    this.childrenInfo = '',
    this.children = const [],
    this.photoPath,
    this.photoBytes,
    this.notes = '',
    this.talkingPoints = '',
    ContactStatus status = ContactStatus.active,
    bool isArchived = false,
  }) : _legacyAddress = address,
       status = status == ContactStatus.archived || isArchived
           ? ContactStatus.archived
           : status,
       isArchived = status == ContactStatus.archived || isArchived;
  final double? latitude, longitude;
  final String coordinateSource;
  final int? id, organizationId;
  final String prefix,
      firstName,
      middleName,
      lastName,
      suffix,
      militaryBranch,
      militaryRank,
      preferredContactMethod,
      lifeStatus,
      title,
      phone,
      phoneLabel,
      email,
      emailLabel,
      spouseName,
      childrenInfo,
      notes,
      talkingPoints;
  final String addressLine1, addressLine2, city, state, postalCode, country;
  final String _legacyAddress;
  final String? photoPath;
  final Uint8List? photoBytes;
  final List<ContactPhoneNumber> additionalPhones;
  final List<ContactEmailAddress> additionalEmails;
  final List<ChildRecord> children;
  final List<int> customTagIds;
  final ContactStatus status;
  final bool isArchived;

  String get _effectiveAddressLine1 =>
      addressLine1.isNotEmpty ||
          addressLine2.isNotEmpty ||
          city.isNotEmpty ||
          state.isNotEmpty ||
          postalCode.isNotEmpty ||
          country.isNotEmpty
      ? addressLine1
      : _legacyAddress;

  String get address {
    final formatted = _joinAddressParts([
      _effectiveAddressLine1,
      addressLine2,
      city,
      state,
      postalCode,
      country,
    ]);
    return formatted.isEmpty ? _legacyAddress : formatted;
  }

  String get addressDetails {
    final street = _joinAddressParts([_effectiveAddressLine1, addressLine2]);
    final details = [
      if (street.isNotEmpty) 'Address: $street',
      if (city.isNotEmpty) 'City: $city',
      if (state.isNotEmpty) 'State / Province: $state',
      if (country.isNotEmpty) 'Country: $country',
      if (postalCode.isNotEmpty) 'ZIP / Postal code: $postalCode',
    ].join('\n');
    return details.isEmpty ? _legacyAddress : details;
  }

  List<ContactPhoneNumber> get phoneNumbers => [
    if (phone.trim().isNotEmpty)
      ContactPhoneNumber(
        label: phoneLabel.trim().isEmpty ? 'Phone' : phoneLabel,
        number: phone,
      ),
    ...additionalPhones.where((phone) => phone.number.trim().isNotEmpty),
  ];
  List<ContactEmailAddress> get emailAddresses => [
    if (email.trim().isNotEmpty)
      ContactEmailAddress(
        label: emailLabel.trim().isEmpty ? 'Email' : emailLabel,
        address: email,
      ),
    ...additionalEmails.where((email) => email.address.trim().isNotEmpty),
  ];
  String get fullName =>
      [
        if (prefix.trim().isNotEmpty) prefix.trim(),
        firstName.trim(),
        if (middleName.trim().isNotEmpty) middleName.trim(),
        lastName.trim(),
      ].join(' ') +
      (suffix.trim().isEmpty ? '' : ', ${suffix.trim()}');
  String get searchText => [
    fullName,
    title,
    militaryBranch,
    militaryRank,
    address,
    spouseName,
    childrenInfo,
    ...children.map((c) => c.name),
    RichTextContent.plainText(notes),
    RichTextContent.plainText(talkingPoints),
  ].join(' ');
  String get nameSoundex => SoundexHelper.encodePhrase(
    '$firstName $middleName $lastName $spouseName',
  );
  String get fullSoundexIndex => SoundexHelper.encodePhrase(searchText);

  Map<String, Object?> toMap() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'coordinate_source': coordinateSource,
    'name_soundex': nameSoundex,
    'soundex_index': fullSoundexIndex,
    'organization_id': organizationId,
    'prefix': prefix,
    'first_name': firstName,
    'middle_name': middleName,
    'last_name': lastName,
    'suffix': suffix,
    'military_branch': militaryBranch,
    'military_rank': militaryRank,
    'preferred_contact_method': preferredContactMethod,
    'life_status': lifeStatus,
    'custom_tags_json': jsonEncode(customTagIds),
    'title': title,
    'phone': phone,
    'phone_label': phoneLabel,
    'additional_phones_json': jsonEncode(
      additionalPhones.map((phone) => phone.toMap()).toList(),
    ),
    'email': email,
    'email_label': emailLabel,
    'additional_emails_json': jsonEncode(
      additionalEmails.map((email) => email.toMap()).toList(),
    ),
    'address': address,
    'address_line1': _effectiveAddressLine1,
    'address_line2': addressLine2,
    'city': city,
    'state': state,
    'postal_code': postalCode,
    'country': country,
    'spouse_name': spouseName,
    'children_info': childrenInfo,
    'children_json': jsonEncode(
      children.map((child) => child.toMap()).toList(),
    ),
    'photo_path': photoPath,
    'photo_blob': photoBytes,
    'notes': notes,
    'talking_points': talkingPoints,
    'status': status.name,
    'contact_status': status == ContactStatus.inactive ? 'inactive' : 'active',
    'is_archived': isArchived ? 1 : 0,
  };
  factory Contact.fromMap(Map<String, Object?> m) {
    final address = _addressComponentsFromMap(m);
    final storedStatus = m['status'] as String? ?? 'active';
    // Older databases used Inactive to mean archived. The explicit
    // contact_status field distinguishes the new inactive state.
    final hasExplicitContactStatus = m.containsKey('contact_status');
    final storedContactStatus = m['contact_status'] as String? ?? 'active';
    final isArchived =
        m['is_archived'] == 1 ||
        (!hasExplicitContactStatus &&
            (storedStatus == 'archived' || storedStatus == 'inactive'));

    return Contact(
      id: m['id'] as int?,
      latitude: _coordinate(m['latitude']),
      longitude: _coordinate(m['longitude']),
      coordinateSource: m['coordinate_source'] as String? ?? '',
      organizationId: m['organization_id'] as int?,
      prefix: m['prefix'] as String? ?? '',
      firstName: m['first_name'] as String,
      middleName: m['middle_name'] as String? ?? '',
      lastName: m['last_name'] as String,
      suffix: m['suffix'] as String? ?? '',
      militaryBranch: m['military_branch'] as String? ?? '',
      militaryRank: m['military_rank'] as String? ?? '',
      preferredContactMethod: m['preferred_contact_method'] as String? ?? '',
      lifeStatus:
          m['life_status'] as String? ??
          (storedStatus == 'deceased' ? 'deceased' : 'alive'),
      customTagIds: decodeIntList(m['custom_tags_json']),
      title: m['title'] as String? ?? '',
      phone: m['phone'] as String? ?? '',
      phoneLabel: m['phone_label'] as String? ?? 'Mobile',
      additionalPhones: ContactPhoneNumber.decodeMany(
        m['additional_phones_json'],
      ),
      email: m['email'] as String? ?? '',
      emailLabel: m['email_label'] as String? ?? 'Primary',
      additionalEmails: ContactEmailAddress.decodeMany(
        m['additional_emails_json'],
      ),
      address: address.formatted,
      addressLine1: address.line1,
      addressLine2: address.line2,
      city: address.city,
      state: address.state,
      postalCode: address.postalCode,
      country: address.country,
      spouseName: m['spouse_name'] as String? ?? '',
      childrenInfo: m['children_info'] as String? ?? '',
      children: ChildRecord.decodeMany(m['children_json']),
      photoPath: m['photo_path'] as String?,
      photoBytes: _readPhotoBytes(m['photo_blob']),
      notes: m['notes'] as String? ?? '',
      talkingPoints: m['talking_points'] as String? ?? '',
      status: isArchived
          ? ContactStatus.archived
          : storedContactStatus == ContactStatus.inactive.name
          ? ContactStatus.inactive
          : ContactStatus.active,
      isArchived: isArchived,
    );
  }
  Contact copyWith({
    Object? id = _unset,
    Object? latitude = _unset,
    Object? longitude = _unset,
    String? coordinateSource,
    Object? organizationId = _unset,
    String? prefix,
    String? firstName,
    String? middleName,
    String? lastName,
    String? suffix,
    String? militaryBranch,
    String? militaryRank,
    String? preferredContactMethod,
    String? lifeStatus,
    List<int>? customTagIds,
    String? title,
    String? phone,
    String? phoneLabel,
    List<ContactPhoneNumber>? additionalPhones,
    String? email,
    String? emailLabel,
    List<ContactEmailAddress>? additionalEmails,
    String? address,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? spouseName,
    String? childrenInfo,
    List<ChildRecord>? children,
    Object? photoPath = _unset,
    Object? photoBytes = _unset,
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
            : this.status == ContactStatus.archived
            ? ContactStatus.active
            : this.status);
    final nextIsArchived =
        isArchived ??
        (status == null ? this.isArchived : status == ContactStatus.archived);
    final addressFieldsChanged =
        addressLine1 != null ||
        addressLine2 != null ||
        city != null ||
        state != null ||
        postalCode != null ||
        country != null;

    return Contact(
      id: identical(id, _unset) ? this.id : id as int?,
      latitude: identical(latitude, _unset)
          ? this.latitude
          : _coordinate(latitude),
      longitude: identical(longitude, _unset)
          ? this.longitude
          : _coordinate(longitude),
      coordinateSource: coordinateSource ?? this.coordinateSource,
      organizationId: identical(organizationId, _unset)
          ? this.organizationId
          : organizationId as int?,
      prefix: prefix ?? this.prefix,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      suffix: suffix ?? this.suffix,
      militaryBranch: militaryBranch ?? this.militaryBranch,
      militaryRank: militaryRank ?? this.militaryRank,
      preferredContactMethod:
          preferredContactMethod ?? this.preferredContactMethod,
      lifeStatus: lifeStatus ?? this.lifeStatus,
      customTagIds: customTagIds ?? this.customTagIds,
      title: title ?? this.title,
      phone: phone ?? this.phone,
      phoneLabel: phoneLabel ?? this.phoneLabel,
      additionalPhones: additionalPhones ?? this.additionalPhones,
      email: email ?? this.email,
      emailLabel: emailLabel ?? this.emailLabel,
      additionalEmails: additionalEmails ?? this.additionalEmails,
      address: address ?? (addressFieldsChanged ? '' : _legacyAddress),
      addressLine1:
          addressLine1 ?? (address == null ? this.addressLine1 : address),
      addressLine2: addressLine2 ?? (address == null ? this.addressLine2 : ''),
      city: city ?? (address == null ? this.city : ''),
      state: state ?? (address == null ? this.state : ''),
      postalCode: postalCode ?? (address == null ? this.postalCode : ''),
      country: country ?? (address == null ? this.country : ''),
      spouseName: spouseName ?? this.spouseName,
      childrenInfo: childrenInfo ?? this.childrenInfo,
      children: children ?? this.children,
      photoPath: identical(photoPath, _unset)
          ? this.photoPath
          : photoPath as String?,
      photoBytes: identical(photoBytes, _unset)
          ? this.photoBytes
          : photoBytes as Uint8List?,
      notes: notes ?? this.notes,
      talkingPoints: talkingPoints ?? this.talkingPoints,
      status: nextStatus,
      isArchived: nextIsArchived,
    );
  }
}

class ContactNote {
  const ContactNote({
    this.id,
    required this.contactId,
    required this.text,
    required this.createdAt,
  });

  final int? id;
  final int contactId;
  final String text;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'contact_id': contactId,
    'note_text': text,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory ContactNote.fromMap(Map<String, Object?> map) => ContactNote(
    id: map['id'] as int?,
    contactId: map['contact_id'] as int,
    text: map['note_text']?.toString() ?? '',
    createdAt: parseUtcTimestamp(
      map['created_at']?.toString() ?? '1970-01-01T00:00:00Z',
    ),
  );
}

Uint8List? _readPhotoBytes(Object? value) {
  if (value is Uint8List) return value;
  if (value is List<int>) return Uint8List.fromList(value);
  return null;
}

class OrganizationNote {
  const OrganizationNote({
    this.id,
    required this.organizationId,
    required this.text,
    required this.createdAt,
  });

  final int? id;
  final int organizationId;
  final String text;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'organization_id': organizationId,
    'note_text': text,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory OrganizationNote.fromMap(Map<String, Object?> map) =>
      OrganizationNote(
        id: map['id'] as int?,
        organizationId: map['organization_id'] as int,
        text: map['note_text']?.toString() ?? '',
        createdAt: parseUtcTimestamp(map['created_at'] as String),
      );
}

class InteractionAttachment {
  const InteractionAttachment({
    this.id,
    required this.fileName,
    required this.bytes,
    this.mimeType,
  });

  final int? id;
  final String fileName;
  final Uint8List bytes;
  final String? mimeType;

  Map<String, Object?> toMap() => {
    'id': id,
    'file_name': fileName,
    'mime_type': mimeType,
    'file_blob': bytes,
  };

  factory InteractionAttachment.fromMap(Map<String, Object?> map) =>
      InteractionAttachment(
        id: map['id'] as int?,
        fileName: map['file_name']?.toString() ?? 'Attachment',
        mimeType: map['mime_type']?.toString(),
        bytes: _readPhotoBytes(map['file_blob']) ?? Uint8List(0),
      );
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
    this.followUpTime,
    this.followUpReason = '',
    this.followUpCompleted = false,
    this.isFollowUpOnly = false,
    this.attachments = const [],
  });
  static const types = ['Call', 'Text', 'In-Person', 'Email'];
  final int? id, organizationId;
  final int contactId;
  final DateTime date;
  final String type, summary;
  final String followUpReason;
  final DateTime? followUpDate;
  final String? followUpTime;
  final bool followUpCompleted;
  final bool isFollowUpOnly;
  final List<InteractionAttachment> attachments;
  Map<String, Object?> toMap() => {
    'id': id,
    'contact_id': contactId,
    'organization_id': organizationId,
    'date': date.toUtc().toIso8601String(),
    'type': type,
    'summary': summary,
    'follow_up_date': followUpDate?.toIso8601String(),
    'follow_up_time': followUpTime,
    'follow_up_reason': followUpReason,
    'follow_up_completed': followUpCompleted ? 1 : 0,
    'is_follow_up_only': isFollowUpOnly ? 1 : 0,
    'attachments': attachments.map((attachment) => attachment.toMap()).toList(),
  };
  factory InteractionLog.fromMap(Map<String, Object?> m) {
    final followUpDate = m['follow_up_date']?.toString();
    final rawDate = m['date']?.toString();
    final rawAttachments = m['attachments'];
    return InteractionLog(
      id: m['id'] as int?,
      contactId: m['contact_id'] as int,
      organizationId: m['organization_id'] as int?,
      // Older database rows can contain NULL in optional interaction columns.
      // Keep one incomplete legacy row from breaking the entire Home page.
      date: rawDate == null || rawDate.isEmpty
          ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : parseUtcTimestamp(rawDate),
      type: m['type']?.toString() ?? 'Call',
      summary: m['summary']?.toString() ?? '',
      followUpDate: followUpDate == null
          ? null
          : _parseFollowUpDate(followUpDate),
      followUpTime: m['follow_up_time']?.toString(),
      followUpReason: m['follow_up_reason']?.toString() ?? '',
      followUpCompleted: m['follow_up_completed'] == 1,
      isFollowUpOnly: m['is_follow_up_only'] == 1,
      attachments: rawAttachments is List
          ? [
              for (final attachment in rawAttachments)
                if (attachment is Map)
                  InteractionAttachment.fromMap(
                    Map<String, Object?>.from(attachment),
                  ),
            ]
          : const [],
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
    Object? followUpTime = _unset,
    String? followUpReason,
    bool? followUpCompleted,
    bool? isFollowUpOnly,
    List<InteractionAttachment>? attachments,
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
    followUpTime: identical(followUpTime, _unset)
        ? this.followUpTime
        : followUpTime as String?,
    followUpReason: followUpReason ?? this.followUpReason,
    followUpCompleted: followUpCompleted ?? this.followUpCompleted,
    isFollowUpOnly: isFollowUpOnly ?? this.isFollowUpOnly,
    attachments: attachments ?? this.attachments,
  );
}

double? _coordinate(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
  });
  final double latitude, longitude;
  final String label;
  static const demo = UserLocation(
    latitude: 36.163,
    longitude: -86.782,
    label: 'Demo base — Nashville',
  );
  Map<String, Object?> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    'label': label,
  };
  factory UserLocation.fromMap(Map<String, Object?> map) => UserLocation(
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
    label: map['label'] as String,
  );
}

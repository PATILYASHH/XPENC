// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts
    with TableInfo<$AccountsTable, AccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 60,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AccountType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AccountType>($AccountsTable.$convertertype);
  @override
  late final GeneratedColumnWithTypeConverter<CardKind?, String> cardKind =
      GeneratedColumn<String>(
        'card_kind',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<CardKind?>($AccountsTable.$convertercardKindn);
  static const VerificationMeta _linkedAccountIdMeta = const VerificationMeta(
    'linkedAccountId',
  );
  @override
  late final GeneratedColumn<int> linkedAccountId = GeneratedColumn<int>(
    'linked_account_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _bankNameMeta = const VerificationMeta(
    'bankName',
  );
  @override
  late final GeneratedColumn<String> bankName = GeneratedColumn<String>(
    'bank_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _last4Meta = const VerificationMeta('last4');
  @override
  late final GeneratedColumn<String> last4 = GeneratedColumn<String>(
    'last4',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 4,
      maxTextLength: 4,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconKeyMeta = const VerificationMeta(
    'iconKey',
  );
  @override
  late final GeneratedColumn<String> iconKey = GeneratedColumn<String>(
    'icon_key',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 40,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Money, int> openingBalance =
      GeneratedColumn<int>(
        'opening_balance',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Money>($AccountsTable.$converteropeningBalance);
  @override
  late final GeneratedColumnWithTypeConverter<Money, int> currentBalance =
      GeneratedColumn<int>(
        'current_balance',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Money>($AccountsTable.$convertercurrentBalance);
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    cardKind,
    linkedAccountId,
    bankName,
    last4,
    colorValue,
    iconKey,
    openingBalance,
    currentBalance,
    isArchived,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('linked_account_id')) {
      context.handle(
        _linkedAccountIdMeta,
        linkedAccountId.isAcceptableOrUnknown(
          data['linked_account_id']!,
          _linkedAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('bank_name')) {
      context.handle(
        _bankNameMeta,
        bankName.isAcceptableOrUnknown(data['bank_name']!, _bankNameMeta),
      );
    }
    if (data.containsKey('last4')) {
      context.handle(
        _last4Meta,
        last4.isAcceptableOrUnknown(data['last4']!, _last4Meta),
      );
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('icon_key')) {
      context.handle(
        _iconKeyMeta,
        iconKey.isAcceptableOrUnknown(data['icon_key']!, _iconKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_iconKeyMeta);
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AccountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: $AccountsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      cardKind: $AccountsTable.$convertercardKindn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}card_kind'],
        ),
      ),
      linkedAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}linked_account_id'],
      ),
      bankName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_name'],
      ),
      last4: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last4'],
      ),
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      iconKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_key'],
      )!,
      openingBalance: $AccountsTable.$converteropeningBalance.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}opening_balance'],
        )!,
      ),
      currentBalance: $AccountsTable.$convertercurrentBalance.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}current_balance'],
        )!,
      ),
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AccountType, String, String> $convertertype =
      const EnumNameConverter<AccountType>(AccountType.values);
  static JsonTypeConverter2<CardKind, String, String> $convertercardKind =
      const EnumNameConverter<CardKind>(CardKind.values);
  static JsonTypeConverter2<CardKind?, String?, String?> $convertercardKindn =
      JsonTypeConverter2.asNullable($convertercardKind);
  static TypeConverter<Money, int> $converteropeningBalance =
      const MoneyConverter();
  static TypeConverter<Money, int> $convertercurrentBalance =
      const MoneyConverter();
}

class AccountRow extends DataClass implements Insertable<AccountRow> {
  final int id;
  final String name;
  final AccountType type;

  /// Only set when [type] is [AccountType.card].
  final CardKind? cardKind;

  /// Set for debit cards (and UPI-style instruments): the bank they draw from.
  /// When non-null this account holds **no** balance of its own.
  final int? linkedAccountId;

  /// For message auto-capture: which bank, and the last 4 digits to match on.
  final String? bankName;
  final String? last4;
  final int colorValue;
  final String iconKey;
  final Money openingBalance;

  /// Cache of the ledger. Updated atomically with every write.
  /// `recalculateBalances()` rebuilds it from the ledger if it ever drifts.
  final Money currentBalance;
  final bool isArchived;
  final int sortOrder;
  final DateTime createdAt;
  const AccountRow({
    required this.id,
    required this.name,
    required this.type,
    this.cardKind,
    this.linkedAccountId,
    this.bankName,
    this.last4,
    required this.colorValue,
    required this.iconKey,
    required this.openingBalance,
    required this.currentBalance,
    required this.isArchived,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    {
      map['type'] = Variable<String>($AccountsTable.$convertertype.toSql(type));
    }
    if (!nullToAbsent || cardKind != null) {
      map['card_kind'] = Variable<String>(
        $AccountsTable.$convertercardKindn.toSql(cardKind),
      );
    }
    if (!nullToAbsent || linkedAccountId != null) {
      map['linked_account_id'] = Variable<int>(linkedAccountId);
    }
    if (!nullToAbsent || bankName != null) {
      map['bank_name'] = Variable<String>(bankName);
    }
    if (!nullToAbsent || last4 != null) {
      map['last4'] = Variable<String>(last4);
    }
    map['color_value'] = Variable<int>(colorValue);
    map['icon_key'] = Variable<String>(iconKey);
    {
      map['opening_balance'] = Variable<int>(
        $AccountsTable.$converteropeningBalance.toSql(openingBalance),
      );
    }
    {
      map['current_balance'] = Variable<int>(
        $AccountsTable.$convertercurrentBalance.toSql(currentBalance),
      );
    }
    map['is_archived'] = Variable<bool>(isArchived);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      cardKind: cardKind == null && nullToAbsent
          ? const Value.absent()
          : Value(cardKind),
      linkedAccountId: linkedAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedAccountId),
      bankName: bankName == null && nullToAbsent
          ? const Value.absent()
          : Value(bankName),
      last4: last4 == null && nullToAbsent
          ? const Value.absent()
          : Value(last4),
      colorValue: Value(colorValue),
      iconKey: Value(iconKey),
      openingBalance: Value(openingBalance),
      currentBalance: Value(currentBalance),
      isArchived: Value(isArchived),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory AccountRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: $AccountsTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      cardKind: $AccountsTable.$convertercardKindn.fromJson(
        serializer.fromJson<String?>(json['cardKind']),
      ),
      linkedAccountId: serializer.fromJson<int?>(json['linkedAccountId']),
      bankName: serializer.fromJson<String?>(json['bankName']),
      last4: serializer.fromJson<String?>(json['last4']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      iconKey: serializer.fromJson<String>(json['iconKey']),
      openingBalance: serializer.fromJson<Money>(json['openingBalance']),
      currentBalance: serializer.fromJson<Money>(json['currentBalance']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(
        $AccountsTable.$convertertype.toJson(type),
      ),
      'cardKind': serializer.toJson<String?>(
        $AccountsTable.$convertercardKindn.toJson(cardKind),
      ),
      'linkedAccountId': serializer.toJson<int?>(linkedAccountId),
      'bankName': serializer.toJson<String?>(bankName),
      'last4': serializer.toJson<String?>(last4),
      'colorValue': serializer.toJson<int>(colorValue),
      'iconKey': serializer.toJson<String>(iconKey),
      'openingBalance': serializer.toJson<Money>(openingBalance),
      'currentBalance': serializer.toJson<Money>(currentBalance),
      'isArchived': serializer.toJson<bool>(isArchived),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AccountRow copyWith({
    int? id,
    String? name,
    AccountType? type,
    Value<CardKind?> cardKind = const Value.absent(),
    Value<int?> linkedAccountId = const Value.absent(),
    Value<String?> bankName = const Value.absent(),
    Value<String?> last4 = const Value.absent(),
    int? colorValue,
    String? iconKey,
    Money? openingBalance,
    Money? currentBalance,
    bool? isArchived,
    int? sortOrder,
    DateTime? createdAt,
  }) => AccountRow(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    cardKind: cardKind.present ? cardKind.value : this.cardKind,
    linkedAccountId: linkedAccountId.present
        ? linkedAccountId.value
        : this.linkedAccountId,
    bankName: bankName.present ? bankName.value : this.bankName,
    last4: last4.present ? last4.value : this.last4,
    colorValue: colorValue ?? this.colorValue,
    iconKey: iconKey ?? this.iconKey,
    openingBalance: openingBalance ?? this.openingBalance,
    currentBalance: currentBalance ?? this.currentBalance,
    isArchived: isArchived ?? this.isArchived,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  AccountRow copyWithCompanion(AccountsCompanion data) {
    return AccountRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      cardKind: data.cardKind.present ? data.cardKind.value : this.cardKind,
      linkedAccountId: data.linkedAccountId.present
          ? data.linkedAccountId.value
          : this.linkedAccountId,
      bankName: data.bankName.present ? data.bankName.value : this.bankName,
      last4: data.last4.present ? data.last4.value : this.last4,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      iconKey: data.iconKey.present ? data.iconKey.value : this.iconKey,
      openingBalance: data.openingBalance.present
          ? data.openingBalance.value
          : this.openingBalance,
      currentBalance: data.currentBalance.present
          ? data.currentBalance.value
          : this.currentBalance,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('cardKind: $cardKind, ')
          ..write('linkedAccountId: $linkedAccountId, ')
          ..write('bankName: $bankName, ')
          ..write('last4: $last4, ')
          ..write('colorValue: $colorValue, ')
          ..write('iconKey: $iconKey, ')
          ..write('openingBalance: $openingBalance, ')
          ..write('currentBalance: $currentBalance, ')
          ..write('isArchived: $isArchived, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    cardKind,
    linkedAccountId,
    bankName,
    last4,
    colorValue,
    iconKey,
    openingBalance,
    currentBalance,
    isArchived,
    sortOrder,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.cardKind == this.cardKind &&
          other.linkedAccountId == this.linkedAccountId &&
          other.bankName == this.bankName &&
          other.last4 == this.last4 &&
          other.colorValue == this.colorValue &&
          other.iconKey == this.iconKey &&
          other.openingBalance == this.openingBalance &&
          other.currentBalance == this.currentBalance &&
          other.isArchived == this.isArchived &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class AccountsCompanion extends UpdateCompanion<AccountRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<AccountType> type;
  final Value<CardKind?> cardKind;
  final Value<int?> linkedAccountId;
  final Value<String?> bankName;
  final Value<String?> last4;
  final Value<int> colorValue;
  final Value<String> iconKey;
  final Value<Money> openingBalance;
  final Value<Money> currentBalance;
  final Value<bool> isArchived;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.cardKind = const Value.absent(),
    this.linkedAccountId = const Value.absent(),
    this.bankName = const Value.absent(),
    this.last4 = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.openingBalance = const Value.absent(),
    this.currentBalance = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AccountsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required AccountType type,
    this.cardKind = const Value.absent(),
    this.linkedAccountId = const Value.absent(),
    this.bankName = const Value.absent(),
    this.last4 = const Value.absent(),
    required int colorValue,
    required String iconKey,
    required Money openingBalance,
    required Money currentBalance,
    this.isArchived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       type = Value(type),
       colorValue = Value(colorValue),
       iconKey = Value(iconKey),
       openingBalance = Value(openingBalance),
       currentBalance = Value(currentBalance);
  static Insertable<AccountRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? cardKind,
    Expression<int>? linkedAccountId,
    Expression<String>? bankName,
    Expression<String>? last4,
    Expression<int>? colorValue,
    Expression<String>? iconKey,
    Expression<int>? openingBalance,
    Expression<int>? currentBalance,
    Expression<bool>? isArchived,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (cardKind != null) 'card_kind': cardKind,
      if (linkedAccountId != null) 'linked_account_id': linkedAccountId,
      if (bankName != null) 'bank_name': bankName,
      if (last4 != null) 'last4': last4,
      if (colorValue != null) 'color_value': colorValue,
      if (iconKey != null) 'icon_key': iconKey,
      if (openingBalance != null) 'opening_balance': openingBalance,
      if (currentBalance != null) 'current_balance': currentBalance,
      if (isArchived != null) 'is_archived': isArchived,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AccountsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<AccountType>? type,
    Value<CardKind?>? cardKind,
    Value<int?>? linkedAccountId,
    Value<String?>? bankName,
    Value<String?>? last4,
    Value<int>? colorValue,
    Value<String>? iconKey,
    Value<Money>? openingBalance,
    Value<Money>? currentBalance,
    Value<bool>? isArchived,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      cardKind: cardKind ?? this.cardKind,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      bankName: bankName ?? this.bankName,
      last4: last4 ?? this.last4,
      colorValue: colorValue ?? this.colorValue,
      iconKey: iconKey ?? this.iconKey,
      openingBalance: openingBalance ?? this.openingBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $AccountsTable.$convertertype.toSql(type.value),
      );
    }
    if (cardKind.present) {
      map['card_kind'] = Variable<String>(
        $AccountsTable.$convertercardKindn.toSql(cardKind.value),
      );
    }
    if (linkedAccountId.present) {
      map['linked_account_id'] = Variable<int>(linkedAccountId.value);
    }
    if (bankName.present) {
      map['bank_name'] = Variable<String>(bankName.value);
    }
    if (last4.present) {
      map['last4'] = Variable<String>(last4.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (iconKey.present) {
      map['icon_key'] = Variable<String>(iconKey.value);
    }
    if (openingBalance.present) {
      map['opening_balance'] = Variable<int>(
        $AccountsTable.$converteropeningBalance.toSql(openingBalance.value),
      );
    }
    if (currentBalance.present) {
      map['current_balance'] = Variable<int>(
        $AccountsTable.$convertercurrentBalance.toSql(currentBalance.value),
      );
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('cardKind: $cardKind, ')
          ..write('linkedAccountId: $linkedAccountId, ')
          ..write('bankName: $bankName, ')
          ..write('last4: $last4, ')
          ..write('colorValue: $colorValue, ')
          ..write('iconKey: $iconKey, ')
          ..write('openingBalance: $openingBalance, ')
          ..write('currentBalance: $currentBalance, ')
          ..write('isArchived: $isArchived, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, CategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 40,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CategoryKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CategoryKind>($CategoriesTable.$converterkind);
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconKeyMeta = const VerificationMeta(
    'iconKey',
  );
  @override
  late final GeneratedColumn<String> iconKey = GeneratedColumn<String>(
    'icon_key',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 40,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<int> parentId = GeneratedColumn<int>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    kind,
    colorValue,
    iconKey,
    isArchived,
    sortOrder,
    parentId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('icon_key')) {
      context.handle(
        _iconKeyMeta,
        iconKey.isAcceptableOrUnknown(data['icon_key']!, _iconKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_iconKeyMeta);
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: $CategoriesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      iconKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_key'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_id'],
      ),
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CategoryKind, String, String> $converterkind =
      const EnumNameConverter<CategoryKind>(CategoryKind.values);
}

class CategoryRow extends DataClass implements Insertable<CategoryRow> {
  final int id;
  final String name;
  final CategoryKind kind;
  final int colorValue;
  final String iconKey;
  final bool isArchived;
  final int sortOrder;

  /// A top-level category has a **null** parent. A subcategory points at its
  /// parent, which is always itself top-level — the tree is exactly two deep.
  /// A child always shares its parent's [kind].
  ///
  /// No schema-level foreign key on purpose: categories are archived, never
  /// hard-deleted, so a parent can't vanish under a child. The parent's
  /// existence, kind and single-level depth are all enforced in the DB layer
  /// ([AppDatabase.addCategory] / [AppDatabase.updateCategory]); a stray id
  /// from an old backup is treated as top-level rather than wedging a query.
  final int? parentId;
  const CategoryRow({
    required this.id,
    required this.name,
    required this.kind,
    required this.colorValue,
    required this.iconKey,
    required this.isArchived,
    required this.sortOrder,
    this.parentId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    {
      map['kind'] = Variable<String>(
        $CategoriesTable.$converterkind.toSql(kind),
      );
    }
    map['color_value'] = Variable<int>(colorValue);
    map['icon_key'] = Variable<String>(iconKey);
    map['is_archived'] = Variable<bool>(isArchived);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<int>(parentId);
    }
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      colorValue: Value(colorValue),
      iconKey: Value(iconKey),
      isArchived: Value(isArchived),
      sortOrder: Value(sortOrder),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
    );
  }

  factory CategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: $CategoriesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      iconKey: serializer.fromJson<String>(json['iconKey']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      parentId: serializer.fromJson<int?>(json['parentId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(
        $CategoriesTable.$converterkind.toJson(kind),
      ),
      'colorValue': serializer.toJson<int>(colorValue),
      'iconKey': serializer.toJson<String>(iconKey),
      'isArchived': serializer.toJson<bool>(isArchived),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'parentId': serializer.toJson<int?>(parentId),
    };
  }

  CategoryRow copyWith({
    int? id,
    String? name,
    CategoryKind? kind,
    int? colorValue,
    String? iconKey,
    bool? isArchived,
    int? sortOrder,
    Value<int?> parentId = const Value.absent(),
  }) => CategoryRow(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    colorValue: colorValue ?? this.colorValue,
    iconKey: iconKey ?? this.iconKey,
    isArchived: isArchived ?? this.isArchived,
    sortOrder: sortOrder ?? this.sortOrder,
    parentId: parentId.present ? parentId.value : this.parentId,
  );
  CategoryRow copyWithCompanion(CategoriesCompanion data) {
    return CategoryRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      iconKey: data.iconKey.present ? data.iconKey.value : this.iconKey,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('colorValue: $colorValue, ')
          ..write('iconKey: $iconKey, ')
          ..write('isArchived: $isArchived, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('parentId: $parentId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    colorValue,
    iconKey,
    isArchived,
    sortOrder,
    parentId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.colorValue == this.colorValue &&
          other.iconKey == this.iconKey &&
          other.isArchived == this.isArchived &&
          other.sortOrder == this.sortOrder &&
          other.parentId == this.parentId);
}

class CategoriesCompanion extends UpdateCompanion<CategoryRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<CategoryKind> kind;
  final Value<int> colorValue;
  final Value<String> iconKey;
  final Value<bool> isArchived;
  final Value<int> sortOrder;
  final Value<int?> parentId;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.parentId = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required CategoryKind kind,
    required int colorValue,
    required String iconKey,
    this.isArchived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.parentId = const Value.absent(),
  }) : name = Value(name),
       kind = Value(kind),
       colorValue = Value(colorValue),
       iconKey = Value(iconKey);
  static Insertable<CategoryRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<int>? colorValue,
    Expression<String>? iconKey,
    Expression<bool>? isArchived,
    Expression<int>? sortOrder,
    Expression<int>? parentId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (colorValue != null) 'color_value': colorValue,
      if (iconKey != null) 'icon_key': iconKey,
      if (isArchived != null) 'is_archived': isArchived,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (parentId != null) 'parent_id': parentId,
    });
  }

  CategoriesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<CategoryKind>? kind,
    Value<int>? colorValue,
    Value<String>? iconKey,
    Value<bool>? isArchived,
    Value<int>? sortOrder,
    Value<int?>? parentId,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      colorValue: colorValue ?? this.colorValue,
      iconKey: iconKey ?? this.iconKey,
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
      parentId: parentId ?? this.parentId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $CategoriesTable.$converterkind.toSql(kind.value),
      );
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (iconKey.present) {
      map['icon_key'] = Variable<String>(iconKey.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<int>(parentId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('colorValue: $colorValue, ')
          ..write('iconKey: $iconKey, ')
          ..write('isArchived: $isArchived, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('parentId: $parentId')
          ..write(')'))
        .toString();
  }
}

class $PersonsTable extends Persons with TableInfo<$PersonsTable, PersonRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PersonsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 60,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contactMeta = const VerificationMeta(
    'contact',
  );
  @override
  late final GeneratedColumn<String> contact = GeneratedColumn<String>(
    'contact',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    contact,
    note,
    isArchived,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'persons';
  @override
  VerificationContext validateIntegrity(
    Insertable<PersonRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('contact')) {
      context.handle(
        _contactMeta,
        contact.isAcceptableOrUnknown(data['contact']!, _contactMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PersonRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PersonRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      contact: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PersonsTable createAlias(String alias) {
    return $PersonsTable(attachedDatabase, alias);
  }
}

class PersonRow extends DataClass implements Insertable<PersonRow> {
  final int id;
  final String name;
  final String? contact;
  final String? note;
  final bool isArchived;
  final DateTime createdAt;
  const PersonRow({
    required this.id,
    required this.name,
    this.contact,
    this.note,
    required this.isArchived,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || contact != null) {
      map['contact'] = Variable<String>(contact);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['is_archived'] = Variable<bool>(isArchived);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PersonsCompanion toCompanion(bool nullToAbsent) {
    return PersonsCompanion(
      id: Value(id),
      name: Value(name),
      contact: contact == null && nullToAbsent
          ? const Value.absent()
          : Value(contact),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      isArchived: Value(isArchived),
      createdAt: Value(createdAt),
    );
  }

  factory PersonRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PersonRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      contact: serializer.fromJson<String?>(json['contact']),
      note: serializer.fromJson<String?>(json['note']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'contact': serializer.toJson<String?>(contact),
      'note': serializer.toJson<String?>(note),
      'isArchived': serializer.toJson<bool>(isArchived),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PersonRow copyWith({
    int? id,
    String? name,
    Value<String?> contact = const Value.absent(),
    Value<String?> note = const Value.absent(),
    bool? isArchived,
    DateTime? createdAt,
  }) => PersonRow(
    id: id ?? this.id,
    name: name ?? this.name,
    contact: contact.present ? contact.value : this.contact,
    note: note.present ? note.value : this.note,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt ?? this.createdAt,
  );
  PersonRow copyWithCompanion(PersonsCompanion data) {
    return PersonRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      contact: data.contact.present ? data.contact.value : this.contact,
      note: data.note.present ? data.note.value : this.note,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PersonRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('contact: $contact, ')
          ..write('note: $note, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, contact, note, isArchived, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersonRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.contact == this.contact &&
          other.note == this.note &&
          other.isArchived == this.isArchived &&
          other.createdAt == this.createdAt);
}

class PersonsCompanion extends UpdateCompanion<PersonRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> contact;
  final Value<String?> note;
  final Value<bool> isArchived;
  final Value<DateTime> createdAt;
  const PersonsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.contact = const Value.absent(),
    this.note = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PersonsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.contact = const Value.absent(),
    this.note = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<PersonRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? contact,
    Expression<String>? note,
    Expression<bool>? isArchived,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (contact != null) 'contact': contact,
      if (note != null) 'note': note,
      if (isArchived != null) 'is_archived': isArchived,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PersonsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? contact,
    Value<String?>? note,
    Value<bool>? isArchived,
    Value<DateTime>? createdAt,
  }) {
    return PersonsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      contact: contact ?? this.contact,
      note: note ?? this.note,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (contact.present) {
      map['contact'] = Variable<String>(contact.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PersonsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('contact: $contact, ')
          ..write('note: $note, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $RecurringRulesTable extends RecurringRules
    with TableInfo<$RecurringRulesTable, RecurringRuleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecurringRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 60,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CategoryKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CategoryKind>($RecurringRulesTable.$converterkind);
  @override
  late final GeneratedColumnWithTypeConverter<Money, int> amount =
      GeneratedColumn<int>(
        'amount',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Money>($RecurringRulesTable.$converteramount);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _payeeMeta = const VerificationMeta('payee');
  @override
  late final GeneratedColumn<String> payee = GeneratedColumn<String>(
    'payee',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<RecurringFrequency, String>
  frequency = GeneratedColumn<String>(
    'frequency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<RecurringFrequency>($RecurringRulesTable.$converterfrequency);
  static const VerificationMeta _dayOfMonthMeta = const VerificationMeta(
    'dayOfMonth',
  );
  @override
  late final GeneratedColumn<int> dayOfMonth = GeneratedColumn<int>(
    'day_of_month',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextDueDateMeta = const VerificationMeta(
    'nextDueDate',
  );
  @override
  late final GeneratedColumn<DateTime> nextDueDate = GeneratedColumn<DateTime>(
    'next_due_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notifyDaysBeforeMeta = const VerificationMeta(
    'notifyDaysBefore',
  );
  @override
  late final GeneratedColumn<int> notifyDaysBefore = GeneratedColumn<int>(
    'notify_days_before',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isEstimateMeta = const VerificationMeta(
    'isEstimate',
  );
  @override
  late final GeneratedColumn<bool> isEstimate = GeneratedColumn<bool>(
    'is_estimate',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_estimate" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    kind,
    amount,
    accountId,
    categoryId,
    payee,
    frequency,
    dayOfMonth,
    nextDueDate,
    notifyDaysBefore,
    isActive,
    isEstimate,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recurring_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecurringRuleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('payee')) {
      context.handle(
        _payeeMeta,
        payee.isAcceptableOrUnknown(data['payee']!, _payeeMeta),
      );
    }
    if (data.containsKey('day_of_month')) {
      context.handle(
        _dayOfMonthMeta,
        dayOfMonth.isAcceptableOrUnknown(
          data['day_of_month']!,
          _dayOfMonthMeta,
        ),
      );
    }
    if (data.containsKey('next_due_date')) {
      context.handle(
        _nextDueDateMeta,
        nextDueDate.isAcceptableOrUnknown(
          data['next_due_date']!,
          _nextDueDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextDueDateMeta);
    }
    if (data.containsKey('notify_days_before')) {
      context.handle(
        _notifyDaysBeforeMeta,
        notifyDaysBefore.isAcceptableOrUnknown(
          data['notify_days_before']!,
          _notifyDaysBeforeMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('is_estimate')) {
      context.handle(
        _isEstimateMeta,
        isEstimate.isAcceptableOrUnknown(data['is_estimate']!, _isEstimateMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecurringRuleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecurringRuleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: $RecurringRulesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      amount: $RecurringRulesTable.$converteramount.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}amount'],
        )!,
      ),
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      )!,
      payee: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee'],
      ),
      frequency: $RecurringRulesTable.$converterfrequency.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}frequency'],
        )!,
      ),
      dayOfMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_of_month'],
      ),
      nextDueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_due_date'],
      )!,
      notifyDaysBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notify_days_before'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      isEstimate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_estimate'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RecurringRulesTable createAlias(String alias) {
    return $RecurringRulesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CategoryKind, String, String> $converterkind =
      const EnumNameConverter<CategoryKind>(CategoryKind.values);
  static TypeConverter<Money, int> $converteramount = const MoneyConverter();
  static JsonTypeConverter2<RecurringFrequency, String, String>
  $converterfrequency = const EnumNameConverter<RecurringFrequency>(
    RecurringFrequency.values,
  );
}

class RecurringRuleRow extends DataClass
    implements Insertable<RecurringRuleRow> {
  final int id;
  final String name;

  /// Reuses [CategoryKind] rather than a bespoke enum — a rule is exactly as
  /// income-or-expense as the category it posts under.
  final CategoryKind kind;
  final Money amount;
  final int accountId;
  final int categoryId;

  /// Expense only — same free-text field as [Transactions.payee].
  final String? payee;
  final RecurringFrequency frequency;

  /// Monthly only. Captured once from whichever "starts on" date is chosen —
  /// not re-derived from [nextDueDate] each time, so a month too short for it
  /// (see [nextDueDate]) still remembers the day to snap back to.
  final int? dayOfMonth;

  /// The next occurrence still to be posted. A catch-up run advances this one
  /// occurrence at a time until it lands in the future, backfilling every
  /// missed date on the way — it never sits stale behind the present.
  final DateTime nextDueDate;
  final int notifyDaysBefore;
  final bool isActive;

  /// True for a rule whose amount isn't really fixed — a salary that depends
  /// on hours worked, production, etc. [amount] still seeds every posted
  /// occurrence (so there's always a number in the ledger the moment it's
  /// due), but that transaction comes out flagged via
  /// [Transactions.needsAmountReview] so the user is nudged to correct it to
  /// what actually landed.
  final bool isEstimate;
  final DateTime createdAt;
  const RecurringRuleRow({
    required this.id,
    required this.name,
    required this.kind,
    required this.amount,
    required this.accountId,
    required this.categoryId,
    this.payee,
    required this.frequency,
    this.dayOfMonth,
    required this.nextDueDate,
    required this.notifyDaysBefore,
    required this.isActive,
    required this.isEstimate,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    {
      map['kind'] = Variable<String>(
        $RecurringRulesTable.$converterkind.toSql(kind),
      );
    }
    {
      map['amount'] = Variable<int>(
        $RecurringRulesTable.$converteramount.toSql(amount),
      );
    }
    map['account_id'] = Variable<int>(accountId);
    map['category_id'] = Variable<int>(categoryId);
    if (!nullToAbsent || payee != null) {
      map['payee'] = Variable<String>(payee);
    }
    {
      map['frequency'] = Variable<String>(
        $RecurringRulesTable.$converterfrequency.toSql(frequency),
      );
    }
    if (!nullToAbsent || dayOfMonth != null) {
      map['day_of_month'] = Variable<int>(dayOfMonth);
    }
    map['next_due_date'] = Variable<DateTime>(nextDueDate);
    map['notify_days_before'] = Variable<int>(notifyDaysBefore);
    map['is_active'] = Variable<bool>(isActive);
    map['is_estimate'] = Variable<bool>(isEstimate);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RecurringRulesCompanion toCompanion(bool nullToAbsent) {
    return RecurringRulesCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      amount: Value(amount),
      accountId: Value(accountId),
      categoryId: Value(categoryId),
      payee: payee == null && nullToAbsent
          ? const Value.absent()
          : Value(payee),
      frequency: Value(frequency),
      dayOfMonth: dayOfMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(dayOfMonth),
      nextDueDate: Value(nextDueDate),
      notifyDaysBefore: Value(notifyDaysBefore),
      isActive: Value(isActive),
      isEstimate: Value(isEstimate),
      createdAt: Value(createdAt),
    );
  }

  factory RecurringRuleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecurringRuleRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: $RecurringRulesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      amount: serializer.fromJson<Money>(json['amount']),
      accountId: serializer.fromJson<int>(json['accountId']),
      categoryId: serializer.fromJson<int>(json['categoryId']),
      payee: serializer.fromJson<String?>(json['payee']),
      frequency: $RecurringRulesTable.$converterfrequency.fromJson(
        serializer.fromJson<String>(json['frequency']),
      ),
      dayOfMonth: serializer.fromJson<int?>(json['dayOfMonth']),
      nextDueDate: serializer.fromJson<DateTime>(json['nextDueDate']),
      notifyDaysBefore: serializer.fromJson<int>(json['notifyDaysBefore']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      isEstimate: serializer.fromJson<bool>(json['isEstimate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(
        $RecurringRulesTable.$converterkind.toJson(kind),
      ),
      'amount': serializer.toJson<Money>(amount),
      'accountId': serializer.toJson<int>(accountId),
      'categoryId': serializer.toJson<int>(categoryId),
      'payee': serializer.toJson<String?>(payee),
      'frequency': serializer.toJson<String>(
        $RecurringRulesTable.$converterfrequency.toJson(frequency),
      ),
      'dayOfMonth': serializer.toJson<int?>(dayOfMonth),
      'nextDueDate': serializer.toJson<DateTime>(nextDueDate),
      'notifyDaysBefore': serializer.toJson<int>(notifyDaysBefore),
      'isActive': serializer.toJson<bool>(isActive),
      'isEstimate': serializer.toJson<bool>(isEstimate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RecurringRuleRow copyWith({
    int? id,
    String? name,
    CategoryKind? kind,
    Money? amount,
    int? accountId,
    int? categoryId,
    Value<String?> payee = const Value.absent(),
    RecurringFrequency? frequency,
    Value<int?> dayOfMonth = const Value.absent(),
    DateTime? nextDueDate,
    int? notifyDaysBefore,
    bool? isActive,
    bool? isEstimate,
    DateTime? createdAt,
  }) => RecurringRuleRow(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    amount: amount ?? this.amount,
    accountId: accountId ?? this.accountId,
    categoryId: categoryId ?? this.categoryId,
    payee: payee.present ? payee.value : this.payee,
    frequency: frequency ?? this.frequency,
    dayOfMonth: dayOfMonth.present ? dayOfMonth.value : this.dayOfMonth,
    nextDueDate: nextDueDate ?? this.nextDueDate,
    notifyDaysBefore: notifyDaysBefore ?? this.notifyDaysBefore,
    isActive: isActive ?? this.isActive,
    isEstimate: isEstimate ?? this.isEstimate,
    createdAt: createdAt ?? this.createdAt,
  );
  RecurringRuleRow copyWithCompanion(RecurringRulesCompanion data) {
    return RecurringRuleRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      amount: data.amount.present ? data.amount.value : this.amount,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      payee: data.payee.present ? data.payee.value : this.payee,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      dayOfMonth: data.dayOfMonth.present
          ? data.dayOfMonth.value
          : this.dayOfMonth,
      nextDueDate: data.nextDueDate.present
          ? data.nextDueDate.value
          : this.nextDueDate,
      notifyDaysBefore: data.notifyDaysBefore.present
          ? data.notifyDaysBefore.value
          : this.notifyDaysBefore,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      isEstimate: data.isEstimate.present
          ? data.isEstimate.value
          : this.isEstimate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecurringRuleRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('amount: $amount, ')
          ..write('accountId: $accountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('payee: $payee, ')
          ..write('frequency: $frequency, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('nextDueDate: $nextDueDate, ')
          ..write('notifyDaysBefore: $notifyDaysBefore, ')
          ..write('isActive: $isActive, ')
          ..write('isEstimate: $isEstimate, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    amount,
    accountId,
    categoryId,
    payee,
    frequency,
    dayOfMonth,
    nextDueDate,
    notifyDaysBefore,
    isActive,
    isEstimate,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecurringRuleRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.amount == this.amount &&
          other.accountId == this.accountId &&
          other.categoryId == this.categoryId &&
          other.payee == this.payee &&
          other.frequency == this.frequency &&
          other.dayOfMonth == this.dayOfMonth &&
          other.nextDueDate == this.nextDueDate &&
          other.notifyDaysBefore == this.notifyDaysBefore &&
          other.isActive == this.isActive &&
          other.isEstimate == this.isEstimate &&
          other.createdAt == this.createdAt);
}

class RecurringRulesCompanion extends UpdateCompanion<RecurringRuleRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<CategoryKind> kind;
  final Value<Money> amount;
  final Value<int> accountId;
  final Value<int> categoryId;
  final Value<String?> payee;
  final Value<RecurringFrequency> frequency;
  final Value<int?> dayOfMonth;
  final Value<DateTime> nextDueDate;
  final Value<int> notifyDaysBefore;
  final Value<bool> isActive;
  final Value<bool> isEstimate;
  final Value<DateTime> createdAt;
  const RecurringRulesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.amount = const Value.absent(),
    this.accountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.payee = const Value.absent(),
    this.frequency = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.nextDueDate = const Value.absent(),
    this.notifyDaysBefore = const Value.absent(),
    this.isActive = const Value.absent(),
    this.isEstimate = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  RecurringRulesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required CategoryKind kind,
    required Money amount,
    required int accountId,
    required int categoryId,
    this.payee = const Value.absent(),
    required RecurringFrequency frequency,
    this.dayOfMonth = const Value.absent(),
    required DateTime nextDueDate,
    this.notifyDaysBefore = const Value.absent(),
    this.isActive = const Value.absent(),
    this.isEstimate = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       kind = Value(kind),
       amount = Value(amount),
       accountId = Value(accountId),
       categoryId = Value(categoryId),
       frequency = Value(frequency),
       nextDueDate = Value(nextDueDate);
  static Insertable<RecurringRuleRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<int>? amount,
    Expression<int>? accountId,
    Expression<int>? categoryId,
    Expression<String>? payee,
    Expression<String>? frequency,
    Expression<int>? dayOfMonth,
    Expression<DateTime>? nextDueDate,
    Expression<int>? notifyDaysBefore,
    Expression<bool>? isActive,
    Expression<bool>? isEstimate,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (amount != null) 'amount': amount,
      if (accountId != null) 'account_id': accountId,
      if (categoryId != null) 'category_id': categoryId,
      if (payee != null) 'payee': payee,
      if (frequency != null) 'frequency': frequency,
      if (dayOfMonth != null) 'day_of_month': dayOfMonth,
      if (nextDueDate != null) 'next_due_date': nextDueDate,
      if (notifyDaysBefore != null) 'notify_days_before': notifyDaysBefore,
      if (isActive != null) 'is_active': isActive,
      if (isEstimate != null) 'is_estimate': isEstimate,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  RecurringRulesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<CategoryKind>? kind,
    Value<Money>? amount,
    Value<int>? accountId,
    Value<int>? categoryId,
    Value<String?>? payee,
    Value<RecurringFrequency>? frequency,
    Value<int?>? dayOfMonth,
    Value<DateTime>? nextDueDate,
    Value<int>? notifyDaysBefore,
    Value<bool>? isActive,
    Value<bool>? isEstimate,
    Value<DateTime>? createdAt,
  }) {
    return RecurringRulesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      amount: amount ?? this.amount,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      payee: payee ?? this.payee,
      frequency: frequency ?? this.frequency,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      notifyDaysBefore: notifyDaysBefore ?? this.notifyDaysBefore,
      isActive: isActive ?? this.isActive,
      isEstimate: isEstimate ?? this.isEstimate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $RecurringRulesTable.$converterkind.toSql(kind.value),
      );
    }
    if (amount.present) {
      map['amount'] = Variable<int>(
        $RecurringRulesTable.$converteramount.toSql(amount.value),
      );
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (payee.present) {
      map['payee'] = Variable<String>(payee.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<String>(
        $RecurringRulesTable.$converterfrequency.toSql(frequency.value),
      );
    }
    if (dayOfMonth.present) {
      map['day_of_month'] = Variable<int>(dayOfMonth.value);
    }
    if (nextDueDate.present) {
      map['next_due_date'] = Variable<DateTime>(nextDueDate.value);
    }
    if (notifyDaysBefore.present) {
      map['notify_days_before'] = Variable<int>(notifyDaysBefore.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (isEstimate.present) {
      map['is_estimate'] = Variable<bool>(isEstimate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecurringRulesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('amount: $amount, ')
          ..write('accountId: $accountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('payee: $payee, ')
          ..write('frequency: $frequency, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('nextDueDate: $nextDueDate, ')
          ..write('notifyDaysBefore: $notifyDaysBefore, ')
          ..write('isActive: $isActive, ')
          ..write('isEstimate: $isEstimate, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, TransactionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<TxType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TxType>($TransactionsTable.$convertertype);
  @override
  late final GeneratedColumnWithTypeConverter<Money, int> amount =
      GeneratedColumn<int>(
        'amount',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Money>($TransactionsTable.$converteramount);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _toAccountIdMeta = const VerificationMeta(
    'toAccountId',
  );
  @override
  late final GeneratedColumn<int> toAccountId = GeneratedColumn<int>(
    'to_account_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<int> personId = GeneratedColumn<int>(
    'person_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES persons (id)',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payeeMeta = const VerificationMeta('payee');
  @override
  late final GeneratedColumn<String> payee = GeneratedColumn<String>(
    'payee',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurringRuleIdMeta = const VerificationMeta(
    'recurringRuleId',
  );
  @override
  late final GeneratedColumn<int> recurringRuleId = GeneratedColumn<int>(
    'recurring_rule_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recurring_rules (id)',
    ),
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _needsAmountReviewMeta = const VerificationMeta(
    'needsAmountReview',
  );
  @override
  late final GeneratedColumn<bool> needsAmountReview = GeneratedColumn<bool>(
    'needs_amount_review',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_amount_review" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    amount,
    accountId,
    toAccountId,
    categoryId,
    personId,
    date,
    note,
    payee,
    recurringRuleId,
    imagePath,
    createdAt,
    updatedAt,
    needsAmountReview,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransactionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('to_account_id')) {
      context.handle(
        _toAccountIdMeta,
        toAccountId.isAcceptableOrUnknown(
          data['to_account_id']!,
          _toAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('payee')) {
      context.handle(
        _payeeMeta,
        payee.isAcceptableOrUnknown(data['payee']!, _payeeMeta),
      );
    }
    if (data.containsKey('recurring_rule_id')) {
      context.handle(
        _recurringRuleIdMeta,
        recurringRuleId.isAcceptableOrUnknown(
          data['recurring_rule_id']!,
          _recurringRuleIdMeta,
        ),
      );
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('needs_amount_review')) {
      context.handle(
        _needsAmountReviewMeta,
        needsAmountReview.isAcceptableOrUnknown(
          data['needs_amount_review']!,
          _needsAmountReviewMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: $TransactionsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      amount: $TransactionsTable.$converteramount.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}amount'],
        )!,
      ),
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
      toAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}to_account_id'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}person_id'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      payee: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee'],
      ),
      recurringRuleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recurring_rule_id'],
      ),
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      needsAmountReview: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_amount_review'],
      )!,
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TxType, String, String> $convertertype =
      const EnumNameConverter<TxType>(TxType.values);
  static TypeConverter<Money, int> $converteramount = const MoneyConverter();
}

class TransactionRow extends DataClass implements Insertable<TransactionRow> {
  final int id;
  final TxType type;

  /// Always **positive**. Direction is carried by [type], never by the sign.
  final Money amount;

  /// income → destination. expense → source. transfer → source.
  final int accountId;

  /// transfer only → destination.
  final int? toAccountId;

  /// income/expense only. Null for transfers and person movements, by definition.
  final int? categoryId;

  /// personOut / personIn only — who the money went to or came from.
  final int? personId;
  final DateTime date;
  final String? note;

  /// Expense only — who got paid. Free text (not a foreign key) so it never
  /// needs a management screen of its own; the Payees hub derives its list by
  /// grouping this column instead of owning a separate table.
  final String? payee;

  /// Set when [AppDatabase.runDueRecurringRules] auto-posted this row, so the
  /// Auto hub and the Transactions list can trace it back to its rule.
  final int? recurringRuleId;

  /// Absolute path to a receipt photo copied into the app's own documents
  /// directory (see `receipt_storage.dart`) — never a path the app doesn't
  /// own, so nothing depends on a picked file surviving where it was picked
  /// from. Null means no receipt attached.
  final String? imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Set when [AppDatabase.runDueRecurringRules] posts this from a rule whose
  /// [RecurringRules.isEstimate] is true — the amount is a placeholder, not
  /// what actually happened (e.g. a salary that varies month to month).
  /// Cleared the moment the user edits and saves the transaction, by which
  /// point they've either confirmed or corrected the real figure.
  final bool needsAmountReview;
  const TransactionRow({
    required this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    this.personId,
    required this.date,
    this.note,
    this.payee,
    this.recurringRuleId,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
    required this.needsAmountReview,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['type'] = Variable<String>(
        $TransactionsTable.$convertertype.toSql(type),
      );
    }
    {
      map['amount'] = Variable<int>(
        $TransactionsTable.$converteramount.toSql(amount),
      );
    }
    map['account_id'] = Variable<int>(accountId);
    if (!nullToAbsent || toAccountId != null) {
      map['to_account_id'] = Variable<int>(toAccountId);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    if (!nullToAbsent || personId != null) {
      map['person_id'] = Variable<int>(personId);
    }
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || payee != null) {
      map['payee'] = Variable<String>(payee);
    }
    if (!nullToAbsent || recurringRuleId != null) {
      map['recurring_rule_id'] = Variable<int>(recurringRuleId);
    }
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['needs_amount_review'] = Variable<bool>(needsAmountReview);
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      type: Value(type),
      amount: Value(amount),
      accountId: Value(accountId),
      toAccountId: toAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(toAccountId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      personId: personId == null && nullToAbsent
          ? const Value.absent()
          : Value(personId),
      date: Value(date),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      payee: payee == null && nullToAbsent
          ? const Value.absent()
          : Value(payee),
      recurringRuleId: recurringRuleId == null && nullToAbsent
          ? const Value.absent()
          : Value(recurringRuleId),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      needsAmountReview: Value(needsAmountReview),
    );
  }

  factory TransactionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionRow(
      id: serializer.fromJson<int>(json['id']),
      type: $TransactionsTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      amount: serializer.fromJson<Money>(json['amount']),
      accountId: serializer.fromJson<int>(json['accountId']),
      toAccountId: serializer.fromJson<int?>(json['toAccountId']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      personId: serializer.fromJson<int?>(json['personId']),
      date: serializer.fromJson<DateTime>(json['date']),
      note: serializer.fromJson<String?>(json['note']),
      payee: serializer.fromJson<String?>(json['payee']),
      recurringRuleId: serializer.fromJson<int?>(json['recurringRuleId']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      needsAmountReview: serializer.fromJson<bool>(json['needsAmountReview']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(
        $TransactionsTable.$convertertype.toJson(type),
      ),
      'amount': serializer.toJson<Money>(amount),
      'accountId': serializer.toJson<int>(accountId),
      'toAccountId': serializer.toJson<int?>(toAccountId),
      'categoryId': serializer.toJson<int?>(categoryId),
      'personId': serializer.toJson<int?>(personId),
      'date': serializer.toJson<DateTime>(date),
      'note': serializer.toJson<String?>(note),
      'payee': serializer.toJson<String?>(payee),
      'recurringRuleId': serializer.toJson<int?>(recurringRuleId),
      'imagePath': serializer.toJson<String?>(imagePath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'needsAmountReview': serializer.toJson<bool>(needsAmountReview),
    };
  }

  TransactionRow copyWith({
    int? id,
    TxType? type,
    Money? amount,
    int? accountId,
    Value<int?> toAccountId = const Value.absent(),
    Value<int?> categoryId = const Value.absent(),
    Value<int?> personId = const Value.absent(),
    DateTime? date,
    Value<String?> note = const Value.absent(),
    Value<String?> payee = const Value.absent(),
    Value<int?> recurringRuleId = const Value.absent(),
    Value<String?> imagePath = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? needsAmountReview,
  }) => TransactionRow(
    id: id ?? this.id,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    accountId: accountId ?? this.accountId,
    toAccountId: toAccountId.present ? toAccountId.value : this.toAccountId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    personId: personId.present ? personId.value : this.personId,
    date: date ?? this.date,
    note: note.present ? note.value : this.note,
    payee: payee.present ? payee.value : this.payee,
    recurringRuleId: recurringRuleId.present
        ? recurringRuleId.value
        : this.recurringRuleId,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    needsAmountReview: needsAmountReview ?? this.needsAmountReview,
  );
  TransactionRow copyWithCompanion(TransactionsCompanion data) {
    return TransactionRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      amount: data.amount.present ? data.amount.value : this.amount,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      toAccountId: data.toAccountId.present
          ? data.toAccountId.value
          : this.toAccountId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      personId: data.personId.present ? data.personId.value : this.personId,
      date: data.date.present ? data.date.value : this.date,
      note: data.note.present ? data.note.value : this.note,
      payee: data.payee.present ? data.payee.value : this.payee,
      recurringRuleId: data.recurringRuleId.present
          ? data.recurringRuleId.value
          : this.recurringRuleId,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      needsAmountReview: data.needsAmountReview.present
          ? data.needsAmountReview.value
          : this.needsAmountReview,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('personId: $personId, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('payee: $payee, ')
          ..write('recurringRuleId: $recurringRuleId, ')
          ..write('imagePath: $imagePath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('needsAmountReview: $needsAmountReview')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    amount,
    accountId,
    toAccountId,
    categoryId,
    personId,
    date,
    note,
    payee,
    recurringRuleId,
    imagePath,
    createdAt,
    updatedAt,
    needsAmountReview,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.amount == this.amount &&
          other.accountId == this.accountId &&
          other.toAccountId == this.toAccountId &&
          other.categoryId == this.categoryId &&
          other.personId == this.personId &&
          other.date == this.date &&
          other.note == this.note &&
          other.payee == this.payee &&
          other.recurringRuleId == this.recurringRuleId &&
          other.imagePath == this.imagePath &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.needsAmountReview == this.needsAmountReview);
}

class TransactionsCompanion extends UpdateCompanion<TransactionRow> {
  final Value<int> id;
  final Value<TxType> type;
  final Value<Money> amount;
  final Value<int> accountId;
  final Value<int?> toAccountId;
  final Value<int?> categoryId;
  final Value<int?> personId;
  final Value<DateTime> date;
  final Value<String?> note;
  final Value<String?> payee;
  final Value<int?> recurringRuleId;
  final Value<String?> imagePath;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> needsAmountReview;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.amount = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.personId = const Value.absent(),
    this.date = const Value.absent(),
    this.note = const Value.absent(),
    this.payee = const Value.absent(),
    this.recurringRuleId = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.needsAmountReview = const Value.absent(),
  });
  TransactionsCompanion.insert({
    this.id = const Value.absent(),
    required TxType type,
    required Money amount,
    required int accountId,
    this.toAccountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.personId = const Value.absent(),
    required DateTime date,
    this.note = const Value.absent(),
    this.payee = const Value.absent(),
    this.recurringRuleId = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.needsAmountReview = const Value.absent(),
  }) : type = Value(type),
       amount = Value(amount),
       accountId = Value(accountId),
       date = Value(date);
  static Insertable<TransactionRow> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<int>? amount,
    Expression<int>? accountId,
    Expression<int>? toAccountId,
    Expression<int>? categoryId,
    Expression<int>? personId,
    Expression<DateTime>? date,
    Expression<String>? note,
    Expression<String>? payee,
    Expression<int>? recurringRuleId,
    Expression<String>? imagePath,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? needsAmountReview,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (accountId != null) 'account_id': accountId,
      if (toAccountId != null) 'to_account_id': toAccountId,
      if (categoryId != null) 'category_id': categoryId,
      if (personId != null) 'person_id': personId,
      if (date != null) 'date': date,
      if (note != null) 'note': note,
      if (payee != null) 'payee': payee,
      if (recurringRuleId != null) 'recurring_rule_id': recurringRuleId,
      if (imagePath != null) 'image_path': imagePath,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (needsAmountReview != null) 'needs_amount_review': needsAmountReview,
    });
  }

  TransactionsCompanion copyWith({
    Value<int>? id,
    Value<TxType>? type,
    Value<Money>? amount,
    Value<int>? accountId,
    Value<int?>? toAccountId,
    Value<int?>? categoryId,
    Value<int?>? personId,
    Value<DateTime>? date,
    Value<String?>? note,
    Value<String?>? payee,
    Value<int?>? recurringRuleId,
    Value<String?>? imagePath,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? needsAmountReview,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      categoryId: categoryId ?? this.categoryId,
      personId: personId ?? this.personId,
      date: date ?? this.date,
      note: note ?? this.note,
      payee: payee ?? this.payee,
      recurringRuleId: recurringRuleId ?? this.recurringRuleId,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      needsAmountReview: needsAmountReview ?? this.needsAmountReview,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $TransactionsTable.$convertertype.toSql(type.value),
      );
    }
    if (amount.present) {
      map['amount'] = Variable<int>(
        $TransactionsTable.$converteramount.toSql(amount.value),
      );
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (toAccountId.present) {
      map['to_account_id'] = Variable<int>(toAccountId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<int>(personId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (payee.present) {
      map['payee'] = Variable<String>(payee.value);
    }
    if (recurringRuleId.present) {
      map['recurring_rule_id'] = Variable<int>(recurringRuleId.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (needsAmountReview.present) {
      map['needs_amount_review'] = Variable<bool>(needsAmountReview.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('personId: $personId, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('payee: $payee, ')
          ..write('recurringRuleId: $recurringRuleId, ')
          ..write('imagePath: $imagePath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('needsAmountReview: $needsAmountReview')
          ..write(')'))
        .toString();
  }
}

class $BudgetsTable extends Budgets with TableInfo<$BudgetsTable, BudgetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<Money, int> amount =
      GeneratedColumn<int>(
        'amount',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Money>($BudgetsTable.$converteramount);
  @override
  late final GeneratedColumnWithTypeConverter<BudgetPeriod, String> period =
      GeneratedColumn<String>(
        'period',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<BudgetPeriod>($BudgetsTable.$converterperiod);
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _alertThresholdPctMeta = const VerificationMeta(
    'alertThresholdPct',
  );
  @override
  late final GeneratedColumn<int> alertThresholdPct = GeneratedColumn<int>(
    'alert_threshold_pct',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(80),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    categoryId,
    amount,
    period,
    startDate,
    alertThresholdPct,
    isActive,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<BudgetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('alert_threshold_pct')) {
      context.handle(
        _alertThresholdPctMeta,
        alertThresholdPct.isAcceptableOrUnknown(
          data['alert_threshold_pct']!,
          _alertThresholdPctMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {categoryId},
  ];
  @override
  BudgetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BudgetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      )!,
      amount: $BudgetsTable.$converteramount.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}amount'],
        )!,
      ),
      period: $BudgetsTable.$converterperiod.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}period'],
        )!,
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      alertThresholdPct: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}alert_threshold_pct'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $BudgetsTable createAlias(String alias) {
    return $BudgetsTable(attachedDatabase, alias);
  }

  static TypeConverter<Money, int> $converteramount = const MoneyConverter();
  static JsonTypeConverter2<BudgetPeriod, String, String> $converterperiod =
      const EnumNameConverter<BudgetPeriod>(BudgetPeriod.values);
}

class BudgetRow extends DataClass implements Insertable<BudgetRow> {
  final int id;
  final int categoryId;
  final Money amount;
  final BudgetPeriod period;
  final DateTime startDate;
  final int alertThresholdPct;
  final bool isActive;

  /// Free-form context for this budget — why it's set the way it is, what
  /// it's meant to cover, a reminder for next month. Entirely optional.
  final String? note;
  const BudgetRow({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.period,
    required this.startDate,
    required this.alertThresholdPct,
    required this.isActive,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['category_id'] = Variable<int>(categoryId);
    {
      map['amount'] = Variable<int>(
        $BudgetsTable.$converteramount.toSql(amount),
      );
    }
    {
      map['period'] = Variable<String>(
        $BudgetsTable.$converterperiod.toSql(period),
      );
    }
    map['start_date'] = Variable<DateTime>(startDate);
    map['alert_threshold_pct'] = Variable<int>(alertThresholdPct);
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  BudgetsCompanion toCompanion(bool nullToAbsent) {
    return BudgetsCompanion(
      id: Value(id),
      categoryId: Value(categoryId),
      amount: Value(amount),
      period: Value(period),
      startDate: Value(startDate),
      alertThresholdPct: Value(alertThresholdPct),
      isActive: Value(isActive),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory BudgetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BudgetRow(
      id: serializer.fromJson<int>(json['id']),
      categoryId: serializer.fromJson<int>(json['categoryId']),
      amount: serializer.fromJson<Money>(json['amount']),
      period: $BudgetsTable.$converterperiod.fromJson(
        serializer.fromJson<String>(json['period']),
      ),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      alertThresholdPct: serializer.fromJson<int>(json['alertThresholdPct']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'categoryId': serializer.toJson<int>(categoryId),
      'amount': serializer.toJson<Money>(amount),
      'period': serializer.toJson<String>(
        $BudgetsTable.$converterperiod.toJson(period),
      ),
      'startDate': serializer.toJson<DateTime>(startDate),
      'alertThresholdPct': serializer.toJson<int>(alertThresholdPct),
      'isActive': serializer.toJson<bool>(isActive),
      'note': serializer.toJson<String?>(note),
    };
  }

  BudgetRow copyWith({
    int? id,
    int? categoryId,
    Money? amount,
    BudgetPeriod? period,
    DateTime? startDate,
    int? alertThresholdPct,
    bool? isActive,
    Value<String?> note = const Value.absent(),
  }) => BudgetRow(
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    amount: amount ?? this.amount,
    period: period ?? this.period,
    startDate: startDate ?? this.startDate,
    alertThresholdPct: alertThresholdPct ?? this.alertThresholdPct,
    isActive: isActive ?? this.isActive,
    note: note.present ? note.value : this.note,
  );
  BudgetRow copyWithCompanion(BudgetsCompanion data) {
    return BudgetRow(
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      amount: data.amount.present ? data.amount.value : this.amount,
      period: data.period.present ? data.period.value : this.period,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      alertThresholdPct: data.alertThresholdPct.present
          ? data.alertThresholdPct.value
          : this.alertThresholdPct,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BudgetRow(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('period: $period, ')
          ..write('startDate: $startDate, ')
          ..write('alertThresholdPct: $alertThresholdPct, ')
          ..write('isActive: $isActive, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    categoryId,
    amount,
    period,
    startDate,
    alertThresholdPct,
    isActive,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BudgetRow &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.amount == this.amount &&
          other.period == this.period &&
          other.startDate == this.startDate &&
          other.alertThresholdPct == this.alertThresholdPct &&
          other.isActive == this.isActive &&
          other.note == this.note);
}

class BudgetsCompanion extends UpdateCompanion<BudgetRow> {
  final Value<int> id;
  final Value<int> categoryId;
  final Value<Money> amount;
  final Value<BudgetPeriod> period;
  final Value<DateTime> startDate;
  final Value<int> alertThresholdPct;
  final Value<bool> isActive;
  final Value<String?> note;
  const BudgetsCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.amount = const Value.absent(),
    this.period = const Value.absent(),
    this.startDate = const Value.absent(),
    this.alertThresholdPct = const Value.absent(),
    this.isActive = const Value.absent(),
    this.note = const Value.absent(),
  });
  BudgetsCompanion.insert({
    this.id = const Value.absent(),
    required int categoryId,
    required Money amount,
    required BudgetPeriod period,
    required DateTime startDate,
    this.alertThresholdPct = const Value.absent(),
    this.isActive = const Value.absent(),
    this.note = const Value.absent(),
  }) : categoryId = Value(categoryId),
       amount = Value(amount),
       period = Value(period),
       startDate = Value(startDate);
  static Insertable<BudgetRow> custom({
    Expression<int>? id,
    Expression<int>? categoryId,
    Expression<int>? amount,
    Expression<String>? period,
    Expression<DateTime>? startDate,
    Expression<int>? alertThresholdPct,
    Expression<bool>? isActive,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (amount != null) 'amount': amount,
      if (period != null) 'period': period,
      if (startDate != null) 'start_date': startDate,
      if (alertThresholdPct != null) 'alert_threshold_pct': alertThresholdPct,
      if (isActive != null) 'is_active': isActive,
      if (note != null) 'note': note,
    });
  }

  BudgetsCompanion copyWith({
    Value<int>? id,
    Value<int>? categoryId,
    Value<Money>? amount,
    Value<BudgetPeriod>? period,
    Value<DateTime>? startDate,
    Value<int>? alertThresholdPct,
    Value<bool>? isActive,
    Value<String?>? note,
  }) {
    return BudgetsCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      alertThresholdPct: alertThresholdPct ?? this.alertThresholdPct,
      isActive: isActive ?? this.isActive,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(
        $BudgetsTable.$converteramount.toSql(amount.value),
      );
    }
    if (period.present) {
      map['period'] = Variable<String>(
        $BudgetsTable.$converterperiod.toSql(period.value),
      );
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (alertThresholdPct.present) {
      map['alert_threshold_pct'] = Variable<int>(alertThresholdPct.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetsCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('period: $period, ')
          ..write('startDate: $startDate, ')
          ..write('alertThresholdPct: $alertThresholdPct, ')
          ..write('isActive: $isActive, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $PersonEntriesTable extends PersonEntries
    with TableInfo<$PersonEntriesTable, PersonEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PersonEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<int> personId = GeneratedColumn<int>(
    'person_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES persons (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<PersonDirection, String>
  direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<PersonDirection>($PersonEntriesTable.$converterdirection);
  @override
  late final GeneratedColumnWithTypeConverter<Money, int> amount =
      GeneratedColumn<int>(
        'amount',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Money>($PersonEntriesTable.$converteramount);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
    'account_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
    'transaction_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transactions (id)',
    ),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    personId,
    direction,
    amount,
    date,
    dueDate,
    note,
    accountId,
    transactionId,
    categoryId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'person_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<PersonEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PersonEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PersonEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}person_id'],
      )!,
      direction: $PersonEntriesTable.$converterdirection.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}direction'],
        )!,
      ),
      amount: $PersonEntriesTable.$converteramount.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}amount'],
        )!,
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      ),
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transaction_id'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PersonEntriesTable createAlias(String alias) {
    return $PersonEntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PersonDirection, String, String>
  $converterdirection = const EnumNameConverter<PersonDirection>(
    PersonDirection.values,
  );
  static TypeConverter<Money, int> $converteramount = const MoneyConverter();
}

class PersonEntryRow extends DataClass implements Insertable<PersonEntryRow> {
  final int id;
  final int personId;
  final PersonDirection direction;
  final Money amount;
  final DateTime date;
  final DateTime? dueDate;
  final String? note;

  /// Optional: the account real money moved through.
  final int? accountId;

  /// Set when [accountId] is set — the ledger row that moved the money.
  final int? transactionId;

  /// Set only on a **repayment** — an [PersonDirection.iOwe] entry the user
  /// chose to count as income (see [Settings.countRepaymentsAsIncome]).
  /// When set, [transactionId] points at a real [TxType.income] row instead
  /// of the usual [TxType.personIn], so it counts in every income total the
  /// ordinary way. Null for every other entry — lending and borrowing are
  /// never income or expense.
  final int? categoryId;
  final DateTime createdAt;
  const PersonEntryRow({
    required this.id,
    required this.personId,
    required this.direction,
    required this.amount,
    required this.date,
    this.dueDate,
    this.note,
    this.accountId,
    this.transactionId,
    this.categoryId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['person_id'] = Variable<int>(personId);
    {
      map['direction'] = Variable<String>(
        $PersonEntriesTable.$converterdirection.toSql(direction),
      );
    }
    {
      map['amount'] = Variable<int>(
        $PersonEntriesTable.$converteramount.toSql(amount),
      );
    }
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<int>(accountId);
    }
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<int>(transactionId);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PersonEntriesCompanion toCompanion(bool nullToAbsent) {
    return PersonEntriesCompanion(
      id: Value(id),
      personId: Value(personId),
      direction: Value(direction),
      amount: Value(amount),
      date: Value(date),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      createdAt: Value(createdAt),
    );
  }

  factory PersonEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PersonEntryRow(
      id: serializer.fromJson<int>(json['id']),
      personId: serializer.fromJson<int>(json['personId']),
      direction: $PersonEntriesTable.$converterdirection.fromJson(
        serializer.fromJson<String>(json['direction']),
      ),
      amount: serializer.fromJson<Money>(json['amount']),
      date: serializer.fromJson<DateTime>(json['date']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      note: serializer.fromJson<String?>(json['note']),
      accountId: serializer.fromJson<int?>(json['accountId']),
      transactionId: serializer.fromJson<int?>(json['transactionId']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'personId': serializer.toJson<int>(personId),
      'direction': serializer.toJson<String>(
        $PersonEntriesTable.$converterdirection.toJson(direction),
      ),
      'amount': serializer.toJson<Money>(amount),
      'date': serializer.toJson<DateTime>(date),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'note': serializer.toJson<String?>(note),
      'accountId': serializer.toJson<int?>(accountId),
      'transactionId': serializer.toJson<int?>(transactionId),
      'categoryId': serializer.toJson<int?>(categoryId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PersonEntryRow copyWith({
    int? id,
    int? personId,
    PersonDirection? direction,
    Money? amount,
    DateTime? date,
    Value<DateTime?> dueDate = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<int?> accountId = const Value.absent(),
    Value<int?> transactionId = const Value.absent(),
    Value<int?> categoryId = const Value.absent(),
    DateTime? createdAt,
  }) => PersonEntryRow(
    id: id ?? this.id,
    personId: personId ?? this.personId,
    direction: direction ?? this.direction,
    amount: amount ?? this.amount,
    date: date ?? this.date,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    note: note.present ? note.value : this.note,
    accountId: accountId.present ? accountId.value : this.accountId,
    transactionId: transactionId.present
        ? transactionId.value
        : this.transactionId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    createdAt: createdAt ?? this.createdAt,
  );
  PersonEntryRow copyWithCompanion(PersonEntriesCompanion data) {
    return PersonEntryRow(
      id: data.id.present ? data.id.value : this.id,
      personId: data.personId.present ? data.personId.value : this.personId,
      direction: data.direction.present ? data.direction.value : this.direction,
      amount: data.amount.present ? data.amount.value : this.amount,
      date: data.date.present ? data.date.value : this.date,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      note: data.note.present ? data.note.value : this.note,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PersonEntryRow(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('direction: $direction, ')
          ..write('amount: $amount, ')
          ..write('date: $date, ')
          ..write('dueDate: $dueDate, ')
          ..write('note: $note, ')
          ..write('accountId: $accountId, ')
          ..write('transactionId: $transactionId, ')
          ..write('categoryId: $categoryId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    personId,
    direction,
    amount,
    date,
    dueDate,
    note,
    accountId,
    transactionId,
    categoryId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersonEntryRow &&
          other.id == this.id &&
          other.personId == this.personId &&
          other.direction == this.direction &&
          other.amount == this.amount &&
          other.date == this.date &&
          other.dueDate == this.dueDate &&
          other.note == this.note &&
          other.accountId == this.accountId &&
          other.transactionId == this.transactionId &&
          other.categoryId == this.categoryId &&
          other.createdAt == this.createdAt);
}

class PersonEntriesCompanion extends UpdateCompanion<PersonEntryRow> {
  final Value<int> id;
  final Value<int> personId;
  final Value<PersonDirection> direction;
  final Value<Money> amount;
  final Value<DateTime> date;
  final Value<DateTime?> dueDate;
  final Value<String?> note;
  final Value<int?> accountId;
  final Value<int?> transactionId;
  final Value<int?> categoryId;
  final Value<DateTime> createdAt;
  const PersonEntriesCompanion({
    this.id = const Value.absent(),
    this.personId = const Value.absent(),
    this.direction = const Value.absent(),
    this.amount = const Value.absent(),
    this.date = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.note = const Value.absent(),
    this.accountId = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PersonEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int personId,
    required PersonDirection direction,
    required Money amount,
    required DateTime date,
    this.dueDate = const Value.absent(),
    this.note = const Value.absent(),
    this.accountId = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : personId = Value(personId),
       direction = Value(direction),
       amount = Value(amount),
       date = Value(date);
  static Insertable<PersonEntryRow> custom({
    Expression<int>? id,
    Expression<int>? personId,
    Expression<String>? direction,
    Expression<int>? amount,
    Expression<DateTime>? date,
    Expression<DateTime>? dueDate,
    Expression<String>? note,
    Expression<int>? accountId,
    Expression<int>? transactionId,
    Expression<int>? categoryId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (personId != null) 'person_id': personId,
      if (direction != null) 'direction': direction,
      if (amount != null) 'amount': amount,
      if (date != null) 'date': date,
      if (dueDate != null) 'due_date': dueDate,
      if (note != null) 'note': note,
      if (accountId != null) 'account_id': accountId,
      if (transactionId != null) 'transaction_id': transactionId,
      if (categoryId != null) 'category_id': categoryId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PersonEntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? personId,
    Value<PersonDirection>? direction,
    Value<Money>? amount,
    Value<DateTime>? date,
    Value<DateTime?>? dueDate,
    Value<String?>? note,
    Value<int?>? accountId,
    Value<int?>? transactionId,
    Value<int?>? categoryId,
    Value<DateTime>? createdAt,
  }) {
    return PersonEntriesCompanion(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      direction: direction ?? this.direction,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      note: note ?? this.note,
      accountId: accountId ?? this.accountId,
      transactionId: transactionId ?? this.transactionId,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<int>(personId.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(
        $PersonEntriesTable.$converterdirection.toSql(direction.value),
      );
    }
    if (amount.present) {
      map['amount'] = Variable<int>(
        $PersonEntriesTable.$converteramount.toSql(amount.value),
      );
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PersonEntriesCompanion(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('direction: $direction, ')
          ..write('amount: $amount, ')
          ..write('date: $date, ')
          ..write('dueDate: $dueDate, ')
          ..write('note: $note, ')
          ..write('accountId: $accountId, ')
          ..write('transactionId: $transactionId, ')
          ..write('categoryId: $categoryId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, ReminderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Money?, int> amount =
      GeneratedColumn<int>(
        'amount',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<Money?>($RemindersTable.$converteramountn);
  @override
  late final GeneratedColumnWithTypeConverter<ReminderDirection, String>
  direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<ReminderDirection>($RemindersTable.$converterdirection);
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
    'account_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<int> personId = GeneratedColumn<int>(
    'person_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES persons (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ReminderRepeat, String> repeat =
      GeneratedColumn<String>(
        'repeat',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('none'),
      ).withConverter<ReminderRepeat>($RemindersTable.$converterrepeat);
  static const VerificationMeta _notifyDaysBeforeMeta = const VerificationMeta(
    'notifyDaysBefore',
  );
  @override
  late final GeneratedColumn<int> notifyDaysBefore = GeneratedColumn<int>(
    'notify_days_before',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ReminderStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('open'),
      ).withConverter<ReminderStatus>($RemindersTable.$converterstatus);
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
    'transaction_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transactions (id)',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    amount,
    direction,
    dueDate,
    accountId,
    categoryId,
    personId,
    repeat,
    notifyDaysBefore,
    status,
    transactionId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReminderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    } else if (isInserting) {
      context.missing(_dueDateMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    }
    if (data.containsKey('notify_days_before')) {
      context.handle(
        _notifyDaysBeforeMeta,
        notifyDaysBefore.isAcceptableOrUnknown(
          data['notify_days_before']!,
          _notifyDaysBeforeMeta,
        ),
      );
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReminderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      amount: $RemindersTable.$converteramountn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}amount'],
        ),
      ),
      direction: $RemindersTable.$converterdirection.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}direction'],
        )!,
      ),
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}person_id'],
      ),
      repeat: $RemindersTable.$converterrepeat.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}repeat'],
        )!,
      ),
      notifyDaysBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notify_days_before'],
      )!,
      status: $RemindersTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transaction_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }

  static TypeConverter<Money, int> $converteramount = const MoneyConverter();
  static TypeConverter<Money?, int?> $converteramountn =
      NullAwareTypeConverter.wrap($converteramount);
  static JsonTypeConverter2<ReminderDirection, String, String>
  $converterdirection = const EnumNameConverter<ReminderDirection>(
    ReminderDirection.values,
  );
  static JsonTypeConverter2<ReminderRepeat, String, String> $converterrepeat =
      const EnumNameConverter<ReminderRepeat>(ReminderRepeat.values);
  static JsonTypeConverter2<ReminderStatus, String, String> $converterstatus =
      const EnumNameConverter<ReminderStatus>(ReminderStatus.values);
}

class ReminderRow extends DataClass implements Insertable<ReminderRow> {
  final int id;
  final String title;
  final Money? amount;
  final ReminderDirection direction;
  final DateTime dueDate;
  final int? accountId;
  final int? categoryId;
  final int? personId;
  final ReminderRepeat repeat;
  final int notifyDaysBefore;
  final ReminderStatus status;

  /// Set once "Mark as paid" posts the real transaction.
  final int? transactionId;
  final DateTime createdAt;
  const ReminderRow({
    required this.id,
    required this.title,
    this.amount,
    required this.direction,
    required this.dueDate,
    this.accountId,
    this.categoryId,
    this.personId,
    required this.repeat,
    required this.notifyDaysBefore,
    required this.status,
    this.transactionId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || amount != null) {
      map['amount'] = Variable<int>(
        $RemindersTable.$converteramountn.toSql(amount),
      );
    }
    {
      map['direction'] = Variable<String>(
        $RemindersTable.$converterdirection.toSql(direction),
      );
    }
    map['due_date'] = Variable<DateTime>(dueDate);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<int>(accountId);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    if (!nullToAbsent || personId != null) {
      map['person_id'] = Variable<int>(personId);
    }
    {
      map['repeat'] = Variable<String>(
        $RemindersTable.$converterrepeat.toSql(repeat),
      );
    }
    map['notify_days_before'] = Variable<int>(notifyDaysBefore);
    {
      map['status'] = Variable<String>(
        $RemindersTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<int>(transactionId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      id: Value(id),
      title: Value(title),
      amount: amount == null && nullToAbsent
          ? const Value.absent()
          : Value(amount),
      direction: Value(direction),
      dueDate: Value(dueDate),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      personId: personId == null && nullToAbsent
          ? const Value.absent()
          : Value(personId),
      repeat: Value(repeat),
      notifyDaysBefore: Value(notifyDaysBefore),
      status: Value(status),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
      createdAt: Value(createdAt),
    );
  }

  factory ReminderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderRow(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      amount: serializer.fromJson<Money?>(json['amount']),
      direction: $RemindersTable.$converterdirection.fromJson(
        serializer.fromJson<String>(json['direction']),
      ),
      dueDate: serializer.fromJson<DateTime>(json['dueDate']),
      accountId: serializer.fromJson<int?>(json['accountId']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      personId: serializer.fromJson<int?>(json['personId']),
      repeat: $RemindersTable.$converterrepeat.fromJson(
        serializer.fromJson<String>(json['repeat']),
      ),
      notifyDaysBefore: serializer.fromJson<int>(json['notifyDaysBefore']),
      status: $RemindersTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      transactionId: serializer.fromJson<int?>(json['transactionId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'amount': serializer.toJson<Money?>(amount),
      'direction': serializer.toJson<String>(
        $RemindersTable.$converterdirection.toJson(direction),
      ),
      'dueDate': serializer.toJson<DateTime>(dueDate),
      'accountId': serializer.toJson<int?>(accountId),
      'categoryId': serializer.toJson<int?>(categoryId),
      'personId': serializer.toJson<int?>(personId),
      'repeat': serializer.toJson<String>(
        $RemindersTable.$converterrepeat.toJson(repeat),
      ),
      'notifyDaysBefore': serializer.toJson<int>(notifyDaysBefore),
      'status': serializer.toJson<String>(
        $RemindersTable.$converterstatus.toJson(status),
      ),
      'transactionId': serializer.toJson<int?>(transactionId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ReminderRow copyWith({
    int? id,
    String? title,
    Value<Money?> amount = const Value.absent(),
    ReminderDirection? direction,
    DateTime? dueDate,
    Value<int?> accountId = const Value.absent(),
    Value<int?> categoryId = const Value.absent(),
    Value<int?> personId = const Value.absent(),
    ReminderRepeat? repeat,
    int? notifyDaysBefore,
    ReminderStatus? status,
    Value<int?> transactionId = const Value.absent(),
    DateTime? createdAt,
  }) => ReminderRow(
    id: id ?? this.id,
    title: title ?? this.title,
    amount: amount.present ? amount.value : this.amount,
    direction: direction ?? this.direction,
    dueDate: dueDate ?? this.dueDate,
    accountId: accountId.present ? accountId.value : this.accountId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    personId: personId.present ? personId.value : this.personId,
    repeat: repeat ?? this.repeat,
    notifyDaysBefore: notifyDaysBefore ?? this.notifyDaysBefore,
    status: status ?? this.status,
    transactionId: transactionId.present
        ? transactionId.value
        : this.transactionId,
    createdAt: createdAt ?? this.createdAt,
  );
  ReminderRow copyWithCompanion(RemindersCompanion data) {
    return ReminderRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      amount: data.amount.present ? data.amount.value : this.amount,
      direction: data.direction.present ? data.direction.value : this.direction,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      personId: data.personId.present ? data.personId.value : this.personId,
      repeat: data.repeat.present ? data.repeat.value : this.repeat,
      notifyDaysBefore: data.notifyDaysBefore.present
          ? data.notifyDaysBefore.value
          : this.notifyDaysBefore,
      status: data.status.present ? data.status.value : this.status,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('amount: $amount, ')
          ..write('direction: $direction, ')
          ..write('dueDate: $dueDate, ')
          ..write('accountId: $accountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('personId: $personId, ')
          ..write('repeat: $repeat, ')
          ..write('notifyDaysBefore: $notifyDaysBefore, ')
          ..write('status: $status, ')
          ..write('transactionId: $transactionId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    amount,
    direction,
    dueDate,
    accountId,
    categoryId,
    personId,
    repeat,
    notifyDaysBefore,
    status,
    transactionId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.amount == this.amount &&
          other.direction == this.direction &&
          other.dueDate == this.dueDate &&
          other.accountId == this.accountId &&
          other.categoryId == this.categoryId &&
          other.personId == this.personId &&
          other.repeat == this.repeat &&
          other.notifyDaysBefore == this.notifyDaysBefore &&
          other.status == this.status &&
          other.transactionId == this.transactionId &&
          other.createdAt == this.createdAt);
}

class RemindersCompanion extends UpdateCompanion<ReminderRow> {
  final Value<int> id;
  final Value<String> title;
  final Value<Money?> amount;
  final Value<ReminderDirection> direction;
  final Value<DateTime> dueDate;
  final Value<int?> accountId;
  final Value<int?> categoryId;
  final Value<int?> personId;
  final Value<ReminderRepeat> repeat;
  final Value<int> notifyDaysBefore;
  final Value<ReminderStatus> status;
  final Value<int?> transactionId;
  final Value<DateTime> createdAt;
  const RemindersCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.amount = const Value.absent(),
    this.direction = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.accountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.personId = const Value.absent(),
    this.repeat = const Value.absent(),
    this.notifyDaysBefore = const Value.absent(),
    this.status = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  RemindersCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.amount = const Value.absent(),
    required ReminderDirection direction,
    required DateTime dueDate,
    this.accountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.personId = const Value.absent(),
    this.repeat = const Value.absent(),
    this.notifyDaysBefore = const Value.absent(),
    this.status = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : title = Value(title),
       direction = Value(direction),
       dueDate = Value(dueDate);
  static Insertable<ReminderRow> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<int>? amount,
    Expression<String>? direction,
    Expression<DateTime>? dueDate,
    Expression<int>? accountId,
    Expression<int>? categoryId,
    Expression<int>? personId,
    Expression<String>? repeat,
    Expression<int>? notifyDaysBefore,
    Expression<String>? status,
    Expression<int>? transactionId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (amount != null) 'amount': amount,
      if (direction != null) 'direction': direction,
      if (dueDate != null) 'due_date': dueDate,
      if (accountId != null) 'account_id': accountId,
      if (categoryId != null) 'category_id': categoryId,
      if (personId != null) 'person_id': personId,
      if (repeat != null) 'repeat': repeat,
      if (notifyDaysBefore != null) 'notify_days_before': notifyDaysBefore,
      if (status != null) 'status': status,
      if (transactionId != null) 'transaction_id': transactionId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  RemindersCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<Money?>? amount,
    Value<ReminderDirection>? direction,
    Value<DateTime>? dueDate,
    Value<int?>? accountId,
    Value<int?>? categoryId,
    Value<int?>? personId,
    Value<ReminderRepeat>? repeat,
    Value<int>? notifyDaysBefore,
    Value<ReminderStatus>? status,
    Value<int?>? transactionId,
    Value<DateTime>? createdAt,
  }) {
    return RemindersCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      direction: direction ?? this.direction,
      dueDate: dueDate ?? this.dueDate,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      personId: personId ?? this.personId,
      repeat: repeat ?? this.repeat,
      notifyDaysBefore: notifyDaysBefore ?? this.notifyDaysBefore,
      status: status ?? this.status,
      transactionId: transactionId ?? this.transactionId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(
        $RemindersTable.$converteramountn.toSql(amount.value),
      );
    }
    if (direction.present) {
      map['direction'] = Variable<String>(
        $RemindersTable.$converterdirection.toSql(direction.value),
      );
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<int>(personId.value);
    }
    if (repeat.present) {
      map['repeat'] = Variable<String>(
        $RemindersTable.$converterrepeat.toSql(repeat.value),
      );
    }
    if (notifyDaysBefore.present) {
      map['notify_days_before'] = Variable<int>(notifyDaysBefore.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $RemindersTable.$converterstatus.toSql(status.value),
      );
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('amount: $amount, ')
          ..write('direction: $direction, ')
          ..write('dueDate: $dueDate, ')
          ..write('accountId: $accountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('personId: $personId, ')
          ..write('repeat: $repeat, ')
          ..write('notifyDaysBefore: $notifyDaysBefore, ')
          ..write('status: $status, ')
          ..write('transactionId: $transactionId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('INR'),
  );
  static const VerificationMeta _budgetStartDayMeta = const VerificationMeta(
    'budgetStartDay',
  );
  @override
  late final GeneratedColumn<int> budgetStartDay = GeneratedColumn<int>(
    'budget_start_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _onboardedMeta = const VerificationMeta(
    'onboarded',
  );
  @override
  late final GeneratedColumn<bool> onboarded = GeneratedColumn<bool>(
    'onboarded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("onboarded" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _autoApproveMeta = const VerificationMeta(
    'autoApprove',
  );
  @override
  late final GeneratedColumn<bool> autoApprove = GeneratedColumn<bool>(
    'auto_approve',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_approve" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _messageCaptureEnabledMeta =
      const VerificationMeta('messageCaptureEnabled');
  @override
  late final GeneratedColumn<bool> messageCaptureEnabled =
      GeneratedColumn<bool>(
        'message_capture_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("message_capture_enabled" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _lastMessageScanAtMeta = const VerificationMeta(
    'lastMessageScanAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastMessageScanAt =
      GeneratedColumn<DateTime>(
        'last_message_scan_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _notificationsEnabledMeta =
      const VerificationMeta('notificationsEnabled');
  @override
  late final GeneratedColumn<bool> notificationsEnabled = GeneratedColumn<bool>(
    'notifications_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notifications_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _themeNameMeta = const VerificationMeta(
    'themeName',
  );
  @override
  late final GeneratedColumn<String> themeName = GeneratedColumn<String>(
    'theme_name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 30,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('system'),
  );
  static const VerificationMeta _showCurrencySymbolMeta =
      const VerificationMeta('showCurrencySymbol');
  @override
  late final GeneratedColumn<bool> showCurrencySymbol = GeneratedColumn<bool>(
    'show_currency_symbol',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_currency_symbol" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _countRepaymentsAsIncomeMeta =
      const VerificationMeta('countRepaymentsAsIncome');
  @override
  late final GeneratedColumn<bool> countRepaymentsAsIncome =
      GeneratedColumn<bool>(
        'count_repayments_as_income',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("count_repayments_as_income" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _passcodeHashMeta = const VerificationMeta(
    'passcodeHash',
  );
  @override
  late final GeneratedColumn<String> passcodeHash = GeneratedColumn<String>(
    'passcode_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _passcodeSaltMeta = const VerificationMeta(
    'passcodeSalt',
  );
  @override
  late final GeneratedColumn<String> passcodeSalt = GeneratedColumn<String>(
    'passcode_salt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _biometricEnabledMeta = const VerificationMeta(
    'biometricEnabled',
  );
  @override
  late final GeneratedColumn<bool> biometricEnabled = GeneratedColumn<bool>(
    'biometric_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("biometric_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _expenseReminderEnabledMeta =
      const VerificationMeta('expenseReminderEnabled');
  @override
  late final GeneratedColumn<bool> expenseReminderEnabled =
      GeneratedColumn<bool>(
        'expense_reminder_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("expense_reminder_enabled" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _expenseReminderHourMeta =
      const VerificationMeta('expenseReminderHour');
  @override
  late final GeneratedColumn<int> expenseReminderHour = GeneratedColumn<int>(
    'expense_reminder_hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(20),
  );
  static const VerificationMeta _expenseReminderMinuteMeta =
      const VerificationMeta('expenseReminderMinute');
  @override
  late final GeneratedColumn<int> expenseReminderMinute = GeneratedColumn<int>(
    'expense_reminder_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _autoBackupEnabledMeta = const VerificationMeta(
    'autoBackupEnabled',
  );
  @override
  late final GeneratedColumn<bool> autoBackupEnabled = GeneratedColumn<bool>(
    'auto_backup_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_backup_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<AutoBackupFrequency, String>
  autoBackupFrequency =
      GeneratedColumn<String>(
        'auto_backup_frequency',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('daily'),
      ).withConverter<AutoBackupFrequency>(
        $SettingsTable.$converterautoBackupFrequency,
      );
  static const VerificationMeta _autoBackupCustomDaysMeta =
      const VerificationMeta('autoBackupCustomDays');
  @override
  late final GeneratedColumn<int> autoBackupCustomDays = GeneratedColumn<int>(
    'auto_backup_custom_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _autoBackupCustomHoursMeta =
      const VerificationMeta('autoBackupCustomHours');
  @override
  late final GeneratedColumn<int> autoBackupCustomHours = GeneratedColumn<int>(
    'auto_backup_custom_hours',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAutoBackupAtMeta = const VerificationMeta(
    'lastAutoBackupAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAutoBackupAt =
      GeneratedColumn<DateTime>(
        'last_auto_backup_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _backupRetentionDaysMeta =
      const VerificationMeta('backupRetentionDays');
  @override
  late final GeneratedColumn<int> backupRetentionDays = GeneratedColumn<int>(
    'backup_retention_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(180),
  );
  static const VerificationMeta _preventScreenshotsMeta =
      const VerificationMeta('preventScreenshots');
  @override
  late final GeneratedColumn<bool> preventScreenshots = GeneratedColumn<bool>(
    'prevent_screenshots',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("prevent_screenshots" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    currencyCode,
    budgetStartDay,
    onboarded,
    autoApprove,
    messageCaptureEnabled,
    lastMessageScanAt,
    notificationsEnabled,
    themeName,
    showCurrencySymbol,
    countRepaymentsAsIncome,
    passcodeHash,
    passcodeSalt,
    biometricEnabled,
    expenseReminderEnabled,
    expenseReminderHour,
    expenseReminderMinute,
    autoBackupEnabled,
    autoBackupFrequency,
    autoBackupCustomDays,
    autoBackupCustomHours,
    lastAutoBackupAt,
    backupRetentionDays,
    preventScreenshots,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    }
    if (data.containsKey('budget_start_day')) {
      context.handle(
        _budgetStartDayMeta,
        budgetStartDay.isAcceptableOrUnknown(
          data['budget_start_day']!,
          _budgetStartDayMeta,
        ),
      );
    }
    if (data.containsKey('onboarded')) {
      context.handle(
        _onboardedMeta,
        onboarded.isAcceptableOrUnknown(data['onboarded']!, _onboardedMeta),
      );
    }
    if (data.containsKey('auto_approve')) {
      context.handle(
        _autoApproveMeta,
        autoApprove.isAcceptableOrUnknown(
          data['auto_approve']!,
          _autoApproveMeta,
        ),
      );
    }
    if (data.containsKey('message_capture_enabled')) {
      context.handle(
        _messageCaptureEnabledMeta,
        messageCaptureEnabled.isAcceptableOrUnknown(
          data['message_capture_enabled']!,
          _messageCaptureEnabledMeta,
        ),
      );
    }
    if (data.containsKey('last_message_scan_at')) {
      context.handle(
        _lastMessageScanAtMeta,
        lastMessageScanAt.isAcceptableOrUnknown(
          data['last_message_scan_at']!,
          _lastMessageScanAtMeta,
        ),
      );
    }
    if (data.containsKey('notifications_enabled')) {
      context.handle(
        _notificationsEnabledMeta,
        notificationsEnabled.isAcceptableOrUnknown(
          data['notifications_enabled']!,
          _notificationsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('theme_name')) {
      context.handle(
        _themeNameMeta,
        themeName.isAcceptableOrUnknown(data['theme_name']!, _themeNameMeta),
      );
    }
    if (data.containsKey('show_currency_symbol')) {
      context.handle(
        _showCurrencySymbolMeta,
        showCurrencySymbol.isAcceptableOrUnknown(
          data['show_currency_symbol']!,
          _showCurrencySymbolMeta,
        ),
      );
    }
    if (data.containsKey('count_repayments_as_income')) {
      context.handle(
        _countRepaymentsAsIncomeMeta,
        countRepaymentsAsIncome.isAcceptableOrUnknown(
          data['count_repayments_as_income']!,
          _countRepaymentsAsIncomeMeta,
        ),
      );
    }
    if (data.containsKey('passcode_hash')) {
      context.handle(
        _passcodeHashMeta,
        passcodeHash.isAcceptableOrUnknown(
          data['passcode_hash']!,
          _passcodeHashMeta,
        ),
      );
    }
    if (data.containsKey('passcode_salt')) {
      context.handle(
        _passcodeSaltMeta,
        passcodeSalt.isAcceptableOrUnknown(
          data['passcode_salt']!,
          _passcodeSaltMeta,
        ),
      );
    }
    if (data.containsKey('biometric_enabled')) {
      context.handle(
        _biometricEnabledMeta,
        biometricEnabled.isAcceptableOrUnknown(
          data['biometric_enabled']!,
          _biometricEnabledMeta,
        ),
      );
    }
    if (data.containsKey('expense_reminder_enabled')) {
      context.handle(
        _expenseReminderEnabledMeta,
        expenseReminderEnabled.isAcceptableOrUnknown(
          data['expense_reminder_enabled']!,
          _expenseReminderEnabledMeta,
        ),
      );
    }
    if (data.containsKey('expense_reminder_hour')) {
      context.handle(
        _expenseReminderHourMeta,
        expenseReminderHour.isAcceptableOrUnknown(
          data['expense_reminder_hour']!,
          _expenseReminderHourMeta,
        ),
      );
    }
    if (data.containsKey('expense_reminder_minute')) {
      context.handle(
        _expenseReminderMinuteMeta,
        expenseReminderMinute.isAcceptableOrUnknown(
          data['expense_reminder_minute']!,
          _expenseReminderMinuteMeta,
        ),
      );
    }
    if (data.containsKey('auto_backup_enabled')) {
      context.handle(
        _autoBackupEnabledMeta,
        autoBackupEnabled.isAcceptableOrUnknown(
          data['auto_backup_enabled']!,
          _autoBackupEnabledMeta,
        ),
      );
    }
    if (data.containsKey('auto_backup_custom_days')) {
      context.handle(
        _autoBackupCustomDaysMeta,
        autoBackupCustomDays.isAcceptableOrUnknown(
          data['auto_backup_custom_days']!,
          _autoBackupCustomDaysMeta,
        ),
      );
    }
    if (data.containsKey('auto_backup_custom_hours')) {
      context.handle(
        _autoBackupCustomHoursMeta,
        autoBackupCustomHours.isAcceptableOrUnknown(
          data['auto_backup_custom_hours']!,
          _autoBackupCustomHoursMeta,
        ),
      );
    }
    if (data.containsKey('last_auto_backup_at')) {
      context.handle(
        _lastAutoBackupAtMeta,
        lastAutoBackupAt.isAcceptableOrUnknown(
          data['last_auto_backup_at']!,
          _lastAutoBackupAtMeta,
        ),
      );
    }
    if (data.containsKey('backup_retention_days')) {
      context.handle(
        _backupRetentionDaysMeta,
        backupRetentionDays.isAcceptableOrUnknown(
          data['backup_retention_days']!,
          _backupRetentionDaysMeta,
        ),
      );
    }
    if (data.containsKey('prevent_screenshots')) {
      context.handle(
        _preventScreenshotsMeta,
        preventScreenshots.isAcceptableOrUnknown(
          data['prevent_screenshots']!,
          _preventScreenshotsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      budgetStartDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}budget_start_day'],
      )!,
      onboarded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}onboarded'],
      )!,
      autoApprove: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_approve'],
      )!,
      messageCaptureEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}message_capture_enabled'],
      )!,
      lastMessageScanAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_message_scan_at'],
      ),
      notificationsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notifications_enabled'],
      )!,
      themeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_name'],
      )!,
      showCurrencySymbol: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_currency_symbol'],
      )!,
      countRepaymentsAsIncome: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}count_repayments_as_income'],
      )!,
      passcodeHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}passcode_hash'],
      ),
      passcodeSalt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}passcode_salt'],
      ),
      biometricEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}biometric_enabled'],
      )!,
      expenseReminderEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}expense_reminder_enabled'],
      )!,
      expenseReminderHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expense_reminder_hour'],
      )!,
      expenseReminderMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expense_reminder_minute'],
      )!,
      autoBackupEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_backup_enabled'],
      )!,
      autoBackupFrequency: $SettingsTable.$converterautoBackupFrequency.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}auto_backup_frequency'],
        )!,
      ),
      autoBackupCustomDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}auto_backup_custom_days'],
      )!,
      autoBackupCustomHours: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}auto_backup_custom_hours'],
      )!,
      lastAutoBackupAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_auto_backup_at'],
      ),
      backupRetentionDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}backup_retention_days'],
      )!,
      preventScreenshots: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}prevent_screenshots'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AutoBackupFrequency, String, String>
  $converterautoBackupFrequency = const EnumNameConverter<AutoBackupFrequency>(
    AutoBackupFrequency.values,
  );
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final int id;
  final String currencyCode;
  final int budgetStartDay;
  final bool onboarded;

  /// Auto-fill + post transactions from rules already learned. The card still
  /// shows, so the user always sees what was filled in for them.
  final bool autoApprove;
  final bool messageCaptureEnabled;

  /// Watermark for the "read SMS since last open" scan.
  final DateTime? lastMessageScanAt;
  final bool notificationsEnabled;

  /// A `ThemePreset.name`. Stored as text rather than an enum index, so
  /// reordering the enum can never silently repaint someone's app.
  final String themeName;

  /// When false, amounts render as bare numbers — the escape hatch for a
  /// currency whose symbol we don't carry. [currencyCode] still governs grouping
  /// and decimals.
  final bool showCurrencySymbol;

  /// When true, [PersonDetailScreen] offers "Mark as repaid" — a repayment
  /// entry that posts as real income (with a chosen category) instead of the
  /// usual [TxType.personIn], so it counts toward income totals and reports.
  /// Off by default: lending/borrowing stays out of income/expense unless
  /// asked for.
  final bool countRepaymentsAsIncome;

  /// A salted SHA-256 hash — never the passcode itself. Null means no
  /// passcode is set, the default, and the app never locks.
  final String? passcodeHash;
  final String? passcodeSalt;

  /// Only ever offered as a shortcut once [passcodeHash] is set — the PIN
  /// stays the fallback whenever biometrics fail or aren't enrolled.
  final bool biometricEnabled;

  /// A daily nudge — "log today's spending" — distinct from [Reminders],
  /// which are always for one specific planned payment.
  final bool expenseReminderEnabled;
  final int expenseReminderHour;
  final int expenseReminderMinute;

  /// Whether XPENC creates a backup on its own schedule, with no "Back up
  /// now" tap needed. Off by default.
  final bool autoBackupEnabled;

  /// How often, when [autoBackupEnabled]. `custom` uses
  /// [autoBackupCustomDays] + [autoBackupCustomHours] instead of a fixed
  /// cadence.
  final AutoBackupFrequency autoBackupFrequency;
  final int autoBackupCustomDays;
  final int autoBackupCustomHours;

  /// When the last *automatic* backup ran — the due-date anchor. A manual
  /// "Back up now" never touches this, so it can't push an automatic backup
  /// later than the schedule promises.
  final DateTime? lastAutoBackupAt;

  /// How many days a backup is kept before automatic cleanup removes it.
  /// `0` means "keep forever". Must be at least as long as the auto-backup
  /// interval (see `AppDatabase.setAutoBackupSettings`) — otherwise cleanup
  /// could delete a backup before the next one exists to replace it.
  final int backupRetentionDays;

  /// Blocks screenshots and hides XPENC from the recent-apps thumbnail —
  /// applied natively as `FLAG_SECURE` on the Android window (see
  /// `ScreenSecurity`). Off by default: it's a privacy trade-off (no
  /// screenshotting a statement to share it) the user opts into.
  final bool preventScreenshots;
  const SettingRow({
    required this.id,
    required this.currencyCode,
    required this.budgetStartDay,
    required this.onboarded,
    required this.autoApprove,
    required this.messageCaptureEnabled,
    this.lastMessageScanAt,
    required this.notificationsEnabled,
    required this.themeName,
    required this.showCurrencySymbol,
    required this.countRepaymentsAsIncome,
    this.passcodeHash,
    this.passcodeSalt,
    required this.biometricEnabled,
    required this.expenseReminderEnabled,
    required this.expenseReminderHour,
    required this.expenseReminderMinute,
    required this.autoBackupEnabled,
    required this.autoBackupFrequency,
    required this.autoBackupCustomDays,
    required this.autoBackupCustomHours,
    this.lastAutoBackupAt,
    required this.backupRetentionDays,
    required this.preventScreenshots,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['currency_code'] = Variable<String>(currencyCode);
    map['budget_start_day'] = Variable<int>(budgetStartDay);
    map['onboarded'] = Variable<bool>(onboarded);
    map['auto_approve'] = Variable<bool>(autoApprove);
    map['message_capture_enabled'] = Variable<bool>(messageCaptureEnabled);
    if (!nullToAbsent || lastMessageScanAt != null) {
      map['last_message_scan_at'] = Variable<DateTime>(lastMessageScanAt);
    }
    map['notifications_enabled'] = Variable<bool>(notificationsEnabled);
    map['theme_name'] = Variable<String>(themeName);
    map['show_currency_symbol'] = Variable<bool>(showCurrencySymbol);
    map['count_repayments_as_income'] = Variable<bool>(countRepaymentsAsIncome);
    if (!nullToAbsent || passcodeHash != null) {
      map['passcode_hash'] = Variable<String>(passcodeHash);
    }
    if (!nullToAbsent || passcodeSalt != null) {
      map['passcode_salt'] = Variable<String>(passcodeSalt);
    }
    map['biometric_enabled'] = Variable<bool>(biometricEnabled);
    map['expense_reminder_enabled'] = Variable<bool>(expenseReminderEnabled);
    map['expense_reminder_hour'] = Variable<int>(expenseReminderHour);
    map['expense_reminder_minute'] = Variable<int>(expenseReminderMinute);
    map['auto_backup_enabled'] = Variable<bool>(autoBackupEnabled);
    {
      map['auto_backup_frequency'] = Variable<String>(
        $SettingsTable.$converterautoBackupFrequency.toSql(autoBackupFrequency),
      );
    }
    map['auto_backup_custom_days'] = Variable<int>(autoBackupCustomDays);
    map['auto_backup_custom_hours'] = Variable<int>(autoBackupCustomHours);
    if (!nullToAbsent || lastAutoBackupAt != null) {
      map['last_auto_backup_at'] = Variable<DateTime>(lastAutoBackupAt);
    }
    map['backup_retention_days'] = Variable<int>(backupRetentionDays);
    map['prevent_screenshots'] = Variable<bool>(preventScreenshots);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      id: Value(id),
      currencyCode: Value(currencyCode),
      budgetStartDay: Value(budgetStartDay),
      onboarded: Value(onboarded),
      autoApprove: Value(autoApprove),
      messageCaptureEnabled: Value(messageCaptureEnabled),
      lastMessageScanAt: lastMessageScanAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageScanAt),
      notificationsEnabled: Value(notificationsEnabled),
      themeName: Value(themeName),
      showCurrencySymbol: Value(showCurrencySymbol),
      countRepaymentsAsIncome: Value(countRepaymentsAsIncome),
      passcodeHash: passcodeHash == null && nullToAbsent
          ? const Value.absent()
          : Value(passcodeHash),
      passcodeSalt: passcodeSalt == null && nullToAbsent
          ? const Value.absent()
          : Value(passcodeSalt),
      biometricEnabled: Value(biometricEnabled),
      expenseReminderEnabled: Value(expenseReminderEnabled),
      expenseReminderHour: Value(expenseReminderHour),
      expenseReminderMinute: Value(expenseReminderMinute),
      autoBackupEnabled: Value(autoBackupEnabled),
      autoBackupFrequency: Value(autoBackupFrequency),
      autoBackupCustomDays: Value(autoBackupCustomDays),
      autoBackupCustomHours: Value(autoBackupCustomHours),
      lastAutoBackupAt: lastAutoBackupAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAutoBackupAt),
      backupRetentionDays: Value(backupRetentionDays),
      preventScreenshots: Value(preventScreenshots),
    );
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      id: serializer.fromJson<int>(json['id']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      budgetStartDay: serializer.fromJson<int>(json['budgetStartDay']),
      onboarded: serializer.fromJson<bool>(json['onboarded']),
      autoApprove: serializer.fromJson<bool>(json['autoApprove']),
      messageCaptureEnabled: serializer.fromJson<bool>(
        json['messageCaptureEnabled'],
      ),
      lastMessageScanAt: serializer.fromJson<DateTime?>(
        json['lastMessageScanAt'],
      ),
      notificationsEnabled: serializer.fromJson<bool>(
        json['notificationsEnabled'],
      ),
      themeName: serializer.fromJson<String>(json['themeName']),
      showCurrencySymbol: serializer.fromJson<bool>(json['showCurrencySymbol']),
      countRepaymentsAsIncome: serializer.fromJson<bool>(
        json['countRepaymentsAsIncome'],
      ),
      passcodeHash: serializer.fromJson<String?>(json['passcodeHash']),
      passcodeSalt: serializer.fromJson<String?>(json['passcodeSalt']),
      biometricEnabled: serializer.fromJson<bool>(json['biometricEnabled']),
      expenseReminderEnabled: serializer.fromJson<bool>(
        json['expenseReminderEnabled'],
      ),
      expenseReminderHour: serializer.fromJson<int>(
        json['expenseReminderHour'],
      ),
      expenseReminderMinute: serializer.fromJson<int>(
        json['expenseReminderMinute'],
      ),
      autoBackupEnabled: serializer.fromJson<bool>(json['autoBackupEnabled']),
      autoBackupFrequency: $SettingsTable.$converterautoBackupFrequency
          .fromJson(serializer.fromJson<String>(json['autoBackupFrequency'])),
      autoBackupCustomDays: serializer.fromJson<int>(
        json['autoBackupCustomDays'],
      ),
      autoBackupCustomHours: serializer.fromJson<int>(
        json['autoBackupCustomHours'],
      ),
      lastAutoBackupAt: serializer.fromJson<DateTime?>(
        json['lastAutoBackupAt'],
      ),
      backupRetentionDays: serializer.fromJson<int>(
        json['backupRetentionDays'],
      ),
      preventScreenshots: serializer.fromJson<bool>(json['preventScreenshots']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'budgetStartDay': serializer.toJson<int>(budgetStartDay),
      'onboarded': serializer.toJson<bool>(onboarded),
      'autoApprove': serializer.toJson<bool>(autoApprove),
      'messageCaptureEnabled': serializer.toJson<bool>(messageCaptureEnabled),
      'lastMessageScanAt': serializer.toJson<DateTime?>(lastMessageScanAt),
      'notificationsEnabled': serializer.toJson<bool>(notificationsEnabled),
      'themeName': serializer.toJson<String>(themeName),
      'showCurrencySymbol': serializer.toJson<bool>(showCurrencySymbol),
      'countRepaymentsAsIncome': serializer.toJson<bool>(
        countRepaymentsAsIncome,
      ),
      'passcodeHash': serializer.toJson<String?>(passcodeHash),
      'passcodeSalt': serializer.toJson<String?>(passcodeSalt),
      'biometricEnabled': serializer.toJson<bool>(biometricEnabled),
      'expenseReminderEnabled': serializer.toJson<bool>(expenseReminderEnabled),
      'expenseReminderHour': serializer.toJson<int>(expenseReminderHour),
      'expenseReminderMinute': serializer.toJson<int>(expenseReminderMinute),
      'autoBackupEnabled': serializer.toJson<bool>(autoBackupEnabled),
      'autoBackupFrequency': serializer.toJson<String>(
        $SettingsTable.$converterautoBackupFrequency.toJson(
          autoBackupFrequency,
        ),
      ),
      'autoBackupCustomDays': serializer.toJson<int>(autoBackupCustomDays),
      'autoBackupCustomHours': serializer.toJson<int>(autoBackupCustomHours),
      'lastAutoBackupAt': serializer.toJson<DateTime?>(lastAutoBackupAt),
      'backupRetentionDays': serializer.toJson<int>(backupRetentionDays),
      'preventScreenshots': serializer.toJson<bool>(preventScreenshots),
    };
  }

  SettingRow copyWith({
    int? id,
    String? currencyCode,
    int? budgetStartDay,
    bool? onboarded,
    bool? autoApprove,
    bool? messageCaptureEnabled,
    Value<DateTime?> lastMessageScanAt = const Value.absent(),
    bool? notificationsEnabled,
    String? themeName,
    bool? showCurrencySymbol,
    bool? countRepaymentsAsIncome,
    Value<String?> passcodeHash = const Value.absent(),
    Value<String?> passcodeSalt = const Value.absent(),
    bool? biometricEnabled,
    bool? expenseReminderEnabled,
    int? expenseReminderHour,
    int? expenseReminderMinute,
    bool? autoBackupEnabled,
    AutoBackupFrequency? autoBackupFrequency,
    int? autoBackupCustomDays,
    int? autoBackupCustomHours,
    Value<DateTime?> lastAutoBackupAt = const Value.absent(),
    int? backupRetentionDays,
    bool? preventScreenshots,
  }) => SettingRow(
    id: id ?? this.id,
    currencyCode: currencyCode ?? this.currencyCode,
    budgetStartDay: budgetStartDay ?? this.budgetStartDay,
    onboarded: onboarded ?? this.onboarded,
    autoApprove: autoApprove ?? this.autoApprove,
    messageCaptureEnabled: messageCaptureEnabled ?? this.messageCaptureEnabled,
    lastMessageScanAt: lastMessageScanAt.present
        ? lastMessageScanAt.value
        : this.lastMessageScanAt,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    themeName: themeName ?? this.themeName,
    showCurrencySymbol: showCurrencySymbol ?? this.showCurrencySymbol,
    countRepaymentsAsIncome:
        countRepaymentsAsIncome ?? this.countRepaymentsAsIncome,
    passcodeHash: passcodeHash.present ? passcodeHash.value : this.passcodeHash,
    passcodeSalt: passcodeSalt.present ? passcodeSalt.value : this.passcodeSalt,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    expenseReminderEnabled:
        expenseReminderEnabled ?? this.expenseReminderEnabled,
    expenseReminderHour: expenseReminderHour ?? this.expenseReminderHour,
    expenseReminderMinute: expenseReminderMinute ?? this.expenseReminderMinute,
    autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
    autoBackupFrequency: autoBackupFrequency ?? this.autoBackupFrequency,
    autoBackupCustomDays: autoBackupCustomDays ?? this.autoBackupCustomDays,
    autoBackupCustomHours: autoBackupCustomHours ?? this.autoBackupCustomHours,
    lastAutoBackupAt: lastAutoBackupAt.present
        ? lastAutoBackupAt.value
        : this.lastAutoBackupAt,
    backupRetentionDays: backupRetentionDays ?? this.backupRetentionDays,
    preventScreenshots: preventScreenshots ?? this.preventScreenshots,
  );
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      id: data.id.present ? data.id.value : this.id,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      budgetStartDay: data.budgetStartDay.present
          ? data.budgetStartDay.value
          : this.budgetStartDay,
      onboarded: data.onboarded.present ? data.onboarded.value : this.onboarded,
      autoApprove: data.autoApprove.present
          ? data.autoApprove.value
          : this.autoApprove,
      messageCaptureEnabled: data.messageCaptureEnabled.present
          ? data.messageCaptureEnabled.value
          : this.messageCaptureEnabled,
      lastMessageScanAt: data.lastMessageScanAt.present
          ? data.lastMessageScanAt.value
          : this.lastMessageScanAt,
      notificationsEnabled: data.notificationsEnabled.present
          ? data.notificationsEnabled.value
          : this.notificationsEnabled,
      themeName: data.themeName.present ? data.themeName.value : this.themeName,
      showCurrencySymbol: data.showCurrencySymbol.present
          ? data.showCurrencySymbol.value
          : this.showCurrencySymbol,
      countRepaymentsAsIncome: data.countRepaymentsAsIncome.present
          ? data.countRepaymentsAsIncome.value
          : this.countRepaymentsAsIncome,
      passcodeHash: data.passcodeHash.present
          ? data.passcodeHash.value
          : this.passcodeHash,
      passcodeSalt: data.passcodeSalt.present
          ? data.passcodeSalt.value
          : this.passcodeSalt,
      biometricEnabled: data.biometricEnabled.present
          ? data.biometricEnabled.value
          : this.biometricEnabled,
      expenseReminderEnabled: data.expenseReminderEnabled.present
          ? data.expenseReminderEnabled.value
          : this.expenseReminderEnabled,
      expenseReminderHour: data.expenseReminderHour.present
          ? data.expenseReminderHour.value
          : this.expenseReminderHour,
      expenseReminderMinute: data.expenseReminderMinute.present
          ? data.expenseReminderMinute.value
          : this.expenseReminderMinute,
      autoBackupEnabled: data.autoBackupEnabled.present
          ? data.autoBackupEnabled.value
          : this.autoBackupEnabled,
      autoBackupFrequency: data.autoBackupFrequency.present
          ? data.autoBackupFrequency.value
          : this.autoBackupFrequency,
      autoBackupCustomDays: data.autoBackupCustomDays.present
          ? data.autoBackupCustomDays.value
          : this.autoBackupCustomDays,
      autoBackupCustomHours: data.autoBackupCustomHours.present
          ? data.autoBackupCustomHours.value
          : this.autoBackupCustomHours,
      lastAutoBackupAt: data.lastAutoBackupAt.present
          ? data.lastAutoBackupAt.value
          : this.lastAutoBackupAt,
      backupRetentionDays: data.backupRetentionDays.present
          ? data.backupRetentionDays.value
          : this.backupRetentionDays,
      preventScreenshots: data.preventScreenshots.present
          ? data.preventScreenshots.value
          : this.preventScreenshots,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('id: $id, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('budgetStartDay: $budgetStartDay, ')
          ..write('onboarded: $onboarded, ')
          ..write('autoApprove: $autoApprove, ')
          ..write('messageCaptureEnabled: $messageCaptureEnabled, ')
          ..write('lastMessageScanAt: $lastMessageScanAt, ')
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('themeName: $themeName, ')
          ..write('showCurrencySymbol: $showCurrencySymbol, ')
          ..write('countRepaymentsAsIncome: $countRepaymentsAsIncome, ')
          ..write('passcodeHash: $passcodeHash, ')
          ..write('passcodeSalt: $passcodeSalt, ')
          ..write('biometricEnabled: $biometricEnabled, ')
          ..write('expenseReminderEnabled: $expenseReminderEnabled, ')
          ..write('expenseReminderHour: $expenseReminderHour, ')
          ..write('expenseReminderMinute: $expenseReminderMinute, ')
          ..write('autoBackupEnabled: $autoBackupEnabled, ')
          ..write('autoBackupFrequency: $autoBackupFrequency, ')
          ..write('autoBackupCustomDays: $autoBackupCustomDays, ')
          ..write('autoBackupCustomHours: $autoBackupCustomHours, ')
          ..write('lastAutoBackupAt: $lastAutoBackupAt, ')
          ..write('backupRetentionDays: $backupRetentionDays, ')
          ..write('preventScreenshots: $preventScreenshots')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    currencyCode,
    budgetStartDay,
    onboarded,
    autoApprove,
    messageCaptureEnabled,
    lastMessageScanAt,
    notificationsEnabled,
    themeName,
    showCurrencySymbol,
    countRepaymentsAsIncome,
    passcodeHash,
    passcodeSalt,
    biometricEnabled,
    expenseReminderEnabled,
    expenseReminderHour,
    expenseReminderMinute,
    autoBackupEnabled,
    autoBackupFrequency,
    autoBackupCustomDays,
    autoBackupCustomHours,
    lastAutoBackupAt,
    backupRetentionDays,
    preventScreenshots,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.id == this.id &&
          other.currencyCode == this.currencyCode &&
          other.budgetStartDay == this.budgetStartDay &&
          other.onboarded == this.onboarded &&
          other.autoApprove == this.autoApprove &&
          other.messageCaptureEnabled == this.messageCaptureEnabled &&
          other.lastMessageScanAt == this.lastMessageScanAt &&
          other.notificationsEnabled == this.notificationsEnabled &&
          other.themeName == this.themeName &&
          other.showCurrencySymbol == this.showCurrencySymbol &&
          other.countRepaymentsAsIncome == this.countRepaymentsAsIncome &&
          other.passcodeHash == this.passcodeHash &&
          other.passcodeSalt == this.passcodeSalt &&
          other.biometricEnabled == this.biometricEnabled &&
          other.expenseReminderEnabled == this.expenseReminderEnabled &&
          other.expenseReminderHour == this.expenseReminderHour &&
          other.expenseReminderMinute == this.expenseReminderMinute &&
          other.autoBackupEnabled == this.autoBackupEnabled &&
          other.autoBackupFrequency == this.autoBackupFrequency &&
          other.autoBackupCustomDays == this.autoBackupCustomDays &&
          other.autoBackupCustomHours == this.autoBackupCustomHours &&
          other.lastAutoBackupAt == this.lastAutoBackupAt &&
          other.backupRetentionDays == this.backupRetentionDays &&
          other.preventScreenshots == this.preventScreenshots);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<int> id;
  final Value<String> currencyCode;
  final Value<int> budgetStartDay;
  final Value<bool> onboarded;
  final Value<bool> autoApprove;
  final Value<bool> messageCaptureEnabled;
  final Value<DateTime?> lastMessageScanAt;
  final Value<bool> notificationsEnabled;
  final Value<String> themeName;
  final Value<bool> showCurrencySymbol;
  final Value<bool> countRepaymentsAsIncome;
  final Value<String?> passcodeHash;
  final Value<String?> passcodeSalt;
  final Value<bool> biometricEnabled;
  final Value<bool> expenseReminderEnabled;
  final Value<int> expenseReminderHour;
  final Value<int> expenseReminderMinute;
  final Value<bool> autoBackupEnabled;
  final Value<AutoBackupFrequency> autoBackupFrequency;
  final Value<int> autoBackupCustomDays;
  final Value<int> autoBackupCustomHours;
  final Value<DateTime?> lastAutoBackupAt;
  final Value<int> backupRetentionDays;
  final Value<bool> preventScreenshots;
  const SettingsCompanion({
    this.id = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.budgetStartDay = const Value.absent(),
    this.onboarded = const Value.absent(),
    this.autoApprove = const Value.absent(),
    this.messageCaptureEnabled = const Value.absent(),
    this.lastMessageScanAt = const Value.absent(),
    this.notificationsEnabled = const Value.absent(),
    this.themeName = const Value.absent(),
    this.showCurrencySymbol = const Value.absent(),
    this.countRepaymentsAsIncome = const Value.absent(),
    this.passcodeHash = const Value.absent(),
    this.passcodeSalt = const Value.absent(),
    this.biometricEnabled = const Value.absent(),
    this.expenseReminderEnabled = const Value.absent(),
    this.expenseReminderHour = const Value.absent(),
    this.expenseReminderMinute = const Value.absent(),
    this.autoBackupEnabled = const Value.absent(),
    this.autoBackupFrequency = const Value.absent(),
    this.autoBackupCustomDays = const Value.absent(),
    this.autoBackupCustomHours = const Value.absent(),
    this.lastAutoBackupAt = const Value.absent(),
    this.backupRetentionDays = const Value.absent(),
    this.preventScreenshots = const Value.absent(),
  });
  SettingsCompanion.insert({
    this.id = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.budgetStartDay = const Value.absent(),
    this.onboarded = const Value.absent(),
    this.autoApprove = const Value.absent(),
    this.messageCaptureEnabled = const Value.absent(),
    this.lastMessageScanAt = const Value.absent(),
    this.notificationsEnabled = const Value.absent(),
    this.themeName = const Value.absent(),
    this.showCurrencySymbol = const Value.absent(),
    this.countRepaymentsAsIncome = const Value.absent(),
    this.passcodeHash = const Value.absent(),
    this.passcodeSalt = const Value.absent(),
    this.biometricEnabled = const Value.absent(),
    this.expenseReminderEnabled = const Value.absent(),
    this.expenseReminderHour = const Value.absent(),
    this.expenseReminderMinute = const Value.absent(),
    this.autoBackupEnabled = const Value.absent(),
    this.autoBackupFrequency = const Value.absent(),
    this.autoBackupCustomDays = const Value.absent(),
    this.autoBackupCustomHours = const Value.absent(),
    this.lastAutoBackupAt = const Value.absent(),
    this.backupRetentionDays = const Value.absent(),
    this.preventScreenshots = const Value.absent(),
  });
  static Insertable<SettingRow> custom({
    Expression<int>? id,
    Expression<String>? currencyCode,
    Expression<int>? budgetStartDay,
    Expression<bool>? onboarded,
    Expression<bool>? autoApprove,
    Expression<bool>? messageCaptureEnabled,
    Expression<DateTime>? lastMessageScanAt,
    Expression<bool>? notificationsEnabled,
    Expression<String>? themeName,
    Expression<bool>? showCurrencySymbol,
    Expression<bool>? countRepaymentsAsIncome,
    Expression<String>? passcodeHash,
    Expression<String>? passcodeSalt,
    Expression<bool>? biometricEnabled,
    Expression<bool>? expenseReminderEnabled,
    Expression<int>? expenseReminderHour,
    Expression<int>? expenseReminderMinute,
    Expression<bool>? autoBackupEnabled,
    Expression<String>? autoBackupFrequency,
    Expression<int>? autoBackupCustomDays,
    Expression<int>? autoBackupCustomHours,
    Expression<DateTime>? lastAutoBackupAt,
    Expression<int>? backupRetentionDays,
    Expression<bool>? preventScreenshots,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (budgetStartDay != null) 'budget_start_day': budgetStartDay,
      if (onboarded != null) 'onboarded': onboarded,
      if (autoApprove != null) 'auto_approve': autoApprove,
      if (messageCaptureEnabled != null)
        'message_capture_enabled': messageCaptureEnabled,
      if (lastMessageScanAt != null) 'last_message_scan_at': lastMessageScanAt,
      if (notificationsEnabled != null)
        'notifications_enabled': notificationsEnabled,
      if (themeName != null) 'theme_name': themeName,
      if (showCurrencySymbol != null)
        'show_currency_symbol': showCurrencySymbol,
      if (countRepaymentsAsIncome != null)
        'count_repayments_as_income': countRepaymentsAsIncome,
      if (passcodeHash != null) 'passcode_hash': passcodeHash,
      if (passcodeSalt != null) 'passcode_salt': passcodeSalt,
      if (biometricEnabled != null) 'biometric_enabled': biometricEnabled,
      if (expenseReminderEnabled != null)
        'expense_reminder_enabled': expenseReminderEnabled,
      if (expenseReminderHour != null)
        'expense_reminder_hour': expenseReminderHour,
      if (expenseReminderMinute != null)
        'expense_reminder_minute': expenseReminderMinute,
      if (autoBackupEnabled != null) 'auto_backup_enabled': autoBackupEnabled,
      if (autoBackupFrequency != null)
        'auto_backup_frequency': autoBackupFrequency,
      if (autoBackupCustomDays != null)
        'auto_backup_custom_days': autoBackupCustomDays,
      if (autoBackupCustomHours != null)
        'auto_backup_custom_hours': autoBackupCustomHours,
      if (lastAutoBackupAt != null) 'last_auto_backup_at': lastAutoBackupAt,
      if (backupRetentionDays != null)
        'backup_retention_days': backupRetentionDays,
      if (preventScreenshots != null) 'prevent_screenshots': preventScreenshots,
    });
  }

  SettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? currencyCode,
    Value<int>? budgetStartDay,
    Value<bool>? onboarded,
    Value<bool>? autoApprove,
    Value<bool>? messageCaptureEnabled,
    Value<DateTime?>? lastMessageScanAt,
    Value<bool>? notificationsEnabled,
    Value<String>? themeName,
    Value<bool>? showCurrencySymbol,
    Value<bool>? countRepaymentsAsIncome,
    Value<String?>? passcodeHash,
    Value<String?>? passcodeSalt,
    Value<bool>? biometricEnabled,
    Value<bool>? expenseReminderEnabled,
    Value<int>? expenseReminderHour,
    Value<int>? expenseReminderMinute,
    Value<bool>? autoBackupEnabled,
    Value<AutoBackupFrequency>? autoBackupFrequency,
    Value<int>? autoBackupCustomDays,
    Value<int>? autoBackupCustomHours,
    Value<DateTime?>? lastAutoBackupAt,
    Value<int>? backupRetentionDays,
    Value<bool>? preventScreenshots,
  }) {
    return SettingsCompanion(
      id: id ?? this.id,
      currencyCode: currencyCode ?? this.currencyCode,
      budgetStartDay: budgetStartDay ?? this.budgetStartDay,
      onboarded: onboarded ?? this.onboarded,
      autoApprove: autoApprove ?? this.autoApprove,
      messageCaptureEnabled:
          messageCaptureEnabled ?? this.messageCaptureEnabled,
      lastMessageScanAt: lastMessageScanAt ?? this.lastMessageScanAt,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      themeName: themeName ?? this.themeName,
      showCurrencySymbol: showCurrencySymbol ?? this.showCurrencySymbol,
      countRepaymentsAsIncome:
          countRepaymentsAsIncome ?? this.countRepaymentsAsIncome,
      passcodeHash: passcodeHash ?? this.passcodeHash,
      passcodeSalt: passcodeSalt ?? this.passcodeSalt,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      expenseReminderEnabled:
          expenseReminderEnabled ?? this.expenseReminderEnabled,
      expenseReminderHour: expenseReminderHour ?? this.expenseReminderHour,
      expenseReminderMinute:
          expenseReminderMinute ?? this.expenseReminderMinute,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      autoBackupFrequency: autoBackupFrequency ?? this.autoBackupFrequency,
      autoBackupCustomDays: autoBackupCustomDays ?? this.autoBackupCustomDays,
      autoBackupCustomHours:
          autoBackupCustomHours ?? this.autoBackupCustomHours,
      lastAutoBackupAt: lastAutoBackupAt ?? this.lastAutoBackupAt,
      backupRetentionDays: backupRetentionDays ?? this.backupRetentionDays,
      preventScreenshots: preventScreenshots ?? this.preventScreenshots,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (budgetStartDay.present) {
      map['budget_start_day'] = Variable<int>(budgetStartDay.value);
    }
    if (onboarded.present) {
      map['onboarded'] = Variable<bool>(onboarded.value);
    }
    if (autoApprove.present) {
      map['auto_approve'] = Variable<bool>(autoApprove.value);
    }
    if (messageCaptureEnabled.present) {
      map['message_capture_enabled'] = Variable<bool>(
        messageCaptureEnabled.value,
      );
    }
    if (lastMessageScanAt.present) {
      map['last_message_scan_at'] = Variable<DateTime>(lastMessageScanAt.value);
    }
    if (notificationsEnabled.present) {
      map['notifications_enabled'] = Variable<bool>(notificationsEnabled.value);
    }
    if (themeName.present) {
      map['theme_name'] = Variable<String>(themeName.value);
    }
    if (showCurrencySymbol.present) {
      map['show_currency_symbol'] = Variable<bool>(showCurrencySymbol.value);
    }
    if (countRepaymentsAsIncome.present) {
      map['count_repayments_as_income'] = Variable<bool>(
        countRepaymentsAsIncome.value,
      );
    }
    if (passcodeHash.present) {
      map['passcode_hash'] = Variable<String>(passcodeHash.value);
    }
    if (passcodeSalt.present) {
      map['passcode_salt'] = Variable<String>(passcodeSalt.value);
    }
    if (biometricEnabled.present) {
      map['biometric_enabled'] = Variable<bool>(biometricEnabled.value);
    }
    if (expenseReminderEnabled.present) {
      map['expense_reminder_enabled'] = Variable<bool>(
        expenseReminderEnabled.value,
      );
    }
    if (expenseReminderHour.present) {
      map['expense_reminder_hour'] = Variable<int>(expenseReminderHour.value);
    }
    if (expenseReminderMinute.present) {
      map['expense_reminder_minute'] = Variable<int>(
        expenseReminderMinute.value,
      );
    }
    if (autoBackupEnabled.present) {
      map['auto_backup_enabled'] = Variable<bool>(autoBackupEnabled.value);
    }
    if (autoBackupFrequency.present) {
      map['auto_backup_frequency'] = Variable<String>(
        $SettingsTable.$converterautoBackupFrequency.toSql(
          autoBackupFrequency.value,
        ),
      );
    }
    if (autoBackupCustomDays.present) {
      map['auto_backup_custom_days'] = Variable<int>(
        autoBackupCustomDays.value,
      );
    }
    if (autoBackupCustomHours.present) {
      map['auto_backup_custom_hours'] = Variable<int>(
        autoBackupCustomHours.value,
      );
    }
    if (lastAutoBackupAt.present) {
      map['last_auto_backup_at'] = Variable<DateTime>(lastAutoBackupAt.value);
    }
    if (backupRetentionDays.present) {
      map['backup_retention_days'] = Variable<int>(backupRetentionDays.value);
    }
    if (preventScreenshots.present) {
      map['prevent_screenshots'] = Variable<bool>(preventScreenshots.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('id: $id, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('budgetStartDay: $budgetStartDay, ')
          ..write('onboarded: $onboarded, ')
          ..write('autoApprove: $autoApprove, ')
          ..write('messageCaptureEnabled: $messageCaptureEnabled, ')
          ..write('lastMessageScanAt: $lastMessageScanAt, ')
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('themeName: $themeName, ')
          ..write('showCurrencySymbol: $showCurrencySymbol, ')
          ..write('countRepaymentsAsIncome: $countRepaymentsAsIncome, ')
          ..write('passcodeHash: $passcodeHash, ')
          ..write('passcodeSalt: $passcodeSalt, ')
          ..write('biometricEnabled: $biometricEnabled, ')
          ..write('expenseReminderEnabled: $expenseReminderEnabled, ')
          ..write('expenseReminderHour: $expenseReminderHour, ')
          ..write('expenseReminderMinute: $expenseReminderMinute, ')
          ..write('autoBackupEnabled: $autoBackupEnabled, ')
          ..write('autoBackupFrequency: $autoBackupFrequency, ')
          ..write('autoBackupCustomDays: $autoBackupCustomDays, ')
          ..write('autoBackupCustomHours: $autoBackupCustomHours, ')
          ..write('lastAutoBackupAt: $lastAutoBackupAt, ')
          ..write('backupRetentionDays: $backupRetentionDays, ')
          ..write('preventScreenshots: $preventScreenshots')
          ..write(')'))
        .toString();
  }
}

class $PendingTxnsTable extends PendingTxns
    with TableInfo<$PendingTxnsTable, PendingTxnRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingTxnsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<MessageSourceKind, String>
  source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<MessageSourceKind>($PendingTxnsTable.$convertersource);
  static const VerificationMeta _rawBodyMeta = const VerificationMeta(
    'rawBody',
  );
  @override
  late final GeneratedColumn<String> rawBody = GeneratedColumn<String>(
    'raw_body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderMeta = const VerificationMeta('sender');
  @override
  late final GeneratedColumn<String> sender = GeneratedColumn<String>(
    'sender',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receivedAtMeta = const VerificationMeta(
    'receivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
    'received_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Money?, int> parsedAmount =
      GeneratedColumn<int>(
        'parsed_amount',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<Money?>($PendingTxnsTable.$converterparsedAmountn);
  @override
  late final GeneratedColumnWithTypeConverter<TxDirection?, String>
  parsedDirection = GeneratedColumn<String>(
    'parsed_direction',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<TxDirection?>($PendingTxnsTable.$converterparsedDirectionn);
  static const VerificationMeta _parsedAccountHintMeta = const VerificationMeta(
    'parsedAccountHint',
  );
  @override
  late final GeneratedColumn<String> parsedAccountHint =
      GeneratedColumn<String>(
        'parsed_account_hint',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _parsedMerchantMeta = const VerificationMeta(
    'parsedMerchant',
  );
  @override
  late final GeneratedColumn<String> parsedMerchant = GeneratedColumn<String>(
    'parsed_merchant',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parsedRefMeta = const VerificationMeta(
    'parsedRef',
  );
  @override
  late final GeneratedColumn<String> parsedRef = GeneratedColumn<String>(
    'parsed_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Money?, int> parsedBalance =
      GeneratedColumn<int>(
        'parsed_balance',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<Money?>($PendingTxnsTable.$converterparsedBalancen);
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<int> confidence = GeneratedColumn<int>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<PendingStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('pending'),
      ).withConverter<PendingStatus>($PendingTxnsTable.$converterstatus);
  static const VerificationMeta _matchedAccountIdMeta = const VerificationMeta(
    'matchedAccountId',
  );
  @override
  late final GeneratedColumn<int> matchedAccountId = GeneratedColumn<int>(
    'matched_account_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _appliedRuleIdMeta = const VerificationMeta(
    'appliedRuleId',
  );
  @override
  late final GeneratedColumn<int> appliedRuleId = GeneratedColumn<int>(
    'applied_rule_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdTransactionIdMeta =
      const VerificationMeta('createdTransactionId');
  @override
  late final GeneratedColumn<int> createdTransactionId = GeneratedColumn<int>(
    'created_transaction_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transactions (id)',
    ),
  );
  static const VerificationMeta _dedupeKeyMeta = const VerificationMeta(
    'dedupeKey',
  );
  @override
  late final GeneratedColumn<String> dedupeKey = GeneratedColumn<String>(
    'dedupe_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    source,
    rawBody,
    sender,
    receivedAt,
    parsedAmount,
    parsedDirection,
    parsedAccountHint,
    parsedMerchant,
    parsedRef,
    parsedBalance,
    confidence,
    status,
    matchedAccountId,
    appliedRuleId,
    createdTransactionId,
    dedupeKey,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_txns';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingTxnRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('raw_body')) {
      context.handle(
        _rawBodyMeta,
        rawBody.isAcceptableOrUnknown(data['raw_body']!, _rawBodyMeta),
      );
    } else if (isInserting) {
      context.missing(_rawBodyMeta);
    }
    if (data.containsKey('sender')) {
      context.handle(
        _senderMeta,
        sender.isAcceptableOrUnknown(data['sender']!, _senderMeta),
      );
    } else if (isInserting) {
      context.missing(_senderMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    if (data.containsKey('parsed_account_hint')) {
      context.handle(
        _parsedAccountHintMeta,
        parsedAccountHint.isAcceptableOrUnknown(
          data['parsed_account_hint']!,
          _parsedAccountHintMeta,
        ),
      );
    }
    if (data.containsKey('parsed_merchant')) {
      context.handle(
        _parsedMerchantMeta,
        parsedMerchant.isAcceptableOrUnknown(
          data['parsed_merchant']!,
          _parsedMerchantMeta,
        ),
      );
    }
    if (data.containsKey('parsed_ref')) {
      context.handle(
        _parsedRefMeta,
        parsedRef.isAcceptableOrUnknown(data['parsed_ref']!, _parsedRefMeta),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('matched_account_id')) {
      context.handle(
        _matchedAccountIdMeta,
        matchedAccountId.isAcceptableOrUnknown(
          data['matched_account_id']!,
          _matchedAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('applied_rule_id')) {
      context.handle(
        _appliedRuleIdMeta,
        appliedRuleId.isAcceptableOrUnknown(
          data['applied_rule_id']!,
          _appliedRuleIdMeta,
        ),
      );
    }
    if (data.containsKey('created_transaction_id')) {
      context.handle(
        _createdTransactionIdMeta,
        createdTransactionId.isAcceptableOrUnknown(
          data['created_transaction_id']!,
          _createdTransactionIdMeta,
        ),
      );
    }
    if (data.containsKey('dedupe_key')) {
      context.handle(
        _dedupeKeyMeta,
        dedupeKey.isAcceptableOrUnknown(data['dedupe_key']!, _dedupeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dedupeKeyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {dedupeKey},
  ];
  @override
  PendingTxnRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingTxnRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      source: $PendingTxnsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      rawBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_body'],
      )!,
      sender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender'],
      )!,
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}received_at'],
      )!,
      parsedAmount: $PendingTxnsTable.$converterparsedAmountn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}parsed_amount'],
        ),
      ),
      parsedDirection: $PendingTxnsTable.$converterparsedDirectionn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}parsed_direction'],
        ),
      ),
      parsedAccountHint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parsed_account_hint'],
      ),
      parsedMerchant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parsed_merchant'],
      ),
      parsedRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parsed_ref'],
      ),
      parsedBalance: $PendingTxnsTable.$converterparsedBalancen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}parsed_balance'],
        ),
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}confidence'],
      )!,
      status: $PendingTxnsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      matchedAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}matched_account_id'],
      ),
      appliedRuleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}applied_rule_id'],
      ),
      createdTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_transaction_id'],
      ),
      dedupeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dedupe_key'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PendingTxnsTable createAlias(String alias) {
    return $PendingTxnsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MessageSourceKind, String, String>
  $convertersource = const EnumNameConverter<MessageSourceKind>(
    MessageSourceKind.values,
  );
  static TypeConverter<Money, int> $converterparsedAmount =
      const MoneyConverter();
  static TypeConverter<Money?, int?> $converterparsedAmountn =
      NullAwareTypeConverter.wrap($converterparsedAmount);
  static JsonTypeConverter2<TxDirection, String, String>
  $converterparsedDirection = const EnumNameConverter<TxDirection>(
    TxDirection.values,
  );
  static JsonTypeConverter2<TxDirection?, String?, String?>
  $converterparsedDirectionn = JsonTypeConverter2.asNullable(
    $converterparsedDirection,
  );
  static TypeConverter<Money, int> $converterparsedBalance =
      const MoneyConverter();
  static TypeConverter<Money?, int?> $converterparsedBalancen =
      NullAwareTypeConverter.wrap($converterparsedBalance);
  static JsonTypeConverter2<PendingStatus, String, String> $converterstatus =
      const EnumNameConverter<PendingStatus>(PendingStatus.values);
}

class PendingTxnRow extends DataClass implements Insertable<PendingTxnRow> {
  final int id;
  final MessageSourceKind source;
  final String rawBody;
  final String sender;
  final DateTime receivedAt;
  final Money? parsedAmount;
  final TxDirection? parsedDirection;

  /// Last 4 digits lifted from `A/c XX1234` / `Card ending 5678`.
  final String? parsedAccountHint;
  final String? parsedMerchant;
  final String? parsedRef;
  final Money? parsedBalance;

  /// 0–100. Low confidence never auto-posts.
  final int confidence;
  final PendingStatus status;
  final int? matchedAccountId;
  final int? appliedRuleId;
  final int? createdTransactionId;

  /// Stable identity for dedupe: sender + body + received-minute.
  final String dedupeKey;
  final DateTime createdAt;
  const PendingTxnRow({
    required this.id,
    required this.source,
    required this.rawBody,
    required this.sender,
    required this.receivedAt,
    this.parsedAmount,
    this.parsedDirection,
    this.parsedAccountHint,
    this.parsedMerchant,
    this.parsedRef,
    this.parsedBalance,
    required this.confidence,
    required this.status,
    this.matchedAccountId,
    this.appliedRuleId,
    this.createdTransactionId,
    required this.dedupeKey,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['source'] = Variable<String>(
        $PendingTxnsTable.$convertersource.toSql(source),
      );
    }
    map['raw_body'] = Variable<String>(rawBody);
    map['sender'] = Variable<String>(sender);
    map['received_at'] = Variable<DateTime>(receivedAt);
    if (!nullToAbsent || parsedAmount != null) {
      map['parsed_amount'] = Variable<int>(
        $PendingTxnsTable.$converterparsedAmountn.toSql(parsedAmount),
      );
    }
    if (!nullToAbsent || parsedDirection != null) {
      map['parsed_direction'] = Variable<String>(
        $PendingTxnsTable.$converterparsedDirectionn.toSql(parsedDirection),
      );
    }
    if (!nullToAbsent || parsedAccountHint != null) {
      map['parsed_account_hint'] = Variable<String>(parsedAccountHint);
    }
    if (!nullToAbsent || parsedMerchant != null) {
      map['parsed_merchant'] = Variable<String>(parsedMerchant);
    }
    if (!nullToAbsent || parsedRef != null) {
      map['parsed_ref'] = Variable<String>(parsedRef);
    }
    if (!nullToAbsent || parsedBalance != null) {
      map['parsed_balance'] = Variable<int>(
        $PendingTxnsTable.$converterparsedBalancen.toSql(parsedBalance),
      );
    }
    map['confidence'] = Variable<int>(confidence);
    {
      map['status'] = Variable<String>(
        $PendingTxnsTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || matchedAccountId != null) {
      map['matched_account_id'] = Variable<int>(matchedAccountId);
    }
    if (!nullToAbsent || appliedRuleId != null) {
      map['applied_rule_id'] = Variable<int>(appliedRuleId);
    }
    if (!nullToAbsent || createdTransactionId != null) {
      map['created_transaction_id'] = Variable<int>(createdTransactionId);
    }
    map['dedupe_key'] = Variable<String>(dedupeKey);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingTxnsCompanion toCompanion(bool nullToAbsent) {
    return PendingTxnsCompanion(
      id: Value(id),
      source: Value(source),
      rawBody: Value(rawBody),
      sender: Value(sender),
      receivedAt: Value(receivedAt),
      parsedAmount: parsedAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(parsedAmount),
      parsedDirection: parsedDirection == null && nullToAbsent
          ? const Value.absent()
          : Value(parsedDirection),
      parsedAccountHint: parsedAccountHint == null && nullToAbsent
          ? const Value.absent()
          : Value(parsedAccountHint),
      parsedMerchant: parsedMerchant == null && nullToAbsent
          ? const Value.absent()
          : Value(parsedMerchant),
      parsedRef: parsedRef == null && nullToAbsent
          ? const Value.absent()
          : Value(parsedRef),
      parsedBalance: parsedBalance == null && nullToAbsent
          ? const Value.absent()
          : Value(parsedBalance),
      confidence: Value(confidence),
      status: Value(status),
      matchedAccountId: matchedAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(matchedAccountId),
      appliedRuleId: appliedRuleId == null && nullToAbsent
          ? const Value.absent()
          : Value(appliedRuleId),
      createdTransactionId: createdTransactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(createdTransactionId),
      dedupeKey: Value(dedupeKey),
      createdAt: Value(createdAt),
    );
  }

  factory PendingTxnRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingTxnRow(
      id: serializer.fromJson<int>(json['id']),
      source: $PendingTxnsTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      rawBody: serializer.fromJson<String>(json['rawBody']),
      sender: serializer.fromJson<String>(json['sender']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
      parsedAmount: serializer.fromJson<Money?>(json['parsedAmount']),
      parsedDirection: $PendingTxnsTable.$converterparsedDirectionn.fromJson(
        serializer.fromJson<String?>(json['parsedDirection']),
      ),
      parsedAccountHint: serializer.fromJson<String?>(
        json['parsedAccountHint'],
      ),
      parsedMerchant: serializer.fromJson<String?>(json['parsedMerchant']),
      parsedRef: serializer.fromJson<String?>(json['parsedRef']),
      parsedBalance: serializer.fromJson<Money?>(json['parsedBalance']),
      confidence: serializer.fromJson<int>(json['confidence']),
      status: $PendingTxnsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      matchedAccountId: serializer.fromJson<int?>(json['matchedAccountId']),
      appliedRuleId: serializer.fromJson<int?>(json['appliedRuleId']),
      createdTransactionId: serializer.fromJson<int?>(
        json['createdTransactionId'],
      ),
      dedupeKey: serializer.fromJson<String>(json['dedupeKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'source': serializer.toJson<String>(
        $PendingTxnsTable.$convertersource.toJson(source),
      ),
      'rawBody': serializer.toJson<String>(rawBody),
      'sender': serializer.toJson<String>(sender),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
      'parsedAmount': serializer.toJson<Money?>(parsedAmount),
      'parsedDirection': serializer.toJson<String?>(
        $PendingTxnsTable.$converterparsedDirectionn.toJson(parsedDirection),
      ),
      'parsedAccountHint': serializer.toJson<String?>(parsedAccountHint),
      'parsedMerchant': serializer.toJson<String?>(parsedMerchant),
      'parsedRef': serializer.toJson<String?>(parsedRef),
      'parsedBalance': serializer.toJson<Money?>(parsedBalance),
      'confidence': serializer.toJson<int>(confidence),
      'status': serializer.toJson<String>(
        $PendingTxnsTable.$converterstatus.toJson(status),
      ),
      'matchedAccountId': serializer.toJson<int?>(matchedAccountId),
      'appliedRuleId': serializer.toJson<int?>(appliedRuleId),
      'createdTransactionId': serializer.toJson<int?>(createdTransactionId),
      'dedupeKey': serializer.toJson<String>(dedupeKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingTxnRow copyWith({
    int? id,
    MessageSourceKind? source,
    String? rawBody,
    String? sender,
    DateTime? receivedAt,
    Value<Money?> parsedAmount = const Value.absent(),
    Value<TxDirection?> parsedDirection = const Value.absent(),
    Value<String?> parsedAccountHint = const Value.absent(),
    Value<String?> parsedMerchant = const Value.absent(),
    Value<String?> parsedRef = const Value.absent(),
    Value<Money?> parsedBalance = const Value.absent(),
    int? confidence,
    PendingStatus? status,
    Value<int?> matchedAccountId = const Value.absent(),
    Value<int?> appliedRuleId = const Value.absent(),
    Value<int?> createdTransactionId = const Value.absent(),
    String? dedupeKey,
    DateTime? createdAt,
  }) => PendingTxnRow(
    id: id ?? this.id,
    source: source ?? this.source,
    rawBody: rawBody ?? this.rawBody,
    sender: sender ?? this.sender,
    receivedAt: receivedAt ?? this.receivedAt,
    parsedAmount: parsedAmount.present ? parsedAmount.value : this.parsedAmount,
    parsedDirection: parsedDirection.present
        ? parsedDirection.value
        : this.parsedDirection,
    parsedAccountHint: parsedAccountHint.present
        ? parsedAccountHint.value
        : this.parsedAccountHint,
    parsedMerchant: parsedMerchant.present
        ? parsedMerchant.value
        : this.parsedMerchant,
    parsedRef: parsedRef.present ? parsedRef.value : this.parsedRef,
    parsedBalance: parsedBalance.present
        ? parsedBalance.value
        : this.parsedBalance,
    confidence: confidence ?? this.confidence,
    status: status ?? this.status,
    matchedAccountId: matchedAccountId.present
        ? matchedAccountId.value
        : this.matchedAccountId,
    appliedRuleId: appliedRuleId.present
        ? appliedRuleId.value
        : this.appliedRuleId,
    createdTransactionId: createdTransactionId.present
        ? createdTransactionId.value
        : this.createdTransactionId,
    dedupeKey: dedupeKey ?? this.dedupeKey,
    createdAt: createdAt ?? this.createdAt,
  );
  PendingTxnRow copyWithCompanion(PendingTxnsCompanion data) {
    return PendingTxnRow(
      id: data.id.present ? data.id.value : this.id,
      source: data.source.present ? data.source.value : this.source,
      rawBody: data.rawBody.present ? data.rawBody.value : this.rawBody,
      sender: data.sender.present ? data.sender.value : this.sender,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
      parsedAmount: data.parsedAmount.present
          ? data.parsedAmount.value
          : this.parsedAmount,
      parsedDirection: data.parsedDirection.present
          ? data.parsedDirection.value
          : this.parsedDirection,
      parsedAccountHint: data.parsedAccountHint.present
          ? data.parsedAccountHint.value
          : this.parsedAccountHint,
      parsedMerchant: data.parsedMerchant.present
          ? data.parsedMerchant.value
          : this.parsedMerchant,
      parsedRef: data.parsedRef.present ? data.parsedRef.value : this.parsedRef,
      parsedBalance: data.parsedBalance.present
          ? data.parsedBalance.value
          : this.parsedBalance,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      status: data.status.present ? data.status.value : this.status,
      matchedAccountId: data.matchedAccountId.present
          ? data.matchedAccountId.value
          : this.matchedAccountId,
      appliedRuleId: data.appliedRuleId.present
          ? data.appliedRuleId.value
          : this.appliedRuleId,
      createdTransactionId: data.createdTransactionId.present
          ? data.createdTransactionId.value
          : this.createdTransactionId,
      dedupeKey: data.dedupeKey.present ? data.dedupeKey.value : this.dedupeKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingTxnRow(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('rawBody: $rawBody, ')
          ..write('sender: $sender, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('parsedAmount: $parsedAmount, ')
          ..write('parsedDirection: $parsedDirection, ')
          ..write('parsedAccountHint: $parsedAccountHint, ')
          ..write('parsedMerchant: $parsedMerchant, ')
          ..write('parsedRef: $parsedRef, ')
          ..write('parsedBalance: $parsedBalance, ')
          ..write('confidence: $confidence, ')
          ..write('status: $status, ')
          ..write('matchedAccountId: $matchedAccountId, ')
          ..write('appliedRuleId: $appliedRuleId, ')
          ..write('createdTransactionId: $createdTransactionId, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    source,
    rawBody,
    sender,
    receivedAt,
    parsedAmount,
    parsedDirection,
    parsedAccountHint,
    parsedMerchant,
    parsedRef,
    parsedBalance,
    confidence,
    status,
    matchedAccountId,
    appliedRuleId,
    createdTransactionId,
    dedupeKey,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingTxnRow &&
          other.id == this.id &&
          other.source == this.source &&
          other.rawBody == this.rawBody &&
          other.sender == this.sender &&
          other.receivedAt == this.receivedAt &&
          other.parsedAmount == this.parsedAmount &&
          other.parsedDirection == this.parsedDirection &&
          other.parsedAccountHint == this.parsedAccountHint &&
          other.parsedMerchant == this.parsedMerchant &&
          other.parsedRef == this.parsedRef &&
          other.parsedBalance == this.parsedBalance &&
          other.confidence == this.confidence &&
          other.status == this.status &&
          other.matchedAccountId == this.matchedAccountId &&
          other.appliedRuleId == this.appliedRuleId &&
          other.createdTransactionId == this.createdTransactionId &&
          other.dedupeKey == this.dedupeKey &&
          other.createdAt == this.createdAt);
}

class PendingTxnsCompanion extends UpdateCompanion<PendingTxnRow> {
  final Value<int> id;
  final Value<MessageSourceKind> source;
  final Value<String> rawBody;
  final Value<String> sender;
  final Value<DateTime> receivedAt;
  final Value<Money?> parsedAmount;
  final Value<TxDirection?> parsedDirection;
  final Value<String?> parsedAccountHint;
  final Value<String?> parsedMerchant;
  final Value<String?> parsedRef;
  final Value<Money?> parsedBalance;
  final Value<int> confidence;
  final Value<PendingStatus> status;
  final Value<int?> matchedAccountId;
  final Value<int?> appliedRuleId;
  final Value<int?> createdTransactionId;
  final Value<String> dedupeKey;
  final Value<DateTime> createdAt;
  const PendingTxnsCompanion({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    this.rawBody = const Value.absent(),
    this.sender = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.parsedAmount = const Value.absent(),
    this.parsedDirection = const Value.absent(),
    this.parsedAccountHint = const Value.absent(),
    this.parsedMerchant = const Value.absent(),
    this.parsedRef = const Value.absent(),
    this.parsedBalance = const Value.absent(),
    this.confidence = const Value.absent(),
    this.status = const Value.absent(),
    this.matchedAccountId = const Value.absent(),
    this.appliedRuleId = const Value.absent(),
    this.createdTransactionId = const Value.absent(),
    this.dedupeKey = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PendingTxnsCompanion.insert({
    this.id = const Value.absent(),
    required MessageSourceKind source,
    required String rawBody,
    required String sender,
    required DateTime receivedAt,
    this.parsedAmount = const Value.absent(),
    this.parsedDirection = const Value.absent(),
    this.parsedAccountHint = const Value.absent(),
    this.parsedMerchant = const Value.absent(),
    this.parsedRef = const Value.absent(),
    this.parsedBalance = const Value.absent(),
    this.confidence = const Value.absent(),
    this.status = const Value.absent(),
    this.matchedAccountId = const Value.absent(),
    this.appliedRuleId = const Value.absent(),
    this.createdTransactionId = const Value.absent(),
    required String dedupeKey,
    this.createdAt = const Value.absent(),
  }) : source = Value(source),
       rawBody = Value(rawBody),
       sender = Value(sender),
       receivedAt = Value(receivedAt),
       dedupeKey = Value(dedupeKey);
  static Insertable<PendingTxnRow> custom({
    Expression<int>? id,
    Expression<String>? source,
    Expression<String>? rawBody,
    Expression<String>? sender,
    Expression<DateTime>? receivedAt,
    Expression<int>? parsedAmount,
    Expression<String>? parsedDirection,
    Expression<String>? parsedAccountHint,
    Expression<String>? parsedMerchant,
    Expression<String>? parsedRef,
    Expression<int>? parsedBalance,
    Expression<int>? confidence,
    Expression<String>? status,
    Expression<int>? matchedAccountId,
    Expression<int>? appliedRuleId,
    Expression<int>? createdTransactionId,
    Expression<String>? dedupeKey,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (source != null) 'source': source,
      if (rawBody != null) 'raw_body': rawBody,
      if (sender != null) 'sender': sender,
      if (receivedAt != null) 'received_at': receivedAt,
      if (parsedAmount != null) 'parsed_amount': parsedAmount,
      if (parsedDirection != null) 'parsed_direction': parsedDirection,
      if (parsedAccountHint != null) 'parsed_account_hint': parsedAccountHint,
      if (parsedMerchant != null) 'parsed_merchant': parsedMerchant,
      if (parsedRef != null) 'parsed_ref': parsedRef,
      if (parsedBalance != null) 'parsed_balance': parsedBalance,
      if (confidence != null) 'confidence': confidence,
      if (status != null) 'status': status,
      if (matchedAccountId != null) 'matched_account_id': matchedAccountId,
      if (appliedRuleId != null) 'applied_rule_id': appliedRuleId,
      if (createdTransactionId != null)
        'created_transaction_id': createdTransactionId,
      if (dedupeKey != null) 'dedupe_key': dedupeKey,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PendingTxnsCompanion copyWith({
    Value<int>? id,
    Value<MessageSourceKind>? source,
    Value<String>? rawBody,
    Value<String>? sender,
    Value<DateTime>? receivedAt,
    Value<Money?>? parsedAmount,
    Value<TxDirection?>? parsedDirection,
    Value<String?>? parsedAccountHint,
    Value<String?>? parsedMerchant,
    Value<String?>? parsedRef,
    Value<Money?>? parsedBalance,
    Value<int>? confidence,
    Value<PendingStatus>? status,
    Value<int?>? matchedAccountId,
    Value<int?>? appliedRuleId,
    Value<int?>? createdTransactionId,
    Value<String>? dedupeKey,
    Value<DateTime>? createdAt,
  }) {
    return PendingTxnsCompanion(
      id: id ?? this.id,
      source: source ?? this.source,
      rawBody: rawBody ?? this.rawBody,
      sender: sender ?? this.sender,
      receivedAt: receivedAt ?? this.receivedAt,
      parsedAmount: parsedAmount ?? this.parsedAmount,
      parsedDirection: parsedDirection ?? this.parsedDirection,
      parsedAccountHint: parsedAccountHint ?? this.parsedAccountHint,
      parsedMerchant: parsedMerchant ?? this.parsedMerchant,
      parsedRef: parsedRef ?? this.parsedRef,
      parsedBalance: parsedBalance ?? this.parsedBalance,
      confidence: confidence ?? this.confidence,
      status: status ?? this.status,
      matchedAccountId: matchedAccountId ?? this.matchedAccountId,
      appliedRuleId: appliedRuleId ?? this.appliedRuleId,
      createdTransactionId: createdTransactionId ?? this.createdTransactionId,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $PendingTxnsTable.$convertersource.toSql(source.value),
      );
    }
    if (rawBody.present) {
      map['raw_body'] = Variable<String>(rawBody.value);
    }
    if (sender.present) {
      map['sender'] = Variable<String>(sender.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (parsedAmount.present) {
      map['parsed_amount'] = Variable<int>(
        $PendingTxnsTable.$converterparsedAmountn.toSql(parsedAmount.value),
      );
    }
    if (parsedDirection.present) {
      map['parsed_direction'] = Variable<String>(
        $PendingTxnsTable.$converterparsedDirectionn.toSql(
          parsedDirection.value,
        ),
      );
    }
    if (parsedAccountHint.present) {
      map['parsed_account_hint'] = Variable<String>(parsedAccountHint.value);
    }
    if (parsedMerchant.present) {
      map['parsed_merchant'] = Variable<String>(parsedMerchant.value);
    }
    if (parsedRef.present) {
      map['parsed_ref'] = Variable<String>(parsedRef.value);
    }
    if (parsedBalance.present) {
      map['parsed_balance'] = Variable<int>(
        $PendingTxnsTable.$converterparsedBalancen.toSql(parsedBalance.value),
      );
    }
    if (confidence.present) {
      map['confidence'] = Variable<int>(confidence.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $PendingTxnsTable.$converterstatus.toSql(status.value),
      );
    }
    if (matchedAccountId.present) {
      map['matched_account_id'] = Variable<int>(matchedAccountId.value);
    }
    if (appliedRuleId.present) {
      map['applied_rule_id'] = Variable<int>(appliedRuleId.value);
    }
    if (createdTransactionId.present) {
      map['created_transaction_id'] = Variable<int>(createdTransactionId.value);
    }
    if (dedupeKey.present) {
      map['dedupe_key'] = Variable<String>(dedupeKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingTxnsCompanion(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('rawBody: $rawBody, ')
          ..write('sender: $sender, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('parsedAmount: $parsedAmount, ')
          ..write('parsedDirection: $parsedDirection, ')
          ..write('parsedAccountHint: $parsedAccountHint, ')
          ..write('parsedMerchant: $parsedMerchant, ')
          ..write('parsedRef: $parsedRef, ')
          ..write('parsedBalance: $parsedBalance, ')
          ..write('confidence: $confidence, ')
          ..write('status: $status, ')
          ..write('matchedAccountId: $matchedAccountId, ')
          ..write('appliedRuleId: $appliedRuleId, ')
          ..write('createdTransactionId: $createdTransactionId, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $MerchantRulesTable extends MerchantRules
    with TableInfo<$MerchantRulesTable, MerchantRuleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MerchantRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _matchPatternMeta = const VerificationMeta(
    'matchPattern',
  );
  @override
  late final GeneratedColumn<String> matchPattern = GeneratedColumn<String>(
    'match_pattern',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
    'account_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _autoApproveMeta = const VerificationMeta(
    'autoApprove',
  );
  @override
  late final GeneratedColumn<bool> autoApprove = GeneratedColumn<bool>(
    'auto_approve',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_approve" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _hitCountMeta = const VerificationMeta(
    'hitCount',
  );
  @override
  late final GeneratedColumn<int> hitCount = GeneratedColumn<int>(
    'hit_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    matchPattern,
    categoryId,
    accountId,
    autoApprove,
    hitCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'merchant_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<MerchantRuleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('match_pattern')) {
      context.handle(
        _matchPatternMeta,
        matchPattern.isAcceptableOrUnknown(
          data['match_pattern']!,
          _matchPatternMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_matchPatternMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    }
    if (data.containsKey('auto_approve')) {
      context.handle(
        _autoApproveMeta,
        autoApprove.isAcceptableOrUnknown(
          data['auto_approve']!,
          _autoApproveMeta,
        ),
      );
    }
    if (data.containsKey('hit_count')) {
      context.handle(
        _hitCountMeta,
        hitCount.isAcceptableOrUnknown(data['hit_count']!, _hitCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {matchPattern},
  ];
  @override
  MerchantRuleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MerchantRuleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      matchPattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_pattern'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      ),
      autoApprove: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_approve'],
      )!,
      hitCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hit_count'],
      )!,
    );
  }

  @override
  $MerchantRulesTable createAlias(String alias) {
    return $MerchantRulesTable(attachedDatabase, alias);
  }
}

class MerchantRuleRow extends DataClass implements Insertable<MerchantRuleRow> {
  final int id;
  final String matchPattern;
  final int categoryId;
  final int? accountId;
  final bool autoApprove;
  final int hitCount;
  const MerchantRuleRow({
    required this.id,
    required this.matchPattern,
    required this.categoryId,
    this.accountId,
    required this.autoApprove,
    required this.hitCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['match_pattern'] = Variable<String>(matchPattern);
    map['category_id'] = Variable<int>(categoryId);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<int>(accountId);
    }
    map['auto_approve'] = Variable<bool>(autoApprove);
    map['hit_count'] = Variable<int>(hitCount);
    return map;
  }

  MerchantRulesCompanion toCompanion(bool nullToAbsent) {
    return MerchantRulesCompanion(
      id: Value(id),
      matchPattern: Value(matchPattern),
      categoryId: Value(categoryId),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      autoApprove: Value(autoApprove),
      hitCount: Value(hitCount),
    );
  }

  factory MerchantRuleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MerchantRuleRow(
      id: serializer.fromJson<int>(json['id']),
      matchPattern: serializer.fromJson<String>(json['matchPattern']),
      categoryId: serializer.fromJson<int>(json['categoryId']),
      accountId: serializer.fromJson<int?>(json['accountId']),
      autoApprove: serializer.fromJson<bool>(json['autoApprove']),
      hitCount: serializer.fromJson<int>(json['hitCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'matchPattern': serializer.toJson<String>(matchPattern),
      'categoryId': serializer.toJson<int>(categoryId),
      'accountId': serializer.toJson<int?>(accountId),
      'autoApprove': serializer.toJson<bool>(autoApprove),
      'hitCount': serializer.toJson<int>(hitCount),
    };
  }

  MerchantRuleRow copyWith({
    int? id,
    String? matchPattern,
    int? categoryId,
    Value<int?> accountId = const Value.absent(),
    bool? autoApprove,
    int? hitCount,
  }) => MerchantRuleRow(
    id: id ?? this.id,
    matchPattern: matchPattern ?? this.matchPattern,
    categoryId: categoryId ?? this.categoryId,
    accountId: accountId.present ? accountId.value : this.accountId,
    autoApprove: autoApprove ?? this.autoApprove,
    hitCount: hitCount ?? this.hitCount,
  );
  MerchantRuleRow copyWithCompanion(MerchantRulesCompanion data) {
    return MerchantRuleRow(
      id: data.id.present ? data.id.value : this.id,
      matchPattern: data.matchPattern.present
          ? data.matchPattern.value
          : this.matchPattern,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      autoApprove: data.autoApprove.present
          ? data.autoApprove.value
          : this.autoApprove,
      hitCount: data.hitCount.present ? data.hitCount.value : this.hitCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MerchantRuleRow(')
          ..write('id: $id, ')
          ..write('matchPattern: $matchPattern, ')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId, ')
          ..write('autoApprove: $autoApprove, ')
          ..write('hitCount: $hitCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    matchPattern,
    categoryId,
    accountId,
    autoApprove,
    hitCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MerchantRuleRow &&
          other.id == this.id &&
          other.matchPattern == this.matchPattern &&
          other.categoryId == this.categoryId &&
          other.accountId == this.accountId &&
          other.autoApprove == this.autoApprove &&
          other.hitCount == this.hitCount);
}

class MerchantRulesCompanion extends UpdateCompanion<MerchantRuleRow> {
  final Value<int> id;
  final Value<String> matchPattern;
  final Value<int> categoryId;
  final Value<int?> accountId;
  final Value<bool> autoApprove;
  final Value<int> hitCount;
  const MerchantRulesCompanion({
    this.id = const Value.absent(),
    this.matchPattern = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.autoApprove = const Value.absent(),
    this.hitCount = const Value.absent(),
  });
  MerchantRulesCompanion.insert({
    this.id = const Value.absent(),
    required String matchPattern,
    required int categoryId,
    this.accountId = const Value.absent(),
    this.autoApprove = const Value.absent(),
    this.hitCount = const Value.absent(),
  }) : matchPattern = Value(matchPattern),
       categoryId = Value(categoryId);
  static Insertable<MerchantRuleRow> custom({
    Expression<int>? id,
    Expression<String>? matchPattern,
    Expression<int>? categoryId,
    Expression<int>? accountId,
    Expression<bool>? autoApprove,
    Expression<int>? hitCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (matchPattern != null) 'match_pattern': matchPattern,
      if (categoryId != null) 'category_id': categoryId,
      if (accountId != null) 'account_id': accountId,
      if (autoApprove != null) 'auto_approve': autoApprove,
      if (hitCount != null) 'hit_count': hitCount,
    });
  }

  MerchantRulesCompanion copyWith({
    Value<int>? id,
    Value<String>? matchPattern,
    Value<int>? categoryId,
    Value<int?>? accountId,
    Value<bool>? autoApprove,
    Value<int>? hitCount,
  }) {
    return MerchantRulesCompanion(
      id: id ?? this.id,
      matchPattern: matchPattern ?? this.matchPattern,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      autoApprove: autoApprove ?? this.autoApprove,
      hitCount: hitCount ?? this.hitCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (matchPattern.present) {
      map['match_pattern'] = Variable<String>(matchPattern.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (autoApprove.present) {
      map['auto_approve'] = Variable<bool>(autoApprove.value);
    }
    if (hitCount.present) {
      map['hit_count'] = Variable<int>(hitCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MerchantRulesCompanion(')
          ..write('id: $id, ')
          ..write('matchPattern: $matchPattern, ')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId, ')
          ..write('autoApprove: $autoApprove, ')
          ..write('hitCount: $hitCount')
          ..write(')'))
        .toString();
  }
}

class $SenderRulesTable extends SenderRules
    with TableInfo<$SenderRulesTable, SenderRuleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SenderRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _senderPatternMeta = const VerificationMeta(
    'senderPattern',
  );
  @override
  late final GeneratedColumn<String> senderPattern = GeneratedColumn<String>(
    'sender_pattern',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bankNameMeta = const VerificationMeta(
    'bankName',
  );
  @override
  late final GeneratedColumn<String> bankName = GeneratedColumn<String>(
    'bank_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [id, senderPattern, bankName, enabled];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sender_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<SenderRuleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sender_pattern')) {
      context.handle(
        _senderPatternMeta,
        senderPattern.isAcceptableOrUnknown(
          data['sender_pattern']!,
          _senderPatternMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_senderPatternMeta);
    }
    if (data.containsKey('bank_name')) {
      context.handle(
        _bankNameMeta,
        bankName.isAcceptableOrUnknown(data['bank_name']!, _bankNameMeta),
      );
    } else if (isInserting) {
      context.missing(_bankNameMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {senderPattern},
  ];
  @override
  SenderRuleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SenderRuleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      senderPattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_pattern'],
      )!,
      bankName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_name'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
    );
  }

  @override
  $SenderRulesTable createAlias(String alias) {
    return $SenderRulesTable(attachedDatabase, alias);
  }
}

class SenderRuleRow extends DataClass implements Insertable<SenderRuleRow> {
  final int id;
  final String senderPattern;
  final String bankName;
  final bool enabled;
  const SenderRuleRow({
    required this.id,
    required this.senderPattern,
    required this.bankName,
    required this.enabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sender_pattern'] = Variable<String>(senderPattern);
    map['bank_name'] = Variable<String>(bankName);
    map['enabled'] = Variable<bool>(enabled);
    return map;
  }

  SenderRulesCompanion toCompanion(bool nullToAbsent) {
    return SenderRulesCompanion(
      id: Value(id),
      senderPattern: Value(senderPattern),
      bankName: Value(bankName),
      enabled: Value(enabled),
    );
  }

  factory SenderRuleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SenderRuleRow(
      id: serializer.fromJson<int>(json['id']),
      senderPattern: serializer.fromJson<String>(json['senderPattern']),
      bankName: serializer.fromJson<String>(json['bankName']),
      enabled: serializer.fromJson<bool>(json['enabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'senderPattern': serializer.toJson<String>(senderPattern),
      'bankName': serializer.toJson<String>(bankName),
      'enabled': serializer.toJson<bool>(enabled),
    };
  }

  SenderRuleRow copyWith({
    int? id,
    String? senderPattern,
    String? bankName,
    bool? enabled,
  }) => SenderRuleRow(
    id: id ?? this.id,
    senderPattern: senderPattern ?? this.senderPattern,
    bankName: bankName ?? this.bankName,
    enabled: enabled ?? this.enabled,
  );
  SenderRuleRow copyWithCompanion(SenderRulesCompanion data) {
    return SenderRuleRow(
      id: data.id.present ? data.id.value : this.id,
      senderPattern: data.senderPattern.present
          ? data.senderPattern.value
          : this.senderPattern,
      bankName: data.bankName.present ? data.bankName.value : this.bankName,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SenderRuleRow(')
          ..write('id: $id, ')
          ..write('senderPattern: $senderPattern, ')
          ..write('bankName: $bankName, ')
          ..write('enabled: $enabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, senderPattern, bankName, enabled);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SenderRuleRow &&
          other.id == this.id &&
          other.senderPattern == this.senderPattern &&
          other.bankName == this.bankName &&
          other.enabled == this.enabled);
}

class SenderRulesCompanion extends UpdateCompanion<SenderRuleRow> {
  final Value<int> id;
  final Value<String> senderPattern;
  final Value<String> bankName;
  final Value<bool> enabled;
  const SenderRulesCompanion({
    this.id = const Value.absent(),
    this.senderPattern = const Value.absent(),
    this.bankName = const Value.absent(),
    this.enabled = const Value.absent(),
  });
  SenderRulesCompanion.insert({
    this.id = const Value.absent(),
    required String senderPattern,
    required String bankName,
    this.enabled = const Value.absent(),
  }) : senderPattern = Value(senderPattern),
       bankName = Value(bankName);
  static Insertable<SenderRuleRow> custom({
    Expression<int>? id,
    Expression<String>? senderPattern,
    Expression<String>? bankName,
    Expression<bool>? enabled,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (senderPattern != null) 'sender_pattern': senderPattern,
      if (bankName != null) 'bank_name': bankName,
      if (enabled != null) 'enabled': enabled,
    });
  }

  SenderRulesCompanion copyWith({
    Value<int>? id,
    Value<String>? senderPattern,
    Value<String>? bankName,
    Value<bool>? enabled,
  }) {
    return SenderRulesCompanion(
      id: id ?? this.id,
      senderPattern: senderPattern ?? this.senderPattern,
      bankName: bankName ?? this.bankName,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (senderPattern.present) {
      map['sender_pattern'] = Variable<String>(senderPattern.value);
    }
    if (bankName.present) {
      map['bank_name'] = Variable<String>(bankName.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SenderRulesCompanion(')
          ..write('id: $id, ')
          ..write('senderPattern: $senderPattern, ')
          ..write('bankName: $bankName, ')
          ..write('enabled: $enabled')
          ..write(')'))
        .toString();
  }
}

class $BudgetAlertsTable extends BudgetAlerts
    with TableInfo<$BudgetAlertsTable, BudgetAlertRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetAlertsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _periodKeyMeta = const VerificationMeta(
    'periodKey',
  );
  @override
  late final GeneratedColumn<String> periodKey = GeneratedColumn<String>(
    'period_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AlertLevel, String> level =
      GeneratedColumn<String>(
        'level',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AlertLevel>($BudgetAlertsTable.$converterlevel);
  static const VerificationMeta _firedAtMeta = const VerificationMeta(
    'firedAt',
  );
  @override
  late final GeneratedColumn<DateTime> firedAt = GeneratedColumn<DateTime>(
    'fired_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    categoryId,
    periodKey,
    level,
    firedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budget_alerts';
  @override
  VerificationContext validateIntegrity(
    Insertable<BudgetAlertRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('period_key')) {
      context.handle(
        _periodKeyMeta,
        periodKey.isAcceptableOrUnknown(data['period_key']!, _periodKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_periodKeyMeta);
    }
    if (data.containsKey('fired_at')) {
      context.handle(
        _firedAtMeta,
        firedAt.isAcceptableOrUnknown(data['fired_at']!, _firedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {categoryId, periodKey, level},
  ];
  @override
  BudgetAlertRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BudgetAlertRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      )!,
      periodKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_key'],
      )!,
      level: $BudgetAlertsTable.$converterlevel.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}level'],
        )!,
      ),
      firedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fired_at'],
      )!,
    );
  }

  @override
  $BudgetAlertsTable createAlias(String alias) {
    return $BudgetAlertsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AlertLevel, String, String> $converterlevel =
      const EnumNameConverter<AlertLevel>(AlertLevel.values);
}

class BudgetAlertRow extends DataClass implements Insertable<BudgetAlertRow> {
  final int id;
  final int categoryId;

  /// e.g. `2026-07`.
  final String periodKey;
  final AlertLevel level;
  final DateTime firedAt;
  const BudgetAlertRow({
    required this.id,
    required this.categoryId,
    required this.periodKey,
    required this.level,
    required this.firedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['category_id'] = Variable<int>(categoryId);
    map['period_key'] = Variable<String>(periodKey);
    {
      map['level'] = Variable<String>(
        $BudgetAlertsTable.$converterlevel.toSql(level),
      );
    }
    map['fired_at'] = Variable<DateTime>(firedAt);
    return map;
  }

  BudgetAlertsCompanion toCompanion(bool nullToAbsent) {
    return BudgetAlertsCompanion(
      id: Value(id),
      categoryId: Value(categoryId),
      periodKey: Value(periodKey),
      level: Value(level),
      firedAt: Value(firedAt),
    );
  }

  factory BudgetAlertRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BudgetAlertRow(
      id: serializer.fromJson<int>(json['id']),
      categoryId: serializer.fromJson<int>(json['categoryId']),
      periodKey: serializer.fromJson<String>(json['periodKey']),
      level: $BudgetAlertsTable.$converterlevel.fromJson(
        serializer.fromJson<String>(json['level']),
      ),
      firedAt: serializer.fromJson<DateTime>(json['firedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'categoryId': serializer.toJson<int>(categoryId),
      'periodKey': serializer.toJson<String>(periodKey),
      'level': serializer.toJson<String>(
        $BudgetAlertsTable.$converterlevel.toJson(level),
      ),
      'firedAt': serializer.toJson<DateTime>(firedAt),
    };
  }

  BudgetAlertRow copyWith({
    int? id,
    int? categoryId,
    String? periodKey,
    AlertLevel? level,
    DateTime? firedAt,
  }) => BudgetAlertRow(
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    periodKey: periodKey ?? this.periodKey,
    level: level ?? this.level,
    firedAt: firedAt ?? this.firedAt,
  );
  BudgetAlertRow copyWithCompanion(BudgetAlertsCompanion data) {
    return BudgetAlertRow(
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      periodKey: data.periodKey.present ? data.periodKey.value : this.periodKey,
      level: data.level.present ? data.level.value : this.level,
      firedAt: data.firedAt.present ? data.firedAt.value : this.firedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BudgetAlertRow(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('periodKey: $periodKey, ')
          ..write('level: $level, ')
          ..write('firedAt: $firedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, categoryId, periodKey, level, firedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BudgetAlertRow &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.periodKey == this.periodKey &&
          other.level == this.level &&
          other.firedAt == this.firedAt);
}

class BudgetAlertsCompanion extends UpdateCompanion<BudgetAlertRow> {
  final Value<int> id;
  final Value<int> categoryId;
  final Value<String> periodKey;
  final Value<AlertLevel> level;
  final Value<DateTime> firedAt;
  const BudgetAlertsCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.periodKey = const Value.absent(),
    this.level = const Value.absent(),
    this.firedAt = const Value.absent(),
  });
  BudgetAlertsCompanion.insert({
    this.id = const Value.absent(),
    required int categoryId,
    required String periodKey,
    required AlertLevel level,
    this.firedAt = const Value.absent(),
  }) : categoryId = Value(categoryId),
       periodKey = Value(periodKey),
       level = Value(level);
  static Insertable<BudgetAlertRow> custom({
    Expression<int>? id,
    Expression<int>? categoryId,
    Expression<String>? periodKey,
    Expression<String>? level,
    Expression<DateTime>? firedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (periodKey != null) 'period_key': periodKey,
      if (level != null) 'level': level,
      if (firedAt != null) 'fired_at': firedAt,
    });
  }

  BudgetAlertsCompanion copyWith({
    Value<int>? id,
    Value<int>? categoryId,
    Value<String>? periodKey,
    Value<AlertLevel>? level,
    Value<DateTime>? firedAt,
  }) {
    return BudgetAlertsCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      periodKey: periodKey ?? this.periodKey,
      level: level ?? this.level,
      firedAt: firedAt ?? this.firedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (periodKey.present) {
      map['period_key'] = Variable<String>(periodKey.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(
        $BudgetAlertsTable.$converterlevel.toSql(level.value),
      );
    }
    if (firedAt.present) {
      map['fired_at'] = Variable<DateTime>(firedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetAlertsCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('periodKey: $periodKey, ')
          ..write('level: $level, ')
          ..write('firedAt: $firedAt')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, TagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 30,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, colorValue];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {name},
  ];
  @override
  TagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class TagRow extends DataClass implements Insertable<TagRow> {
  final int id;
  final String name;
  final int colorValue;
  const TagRow({
    required this.id,
    required this.name,
    required this.colorValue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color_value'] = Variable<int>(colorValue);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      colorValue: Value(colorValue),
    );
  }

  factory TagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'colorValue': serializer.toJson<int>(colorValue),
    };
  }

  TagRow copyWith({int? id, String? name, int? colorValue}) => TagRow(
    id: id ?? this.id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
  );
  TagRow copyWithCompanion(TagsCompanion data) {
    return TagRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, colorValue);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorValue == this.colorValue);
}

class TagsCompanion extends UpdateCompanion<TagRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> colorValue;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorValue = const Value.absent(),
  });
  TagsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int colorValue,
  }) : name = Value(name),
       colorValue = Value(colorValue);
  static Insertable<TagRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? colorValue,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorValue != null) 'color_value': colorValue,
    });
  }

  TagsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? colorValue,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue')
          ..write(')'))
        .toString();
  }
}

class $TransactionTagsTable extends TransactionTags
    with TableInfo<$TransactionTagsTable, TransactionTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
    'transaction_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transactions (id)',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [transactionId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transaction_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransactionTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {transactionId, tagId};
  @override
  TransactionTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionTagRow(
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transaction_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $TransactionTagsTable createAlias(String alias) {
    return $TransactionTagsTable(attachedDatabase, alias);
  }
}

class TransactionTagRow extends DataClass
    implements Insertable<TransactionTagRow> {
  final int transactionId;
  final int tagId;
  const TransactionTagRow({required this.transactionId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['transaction_id'] = Variable<int>(transactionId);
    map['tag_id'] = Variable<int>(tagId);
    return map;
  }

  TransactionTagsCompanion toCompanion(bool nullToAbsent) {
    return TransactionTagsCompanion(
      transactionId: Value(transactionId),
      tagId: Value(tagId),
    );
  }

  factory TransactionTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionTagRow(
      transactionId: serializer.fromJson<int>(json['transactionId']),
      tagId: serializer.fromJson<int>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'transactionId': serializer.toJson<int>(transactionId),
      'tagId': serializer.toJson<int>(tagId),
    };
  }

  TransactionTagRow copyWith({int? transactionId, int? tagId}) =>
      TransactionTagRow(
        transactionId: transactionId ?? this.transactionId,
        tagId: tagId ?? this.tagId,
      );
  TransactionTagRow copyWithCompanion(TransactionTagsCompanion data) {
    return TransactionTagRow(
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionTagRow(')
          ..write('transactionId: $transactionId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(transactionId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionTagRow &&
          other.transactionId == this.transactionId &&
          other.tagId == this.tagId);
}

class TransactionTagsCompanion extends UpdateCompanion<TransactionTagRow> {
  final Value<int> transactionId;
  final Value<int> tagId;
  final Value<int> rowid;
  const TransactionTagsCompanion({
    this.transactionId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionTagsCompanion.insert({
    required int transactionId,
    required int tagId,
    this.rowid = const Value.absent(),
  }) : transactionId = Value(transactionId),
       tagId = Value(tagId);
  static Insertable<TransactionTagRow> custom({
    Expression<int>? transactionId,
    Expression<int>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (transactionId != null) 'transaction_id': transactionId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionTagsCompanion copyWith({
    Value<int>? transactionId,
    Value<int>? tagId,
    Value<int>? rowid,
  }) {
    return TransactionTagsCompanion(
      transactionId: transactionId ?? this.transactionId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionTagsCompanion(')
          ..write('transactionId: $transactionId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionSplitsTable extends TransactionSplits
    with TableInfo<$TransactionSplitsTable, TransactionSplitRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionSplitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
    'transaction_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transactions (id)',
    ),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<Money, int> amount =
      GeneratedColumn<int>(
        'amount',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Money>($TransactionSplitsTable.$converteramount);
  @override
  List<GeneratedColumn> get $columns => [id, transactionId, categoryId, amount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transaction_splits';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransactionSplitRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionSplitRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionSplitRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transaction_id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      )!,
      amount: $TransactionSplitsTable.$converteramount.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}amount'],
        )!,
      ),
    );
  }

  @override
  $TransactionSplitsTable createAlias(String alias) {
    return $TransactionSplitsTable(attachedDatabase, alias);
  }

  static TypeConverter<Money, int> $converteramount = const MoneyConverter();
}

class TransactionSplitRow extends DataClass
    implements Insertable<TransactionSplitRow> {
  final int id;
  final int transactionId;
  final int categoryId;
  final Money amount;
  const TransactionSplitRow({
    required this.id,
    required this.transactionId,
    required this.categoryId,
    required this.amount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['transaction_id'] = Variable<int>(transactionId);
    map['category_id'] = Variable<int>(categoryId);
    {
      map['amount'] = Variable<int>(
        $TransactionSplitsTable.$converteramount.toSql(amount),
      );
    }
    return map;
  }

  TransactionSplitsCompanion toCompanion(bool nullToAbsent) {
    return TransactionSplitsCompanion(
      id: Value(id),
      transactionId: Value(transactionId),
      categoryId: Value(categoryId),
      amount: Value(amount),
    );
  }

  factory TransactionSplitRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionSplitRow(
      id: serializer.fromJson<int>(json['id']),
      transactionId: serializer.fromJson<int>(json['transactionId']),
      categoryId: serializer.fromJson<int>(json['categoryId']),
      amount: serializer.fromJson<Money>(json['amount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'transactionId': serializer.toJson<int>(transactionId),
      'categoryId': serializer.toJson<int>(categoryId),
      'amount': serializer.toJson<Money>(amount),
    };
  }

  TransactionSplitRow copyWith({
    int? id,
    int? transactionId,
    int? categoryId,
    Money? amount,
  }) => TransactionSplitRow(
    id: id ?? this.id,
    transactionId: transactionId ?? this.transactionId,
    categoryId: categoryId ?? this.categoryId,
    amount: amount ?? this.amount,
  );
  TransactionSplitRow copyWithCompanion(TransactionSplitsCompanion data) {
    return TransactionSplitRow(
      id: data.id.present ? data.id.value : this.id,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      amount: data.amount.present ? data.amount.value : this.amount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionSplitRow(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, transactionId, categoryId, amount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionSplitRow &&
          other.id == this.id &&
          other.transactionId == this.transactionId &&
          other.categoryId == this.categoryId &&
          other.amount == this.amount);
}

class TransactionSplitsCompanion extends UpdateCompanion<TransactionSplitRow> {
  final Value<int> id;
  final Value<int> transactionId;
  final Value<int> categoryId;
  final Value<Money> amount;
  const TransactionSplitsCompanion({
    this.id = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.amount = const Value.absent(),
  });
  TransactionSplitsCompanion.insert({
    this.id = const Value.absent(),
    required int transactionId,
    required int categoryId,
    required Money amount,
  }) : transactionId = Value(transactionId),
       categoryId = Value(categoryId),
       amount = Value(amount);
  static Insertable<TransactionSplitRow> custom({
    Expression<int>? id,
    Expression<int>? transactionId,
    Expression<int>? categoryId,
    Expression<int>? amount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (transactionId != null) 'transaction_id': transactionId,
      if (categoryId != null) 'category_id': categoryId,
      if (amount != null) 'amount': amount,
    });
  }

  TransactionSplitsCompanion copyWith({
    Value<int>? id,
    Value<int>? transactionId,
    Value<int>? categoryId,
    Value<Money>? amount,
  }) {
    return TransactionSplitsCompanion(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(
        $TransactionSplitsTable.$converteramount.toSql(amount.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionSplitsCompanion(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount')
          ..write(')'))
        .toString();
  }
}

class $GoalDetailsTable extends GoalDetails
    with TableInfo<$GoalDetailsTable, GoalDetailRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalDetailsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<Money, int> targetAmount =
      GeneratedColumn<int>(
        'target_amount',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Money>($GoalDetailsTable.$convertertargetAmount);
  static const VerificationMeta _targetDateMeta = const VerificationMeta(
    'targetDate',
  );
  @override
  late final GeneratedColumn<DateTime> targetDate = GeneratedColumn<DateTime>(
    'target_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [accountId, targetAmount, targetDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goal_details';
  @override
  VerificationContext validateIntegrity(
    Insertable<GoalDetailRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    }
    if (data.containsKey('target_date')) {
      context.handle(
        _targetDateMeta,
        targetDate.isAcceptableOrUnknown(data['target_date']!, _targetDateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId};
  @override
  GoalDetailRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoalDetailRow(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
      targetAmount: $GoalDetailsTable.$convertertargetAmount.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}target_amount'],
        )!,
      ),
      targetDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}target_date'],
      ),
    );
  }

  @override
  $GoalDetailsTable createAlias(String alias) {
    return $GoalDetailsTable(attachedDatabase, alias);
  }

  static TypeConverter<Money, int> $convertertargetAmount =
      const MoneyConverter();
}

class GoalDetailRow extends DataClass implements Insertable<GoalDetailRow> {
  final int accountId;
  final Money targetAmount;
  final DateTime? targetDate;
  const GoalDetailRow({
    required this.accountId,
    required this.targetAmount,
    this.targetDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<int>(accountId);
    {
      map['target_amount'] = Variable<int>(
        $GoalDetailsTable.$convertertargetAmount.toSql(targetAmount),
      );
    }
    if (!nullToAbsent || targetDate != null) {
      map['target_date'] = Variable<DateTime>(targetDate);
    }
    return map;
  }

  GoalDetailsCompanion toCompanion(bool nullToAbsent) {
    return GoalDetailsCompanion(
      accountId: Value(accountId),
      targetAmount: Value(targetAmount),
      targetDate: targetDate == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDate),
    );
  }

  factory GoalDetailRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoalDetailRow(
      accountId: serializer.fromJson<int>(json['accountId']),
      targetAmount: serializer.fromJson<Money>(json['targetAmount']),
      targetDate: serializer.fromJson<DateTime?>(json['targetDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<int>(accountId),
      'targetAmount': serializer.toJson<Money>(targetAmount),
      'targetDate': serializer.toJson<DateTime?>(targetDate),
    };
  }

  GoalDetailRow copyWith({
    int? accountId,
    Money? targetAmount,
    Value<DateTime?> targetDate = const Value.absent(),
  }) => GoalDetailRow(
    accountId: accountId ?? this.accountId,
    targetAmount: targetAmount ?? this.targetAmount,
    targetDate: targetDate.present ? targetDate.value : this.targetDate,
  );
  GoalDetailRow copyWithCompanion(GoalDetailsCompanion data) {
    return GoalDetailRow(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      targetAmount: data.targetAmount.present
          ? data.targetAmount.value
          : this.targetAmount,
      targetDate: data.targetDate.present
          ? data.targetDate.value
          : this.targetDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoalDetailRow(')
          ..write('accountId: $accountId, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('targetDate: $targetDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, targetAmount, targetDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalDetailRow &&
          other.accountId == this.accountId &&
          other.targetAmount == this.targetAmount &&
          other.targetDate == this.targetDate);
}

class GoalDetailsCompanion extends UpdateCompanion<GoalDetailRow> {
  final Value<int> accountId;
  final Value<Money> targetAmount;
  final Value<DateTime?> targetDate;
  const GoalDetailsCompanion({
    this.accountId = const Value.absent(),
    this.targetAmount = const Value.absent(),
    this.targetDate = const Value.absent(),
  });
  GoalDetailsCompanion.insert({
    this.accountId = const Value.absent(),
    required Money targetAmount,
    this.targetDate = const Value.absent(),
  }) : targetAmount = Value(targetAmount);
  static Insertable<GoalDetailRow> custom({
    Expression<int>? accountId,
    Expression<int>? targetAmount,
    Expression<DateTime>? targetDate,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (targetAmount != null) 'target_amount': targetAmount,
      if (targetDate != null) 'target_date': targetDate,
    });
  }

  GoalDetailsCompanion copyWith({
    Value<int>? accountId,
    Value<Money>? targetAmount,
    Value<DateTime?>? targetDate,
  }) {
    return GoalDetailsCompanion(
      accountId: accountId ?? this.accountId,
      targetAmount: targetAmount ?? this.targetAmount,
      targetDate: targetDate ?? this.targetDate,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (targetAmount.present) {
      map['target_amount'] = Variable<int>(
        $GoalDetailsTable.$convertertargetAmount.toSql(targetAmount.value),
      );
    }
    if (targetDate.present) {
      map['target_date'] = Variable<DateTime>(targetDate.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalDetailsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('targetDate: $targetDate')
          ..write(')'))
        .toString();
  }
}

class $ShoppingListsTable extends ShoppingLists
    with TableInfo<$ShoppingListsTable, ShoppingListRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShoppingListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 60,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, colorValue, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shopping_lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShoppingListRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShoppingListRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShoppingListRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ShoppingListsTable createAlias(String alias) {
    return $ShoppingListsTable(attachedDatabase, alias);
  }
}

class ShoppingListRow extends DataClass implements Insertable<ShoppingListRow> {
  final int id;
  final String name;
  final int colorValue;
  final DateTime createdAt;
  const ShoppingListRow({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color_value'] = Variable<int>(colorValue);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ShoppingListsCompanion toCompanion(bool nullToAbsent) {
    return ShoppingListsCompanion(
      id: Value(id),
      name: Value(name),
      colorValue: Value(colorValue),
      createdAt: Value(createdAt),
    );
  }

  factory ShoppingListRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShoppingListRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'colorValue': serializer.toJson<int>(colorValue),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ShoppingListRow copyWith({
    int? id,
    String? name,
    int? colorValue,
    DateTime? createdAt,
  }) => ShoppingListRow(
    id: id ?? this.id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    createdAt: createdAt ?? this.createdAt,
  );
  ShoppingListRow copyWithCompanion(ShoppingListsCompanion data) {
    return ShoppingListRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingListRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, colorValue, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShoppingListRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorValue == this.colorValue &&
          other.createdAt == this.createdAt);
}

class ShoppingListsCompanion extends UpdateCompanion<ShoppingListRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> colorValue;
  final Value<DateTime> createdAt;
  const ShoppingListsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ShoppingListsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int colorValue,
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       colorValue = Value(colorValue);
  static Insertable<ShoppingListRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? colorValue,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorValue != null) 'color_value': colorValue,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ShoppingListsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? colorValue,
    Value<DateTime>? createdAt,
  }) {
    return ShoppingListsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingListsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ShoppingItemsTable extends ShoppingItems
    with TableInfo<$ShoppingItemsTable, ShoppingItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShoppingItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<int> listId = GeneratedColumn<int>(
    'list_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shopping_lists (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Money?, int> estimatedAmount =
      GeneratedColumn<int>(
        'estimated_amount',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<Money?>($ShoppingItemsTable.$converterestimatedAmountn);
  static const VerificationMeta _isCheckedMeta = const VerificationMeta(
    'isChecked',
  );
  @override
  late final GeneratedColumn<bool> isChecked = GeneratedColumn<bool>(
    'is_checked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_checked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    listId,
    name,
    estimatedAmount,
    isChecked,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shopping_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShoppingItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_checked')) {
      context.handle(
        _isCheckedMeta,
        isChecked.isAcceptableOrUnknown(data['is_checked']!, _isCheckedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShoppingItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShoppingItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}list_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      estimatedAmount: $ShoppingItemsTable.$converterestimatedAmountn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}estimated_amount'],
        ),
      ),
      isChecked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_checked'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ShoppingItemsTable createAlias(String alias) {
    return $ShoppingItemsTable(attachedDatabase, alias);
  }

  static TypeConverter<Money, int> $converterestimatedAmount =
      const MoneyConverter();
  static TypeConverter<Money?, int?> $converterestimatedAmountn =
      NullAwareTypeConverter.wrap($converterestimatedAmount);
}

class ShoppingItemRow extends DataClass implements Insertable<ShoppingItemRow> {
  final int id;

  /// Nullable only because SQLite can't add a NOT NULL column to a table
  /// that already has rows without a default — every item made before named
  /// lists existed gets backfilled onto one default list during the v17
  /// migration, and every item from then on always gets one at insert time
  /// (see AppDatabase.addShoppingItem). Never actually null in practice.
  final int? listId;
  final String name;
  final Money? estimatedAmount;
  final bool isChecked;
  final DateTime createdAt;
  const ShoppingItemRow({
    required this.id,
    this.listId,
    required this.name,
    this.estimatedAmount,
    required this.isChecked,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || listId != null) {
      map['list_id'] = Variable<int>(listId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || estimatedAmount != null) {
      map['estimated_amount'] = Variable<int>(
        $ShoppingItemsTable.$converterestimatedAmountn.toSql(estimatedAmount),
      );
    }
    map['is_checked'] = Variable<bool>(isChecked);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ShoppingItemsCompanion toCompanion(bool nullToAbsent) {
    return ShoppingItemsCompanion(
      id: Value(id),
      listId: listId == null && nullToAbsent
          ? const Value.absent()
          : Value(listId),
      name: Value(name),
      estimatedAmount: estimatedAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(estimatedAmount),
      isChecked: Value(isChecked),
      createdAt: Value(createdAt),
    );
  }

  factory ShoppingItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShoppingItemRow(
      id: serializer.fromJson<int>(json['id']),
      listId: serializer.fromJson<int?>(json['listId']),
      name: serializer.fromJson<String>(json['name']),
      estimatedAmount: serializer.fromJson<Money?>(json['estimatedAmount']),
      isChecked: serializer.fromJson<bool>(json['isChecked']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'listId': serializer.toJson<int?>(listId),
      'name': serializer.toJson<String>(name),
      'estimatedAmount': serializer.toJson<Money?>(estimatedAmount),
      'isChecked': serializer.toJson<bool>(isChecked),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ShoppingItemRow copyWith({
    int? id,
    Value<int?> listId = const Value.absent(),
    String? name,
    Value<Money?> estimatedAmount = const Value.absent(),
    bool? isChecked,
    DateTime? createdAt,
  }) => ShoppingItemRow(
    id: id ?? this.id,
    listId: listId.present ? listId.value : this.listId,
    name: name ?? this.name,
    estimatedAmount: estimatedAmount.present
        ? estimatedAmount.value
        : this.estimatedAmount,
    isChecked: isChecked ?? this.isChecked,
    createdAt: createdAt ?? this.createdAt,
  );
  ShoppingItemRow copyWithCompanion(ShoppingItemsCompanion data) {
    return ShoppingItemRow(
      id: data.id.present ? data.id.value : this.id,
      listId: data.listId.present ? data.listId.value : this.listId,
      name: data.name.present ? data.name.value : this.name,
      estimatedAmount: data.estimatedAmount.present
          ? data.estimatedAmount.value
          : this.estimatedAmount,
      isChecked: data.isChecked.present ? data.isChecked.value : this.isChecked,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingItemRow(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('name: $name, ')
          ..write('estimatedAmount: $estimatedAmount, ')
          ..write('isChecked: $isChecked, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, listId, name, estimatedAmount, isChecked, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShoppingItemRow &&
          other.id == this.id &&
          other.listId == this.listId &&
          other.name == this.name &&
          other.estimatedAmount == this.estimatedAmount &&
          other.isChecked == this.isChecked &&
          other.createdAt == this.createdAt);
}

class ShoppingItemsCompanion extends UpdateCompanion<ShoppingItemRow> {
  final Value<int> id;
  final Value<int?> listId;
  final Value<String> name;
  final Value<Money?> estimatedAmount;
  final Value<bool> isChecked;
  final Value<DateTime> createdAt;
  const ShoppingItemsCompanion({
    this.id = const Value.absent(),
    this.listId = const Value.absent(),
    this.name = const Value.absent(),
    this.estimatedAmount = const Value.absent(),
    this.isChecked = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ShoppingItemsCompanion.insert({
    this.id = const Value.absent(),
    this.listId = const Value.absent(),
    required String name,
    this.estimatedAmount = const Value.absent(),
    this.isChecked = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<ShoppingItemRow> custom({
    Expression<int>? id,
    Expression<int>? listId,
    Expression<String>? name,
    Expression<int>? estimatedAmount,
    Expression<bool>? isChecked,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (listId != null) 'list_id': listId,
      if (name != null) 'name': name,
      if (estimatedAmount != null) 'estimated_amount': estimatedAmount,
      if (isChecked != null) 'is_checked': isChecked,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ShoppingItemsCompanion copyWith({
    Value<int>? id,
    Value<int?>? listId,
    Value<String>? name,
    Value<Money?>? estimatedAmount,
    Value<bool>? isChecked,
    Value<DateTime>? createdAt,
  }) {
    return ShoppingItemsCompanion(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      name: name ?? this.name,
      estimatedAmount: estimatedAmount ?? this.estimatedAmount,
      isChecked: isChecked ?? this.isChecked,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<int>(listId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (estimatedAmount.present) {
      map['estimated_amount'] = Variable<int>(
        $ShoppingItemsTable.$converterestimatedAmountn.toSql(
          estimatedAmount.value,
        ),
      );
    }
    if (isChecked.present) {
      map['is_checked'] = Variable<bool>(isChecked.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingItemsCompanion(')
          ..write('id: $id, ')
          ..write('listId: $listId, ')
          ..write('name: $name, ')
          ..write('estimatedAmount: $estimatedAmount, ')
          ..write('isChecked: $isChecked, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $BackupRecordsTable extends BackupRecords
    with TableInfo<$BackupRecordsTable, BackupRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BackupRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uriMeta = const VerificationMeta('uri');
  @override
  late final GeneratedColumn<String> uri = GeneratedColumn<String>(
    'uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fileName,
    uri,
    sizeBytes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'backup_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<BackupRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('uri')) {
      context.handle(
        _uriMeta,
        uri.isAcceptableOrUnknown(data['uri']!, _uriMeta),
      );
    } else if (isInserting) {
      context.missing(_uriMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {fileName},
  ];
  @override
  BackupRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BackupRecordRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      uri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uri'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BackupRecordsTable createAlias(String alias) {
    return $BackupRecordsTable(attachedDatabase, alias);
  }
}

class BackupRecordRow extends DataClass implements Insertable<BackupRecordRow> {
  final int id;
  final String fileName;

  /// A MediaStore `content://` URI — the only reliable handle once a file is
  /// written, since scoped storage never promises a stable filesystem path.
  final String uri;
  final int sizeBytes;
  final DateTime createdAt;
  const BackupRecordRow({
    required this.id,
    required this.fileName,
    required this.uri,
    required this.sizeBytes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['file_name'] = Variable<String>(fileName);
    map['uri'] = Variable<String>(uri);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BackupRecordsCompanion toCompanion(bool nullToAbsent) {
    return BackupRecordsCompanion(
      id: Value(id),
      fileName: Value(fileName),
      uri: Value(uri),
      sizeBytes: Value(sizeBytes),
      createdAt: Value(createdAt),
    );
  }

  factory BackupRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BackupRecordRow(
      id: serializer.fromJson<int>(json['id']),
      fileName: serializer.fromJson<String>(json['fileName']),
      uri: serializer.fromJson<String>(json['uri']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fileName': serializer.toJson<String>(fileName),
      'uri': serializer.toJson<String>(uri),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BackupRecordRow copyWith({
    int? id,
    String? fileName,
    String? uri,
    int? sizeBytes,
    DateTime? createdAt,
  }) => BackupRecordRow(
    id: id ?? this.id,
    fileName: fileName ?? this.fileName,
    uri: uri ?? this.uri,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    createdAt: createdAt ?? this.createdAt,
  );
  BackupRecordRow copyWithCompanion(BackupRecordsCompanion data) {
    return BackupRecordRow(
      id: data.id.present ? data.id.value : this.id,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      uri: data.uri.present ? data.uri.value : this.uri,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BackupRecordRow(')
          ..write('id: $id, ')
          ..write('fileName: $fileName, ')
          ..write('uri: $uri, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, fileName, uri, sizeBytes, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BackupRecordRow &&
          other.id == this.id &&
          other.fileName == this.fileName &&
          other.uri == this.uri &&
          other.sizeBytes == this.sizeBytes &&
          other.createdAt == this.createdAt);
}

class BackupRecordsCompanion extends UpdateCompanion<BackupRecordRow> {
  final Value<int> id;
  final Value<String> fileName;
  final Value<String> uri;
  final Value<int> sizeBytes;
  final Value<DateTime> createdAt;
  const BackupRecordsCompanion({
    this.id = const Value.absent(),
    this.fileName = const Value.absent(),
    this.uri = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BackupRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String fileName,
    required String uri,
    this.sizeBytes = const Value.absent(),
    required DateTime createdAt,
  }) : fileName = Value(fileName),
       uri = Value(uri),
       createdAt = Value(createdAt);
  static Insertable<BackupRecordRow> custom({
    Expression<int>? id,
    Expression<String>? fileName,
    Expression<String>? uri,
    Expression<int>? sizeBytes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fileName != null) 'file_name': fileName,
      if (uri != null) 'uri': uri,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BackupRecordsCompanion copyWith({
    Value<int>? id,
    Value<String>? fileName,
    Value<String>? uri,
    Value<int>? sizeBytes,
    Value<DateTime>? createdAt,
  }) {
    return BackupRecordsCompanion(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      uri: uri ?? this.uri,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (uri.present) {
      map['uri'] = Variable<String>(uri.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BackupRecordsCompanion(')
          ..write('id: $id, ')
          ..write('fileName: $fileName, ')
          ..write('uri: $uri, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $PersonsTable persons = $PersonsTable(this);
  late final $RecurringRulesTable recurringRules = $RecurringRulesTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $BudgetsTable budgets = $BudgetsTable(this);
  late final $PersonEntriesTable personEntries = $PersonEntriesTable(this);
  late final $RemindersTable reminders = $RemindersTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $PendingTxnsTable pendingTxns = $PendingTxnsTable(this);
  late final $MerchantRulesTable merchantRules = $MerchantRulesTable(this);
  late final $SenderRulesTable senderRules = $SenderRulesTable(this);
  late final $BudgetAlertsTable budgetAlerts = $BudgetAlertsTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $TransactionTagsTable transactionTags = $TransactionTagsTable(
    this,
  );
  late final $TransactionSplitsTable transactionSplits =
      $TransactionSplitsTable(this);
  late final $GoalDetailsTable goalDetails = $GoalDetailsTable(this);
  late final $ShoppingListsTable shoppingLists = $ShoppingListsTable(this);
  late final $ShoppingItemsTable shoppingItems = $ShoppingItemsTable(this);
  late final $BackupRecordsTable backupRecords = $BackupRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    categories,
    persons,
    recurringRules,
    transactions,
    budgets,
    personEntries,
    reminders,
    settings,
    pendingTxns,
    merchantRules,
    senderRules,
    budgetAlerts,
    tags,
    transactionTags,
    transactionSplits,
    goalDetails,
    shoppingLists,
    shoppingItems,
    backupRecords,
  ];
}

typedef $$AccountsTableCreateCompanionBuilder =
    AccountsCompanion Function({
      Value<int> id,
      required String name,
      required AccountType type,
      Value<CardKind?> cardKind,
      Value<int?> linkedAccountId,
      Value<String?> bankName,
      Value<String?> last4,
      required int colorValue,
      required String iconKey,
      required Money openingBalance,
      required Money currentBalance,
      Value<bool> isArchived,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
    });
typedef $$AccountsTableUpdateCompanionBuilder =
    AccountsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<AccountType> type,
      Value<CardKind?> cardKind,
      Value<int?> linkedAccountId,
      Value<String?> bankName,
      Value<String?> last4,
      Value<int> colorValue,
      Value<String> iconKey,
      Value<Money> openingBalance,
      Value<Money> currentBalance,
      Value<bool> isArchived,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
    });

final class $$AccountsTableReferences
    extends BaseReferences<_$AppDatabase, $AccountsTable, AccountRow> {
  $$AccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _linkedAccountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.accounts.linkedAccountId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager? get linkedAccountId {
    final $_column = $_itemColumn<int>('linked_account_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_linkedAccountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RecurringRulesTable, List<RecurringRuleRow>>
  _recurringRulesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recurringRules,
    aliasName: $_aliasNameGenerator(
      db.accounts.id,
      db.recurringRules.accountId,
    ),
  );

  $$RecurringRulesTableProcessedTableManager get recurringRulesRefs {
    final manager = $$RecurringRulesTableTableManager(
      $_db,
      $_db.recurringRules,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_recurringRulesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PersonEntriesTable, List<PersonEntryRow>>
  _personEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.personEntries,
    aliasName: $_aliasNameGenerator(db.accounts.id, db.personEntries.accountId),
  );

  $$PersonEntriesTableProcessedTableManager get personEntriesRefs {
    final manager = $$PersonEntriesTableTableManager(
      $_db,
      $_db.personEntries,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_personEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RemindersTable, List<ReminderRow>>
  _remindersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reminders,
    aliasName: $_aliasNameGenerator(db.accounts.id, db.reminders.accountId),
  );

  $$RemindersTableProcessedTableManager get remindersRefs {
    final manager = $$RemindersTableTableManager(
      $_db,
      $_db.reminders,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_remindersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PendingTxnsTable, List<PendingTxnRow>>
  _pendingTxnsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.pendingTxns,
    aliasName: $_aliasNameGenerator(
      db.accounts.id,
      db.pendingTxns.matchedAccountId,
    ),
  );

  $$PendingTxnsTableProcessedTableManager get pendingTxnsRefs {
    final manager = $$PendingTxnsTableTableManager(
      $_db,
      $_db.pendingTxns,
    ).filter((f) => f.matchedAccountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_pendingTxnsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MerchantRulesTable, List<MerchantRuleRow>>
  _merchantRulesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.merchantRules,
    aliasName: $_aliasNameGenerator(db.accounts.id, db.merchantRules.accountId),
  );

  $$MerchantRulesTableProcessedTableManager get merchantRulesRefs {
    final manager = $$MerchantRulesTableTableManager(
      $_db,
      $_db.merchantRules,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_merchantRulesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$GoalDetailsTable, List<GoalDetailRow>>
  _goalDetailsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.goalDetails,
    aliasName: $_aliasNameGenerator(db.accounts.id, db.goalDetails.accountId),
  );

  $$GoalDetailsTableProcessedTableManager get goalDetailsRefs {
    final manager = $$GoalDetailsTableTableManager(
      $_db,
      $_db.goalDetails,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_goalDetailsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AccountType, AccountType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<CardKind?, CardKind, String> get cardKind =>
      $composableBuilder(
        column: $table.cardKind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get bankName => $composableBuilder(
    column: $table.bankName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get last4 => $composableBuilder(
    column: $table.last4,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Money, Money, int> get openingBalance =>
      $composableBuilder(
        column: $table.openingBalance,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Money, Money, int> get currentBalance =>
      $composableBuilder(
        column: $table.currentBalance,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get linkedAccountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> recurringRulesRefs(
    Expression<bool> Function($$RecurringRulesTableFilterComposer f) f,
  ) {
    final $$RecurringRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recurringRules,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringRulesTableFilterComposer(
            $db: $db,
            $table: $db.recurringRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> personEntriesRefs(
    Expression<bool> Function($$PersonEntriesTableFilterComposer f) f,
  ) {
    final $$PersonEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.personEntries,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonEntriesTableFilterComposer(
            $db: $db,
            $table: $db.personEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> remindersRefs(
    Expression<bool> Function($$RemindersTableFilterComposer f) f,
  ) {
    final $$RemindersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableFilterComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> pendingTxnsRefs(
    Expression<bool> Function($$PendingTxnsTableFilterComposer f) f,
  ) {
    final $$PendingTxnsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pendingTxns,
      getReferencedColumn: (t) => t.matchedAccountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PendingTxnsTableFilterComposer(
            $db: $db,
            $table: $db.pendingTxns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> merchantRulesRefs(
    Expression<bool> Function($$MerchantRulesTableFilterComposer f) f,
  ) {
    final $$MerchantRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.merchantRules,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MerchantRulesTableFilterComposer(
            $db: $db,
            $table: $db.merchantRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> goalDetailsRefs(
    Expression<bool> Function($$GoalDetailsTableFilterComposer f) f,
  ) {
    final $$GoalDetailsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.goalDetails,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalDetailsTableFilterComposer(
            $db: $db,
            $table: $db.goalDetails,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardKind => $composableBuilder(
    column: $table.cardKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bankName => $composableBuilder(
    column: $table.bankName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get last4 => $composableBuilder(
    column: $table.last4,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openingBalance => $composableBuilder(
    column: $table.openingBalance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentBalance => $composableBuilder(
    column: $table.currentBalance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get linkedAccountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AccountType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CardKind?, String> get cardKind =>
      $composableBuilder(column: $table.cardKind, builder: (column) => column);

  GeneratedColumn<String> get bankName =>
      $composableBuilder(column: $table.bankName, builder: (column) => column);

  GeneratedColumn<String> get last4 =>
      $composableBuilder(column: $table.last4, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Money, int> get openingBalance =>
      $composableBuilder(
        column: $table.openingBalance,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Money, int> get currentBalance =>
      $composableBuilder(
        column: $table.currentBalance,
        builder: (column) => column,
      );

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get linkedAccountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> recurringRulesRefs<T extends Object>(
    Expression<T> Function($$RecurringRulesTableAnnotationComposer a) f,
  ) {
    final $$RecurringRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recurringRules,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.recurringRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> personEntriesRefs<T extends Object>(
    Expression<T> Function($$PersonEntriesTableAnnotationComposer a) f,
  ) {
    final $$PersonEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.personEntries,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.personEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> remindersRefs<T extends Object>(
    Expression<T> Function($$RemindersTableAnnotationComposer a) f,
  ) {
    final $$RemindersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableAnnotationComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> pendingTxnsRefs<T extends Object>(
    Expression<T> Function($$PendingTxnsTableAnnotationComposer a) f,
  ) {
    final $$PendingTxnsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pendingTxns,
      getReferencedColumn: (t) => t.matchedAccountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PendingTxnsTableAnnotationComposer(
            $db: $db,
            $table: $db.pendingTxns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> merchantRulesRefs<T extends Object>(
    Expression<T> Function($$MerchantRulesTableAnnotationComposer a) f,
  ) {
    final $$MerchantRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.merchantRules,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MerchantRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.merchantRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> goalDetailsRefs<T extends Object>(
    Expression<T> Function($$GoalDetailsTableAnnotationComposer a) f,
  ) {
    final $$GoalDetailsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.goalDetails,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalDetailsTableAnnotationComposer(
            $db: $db,
            $table: $db.goalDetails,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountsTable,
          AccountRow,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (AccountRow, $$AccountsTableReferences),
          AccountRow,
          PrefetchHooks Function({
            bool linkedAccountId,
            bool recurringRulesRefs,
            bool personEntriesRefs,
            bool remindersRefs,
            bool pendingTxnsRefs,
            bool merchantRulesRefs,
            bool goalDetailsRefs,
          })
        > {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<AccountType> type = const Value.absent(),
                Value<CardKind?> cardKind = const Value.absent(),
                Value<int?> linkedAccountId = const Value.absent(),
                Value<String?> bankName = const Value.absent(),
                Value<String?> last4 = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<String> iconKey = const Value.absent(),
                Value<Money> openingBalance = const Value.absent(),
                Value<Money> currentBalance = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                name: name,
                type: type,
                cardKind: cardKind,
                linkedAccountId: linkedAccountId,
                bankName: bankName,
                last4: last4,
                colorValue: colorValue,
                iconKey: iconKey,
                openingBalance: openingBalance,
                currentBalance: currentBalance,
                isArchived: isArchived,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required AccountType type,
                Value<CardKind?> cardKind = const Value.absent(),
                Value<int?> linkedAccountId = const Value.absent(),
                Value<String?> bankName = const Value.absent(),
                Value<String?> last4 = const Value.absent(),
                required int colorValue,
                required String iconKey,
                required Money openingBalance,
                required Money currentBalance,
                Value<bool> isArchived = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                name: name,
                type: type,
                cardKind: cardKind,
                linkedAccountId: linkedAccountId,
                bankName: bankName,
                last4: last4,
                colorValue: colorValue,
                iconKey: iconKey,
                openingBalance: openingBalance,
                currentBalance: currentBalance,
                isArchived: isArchived,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                linkedAccountId = false,
                recurringRulesRefs = false,
                personEntriesRefs = false,
                remindersRefs = false,
                pendingTxnsRefs = false,
                merchantRulesRefs = false,
                goalDetailsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (recurringRulesRefs) db.recurringRules,
                    if (personEntriesRefs) db.personEntries,
                    if (remindersRefs) db.reminders,
                    if (pendingTxnsRefs) db.pendingTxns,
                    if (merchantRulesRefs) db.merchantRules,
                    if (goalDetailsRefs) db.goalDetails,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (linkedAccountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.linkedAccountId,
                                    referencedTable: $$AccountsTableReferences
                                        ._linkedAccountIdTable(db),
                                    referencedColumn: $$AccountsTableReferences
                                        ._linkedAccountIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (recurringRulesRefs)
                        await $_getPrefetchedData<
                          AccountRow,
                          $AccountsTable,
                          RecurringRuleRow
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._recurringRulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).recurringRulesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (personEntriesRefs)
                        await $_getPrefetchedData<
                          AccountRow,
                          $AccountsTable,
                          PersonEntryRow
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._personEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).personEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (remindersRefs)
                        await $_getPrefetchedData<
                          AccountRow,
                          $AccountsTable,
                          ReminderRow
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._remindersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).remindersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (pendingTxnsRefs)
                        await $_getPrefetchedData<
                          AccountRow,
                          $AccountsTable,
                          PendingTxnRow
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._pendingTxnsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).pendingTxnsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.matchedAccountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (merchantRulesRefs)
                        await $_getPrefetchedData<
                          AccountRow,
                          $AccountsTable,
                          MerchantRuleRow
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._merchantRulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).merchantRulesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (goalDetailsRefs)
                        await $_getPrefetchedData<
                          AccountRow,
                          $AccountsTable,
                          GoalDetailRow
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._goalDetailsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).goalDetailsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountsTable,
      AccountRow,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (AccountRow, $$AccountsTableReferences),
      AccountRow,
      PrefetchHooks Function({
        bool linkedAccountId,
        bool recurringRulesRefs,
        bool personEntriesRefs,
        bool remindersRefs,
        bool pendingTxnsRefs,
        bool merchantRulesRefs,
        bool goalDetailsRefs,
      })
    >;
typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      Value<int> id,
      required String name,
      required CategoryKind kind,
      required int colorValue,
      required String iconKey,
      Value<bool> isArchived,
      Value<int> sortOrder,
      Value<int?> parentId,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<CategoryKind> kind,
      Value<int> colorValue,
      Value<String> iconKey,
      Value<bool> isArchived,
      Value<int> sortOrder,
      Value<int?> parentId,
    });

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, CategoryRow> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RecurringRulesTable, List<RecurringRuleRow>>
  _recurringRulesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recurringRules,
    aliasName: $_aliasNameGenerator(
      db.categories.id,
      db.recurringRules.categoryId,
    ),
  );

  $$RecurringRulesTableProcessedTableManager get recurringRulesRefs {
    final manager = $$RecurringRulesTableTableManager(
      $_db,
      $_db.recurringRules,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_recurringRulesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TransactionsTable, List<TransactionRow>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: $_aliasNameGenerator(
      db.categories.id,
      db.transactions.categoryId,
    ),
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BudgetsTable, List<BudgetRow>> _budgetsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.budgets,
    aliasName: $_aliasNameGenerator(db.categories.id, db.budgets.categoryId),
  );

  $$BudgetsTableProcessedTableManager get budgetsRefs {
    final manager = $$BudgetsTableTableManager(
      $_db,
      $_db.budgets,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_budgetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PersonEntriesTable, List<PersonEntryRow>>
  _personEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.personEntries,
    aliasName: $_aliasNameGenerator(
      db.categories.id,
      db.personEntries.categoryId,
    ),
  );

  $$PersonEntriesTableProcessedTableManager get personEntriesRefs {
    final manager = $$PersonEntriesTableTableManager(
      $_db,
      $_db.personEntries,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_personEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RemindersTable, List<ReminderRow>>
  _remindersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reminders,
    aliasName: $_aliasNameGenerator(db.categories.id, db.reminders.categoryId),
  );

  $$RemindersTableProcessedTableManager get remindersRefs {
    final manager = $$RemindersTableTableManager(
      $_db,
      $_db.reminders,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_remindersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MerchantRulesTable, List<MerchantRuleRow>>
  _merchantRulesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.merchantRules,
    aliasName: $_aliasNameGenerator(
      db.categories.id,
      db.merchantRules.categoryId,
    ),
  );

  $$MerchantRulesTableProcessedTableManager get merchantRulesRefs {
    final manager = $$MerchantRulesTableTableManager(
      $_db,
      $_db.merchantRules,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_merchantRulesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BudgetAlertsTable, List<BudgetAlertRow>>
  _budgetAlertsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.budgetAlerts,
    aliasName: $_aliasNameGenerator(
      db.categories.id,
      db.budgetAlerts.categoryId,
    ),
  );

  $$BudgetAlertsTableProcessedTableManager get budgetAlertsRefs {
    final manager = $$BudgetAlertsTableTableManager(
      $_db,
      $_db.budgetAlerts,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_budgetAlertsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TransactionSplitsTable, List<TransactionSplitRow>>
  _transactionSplitsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.transactionSplits,
        aliasName: $_aliasNameGenerator(
          db.categories.id,
          db.transactionSplits.categoryId,
        ),
      );

  $$TransactionSplitsTableProcessedTableManager get transactionSplitsRefs {
    final manager = $$TransactionSplitsTableTableManager(
      $_db,
      $_db.transactionSplits,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _transactionSplitsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CategoryKind, CategoryKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> recurringRulesRefs(
    Expression<bool> Function($$RecurringRulesTableFilterComposer f) f,
  ) {
    final $$RecurringRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recurringRules,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringRulesTableFilterComposer(
            $db: $db,
            $table: $db.recurringRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> budgetsRefs(
    Expression<bool> Function($$BudgetsTableFilterComposer f) f,
  ) {
    final $$BudgetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgets,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetsTableFilterComposer(
            $db: $db,
            $table: $db.budgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> personEntriesRefs(
    Expression<bool> Function($$PersonEntriesTableFilterComposer f) f,
  ) {
    final $$PersonEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.personEntries,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonEntriesTableFilterComposer(
            $db: $db,
            $table: $db.personEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> remindersRefs(
    Expression<bool> Function($$RemindersTableFilterComposer f) f,
  ) {
    final $$RemindersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableFilterComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> merchantRulesRefs(
    Expression<bool> Function($$MerchantRulesTableFilterComposer f) f,
  ) {
    final $$MerchantRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.merchantRules,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MerchantRulesTableFilterComposer(
            $db: $db,
            $table: $db.merchantRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> budgetAlertsRefs(
    Expression<bool> Function($$BudgetAlertsTableFilterComposer f) f,
  ) {
    final $$BudgetAlertsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgetAlerts,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetAlertsTableFilterComposer(
            $db: $db,
            $table: $db.budgetAlerts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transactionSplitsRefs(
    Expression<bool> Function($$TransactionSplitsTableFilterComposer f) f,
  ) {
    final $$TransactionSplitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactionSplits,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionSplitsTableFilterComposer(
            $db: $db,
            $table: $db.transactionSplits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CategoryKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  Expression<T> recurringRulesRefs<T extends Object>(
    Expression<T> Function($$RecurringRulesTableAnnotationComposer a) f,
  ) {
    final $$RecurringRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recurringRules,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.recurringRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> budgetsRefs<T extends Object>(
    Expression<T> Function($$BudgetsTableAnnotationComposer a) f,
  ) {
    final $$BudgetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgets,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetsTableAnnotationComposer(
            $db: $db,
            $table: $db.budgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> personEntriesRefs<T extends Object>(
    Expression<T> Function($$PersonEntriesTableAnnotationComposer a) f,
  ) {
    final $$PersonEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.personEntries,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.personEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> remindersRefs<T extends Object>(
    Expression<T> Function($$RemindersTableAnnotationComposer a) f,
  ) {
    final $$RemindersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableAnnotationComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> merchantRulesRefs<T extends Object>(
    Expression<T> Function($$MerchantRulesTableAnnotationComposer a) f,
  ) {
    final $$MerchantRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.merchantRules,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MerchantRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.merchantRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> budgetAlertsRefs<T extends Object>(
    Expression<T> Function($$BudgetAlertsTableAnnotationComposer a) f,
  ) {
    final $$BudgetAlertsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgetAlerts,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetAlertsTableAnnotationComposer(
            $db: $db,
            $table: $db.budgetAlerts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transactionSplitsRefs<T extends Object>(
    Expression<T> Function($$TransactionSplitsTableAnnotationComposer a) f,
  ) {
    final $$TransactionSplitsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transactionSplits,
          getReferencedColumn: (t) => t.categoryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TransactionSplitsTableAnnotationComposer(
                $db: $db,
                $table: $db.transactionSplits,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          CategoryRow,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (CategoryRow, $$CategoriesTableReferences),
          CategoryRow,
          PrefetchHooks Function({
            bool recurringRulesRefs,
            bool transactionsRefs,
            bool budgetsRefs,
            bool personEntriesRefs,
            bool remindersRefs,
            bool merchantRulesRefs,
            bool budgetAlertsRefs,
            bool transactionSplitsRefs,
          })
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<CategoryKind> kind = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<String> iconKey = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int?> parentId = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                kind: kind,
                colorValue: colorValue,
                iconKey: iconKey,
                isArchived: isArchived,
                sortOrder: sortOrder,
                parentId: parentId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required CategoryKind kind,
                required int colorValue,
                required String iconKey,
                Value<bool> isArchived = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int?> parentId = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                kind: kind,
                colorValue: colorValue,
                iconKey: iconKey,
                isArchived: isArchived,
                sortOrder: sortOrder,
                parentId: parentId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                recurringRulesRefs = false,
                transactionsRefs = false,
                budgetsRefs = false,
                personEntriesRefs = false,
                remindersRefs = false,
                merchantRulesRefs = false,
                budgetAlertsRefs = false,
                transactionSplitsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (recurringRulesRefs) db.recurringRules,
                    if (transactionsRefs) db.transactions,
                    if (budgetsRefs) db.budgets,
                    if (personEntriesRefs) db.personEntries,
                    if (remindersRefs) db.reminders,
                    if (merchantRulesRefs) db.merchantRules,
                    if (budgetAlertsRefs) db.budgetAlerts,
                    if (transactionSplitsRefs) db.transactionSplits,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (recurringRulesRefs)
                        await $_getPrefetchedData<
                          CategoryRow,
                          $CategoriesTable,
                          RecurringRuleRow
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._recurringRulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).recurringRulesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transactionsRefs)
                        await $_getPrefetchedData<
                          CategoryRow,
                          $CategoriesTable,
                          TransactionRow
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (budgetsRefs)
                        await $_getPrefetchedData<
                          CategoryRow,
                          $CategoriesTable,
                          BudgetRow
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._budgetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).budgetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (personEntriesRefs)
                        await $_getPrefetchedData<
                          CategoryRow,
                          $CategoriesTable,
                          PersonEntryRow
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._personEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).personEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (remindersRefs)
                        await $_getPrefetchedData<
                          CategoryRow,
                          $CategoriesTable,
                          ReminderRow
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._remindersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).remindersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (merchantRulesRefs)
                        await $_getPrefetchedData<
                          CategoryRow,
                          $CategoriesTable,
                          MerchantRuleRow
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._merchantRulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).merchantRulesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (budgetAlertsRefs)
                        await $_getPrefetchedData<
                          CategoryRow,
                          $CategoriesTable,
                          BudgetAlertRow
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._budgetAlertsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).budgetAlertsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transactionSplitsRefs)
                        await $_getPrefetchedData<
                          CategoryRow,
                          $CategoriesTable,
                          TransactionSplitRow
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._transactionSplitsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionSplitsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      CategoryRow,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (CategoryRow, $$CategoriesTableReferences),
      CategoryRow,
      PrefetchHooks Function({
        bool recurringRulesRefs,
        bool transactionsRefs,
        bool budgetsRefs,
        bool personEntriesRefs,
        bool remindersRefs,
        bool merchantRulesRefs,
        bool budgetAlertsRefs,
        bool transactionSplitsRefs,
      })
    >;
typedef $$PersonsTableCreateCompanionBuilder =
    PersonsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> contact,
      Value<String?> note,
      Value<bool> isArchived,
      Value<DateTime> createdAt,
    });
typedef $$PersonsTableUpdateCompanionBuilder =
    PersonsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> contact,
      Value<String?> note,
      Value<bool> isArchived,
      Value<DateTime> createdAt,
    });

final class $$PersonsTableReferences
    extends BaseReferences<_$AppDatabase, $PersonsTable, PersonRow> {
  $$PersonsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TransactionsTable, List<TransactionRow>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: $_aliasNameGenerator(db.persons.id, db.transactions.personId),
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.personId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PersonEntriesTable, List<PersonEntryRow>>
  _personEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.personEntries,
    aliasName: $_aliasNameGenerator(db.persons.id, db.personEntries.personId),
  );

  $$PersonEntriesTableProcessedTableManager get personEntriesRefs {
    final manager = $$PersonEntriesTableTableManager(
      $_db,
      $_db.personEntries,
    ).filter((f) => f.personId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_personEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RemindersTable, List<ReminderRow>>
  _remindersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reminders,
    aliasName: $_aliasNameGenerator(db.persons.id, db.reminders.personId),
  );

  $$RemindersTableProcessedTableManager get remindersRefs {
    final manager = $$RemindersTableTableManager(
      $_db,
      $_db.reminders,
    ).filter((f) => f.personId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_remindersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PersonsTableFilterComposer
    extends Composer<_$AppDatabase, $PersonsTable> {
  $$PersonsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contact => $composableBuilder(
    column: $table.contact,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> personEntriesRefs(
    Expression<bool> Function($$PersonEntriesTableFilterComposer f) f,
  ) {
    final $$PersonEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.personEntries,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonEntriesTableFilterComposer(
            $db: $db,
            $table: $db.personEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> remindersRefs(
    Expression<bool> Function($$RemindersTableFilterComposer f) f,
  ) {
    final $$RemindersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableFilterComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PersonsTableOrderingComposer
    extends Composer<_$AppDatabase, $PersonsTable> {
  $$PersonsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contact => $composableBuilder(
    column: $table.contact,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PersonsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PersonsTable> {
  $$PersonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get contact =>
      $composableBuilder(column: $table.contact, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> personEntriesRefs<T extends Object>(
    Expression<T> Function($$PersonEntriesTableAnnotationComposer a) f,
  ) {
    final $$PersonEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.personEntries,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.personEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> remindersRefs<T extends Object>(
    Expression<T> Function($$RemindersTableAnnotationComposer a) f,
  ) {
    final $$RemindersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableAnnotationComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PersonsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PersonsTable,
          PersonRow,
          $$PersonsTableFilterComposer,
          $$PersonsTableOrderingComposer,
          $$PersonsTableAnnotationComposer,
          $$PersonsTableCreateCompanionBuilder,
          $$PersonsTableUpdateCompanionBuilder,
          (PersonRow, $$PersonsTableReferences),
          PersonRow,
          PrefetchHooks Function({
            bool transactionsRefs,
            bool personEntriesRefs,
            bool remindersRefs,
          })
        > {
  $$PersonsTableTableManager(_$AppDatabase db, $PersonsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PersonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PersonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PersonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> contact = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PersonsCompanion(
                id: id,
                name: name,
                contact: contact,
                note: note,
                isArchived: isArchived,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> contact = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PersonsCompanion.insert(
                id: id,
                name: name,
                contact: contact,
                note: note,
                isArchived: isArchived,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PersonsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                transactionsRefs = false,
                personEntriesRefs = false,
                remindersRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transactionsRefs) db.transactions,
                    if (personEntriesRefs) db.personEntries,
                    if (remindersRefs) db.reminders,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transactionsRefs)
                        await $_getPrefetchedData<
                          PersonRow,
                          $PersonsTable,
                          TransactionRow
                        >(
                          currentTable: table,
                          referencedTable: $$PersonsTableReferences
                              ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PersonsTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.personId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (personEntriesRefs)
                        await $_getPrefetchedData<
                          PersonRow,
                          $PersonsTable,
                          PersonEntryRow
                        >(
                          currentTable: table,
                          referencedTable: $$PersonsTableReferences
                              ._personEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PersonsTableReferences(
                                db,
                                table,
                                p0,
                              ).personEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.personId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (remindersRefs)
                        await $_getPrefetchedData<
                          PersonRow,
                          $PersonsTable,
                          ReminderRow
                        >(
                          currentTable: table,
                          referencedTable: $$PersonsTableReferences
                              ._remindersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PersonsTableReferences(
                                db,
                                table,
                                p0,
                              ).remindersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.personId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PersonsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PersonsTable,
      PersonRow,
      $$PersonsTableFilterComposer,
      $$PersonsTableOrderingComposer,
      $$PersonsTableAnnotationComposer,
      $$PersonsTableCreateCompanionBuilder,
      $$PersonsTableUpdateCompanionBuilder,
      (PersonRow, $$PersonsTableReferences),
      PersonRow,
      PrefetchHooks Function({
        bool transactionsRefs,
        bool personEntriesRefs,
        bool remindersRefs,
      })
    >;
typedef $$RecurringRulesTableCreateCompanionBuilder =
    RecurringRulesCompanion Function({
      Value<int> id,
      required String name,
      required CategoryKind kind,
      required Money amount,
      required int accountId,
      required int categoryId,
      Value<String?> payee,
      required RecurringFrequency frequency,
      Value<int?> dayOfMonth,
      required DateTime nextDueDate,
      Value<int> notifyDaysBefore,
      Value<bool> isActive,
      Value<bool> isEstimate,
      Value<DateTime> createdAt,
    });
typedef $$RecurringRulesTableUpdateCompanionBuilder =
    RecurringRulesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<CategoryKind> kind,
      Value<Money> amount,
      Value<int> accountId,
      Value<int> categoryId,
      Value<String?> payee,
      Value<RecurringFrequency> frequency,
      Value<int?> dayOfMonth,
      Value<DateTime> nextDueDate,
      Value<int> notifyDaysBefore,
      Value<bool> isActive,
      Value<bool> isEstimate,
      Value<DateTime> createdAt,
    });

final class $$RecurringRulesTableReferences
    extends
        BaseReferences<_$AppDatabase, $RecurringRulesTable, RecurringRuleRow> {
  $$RecurringRulesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.recurringRules.accountId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<int>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias(
        $_aliasNameGenerator(db.recurringRules.categoryId, db.categories.id),
      );

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<int>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TransactionsTable, List<TransactionRow>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: $_aliasNameGenerator(
      db.recurringRules.id,
      db.transactions.recurringRuleId,
    ),
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.recurringRuleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RecurringRulesTableFilterComposer
    extends Composer<_$AppDatabase, $RecurringRulesTable> {
  $$RecurringRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CategoryKind, CategoryKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Money, Money, int> get amount =>
      $composableBuilder(
        column: $table.amount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get payee => $composableBuilder(
    column: $table.payee,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RecurringFrequency, RecurringFrequency, String>
  get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextDueDate => $composableBuilder(
    column: $table.nextDueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notifyDaysBefore => $composableBuilder(
    column: $table.notifyDaysBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEstimate => $composableBuilder(
    column: $table.isEstimate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.recurringRuleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecurringRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecurringRulesTable> {
  $$RecurringRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payee => $composableBuilder(
    column: $table.payee,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextDueDate => $composableBuilder(
    column: $table.nextDueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notifyDaysBefore => $composableBuilder(
    column: $table.notifyDaysBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEstimate => $composableBuilder(
    column: $table.isEstimate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecurringRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecurringRulesTable> {
  $$RecurringRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CategoryKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Money, int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get payee =>
      $composableBuilder(column: $table.payee, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RecurringFrequency, String> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextDueDate => $composableBuilder(
    column: $table.nextDueDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get notifyDaysBefore => $composableBuilder(
    column: $table.notifyDaysBefore,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<bool> get isEstimate => $composableBuilder(
    column: $table.isEstimate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.recurringRuleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecurringRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecurringRulesTable,
          RecurringRuleRow,
          $$RecurringRulesTableFilterComposer,
          $$RecurringRulesTableOrderingComposer,
          $$RecurringRulesTableAnnotationComposer,
          $$RecurringRulesTableCreateCompanionBuilder,
          $$RecurringRulesTableUpdateCompanionBuilder,
          (RecurringRuleRow, $$RecurringRulesTableReferences),
          RecurringRuleRow,
          PrefetchHooks Function({
            bool accountId,
            bool categoryId,
            bool transactionsRefs,
          })
        > {
  $$RecurringRulesTableTableManager(
    _$AppDatabase db,
    $RecurringRulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecurringRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecurringRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecurringRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<CategoryKind> kind = const Value.absent(),
                Value<Money> amount = const Value.absent(),
                Value<int> accountId = const Value.absent(),
                Value<int> categoryId = const Value.absent(),
                Value<String?> payee = const Value.absent(),
                Value<RecurringFrequency> frequency = const Value.absent(),
                Value<int?> dayOfMonth = const Value.absent(),
                Value<DateTime> nextDueDate = const Value.absent(),
                Value<int> notifyDaysBefore = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<bool> isEstimate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => RecurringRulesCompanion(
                id: id,
                name: name,
                kind: kind,
                amount: amount,
                accountId: accountId,
                categoryId: categoryId,
                payee: payee,
                frequency: frequency,
                dayOfMonth: dayOfMonth,
                nextDueDate: nextDueDate,
                notifyDaysBefore: notifyDaysBefore,
                isActive: isActive,
                isEstimate: isEstimate,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required CategoryKind kind,
                required Money amount,
                required int accountId,
                required int categoryId,
                Value<String?> payee = const Value.absent(),
                required RecurringFrequency frequency,
                Value<int?> dayOfMonth = const Value.absent(),
                required DateTime nextDueDate,
                Value<int> notifyDaysBefore = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<bool> isEstimate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => RecurringRulesCompanion.insert(
                id: id,
                name: name,
                kind: kind,
                amount: amount,
                accountId: accountId,
                categoryId: categoryId,
                payee: payee,
                frequency: frequency,
                dayOfMonth: dayOfMonth,
                nextDueDate: nextDueDate,
                notifyDaysBefore: notifyDaysBefore,
                isActive: isActive,
                isEstimate: isEstimate,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RecurringRulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                accountId = false,
                categoryId = false,
                transactionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transactionsRefs) db.transactions,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (accountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.accountId,
                                    referencedTable:
                                        $$RecurringRulesTableReferences
                                            ._accountIdTable(db),
                                    referencedColumn:
                                        $$RecurringRulesTableReferences
                                            ._accountIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (categoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.categoryId,
                                    referencedTable:
                                        $$RecurringRulesTableReferences
                                            ._categoryIdTable(db),
                                    referencedColumn:
                                        $$RecurringRulesTableReferences
                                            ._categoryIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transactionsRefs)
                        await $_getPrefetchedData<
                          RecurringRuleRow,
                          $RecurringRulesTable,
                          TransactionRow
                        >(
                          currentTable: table,
                          referencedTable: $$RecurringRulesTableReferences
                              ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecurringRulesTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.recurringRuleId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RecurringRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecurringRulesTable,
      RecurringRuleRow,
      $$RecurringRulesTableFilterComposer,
      $$RecurringRulesTableOrderingComposer,
      $$RecurringRulesTableAnnotationComposer,
      $$RecurringRulesTableCreateCompanionBuilder,
      $$RecurringRulesTableUpdateCompanionBuilder,
      (RecurringRuleRow, $$RecurringRulesTableReferences),
      RecurringRuleRow,
      PrefetchHooks Function({
        bool accountId,
        bool categoryId,
        bool transactionsRefs,
      })
    >;
typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      Value<int> id,
      required TxType type,
      required Money amount,
      required int accountId,
      Value<int?> toAccountId,
      Value<int?> categoryId,
      Value<int?> personId,
      required DateTime date,
      Value<String?> note,
      Value<String?> payee,
      Value<int?> recurringRuleId,
      Value<String?> imagePath,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> needsAmountReview,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<int> id,
      Value<TxType> type,
      Value<Money> amount,
      Value<int> accountId,
      Value<int?> toAccountId,
      Value<int?> categoryId,
      Value<int?> personId,
      Value<DateTime> date,
      Value<String?> note,
      Value<String?> payee,
      Value<int?> recurringRuleId,
      Value<String?> imagePath,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> needsAmountReview,
    });

final class $$TransactionsTableReferences
    extends BaseReferences<_$AppDatabase, $TransactionsTable, TransactionRow> {
  $$TransactionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.transactions.accountId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<int>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AccountsTable _toAccountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.transactions.toAccountId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager? get toAccountId {
    final $_column = $_itemColumn<int>('to_account_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_toAccountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias(
        $_aliasNameGenerator(db.transactions.categoryId, db.categories.id),
      );

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<int>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PersonsTable _personIdTable(_$AppDatabase db) =>
      db.persons.createAlias(
        $_aliasNameGenerator(db.transactions.personId, db.persons.id),
      );

  $$PersonsTableProcessedTableManager? get personId {
    final $_column = $_itemColumn<int>('person_id');
    if ($_column == null) return null;
    final manager = $$PersonsTableTableManager(
      $_db,
      $_db.persons,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RecurringRulesTable _recurringRuleIdTable(_$AppDatabase db) =>
      db.recurringRules.createAlias(
        $_aliasNameGenerator(
          db.transactions.recurringRuleId,
          db.recurringRules.id,
        ),
      );

  $$RecurringRulesTableProcessedTableManager? get recurringRuleId {
    final $_column = $_itemColumn<int>('recurring_rule_id');
    if ($_column == null) return null;
    final manager = $$RecurringRulesTableTableManager(
      $_db,
      $_db.recurringRules,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recurringRuleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PersonEntriesTable, List<PersonEntryRow>>
  _personEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.personEntries,
    aliasName: $_aliasNameGenerator(
      db.transactions.id,
      db.personEntries.transactionId,
    ),
  );

  $$PersonEntriesTableProcessedTableManager get personEntriesRefs {
    final manager = $$PersonEntriesTableTableManager(
      $_db,
      $_db.personEntries,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_personEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RemindersTable, List<ReminderRow>>
  _remindersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reminders,
    aliasName: $_aliasNameGenerator(
      db.transactions.id,
      db.reminders.transactionId,
    ),
  );

  $$RemindersTableProcessedTableManager get remindersRefs {
    final manager = $$RemindersTableTableManager(
      $_db,
      $_db.reminders,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_remindersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PendingTxnsTable, List<PendingTxnRow>>
  _pendingTxnsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.pendingTxns,
    aliasName: $_aliasNameGenerator(
      db.transactions.id,
      db.pendingTxns.createdTransactionId,
    ),
  );

  $$PendingTxnsTableProcessedTableManager get pendingTxnsRefs {
    final manager = $$PendingTxnsTableTableManager($_db, $_db.pendingTxns)
        .filter(
          (f) => f.createdTransactionId.id.sqlEquals($_itemColumn<int>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(_pendingTxnsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TransactionTagsTable, List<TransactionTagRow>>
  _transactionTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactionTags,
    aliasName: $_aliasNameGenerator(
      db.transactions.id,
      db.transactionTags.transactionId,
    ),
  );

  $$TransactionTagsTableProcessedTableManager get transactionTagsRefs {
    final manager = $$TransactionTagsTableTableManager(
      $_db,
      $_db.transactionTags,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _transactionTagsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TransactionSplitsTable, List<TransactionSplitRow>>
  _transactionSplitsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.transactionSplits,
        aliasName: $_aliasNameGenerator(
          db.transactions.id,
          db.transactionSplits.transactionId,
        ),
      );

  $$TransactionSplitsTableProcessedTableManager get transactionSplitsRefs {
    final manager = $$TransactionSplitsTableTableManager(
      $_db,
      $_db.transactionSplits,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _transactionSplitsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TxType, TxType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Money, Money, int> get amount =>
      $composableBuilder(
        column: $table.amount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payee => $composableBuilder(
    column: $table.payee,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needsAmountReview => $composableBuilder(
    column: $table.needsAmountReview,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableFilterComposer get toAccountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.toAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PersonsTableFilterComposer get personId {
    final $$PersonsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.persons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonsTableFilterComposer(
            $db: $db,
            $table: $db.persons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RecurringRulesTableFilterComposer get recurringRuleId {
    final $$RecurringRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recurringRuleId,
      referencedTable: $db.recurringRules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringRulesTableFilterComposer(
            $db: $db,
            $table: $db.recurringRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> personEntriesRefs(
    Expression<bool> Function($$PersonEntriesTableFilterComposer f) f,
  ) {
    final $$PersonEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.personEntries,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonEntriesTableFilterComposer(
            $db: $db,
            $table: $db.personEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> remindersRefs(
    Expression<bool> Function($$RemindersTableFilterComposer f) f,
  ) {
    final $$RemindersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableFilterComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> pendingTxnsRefs(
    Expression<bool> Function($$PendingTxnsTableFilterComposer f) f,
  ) {
    final $$PendingTxnsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pendingTxns,
      getReferencedColumn: (t) => t.createdTransactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PendingTxnsTableFilterComposer(
            $db: $db,
            $table: $db.pendingTxns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transactionTagsRefs(
    Expression<bool> Function($$TransactionTagsTableFilterComposer f) f,
  ) {
    final $$TransactionTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactionTags,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionTagsTableFilterComposer(
            $db: $db,
            $table: $db.transactionTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transactionSplitsRefs(
    Expression<bool> Function($$TransactionSplitsTableFilterComposer f) f,
  ) {
    final $$TransactionSplitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactionSplits,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionSplitsTableFilterComposer(
            $db: $db,
            $table: $db.transactionSplits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payee => $composableBuilder(
    column: $table.payee,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needsAmountReview => $composableBuilder(
    column: $table.needsAmountReview,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableOrderingComposer get toAccountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.toAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PersonsTableOrderingComposer get personId {
    final $$PersonsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.persons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonsTableOrderingComposer(
            $db: $db,
            $table: $db.persons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RecurringRulesTableOrderingComposer get recurringRuleId {
    final $$RecurringRulesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recurringRuleId,
      referencedTable: $db.recurringRules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringRulesTableOrderingComposer(
            $db: $db,
            $table: $db.recurringRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TxType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Money, int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get payee =>
      $composableBuilder(column: $table.payee, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get needsAmountReview => $composableBuilder(
    column: $table.needsAmountReview,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableAnnotationComposer get toAccountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.toAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PersonsTableAnnotationComposer get personId {
    final $$PersonsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.persons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonsTableAnnotationComposer(
            $db: $db,
            $table: $db.persons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RecurringRulesTableAnnotationComposer get recurringRuleId {
    final $$RecurringRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recurringRuleId,
      referencedTable: $db.recurringRules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.recurringRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> personEntriesRefs<T extends Object>(
    Expression<T> Function($$PersonEntriesTableAnnotationComposer a) f,
  ) {
    final $$PersonEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.personEntries,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.personEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> remindersRefs<T extends Object>(
    Expression<T> Function($$RemindersTableAnnotationComposer a) f,
  ) {
    final $$RemindersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableAnnotationComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> pendingTxnsRefs<T extends Object>(
    Expression<T> Function($$PendingTxnsTableAnnotationComposer a) f,
  ) {
    final $$PendingTxnsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pendingTxns,
      getReferencedColumn: (t) => t.createdTransactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PendingTxnsTableAnnotationComposer(
            $db: $db,
            $table: $db.pendingTxns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transactionTagsRefs<T extends Object>(
    Expression<T> Function($$TransactionTagsTableAnnotationComposer a) f,
  ) {
    final $$TransactionTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactionTags,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactionTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transactionSplitsRefs<T extends Object>(
    Expression<T> Function($$TransactionSplitsTableAnnotationComposer a) f,
  ) {
    final $$TransactionSplitsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transactionSplits,
          getReferencedColumn: (t) => t.transactionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TransactionSplitsTableAnnotationComposer(
                $db: $db,
                $table: $db.transactionSplits,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionsTable,
          TransactionRow,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (TransactionRow, $$TransactionsTableReferences),
          TransactionRow,
          PrefetchHooks Function({
            bool accountId,
            bool toAccountId,
            bool categoryId,
            bool personId,
            bool recurringRuleId,
            bool personEntriesRefs,
            bool remindersRefs,
            bool pendingTxnsRefs,
            bool transactionTagsRefs,
            bool transactionSplitsRefs,
          })
        > {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<TxType> type = const Value.absent(),
                Value<Money> amount = const Value.absent(),
                Value<int> accountId = const Value.absent(),
                Value<int?> toAccountId = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<int?> personId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> payee = const Value.absent(),
                Value<int?> recurringRuleId = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> needsAmountReview = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                type: type,
                amount: amount,
                accountId: accountId,
                toAccountId: toAccountId,
                categoryId: categoryId,
                personId: personId,
                date: date,
                note: note,
                payee: payee,
                recurringRuleId: recurringRuleId,
                imagePath: imagePath,
                createdAt: createdAt,
                updatedAt: updatedAt,
                needsAmountReview: needsAmountReview,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required TxType type,
                required Money amount,
                required int accountId,
                Value<int?> toAccountId = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<int?> personId = const Value.absent(),
                required DateTime date,
                Value<String?> note = const Value.absent(),
                Value<String?> payee = const Value.absent(),
                Value<int?> recurringRuleId = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> needsAmountReview = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                type: type,
                amount: amount,
                accountId: accountId,
                toAccountId: toAccountId,
                categoryId: categoryId,
                personId: personId,
                date: date,
                note: note,
                payee: payee,
                recurringRuleId: recurringRuleId,
                imagePath: imagePath,
                createdAt: createdAt,
                updatedAt: updatedAt,
                needsAmountReview: needsAmountReview,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                accountId = false,
                toAccountId = false,
                categoryId = false,
                personId = false,
                recurringRuleId = false,
                personEntriesRefs = false,
                remindersRefs = false,
                pendingTxnsRefs = false,
                transactionTagsRefs = false,
                transactionSplitsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (personEntriesRefs) db.personEntries,
                    if (remindersRefs) db.reminders,
                    if (pendingTxnsRefs) db.pendingTxns,
                    if (transactionTagsRefs) db.transactionTags,
                    if (transactionSplitsRefs) db.transactionSplits,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (accountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.accountId,
                                    referencedTable:
                                        $$TransactionsTableReferences
                                            ._accountIdTable(db),
                                    referencedColumn:
                                        $$TransactionsTableReferences
                                            ._accountIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (toAccountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.toAccountId,
                                    referencedTable:
                                        $$TransactionsTableReferences
                                            ._toAccountIdTable(db),
                                    referencedColumn:
                                        $$TransactionsTableReferences
                                            ._toAccountIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (categoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.categoryId,
                                    referencedTable:
                                        $$TransactionsTableReferences
                                            ._categoryIdTable(db),
                                    referencedColumn:
                                        $$TransactionsTableReferences
                                            ._categoryIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (personId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.personId,
                                    referencedTable:
                                        $$TransactionsTableReferences
                                            ._personIdTable(db),
                                    referencedColumn:
                                        $$TransactionsTableReferences
                                            ._personIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (recurringRuleId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.recurringRuleId,
                                    referencedTable:
                                        $$TransactionsTableReferences
                                            ._recurringRuleIdTable(db),
                                    referencedColumn:
                                        $$TransactionsTableReferences
                                            ._recurringRuleIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (personEntriesRefs)
                        await $_getPrefetchedData<
                          TransactionRow,
                          $TransactionsTable,
                          PersonEntryRow
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionsTableReferences
                              ._personEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).personEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transactionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (remindersRefs)
                        await $_getPrefetchedData<
                          TransactionRow,
                          $TransactionsTable,
                          ReminderRow
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionsTableReferences
                              ._remindersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).remindersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transactionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (pendingTxnsRefs)
                        await $_getPrefetchedData<
                          TransactionRow,
                          $TransactionsTable,
                          PendingTxnRow
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionsTableReferences
                              ._pendingTxnsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).pendingTxnsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.createdTransactionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transactionTagsRefs)
                        await $_getPrefetchedData<
                          TransactionRow,
                          $TransactionsTable,
                          TransactionTagRow
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionsTableReferences
                              ._transactionTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transactionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transactionSplitsRefs)
                        await $_getPrefetchedData<
                          TransactionRow,
                          $TransactionsTable,
                          TransactionSplitRow
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionsTableReferences
                              ._transactionSplitsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionSplitsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transactionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionsTable,
      TransactionRow,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (TransactionRow, $$TransactionsTableReferences),
      TransactionRow,
      PrefetchHooks Function({
        bool accountId,
        bool toAccountId,
        bool categoryId,
        bool personId,
        bool recurringRuleId,
        bool personEntriesRefs,
        bool remindersRefs,
        bool pendingTxnsRefs,
        bool transactionTagsRefs,
        bool transactionSplitsRefs,
      })
    >;
typedef $$BudgetsTableCreateCompanionBuilder =
    BudgetsCompanion Function({
      Value<int> id,
      required int categoryId,
      required Money amount,
      required BudgetPeriod period,
      required DateTime startDate,
      Value<int> alertThresholdPct,
      Value<bool> isActive,
      Value<String?> note,
    });
typedef $$BudgetsTableUpdateCompanionBuilder =
    BudgetsCompanion Function({
      Value<int> id,
      Value<int> categoryId,
      Value<Money> amount,
      Value<BudgetPeriod> period,
      Value<DateTime> startDate,
      Value<int> alertThresholdPct,
      Value<bool> isActive,
      Value<String?> note,
    });

final class $$BudgetsTableReferences
    extends BaseReferences<_$AppDatabase, $BudgetsTable, BudgetRow> {
  $$BudgetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias(
        $_aliasNameGenerator(db.budgets.categoryId, db.categories.id),
      );

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<int>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Money, Money, int> get amount =>
      $composableBuilder(
        column: $table.amount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<BudgetPeriod, BudgetPeriod, String>
  get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get alertThresholdPct => $composableBuilder(
    column: $table.alertThresholdPct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get alertThresholdPct => $composableBuilder(
    column: $table.alertThresholdPct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Money, int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BudgetPeriod, String> get period =>
      $composableBuilder(column: $table.period, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<int> get alertThresholdPct => $composableBuilder(
    column: $table.alertThresholdPct,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BudgetsTable,
          BudgetRow,
          $$BudgetsTableFilterComposer,
          $$BudgetsTableOrderingComposer,
          $$BudgetsTableAnnotationComposer,
          $$BudgetsTableCreateCompanionBuilder,
          $$BudgetsTableUpdateCompanionBuilder,
          (BudgetRow, $$BudgetsTableReferences),
          BudgetRow,
          PrefetchHooks Function({bool categoryId})
        > {
  $$BudgetsTableTableManager(_$AppDatabase db, $BudgetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> categoryId = const Value.absent(),
                Value<Money> amount = const Value.absent(),
                Value<BudgetPeriod> period = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<int> alertThresholdPct = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => BudgetsCompanion(
                id: id,
                categoryId: categoryId,
                amount: amount,
                period: period,
                startDate: startDate,
                alertThresholdPct: alertThresholdPct,
                isActive: isActive,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int categoryId,
                required Money amount,
                required BudgetPeriod period,
                required DateTime startDate,
                Value<int> alertThresholdPct = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => BudgetsCompanion.insert(
                id: id,
                categoryId: categoryId,
                amount: amount,
                period: period,
                startDate: startDate,
                alertThresholdPct: alertThresholdPct,
                isActive: isActive,
                note: note,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BudgetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.categoryId,
                                referencedTable: $$BudgetsTableReferences
                                    ._categoryIdTable(db),
                                referencedColumn: $$BudgetsTableReferences
                                    ._categoryIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BudgetsTable,
      BudgetRow,
      $$BudgetsTableFilterComposer,
      $$BudgetsTableOrderingComposer,
      $$BudgetsTableAnnotationComposer,
      $$BudgetsTableCreateCompanionBuilder,
      $$BudgetsTableUpdateCompanionBuilder,
      (BudgetRow, $$BudgetsTableReferences),
      BudgetRow,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$PersonEntriesTableCreateCompanionBuilder =
    PersonEntriesCompanion Function({
      Value<int> id,
      required int personId,
      required PersonDirection direction,
      required Money amount,
      required DateTime date,
      Value<DateTime?> dueDate,
      Value<String?> note,
      Value<int?> accountId,
      Value<int?> transactionId,
      Value<int?> categoryId,
      Value<DateTime> createdAt,
    });
typedef $$PersonEntriesTableUpdateCompanionBuilder =
    PersonEntriesCompanion Function({
      Value<int> id,
      Value<int> personId,
      Value<PersonDirection> direction,
      Value<Money> amount,
      Value<DateTime> date,
      Value<DateTime?> dueDate,
      Value<String?> note,
      Value<int?> accountId,
      Value<int?> transactionId,
      Value<int?> categoryId,
      Value<DateTime> createdAt,
    });

final class $$PersonEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $PersonEntriesTable, PersonEntryRow> {
  $$PersonEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PersonsTable _personIdTable(_$AppDatabase db) =>
      db.persons.createAlias(
        $_aliasNameGenerator(db.personEntries.personId, db.persons.id),
      );

  $$PersonsTableProcessedTableManager get personId {
    final $_column = $_itemColumn<int>('person_id')!;

    final manager = $$PersonsTableTableManager(
      $_db,
      $_db.persons,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.personEntries.accountId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager? get accountId {
    final $_column = $_itemColumn<int>('account_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TransactionsTable _transactionIdTable(_$AppDatabase db) =>
      db.transactions.createAlias(
        $_aliasNameGenerator(
          db.personEntries.transactionId,
          db.transactions.id,
        ),
      );

  $$TransactionsTableProcessedTableManager? get transactionId {
    final $_column = $_itemColumn<int>('transaction_id');
    if ($_column == null) return null;
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias(
        $_aliasNameGenerator(db.personEntries.categoryId, db.categories.id),
      );

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<int>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PersonEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $PersonEntriesTable> {
  $$PersonEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PersonDirection, PersonDirection, String>
  get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<Money, Money, int> get amount =>
      $composableBuilder(
        column: $table.amount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PersonsTableFilterComposer get personId {
    final $$PersonsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.persons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonsTableFilterComposer(
            $db: $db,
            $table: $db.persons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableFilterComposer get transactionId {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PersonEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PersonEntriesTable> {
  $$PersonEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PersonsTableOrderingComposer get personId {
    final $$PersonsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.persons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonsTableOrderingComposer(
            $db: $db,
            $table: $db.persons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableOrderingComposer get transactionId {
    final $$TransactionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableOrderingComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PersonEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PersonEntriesTable> {
  $$PersonEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PersonDirection, String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Money, int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$PersonsTableAnnotationComposer get personId {
    final $$PersonsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.persons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonsTableAnnotationComposer(
            $db: $db,
            $table: $db.persons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableAnnotationComposer get transactionId {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PersonEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PersonEntriesTable,
          PersonEntryRow,
          $$PersonEntriesTableFilterComposer,
          $$PersonEntriesTableOrderingComposer,
          $$PersonEntriesTableAnnotationComposer,
          $$PersonEntriesTableCreateCompanionBuilder,
          $$PersonEntriesTableUpdateCompanionBuilder,
          (PersonEntryRow, $$PersonEntriesTableReferences),
          PersonEntryRow,
          PrefetchHooks Function({
            bool personId,
            bool accountId,
            bool transactionId,
            bool categoryId,
          })
        > {
  $$PersonEntriesTableTableManager(_$AppDatabase db, $PersonEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PersonEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PersonEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PersonEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> personId = const Value.absent(),
                Value<PersonDirection> direction = const Value.absent(),
                Value<Money> amount = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> accountId = const Value.absent(),
                Value<int?> transactionId = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PersonEntriesCompanion(
                id: id,
                personId: personId,
                direction: direction,
                amount: amount,
                date: date,
                dueDate: dueDate,
                note: note,
                accountId: accountId,
                transactionId: transactionId,
                categoryId: categoryId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int personId,
                required PersonDirection direction,
                required Money amount,
                required DateTime date,
                Value<DateTime?> dueDate = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> accountId = const Value.absent(),
                Value<int?> transactionId = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PersonEntriesCompanion.insert(
                id: id,
                personId: personId,
                direction: direction,
                amount: amount,
                date: date,
                dueDate: dueDate,
                note: note,
                accountId: accountId,
                transactionId: transactionId,
                categoryId: categoryId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PersonEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                personId = false,
                accountId = false,
                transactionId = false,
                categoryId = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (personId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.personId,
                                    referencedTable:
                                        $$PersonEntriesTableReferences
                                            ._personIdTable(db),
                                    referencedColumn:
                                        $$PersonEntriesTableReferences
                                            ._personIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (accountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.accountId,
                                    referencedTable:
                                        $$PersonEntriesTableReferences
                                            ._accountIdTable(db),
                                    referencedColumn:
                                        $$PersonEntriesTableReferences
                                            ._accountIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (transactionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.transactionId,
                                    referencedTable:
                                        $$PersonEntriesTableReferences
                                            ._transactionIdTable(db),
                                    referencedColumn:
                                        $$PersonEntriesTableReferences
                                            ._transactionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (categoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.categoryId,
                                    referencedTable:
                                        $$PersonEntriesTableReferences
                                            ._categoryIdTable(db),
                                    referencedColumn:
                                        $$PersonEntriesTableReferences
                                            ._categoryIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$PersonEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PersonEntriesTable,
      PersonEntryRow,
      $$PersonEntriesTableFilterComposer,
      $$PersonEntriesTableOrderingComposer,
      $$PersonEntriesTableAnnotationComposer,
      $$PersonEntriesTableCreateCompanionBuilder,
      $$PersonEntriesTableUpdateCompanionBuilder,
      (PersonEntryRow, $$PersonEntriesTableReferences),
      PersonEntryRow,
      PrefetchHooks Function({
        bool personId,
        bool accountId,
        bool transactionId,
        bool categoryId,
      })
    >;
typedef $$RemindersTableCreateCompanionBuilder =
    RemindersCompanion Function({
      Value<int> id,
      required String title,
      Value<Money?> amount,
      required ReminderDirection direction,
      required DateTime dueDate,
      Value<int?> accountId,
      Value<int?> categoryId,
      Value<int?> personId,
      Value<ReminderRepeat> repeat,
      Value<int> notifyDaysBefore,
      Value<ReminderStatus> status,
      Value<int?> transactionId,
      Value<DateTime> createdAt,
    });
typedef $$RemindersTableUpdateCompanionBuilder =
    RemindersCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<Money?> amount,
      Value<ReminderDirection> direction,
      Value<DateTime> dueDate,
      Value<int?> accountId,
      Value<int?> categoryId,
      Value<int?> personId,
      Value<ReminderRepeat> repeat,
      Value<int> notifyDaysBefore,
      Value<ReminderStatus> status,
      Value<int?> transactionId,
      Value<DateTime> createdAt,
    });

final class $$RemindersTableReferences
    extends BaseReferences<_$AppDatabase, $RemindersTable, ReminderRow> {
  $$RemindersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.reminders.accountId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager? get accountId {
    final $_column = $_itemColumn<int>('account_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias(
        $_aliasNameGenerator(db.reminders.categoryId, db.categories.id),
      );

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<int>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PersonsTable _personIdTable(_$AppDatabase db) => db.persons
      .createAlias($_aliasNameGenerator(db.reminders.personId, db.persons.id));

  $$PersonsTableProcessedTableManager? get personId {
    final $_column = $_itemColumn<int>('person_id');
    if ($_column == null) return null;
    final manager = $$PersonsTableTableManager(
      $_db,
      $_db.persons,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TransactionsTable _transactionIdTable(_$AppDatabase db) =>
      db.transactions.createAlias(
        $_aliasNameGenerator(db.reminders.transactionId, db.transactions.id),
      );

  $$TransactionsTableProcessedTableManager? get transactionId {
    final $_column = $_itemColumn<int>('transaction_id');
    if ($_column == null) return null;
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RemindersTableFilterComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Money?, Money, int> get amount =>
      $composableBuilder(
        column: $table.amount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<ReminderDirection, ReminderDirection, String>
  get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ReminderRepeat, ReminderRepeat, String>
  get repeat => $composableBuilder(
    column: $table.repeat,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get notifyDaysBefore => $composableBuilder(
    column: $table.notifyDaysBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ReminderStatus, ReminderStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PersonsTableFilterComposer get personId {
    final $$PersonsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.persons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonsTableFilterComposer(
            $db: $db,
            $table: $db.persons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableFilterComposer get transactionId {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeat => $composableBuilder(
    column: $table.repeat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notifyDaysBefore => $composableBuilder(
    column: $table.notifyDaysBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PersonsTableOrderingComposer get personId {
    final $$PersonsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.persons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonsTableOrderingComposer(
            $db: $db,
            $table: $db.persons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableOrderingComposer get transactionId {
    final $$TransactionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableOrderingComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Money?, int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ReminderDirection, String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ReminderRepeat, String> get repeat =>
      $composableBuilder(column: $table.repeat, builder: (column) => column);

  GeneratedColumn<int> get notifyDaysBefore => $composableBuilder(
    column: $table.notifyDaysBefore,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ReminderStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PersonsTableAnnotationComposer get personId {
    final $$PersonsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.persons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonsTableAnnotationComposer(
            $db: $db,
            $table: $db.persons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableAnnotationComposer get transactionId {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemindersTable,
          ReminderRow,
          $$RemindersTableFilterComposer,
          $$RemindersTableOrderingComposer,
          $$RemindersTableAnnotationComposer,
          $$RemindersTableCreateCompanionBuilder,
          $$RemindersTableUpdateCompanionBuilder,
          (ReminderRow, $$RemindersTableReferences),
          ReminderRow,
          PrefetchHooks Function({
            bool accountId,
            bool categoryId,
            bool personId,
            bool transactionId,
          })
        > {
  $$RemindersTableTableManager(_$AppDatabase db, $RemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<Money?> amount = const Value.absent(),
                Value<ReminderDirection> direction = const Value.absent(),
                Value<DateTime> dueDate = const Value.absent(),
                Value<int?> accountId = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<int?> personId = const Value.absent(),
                Value<ReminderRepeat> repeat = const Value.absent(),
                Value<int> notifyDaysBefore = const Value.absent(),
                Value<ReminderStatus> status = const Value.absent(),
                Value<int?> transactionId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => RemindersCompanion(
                id: id,
                title: title,
                amount: amount,
                direction: direction,
                dueDate: dueDate,
                accountId: accountId,
                categoryId: categoryId,
                personId: personId,
                repeat: repeat,
                notifyDaysBefore: notifyDaysBefore,
                status: status,
                transactionId: transactionId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<Money?> amount = const Value.absent(),
                required ReminderDirection direction,
                required DateTime dueDate,
                Value<int?> accountId = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<int?> personId = const Value.absent(),
                Value<ReminderRepeat> repeat = const Value.absent(),
                Value<int> notifyDaysBefore = const Value.absent(),
                Value<ReminderStatus> status = const Value.absent(),
                Value<int?> transactionId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => RemindersCompanion.insert(
                id: id,
                title: title,
                amount: amount,
                direction: direction,
                dueDate: dueDate,
                accountId: accountId,
                categoryId: categoryId,
                personId: personId,
                repeat: repeat,
                notifyDaysBefore: notifyDaysBefore,
                status: status,
                transactionId: transactionId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RemindersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                accountId = false,
                categoryId = false,
                personId = false,
                transactionId = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (accountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.accountId,
                                    referencedTable: $$RemindersTableReferences
                                        ._accountIdTable(db),
                                    referencedColumn: $$RemindersTableReferences
                                        ._accountIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (categoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.categoryId,
                                    referencedTable: $$RemindersTableReferences
                                        ._categoryIdTable(db),
                                    referencedColumn: $$RemindersTableReferences
                                        ._categoryIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (personId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.personId,
                                    referencedTable: $$RemindersTableReferences
                                        ._personIdTable(db),
                                    referencedColumn: $$RemindersTableReferences
                                        ._personIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (transactionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.transactionId,
                                    referencedTable: $$RemindersTableReferences
                                        ._transactionIdTable(db),
                                    referencedColumn: $$RemindersTableReferences
                                        ._transactionIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$RemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemindersTable,
      ReminderRow,
      $$RemindersTableFilterComposer,
      $$RemindersTableOrderingComposer,
      $$RemindersTableAnnotationComposer,
      $$RemindersTableCreateCompanionBuilder,
      $$RemindersTableUpdateCompanionBuilder,
      (ReminderRow, $$RemindersTableReferences),
      ReminderRow,
      PrefetchHooks Function({
        bool accountId,
        bool categoryId,
        bool personId,
        bool transactionId,
      })
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      Value<int> id,
      Value<String> currencyCode,
      Value<int> budgetStartDay,
      Value<bool> onboarded,
      Value<bool> autoApprove,
      Value<bool> messageCaptureEnabled,
      Value<DateTime?> lastMessageScanAt,
      Value<bool> notificationsEnabled,
      Value<String> themeName,
      Value<bool> showCurrencySymbol,
      Value<bool> countRepaymentsAsIncome,
      Value<String?> passcodeHash,
      Value<String?> passcodeSalt,
      Value<bool> biometricEnabled,
      Value<bool> expenseReminderEnabled,
      Value<int> expenseReminderHour,
      Value<int> expenseReminderMinute,
      Value<bool> autoBackupEnabled,
      Value<AutoBackupFrequency> autoBackupFrequency,
      Value<int> autoBackupCustomDays,
      Value<int> autoBackupCustomHours,
      Value<DateTime?> lastAutoBackupAt,
      Value<int> backupRetentionDays,
      Value<bool> preventScreenshots,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<int> id,
      Value<String> currencyCode,
      Value<int> budgetStartDay,
      Value<bool> onboarded,
      Value<bool> autoApprove,
      Value<bool> messageCaptureEnabled,
      Value<DateTime?> lastMessageScanAt,
      Value<bool> notificationsEnabled,
      Value<String> themeName,
      Value<bool> showCurrencySymbol,
      Value<bool> countRepaymentsAsIncome,
      Value<String?> passcodeHash,
      Value<String?> passcodeSalt,
      Value<bool> biometricEnabled,
      Value<bool> expenseReminderEnabled,
      Value<int> expenseReminderHour,
      Value<int> expenseReminderMinute,
      Value<bool> autoBackupEnabled,
      Value<AutoBackupFrequency> autoBackupFrequency,
      Value<int> autoBackupCustomDays,
      Value<int> autoBackupCustomHours,
      Value<DateTime?> lastAutoBackupAt,
      Value<int> backupRetentionDays,
      Value<bool> preventScreenshots,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get budgetStartDay => $composableBuilder(
    column: $table.budgetStartDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onboarded => $composableBuilder(
    column: $table.onboarded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoApprove => $composableBuilder(
    column: $table.autoApprove,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get messageCaptureEnabled => $composableBuilder(
    column: $table.messageCaptureEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastMessageScanAt => $composableBuilder(
    column: $table.lastMessageScanAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeName => $composableBuilder(
    column: $table.themeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showCurrencySymbol => $composableBuilder(
    column: $table.showCurrencySymbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get countRepaymentsAsIncome => $composableBuilder(
    column: $table.countRepaymentsAsIncome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passcodeHash => $composableBuilder(
    column: $table.passcodeHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passcodeSalt => $composableBuilder(
    column: $table.passcodeSalt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get biometricEnabled => $composableBuilder(
    column: $table.biometricEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get expenseReminderEnabled => $composableBuilder(
    column: $table.expenseReminderEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expenseReminderHour => $composableBuilder(
    column: $table.expenseReminderHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expenseReminderMinute => $composableBuilder(
    column: $table.expenseReminderMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoBackupEnabled => $composableBuilder(
    column: $table.autoBackupEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    AutoBackupFrequency,
    AutoBackupFrequency,
    String
  >
  get autoBackupFrequency => $composableBuilder(
    column: $table.autoBackupFrequency,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get autoBackupCustomDays => $composableBuilder(
    column: $table.autoBackupCustomDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get autoBackupCustomHours => $composableBuilder(
    column: $table.autoBackupCustomHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAutoBackupAt => $composableBuilder(
    column: $table.lastAutoBackupAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get backupRetentionDays => $composableBuilder(
    column: $table.backupRetentionDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get preventScreenshots => $composableBuilder(
    column: $table.preventScreenshots,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get budgetStartDay => $composableBuilder(
    column: $table.budgetStartDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onboarded => $composableBuilder(
    column: $table.onboarded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoApprove => $composableBuilder(
    column: $table.autoApprove,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get messageCaptureEnabled => $composableBuilder(
    column: $table.messageCaptureEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastMessageScanAt => $composableBuilder(
    column: $table.lastMessageScanAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeName => $composableBuilder(
    column: $table.themeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showCurrencySymbol => $composableBuilder(
    column: $table.showCurrencySymbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get countRepaymentsAsIncome => $composableBuilder(
    column: $table.countRepaymentsAsIncome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passcodeHash => $composableBuilder(
    column: $table.passcodeHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passcodeSalt => $composableBuilder(
    column: $table.passcodeSalt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get biometricEnabled => $composableBuilder(
    column: $table.biometricEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get expenseReminderEnabled => $composableBuilder(
    column: $table.expenseReminderEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expenseReminderHour => $composableBuilder(
    column: $table.expenseReminderHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expenseReminderMinute => $composableBuilder(
    column: $table.expenseReminderMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoBackupEnabled => $composableBuilder(
    column: $table.autoBackupEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get autoBackupFrequency => $composableBuilder(
    column: $table.autoBackupFrequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get autoBackupCustomDays => $composableBuilder(
    column: $table.autoBackupCustomDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get autoBackupCustomHours => $composableBuilder(
    column: $table.autoBackupCustomHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAutoBackupAt => $composableBuilder(
    column: $table.lastAutoBackupAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get backupRetentionDays => $composableBuilder(
    column: $table.backupRetentionDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get preventScreenshots => $composableBuilder(
    column: $table.preventScreenshots,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get budgetStartDay => $composableBuilder(
    column: $table.budgetStartDay,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get onboarded =>
      $composableBuilder(column: $table.onboarded, builder: (column) => column);

  GeneratedColumn<bool> get autoApprove => $composableBuilder(
    column: $table.autoApprove,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get messageCaptureEnabled => $composableBuilder(
    column: $table.messageCaptureEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastMessageScanAt => $composableBuilder(
    column: $table.lastMessageScanAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get themeName =>
      $composableBuilder(column: $table.themeName, builder: (column) => column);

  GeneratedColumn<bool> get showCurrencySymbol => $composableBuilder(
    column: $table.showCurrencySymbol,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get countRepaymentsAsIncome => $composableBuilder(
    column: $table.countRepaymentsAsIncome,
    builder: (column) => column,
  );

  GeneratedColumn<String> get passcodeHash => $composableBuilder(
    column: $table.passcodeHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get passcodeSalt => $composableBuilder(
    column: $table.passcodeSalt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get biometricEnabled => $composableBuilder(
    column: $table.biometricEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get expenseReminderEnabled => $composableBuilder(
    column: $table.expenseReminderEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expenseReminderHour => $composableBuilder(
    column: $table.expenseReminderHour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expenseReminderMinute => $composableBuilder(
    column: $table.expenseReminderMinute,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoBackupEnabled => $composableBuilder(
    column: $table.autoBackupEnabled,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<AutoBackupFrequency, String>
  get autoBackupFrequency => $composableBuilder(
    column: $table.autoBackupFrequency,
    builder: (column) => column,
  );

  GeneratedColumn<int> get autoBackupCustomDays => $composableBuilder(
    column: $table.autoBackupCustomDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get autoBackupCustomHours => $composableBuilder(
    column: $table.autoBackupCustomHours,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAutoBackupAt => $composableBuilder(
    column: $table.lastAutoBackupAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get backupRetentionDays => $composableBuilder(
    column: $table.backupRetentionDays,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get preventScreenshots => $composableBuilder(
    column: $table.preventScreenshots,
    builder: (column) => column,
  );
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<int> budgetStartDay = const Value.absent(),
                Value<bool> onboarded = const Value.absent(),
                Value<bool> autoApprove = const Value.absent(),
                Value<bool> messageCaptureEnabled = const Value.absent(),
                Value<DateTime?> lastMessageScanAt = const Value.absent(),
                Value<bool> notificationsEnabled = const Value.absent(),
                Value<String> themeName = const Value.absent(),
                Value<bool> showCurrencySymbol = const Value.absent(),
                Value<bool> countRepaymentsAsIncome = const Value.absent(),
                Value<String?> passcodeHash = const Value.absent(),
                Value<String?> passcodeSalt = const Value.absent(),
                Value<bool> biometricEnabled = const Value.absent(),
                Value<bool> expenseReminderEnabled = const Value.absent(),
                Value<int> expenseReminderHour = const Value.absent(),
                Value<int> expenseReminderMinute = const Value.absent(),
                Value<bool> autoBackupEnabled = const Value.absent(),
                Value<AutoBackupFrequency> autoBackupFrequency =
                    const Value.absent(),
                Value<int> autoBackupCustomDays = const Value.absent(),
                Value<int> autoBackupCustomHours = const Value.absent(),
                Value<DateTime?> lastAutoBackupAt = const Value.absent(),
                Value<int> backupRetentionDays = const Value.absent(),
                Value<bool> preventScreenshots = const Value.absent(),
              }) => SettingsCompanion(
                id: id,
                currencyCode: currencyCode,
                budgetStartDay: budgetStartDay,
                onboarded: onboarded,
                autoApprove: autoApprove,
                messageCaptureEnabled: messageCaptureEnabled,
                lastMessageScanAt: lastMessageScanAt,
                notificationsEnabled: notificationsEnabled,
                themeName: themeName,
                showCurrencySymbol: showCurrencySymbol,
                countRepaymentsAsIncome: countRepaymentsAsIncome,
                passcodeHash: passcodeHash,
                passcodeSalt: passcodeSalt,
                biometricEnabled: biometricEnabled,
                expenseReminderEnabled: expenseReminderEnabled,
                expenseReminderHour: expenseReminderHour,
                expenseReminderMinute: expenseReminderMinute,
                autoBackupEnabled: autoBackupEnabled,
                autoBackupFrequency: autoBackupFrequency,
                autoBackupCustomDays: autoBackupCustomDays,
                autoBackupCustomHours: autoBackupCustomHours,
                lastAutoBackupAt: lastAutoBackupAt,
                backupRetentionDays: backupRetentionDays,
                preventScreenshots: preventScreenshots,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<int> budgetStartDay = const Value.absent(),
                Value<bool> onboarded = const Value.absent(),
                Value<bool> autoApprove = const Value.absent(),
                Value<bool> messageCaptureEnabled = const Value.absent(),
                Value<DateTime?> lastMessageScanAt = const Value.absent(),
                Value<bool> notificationsEnabled = const Value.absent(),
                Value<String> themeName = const Value.absent(),
                Value<bool> showCurrencySymbol = const Value.absent(),
                Value<bool> countRepaymentsAsIncome = const Value.absent(),
                Value<String?> passcodeHash = const Value.absent(),
                Value<String?> passcodeSalt = const Value.absent(),
                Value<bool> biometricEnabled = const Value.absent(),
                Value<bool> expenseReminderEnabled = const Value.absent(),
                Value<int> expenseReminderHour = const Value.absent(),
                Value<int> expenseReminderMinute = const Value.absent(),
                Value<bool> autoBackupEnabled = const Value.absent(),
                Value<AutoBackupFrequency> autoBackupFrequency =
                    const Value.absent(),
                Value<int> autoBackupCustomDays = const Value.absent(),
                Value<int> autoBackupCustomHours = const Value.absent(),
                Value<DateTime?> lastAutoBackupAt = const Value.absent(),
                Value<int> backupRetentionDays = const Value.absent(),
                Value<bool> preventScreenshots = const Value.absent(),
              }) => SettingsCompanion.insert(
                id: id,
                currencyCode: currencyCode,
                budgetStartDay: budgetStartDay,
                onboarded: onboarded,
                autoApprove: autoApprove,
                messageCaptureEnabled: messageCaptureEnabled,
                lastMessageScanAt: lastMessageScanAt,
                notificationsEnabled: notificationsEnabled,
                themeName: themeName,
                showCurrencySymbol: showCurrencySymbol,
                countRepaymentsAsIncome: countRepaymentsAsIncome,
                passcodeHash: passcodeHash,
                passcodeSalt: passcodeSalt,
                biometricEnabled: biometricEnabled,
                expenseReminderEnabled: expenseReminderEnabled,
                expenseReminderHour: expenseReminderHour,
                expenseReminderMinute: expenseReminderMinute,
                autoBackupEnabled: autoBackupEnabled,
                autoBackupFrequency: autoBackupFrequency,
                autoBackupCustomDays: autoBackupCustomDays,
                autoBackupCustomHours: autoBackupCustomHours,
                lastAutoBackupAt: lastAutoBackupAt,
                backupRetentionDays: backupRetentionDays,
                preventScreenshots: preventScreenshots,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$PendingTxnsTableCreateCompanionBuilder =
    PendingTxnsCompanion Function({
      Value<int> id,
      required MessageSourceKind source,
      required String rawBody,
      required String sender,
      required DateTime receivedAt,
      Value<Money?> parsedAmount,
      Value<TxDirection?> parsedDirection,
      Value<String?> parsedAccountHint,
      Value<String?> parsedMerchant,
      Value<String?> parsedRef,
      Value<Money?> parsedBalance,
      Value<int> confidence,
      Value<PendingStatus> status,
      Value<int?> matchedAccountId,
      Value<int?> appliedRuleId,
      Value<int?> createdTransactionId,
      required String dedupeKey,
      Value<DateTime> createdAt,
    });
typedef $$PendingTxnsTableUpdateCompanionBuilder =
    PendingTxnsCompanion Function({
      Value<int> id,
      Value<MessageSourceKind> source,
      Value<String> rawBody,
      Value<String> sender,
      Value<DateTime> receivedAt,
      Value<Money?> parsedAmount,
      Value<TxDirection?> parsedDirection,
      Value<String?> parsedAccountHint,
      Value<String?> parsedMerchant,
      Value<String?> parsedRef,
      Value<Money?> parsedBalance,
      Value<int> confidence,
      Value<PendingStatus> status,
      Value<int?> matchedAccountId,
      Value<int?> appliedRuleId,
      Value<int?> createdTransactionId,
      Value<String> dedupeKey,
      Value<DateTime> createdAt,
    });

final class $$PendingTxnsTableReferences
    extends BaseReferences<_$AppDatabase, $PendingTxnsTable, PendingTxnRow> {
  $$PendingTxnsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _matchedAccountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.pendingTxns.matchedAccountId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager? get matchedAccountId {
    final $_column = $_itemColumn<int>('matched_account_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_matchedAccountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TransactionsTable _createdTransactionIdTable(_$AppDatabase db) =>
      db.transactions.createAlias(
        $_aliasNameGenerator(
          db.pendingTxns.createdTransactionId,
          db.transactions.id,
        ),
      );

  $$TransactionsTableProcessedTableManager? get createdTransactionId {
    final $_column = $_itemColumn<int>('created_transaction_id');
    if ($_column == null) return null;
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(
      _createdTransactionIdTable($_db),
    );
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PendingTxnsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingTxnsTable> {
  $$PendingTxnsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MessageSourceKind, MessageSourceKind, String>
  get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get rawBody => $composableBuilder(
    column: $table.rawBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Money?, Money, int> get parsedAmount =>
      $composableBuilder(
        column: $table.parsedAmount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<TxDirection?, TxDirection, String>
  get parsedDirection => $composableBuilder(
    column: $table.parsedDirection,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get parsedAccountHint => $composableBuilder(
    column: $table.parsedAccountHint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parsedMerchant => $composableBuilder(
    column: $table.parsedMerchant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parsedRef => $composableBuilder(
    column: $table.parsedRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Money?, Money, int> get parsedBalance =>
      $composableBuilder(
        column: $table.parsedBalance,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PendingStatus, PendingStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get appliedRuleId => $composableBuilder(
    column: $table.appliedRuleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get matchedAccountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchedAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableFilterComposer get createdTransactionId {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.createdTransactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PendingTxnsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingTxnsTable> {
  $$PendingTxnsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawBody => $composableBuilder(
    column: $table.rawBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parsedAmount => $composableBuilder(
    column: $table.parsedAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parsedDirection => $composableBuilder(
    column: $table.parsedDirection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parsedAccountHint => $composableBuilder(
    column: $table.parsedAccountHint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parsedMerchant => $composableBuilder(
    column: $table.parsedMerchant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parsedRef => $composableBuilder(
    column: $table.parsedRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parsedBalance => $composableBuilder(
    column: $table.parsedBalance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get appliedRuleId => $composableBuilder(
    column: $table.appliedRuleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get matchedAccountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchedAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableOrderingComposer get createdTransactionId {
    final $$TransactionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.createdTransactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableOrderingComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PendingTxnsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingTxnsTable> {
  $$PendingTxnsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MessageSourceKind, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get rawBody =>
      $composableBuilder(column: $table.rawBody, builder: (column) => column);

  GeneratedColumn<String> get sender =>
      $composableBuilder(column: $table.sender, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Money?, int> get parsedAmount =>
      $composableBuilder(
        column: $table.parsedAmount,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<TxDirection?, String> get parsedDirection =>
      $composableBuilder(
        column: $table.parsedDirection,
        builder: (column) => column,
      );

  GeneratedColumn<String> get parsedAccountHint => $composableBuilder(
    column: $table.parsedAccountHint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parsedMerchant => $composableBuilder(
    column: $table.parsedMerchant,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parsedRef =>
      $composableBuilder(column: $table.parsedRef, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Money?, int> get parsedBalance =>
      $composableBuilder(
        column: $table.parsedBalance,
        builder: (column) => column,
      );

  GeneratedColumn<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<PendingStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get appliedRuleId => $composableBuilder(
    column: $table.appliedRuleId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dedupeKey =>
      $composableBuilder(column: $table.dedupeKey, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get matchedAccountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchedAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableAnnotationComposer get createdTransactionId {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.createdTransactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PendingTxnsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingTxnsTable,
          PendingTxnRow,
          $$PendingTxnsTableFilterComposer,
          $$PendingTxnsTableOrderingComposer,
          $$PendingTxnsTableAnnotationComposer,
          $$PendingTxnsTableCreateCompanionBuilder,
          $$PendingTxnsTableUpdateCompanionBuilder,
          (PendingTxnRow, $$PendingTxnsTableReferences),
          PendingTxnRow,
          PrefetchHooks Function({
            bool matchedAccountId,
            bool createdTransactionId,
          })
        > {
  $$PendingTxnsTableTableManager(_$AppDatabase db, $PendingTxnsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingTxnsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingTxnsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingTxnsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<MessageSourceKind> source = const Value.absent(),
                Value<String> rawBody = const Value.absent(),
                Value<String> sender = const Value.absent(),
                Value<DateTime> receivedAt = const Value.absent(),
                Value<Money?> parsedAmount = const Value.absent(),
                Value<TxDirection?> parsedDirection = const Value.absent(),
                Value<String?> parsedAccountHint = const Value.absent(),
                Value<String?> parsedMerchant = const Value.absent(),
                Value<String?> parsedRef = const Value.absent(),
                Value<Money?> parsedBalance = const Value.absent(),
                Value<int> confidence = const Value.absent(),
                Value<PendingStatus> status = const Value.absent(),
                Value<int?> matchedAccountId = const Value.absent(),
                Value<int?> appliedRuleId = const Value.absent(),
                Value<int?> createdTransactionId = const Value.absent(),
                Value<String> dedupeKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PendingTxnsCompanion(
                id: id,
                source: source,
                rawBody: rawBody,
                sender: sender,
                receivedAt: receivedAt,
                parsedAmount: parsedAmount,
                parsedDirection: parsedDirection,
                parsedAccountHint: parsedAccountHint,
                parsedMerchant: parsedMerchant,
                parsedRef: parsedRef,
                parsedBalance: parsedBalance,
                confidence: confidence,
                status: status,
                matchedAccountId: matchedAccountId,
                appliedRuleId: appliedRuleId,
                createdTransactionId: createdTransactionId,
                dedupeKey: dedupeKey,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required MessageSourceKind source,
                required String rawBody,
                required String sender,
                required DateTime receivedAt,
                Value<Money?> parsedAmount = const Value.absent(),
                Value<TxDirection?> parsedDirection = const Value.absent(),
                Value<String?> parsedAccountHint = const Value.absent(),
                Value<String?> parsedMerchant = const Value.absent(),
                Value<String?> parsedRef = const Value.absent(),
                Value<Money?> parsedBalance = const Value.absent(),
                Value<int> confidence = const Value.absent(),
                Value<PendingStatus> status = const Value.absent(),
                Value<int?> matchedAccountId = const Value.absent(),
                Value<int?> appliedRuleId = const Value.absent(),
                Value<int?> createdTransactionId = const Value.absent(),
                required String dedupeKey,
                Value<DateTime> createdAt = const Value.absent(),
              }) => PendingTxnsCompanion.insert(
                id: id,
                source: source,
                rawBody: rawBody,
                sender: sender,
                receivedAt: receivedAt,
                parsedAmount: parsedAmount,
                parsedDirection: parsedDirection,
                parsedAccountHint: parsedAccountHint,
                parsedMerchant: parsedMerchant,
                parsedRef: parsedRef,
                parsedBalance: parsedBalance,
                confidence: confidence,
                status: status,
                matchedAccountId: matchedAccountId,
                appliedRuleId: appliedRuleId,
                createdTransactionId: createdTransactionId,
                dedupeKey: dedupeKey,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PendingTxnsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({matchedAccountId = false, createdTransactionId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (matchedAccountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.matchedAccountId,
                                    referencedTable:
                                        $$PendingTxnsTableReferences
                                            ._matchedAccountIdTable(db),
                                    referencedColumn:
                                        $$PendingTxnsTableReferences
                                            ._matchedAccountIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (createdTransactionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.createdTransactionId,
                                    referencedTable:
                                        $$PendingTxnsTableReferences
                                            ._createdTransactionIdTable(db),
                                    referencedColumn:
                                        $$PendingTxnsTableReferences
                                            ._createdTransactionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$PendingTxnsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingTxnsTable,
      PendingTxnRow,
      $$PendingTxnsTableFilterComposer,
      $$PendingTxnsTableOrderingComposer,
      $$PendingTxnsTableAnnotationComposer,
      $$PendingTxnsTableCreateCompanionBuilder,
      $$PendingTxnsTableUpdateCompanionBuilder,
      (PendingTxnRow, $$PendingTxnsTableReferences),
      PendingTxnRow,
      PrefetchHooks Function({bool matchedAccountId, bool createdTransactionId})
    >;
typedef $$MerchantRulesTableCreateCompanionBuilder =
    MerchantRulesCompanion Function({
      Value<int> id,
      required String matchPattern,
      required int categoryId,
      Value<int?> accountId,
      Value<bool> autoApprove,
      Value<int> hitCount,
    });
typedef $$MerchantRulesTableUpdateCompanionBuilder =
    MerchantRulesCompanion Function({
      Value<int> id,
      Value<String> matchPattern,
      Value<int> categoryId,
      Value<int?> accountId,
      Value<bool> autoApprove,
      Value<int> hitCount,
    });

final class $$MerchantRulesTableReferences
    extends
        BaseReferences<_$AppDatabase, $MerchantRulesTable, MerchantRuleRow> {
  $$MerchantRulesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias(
        $_aliasNameGenerator(db.merchantRules.categoryId, db.categories.id),
      );

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<int>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.merchantRules.accountId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager? get accountId {
    final $_column = $_itemColumn<int>('account_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MerchantRulesTableFilterComposer
    extends Composer<_$AppDatabase, $MerchantRulesTable> {
  $$MerchantRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matchPattern => $composableBuilder(
    column: $table.matchPattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoApprove => $composableBuilder(
    column: $table.autoApprove,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hitCount => $composableBuilder(
    column: $table.hitCount,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MerchantRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $MerchantRulesTable> {
  $$MerchantRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matchPattern => $composableBuilder(
    column: $table.matchPattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoApprove => $composableBuilder(
    column: $table.autoApprove,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hitCount => $composableBuilder(
    column: $table.hitCount,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MerchantRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MerchantRulesTable> {
  $$MerchantRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get matchPattern => $composableBuilder(
    column: $table.matchPattern,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoApprove => $composableBuilder(
    column: $table.autoApprove,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hitCount =>
      $composableBuilder(column: $table.hitCount, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MerchantRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MerchantRulesTable,
          MerchantRuleRow,
          $$MerchantRulesTableFilterComposer,
          $$MerchantRulesTableOrderingComposer,
          $$MerchantRulesTableAnnotationComposer,
          $$MerchantRulesTableCreateCompanionBuilder,
          $$MerchantRulesTableUpdateCompanionBuilder,
          (MerchantRuleRow, $$MerchantRulesTableReferences),
          MerchantRuleRow,
          PrefetchHooks Function({bool categoryId, bool accountId})
        > {
  $$MerchantRulesTableTableManager(_$AppDatabase db, $MerchantRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MerchantRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MerchantRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MerchantRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> matchPattern = const Value.absent(),
                Value<int> categoryId = const Value.absent(),
                Value<int?> accountId = const Value.absent(),
                Value<bool> autoApprove = const Value.absent(),
                Value<int> hitCount = const Value.absent(),
              }) => MerchantRulesCompanion(
                id: id,
                matchPattern: matchPattern,
                categoryId: categoryId,
                accountId: accountId,
                autoApprove: autoApprove,
                hitCount: hitCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String matchPattern,
                required int categoryId,
                Value<int?> accountId = const Value.absent(),
                Value<bool> autoApprove = const Value.absent(),
                Value<int> hitCount = const Value.absent(),
              }) => MerchantRulesCompanion.insert(
                id: id,
                matchPattern: matchPattern,
                categoryId: categoryId,
                accountId: accountId,
                autoApprove: autoApprove,
                hitCount: hitCount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MerchantRulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false, accountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.categoryId,
                                referencedTable: $$MerchantRulesTableReferences
                                    ._categoryIdTable(db),
                                referencedColumn: $$MerchantRulesTableReferences
                                    ._categoryIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (accountId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.accountId,
                                referencedTable: $$MerchantRulesTableReferences
                                    ._accountIdTable(db),
                                referencedColumn: $$MerchantRulesTableReferences
                                    ._accountIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MerchantRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MerchantRulesTable,
      MerchantRuleRow,
      $$MerchantRulesTableFilterComposer,
      $$MerchantRulesTableOrderingComposer,
      $$MerchantRulesTableAnnotationComposer,
      $$MerchantRulesTableCreateCompanionBuilder,
      $$MerchantRulesTableUpdateCompanionBuilder,
      (MerchantRuleRow, $$MerchantRulesTableReferences),
      MerchantRuleRow,
      PrefetchHooks Function({bool categoryId, bool accountId})
    >;
typedef $$SenderRulesTableCreateCompanionBuilder =
    SenderRulesCompanion Function({
      Value<int> id,
      required String senderPattern,
      required String bankName,
      Value<bool> enabled,
    });
typedef $$SenderRulesTableUpdateCompanionBuilder =
    SenderRulesCompanion Function({
      Value<int> id,
      Value<String> senderPattern,
      Value<String> bankName,
      Value<bool> enabled,
    });

class $$SenderRulesTableFilterComposer
    extends Composer<_$AppDatabase, $SenderRulesTable> {
  $$SenderRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderPattern => $composableBuilder(
    column: $table.senderPattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bankName => $composableBuilder(
    column: $table.bankName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SenderRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $SenderRulesTable> {
  $$SenderRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderPattern => $composableBuilder(
    column: $table.senderPattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bankName => $composableBuilder(
    column: $table.bankName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SenderRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SenderRulesTable> {
  $$SenderRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get senderPattern => $composableBuilder(
    column: $table.senderPattern,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bankName =>
      $composableBuilder(column: $table.bankName, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);
}

class $$SenderRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SenderRulesTable,
          SenderRuleRow,
          $$SenderRulesTableFilterComposer,
          $$SenderRulesTableOrderingComposer,
          $$SenderRulesTableAnnotationComposer,
          $$SenderRulesTableCreateCompanionBuilder,
          $$SenderRulesTableUpdateCompanionBuilder,
          (
            SenderRuleRow,
            BaseReferences<_$AppDatabase, $SenderRulesTable, SenderRuleRow>,
          ),
          SenderRuleRow,
          PrefetchHooks Function()
        > {
  $$SenderRulesTableTableManager(_$AppDatabase db, $SenderRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SenderRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SenderRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SenderRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> senderPattern = const Value.absent(),
                Value<String> bankName = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
              }) => SenderRulesCompanion(
                id: id,
                senderPattern: senderPattern,
                bankName: bankName,
                enabled: enabled,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String senderPattern,
                required String bankName,
                Value<bool> enabled = const Value.absent(),
              }) => SenderRulesCompanion.insert(
                id: id,
                senderPattern: senderPattern,
                bankName: bankName,
                enabled: enabled,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SenderRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SenderRulesTable,
      SenderRuleRow,
      $$SenderRulesTableFilterComposer,
      $$SenderRulesTableOrderingComposer,
      $$SenderRulesTableAnnotationComposer,
      $$SenderRulesTableCreateCompanionBuilder,
      $$SenderRulesTableUpdateCompanionBuilder,
      (
        SenderRuleRow,
        BaseReferences<_$AppDatabase, $SenderRulesTable, SenderRuleRow>,
      ),
      SenderRuleRow,
      PrefetchHooks Function()
    >;
typedef $$BudgetAlertsTableCreateCompanionBuilder =
    BudgetAlertsCompanion Function({
      Value<int> id,
      required int categoryId,
      required String periodKey,
      required AlertLevel level,
      Value<DateTime> firedAt,
    });
typedef $$BudgetAlertsTableUpdateCompanionBuilder =
    BudgetAlertsCompanion Function({
      Value<int> id,
      Value<int> categoryId,
      Value<String> periodKey,
      Value<AlertLevel> level,
      Value<DateTime> firedAt,
    });

final class $$BudgetAlertsTableReferences
    extends BaseReferences<_$AppDatabase, $BudgetAlertsTable, BudgetAlertRow> {
  $$BudgetAlertsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias(
        $_aliasNameGenerator(db.budgetAlerts.categoryId, db.categories.id),
      );

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<int>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BudgetAlertsTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetAlertsTable> {
  $$BudgetAlertsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get periodKey => $composableBuilder(
    column: $table.periodKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AlertLevel, AlertLevel, String> get level =>
      $composableBuilder(
        column: $table.level,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get firedAt => $composableBuilder(
    column: $table.firedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetAlertsTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetAlertsTable> {
  $$BudgetAlertsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodKey => $composableBuilder(
    column: $table.periodKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firedAt => $composableBuilder(
    column: $table.firedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetAlertsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetAlertsTable> {
  $$BudgetAlertsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get periodKey =>
      $composableBuilder(column: $table.periodKey, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AlertLevel, String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<DateTime> get firedAt =>
      $composableBuilder(column: $table.firedAt, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetAlertsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BudgetAlertsTable,
          BudgetAlertRow,
          $$BudgetAlertsTableFilterComposer,
          $$BudgetAlertsTableOrderingComposer,
          $$BudgetAlertsTableAnnotationComposer,
          $$BudgetAlertsTableCreateCompanionBuilder,
          $$BudgetAlertsTableUpdateCompanionBuilder,
          (BudgetAlertRow, $$BudgetAlertsTableReferences),
          BudgetAlertRow,
          PrefetchHooks Function({bool categoryId})
        > {
  $$BudgetAlertsTableTableManager(_$AppDatabase db, $BudgetAlertsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetAlertsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetAlertsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetAlertsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> categoryId = const Value.absent(),
                Value<String> periodKey = const Value.absent(),
                Value<AlertLevel> level = const Value.absent(),
                Value<DateTime> firedAt = const Value.absent(),
              }) => BudgetAlertsCompanion(
                id: id,
                categoryId: categoryId,
                periodKey: periodKey,
                level: level,
                firedAt: firedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int categoryId,
                required String periodKey,
                required AlertLevel level,
                Value<DateTime> firedAt = const Value.absent(),
              }) => BudgetAlertsCompanion.insert(
                id: id,
                categoryId: categoryId,
                periodKey: periodKey,
                level: level,
                firedAt: firedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BudgetAlertsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.categoryId,
                                referencedTable: $$BudgetAlertsTableReferences
                                    ._categoryIdTable(db),
                                referencedColumn: $$BudgetAlertsTableReferences
                                    ._categoryIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BudgetAlertsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BudgetAlertsTable,
      BudgetAlertRow,
      $$BudgetAlertsTableFilterComposer,
      $$BudgetAlertsTableOrderingComposer,
      $$BudgetAlertsTableAnnotationComposer,
      $$BudgetAlertsTableCreateCompanionBuilder,
      $$BudgetAlertsTableUpdateCompanionBuilder,
      (BudgetAlertRow, $$BudgetAlertsTableReferences),
      BudgetAlertRow,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      Value<int> id,
      required String name,
      required int colorValue,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> colorValue,
    });

final class $$TagsTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTable, TagRow> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TransactionTagsTable, List<TransactionTagRow>>
  _transactionTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactionTags,
    aliasName: $_aliasNameGenerator(db.tags.id, db.transactionTags.tagId),
  );

  $$TransactionTagsTableProcessedTableManager get transactionTagsRefs {
    final manager = $$TransactionTagsTableTableManager(
      $_db,
      $_db.transactionTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _transactionTagsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> transactionTagsRefs(
    Expression<bool> Function($$TransactionTagsTableFilterComposer f) f,
  ) {
    final $$TransactionTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactionTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionTagsTableFilterComposer(
            $db: $db,
            $table: $db.transactionTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  Expression<T> transactionTagsRefs<T extends Object>(
    Expression<T> Function($$TransactionTagsTableAnnotationComposer a) f,
  ) {
    final $$TransactionTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactionTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactionTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          TagRow,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (TagRow, $$TagsTableReferences),
          TagRow,
          PrefetchHooks Function({bool transactionTagsRefs})
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
              }) => TagsCompanion(id: id, name: name, colorValue: colorValue),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int colorValue,
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                colorValue: colorValue,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TagsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({transactionTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (transactionTagsRefs) db.transactionTags,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (transactionTagsRefs)
                    await $_getPrefetchedData<
                      TagRow,
                      $TagsTable,
                      TransactionTagRow
                    >(
                      currentTable: table,
                      referencedTable: $$TagsTableReferences
                          ._transactionTagsRefsTable(db),
                      managerFromTypedResult: (p0) => $$TagsTableReferences(
                        db,
                        table,
                        p0,
                      ).transactionTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      TagRow,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (TagRow, $$TagsTableReferences),
      TagRow,
      PrefetchHooks Function({bool transactionTagsRefs})
    >;
typedef $$TransactionTagsTableCreateCompanionBuilder =
    TransactionTagsCompanion Function({
      required int transactionId,
      required int tagId,
      Value<int> rowid,
    });
typedef $$TransactionTagsTableUpdateCompanionBuilder =
    TransactionTagsCompanion Function({
      Value<int> transactionId,
      Value<int> tagId,
      Value<int> rowid,
    });

final class $$TransactionTagsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TransactionTagsTable,
          TransactionTagRow
        > {
  $$TransactionTagsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TransactionsTable _transactionIdTable(_$AppDatabase db) =>
      db.transactions.createAlias(
        $_aliasNameGenerator(
          db.transactionTags.transactionId,
          db.transactions.id,
        ),
      );

  $$TransactionsTableProcessedTableManager get transactionId {
    final $_column = $_itemColumn<int>('transaction_id')!;

    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagsTable _tagIdTable(_$AppDatabase db) => db.tags.createAlias(
    $_aliasNameGenerator(db.transactionTags.tagId, db.tags.id),
  );

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<int>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TransactionTagsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionTagsTable> {
  $$TransactionTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TransactionsTableFilterComposer get transactionId {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionTagsTable> {
  $$TransactionTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TransactionsTableOrderingComposer get transactionId {
    final $$TransactionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableOrderingComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionTagsTable> {
  $$TransactionTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TransactionsTableAnnotationComposer get transactionId {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionTagsTable,
          TransactionTagRow,
          $$TransactionTagsTableFilterComposer,
          $$TransactionTagsTableOrderingComposer,
          $$TransactionTagsTableAnnotationComposer,
          $$TransactionTagsTableCreateCompanionBuilder,
          $$TransactionTagsTableUpdateCompanionBuilder,
          (TransactionTagRow, $$TransactionTagsTableReferences),
          TransactionTagRow,
          PrefetchHooks Function({bool transactionId, bool tagId})
        > {
  $$TransactionTagsTableTableManager(
    _$AppDatabase db,
    $TransactionTagsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> transactionId = const Value.absent(),
                Value<int> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionTagsCompanion(
                transactionId: transactionId,
                tagId: tagId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int transactionId,
                required int tagId,
                Value<int> rowid = const Value.absent(),
              }) => TransactionTagsCompanion.insert(
                transactionId: transactionId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TransactionTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transactionId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (transactionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.transactionId,
                                referencedTable:
                                    $$TransactionTagsTableReferences
                                        ._transactionIdTable(db),
                                referencedColumn:
                                    $$TransactionTagsTableReferences
                                        ._transactionIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable:
                                    $$TransactionTagsTableReferences
                                        ._tagIdTable(db),
                                referencedColumn:
                                    $$TransactionTagsTableReferences
                                        ._tagIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TransactionTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionTagsTable,
      TransactionTagRow,
      $$TransactionTagsTableFilterComposer,
      $$TransactionTagsTableOrderingComposer,
      $$TransactionTagsTableAnnotationComposer,
      $$TransactionTagsTableCreateCompanionBuilder,
      $$TransactionTagsTableUpdateCompanionBuilder,
      (TransactionTagRow, $$TransactionTagsTableReferences),
      TransactionTagRow,
      PrefetchHooks Function({bool transactionId, bool tagId})
    >;
typedef $$TransactionSplitsTableCreateCompanionBuilder =
    TransactionSplitsCompanion Function({
      Value<int> id,
      required int transactionId,
      required int categoryId,
      required Money amount,
    });
typedef $$TransactionSplitsTableUpdateCompanionBuilder =
    TransactionSplitsCompanion Function({
      Value<int> id,
      Value<int> transactionId,
      Value<int> categoryId,
      Value<Money> amount,
    });

final class $$TransactionSplitsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TransactionSplitsTable,
          TransactionSplitRow
        > {
  $$TransactionSplitsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TransactionsTable _transactionIdTable(_$AppDatabase db) =>
      db.transactions.createAlias(
        $_aliasNameGenerator(
          db.transactionSplits.transactionId,
          db.transactions.id,
        ),
      );

  $$TransactionsTableProcessedTableManager get transactionId {
    final $_column = $_itemColumn<int>('transaction_id')!;

    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias(
        $_aliasNameGenerator(db.transactionSplits.categoryId, db.categories.id),
      );

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<int>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TransactionSplitsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionSplitsTable> {
  $$TransactionSplitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Money, Money, int> get amount =>
      $composableBuilder(
        column: $table.amount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$TransactionsTableFilterComposer get transactionId {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionSplitsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionSplitsTable> {
  $$TransactionSplitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  $$TransactionsTableOrderingComposer get transactionId {
    final $$TransactionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableOrderingComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionSplitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionSplitsTable> {
  $$TransactionSplitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Money, int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  $$TransactionsTableAnnotationComposer get transactionId {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionSplitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionSplitsTable,
          TransactionSplitRow,
          $$TransactionSplitsTableFilterComposer,
          $$TransactionSplitsTableOrderingComposer,
          $$TransactionSplitsTableAnnotationComposer,
          $$TransactionSplitsTableCreateCompanionBuilder,
          $$TransactionSplitsTableUpdateCompanionBuilder,
          (TransactionSplitRow, $$TransactionSplitsTableReferences),
          TransactionSplitRow,
          PrefetchHooks Function({bool transactionId, bool categoryId})
        > {
  $$TransactionSplitsTableTableManager(
    _$AppDatabase db,
    $TransactionSplitsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionSplitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionSplitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionSplitsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> transactionId = const Value.absent(),
                Value<int> categoryId = const Value.absent(),
                Value<Money> amount = const Value.absent(),
              }) => TransactionSplitsCompanion(
                id: id,
                transactionId: transactionId,
                categoryId: categoryId,
                amount: amount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int transactionId,
                required int categoryId,
                required Money amount,
              }) => TransactionSplitsCompanion.insert(
                id: id,
                transactionId: transactionId,
                categoryId: categoryId,
                amount: amount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TransactionSplitsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transactionId = false, categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (transactionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.transactionId,
                                referencedTable:
                                    $$TransactionSplitsTableReferences
                                        ._transactionIdTable(db),
                                referencedColumn:
                                    $$TransactionSplitsTableReferences
                                        ._transactionIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (categoryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.categoryId,
                                referencedTable:
                                    $$TransactionSplitsTableReferences
                                        ._categoryIdTable(db),
                                referencedColumn:
                                    $$TransactionSplitsTableReferences
                                        ._categoryIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TransactionSplitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionSplitsTable,
      TransactionSplitRow,
      $$TransactionSplitsTableFilterComposer,
      $$TransactionSplitsTableOrderingComposer,
      $$TransactionSplitsTableAnnotationComposer,
      $$TransactionSplitsTableCreateCompanionBuilder,
      $$TransactionSplitsTableUpdateCompanionBuilder,
      (TransactionSplitRow, $$TransactionSplitsTableReferences),
      TransactionSplitRow,
      PrefetchHooks Function({bool transactionId, bool categoryId})
    >;
typedef $$GoalDetailsTableCreateCompanionBuilder =
    GoalDetailsCompanion Function({
      Value<int> accountId,
      required Money targetAmount,
      Value<DateTime?> targetDate,
    });
typedef $$GoalDetailsTableUpdateCompanionBuilder =
    GoalDetailsCompanion Function({
      Value<int> accountId,
      Value<Money> targetAmount,
      Value<DateTime?> targetDate,
    });

final class $$GoalDetailsTableReferences
    extends BaseReferences<_$AppDatabase, $GoalDetailsTable, GoalDetailRow> {
  $$GoalDetailsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.goalDetails.accountId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<int>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GoalDetailsTableFilterComposer
    extends Composer<_$AppDatabase, $GoalDetailsTable> {
  $$GoalDetailsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<Money, Money, int> get targetAmount =>
      $composableBuilder(
        column: $table.targetAmount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalDetailsTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalDetailsTable> {
  $$GoalDetailsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalDetailsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalDetailsTable> {
  $$GoalDetailsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<Money, int> get targetAmount =>
      $composableBuilder(
        column: $table.targetAmount,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalDetailsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GoalDetailsTable,
          GoalDetailRow,
          $$GoalDetailsTableFilterComposer,
          $$GoalDetailsTableOrderingComposer,
          $$GoalDetailsTableAnnotationComposer,
          $$GoalDetailsTableCreateCompanionBuilder,
          $$GoalDetailsTableUpdateCompanionBuilder,
          (GoalDetailRow, $$GoalDetailsTableReferences),
          GoalDetailRow,
          PrefetchHooks Function({bool accountId})
        > {
  $$GoalDetailsTableTableManager(_$AppDatabase db, $GoalDetailsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalDetailsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalDetailsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalDetailsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> accountId = const Value.absent(),
                Value<Money> targetAmount = const Value.absent(),
                Value<DateTime?> targetDate = const Value.absent(),
              }) => GoalDetailsCompanion(
                accountId: accountId,
                targetAmount: targetAmount,
                targetDate: targetDate,
              ),
          createCompanionCallback:
              ({
                Value<int> accountId = const Value.absent(),
                required Money targetAmount,
                Value<DateTime?> targetDate = const Value.absent(),
              }) => GoalDetailsCompanion.insert(
                accountId: accountId,
                targetAmount: targetAmount,
                targetDate: targetDate,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GoalDetailsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (accountId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.accountId,
                                referencedTable: $$GoalDetailsTableReferences
                                    ._accountIdTable(db),
                                referencedColumn: $$GoalDetailsTableReferences
                                    ._accountIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GoalDetailsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GoalDetailsTable,
      GoalDetailRow,
      $$GoalDetailsTableFilterComposer,
      $$GoalDetailsTableOrderingComposer,
      $$GoalDetailsTableAnnotationComposer,
      $$GoalDetailsTableCreateCompanionBuilder,
      $$GoalDetailsTableUpdateCompanionBuilder,
      (GoalDetailRow, $$GoalDetailsTableReferences),
      GoalDetailRow,
      PrefetchHooks Function({bool accountId})
    >;
typedef $$ShoppingListsTableCreateCompanionBuilder =
    ShoppingListsCompanion Function({
      Value<int> id,
      required String name,
      required int colorValue,
      Value<DateTime> createdAt,
    });
typedef $$ShoppingListsTableUpdateCompanionBuilder =
    ShoppingListsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> colorValue,
      Value<DateTime> createdAt,
    });

final class $$ShoppingListsTableReferences
    extends
        BaseReferences<_$AppDatabase, $ShoppingListsTable, ShoppingListRow> {
  $$ShoppingListsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ShoppingItemsTable, List<ShoppingItemRow>>
  _shoppingItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.shoppingItems,
    aliasName: $_aliasNameGenerator(
      db.shoppingLists.id,
      db.shoppingItems.listId,
    ),
  );

  $$ShoppingItemsTableProcessedTableManager get shoppingItemsRefs {
    final manager = $$ShoppingItemsTableTableManager(
      $_db,
      $_db.shoppingItems,
    ).filter((f) => f.listId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_shoppingItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ShoppingListsTableFilterComposer
    extends Composer<_$AppDatabase, $ShoppingListsTable> {
  $$ShoppingListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> shoppingItemsRefs(
    Expression<bool> Function($$ShoppingItemsTableFilterComposer f) f,
  ) {
    final $$ShoppingItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shoppingItems,
      getReferencedColumn: (t) => t.listId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShoppingItemsTableFilterComposer(
            $db: $db,
            $table: $db.shoppingItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShoppingListsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShoppingListsTable> {
  $$ShoppingListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShoppingListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShoppingListsTable> {
  $$ShoppingListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> shoppingItemsRefs<T extends Object>(
    Expression<T> Function($$ShoppingItemsTableAnnotationComposer a) f,
  ) {
    final $$ShoppingItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shoppingItems,
      getReferencedColumn: (t) => t.listId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShoppingItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.shoppingItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShoppingListsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShoppingListsTable,
          ShoppingListRow,
          $$ShoppingListsTableFilterComposer,
          $$ShoppingListsTableOrderingComposer,
          $$ShoppingListsTableAnnotationComposer,
          $$ShoppingListsTableCreateCompanionBuilder,
          $$ShoppingListsTableUpdateCompanionBuilder,
          (ShoppingListRow, $$ShoppingListsTableReferences),
          ShoppingListRow,
          PrefetchHooks Function({bool shoppingItemsRefs})
        > {
  $$ShoppingListsTableTableManager(_$AppDatabase db, $ShoppingListsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShoppingListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShoppingListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShoppingListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ShoppingListsCompanion(
                id: id,
                name: name,
                colorValue: colorValue,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int colorValue,
                Value<DateTime> createdAt = const Value.absent(),
              }) => ShoppingListsCompanion.insert(
                id: id,
                name: name,
                colorValue: colorValue,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ShoppingListsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({shoppingItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (shoppingItemsRefs) db.shoppingItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (shoppingItemsRefs)
                    await $_getPrefetchedData<
                      ShoppingListRow,
                      $ShoppingListsTable,
                      ShoppingItemRow
                    >(
                      currentTable: table,
                      referencedTable: $$ShoppingListsTableReferences
                          ._shoppingItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ShoppingListsTableReferences(
                            db,
                            table,
                            p0,
                          ).shoppingItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.listId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ShoppingListsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShoppingListsTable,
      ShoppingListRow,
      $$ShoppingListsTableFilterComposer,
      $$ShoppingListsTableOrderingComposer,
      $$ShoppingListsTableAnnotationComposer,
      $$ShoppingListsTableCreateCompanionBuilder,
      $$ShoppingListsTableUpdateCompanionBuilder,
      (ShoppingListRow, $$ShoppingListsTableReferences),
      ShoppingListRow,
      PrefetchHooks Function({bool shoppingItemsRefs})
    >;
typedef $$ShoppingItemsTableCreateCompanionBuilder =
    ShoppingItemsCompanion Function({
      Value<int> id,
      Value<int?> listId,
      required String name,
      Value<Money?> estimatedAmount,
      Value<bool> isChecked,
      Value<DateTime> createdAt,
    });
typedef $$ShoppingItemsTableUpdateCompanionBuilder =
    ShoppingItemsCompanion Function({
      Value<int> id,
      Value<int?> listId,
      Value<String> name,
      Value<Money?> estimatedAmount,
      Value<bool> isChecked,
      Value<DateTime> createdAt,
    });

final class $$ShoppingItemsTableReferences
    extends
        BaseReferences<_$AppDatabase, $ShoppingItemsTable, ShoppingItemRow> {
  $$ShoppingItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ShoppingListsTable _listIdTable(_$AppDatabase db) =>
      db.shoppingLists.createAlias(
        $_aliasNameGenerator(db.shoppingItems.listId, db.shoppingLists.id),
      );

  $$ShoppingListsTableProcessedTableManager? get listId {
    final $_column = $_itemColumn<int>('list_id');
    if ($_column == null) return null;
    final manager = $$ShoppingListsTableTableManager(
      $_db,
      $_db.shoppingLists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_listIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ShoppingItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ShoppingItemsTable> {
  $$ShoppingItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Money?, Money, int> get estimatedAmount =>
      $composableBuilder(
        column: $table.estimatedAmount,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get isChecked => $composableBuilder(
    column: $table.isChecked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ShoppingListsTableFilterComposer get listId {
    final $$ShoppingListsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.shoppingLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShoppingListsTableFilterComposer(
            $db: $db,
            $table: $db.shoppingLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShoppingItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShoppingItemsTable> {
  $$ShoppingItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimatedAmount => $composableBuilder(
    column: $table.estimatedAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isChecked => $composableBuilder(
    column: $table.isChecked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ShoppingListsTableOrderingComposer get listId {
    final $$ShoppingListsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.shoppingLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShoppingListsTableOrderingComposer(
            $db: $db,
            $table: $db.shoppingLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShoppingItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShoppingItemsTable> {
  $$ShoppingItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Money?, int> get estimatedAmount =>
      $composableBuilder(
        column: $table.estimatedAmount,
        builder: (column) => column,
      );

  GeneratedColumn<bool> get isChecked =>
      $composableBuilder(column: $table.isChecked, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ShoppingListsTableAnnotationComposer get listId {
    final $$ShoppingListsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.shoppingLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShoppingListsTableAnnotationComposer(
            $db: $db,
            $table: $db.shoppingLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShoppingItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShoppingItemsTable,
          ShoppingItemRow,
          $$ShoppingItemsTableFilterComposer,
          $$ShoppingItemsTableOrderingComposer,
          $$ShoppingItemsTableAnnotationComposer,
          $$ShoppingItemsTableCreateCompanionBuilder,
          $$ShoppingItemsTableUpdateCompanionBuilder,
          (ShoppingItemRow, $$ShoppingItemsTableReferences),
          ShoppingItemRow,
          PrefetchHooks Function({bool listId})
        > {
  $$ShoppingItemsTableTableManager(_$AppDatabase db, $ShoppingItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShoppingItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShoppingItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShoppingItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> listId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<Money?> estimatedAmount = const Value.absent(),
                Value<bool> isChecked = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ShoppingItemsCompanion(
                id: id,
                listId: listId,
                name: name,
                estimatedAmount: estimatedAmount,
                isChecked: isChecked,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> listId = const Value.absent(),
                required String name,
                Value<Money?> estimatedAmount = const Value.absent(),
                Value<bool> isChecked = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ShoppingItemsCompanion.insert(
                id: id,
                listId: listId,
                name: name,
                estimatedAmount: estimatedAmount,
                isChecked: isChecked,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ShoppingItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({listId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (listId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.listId,
                                referencedTable: $$ShoppingItemsTableReferences
                                    ._listIdTable(db),
                                referencedColumn: $$ShoppingItemsTableReferences
                                    ._listIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ShoppingItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShoppingItemsTable,
      ShoppingItemRow,
      $$ShoppingItemsTableFilterComposer,
      $$ShoppingItemsTableOrderingComposer,
      $$ShoppingItemsTableAnnotationComposer,
      $$ShoppingItemsTableCreateCompanionBuilder,
      $$ShoppingItemsTableUpdateCompanionBuilder,
      (ShoppingItemRow, $$ShoppingItemsTableReferences),
      ShoppingItemRow,
      PrefetchHooks Function({bool listId})
    >;
typedef $$BackupRecordsTableCreateCompanionBuilder =
    BackupRecordsCompanion Function({
      Value<int> id,
      required String fileName,
      required String uri,
      Value<int> sizeBytes,
      required DateTime createdAt,
    });
typedef $$BackupRecordsTableUpdateCompanionBuilder =
    BackupRecordsCompanion Function({
      Value<int> id,
      Value<String> fileName,
      Value<String> uri,
      Value<int> sizeBytes,
      Value<DateTime> createdAt,
    });

class $$BackupRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $BackupRecordsTable> {
  $$BackupRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BackupRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $BackupRecordsTable> {
  $$BackupRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BackupRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BackupRecordsTable> {
  $$BackupRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get uri =>
      $composableBuilder(column: $table.uri, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BackupRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BackupRecordsTable,
          BackupRecordRow,
          $$BackupRecordsTableFilterComposer,
          $$BackupRecordsTableOrderingComposer,
          $$BackupRecordsTableAnnotationComposer,
          $$BackupRecordsTableCreateCompanionBuilder,
          $$BackupRecordsTableUpdateCompanionBuilder,
          (
            BackupRecordRow,
            BaseReferences<_$AppDatabase, $BackupRecordsTable, BackupRecordRow>,
          ),
          BackupRecordRow,
          PrefetchHooks Function()
        > {
  $$BackupRecordsTableTableManager(_$AppDatabase db, $BackupRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BackupRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BackupRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BackupRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> uri = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BackupRecordsCompanion(
                id: id,
                fileName: fileName,
                uri: uri,
                sizeBytes: sizeBytes,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String fileName,
                required String uri,
                Value<int> sizeBytes = const Value.absent(),
                required DateTime createdAt,
              }) => BackupRecordsCompanion.insert(
                id: id,
                fileName: fileName,
                uri: uri,
                sizeBytes: sizeBytes,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BackupRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BackupRecordsTable,
      BackupRecordRow,
      $$BackupRecordsTableFilterComposer,
      $$BackupRecordsTableOrderingComposer,
      $$BackupRecordsTableAnnotationComposer,
      $$BackupRecordsTableCreateCompanionBuilder,
      $$BackupRecordsTableUpdateCompanionBuilder,
      (
        BackupRecordRow,
        BaseReferences<_$AppDatabase, $BackupRecordsTable, BackupRecordRow>,
      ),
      BackupRecordRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$PersonsTableTableManager get persons =>
      $$PersonsTableTableManager(_db, _db.persons);
  $$RecurringRulesTableTableManager get recurringRules =>
      $$RecurringRulesTableTableManager(_db, _db.recurringRules);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db, _db.budgets);
  $$PersonEntriesTableTableManager get personEntries =>
      $$PersonEntriesTableTableManager(_db, _db.personEntries);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$PendingTxnsTableTableManager get pendingTxns =>
      $$PendingTxnsTableTableManager(_db, _db.pendingTxns);
  $$MerchantRulesTableTableManager get merchantRules =>
      $$MerchantRulesTableTableManager(_db, _db.merchantRules);
  $$SenderRulesTableTableManager get senderRules =>
      $$SenderRulesTableTableManager(_db, _db.senderRules);
  $$BudgetAlertsTableTableManager get budgetAlerts =>
      $$BudgetAlertsTableTableManager(_db, _db.budgetAlerts);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$TransactionTagsTableTableManager get transactionTags =>
      $$TransactionTagsTableTableManager(_db, _db.transactionTags);
  $$TransactionSplitsTableTableManager get transactionSplits =>
      $$TransactionSplitsTableTableManager(_db, _db.transactionSplits);
  $$GoalDetailsTableTableManager get goalDetails =>
      $$GoalDetailsTableTableManager(_db, _db.goalDetails);
  $$ShoppingListsTableTableManager get shoppingLists =>
      $$ShoppingListsTableTableManager(_db, _db.shoppingLists);
  $$ShoppingItemsTableTableManager get shoppingItems =>
      $$ShoppingItemsTableTableManager(_db, _db.shoppingItems);
  $$BackupRecordsTableTableManager get backupRecords =>
      $$BackupRecordsTableTableManager(_db, _db.backupRecords);
}

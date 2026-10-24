import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/platform_features.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'person_photo_storage.dart';

/// What [pickContact] got back from the device's address book.
typedef PickedContact = ({String? name, String? phone, String? photoPath});

/// Thrown by [pickContact] when contacts access is off (GitHub #167):
/// XPENC doesn't open the address book at all without it.
class ContactsAccessOff implements Exception {
  const ContactsAccessOff();
}

/// What callers tell the user when [pickContact] throws [ContactsAccessOff].
const contactsAccessOffMessage =
    'Contacts access is off. Turn it on in Settings → Permissions.';

/// Whether contacts access is usable, from its [status] and whether XPENC
/// has [asked] before — see [Settings.contactsPermissionAsked]. A null
/// [status] means no plugin (tests, desktop): nothing is hidden there.
bool contactsAccessAllowed(PermissionStatus? status, {required bool asked}) =>
    switch (status) {
      null || PermissionStatus.granted || PermissionStatus.limited => true,
      // Android also says this after access is turned off — only the first
      // ask is still to come when it was never asked.
      PermissionStatus.notDetermined => !asked,
      PermissionStatus.denied ||
      PermissionStatus.permanentlyDenied ||
      PermissionStatus.restricted => false,
    };

/// Whether every "from contacts" button shows (GitHub #167). Re-checked
/// whenever the app comes back to the front — access is turned on or off
/// in system settings — and whenever XPENC asks.
final contactsAccessProvider = FutureProvider<bool>((ref) async {
  if (!PlatformFeatures.contacts) return false;
  final listener = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(listener.dispose);
  final asked = ref.watch(
    settingsProvider.select((s) => s.valueOrNull?.contactsPermissionAsked),
  );
  PermissionStatus? status;
  try {
    status = await FlutterContacts.permissions.check(PermissionType.read);
  } on MissingPluginException {
    status = null;
  } on PlatformException {
    status = null;
  }
  return contactsAccessAllowed(status, asked: asked ?? false);
});

/// Hands off to the OS's own contact picker — the single path behind every
/// "from contacts" action (Add/Edit person, the Individual tab's "Link
/// contact", the group member picker, the payee picker). Asks for contacts
/// access first and opens nothing without it: a refusal throws
/// [ContactsAccessOff], and from then on those buttons hide.
///
/// A picked photo is copied into app storage straight away (see
/// [PersonPhotoStorage]) and only its path is returned. `null` when the
/// user backs out. Throws `PlatformException` if contacts can't be opened.
Future<PickedContact?> pickContact(AppDatabase db) async {
  final status = await FlutterContacts.permissions.request(PermissionType.read);
  await db.markContactsPermissionAsked();
  if (status != PermissionStatus.granted &&
      status != PermissionStatus.limited) {
    throw const ContactsAccessOff();
  }
  final contact = await FlutterContacts.native.showPicker(
    properties: const {ContactProperty.phone, ContactProperty.photoThumbnail},
  );
  if (contact == null) return null;

  final name = contact.displayName?.trim();
  String? phone;
  String? photoPath;
  if (contact.phones.isNotEmpty) phone = contact.phones.first.number;
  final thumbnail = contact.photo?.thumbnail;
  if (thumbnail != null && thumbnail.isNotEmpty) {
    photoPath = await PersonPhotoStorage.storeBytes(thumbnail);
  }
  return (
    name: name == null || name.isEmpty ? null : name,
    phone: phone,
    photoPath: photoPath,
  );
}

/// The last 10 digits of [phone] — enough to treat `+91 98765 43210` and
/// `098765 43210` as the same number. Null for anything too short to be a
/// real number.
String? _phoneKey(String? phone) {
  if (phone == null) return null;
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 7) return null;
  return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}

/// The existing person (active or archived) a picked contact most likely
/// already is — same phone number first, else the same name ignoring case.
/// Null when it's genuinely someone new. Stops "add from contacts" quietly
/// creating a duplicate of someone already in the app.
PersonRow? matchExistingPerson(
  PickedContact contact,
  Iterable<PersonRow> people,
) {
  final key = _phoneKey(contact.phone);
  if (key != null) {
    for (final p in people) {
      if (_phoneKey(p.phone) == key) return p;
    }
  }
  final name = contact.name?.toLowerCase();
  if (name == null) return null;
  for (final p in people) {
    if (p.name.trim().toLowerCase() == name) return p;
  }
  return null;
}

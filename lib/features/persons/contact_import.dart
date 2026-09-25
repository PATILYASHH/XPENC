import 'package:flutter_contacts/flutter_contacts.dart';

import '../../data/database.dart';
import 'person_photo_storage.dart';

/// What [pickContact] got back from the device's address book. [phone] and
/// [photoPath] are only ever filled when contacts access was granted —
/// [detailsAllowed] false means the user picked someone but denied it, so
/// only the name came through.
typedef PickedContact = ({
  String? name,
  String? phone,
  String? photoPath,
  bool detailsAllowed,
});

/// Hands off to the OS's own contact picker — the single path behind every
/// "from contacts" action (Add/Edit person, the Individual tab's "Link
/// contact", the group member picker). The picker itself is always
/// permissionless and always returns a name, but on Android asking it for
/// phone or photo too requires `READ_CONTACTS`, so this requests that
/// first; a denial just falls back to name-only, never a hard failure.
///
/// A picked photo is copied into app storage straight away (see
/// [PersonPhotoStorage]) and only its path is returned. `null` when the
/// user backs out. Throws `PlatformException` if contacts can't be opened.
Future<PickedContact?> pickContact() async {
  final status = await FlutterContacts.permissions.request(PermissionType.read);
  final granted =
      status == PermissionStatus.granted || status == PermissionStatus.limited;
  final contact = await FlutterContacts.native.showPicker(
    properties: granted
        ? const {ContactProperty.phone, ContactProperty.photoThumbnail}
        : null,
  );
  if (contact == null) return null;

  final name = contact.displayName?.trim();
  String? phone;
  String? photoPath;
  if (granted) {
    if (contact.phones.isNotEmpty) phone = contact.phones.first.number;
    final thumbnail = contact.photo?.thumbnail;
    if (thumbnail != null && thumbnail.isNotEmpty) {
      photoPath = await PersonPhotoStorage.storeBytes(thumbnail);
    }
  }
  return (
    name: name == null || name.isEmpty ? null : name,
    phone: phone,
    photoPath: photoPath,
    detailsAllowed: granted,
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

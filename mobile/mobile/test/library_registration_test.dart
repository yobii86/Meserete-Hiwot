import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/app/deep_links.dart';
import 'package:mezmur_zelideta/core/l10n/error_text.dart';
import 'package:mezmur_zelideta/core/network/api_exception.dart';
import 'package:mezmur_zelideta/features/library/books_screen.dart';
import 'package:mezmur_zelideta/l10n/app_localizations_en.dart';
import 'package:mezmur_zelideta/models/admin.dart';
import 'package:mezmur_zelideta/models/library.dart';
import 'package:mezmur_zelideta/services/book_vault.dart';

void main() {
  final l = AppLocalizationsEn();

  group('education library', () {
    test('a digital book carries its PDF link; a printed one its availability', () {
      final d = Book.fromJson({'id': 3, 'title': 'ዶግማ', 'author': 'መምህር', 'code': 'EDU-1', 'kind': 'digital', 'file_url': '/library/books/3/file', 'file_size': 2048, 'downloads': 5, 'available': null});
      expect(d.isDigital, isTrue);
      expect(d.fileUrl, '/library/books/3/file');
      expect(d.downloads, 5);
      expect(d.available, isNull);
      final p = Book.fromJson({'id': 4, 'title': 'መጽሐፍ ቅዱስ', 'code': 'EDU-2', 'kind': 'physical', 'available': 2, 'quantity': 3, 'cover_url': '/uploads/c.png', 'my_request': 'approved'});
      expect(p.isDigital, isFalse);
      expect(p.available, 2);
      expect(p.coverUrl, '/uploads/c.png');
      expect(p.myRequest, 'approved');
      expect(Book.fromJson({'id': 5, 'title': 'x', 'code': 'c'}).kind, 'physical');
    });

    test('a request reads its book and member; only requested / approved are open', () {
      final r = BookRequest.fromJson({
        'id': 9, 'status': 'approved', 'note': 'ለፈተና', 'borrowing_id': null, 'created_at': '2026-10-01T10:00:00Z', 'needed_on': '2026-10-05',
        'book': {'id': 4, 'title': 'መጽሐፍ ቅዱስ', 'code': 'EDU-2', 'available': 1},
        'user': {'id': 7, 'full_name': 'አበበ', 'member_id': 'MZ-7', 'phone': '0911000000'},
      });
      expect(r.isOpen, isTrue);
      expect(r.bookTitle, 'መጽሐፍ ቅዱስ');
      expect(r.bookAvailable, 1);
      expect(r.userName, 'አበበ');
      expect(r.neededOn, isNotNull);
      for (final s in ['issued', 'rejected', 'cancelled']) {
        expect(BookRequest.fromJson({'id': 1, 'status': s, 'book': {'id': 1, 'title': 't'}}).isOpen, isFalse);
      }
      expect(bookRequestStatusLabel(l, 'issued'), l.libReqIssued);
      expect(bookRequestStatusLabel(l, 'requested'), l.libRequested);
    });

    test('items know their book kind and author', () {
      final i = ItemModel.fromJson({'id': 1, 'name': 'ዶግማ', 'code': 'EDU-1', 'kind': 'digital', 'author': 'መምህር', 'has_file': true, 'downloads': 2, 'quantity': 0, 'available_quantity': 0});
      expect(i.kind, 'digital');
      expect(i.author, 'መምህር');
      expect(i.hasFile, isTrue);
      expect(Perm.educationRegister, 'education.register');
    });

    test('book request notifications and registrations open the right page', () {
      expect(routeForEntity('library_request', 12), '/library-request/12');
      expect(routeForEntity('edu_class', 3), '/edu/classes');
    });

    test('downloaded books are kept encrypted and open only with this install\'s key', () {
      final pdf = Uint8List.fromList('%PDF-1.4 a small book'.codeUnits);
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final sealed = BookVault.encrypt(pdf, key);
      expect(String.fromCharCodes(sealed).contains('%PDF'), isFalse); // not a readable PDF
      expect(BookVault.encrypt(pdf, key), isNot(equals(sealed))); // fresh nonce each time
      expect(BookVault.decrypt(sealed, key), pdf);
      final other = Uint8List.fromList(List.generate(32, (i) => 255 - i));
      expect(() => BookVault.decrypt(sealed, other), throwsA(isA<BookVaultException>()));
      final tampered = Uint8List.fromList(sealed)..[20] ^= 1;
      expect(() => BookVault.decrypt(tampered, key), throwsA(isA<BookVaultException>()));
    });

    test('library errors read as sentences', () {
      expect(errorText(l, ApiException(status: 409, code: 'REQUEST_EXISTS')), l.errRequestExists);
      expect(errorText(l, ApiException(status: 400, code: 'BOOK_IS_DIGITAL')), l.errBookIsDigital);
      expect(errorText(l, ApiException(status: 409, code: 'REQUEST_CLOSED')), l.errRequestClosed);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/clients/client_tags.dart';

void main() {
  group('isDuplicateTag', () {
    test('ignores case, spaces and punctuation', () {
      expect(isDuplicateTag(defaultClientTags, 'interior  designer', ''), isTrue);
      expect(isDuplicateTag(defaultClientTags, 'Interior-Designer', ''), isTrue);
      expect(isDuplicateTag(defaultClientTags, 'SHOWROOM', ''), isTrue);
      expect(isDuplicateTag(defaultClientTags, 'Supplier', ''), isFalse);
    });

    test('compares Arabic names, letter forms unified, across languages', () {
      expect(isDuplicateTag(defaultClientTags, 'Plant', 'ورشه'), isTrue); // ة / ه
      expect(isDuplicateTag(defaultClientTags, 'مصنع', ''), isTrue); // Arabic typed in the English field
      expect(isDuplicateTag(defaultClientTags, 'Supplier', 'مورد'), isFalse);
    });

    test('renaming a tag may keep its own name', () {
      expect(isDuplicateTag(defaultClientTags, 'Factory', 'مصنع', exceptId: 'factory'), isFalse);
      expect(isDuplicateTag(defaultClientTags, 'Factory', '', exceptId: 'workshop'), isTrue);
    });

    test('an empty Arabic name never clashes', () {
      final tags = [const ClientTag(id: 'a', en: 'A')];
      expect(isDuplicateTag(tags, 'B', ''), isFalse);
    });
  });
}

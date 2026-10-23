import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/login_name.dart';

void main() {
  test('usernames become hidden emails, emails stay', () {
    expect(loginEmailFor(' Ali.Hassan '), 'ali.hassan@$usernameDomain');
    expect(loginEmailFor(' ali@woodpanelsco.com '), 'ali@woodpanelsco.com');
  });

  test('username of an email', () {
    expect(usernameOf('ali.hassan@$usernameDomain'), 'ali.hassan');
    expect(usernameOf('ALI@${usernameDomain.toUpperCase()}'), 'ali');
    expect(usernameOf('ali@woodpanelsco.com'), isNull);
    expect(loginNameOf('ali@woodpanelsco.com'), 'ali@woodpanelsco.com');
    expect(loginNameOf('driver1@$usernameDomain'), 'driver1');
  });

  test('valid usernames', () {
    for (final ok in ['ali', 'Ali.Hassan', 'driver_01', 'a-b', '123']) {
      expect(isValidUsername(ok), isTrue, reason: ok);
    }
    for (final bad in ['', 'ab', '.ali', 'ali.', 'a..b', 'ali hassan', 'ali@x', 'علي', 'a' * 31]) {
      expect(isValidUsername(bad), isFalse, reason: bad);
    }
  });

  test('suggested usernames', () {
    expect(suggestUsername('Ali Hassan Omar', {}), 'ali.omar');
    expect(suggestUsername('  Sami  ', {}), 'sami');
    expect(suggestUsername('Ali Omar', {'ali.omar', 'ali.omar2'}), 'ali.omar3');
    expect(suggestUsername('محمد علي', {}), 'mhmd.aly');
    expect(suggestUsername('Jo', {}), 'jo0');
    expect(suggestUsername('—', {}), isNull);
    expect(usernamesOf(['a@x.com', 'b.c@$usernameDomain']), {'b.c'});
  });
}

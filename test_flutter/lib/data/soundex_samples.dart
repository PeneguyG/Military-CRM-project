import '../models/crm_models.dart';
import '../utils/rich_text_content.dart';

/// All records are fictional; reserved example.com email addresses and 555 numbers.
class SoundexSamples {
  static String note(String heading, String body) => RichTextContent.encode([
    {
      'insert': heading,
      'attributes': {'bold': true},
    },
    {'insert': '\n'},
    {'insert': body},
    {
      'insert': '\n',
      'attributes': {'list': 'bullet'},
    },
    {
      'insert': 'Fictional Soundex demo record.',
      'attributes': {'italic': true},
    },
    {'insert': '\n'},
    {
      'insert': 'Example website',
      'attributes': {'link': 'https://example.com'},
    },
    {'insert': '\n'},
  ]);

  static List<Organization> get organizations => [
    Organization(
      latitude: 36.529,
      longitude: -87.359,
      coordinateSource: 'Fictional demo pin',
      name: 'Smith Readiness Group [Demo]',
      industry: 'Defense logistics',
      address: '101 Training Avenue, Clarksville, TN 37040',
      phone: '2025550101',
      email: 'smith.group@example.com',
      notes: note(
        'Training partnership',
        'Robert leads the quarterly readiness workshop and equipment review.',
      ),
    ),
    Organization(
      latitude: 34.731,
      longitude: -86.586,
      coordinateSource: 'Fictional demo pin',
      name: 'Ashcraft Aviation Center [Demo]',
      industry: 'Aerospace maintenance',
      address: '220 Flight Road, Huntsville, AL 35801',
      phone: '2025550102',
      email: 'ashcraft.center@example.com',
      notes: note(
        'Aviation planning',
        'Coordinate helicopter maintenance and technician certification with Jackson.',
      ),
    ),
    Organization(
      latitude: 36.851,
      longitude: -76.286,
      coordinateSource: 'Fictional demo pin',
      name: 'Pfister Maritime Institute [Demo]',
      industry: 'Maritime education',
      address: '330 Harbor Lane, Norfolk, VA 23510',
      phone: '2025550103',
      email: 'pfister.institute@example.com',
      notes: note(
        'Community outreach',
        'Plan veteran mentorship and coastal navigation seminars with Catherine.',
      ),
    ),
  ];

  static List<Contact> contacts(List<int> organizationIds, int tagId) {
    const people = [
      (
        'John',
        'Smith',
        'Army',
        'Sergeant',
        'Training coordinator',
        'Emily',
        'Charlotte',
        9,
      ),
      (
        'Robert',
        'Johnson',
        'Army',
        'Major',
        'Readiness director',
        'Sarah',
        'Oliver',
        12,
      ),
      (
        'Catherine',
        'Ashcraft',
        'Air Force',
        'Captain',
        'Aviation program manager',
        'Michael',
        'Amelia',
        7,
      ),
      (
        'Steven',
        'Jackson',
        'Air Force',
        'Master Sergeant',
        'Maintenance supervisor',
        'Rebecca',
        'Henry',
        11,
      ),
      (
        'Philip',
        'Pfister',
        'Navy',
        'Commander',
        'Maritime education director',
        'Elizabeth',
        'Theodore',
        14,
      ),
      (
        'Margaret',
        'Williams',
        'Navy',
        'Lieutenant',
        'Veteran outreach coordinator',
        'Thomas',
        'Sophia',
        6,
      ),
    ];
    return [
      for (var i = 0; i < people.length; i++)
        Contact(
          latitude:
              [36.529, 34.731, 36.851][i ~/ 2] + (i.isEven ? 0.025 : -0.025),
          longitude:
              [-87.359, -86.586, -76.286][i ~/ 2] + (i.isEven ? 0.035 : -0.035),
          coordinateSource: 'Fictional demo pin',
          organizationId: organizationIds[i ~/ 2],
          prefix: i.isEven ? 'Dr.' : 'Mx.',
          firstName: people[i].$1,
          lastName: people[i].$2,
          suffix: 'Ret.',
          militaryBranch: people[i].$3,
          militaryRank: people[i].$4,
          preferredContactMethod: i.isEven ? 'Email' : 'Call',
          lifeStatus: 'alive',
          customTagIds: [tagId],
          title: people[i].$5,
          phone: '202555011${i}',
          phoneLabel: 'Mobile',
          additionalPhones: [
            ContactPhoneNumber(label: 'Work', number: '202555012${i}'),
          ],
          email:
              '${people[i].$1.toLowerCase()}.${people[i].$2.toLowerCase()}@example.com',
          emailLabel: 'Work',
          additionalEmails: [
            ContactEmailAddress(
              label: 'Personal',
              address: 'demo.person${i + 1}@example.com',
            ),
          ],
          address:
              '${410 + i} Example Street, ${['Clarksville, TN 37040', 'Huntsville, AL 35801', 'Norfolk, VA 23510'][i ~/ 2]}',
          spouseName: people[i].$6,
          childrenInfo:
              '${people[i].$7}, age ${people[i].$8}; enjoys swimming.',
          children: [ChildRecord(name: people[i].$7, age: people[i].$8)],
          notes: note(
            'Relationship background',
            '${people[i].$1} supports community volunteering and the annual veterans scholarship program.',
          ),
          talkingPoints: note(
            'Next conversation',
            'Discuss readiness, leadership mentoring, and the November training calendar. Ask about ${people[i].$6} and ${people[i].$7}.',
          ),
        ),
    ];
  }
}

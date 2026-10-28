import 'package:greeting_app/crm_store.dart';
import 'package:greeting_app/models/crm_models.dart';

CrmStore sampleStore() => CrmStore(
  organizations: const [
    Organization(
      id: 1,
      name: 'Fort Liberty Support Group',
      industry: 'Military support',
      address: 'Fayetteville, NC',
      phone: '+1-202-555-0101',
      email: 'support@example.com',
      notes:
          'Fictional demonstration organization. Coordinates family readiness events.',
    ),
    Organization(
      id: 2,
      name: 'Sentinel Defense Systems',
      industry: 'Defense technology',
      address: 'Arlington, VA',
      phone: '+1-202-555-0102',
      email: 'liaison@example.com',
      notes:
          'Fictional demonstration organization. Quarterly logistics briefings.',
    ),
    Organization(
      id: 3,
      name: 'Veterans Outreach Unit',
      industry: 'Veteran services',
      address: 'Nashville, TN',
      notes: 'Former regional partner.',
      isArchived: true,
    ),
  ],
  contacts: const [
    Contact(
      id: 1,
      organizationId: 1,
      firstName: 'Alex',
      lastName: 'Morgan',
      title: 'Major',
      phone: '+1-202-555-0111',
      email: 'alex.morgan@example.com',
      address: 'Fayetteville, NC',
      spouseName: 'Jordan',
      childrenInfo: 'Two children',
      talkingPoints: 'Family readiness event; volunteer schedule.',
      notes: 'Fictional sample contact. Prefers afternoon calls.',
    ),
    Contact(
      id: 2,
      organizationId: 2,
      firstName: 'Taylor',
      lastName: 'Reed',
      title: 'Liaison Officer',
      phone: '+1-202-555-0112',
      email: 'taylor.reed@example.com',
      address: 'Arlington, VA',
      talkingPoints: 'Upcoming logistics workshop.',
      status: ContactStatus.inactive,
    ),
    Contact(
      id: 3,
      organizationId: 3,
      firstName: 'Sam',
      lastName: 'Hayes',
      title: 'Colonel (Ret.)',
      status: ContactStatus.deceased,
      isArchived: true,
      notes: 'Historical contact retained in full.',
    ),
  ],
  interactions: [
    InteractionLog(
      id: 1,
      contactId: 1,
      organizationId: 1,
      date: DateTime.now().subtract(const Duration(days: 3)),
      type: 'Call',
      summary: 'Discussed the next family readiness event.',
      followUpDate: DateTime.now().add(const Duration(days: 7)),
    ),
    InteractionLog(
      id: 2,
      contactId: 2,
      organizationId: 2,
      date: DateTime.now().subtract(const Duration(days: 1)),
      type: 'Email',
      summary: 'Shared workshop agenda.',
    ),
  ],
);

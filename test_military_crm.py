import unittest
from military_crm import MilitaryCRMDatabase, CRMDatabaseError, phone_action_uris


class CRMTests(unittest.TestCase):
    def setUp(self):
        self.db = MilitaryCRMDatabase(':memory:')
        self.db.initialize_database()
        self.org = self.db.add_organization('Defense Team', industry='Aviation', city='Austin', notes='logistics')
        self.contact = self.db.add_contact('Jane', 'Smith', self.org, talking_points='readiness planning',
                                           primary_phone='+1 (512) 555-0100')

    def tearDown(self):
        self.db.close()

    def log(self, contact=None, **fields):
        return self.db.log_interaction(contact or self.contact, 'Call', 'Outbound', 'Discussed plans', **fields)

    def test_search_and_index_sync(self):
        for query in ['Jane Smith', 'logistics', 'readiness', 'Defense', 'Austin']:
            self.assertEqual(len(self.db.search_records(query)), 1)
        self.assertEqual(len(self.db.search_records('Smyth', use_soundex=True)), 1)
        self.assertEqual(self.db.search_records('Smyth'), [])
        self.assertEqual(len(self.db.search_records('', industry='aviation', location='austin')), 1)
        self.assertEqual(self.db.search_records('', industry='Navy'), [])
        with self.db.connection:
            self.db.connection.execute('UPDATE organizations SET name = ?, notes = ? WHERE id = ?',
                                       ('New Unit', 'deployment', self.org))
        self.assertEqual(len(self.db.search_records('deployment')), 1)
        self.assertEqual(self.db.search_records('logistics'), [])
        self.db.initialize_database()
        self.assertEqual(len(self.db.search_records('deployment')), 1)

    def test_literal_untrusted_search(self):
        for query in ['" OR *', "' OR 1=1 --", '%', '_', 'AND', '!!!']:
            self.assertEqual(self.db.search_records(query), [])

    def test_stale_uses_latest(self):
        never = self.db.add_contact('Never', 'Called')
        stale = self.db.add_contact('Old', 'Contact')
        self.log(stale, occurred_at='2000-01-01')
        self.log(occurred_at='2000-01-01')
        self.log()
        self.assertEqual({r['id'] for r in self.db.get_uncontacted_contacts(30)}, {never, stale})
        for bad in [-1, 1.5, True, '30']:
            with self.assertRaises(ValueError):
                self.db.get_uncontacted_contacts(bad)

    def test_inclusive_date_range_and_timezone(self):
        self.log(occurred_at='2026-10-01T23:59:59-05:00')
        self.log(occurred_at='2026-10-02T23:59:59.999999Z')
        other = self.db.add_organization('Other')
        person = self.db.add_contact('Other', 'Person', other)
        self.log(person, occurred_at='2026-10-03T00:00:00Z')
        self.assertEqual(self.db.get_distinct_organizations_contacted('2026-10-02', '2026-10-02'), 1)
        self.assertEqual(self.db.get_distinct_organizations_contacted('2026-10-01', '2026-10-01'), 0)
        with self.assertRaises(ValueError):
            self.db.get_distinct_organizations_contacted('2026-10-03', '2026-10-01')

    def test_constraints_and_cascades(self):
        with self.assertRaises(CRMDatabaseError):
            self.db.add_contact('Bad', 'FK', organization_id=9999)
        with self.assertRaises(CRMDatabaseError):
            self.db.log_interaction(self.contact, 'Invalid', 'Outbound', 'summary')
        with self.assertRaises(CRMDatabaseError):
            self.log(follow_up_required=2)
        self.log(follow_up_required=True, follow_up_date='2026-11-01')
        with self.db.connection:
            self.db.connection.execute('DELETE FROM organizations WHERE id = ?', (self.org,))
        self.assertIsNone(self.db.search_records('Jane')[0]['organization_id'])
        self.assertEqual(self.db.search_records('logistics'), [])
        with self.db.connection:
            self.db.connection.execute('DELETE FROM contacts WHERE id = ?', (self.contact,))
        self.assertEqual(self.db.connection.execute('SELECT count(*) FROM interactions').fetchone()[0], 0)
        self.assertEqual(self.db.search_records('readiness'), [])

    def test_uris_and_field_validation(self):
        self.assertEqual(self.db.get_contact_action_uris(self.contact),
                         {'call_uri': 'tel:+15125550100', 'sms_uri': 'sms:+15125550100'})
        self.assertEqual(phone_action_uris(None), {'call_uri': None, 'sms_uri': None})
        for bad in ['5551234;ext=2', '5551234?body=test', '++123', 'abc']:
            with self.assertRaises(ValueError):
                phone_action_uris(bad)
        with self.assertRaises(KeyError):
            self.db.get_contact_action_uris(999)
        with self.assertRaises(ValueError):
            self.db.add_contact('Bad', 'Column', **{'id) VALUES (1); --': 'bad'})


if __name__ == '__main__':
    unittest.main()

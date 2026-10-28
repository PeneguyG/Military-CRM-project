# Military CRM SQLite storage

Requires Python 3.10+ and SQLite with FTS5. No third-party Python packages.

```python
from military_crm import MilitaryCRMDatabase

with MilitaryCRMDatabase('military_crm.sqlite3') as db:
    db.initialize_database()
    organization = db.add_organization('Operations Group', industry='Defense')
    contact = db.add_contact('Jane', 'Smith', organization,
                             primary_phone='+1 (512) 555-0100',
                             talking_points='Training and readiness')
    db.log_interaction(contact, 'Call', 'Outbound', 'Discussed training',
                       follow_up_required=True, follow_up_date='2026-11-03')
    print(db.search_records('readiness', industry='Defense'))
    print(db.search_records('Smyth', use_soundex=True))
    print(db.get_uncontacted_contacts(30))
    print(db.get_distinct_organizations_contacted('2026-10-01', '2026-10-31'))
    print(db.get_contact_action_uris(contact))
```

Optional keyword fields follow `schema.sql`. Methods return inserted IDs, lists
of dictionaries, an integer count, or URI dictionaries as appropriate. Missing
contacts raise `KeyError`; absent phones yield `None` URI values. Phone numbers
preserve a supplied international prefix; extensions and alphabetic numbers
raise `ValueError`. The application can render returned URIs as clickable links.

`CRMDatabaseError` wraps SQLite errors and preserves their cause. Failed writes
roll back automatically. Use one instance per thread. Foreign keys are enabled
on every helper connection; external SQLite clients must enable them too.

Timestamps are UTC, with helper input normalized from ISO timestamps (naive input
means UTC). Direct SQL writers must use `YYYY-MM-DD HH:MM:SS[.ffffff]` in UTC so
indexed comparisons remain correct. Date ranges include both calendar dates.
All interaction types and directions count as contact. Organization counts use
the contact's current organization; they do not preserve affiliation history.

FTS indexes names, organization notes, general notes, and talking points, with
triggers maintaining organization renames, reassignment, and deletion. Literal
FTS tokens are combined with AND; substring and optional surname Soundex matches
are alternatives. Industry/location filters apply to all alternatives. LIKE
wildcards and FTS operators in user text are treated literally. SQLite LIKE and
the fallback English Soundex provide limited Unicode name matching.

`queries.sql` provides standalone query examples. `schema.sql` is transactional
and repeatable, with `user_version = 1`; initialization rebuilds FTS and should
run during startup/maintenance, not on every request. Future schema changes need
explicit versioned migrations; `CREATE TABLE IF NOT EXISTS` does not migrate
existing tables. WAL allows readers during writes, with a ten-second busy timeout.

SQLite files and backups contain personal data, including family details and
photos. Deploy with restricted filesystem access, encrypted storage, and a
backup/retention policy appropriate to the application. SQLite itself does not
provide encryption or application-level access control. Use SQLite's backup API
for live backups rather than copying only the database file while WAL is active.

Run verification with `python -m unittest -v`.

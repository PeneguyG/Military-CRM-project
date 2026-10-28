"""SQLite CRM interface. Dates are ISO dates; timestamps are stored in UTC."""

from datetime import date, datetime, timezone
from pathlib import Path
import re
import sqlite3


class CRMDatabaseError(RuntimeError):
    """A database operation failed; the original sqlite exception is __cause__."""


def _soundex(value):
    """Portable English Soundex fallback for SQLite builds without SOUNDEx."""
    letters = re.sub('[^A-Z]', '', str(value or '').upper())
    if not letters:
        return '?000'
    codes = dict.fromkeys('BFPV', '1')
    for chars, code in [('CGJKQSXZ', '2'), ('DT', '3'), ('L', '4'), ('MN', '5'), ('R', '6')]:
        codes.update(dict.fromkeys(chars, code))
    result, previous = letters[0], codes.get(letters[0], '')
    for letter in letters[1:]:
        code = codes.get(letter, '')
        if code and code != previous:
            result += code
        previous = code
    return (result + '000')[:4]


def phone_action_uris(phone):
    """Return tel/sms URIs, or None values for a missing number.

    Preserve a leading international +. Reject extensions and letters rather
    than silently routing a call to a different number. No country is inferred.
    """
    if phone is None or not str(phone).strip():
        return {'call_uri': None, 'sms_uri': None}
    phone = str(phone).strip()
    if not re.fullmatch(r'\+?[0-9\s().-]+', phone):
        raise ValueError('Phone number must contain digits and standard separators only')
    number = ('+' if phone.startswith('+') else '') + re.sub(r'\D', '', phone)
    if not 3 <= len(number.lstrip('+')) <= 15:
        raise ValueError('Phone number must contain 3 to 15 digits')
    return {'call_uri': 'tel:' + number, 'sms_uri': 'sms:' + number}


class MilitaryCRMDatabase:
    """One connection per instance/thread; close explicitly or use a with block.

    Each write is atomic. sqlite errors are wrapped in CRMDatabaseError;
    invalid helper arguments raise ValueError. FTS5 support is required.
    """

    def __init__(self, database_path='military_crm.sqlite3'):
        self.connection = sqlite3.connect(database_path, timeout=10)
        self.connection.row_factory = sqlite3.Row
        self.connection.execute('PRAGMA foreign_keys = ON')
        self.connection.execute('PRAGMA busy_timeout = 10000')
        try:
            self.connection.execute("SELECT soundex('Smith')")
        except sqlite3.OperationalError:
            self.connection.create_function('soundex', 1, _soundex, deterministic=True)

    def close(self):
        """Close the connection."""
        self.connection.close()

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    def initialize_database(self):
        """Create schema/indexes atomically and enable WAL for concurrent readers."""
        try:
            self.connection.execute('PRAGMA journal_mode = WAL')
            self.connection.executescript(Path(__file__).with_name('schema.sql').read_text(encoding='utf-8'))
        except sqlite3.Error as exc:
            self.connection.rollback()
            raise CRMDatabaseError('Could not initialize CRM database (FTS5 required)') from exc

    def _insert(self, table, values):
        # Table names are internal constants; column names are schema-whitelisted.
        allowed = {row['name'] for row in self.connection.execute(f'PRAGMA table_info({table})')}
        invalid = set(values) - (allowed - {'id', 'created_at', 'updated_at'})
        if invalid:
            raise ValueError(f'Unsupported fields: {sorted(invalid)}')
        columns = ', '.join(values)
        placeholders = ', '.join('?' for _ in values)
        try:
            with self.connection:
                cursor = self.connection.execute(
                    f'INSERT INTO {table} ({columns}) VALUES ({placeholders})', tuple(values.values()))
            return cursor.lastrowid
        except sqlite3.Error as exc:
            raise CRMDatabaseError(f'Could not insert into {table}') from exc

    def add_organization(self, name, **fields):
        """Insert an organization and return its ID; optional fields match schema.sql."""
        return self._insert('organizations', dict(name=name, **fields))

    def add_contact(self, first_name, last_name, organization_id=None, **fields):
        """Insert a contact; children_details accepts JSON text or a formatted string."""
        return self._insert('contacts', dict(first_name=first_name, last_name=last_name,
                                            organization_id=organization_id, **fields))

    def log_interaction(self, contact_id, interaction_type, direction, summary, **fields):
        """Log communication; aware ISO timestamps are normalized to UTC.

        Naive timestamps are interpreted as UTC. Omitted occurred_at uses SQLite's UTC clock.
        """
        if 'occurred_at' in fields:
            try:
                stamp = datetime.fromisoformat(fields['occurred_at'])
                fields['occurred_at'] = stamp.replace(tzinfo=stamp.tzinfo or timezone.utc).astimezone(
                    timezone.utc).strftime('%Y-%m-%d %H:%M:%S.%f')
            except (TypeError, ValueError) as exc:
                raise ValueError('occurred_at must be an ISO timestamp') from exc
        if fields.get('follow_up_date') is not None:
            self._date(fields['follow_up_date'])
        return self._insert('interactions', dict(contact_id=contact_id,
                            interaction_type=interaction_type, direction=direction, summary=summary, **fields))

    def _query(self, sql, parameters):
        try:
            return [dict(row) for row in self.connection.execute(sql, parameters)]
        except sqlite3.Error as exc:
            raise CRMDatabaseError('CRM query failed') from exc

    def search_records(self, query_string, use_soundex=False, industry=None, location=None):
        """Search literal substrings OR literal FTS tokens OR optional surname Soundex.

        Industry and location are additional substring filters. Location searches
        contact and organization address fields. Empty query lists filtered contacts.
        User text is never interpreted as FTS operators or SQL wildcards.
        """
        query_string = query_string.strip()
        tokens = re.findall(r'\w+', query_string, flags=re.UNICODE)
        fts = ' AND '.join('"' + token + '"' for token in tokens) or '""'
        def pattern(value):
            return '%' + value.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_') + '%'
        params = {'query': query_string, 'like': pattern(query_string), 'fts': fts,
                  'phonetic': int(use_soundex and bool(query_string)),
                  'industry': None if industry is None else pattern(industry),
                  'location': None if location is None else pattern(location)}
        searchable = ['c.first_name', 'c.last_name', "c.first_name || ' ' || c.last_name",
                      'o.name', 'o.industry', 'c.general_notes', 'c.talking_points', 'o.notes']
        locations = [f'{alias}.{field}' for alias in ('c', 'o') for field in
                     ('address_line1', 'address_line2', 'city', 'state', 'postal_code', 'country')]
        match = ' OR '.join(f"{col} LIKE :like ESCAPE '\\'" for col in searchable + locations)
        location_match = ' OR '.join(f"{col} LIKE :location ESCAPE '\\'" for col in locations)
        return self._query(f"""
            SELECT c.*, o.name AS organization_name FROM contacts c
            LEFT JOIN organizations o ON o.id = c.organization_id
            WHERE (:query = '' OR {match}
                OR c.id IN (SELECT rowid FROM contacts_fts WHERE contacts_fts MATCH :fts)
                OR (:phonetic = 1 AND soundex(c.last_name) = soundex(:query)))
            AND (:industry IS NULL OR o.industry LIKE :industry ESCAPE '\\')
            AND (:location IS NULL OR {location_match})
            ORDER BY c.last_name COLLATE NOCASE, c.first_name COLLATE NOCASE, c.id
        """, params)

    def get_uncontacted_contacts(self, days_threshold: int):
        """Return never-contacted contacts and contacts whose latest interaction is older than N days."""
        if type(days_threshold) is not int or days_threshold < 0:
            raise ValueError('days_threshold must be a nonnegative integer')
        return self._query("""
            SELECT c.*, (SELECT MAX(i.occurred_at) FROM interactions i
                          WHERE i.contact_id = c.id) AS last_interaction_at
            FROM contacts c
            WHERE NOT EXISTS (SELECT 1 FROM interactions i WHERE i.contact_id = c.id)
               OR (SELECT MAX(i.occurred_at) FROM interactions i WHERE i.contact_id = c.id)
                  < datetime('now', '-' || :days_threshold || ' days')
            ORDER BY last_interaction_at, c.id
        """, {'days_threshold': days_threshold})

    @staticmethod
    def _date(value):
        if not isinstance(value, str) or not re.fullmatch(r'\d{4}-\d{2}-\d{2}', value):
            raise ValueError('Dates must use YYYY-MM-DD')
        return date.fromisoformat(value)

    def get_distinct_organizations_contacted(self, start_date: str, end_date: str) -> int:
        """Count current organizations with interactions on the inclusive UTC calendar dates."""
        if self._date(start_date) > self._date(end_date):
            raise ValueError('start_date must not be after end_date')
        return self._query("""
            SELECT COUNT(DISTINCT c.organization_id) AS count
            FROM interactions i JOIN contacts c ON c.id = i.contact_id
            WHERE i.occurred_at >= :start_date
              AND i.occurred_at < date(:end_date, '+1 day')
        """, {'start_date': start_date, 'end_date': end_date})[0]['count']

    def get_contact_action_uris(self, contact_id: int) -> dict:
        """Use primary phone, falling back to secondary. Raise KeyError if absent."""
        rows = self._query('SELECT primary_phone, secondary_phone FROM contacts WHERE id = ?', (contact_id,))
        if not rows:
            raise KeyError(f'Contact {contact_id} does not exist')
        return phone_action_uris(rows[0]['primary_phone'] or rows[0]['secondary_phone'])

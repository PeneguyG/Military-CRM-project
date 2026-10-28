PRAGMA foreign_keys = ON;

BEGIN IMMEDIATE;
CREATE TABLE IF NOT EXISTS organizations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL CHECK (length(trim(name)) > 0),
    industry TEXT,
    address_line1 TEXT, address_line2 TEXT, city TEXT, state TEXT,
    postal_code TEXT, country TEXT, phone TEXT, email TEXT, website TEXT,
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS contacts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    organization_id INTEGER REFERENCES organizations(id) ON DELETE SET NULL,
    rank_or_title TEXT,
    first_name TEXT NOT NULL CHECK (length(trim(first_name)) > 0),
    last_name TEXT NOT NULL CHECK (length(trim(last_name)) > 0),
    address_line1 TEXT, address_line2 TEXT, city TEXT, state TEXT,
    postal_code TEXT, country TEXT, primary_phone TEXT, secondary_phone TEXT,
    email TEXT, spouse_name TEXT, children_details TEXT,
    photo_blob BLOB, photo_path TEXT, general_notes TEXT, talking_points TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (photo_blob IS NULL OR photo_path IS NULL)
);
CREATE TABLE IF NOT EXISTS interactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
    interaction_type TEXT NOT NULL CHECK (interaction_type IN
        ('Call', 'Text', 'Email', 'In-Person Meeting', 'Briefing', 'Other')),
    direction TEXT NOT NULL CHECK (direction IN ('Inbound', 'Outbound')),
    occurred_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    summary TEXT NOT NULL CHECK (length(trim(summary)) > 0),
    notes TEXT,
    follow_up_required INTEGER NOT NULL DEFAULT 0 CHECK (follow_up_required IN (0, 1)),
    follow_up_date DATE,
    follow_up_completed INTEGER NOT NULL DEFAULT 0 CHECK (follow_up_completed IN (0, 1)),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (follow_up_date IS NULL OR
        (date(follow_up_date, '+0 days') IS NOT NULL AND
         follow_up_date = date(follow_up_date, '+0 days'))),
    CHECK (follow_up_date IS NULL OR follow_up_required = 1),
    CHECK (follow_up_completed = 0 OR follow_up_required = 1)
);
CREATE INDEX IF NOT EXISTS idx_contacts_last_name ON contacts(last_name COLLATE NOCASE);
CREATE INDEX IF NOT EXISTS idx_contacts_organization ON contacts(organization_id);
CREATE INDEX IF NOT EXISTS idx_interactions_contact_occurred ON interactions(contact_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_interactions_occurred ON interactions(occurred_at);
CREATE INDEX IF NOT EXISTS idx_interactions_follow_up ON interactions(follow_up_date)
    WHERE follow_up_required = 1 AND follow_up_completed = 0;
CREATE INDEX IF NOT EXISTS idx_organizations_industry ON organizations(industry COLLATE NOCASE);

CREATE VIRTUAL TABLE IF NOT EXISTS contacts_fts USING fts5(
    first_name, last_name, organization_name, organization_notes,
    general_notes, talking_points, tokenize = 'unicode61 remove_diacritics 2'
);
CREATE TRIGGER IF NOT EXISTS contacts_fts_insert AFTER INSERT ON contacts BEGIN
    INSERT INTO contacts_fts(rowid, first_name, last_name, organization_name,
        organization_notes, general_notes, talking_points)
    SELECT new.id, new.first_name, new.last_name, o.name, o.notes,
        new.general_notes, new.talking_points
    FROM (SELECT 1) LEFT JOIN organizations o ON o.id = new.organization_id;
END;
CREATE TRIGGER IF NOT EXISTS contacts_fts_delete AFTER DELETE ON contacts BEGIN
    DELETE FROM contacts_fts WHERE rowid = old.id;
END;
CREATE TRIGGER IF NOT EXISTS contacts_fts_update AFTER UPDATE ON contacts BEGIN
    DELETE FROM contacts_fts WHERE rowid = old.id;
    INSERT INTO contacts_fts(rowid, first_name, last_name, organization_name,
        organization_notes, general_notes, talking_points)
    SELECT new.id, new.first_name, new.last_name, o.name, o.notes,
        new.general_notes, new.talking_points
    FROM (SELECT 1) LEFT JOIN organizations o ON o.id = new.organization_id;
END;
CREATE TRIGGER IF NOT EXISTS organizations_fts_update AFTER UPDATE OF name, notes ON organizations BEGIN
    UPDATE contacts_fts SET organization_name = new.name, organization_notes = new.notes
    WHERE rowid IN (SELECT id FROM contacts WHERE organization_id = new.id);
END;
CREATE TRIGGER IF NOT EXISTS contacts_updated_at AFTER UPDATE ON contacts
WHEN new.updated_at = old.updated_at AND new.updated_at <> CURRENT_TIMESTAMP BEGIN
    UPDATE contacts SET updated_at = CURRENT_TIMESTAMP WHERE id = new.id;
END;
CREATE TRIGGER IF NOT EXISTS organizations_updated_at AFTER UPDATE ON organizations
WHEN new.updated_at = old.updated_at AND new.updated_at <> CURRENT_TIMESTAMP BEGIN
    UPDATE organizations SET updated_at = CURRENT_TIMESTAMP WHERE id = new.id;
END;

-- Backfill also repairs the index when initializing an existing database.
DELETE FROM contacts_fts;
INSERT INTO contacts_fts(rowid, first_name, last_name, organization_name,
    organization_notes, general_notes, talking_points)
SELECT c.id, c.first_name, c.last_name, o.name, o.notes, c.general_notes, c.talking_points
FROM contacts c LEFT JOIN organizations o ON o.id = c.organization_id;
PRAGMA user_version = 1;
COMMIT;

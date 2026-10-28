-- Bind parameters; timestamps must use canonical UTC YYYY-MM-DD HH:MM:SS[.ffffff].
-- Latest interaction older than threshold, including never-contacted contacts.
SELECT c.*, MAX(i.occurred_at) AS last_interaction_at
FROM contacts c LEFT JOIN interactions i ON i.contact_id = c.id
GROUP BY c.id
HAVING MAX(i.occurred_at) IS NULL
    OR MAX(i.occurred_at) < datetime('now', '-' || :days_threshold || ' days');

-- Inclusive UTC calendar date range, using current organization membership.
SELECT COUNT(DISTINCT c.organization_id)
FROM interactions i JOIN contacts c ON c.id = i.contact_id
WHERE i.occurred_at >= :start_date AND i.occurred_at < date(:end_date, '+1 day');

-- Soundex requires SQLITE_SOUNDEX or the helper's registered fallback.
SELECT * FROM contacts WHERE soundex(last_name) = soundex(:search_term);

-- :partial_term contains a caller-escaped LIKE pattern; :fts_query contains
-- quoted FTS tokens. Industry/location filters apply to every match branch.
SELECT c.*, o.name AS organization_name
FROM contacts c LEFT JOIN organizations o ON o.id = c.organization_id
WHERE (c.last_name = :search_term COLLATE NOCASE
    OR c.first_name = :search_term COLLATE NOCASE
    OR c.last_name LIKE :partial_term ESCAPE '\'
    OR c.first_name LIKE :partial_term ESCAPE '\'
    OR o.name LIKE :partial_term ESCAPE '\'
    OR c.id IN (SELECT rowid FROM contacts_fts WHERE contacts_fts MATCH :fts_query)
    OR (:use_soundex = 1 AND soundex(c.last_name) = soundex(:search_term)))
AND (:industry IS NULL OR o.industry = :industry COLLATE NOCASE)
AND (:location IS NULL OR c.city = :location COLLATE NOCASE
     OR c.state = :location COLLATE NOCASE OR c.country = :location COLLATE NOCASE
     OR o.city = :location COLLATE NOCASE OR o.state = :location COLLATE NOCASE
     OR o.country = :location COLLATE NOCASE);

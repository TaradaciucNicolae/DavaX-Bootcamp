/* TARADACIUC NICOLAE

   Acest script ia datele brute din MEETINGS_RAW si le transforma intr-o
   forma mai curata si mai usor de folosit in rapoarte.

   Ideea principala este urmatoarea:
   nu folosim direct datele brute din fisier sau din import, pentru ca ele
   pot avea emailuri scrise diferit, nume neuniforme, meeting-uri anulate,
   randuri duplicate sau randuri care reprezinta sali de sedinta.

   De aceea, scriptul:
   - sterge tabela finala daca exista deja
   - creeaza tabela MEETINGS_SANITIZED
   - curata si standardizeaza datele din MEETINGS_RAW
   - pastreaza doar randurile considerate valide

*/

SET DEFINE OFF;
SET SERVEROUTPUT ON;

/* Aici stergem tabela finala daca ea exista deja.

   Daca tabela nu exista, blocul ignora eroarea ORA-00942.
*/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE meetings_sanitized PURGE';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN
            RAISE;
        END IF;
END;
/

/* Aceasta este tabela finala in care vor ajunge doar randurile acceptate.

   - employee_id = daca participantul a fost gasit in tabela EMPLOYEES
   - employee_match_status = spune daca participantul a fost gasit sau nu
   - participant_scope = arata daca emailul este intern Endava, intern non-canonical sau extern
   - attendee_name_clean = numele participantului curatat
   - attendee_email_clean = emailul curatat
   - meeting_start_date, meeting_end_date, meeting_date = datele meeting-ului
   - meeting_subject_clean = subiectul curatat
   - organizer_clean = organizatorul curatat
   - subject_category = o categorie derivata din subiect
   - source_rowid_char = identificatorul randului din sursa
   - loaded_at = momentul cand randul a fost salvat aici

   Constrangerile verifica:
   - valorile permise pentru employee_match_status
   - valorile permise pentru participant_scope
   - valorile permise pentru subject_category
*/
CREATE TABLE meetings_sanitized
(
    sanitized_id           NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    employee_id            NUMBER,
    employee_match_status  VARCHAR2(20) NOT NULL,
    participant_scope      VARCHAR2(30) NOT NULL,
    attendee_name_clean    VARCHAR2(150) NOT NULL,
    attendee_email_clean   VARCHAR2(150) NOT NULL,
    meeting_start_date     DATE NOT NULL,
    meeting_end_date       DATE NOT NULL,
    meeting_date           DATE NOT NULL,
    meeting_subject_clean  VARCHAR2(300) NOT NULL,
    organizer_clean        VARCHAR2(200),
    subject_category       VARCHAR2(30) NOT NULL,
    source_rowid_char      VARCHAR2(30),
    loaded_at              TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,

    CONSTRAINT pk_meetings_sanitized PRIMARY KEY (sanitized_id),
    CONSTRAINT ck_meetings_sanitized_match_status
        CHECK (employee_match_status IN ('MATCHED', 'UNMATCHED')),
    CONSTRAINT ck_meetings_sanitized_scope
        CHECK (participant_scope IN ('ENDAVA_INTERNAL', 'NON_CANONICAL_INTERNAL', 'EXTERNAL')),
    CONSTRAINT ck_meetings_sanitized_category
        CHECK (subject_category IN
        (
            'ACADEMY',
            'WEEKLY_SYNC',
            'Q_AND_A',
            'BUDDY_SYNC',
            'TIMECARDS',
            'WORKSHOP',
            'ALL_HANDS',
            'REMINDER',
            'COMMUNITY_EVENT',
            'OTHER'
        ))
);

/* Aceste indexuri ajuta la cautari mai rapide.

*/
CREATE INDEX ix_meetings_sanitized_email_date
    ON sanitized(attendee_email_clean, meeting_date);

CREATE INDEX ix_meetings_sanitized_subject
    ON sanitized(meeting_subject_clean);

/* luam datele din MEETINGS_RAW si inseram doar randurile acceptate in
   MEETINGS_SANITIZED.

   Folosim trei CTE-uri, adica trei rezultate intermediare cu nume.

   1. normalized
      Aici curatam datele brute:
      - scoatem spatiile inutile
      - transformam numele intr-un format mai uniform
      - transformam emailul in lowercase
      - standardizam subiectul si organizatorul
      - extragem datele de inceput si sfarsit

   2. enriched
      Aici adaugam informatii in plus:
      - incercam sa gasim angajatul in EMPLOYEES dupa email
      - stabilim daca emailul este intern sau extern
      - marcam daca randul pare sa reprezinte o sala de sedinta
      - marcam daca meeting-ul este anulat
      - calculam un numar de ordine pentru duplicate

   3. classified
      Aici hotaram daca randul este ACCEPT sau REJECT.
      Tot aici atribuim o categorie subiectului meeting-ului.
*/
INSERT INTO meetings_sanitized
(
    employee_id,
    employee_match_status,
    participant_scope,
    attendee_name_clean,
    attendee_email_clean,
    meeting_start_date,
    meeting_end_date,
    meeting_date,
    meeting_subject_clean,
    organizer_clean,
    subject_category,
    source_rowid_char
)
WITH normalized AS
(
    SELECT
        ROWIDTOCHAR(m.ROWID) AS source_rowid_char,

        m.nume_invitati AS attendee_name_raw,
        m.email         AS attendee_email_raw,
        m.meeting_start AS meeting_start_raw,
        m.meeting_end   AS meeting_end_raw,
        m.subject       AS meeting_subject_raw,
        m.organizer     AS organizer_raw,

        CASE
            WHEN m.nume_invitati IS NULL THEN NULL
            ELSE INITCAP(LOWER(REGEXP_REPLACE(TRIM(m.nume_invitati), '\s+', ' ')))
        END AS attendee_name_clean,

        CASE
            WHEN m.email IS NULL THEN NULL
            ELSE LOWER(TRIM(m.email))
        END AS attendee_email_clean,

        TRUNC(m.meeting_start) AS meeting_start_date,
        TRUNC(m.meeting_end)   AS meeting_end_date,
        TRUNC(NVL(m.meeting_start, m.meeting_end)) AS meeting_date,

        CASE
            WHEN m.subject IS NULL THEN NULL
            ELSE REGEXP_REPLACE(TRIM(m.subject), '\s+', ' ')
        END AS meeting_subject_clean,

        CASE
            WHEN m.organizer IS NULL THEN NULL
            ELSE REGEXP_REPLACE(TRIM(m.organizer), '\s+', ' ')
        END AS organizer_clean
    FROM meetings_raw m
),
enriched AS
(
    SELECT
        n.*,
        e.employee_id,
        e.first_name,
        e.last_name,

        CASE
            WHEN n.attendee_email_clean LIKE '%@endava.com' THEN 'ENDAVA_INTERNAL'
            WHEN n.attendee_email_clean LIKE '%@endava.onmicrosoft.com' THEN 'NON_CANONICAL_INTERNAL'
            ELSE 'EXTERNAL'
        END AS participant_scope,

        CASE
            WHEN UPPER(NVL(n.attendee_name_raw, '')) LIKE '%MEETING ROOM%' THEN 1
            ELSE 0
        END AS is_room_resource,

        CASE
            WHEN REGEXP_LIKE(UPPER(NVL(n.meeting_subject_clean, '')), '^(CANCELED|CANCELLED)\s*:') THEN 1
            ELSE 0
        END AS is_canceled,

        ROW_NUMBER() OVER
        (
            PARTITION BY
                LOWER(TRIM(NVL(n.attendee_email_clean, 'NULL_EMAIL'))),
                TRUNC(NVL(n.meeting_start_date, DATE '1900-01-01')),
                TRUNC(NVL(n.meeting_end_date, DATE '1900-01-01')),
                LOWER(TRIM(NVL(n.meeting_subject_clean, 'NULL_SUBJECT'))),
                LOWER(TRIM(NVL(n.organizer_clean, 'NULL_ORGANIZER')))
            ORDER BY n.source_rowid_char
        ) AS dup_rn
    FROM normalized n
    LEFT JOIN employees e
        ON LOWER(TRIM(e.email)) = n.attendee_email_clean
),
classified AS
(
    SELECT
        e.*,
        CASE
            WHEN e.attendee_email_clean IS NULL
                 OR NOT REGEXP_LIKE(e.attendee_email_clean, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
                THEN 'REJECT'

            WHEN e.meeting_start_date IS NULL
                THEN 'REJECT'

            WHEN e.meeting_end_date IS NULL
                THEN 'REJECT'

            WHEN e.meeting_end_date < e.meeting_start_date
                THEN 'REJECT'

            WHEN e.meeting_subject_clean IS NULL
                THEN 'REJECT'

            WHEN e.is_room_resource = 1
                THEN 'REJECT'

            WHEN e.is_canceled = 1
                THEN 'REJECT'

            WHEN e.dup_rn > 1
                THEN 'REJECT'

            ELSE 'ACCEPT'
        END AS row_status,

        CASE
            WHEN REGEXP_LIKE(UPPER(NVL(e.meeting_subject_clean, '')), 'BUDDY\s+SYNC') THEN 'BUDDY_SYNC'
            WHEN REGEXP_LIKE(UPPER(NVL(e.meeting_subject_clean, '')), 'WEEKLY\s+SYNC') THEN 'WEEKLY_SYNC'
            WHEN REGEXP_LIKE(UPPER(NVL(e.meeting_subject_clean, '')), 'Q&A|Q & A') THEN 'Q_AND_A'
            WHEN REGEXP_LIKE(UPPER(NVL(e.meeting_subject_clean, '')), 'TIMECARD|TIMESHEET') THEN 'TIMECARDS'
            WHEN REGEXP_LIKE(UPPER(NVL(e.meeting_subject_clean, '')), 'WORKSHOP|WALKTHROUGH') THEN 'WORKSHOP'
            WHEN REGEXP_LIKE(UPPER(NVL(e.meeting_subject_clean, '')), 'ALL HANDS') THEN 'ALL_HANDS'
            WHEN REGEXP_LIKE(UPPER(NVL(e.meeting_subject_clean, '')), 'REMINDER') THEN 'REMINDER'
            WHEN REGEXP_LIKE(UPPER(NVL(e.meeting_subject_clean, '')),
                             'DAVA\.X|ACADEMY|ASK ME ANYTHING|PASS IT ON|BREAKFAST WITH A LEADER|ESPOTLIGHT|GIANT|EFFECTIVE COMMUNICATION')
                THEN 'ACADEMY'
            WHEN REGEXP_LIKE(UPPER(NVL(e.meeting_subject_clean, '')),
                             'WOMEN IN CLIENT TALKS|TEST CAF|JOIN PASS IT ON|BREAKFAST WITH A LEADER')
                THEN 'COMMUNITY_EVENT'
            ELSE 'OTHER'
        END AS subject_category
    FROM enriched e
)
SELECT
    c.employee_id,
    CASE
        WHEN c.employee_id IS NOT NULL THEN 'MATCHED'
        ELSE 'UNMATCHED'
    END AS employee_match_status,
    c.participant_scope,
    CASE
        WHEN c.employee_id IS NOT NULL THEN c.first_name || ' ' || c.last_name
        ELSE c.attendee_name_clean
    END AS attendee_name_clean,
    c.attendee_email_clean,
    c.meeting_start_date,
    c.meeting_end_date,
    c.meeting_date,
    c.meeting_subject_clean,
    c.organizer_clean,
    c.subject_category,
    c.source_rowid_char
FROM classified c
WHERE c.row_status = 'ACCEPT';

COMMIT;

/* doar de verificare
*/
SELECT COUNT(*) AS sanitized_count FROM meetings_sanitized;

SELECT
    attendee_name_clean,
    attendee_email_clean,
    meeting_date,
    meeting_subject_clean,
    organizer_clean,
    subject_category,
    employee_match_status
FROM meetings_sanitized
ORDER BY
    meeting_date,
    attendee_name_clean,
    meeting_subject_clean;

SET DEFINE ON;

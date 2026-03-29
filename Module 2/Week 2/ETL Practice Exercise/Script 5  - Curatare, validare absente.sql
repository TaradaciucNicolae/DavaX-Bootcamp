/* TARADACIUC NICOLAE

   TEMA: Sistem de pontare (Timesheets) - Oracle Database

   TITLU PROPUS:
   Curatarea, validarea si pregatirea absentelor pentru raportare

   Ce face acest script:
   Acest script ia datele brute din ABSENCES_RAW si le transforma in doua rezultate:
   - randurile bune ajung in ABSENCES_SANITIZED
   - randurile problematice ajung in ABSENCES_REJECTED

   In plus, scriptul creeaza si un view de control care compara absenta cu
   orele existente in pontaj in aceeasi zi.

   Ideea principala:
   nu lucram direct cu datele brute din Excel.
   Mai intai le curatam, le verificam si abia dupa aceea le folosim mai departe.
*/

SET SERVEROUTPUT ON;

/* La inceput stergem tabelele, daca ele exista deja.


   Daca tabela nu exista, blocul doar ignora eroarea ORA-00942.
*/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE absences_sanitized PURGE';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN
            RAISE;
        END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE absences_rejected PURGE';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN
            RAISE;
        END IF;
END;
/

/* Aici ajung randurile valide.

   Coloanele importante sunt:
   - employee_id = legatura cu angajatul din tabela EMPLOYEES
   - employee_name_clean = numele curatat
   - employee_email_clean = emailul curatat
   - absence_code_clean = codul standardizat al absentei
   - absence_date = data absentei
   - week_start_date = inceputul saptamanii din care face parte data
   - absence_hours = cate ore inseamna absenta
   - worked_hours_default = valoare implicita 8 pentru afisarea finala
   - work_mode_default = office sau remote, folosit la afisare
   - source_rowid_char = identificatorul randului sursa din ABSENCES_RAW

   Constrangerile verifica:
   - ce coduri de absenta sunt permise
   - ca orele sunt pozitive
   - ca worked_hours_default ramane 8
   - ca work_mode_default este doar office sau remote
*/
CREATE TABLE absences_sanitized
(
    absence_id             NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    employee_id            NUMBER,
    employee_name_clean    VARCHAR2(100) NOT NULL,
    employee_email_clean   VARCHAR2(150) NOT NULL,
    absence_code_clean     VARCHAR2(20) NOT NULL,
    absence_date           DATE NOT NULL,
    week_start_date        DATE NOT NULL,
    absence_hours          NUMBER(4,1) NOT NULL,
    worked_hours_default   NUMBER(4,1) DEFAULT 8 NOT NULL,
    work_mode_default      VARCHAR2(20) NOT NULL,
    reason_text_clean      VARCHAR2(200),
    source_rowid_char      VARCHAR2(30),
    loaded_at              TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,

    CONSTRAINT pk_absences_sanitized PRIMARY KEY (absence_id),
    CONSTRAINT ck_absences_sanitized_code
        CHECK (absence_code_clean IN ('ANNUAL', 'MEDICAL', 'FACULTY', 'PERSONAL')),
    CONSTRAINT ck_absences_sanitized_hours
        CHECK (absence_hours > 0),
    CONSTRAINT ck_absences_sanitized_worked_hours
        CHECK (worked_hours_default = 8),
    CONSTRAINT ck_absences_sanitized_work_mode
        CHECK (work_mode_default IN ('office', 'remote'))
);

/* Acest index ajuta la cautari dupa email si data absentei. */
CREATE INDEX ix_absences_sanitized_email_date
    ON absences_sanitized(employee_email_clean, absence_date);

/* Aceasta tabela pastreaza randurile care nu trec validarea.

   Aici salvam atat datele brute, cat si datele deja curatate, plus motivul
   pentru care randul a fost respins.

   Este utila pentru debugging
*/
CREATE TABLE absences_rejected
(
    reject_id              NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    employee_name_raw      VARCHAR2(200),
    employee_email_raw     VARCHAR2(200),
    absence_code_raw       VARCHAR2(50),
    absence_date_raw       DATE,
    absence_hours_raw      NUMBER(10,2),
    reason_text_raw        VARCHAR2(200),

    employee_name_clean    VARCHAR2(100),
    employee_email_clean   VARCHAR2(150),
    absence_code_clean     VARCHAR2(20),
    absence_date_clean     DATE,
    week_start_date        DATE,
    absence_hours_clean    NUMBER(10,2),
    reason_text_clean      VARCHAR2(200),

    validation_status      VARCHAR2(50) NOT NULL,
    validation_message     VARCHAR2(400),
    source_rowid_char      VARCHAR2(30),
    loaded_at              TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,

    CONSTRAINT pk_absences_rejected PRIMARY KEY (reject_id)
);

/* Aici inserez randurile valide in ABSENCES_SANITIZED.

   Fac trei CTE-uri:

   normalized
   - curata textul
   - transforma numele intr-un format frumos
   - transforma emailul in lowercase si fara spatii inutile
   - transforma codurile de absenta in valori standard
   - calculeaza si week_start_date

   enriched
   - incearca sa lege randul de tabela EMPLOYEES
   - adauga employee_id, first_name si last_name
   - calculeaza si un contor de duplicate

   classified
   - aplica regulile de validare
   - decide daca randul este VALID sau trebuie respins
*/
INSERT INTO absences_sanitized
(
    employee_id,
    employee_name_clean,
    employee_email_clean,
    absence_code_clean,
    absence_date,
    week_start_date,
    absence_hours,
    worked_hours_default,
    work_mode_default,
    reason_text_clean,
    source_rowid_char
)
WITH normalized AS
(
    SELECT
        ROWIDTOCHAR(r.ROWID) AS source_rowid_char,
        r.employee_name_raw,
        r.employee_email_raw,
        r.absence_code_raw,
        r.absence_date_raw,
        r.absence_hours_raw,
        r.reason_text_raw,

        INITCAP(LOWER(REGEXP_REPLACE(TRIM(r.employee_name_raw), '\s+', ' '))) AS employee_name_clean,
        LOWER(TRIM(r.employee_email_raw)) AS employee_email_clean,

        CASE
            WHEN UPPER(TRIM(r.absence_code_raw)) IN ('ANNUAL', 'ANNUAL LEAVE', 'VACATION') THEN 'ANNUAL'
            WHEN UPPER(TRIM(r.absence_code_raw)) IN ('MEDICAL', 'SICK', 'SICK LEAVE') THEN 'MEDICAL'
            WHEN UPPER(TRIM(r.absence_code_raw)) IN ('FACULTY', 'UNIVERSITY', 'STUDY') THEN 'FACULTY'
            WHEN UPPER(TRIM(r.absence_code_raw)) IN ('PERSONAL', 'PERSONAL LEAVE') THEN 'PERSONAL'
            ELSE NULL
        END AS absence_code_clean,

        TRUNC(r.absence_date_raw) AS absence_date_clean,
        TRUNC(r.absence_date_raw, 'IW') AS week_start_date,
        r.absence_hours_raw AS absence_hours_clean,
        REGEXP_REPLACE(TRIM(r.reason_text_raw), '\s+', ' ') AS reason_text_clean
    FROM absences_raw r
),
enriched AS
(
    SELECT
        n.*,
        e.employee_id,
        e.first_name,
        e.last_name,
        COUNT(*) OVER
        (
            PARTITION BY
                n.employee_email_clean,
                n.absence_date_clean,
                NVL(n.absence_code_clean, 'UNKNOWN'),
                NVL(n.absence_hours_clean, -1)
        ) AS dup_cnt
    FROM normalized n
    LEFT JOIN employees e
        ON LOWER(TRIM(e.email)) = n.employee_email_clean
),
classified AS
(
    SELECT
        e.*,
        CASE
            WHEN e.employee_email_clean IS NULL
                 OR NOT REGEXP_LIKE(e.employee_email_clean, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
                THEN 'EMAIL_INVALID'

            WHEN e.absence_code_clean IS NULL
                THEN 'ABSENCE_CODE_INVALID'

            WHEN e.absence_date_clean IS NULL
                THEN 'ABSENCE_DATE_MISSING'

            WHEN TO_CHAR(e.absence_date_clean, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH') IN ('SAT', 'SUN')
                THEN 'WEEKEND_NOT_ALLOWED'

            WHEN e.week_start_date NOT IN (TRUNC(SYSDATE, 'IW'), TRUNC(SYSDATE, 'IW') + 7)
                THEN 'DATE_OUTSIDE_ALLOWED_WEEKS'

            WHEN e.absence_hours_clean IS NULL OR e.absence_hours_clean <= 0
                THEN 'ABSENCE_HOURS_INVALID'

            WHEN e.absence_code_clean = 'ANNUAL' AND e.absence_hours_clean <> 8
                THEN 'ANNUAL_MUST_BE_8H'

            WHEN e.absence_code_clean IN ('MEDICAL', 'FACULTY', 'PERSONAL')
                 AND e.absence_hours_clean NOT IN (2, 4)
                THEN 'PARTIAL_ABSENCE_MUST_BE_2H_OR_4H'

            WHEN e.employee_id IS NULL
                THEN 'EMPLOYEE_NOT_FOUND'

            WHEN e.dup_cnt > 1
                THEN 'DUPLICATE_RAW_RECORD'

            ELSE 'VALID'
        END AS validation_status
    FROM enriched e
)
SELECT
    c.employee_id,
    CASE
        WHEN c.employee_id IS NOT NULL THEN c.first_name || ' ' || c.last_name
        ELSE c.employee_name_clean
    END AS employee_name_clean,
    c.employee_email_clean,
    c.absence_code_clean,
    c.absence_date_clean,
    c.week_start_date,
    c.absence_hours_clean,
    8 AS worked_hours_default,
    CASE
        WHEN MOD(ORA_HASH(c.employee_email_clean || TO_CHAR(c.absence_date_clean, 'YYYYMMDD')), 2) = 0 THEN 'office'
        ELSE 'remote'
    END AS work_mode_default,
    c.reason_text_clean,
    c.source_rowid_char
FROM classified c
WHERE c.validation_status = 'VALID';

/* Aici inseram randurile respinse in ABSENCES_REJECTED.

   Observa ca folosim aceeasi structura normalized -> enriched -> classified.
   Diferenta este ca la final pastram doar randurile care NU sunt VALID.

*/
INSERT INTO absences_rejected
(
    employee_name_raw,
    employee_email_raw,
    absence_code_raw,
    absence_date_raw,
    absence_hours_raw,
    reason_text_raw,
    employee_name_clean,
    employee_email_clean,
    absence_code_clean,
    absence_date_clean,
    week_start_date,
    absence_hours_clean,
    reason_text_clean,
    validation_status,
    validation_message,
    source_rowid_char
)
WITH normalized AS
(
    SELECT
        ROWIDTOCHAR(r.ROWID) AS source_rowid_char,
        r.employee_name_raw,
        r.employee_email_raw,
        r.absence_code_raw,
        r.absence_date_raw,
        r.absence_hours_raw,
        r.reason_text_raw,

        INITCAP(LOWER(REGEXP_REPLACE(TRIM(r.employee_name_raw), '\s+', ' '))) AS employee_name_clean,
        LOWER(TRIM(r.employee_email_raw)) AS employee_email_clean,

        CASE
            WHEN UPPER(TRIM(r.absence_code_raw)) IN ('ANNUAL', 'ANNUAL LEAVE', 'VACATION') THEN 'ANNUAL'
            WHEN UPPER(TRIM(r.absence_code_raw)) IN ('MEDICAL', 'SICK', 'SICK LEAVE') THEN 'MEDICAL'
            WHEN UPPER(TRIM(r.absence_code_raw)) IN ('FACULTY', 'UNIVERSITY', 'STUDY') THEN 'FACULTY'
            WHEN UPPER(TRIM(r.absence_code_raw)) IN ('PERSONAL', 'PERSONAL LEAVE') THEN 'PERSONAL'
            ELSE NULL
        END AS absence_code_clean,

        TRUNC(r.absence_date_raw) AS absence_date_clean,
        TRUNC(r.absence_date_raw, 'IW') AS week_start_date,
        r.absence_hours_raw AS absence_hours_clean,
        REGEXP_REPLACE(TRIM(r.reason_text_raw), '\s+', ' ') AS reason_text_clean
    FROM absences_raw r
),
enriched AS
(
    SELECT
        n.*,
        e.employee_id,
        COUNT(*) OVER
        (
            PARTITION BY
                n.employee_email_clean,
                n.absence_date_clean,
                NVL(n.absence_code_clean, 'UNKNOWN'),
                NVL(n.absence_hours_clean, -1)
        ) AS dup_cnt
    FROM normalized n
    LEFT JOIN employees e
        ON LOWER(TRIM(e.email)) = n.employee_email_clean
),
classified AS
(
    SELECT
        e.*,
        CASE
            WHEN e.employee_email_clean IS NULL
                 OR NOT REGEXP_LIKE(e.employee_email_clean, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
                THEN 'EMAIL_INVALID'

            WHEN e.absence_code_clean IS NULL
                THEN 'ABSENCE_CODE_INVALID'

            WHEN e.absence_date_clean IS NULL
                THEN 'ABSENCE_DATE_MISSING'

            WHEN TO_CHAR(e.absence_date_clean, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH') IN ('SAT', 'SUN')
                THEN 'WEEKEND_NOT_ALLOWED'

            WHEN e.week_start_date NOT IN (TRUNC(SYSDATE, 'IW'), TRUNC(SYSDATE, 'IW') + 7)
                THEN 'DATE_OUTSIDE_ALLOWED_WEEKS'

            WHEN e.absence_hours_clean IS NULL OR e.absence_hours_clean <= 0
                THEN 'ABSENCE_HOURS_INVALID'

            WHEN e.absence_code_clean = 'ANNUAL' AND e.absence_hours_clean <> 8
                THEN 'ANNUAL_MUST_BE_8H'

            WHEN e.absence_code_clean IN ('MEDICAL', 'FACULTY', 'PERSONAL')
                 AND e.absence_hours_clean NOT IN (2, 4)
                THEN 'PARTIAL_ABSENCE_MUST_BE_2H_OR_4H'

            WHEN e.employee_id IS NULL
                THEN 'EMPLOYEE_NOT_FOUND'

            WHEN e.dup_cnt > 1
                THEN 'DUPLICATE_RAW_RECORD'

            ELSE 'VALID'
        END AS validation_status
    FROM enriched e
)
SELECT
    c.employee_name_raw,
    c.employee_email_raw,
    c.absence_code_raw,
    c.absence_date_raw,
    c.absence_hours_raw,
    c.reason_text_raw,
    c.employee_name_clean,
    c.employee_email_clean,
    c.absence_code_clean,
    c.absence_date_clean,
    c.week_start_date,
    c.absence_hours_clean,
    c.reason_text_clean,
    c.validation_status,
    CASE c.validation_status
        WHEN 'EMAIL_INVALID' THEN 'Email invalid dupa trim/lower'
        WHEN 'ABSENCE_CODE_INVALID' THEN 'Cod de absenta neacceptat'
        WHEN 'ABSENCE_DATE_MISSING' THEN 'Data lipsa'
        WHEN 'WEEKEND_NOT_ALLOWED' THEN 'Absenta pe weekend'
        WHEN 'DATE_OUTSIDE_ALLOWED_WEEKS' THEN 'Data nu este in saptamana curenta sau urmatoare'
        WHEN 'ABSENCE_HOURS_INVALID' THEN 'Ore lipsa sau <= 0'
        WHEN 'ANNUAL_MUST_BE_8H' THEN 'ANNUAL trebuie sa fie exact 8h'
        WHEN 'PARTIAL_ABSENCE_MUST_BE_2H_OR_4H' THEN 'MEDICAL/FACULTY/PERSONAL trebuie sa fie 2h sau 4h'
        WHEN 'EMPLOYEE_NOT_FOUND' THEN 'Emailul nu exista in EMPLOYEES'
        WHEN 'DUPLICATE_RAW_RECORD' THEN 'Duplicat dupa sanitizare'
        ELSE 'Necunoscut'
    END AS validation_message,
    c.source_rowid_char
FROM classified c
WHERE c.validation_status <> 'VALID';

COMMIT;

/* Acest view este un control rapid peste datele curate.

   El compara absenta din ABSENCES_SANITIZED cu pontajul din sistem.

*/
CREATE OR REPLACE VIEW vw_absences_sanitized_control AS
SELECT
    a.employee_id,
    a.employee_name_clean,
    a.employee_email_clean,
    a.absence_code_clean,
    a.absence_date,
    a.week_start_date,
    a.absence_hours,
    a.worked_hours_default,
    a.work_mode_default,
    a.reason_text_clean,
    t.timesheet_id,
    t.status AS timesheet_status,
    CASE
        WHEN NVL(SUM(te.hours_worked), 0) = 0 THEN a.worked_hours_default
        ELSE NVL(SUM(te.hours_worked), 0)
    END AS worked_hours_that_day,
    NVL(SUM(te.hours_worked), 0) + a.absence_hours AS worked_plus_absence
FROM absences_sanitized a
LEFT JOIN timesheets t
    ON t.employee_id = a.employee_id
   AND t.week_start_date = a.week_start_date
LEFT JOIN timesheet_entries te
    ON te.timesheet_id = t.timesheet_id
   AND te.entry_date = a.absence_date
GROUP BY
    a.employee_id,
    a.employee_name_clean,
    a.employee_email_clean,
    a.absence_code_clean,
    a.absence_date,
    a.week_start_date,
    a.absence_hours,
    a.worked_hours_default,
    a.work_mode_default,
    a.reason_text_clean,
    t.timesheet_id,
    t.status;

/* astea sunt doar de verificare
*/
SELECT COUNT(*) AS raw_count FROM absences_raw;
SELECT COUNT(*) AS sanitized_count FROM absences_sanitized;
SELECT COUNT(*) AS rejected_count FROM absences_rejected;

SELECT
    employee_name_clean,
    employee_email_clean,
    absence_code_clean,
    absence_date,
    absence_hours,
    reason_text_clean
FROM absences_sanitized
ORDER BY employee_name_clean, absence_date;

SELECT
    employee_name_raw,
    employee_email_raw,
    absence_code_raw,
    absence_date_raw,
    absence_hours_raw,
    validation_status,
    validation_message
FROM absences_rejected
ORDER BY employee_name_raw, absence_date_raw;

SELECT
    employee_name_clean,
    absence_date,
    absence_hours,
    worked_hours_default,
    work_mode_default,
    worked_hours_that_day,
    worked_plus_absence,
    CASE
        WHEN worked_plus_absence > 8 THEN 'OVER_8H'
        WHEN worked_plus_absence = 8 THEN 'OK_8H'
        ELSE 'UNDER_8H'
    END AS day_control
FROM vw_absences_sanitized_control
ORDER BY employee_name_clean, absence_date;

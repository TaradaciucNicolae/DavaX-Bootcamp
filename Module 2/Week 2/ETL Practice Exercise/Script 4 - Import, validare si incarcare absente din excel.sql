/* TARADACIUC NICOLAE

   Script 4
   
   Acest script pregateste tot mecanismul prin care vom aduce absentele
   dintr-un fisier Excel in baza de date

*/

SET SERVEROUTPUT ON;

/* Pregatim scriptul pt rerulare

*/
BEGIN
    DECLARE
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
          INTO v_cnt
          FROM USER_VIEWS
         WHERE VIEW_NAME = 'VW_ABSENCE_TIMESHEET_CONTROL';

        IF v_cnt > 0 THEN
            EXECUTE IMMEDIATE 'DROP VIEW vw_absence_timesheet_control';
            DBMS_OUTPUT.PUT_LINE('Dropped VIEW vw_absence_timesheet_control');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Skip VIEW vw_absence_timesheet_control - nu exista');
        END IF;
    END;

    DECLARE
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
          INTO v_cnt
          FROM USER_VIEWS
         WHERE VIEW_NAME = 'VW_EMPLOYEE_ABSENCES';

        IF v_cnt > 0 THEN
            EXECUTE IMMEDIATE 'DROP VIEW vw_employee_absences';
            DBMS_OUTPUT.PUT_LINE('Dropped VIEW vw_employee_absences');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Skip VIEW vw_employee_absences - nu exista');
        END IF;
    END;

    DECLARE
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
          INTO v_cnt
          FROM USER_OBJECTS
         WHERE OBJECT_TYPE = 'PROCEDURE'
           AND OBJECT_NAME = 'PRC_LOAD_ABSENCES_FROM_STAGE';

        IF v_cnt > 0 THEN
            EXECUTE IMMEDIATE 'DROP PROCEDURE prc_load_absences_from_stage';
            DBMS_OUTPUT.PUT_LINE('Dropped PROCEDURE prc_load_absences_from_stage');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Skip PROCEDURE prc_load_absences_from_stage - nu exista');
        END IF;
    END;

    DECLARE
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
          INTO v_cnt
          FROM USER_TABLES
         WHERE TABLE_NAME = 'EMPLOYEE_ABSENCES';

        IF v_cnt > 0 THEN
            EXECUTE IMMEDIATE 'DROP TABLE employee_absences CASCADE CONSTRAINTS PURGE';
            DBMS_OUTPUT.PUT_LINE('Dropped TABLE employee_absences');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Skip TABLE employee_absences - nu exista');
        END IF;
    END;

    DECLARE
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
          INTO v_cnt
          FROM USER_TABLES
         WHERE TABLE_NAME = 'STG_ABSENCES_RAW';

        IF v_cnt > 0 THEN
            EXECUTE IMMEDIATE 'DROP TABLE stg_absences_raw CASCADE CONSTRAINTS PURGE';
            DBMS_OUTPUT.PUT_LINE('Dropped TABLE stg_absences_raw');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Skip TABLE stg_absences_raw - nu exista');
        END IF;
    END;

    DECLARE
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
          INTO v_cnt
          FROM USER_TABLES
         WHERE TABLE_NAME = 'ABSENCE_IMPORT_BATCHES';

        IF v_cnt > 0 THEN
            EXECUTE IMMEDIATE 'DROP TABLE absence_import_batches CASCADE CONSTRAINTS PURGE';
            DBMS_OUTPUT.PUT_LINE('Dropped TABLE absence_import_batches');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Skip TABLE absence_import_batches - nu exista');
        END IF;
    END;

    DECLARE
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
          INTO v_cnt
          FROM USER_TABLES
         WHERE TABLE_NAME = 'ABSENCE_CODES';

        IF v_cnt > 0 THEN
            EXECUTE IMMEDIATE 'DROP TABLE absence_codes CASCADE CONSTRAINTS PURGE';
            DBMS_OUTPUT.PUT_LINE('Dropped TABLE absence_codes');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Skip TABLE absence_codes - nu exista');
        END IF;
    END;
END;
/

/* Acesta este un tabel de tip lookup.
   
   Este un tabel mic, static, care defineste valorile acceptate pentru tipurile de absenta.

   Aici spui clar ce coduri sunt permise si ce reguli au:
   - ANNUAL poate fi zi intreaga
   - MEDICAL, FACULTY si PERSONAL pot fi doar partiale
*/
CREATE TABLE absence_codes
(
    absence_code        VARCHAR2(20) NOT NULL,
    absence_name        VARCHAR2(100) NOT NULL,
    allows_partial_day  NUMBER(1) DEFAULT 1 NOT NULL,
    allows_full_day     NUMBER(1) DEFAULT 0 NOT NULL,
    is_active           NUMBER(1) DEFAULT 1 NOT NULL,

    CONSTRAINT pk_absence_codes PRIMARY KEY (absence_code),
    CONSTRAINT ck_absence_codes_partial CHECK (allows_partial_day IN (0, 1)),
    CONSTRAINT ck_absence_codes_full CHECK (allows_full_day IN (0, 1)),
    CONSTRAINT ck_absence_codes_active CHECK (is_active IN (0, 1))
);

INSERT INTO absence_codes (absence_code, absence_name, allows_partial_day, allows_full_day, is_active)
VALUES ('ANNUAL', 'Annual Leave', 0, 1, 1);

INSERT INTO absence_codes (absence_code, absence_name, allows_partial_day, allows_full_day, is_active)
VALUES ('MEDICAL', 'Medical Leave', 1, 0, 1);

INSERT INTO absence_codes (absence_code, absence_name, allows_partial_day, allows_full_day, is_active)
VALUES ('FACULTY', 'Faculty / University', 1, 0, 1);

INSERT INTO absence_codes (absence_code, absence_name, allows_partial_day, allows_full_day, is_active)
VALUES ('PERSONAL', 'Personal Leave', 1, 0, 1);

/* Acest tabel memoreaza fiecare import ca batch separat.

   
   Rolul lui este ca atunci cand incarci un fisier, vrei sa stii:
   - ce fisier a fost
   - cand a fost incarcat
   - din ce sistem vine
   - cate randuri te asteptai sa aiba

*/
CREATE TABLE absence_import_batches
(
    batch_id             NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    source_file_batch    VARCHAR2(100) NOT NULL,
    source_file_name     VARCHAR2(255) NOT NULL,
    source_system        VARCHAR2(100) NOT NULL,
    loaded_at            TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    row_count_expected   NUMBER,
    notes                VARCHAR2(400),

    CONSTRAINT pk_absence_import_batches PRIMARY KEY (batch_id),
    CONSTRAINT uq_absence_import_batches UNIQUE (source_file_batch)
);

/* Acesta este tabelul de staging pentru datele brute din Excel.

   Am vrut sa il numesc staging pentru ca este o zona intermediara 
   in care incarc datele exact cum vin, inainte sa le curat si sa le validez.

   Aici pastram:
   - numele si emailul angajatului asa cum vin din fisier
   - codul de absenta
   - data
   - numarul de ore
   - motivul
   - batch-ul din care face parte randul

   Avem si doua coloane virtuale utile:
   - employee_email_norm = email curatat si pus cu litere mici
   - absence_code_norm   = codul de absenta curatat si pus cu litere mari

*/
CREATE TABLE stg_absences_raw
(
    stg_absence_id        NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    batch_id              NUMBER NOT NULL,
    source_row_num        NUMBER NOT NULL,
    absence_source_code   VARCHAR2(50) NOT NULL,
    employee_name_raw     VARCHAR2(100) NOT NULL,
    employee_email_raw    VARCHAR2(150) NOT NULL,
    employee_email_norm   VARCHAR2(150)
        GENERATED ALWAYS AS (LOWER(TRIM(employee_email_raw))) VIRTUAL,
    absence_code_raw      VARCHAR2(20) NOT NULL,
    absence_code_norm     VARCHAR2(20)
        GENERATED ALWAYS AS (UPPER(TRIM(absence_code_raw))) VIRTUAL,
    absence_date_raw      DATE NOT NULL,
    absence_hours_raw     NUMBER(4,2) NOT NULL,
    reason_text_raw       VARCHAR2(200),
    source_system         VARCHAR2(100) NOT NULL,
    source_file_batch     VARCHAR2(100) NOT NULL,
    load_status           VARCHAR2(20) DEFAULT 'NEW' NOT NULL,
    validation_message    VARCHAR2(400),

    CONSTRAINT pk_stg_absences_raw PRIMARY KEY (stg_absence_id),

    CONSTRAINT fk_stg_absences_batch
        FOREIGN KEY (batch_id)
        REFERENCES absence_import_batches(batch_id),

    CONSTRAINT uq_stg_absences_row
        UNIQUE (batch_id, source_row_num),

    CONSTRAINT uq_stg_absences_source_code
        UNIQUE (batch_id, absence_source_code),

    CONSTRAINT ck_stg_absences_hours
        CHECK (absence_hours_raw IN (2, 4, 8)),

    CONSTRAINT ck_stg_absences_status
        CHECK (load_status IN ('NEW', 'VALID', 'REJECTED', 'LOADED'))
);

/* Acesta este tabelul final

   Doar datele valide ajung aici.

   Relatiile importante sunt:
   - employee_id se leaga de EMPLOYEES
   - absence_code se leaga de ABSENCE_CODES
   - timesheet_id se poate lega de TIMESHEETS
   - source_batch_id se leaga de batch-ul de import

   Avem si reguli de business:
   - ANNUAL poate avea doar 8 ore
   - MEDICAL, FACULTY si PERSONAL pot avea doar 2 sau 4 ore
*/
CREATE TABLE employee_absences
(
    absence_day_id         NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    employee_id            NUMBER NOT NULL,
    absence_code           VARCHAR2(20) NOT NULL,
    absence_date           DATE NOT NULL,
    absence_hours          NUMBER(4,2) NOT NULL,
    reason_text            VARCHAR2(200),
    timesheet_id           NUMBER,
    source_batch_id        NUMBER NOT NULL,
    source_absence_code    VARCHAR2(50) NOT NULL,
    source_system          VARCHAR2(100) NOT NULL,
    source_file_batch      VARCHAR2(100) NOT NULL,
    absence_metadata_json  CLOB,
    created_at             TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,

    CONSTRAINT pk_employee_absences PRIMARY KEY (absence_day_id),

    CONSTRAINT fk_employee_absences_employee
        FOREIGN KEY (employee_id)
        REFERENCES employees(employee_id),

    CONSTRAINT fk_employee_absences_code
        FOREIGN KEY (absence_code)
        REFERENCES absence_codes(absence_code),

    CONSTRAINT fk_employee_absences_timesheet
        FOREIGN KEY (timesheet_id)
        REFERENCES timesheets(timesheet_id),

    CONSTRAINT fk_employee_absences_batch
        FOREIGN KEY (source_batch_id)
        REFERENCES absence_import_batches(batch_id),

    CONSTRAINT uq_employee_absences_business
        UNIQUE (employee_id, absence_date, absence_code),

    CONSTRAINT uq_employee_absences_source
        UNIQUE (source_batch_id, source_absence_code),

    CONSTRAINT ck_employee_absences_hours
        CHECK (absence_hours IN (2, 4, 8)),

    CONSTRAINT ck_employee_absences_rule
        CHECK (
              (absence_hours = 8 AND absence_code = 'ANNUAL')
           OR (absence_hours IN (2, 4) AND absence_code IN ('MEDICAL', 'FACULTY', 'PERSONAL'))
              ),

    CONSTRAINT ck_employee_absences_json
        CHECK (absence_metadata_json IS NULL OR absence_metadata_json IS JSON)
);

/* Aici cream cateva indexuri.

   Rolul lor este sa ajute interogarile frecvente sa ruleze mai repede
   precum cele de genul:
   - cautari dupa email si data in staging
   - cautari dupa employee + date in target
   - cautari dupa cod de absenta + data
*/
CREATE INDEX ix_stg_absences_email_date
    ON stg_absences_raw (employee_email_norm, absence_date_raw);

CREATE INDEX ix_employee_absences_emp_date
    ON employee_absences (employee_id, absence_date);

CREATE INDEX ix_employee_absences_code_date
    ON employee_absences (absence_code, absence_date);

/* Procedura muta datele din staging in tabela finala.

   Ce face procedura, pe scurt:
   - marcheaza randurile din batch ca VALID
   - verifica daca emailul exista in EMPLOYEES
   - verifica daca tipul de absenta este acceptat
   - verifica daca orele sunt corecte
   - aplica regulile de business
   = muta datele valide in EMPLOYEE_ABSENCES folosind MERGE
   - marcheaza randurile mutate ca LOADED


   Ea face doua lucruri: (aici am folosit merge )
   - daca randul exista deja, il actualizeaza
   - daca randul nu exista, il insereaza

   Asa evitam duplicatele.
*/
CREATE OR REPLACE PROCEDURE prc_load_absences_from_stage
(
    p_source_file_batch IN VARCHAR2
)
AS
BEGIN
    UPDATE stg_absences_raw s
       SET s.load_status = 'VALID',
           s.validation_message = NULL
     WHERE s.source_file_batch = p_source_file_batch;

    UPDATE stg_absences_raw s
       SET s.load_status = 'REJECTED',
           s.validation_message = 'Employee email not found in EMPLOYEES'
     WHERE s.source_file_batch = p_source_file_batch
       AND NOT EXISTS
           (
               SELECT 1
               FROM employees e
               WHERE LOWER(TRIM(e.email)) = s.employee_email_norm
           );

    UPDATE stg_absences_raw s
       SET s.load_status = 'REJECTED',
           s.validation_message = NVL(s.validation_message || '; ', '') || 'Invalid absence code'
     WHERE s.source_file_batch = p_source_file_batch
       AND s.load_status <> 'REJECTED'
       AND NOT EXISTS
           (
               SELECT 1
               FROM absence_codes ac
               WHERE ac.absence_code = s.absence_code_norm
                 AND ac.is_active = 1
           );

    UPDATE stg_absences_raw s
       SET s.load_status = 'REJECTED',
           s.validation_message = NVL(s.validation_message || '; ', '') || 'Invalid absence hours'
     WHERE s.source_file_batch = p_source_file_batch
       AND s.load_status <> 'REJECTED'
       AND s.absence_hours_raw NOT IN (2, 4, 8);

    UPDATE stg_absences_raw s
       SET s.load_status = 'REJECTED',
           s.validation_message = NVL(s.validation_message || '; ', '') || '8h allowed only for ANNUAL'
     WHERE s.source_file_batch = p_source_file_batch
       AND s.load_status <> 'REJECTED'
       AND s.absence_hours_raw = 8
       AND s.absence_code_norm <> 'ANNUAL';

    UPDATE stg_absences_raw s
       SET s.load_status = 'REJECTED',
           s.validation_message = NVL(s.validation_message || '; ', '') || '2h/4h allowed only for MEDICAL/FACULTY/PERSONAL'
     WHERE s.source_file_batch = p_source_file_batch
       AND s.load_status <> 'REJECTED'
       AND s.absence_hours_raw IN (2, 4)
       AND s.absence_code_norm NOT IN ('MEDICAL', 'FACULTY', 'PERSONAL');

    MERGE INTO employee_absences tgt
    USING
    (
        SELECT
            e.employee_id,
            s.absence_code_norm AS absence_code,
            s.absence_date_raw AS absence_date,
            s.absence_hours_raw AS absence_hours,
            s.reason_text_raw AS reason_text,
            t.timesheet_id,
            b.batch_id AS source_batch_id,
            s.absence_source_code AS source_absence_code,
            s.source_system,
            s.source_file_batch,
            JSON_OBJECT(
                'sourceRowNum' VALUE s.source_row_num,
                'employeeNameRaw' VALUE s.employee_name_raw,
                'employeeEmailRaw' VALUE s.employee_email_raw,
                'absenceCodeRaw' VALUE s.absence_code_raw,
                'absenceDateRaw' VALUE TO_CHAR(s.absence_date_raw, 'YYYY-MM-DD'),
                'absenceHoursRaw' VALUE s.absence_hours_raw,
                'reasonTextRaw' VALUE s.reason_text_raw
                RETURNING CLOB
            ) AS absence_metadata_json
        FROM stg_absences_raw s
        JOIN absence_import_batches b
            ON b.batch_id = s.batch_id
        JOIN employees e
            ON LOWER(TRIM(e.email)) = s.employee_email_norm
        LEFT JOIN timesheets t
            ON t.employee_id = e.employee_id
           AND t.week_start_date = TRUNC(s.absence_date_raw, 'IW')
        WHERE s.source_file_batch = p_source_file_batch
          AND s.load_status = 'VALID'
    ) src
       ON (
              tgt.employee_id = src.employee_id
          AND tgt.absence_date = src.absence_date
          AND tgt.absence_code = src.absence_code
          )
    WHEN MATCHED THEN
        UPDATE SET
            tgt.absence_hours         = src.absence_hours,
            tgt.reason_text           = src.reason_text,
            tgt.timesheet_id          = src.timesheet_id,
            tgt.source_batch_id       = src.source_batch_id,
            tgt.source_absence_code   = src.source_absence_code,
            tgt.source_system         = src.source_system,
            tgt.source_file_batch     = src.source_file_batch,
            tgt.absence_metadata_json = src.absence_metadata_json
    WHEN NOT MATCHED THEN
        INSERT
        (
            employee_id,
            absence_code,
            absence_date,
            absence_hours,
            reason_text,
            timesheet_id,
            source_batch_id,
            source_absence_code,
            source_system,
            source_file_batch,
            absence_metadata_json
        )
        VALUES
        (
            src.employee_id,
            src.absence_code,
            src.absence_date,
            src.absence_hours,
            src.reason_text,
            src.timesheet_id,
            src.source_batch_id,
            src.source_absence_code,
            src.source_system,
            src.source_file_batch,
            src.absence_metadata_json
        );

    UPDATE stg_absences_raw s
       SET s.load_status = 'LOADED',
           s.validation_message = 'Loaded into EMPLOYEE_ABSENCES'
     WHERE s.source_file_batch = p_source_file_batch
       AND s.load_status = 'VALID';

    COMMIT;
END;
/

/* Acest view este pentru raportare simpla.

   Leaga tabela finala de absente cu:
   - employees
   - departments
   - absence_codes

   Astfel obtii o vedere mai usor de citit:
   vezi angajatul, departamentul, data absentei, tipul, orele si sursa.
*/
CREATE OR REPLACE VIEW vw_employee_absences AS
SELECT
    a.absence_day_id,
    e.employee_id,
    e.first_name,
    e.last_name,
    e.email,
    d.department_name,
    a.absence_date,
    TRUNC(a.absence_date, 'IW') AS absence_week_start,
    a.absence_code,
    ac.absence_name,
    a.absence_hours,
    a.reason_text,
    a.timesheet_id,
    a.source_system,
    a.source_file_batch,
    a.created_at
FROM employee_absences a
JOIN employees e
    ON e.employee_id = a.employee_id
JOIN departments d
    ON d.department_id = e.department_id
JOIN absence_codes ac
    ON ac.absence_code = a.absence_code;

/* Acest view este pentru control.

   Ce poti afla de aici:
   - daca angajatul are timesheet pentru ziua respectiva
   - cate ore are pontate
   - cate ore are ca absenta
   - daca totalul este ok, sub 8 sau peste 8
*/
CREATE OR REPLACE VIEW vw_absence_timesheet_control AS
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    a.absence_date,
    a.absence_code,
    a.absence_hours,
    a.timesheet_id,
    NVL(SUM(te.hours_worked), 0) AS worked_hours,
    a.absence_hours + NVL(SUM(te.hours_worked), 0) AS total_recorded_hours,
    CASE
        WHEN a.timesheet_id IS NULL THEN 'NO_TIMESHEET'
        WHEN a.absence_hours + NVL(SUM(te.hours_worked), 0) > 8 THEN 'OVERBOOKED'
        WHEN a.absence_hours + NVL(SUM(te.hours_worked), 0) = 8 THEN 'OK'
        ELSE 'UNDERBOOKED'
    END AS control_status
FROM employee_absences a
JOIN employees e
    ON e.employee_id = a.employee_id
LEFT JOIN timesheet_entries te
    ON te.timesheet_id = a.timesheet_id
   AND te.entry_date = a.absence_date
GROUP BY
    e.employee_id,
    e.first_name,
    e.last_name,
    a.absence_date,
    a.absence_code,
    a.absence_hours,
    a.timesheet_id;

/* Aici dam drepturi

   - aplicatia poate lucra cu tabelele de absente
   - partea de raportare poate citi view-urile construite mai sus
*/
GRANT SELECT, INSERT, UPDATE, DELETE ON absence_import_batches TO role_timesheet_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON stg_absences_raw TO role_timesheet_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON employee_absences TO role_timesheet_app;
GRANT SELECT ON absence_codes TO role_timesheet_app;
GRANT EXECUTE ON prc_load_absences_from_stage TO role_timesheet_app;

GRANT SELECT ON vw_employee_absences TO role_timesheet_report;
GRANT SELECT ON vw_absence_timesheet_control TO role_timesheet_report;

/* asta e doar de verificare
*/
SELECT table_name
FROM user_tables
WHERE table_name IN
(
    'ABSENCE_CODES',
    'ABSENCE_IMPORT_BATCHES',
    'STG_ABSENCES_RAW',
    'EMPLOYEE_ABSENCES'
)
ORDER BY table_name;

/* TARADACIUC NICOLAE

   DESCRIERE PE SCURT:
   Acest script construieste baza structurala a aplicatiei:
   - creeaza tabelele principale
   - creeaza relatiile dintre ele
   - creeaza view-uri pentru raportare
   - creeaza un tabel de audit
   - creeaza trigger pentru audit
   - acorda granturi pentru rolurile aplicatiei
*/

SET SERVEROUTPUT ON;

/* PASUL 0 - CLEANUP PENTRU RERULAREA SCRIPTULUI

   CE FACE:
   Inainte sa cream din nou tabelele, view-urile si materialized view-ul,
   verificam daca ele exista deja in schema curenta.
   Daca exista, le stergem.
   Daca nu exista, doar afisam un mesaj de tip "skip".


*/
BEGIN
    DECLARE
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
          INTO v_cnt
          FROM USER_MVIEWS
         WHERE MVIEW_NAME = 'MV_EMPLOYEE_TOTAL_HOURS';

        IF v_cnt > 0 THEN
            EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW mv_employee_total_hours';
            DBMS_OUTPUT.PUT_LINE('Dropped MATERIALIZED VIEW mv_employee_total_hours');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Skip MATERIALIZED VIEW mv_employee_total_hours - nu exista');
        END IF;
    END;

    DECLARE
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
          INTO v_cnt
          FROM USER_VIEWS
         WHERE VIEW_NAME = 'VW_EMPLOYEE_REPORTING_SECURE';

        IF v_cnt > 0 THEN
            EXECUTE IMMEDIATE 'DROP VIEW vw_employee_reporting_secure';
            DBMS_OUTPUT.PUT_LINE('Dropped VIEW vw_employee_reporting_secure');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Skip VIEW vw_employee_reporting_secure - nu exista');
        END IF;
    END;

    DECLARE
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
          INTO v_cnt
          FROM USER_VIEWS
         WHERE VIEW_NAME = 'VW_EMPLOYEE_PROJECT_HOURS';

        IF v_cnt > 0 THEN
            EXECUTE IMMEDIATE 'DROP VIEW vw_employee_project_hours';
            DBMS_OUTPUT.PUT_LINE('Dropped VIEW vw_employee_project_hours');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Skip VIEW vw_employee_project_hours - nu exista');
        END IF;
    END;

    DECLARE
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
          INTO v_cnt
          FROM USER_TABLES
         WHERE TABLE_NAME = 'AUDIT_TIMESHEET_ENTRIES';

        IF v_cnt > 0 THEN
            EXECUTE IMMEDIATE 'DROP TABLE audit_timesheet_entries CASCADE CONSTRAINTS PURGE';
            DBMS_OUTPUT.PUT_LINE('Dropped TABLE audit_timesheet_entries');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Skip TABLE audit_timesheet_entries - nu exista');
        END IF;
    END;

    DECLARE
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
          INTO v_cnt
          FROM USER_TABLES
         WHERE TABLE_NAME = 'TIMESHEET_ENTRIES';

        IF v_cnt > 0 THEN
            EXECUTE IMMEDIATE 'DROP TABLE timesheet_entries CASCADE CONSTRAINTS PURGE';
            DBMS_OUTPUT.PUT_LINE('Dropped TABLE timesheet_entries');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Skip TABLE timesheet_entries - nu exista');
        END IF;
    END;

    DECLARE
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
          INTO v_cnt
          FROM USER_TABLES
         WHERE TABLE_NAME = 'TIMESHEETS';

        IF v_cnt > 0 THEN
            EXECUTE IMMEDIATE 'DROP TABLE timesheets CASCADE CONSTRAINTS PURGE';
            DBMS_OUTPUT.PUT_LINE('Dropped TABLE timesheets');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Skip TABLE timesheets - nu exista');
        END IF;
    END;

    DECLARE
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
          INTO v_cnt
          FROM USER_TABLES
         WHERE TABLE_NAME = 'EMPLOYEES';

        IF v_cnt > 0 THEN
            EXECUTE IMMEDIATE 'DROP TABLE employees CASCADE CONSTRAINTS PURGE';
            DBMS_OUTPUT.PUT_LINE('Dropped TABLE employees');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Skip TABLE employees - nu exista');
        END IF;
    END;

    DECLARE
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
          INTO v_cnt
          FROM USER_TABLES
         WHERE TABLE_NAME = 'PROJECTS';

        IF v_cnt > 0 THEN
            EXECUTE IMMEDIATE 'DROP TABLE projects CASCADE CONSTRAINTS PURGE';
            DBMS_OUTPUT.PUT_LINE('Dropped TABLE projects');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Skip TABLE projects - nu exista');
        END IF;
    END;

    DECLARE
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
          INTO v_cnt
          FROM USER_TABLES
         WHERE TABLE_NAME = 'DEPARTMENTS';

        IF v_cnt > 0 THEN
            EXECUTE IMMEDIATE 'DROP TABLE departments CASCADE CONSTRAINTS PURGE';
            DBMS_OUTPUT.PUT_LINE('Dropped TABLE departments');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Skip TABLE departments - nu exista');
        END IF;
    END;
END;
/

/*
	PASUL 1 - CREAREA TABELEI DEPARTMENTS

   CE REPREZINTA:
   Tabelul cu departamentele companiei.

   - department_id   = cheia primara, generata automat
   - department_code = cod scurt, de exemplu DEV / HR / PMO
   - department_name = denumirea completa a departamentului

   CONSTRANGERI:
   - pk_departments      = cheie primara
   - uq_departments_code = codul trebuie sa fie unic
   - uq_departments_name = numele departamentului trebuie sa fie unic
*/
CREATE TABLE departments
(
    department_id   NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    department_code VARCHAR2(10) NOT NULL,
    department_name VARCHAR2(100) NOT NULL,

    CONSTRAINT pk_departments PRIMARY KEY (department_id),
    CONSTRAINT uq_departments_code UNIQUE (department_code),
    CONSTRAINT uq_departments_name UNIQUE (department_name)
);

/* PASUL 2 - CREAREA TABELEI EMPLOYEES

   CE REPREZINTA:
   Tabelul cu angajatii.

   RELATIE:
   Fiecare angajat apartine unui departament.
   De aceea avem department_id ca foreign key catre departments.

   COLOANE IMPORTANTE:
   - employee_id       = cheia primara
   - department_id     = legatura cu departments
   - first_name        = prenume
   - last_name         = nume
   - email             = email unic
   - hire_date         = data angajarii
   - employment_status = ACTIVE / INACTIVE / ON_LEAVE
   - profile_json      = informatii suplimentare in JSON

   CONSTRANGERI IMPORTANTE:
   - email-ul trebuie sa fie unic
   - email-ul trebuie sa aiba format valid
   - statusul trebuie sa fie una dintre valorile acceptate
   - profile_json, daca exista, trebuie sa fie JSON valid
 */
CREATE TABLE employees
(
    employee_id         NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    department_id       NUMBER NOT NULL,
    first_name          VARCHAR2(50) NOT NULL,
    last_name           VARCHAR2(50) NOT NULL,
    email               VARCHAR2(150) NOT NULL,
    hire_date           DATE NOT NULL,
    employment_status   VARCHAR2(20) DEFAULT 'ACTIVE' NOT NULL,
    profile_json        CLOB,

    CONSTRAINT pk_employees PRIMARY KEY (employee_id),

    CONSTRAINT fk_employees_departments
        FOREIGN KEY (department_id)
        REFERENCES departments(department_id),

    CONSTRAINT uq_employees_email UNIQUE (email),

    CONSTRAINT ck_employees_email_format
        CHECK (REGEXP_LIKE(email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')),

    CONSTRAINT ck_employees_status
        CHECK (employment_status IN ('ACTIVE', 'INACTIVE', 'ON_LEAVE')),

    CONSTRAINT ck_employees_profile_json
        CHECK (profile_json IS NULL OR profile_json IS JSON)
);

/* PASUL 3 - CREAREA TABELEI PROJECTS

   CE REPREZINTA:
   Tabelul cu proiectele pe care lucreaza angajatii.

   COLOANE:
   - project_id   = cheia primara
   - project_code = cod unic al proiectului
   - project_name = numele proiectului
   - client_name  = clientul asociat proiectului
   - start_date   = data de inceput
   - end_date     = data de final (optional)
   - is_active    = 1 daca proiectul este activ, 0 daca nu

   VALIDARI:
   - end_date nu poate fi mai mica decat start_date
   - is_active trebuie sa fie doar 0 sau 1
*/
CREATE TABLE projects
(
    project_id     NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    project_code   VARCHAR2(20) NOT NULL,
    project_name   VARCHAR2(100) NOT NULL,
    client_name    VARCHAR2(100),
    start_date     DATE NOT NULL,
    end_date       DATE,
    is_active      NUMBER(1) DEFAULT 1 NOT NULL,

    CONSTRAINT pk_projects PRIMARY KEY (project_id),

    CONSTRAINT uq_projects_code UNIQUE (project_code),

    CONSTRAINT ck_projects_date_range
        CHECK (end_date IS NULL OR end_date >= start_date),

    CONSTRAINT ck_projects_is_active
        CHECK (is_active IN (0, 1))
);

/* PASUL 4 - CREAREA TABELEI TIMESHEETS

   CE REPREZINTA:
   Tabelul "header" al pontajului saptamanal.

   IDEE:
   Un angajat are un timesheet pe saptamana.
   In acel timesheet se vor afla apoi liniile individuale din tabelul
   TIMESHEET_ENTRIES.

   COLOANE:
   - timesheet_id      = cheia primara
   - employee_id       = angajatul caruia ii apartine pontajul
   - week_start_date   = data de inceput a saptamanii
   - status            = DRAFT / SUBMITTED / APPROVED / REJECTED
   - submitted_at      = cand a fost trimis
   - approved_at       = cand a fost aprobat

   REGULA IMPORTANTA:
   Un angajat nu poate avea doua timesheet-uri pentru aceeasi saptamana.
   De aceea exista constrangerea UNIQUE(employee_id, week_start_date).
*/
CREATE TABLE timesheets
(
    timesheet_id       NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    employee_id        NUMBER NOT NULL,
    week_start_date    DATE NOT NULL,
    status             VARCHAR2(20) DEFAULT 'DRAFT' NOT NULL,
    submitted_at       TIMESTAMP,
    approved_at        TIMESTAMP,

    CONSTRAINT pk_timesheets PRIMARY KEY (timesheet_id),

    CONSTRAINT fk_timesheets_employees
        FOREIGN KEY (employee_id)
        REFERENCES employees(employee_id),

    CONSTRAINT uq_timesheets_employee_week
        UNIQUE (employee_id, week_start_date),

    CONSTRAINT ck_timesheets_status
        CHECK (status IN ('DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED')),

    CONSTRAINT ck_timesheets_approval_dates
        CHECK
        (
            approved_at IS NULL
            OR (submitted_at IS NOT NULL AND approved_at >= submitted_at)
        )
);

/* PASUL 5 - CREAREA TABELEI TIMESHEET_ENTRIES

   CE REPREZINTA:
   Liniile de pontaj.
   Aici se salveaza efectiv:
   - pe ce proiect s-a lucrat
   - in ce zi
   - cate ore
   - ce task a fost facut

   RELATII:
   - timesheet_id = legatura catre timesheets
   - project_id   = legatura catre projects

   COLOANE:
   - hours_worked        = numarul de ore lucrate
   - task_description    = descrierea task-ului
   - entry_metadata_json = metadata suplimentara in JSON
   - is_billable         = daca activitatea este facturabila sau nu

   VALIDARI:
   - hours_worked trebuie sa fie > 0 si <= 24
   - is_billable trebuie sa fie 0 sau 1
   - entry_metadata_json trebuie sa fie JSON valid, daca exista
 */
CREATE TABLE timesheet_entries
(
    entry_id               NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    timesheet_id           NUMBER NOT NULL,
    project_id             NUMBER NOT NULL,
    entry_date             DATE NOT NULL,
    hours_worked           NUMBER(5,2) NOT NULL,
    task_description       VARCHAR2(200) NOT NULL,
    entry_metadata_json    CLOB,
    is_billable            NUMBER(1) DEFAULT 1 NOT NULL,

    CONSTRAINT pk_timesheet_entries PRIMARY KEY (entry_id),

    CONSTRAINT fk_entries_timesheets
        FOREIGN KEY (timesheet_id)
        REFERENCES timesheets(timesheet_id),

    CONSTRAINT fk_entries_projects
        FOREIGN KEY (project_id)
        REFERENCES projects(project_id),

    CONSTRAINT ck_entries_hours
        CHECK (hours_worked > 0 AND hours_worked <= 24),

    CONSTRAINT ck_entries_billable
        CHECK (is_billable IN (0, 1)),

    CONSTRAINT ck_entries_metadata_json
        CHECK (entry_metadata_json IS NULL OR entry_metadata_json IS JSON)
);

/* PASUL 6 - CREAREA INDEXURILOR SUPLIMENTARE

   CE ESTE UN INDEX:
   Un index ajuta baza de date sa gaseasca mai repede anumite informatii.

   DE CE LE CREAM:
   Pentru ca anumite cautari apar frecvent:
   - cautare dupa numele angajatului
   - cautare dupa numele proiectului
   - cautare dupa data
   - cautare dupa angajat + saptamana + status
*/
CREATE INDEX ix_employees_last_name
    ON employees(last_name);

CREATE INDEX ix_projects_project_name
    ON projects(project_name);

CREATE INDEX ix_timesheet_entries_entry_date
    ON timesheet_entries(entry_date);

CREATE INDEX ix_timesheets_employee_week_status
    ON timesheets(employee_id, week_start_date, status);

/* PASUL 7 - CREAREA VIEW-ULUI NORMAL

   CE ESTE UN VIEW:
   Un view este o interogare salvata care se comporta ca un "tabel virtual".

   CE FACE ACEST VIEW:
   Leaga:
   - employees
   - timesheets
   - timesheet_entries
   - projects

   Rezultatul este o vedere simpla, utila pentru raportare:
   pentru fiecare angajat vezi proiectul, data, orele si task-ul.
*/
CREATE OR REPLACE VIEW vw_employee_project_hours AS
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    p.project_code,
    p.project_name,
    te.entry_date,
    te.hours_worked,
    te.task_description,
    t.status AS timesheet_status,
    te.is_billable
FROM employees e
JOIN timesheets t
    ON e.employee_id = t.employee_id
JOIN timesheet_entries te
    ON t.timesheet_id = te.timesheet_id
JOIN projects p
    ON te.project_id = p.project_id;

/* PASUL 8 - CREAREA MATERIALIZED VIEW-ULUI

   CE ESTE UN MATERIALIZED VIEW:
   Spre deosebire de un view normal, aici rezultatul se stocheaza fizic.
   Este util pentru rapoarte mai rapide.

   CE FACE:
   Calculeaza totaluri pe angajat:
   - cate entry-uri are
   - cate ore totale are
   - cate ore billable / non-billable
   - prima si ultima zi pontata

   REFRESH COMPLETE ON DEMAND:
   inseamna ca nu se actualizeaza singur la fiecare schimbare.
   Se actualizeaza doar cand ii ceri explicit refresh.
*/
CREATE MATERIALIZED VIEW mv_employee_total_hours
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    COUNT(*) AS entry_count,
    SUM(te.hours_worked) AS total_hours,
    SUM(CASE WHEN te.is_billable = 1 THEN te.hours_worked ELSE 0 END) AS billable_hours,
    SUM(CASE WHEN te.is_billable = 0 THEN te.hours_worked ELSE 0 END) AS non_billable_hours,
    MIN(te.entry_date) AS first_entry_date,
    MAX(te.entry_date) AS last_entry_date
FROM employees e
JOIN timesheets t
    ON e.employee_id = t.employee_id
JOIN timesheet_entries te
    ON t.timesheet_id = te.timesheet_id
GROUP BY
    e.employee_id,
    e.first_name,
    e.last_name;

/* Index util pentru ordonari / filtre pe total_hours */
CREATE INDEX ix_mv_employee_total_hours_total
    ON mv_employee_total_hours(total_hours);

/* PASUL 9 - VIEW SECURIZAT PENTRU RAPORTARE

   CE FACE:
   Acest view este gandit pentru raportare "safe".
   Emailul este mascat astfel incat sa nu expuna adresa completa.

   EXEMPLU:
   ceva de genul:
   n***@endava.com

   UTILITATE:
   Poti da acces la raportare fara sa expui toate datele sensibile.
*/
CREATE OR REPLACE VIEW vw_employee_reporting_secure AS
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    REGEXP_REPLACE(e.email, '(^.).*(@.*$)', '\1***\2') AS masked_email,
    d.department_name,
    t.timesheet_id,
    t.week_start_date,
    t.status,
    p.project_code,
    p.project_name,
    te.entry_date,
    te.hours_worked,
    te.is_billable
FROM employees e
JOIN departments d
    ON e.department_id = d.department_id
LEFT JOIN timesheets t
    ON e.employee_id = t.employee_id
LEFT JOIN timesheet_entries te
    ON t.timesheet_id = te.timesheet_id
LEFT JOIN projects p
    ON te.project_id = p.project_id;

/* PASUL 10 - TABEL DE AUDIT

   CE ESTE AUDITUL:
   Audit inseamna sa pastram un istoric al modificarilor.

   CE SALVAM AICI:
   - tipul operatiei: INSERT / UPDATE / DELETE
   - entry-ul afectat
   - valorile vechi si/sau noi
   - cine a facut schimbarea
   - cand a fost facuta schimbarea

   SCOP:
   Sa putem urmari modificarile facute in timesheet_entries.
*/
CREATE TABLE audit_timesheet_entries
(
    audit_id             NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    operation_type       VARCHAR2(10) NOT NULL,
    entry_id             NUMBER,
    old_hours_worked     NUMBER(5,2),
    new_hours_worked     NUMBER(5,2),
    old_is_billable      NUMBER(1),
    new_is_billable      NUMBER(1),
    changed_by           VARCHAR2(100) NOT NULL,
    changed_at           TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,

    CONSTRAINT pk_audit_timesheet_entries PRIMARY KEY (audit_id),
    CONSTRAINT ck_audit_operation_type CHECK (operation_type IN ('INSERT', 'UPDATE', 'DELETE'))
);

/* PASUL 11 - TRIGGER DE AUDIT

   CE ESTE UN TRIGGER:
   Un trigger este cod care se executa automat cand se intampla ceva.
   In cazul nostru, triggerul se executa dupa:
   - INSERT
   - UPDATE
   - DELETE
   pe tabela timesheet_entries.

   CE FACE:
   Insereaza automat cate o linie in audit_timesheet_entries.

   OBSERVATIE:
   Daca rulezi in schema SYS, triggerul este sarit,
   pentru ca acolo nu se poate crea in acest context.
 */
BEGIN
    IF USER = 'SYS' THEN
        DBMS_OUTPUT.PUT_LINE('Skip trigger trg_audit_timesheet_entries - nu se poate crea in schema SYS');
    ELSE
        EXECUTE IMMEDIATE q'[
CREATE OR REPLACE TRIGGER trg_audit_timesheet_entries
AFTER INSERT OR UPDATE OR DELETE ON timesheet_entries
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO audit_timesheet_entries
        (
            operation_type,
            entry_id,
            new_hours_worked,
            new_is_billable,
            changed_by
        )
        VALUES
        (
            'INSERT',
            :NEW.entry_id,
            :NEW.hours_worked,
            :NEW.is_billable,
            USER
        );

    ELSIF UPDATING THEN
        INSERT INTO audit_timesheet_entries
        (
            operation_type,
            entry_id,
            old_hours_worked,
            new_hours_worked,
            old_is_billable,
            new_is_billable,
            changed_by
        )
        VALUES
        (
            'UPDATE',
            :OLD.entry_id,
            :OLD.hours_worked,
            :NEW.hours_worked,
            :OLD.is_billable,
            :NEW.is_billable,
            USER
        );

    ELSIF DELETING THEN
        INSERT INTO audit_timesheet_entries
        (
            operation_type,
            entry_id,
            old_hours_worked,
            old_is_billable,
            changed_by
        )
        VALUES
        (
            'DELETE',
            :OLD.entry_id,
            :OLD.hours_worked,
            :OLD.is_billable,
            USER
        );
    END IF;
END;
]';
        DBMS_OUTPUT.PUT_LINE('Created trigger trg_audit_timesheet_entries');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Skip trigger trg_audit_timesheet_entries: ' || SQLERRM);
END;
/

/* PASUL 12 - PRIVILEGII

   CE FAC GRANTURILE:
   Dau drepturi anumitor roluri din aplicatie.

   role_timesheet_app:
   - poate citi / insera / actualiza timesheets si timesheet_entries
   - poate citi projects si employees

   role_timesheet_report:
   - poate citi view-ul securizat
   - poate citi materialized view-ul cu totaluri

   OBSERVATIE:
   Daca rolurile nu exista, blocul intra pe EXCEPTION si afiseaza mesaj.
*/
BEGIN
    EXECUTE IMMEDIATE 'GRANT SELECT, INSERT, UPDATE ON timesheets TO role_timesheet_app';
    EXECUTE IMMEDIATE 'GRANT SELECT, INSERT, UPDATE ON timesheet_entries TO role_timesheet_app';
    EXECUTE IMMEDIATE 'GRANT SELECT ON projects TO role_timesheet_app';
    EXECUTE IMMEDIATE 'GRANT SELECT ON employees TO role_timesheet_app';

    EXECUTE IMMEDIATE 'GRANT SELECT ON vw_employee_reporting_secure TO role_timesheet_report';
    EXECUTE IMMEDIATE 'GRANT SELECT ON mv_employee_total_hours TO role_timesheet_report';

    DBMS_OUTPUT.PUT_LINE('Granturile au fost aplicate.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Skip grants: ' || SQLERRM);
END;
/

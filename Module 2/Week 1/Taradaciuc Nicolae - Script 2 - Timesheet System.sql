/* TARADACIUC NICOLAE
    
   TEMA: Sistem de pontare (Timesheets) - Oracle Database

   Script 2
*/

/* PASUL 0 - CLEANUP PENTRU RERULAREA SCRIPTULUI

   Rol:
   - sterge obiectele daca exista deja
   - permite rerularea scriptului fara erori de tip "object already exists"

   Observatie:
   - tabelele sunt sterse in ordinea inversa a dependintelor
   - indexurile nu trebuie sterse separat, deoarece se sterg automat odata cu tabelele
*/
SET SERVEROUTPUT ON;

BEGIN
    --  Drop materialized view doar daca exista in schema curenta

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

    --  Drop view securizat doar daca exista

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

    --  Drop view de raportare doar daca exista

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

    -- Drop tabel audit doar daca exista

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

    --  Drop tabel entries doar daca exista
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


    -- Drop tabel timesheets doar daca exista

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

    -- Drop tabel employees doar daca exista

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

    -- Drop tabel projects doar daca exista
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

    
    -- Drop tabel departments doar daca exista
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

   Rol: Tabela departments stocheaza departamentele companiei.
        Fiecare angajat va apartine unui departament.

   Coloane:
   - department_id     : identificator unic al departamentului
   - department_code   : cod scurt al departamentului
   - department_name   : denumirea completa a departamentului

   Constrangeri:
   - PK pe department_id
   - UK pe department_code
   - UK pe department_name
   - NOT NULL pe toate coloanele importante
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

   Rol: Tabela employees stocheaza angajatii companiei.

   Relatie:
   - fiecare angajat apartine unui departament
   - legatura se face prin department_id

   Coloane:
   - employee_id         : identificator unic al angajatului
   - department_id       : departamentul din care face parte angajatul
   - first_name          : prenumele angajatului
   - last_name           : numele angajatului
   - email               : adresa de email, unica pentru fiecare angajat
   - hire_date           : data angajarii
   - employment_status   : statusul angajatului
   - profile_json        : date semistructurate in format JSON

   Constrangeri:
   - PK pe employee_id
   - FK spre departments(department_id)
   - UK pe email
   - CK pentru status
   - CK pentru validarea JSON-ului
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

   Rol: Tabela projects stocheaza proiectele pe care se poate ponta.

   Coloane:
   - project_id     : identificator unic al proiectului
   - project_code   : cod unic al proiectului
   - project_name   : denumirea proiectului
   - client_name    : numele clientului
   - start_date     : data de inceput a proiectului
   - end_date       : data de finalizare a proiectului
   - is_active      : indicator daca proiectul este activ (1) sau nu (0)

   Constrangeri:
   - PK pe project_id
   - UK pe project_code
   - CK pentru intervalul de date
   - CK pentru is_active
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

   Rol: Tabela timesheets reprezinta antetul unui pontaj.
        Un angajat poate avea cate un pontaj pentru o anumita saptamana.

   Coloane:
   - timesheet_id      : identificator unic al pontajului
   - employee_id       : angajatul caruia ii apartine pontajul
   - week_start_date   : prima zi a saptamanii pontate
   - status            : starea pontajului
   - submitted_at      : momentul trimiterii pontajului
   - approved_at       : momentul aprobarii pontajului

   Constrangeri:
   - PK pe timesheet_id
   - FK spre employees(employee_id)
   - UK pe (employee_id, week_start_date)
   - CK pentru status
   - CK pentru logica datelor de aprobare
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
        CHECK (
            approved_at IS NULL
            OR (submitted_at IS NOT NULL AND approved_at >= submitted_at)
              )
);


/* PASUL 5 - CREAREA TABELEI TIMESHEET_ENTRIES

   Rol: Tabela timesheet_entries stocheaza liniile de pontaj.
        Aici se inregistreaza ce activitate s-a facut, pe ce proiect si cate ore s-au lucrat.

   Coloane:
   - entry_id              : identificator unic al liniei de pontaj
   - timesheet_id          : legatura catre antetul pontajului
   - project_id            : proiectul pe care s-a lucrat
   - entry_date            : data la care s-a lucrat
   - hours_worked          : numarul de ore lucrate
   - task_description      : descrierea activitatii
   - entry_metadata_json   : informatii suplimentare in format JSON
   - is_billable           : indica daca activitatea este facturabila

   Constrangeri:
   - PK pe entry_id
   - FK spre timesheets(timesheet_id)
   - FK spre projects(project_id)
   - CK pentru intervalul valid al orelor
   - CK pentru campul billable
   - CK pentru validarea JSON-ului
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

   Rol: Tema cere sa existe si alte campuri indexate in afara de PK/FK.
        Aceste indexuri pot imbunatati cautarile si sortarile pe coloane folosite frecvent in interogari.

   Indexuri create:
   - ix_employees_last_name         : cautari dupa numele angajatului
   - ix_projects_project_name       : cautari dupa numele proiectului
   - ix_timesheet_entries_entry_date: cautari dupa data pontajului
   - ix_timesheets_employee_week_status: index pentru cautarile uzuale pe pontaje
*/
CREATE INDEX ix_employees_last_name
    ON employees(last_name);

CREATE INDEX ix_projects_project_name
    ON projects(project_name);

CREATE INDEX ix_timesheet_entries_entry_date
    ON timesheet_entries(entry_date);

CREATE INDEX ix_timesheets_employee_week_status
    ON timesheets(employee_id, week_start_date, status);
    


/*PASUL 7 - INSERAREA DATELOR IN DEPARTMENTS

   Rol: Inseram cateva departamente pentru a putea lega angajatii de ele.
*/
INSERT INTO departments (department_code, department_name)
VALUES ('HR', 'Human Resources');

INSERT INTO departments (department_code, department_name)
VALUES ('DEV', 'Development');

INSERT INTO departments (department_code, department_name)
VALUES ('PMO', 'Project Management');


/* PASUL 8 - INSERAREA DATELOR IN EMPLOYEES

   Rol: Inseram angajati de test.
   
   Observatie:
   - profile_json contine date semistructurate in format JSON
   - fiecare angajat este asociat unui departament
*/
INSERT INTO employees
(
    department_id,
    first_name,
    last_name,
    email,
    hire_date,
    employment_status,
    profile_json
)
-- Selecteaza department_id-ul departamentului in care va fi inserat angajatul curent.
SELECT
    d.department_id,
    'Ana',
    'Popescu',
    'ana.popescu@company.local',
    DATE '2023-02-15',
    'ACTIVE',
    '{"phone":"0711000001","skills":["SQL","Excel"]}'
FROM departments d
WHERE d.department_code = 'DEV';

INSERT INTO employees
(
    department_id,
    first_name,
    last_name,
    email,
    hire_date,
    employment_status,
    profile_json
)
-- Selecteaza department_id-ul departamentului in care va fi inserat angajatul curent.
SELECT
    d.department_id,
    'Mihai',
    'Ionescu',
    'mihai.ionescu@company.local',
    DATE '2022-09-01',
    'ACTIVE',
    '{"phone":"0711000002","skills":["Oracle","Power BI"]}'
FROM departments d
WHERE d.department_code = 'DEV';

INSERT INTO employees
(
    department_id,
    first_name,
    last_name,
    email,
    hire_date,
    employment_status,
    profile_json
)
-- Selecteaza department_id-ul departamentului in care va fi inserat angajatul curent.
SELECT
    d.department_id,
    'Irina',
    'Marin',
    'irina.marin@company.local',
    DATE '2021-06-10',
    'ON_LEAVE',
    '{"phone":"0711000003","skills":["Management","Planning"]}'
FROM departments d
WHERE d.department_code = 'PMO';

INSERT INTO employees
(
    department_id,
    first_name,
    last_name,
    email,
    hire_date,
    employment_status,
    profile_json
)
-- Selecteaza department_id-ul departamentului in care va fi inserat angajatul curent.
SELECT
    d.department_id,
    'Radu',
    'Georgescu',
    'radu.georgescu@company.local',
    DATE '2024-01-08',
    'ACTIVE',
    '{"phone":"0711000004","skills":["Recruiting","Communication"]}'
FROM departments d
WHERE d.department_code = 'HR';


/* PASUL 9 - INSERAREA DATELOR IN PROJECTS

   Rol: Inseram cateva proiecte pe care se vor inregistra orele lucrate.
*/
INSERT INTO projects
(
    project_code,
    project_name,
    client_name,
    start_date,
    end_date,
    is_active
)
VALUES
(
    'TS001',
    'Internal Timesheet System',
    'Internal',
    DATE '2025-01-10',
    NULL,
    1
);

INSERT INTO projects
(
    project_code,
    project_name,
    client_name,
    start_date,
    end_date,
    is_active
)
VALUES
(
    'CL001',
    'ERP Implementation',
    'Contoso SRL',
    DATE '2025-02-01',
    NULL,
    1
);

INSERT INTO projects
(
    project_code,
    project_name,
    client_name,
    start_date,
    end_date,
    is_active
)
VALUES
(
    'BI001',
    'Reporting Dashboard',
    'Fabrikam',
    DATE '2025-03-01',
    NULL,
    1
);


/* PASUL 10 - INSERAREA DATELOR IN TIMESHEETS

   Rol: Inseram pontaje saptamanale pentru unii dintre angajati.

   Observatie:
   - am lasat intentionat un angajat fara timesheet
     pentru a demonstra corect interogarea cu LEFT JOIN.
*/
INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
-- Selecteaza employee_id-ul angajatului pentru care se insereaza pontajul saptamanal.
SELECT
    e.employee_id,
    DATE '2025-05-05',
    'APPROVED',
    TIMESTAMP '2025-05-11 18:00:00',
    TIMESTAMP '2025-05-12 09:00:00'
FROM employees e
WHERE e.email = 'ana.popescu@company.local';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
-- Selecteaza employee_id-ul angajatului pentru care se insereaza pontajul saptamanal.
SELECT
    e.employee_id,
    DATE '2025-05-05',
    'SUBMITTED',
    TIMESTAMP '2025-05-10 17:30:00',
    NULL
FROM employees e
WHERE e.email = 'mihai.ionescu@company.local';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
-- Selecteaza employee_id-ul angajatului pentru care se insereaza pontajul saptamanal.
SELECT
    e.employee_id,
    DATE '2025-05-12',
    'DRAFT',
    NULL,
    NULL
FROM employees e
WHERE e.email = 'ana.popescu@company.local';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
-- Selecteaza employee_id-ul angajatului pentru care se insereaza pontajul saptamanal.
SELECT
    e.employee_id,
    DATE '2025-05-05',
    'APPROVED',
    TIMESTAMP '2025-05-11 16:00:00',
    TIMESTAMP '2025-05-12 08:30:00'
FROM employees e
WHERE e.email = 'irina.marin@company.local';


/* PASUL 11 - INSERAREA DATELOR IN TIMESHEET_ENTRIES

   Rol: Inseram linii de pontaj pentru fiecare timesheet.
        Aici se vede efectiv cate ore s-au lucrat, in ce zi si pe ce proiect.

   Observatie:
   - entry_metadata_json contine informatii suplimentare
     in format JSON.
*/
INSERT INTO timesheet_entries
(
    timesheet_id,
    project_id,
    entry_date,
    hours_worked,
    task_description,
    entry_metadata_json,
    is_billable
)
VALUES
(
    (
        -- Selecteaza timesheet_id-ul aferent angajatului si saptamanii folosite in operatia curenta.
        SELECT t.timesheet_id
        FROM timesheets t
        JOIN employees e
            ON e.employee_id = t.employee_id
        WHERE e.email = 'ana.popescu@company.local'
          AND t.week_start_date = DATE '2025-05-05'
    ),
    (
        -- Selecteaza project_id-ul pe baza codului de proiect folosit in operatia curenta.
        SELECT p.project_id
        FROM projects p
        WHERE p.project_code = 'TS001'
    ),
    DATE '2025-05-05',
    4.00,
    'Analiza cerinte timesheet',
    '{"workMode":"remote","taskType":"analysis","billable":false}',
    0
);

INSERT INTO timesheet_entries
(
    timesheet_id,
    project_id,
    entry_date,
    hours_worked,
    task_description,
    entry_metadata_json,
    is_billable
)
VALUES
(
    (
        -- Selecteaza timesheet_id-ul aferent angajatului si saptamanii folosite in operatia curenta.
        SELECT t.timesheet_id
        FROM timesheets t
        JOIN employees e
            ON e.employee_id = t.employee_id
        WHERE e.email = 'ana.popescu@company.local'
          AND t.week_start_date = DATE '2025-05-05'
    ),
    (
        -- Selecteaza project_id-ul pe baza codului de proiect folosit in operatia curenta.
        SELECT p.project_id
        FROM projects p
        WHERE p.project_code = 'CL001'
    ),
    DATE '2025-05-06',
    4.00,
    'Configurare modul ERP',
    '{"workMode":"office","taskType":"implementation","billable":true}',
    1
);

INSERT INTO timesheet_entries
(
    timesheet_id,
    project_id,
    entry_date,
    hours_worked,
    task_description,
    entry_metadata_json,
    is_billable
)
VALUES
(
    (
        -- Selecteaza timesheet_id-ul aferent angajatului si saptamanii folosite in operatia curenta.
        SELECT t.timesheet_id
        FROM timesheets t
        JOIN employees e
            ON e.employee_id = t.employee_id
        WHERE e.email = 'ana.popescu@company.local'
          AND t.week_start_date = DATE '2025-05-05'
    ),
    (
        -- Selecteaza project_id-ul pe baza codului de proiect folosit in operatia curenta.
        SELECT p.project_id
        FROM projects p
        WHERE p.project_code = 'CL001'
    ),
    DATE '2025-05-07',
    3.50,
    'Testare functionalitati ERP',
    '{"workMode":"office","taskType":"testing","billable":true}',
    1
);

INSERT INTO timesheet_entries
(
    timesheet_id,
    project_id,
    entry_date,
    hours_worked,
    task_description,
    entry_metadata_json,
    is_billable
)
VALUES
(
    (
        -- Selecteaza timesheet_id-ul aferent angajatului si saptamanii folosite in operatia curenta.
        SELECT t.timesheet_id
        FROM timesheets t
        JOIN employees e
            ON e.employee_id = t.employee_id
        WHERE e.email = 'mihai.ionescu@company.local'
          AND t.week_start_date = DATE '2025-05-05'
    ),
    (
        -- Selecteaza project_id-ul pe baza codului de proiect folosit in operatia curenta.
        SELECT p.project_id
        FROM projects p
        WHERE p.project_code = 'CL001'
    ),
    DATE '2025-05-05',
    6.00,
    'Dezvoltare pachete PL/SQL',
    '{"workMode":"remote","taskType":"development","billable":true}',
    1
);

INSERT INTO timesheet_entries
(
    timesheet_id,
    project_id,
    entry_date,
    hours_worked,
    task_description,
    entry_metadata_json,
    is_billable
)
VALUES
(
    (
        -- Selecteaza timesheet_id-ul aferent angajatului si saptamanii folosite in operatia curenta.
        SELECT t.timesheet_id
        FROM timesheets t
        JOIN employees e
            ON e.employee_id = t.employee_id
        WHERE e.email = 'mihai.ionescu@company.local'
          AND t.week_start_date = DATE '2025-05-05'
    ),
    (
        -- Selecteaza project_id-ul pe baza codului de proiect folosit in operatia curenta.
        SELECT p.project_id
        FROM projects p
        WHERE p.project_code = 'BI001'
    ),
    DATE '2025-05-06',
    2.00,
    'Pregatire raportare BI',
    '{"workMode":"remote","taskType":"reporting","billable":true}',
    1
);

INSERT INTO timesheet_entries
(
    timesheet_id,
    project_id,
    entry_date,
    hours_worked,
    task_description,
    entry_metadata_json,
    is_billable
)
VALUES
(
    (
        -- Selecteaza timesheet_id-ul aferent angajatului si saptamanii folosite in operatia curenta.
        SELECT t.timesheet_id
        FROM timesheets t
        JOIN employees e
            ON e.employee_id = t.employee_id
        WHERE e.email = 'mihai.ionescu@company.local'
          AND t.week_start_date = DATE '2025-05-05'
    ),
    (
        -- Selecteaza project_id-ul pe baza codului de proiect folosit in operatia curenta.
        SELECT p.project_id
        FROM projects p
        WHERE p.project_code = 'TS001'
    ),
    DATE '2025-05-07',
    1.50,
    'Actualizare documentatie interna',
    '{"workMode":"office","taskType":"documentation","billable":false}',
    0
);

INSERT INTO timesheet_entries
(
    timesheet_id,
    project_id,
    entry_date,
    hours_worked,
    task_description,
    entry_metadata_json,
    is_billable
)
VALUES
(
    (
        -- Selecteaza timesheet_id-ul aferent angajatului si saptamanii folosite in operatia curenta.
        SELECT t.timesheet_id
        FROM timesheets t
        JOIN employees e
            ON e.employee_id = t.employee_id
        WHERE e.email = 'ana.popescu@company.local'
          AND t.week_start_date = DATE '2025-05-12'
    ),
    (
        -- Selecteaza project_id-ul pe baza codului de proiect folosit in operatia curenta.
        SELECT p.project_id
        FROM projects p
        WHERE p.project_code = 'TS001'
    ),
    DATE '2025-05-12',
    2.00,
    'Revizuire template pontaj',
    '{"workMode":"office","taskType":"review","billable":false}',
    0
);

INSERT INTO timesheet_entries
(
    timesheet_id,
    project_id,
    entry_date,
    hours_worked,
    task_description,
    entry_metadata_json,
    is_billable
)
VALUES
(
    (
        -- Selecteaza timesheet_id-ul aferent angajatului si saptamanii folosite in operatia curenta.
        SELECT t.timesheet_id
        FROM timesheets t
        JOIN employees e
            ON e.employee_id = t.employee_id
        WHERE e.email = 'ana.popescu@company.local'
          AND t.week_start_date = DATE '2025-05-12'
    ),
    (
        -- Selecteaza project_id-ul pe baza codului de proiect folosit in operatia curenta.
        SELECT p.project_id
        FROM projects p
        WHERE p.project_code = 'BI001'
    ),
    DATE '2025-05-13',
    5.00,
    'Creare dashboard status proiect',
    '{"workMode":"remote","taskType":"reporting","billable":true}',
    1
);

INSERT INTO timesheet_entries
(
    timesheet_id,
    project_id,
    entry_date,
    hours_worked,
    task_description,
    entry_metadata_json,
    is_billable
)
VALUES
(
    (
        -- Selecteaza timesheet_id-ul aferent angajatului si saptamanii folosite in operatia curenta.
        SELECT t.timesheet_id
        FROM timesheets t
        JOIN employees e
            ON e.employee_id = t.employee_id
        WHERE e.email = 'irina.marin@company.local'
          AND t.week_start_date = DATE '2025-05-05'
    ),
    (
        -- Selecteaza project_id-ul pe baza codului de proiect folosit in operatia curenta.
        SELECT p.project_id
        FROM projects p
        WHERE p.project_code = 'BI001'
    ),
    DATE '2025-05-05',
    7.00,
    'Management sedinta proiect',
    '{"workMode":"office","taskType":"meeting","billable":true}',
    1
);

INSERT INTO timesheet_entries
(
    timesheet_id,
    project_id,
    entry_date,
    hours_worked,
    task_description,
    entry_metadata_json,
    is_billable
)
VALUES
(
    (
        -- Selecteaza timesheet_id-ul aferent angajatului si saptamanii folosite in operatia curenta.
        SELECT t.timesheet_id
        FROM timesheets t
        JOIN employees e
            ON e.employee_id = t.employee_id
        WHERE e.email = 'irina.marin@company.local'
          AND t.week_start_date = DATE '2025-05-05'
    ),
    (
        -- Selecteaza project_id-ul pe baza codului de proiect folosit in operatia curenta.
        SELECT p.project_id
        FROM projects p
        WHERE p.project_code = 'TS001'
    ),
    DATE '2025-05-06',
    2.00,
    'Validare reguli de pontaj',
    '{"workMode":"office","taskType":"validation","billable":false}',
    0
);

/* Confirmarea inserarilor */
COMMIT;


/* PASUL 12 - CREAREA VIEW-ULUI NORMAL

   Rol: Acest view reuneste intr-o singura structura:
        - angajatii
        - pontajele lor
        - liniile de pontaj
        - proiectele pe care au lucrat

   Utilitate:
   View-ul simplifica interogarile de raportare si evita rescrierea repetata a acelorasi JOIN-uri.
*/
CREATE OR REPLACE VIEW vw_employee_project_hours AS
-- Afiseaza detaliile de pontaj pe angajat, proiect si zi lucrata.
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


/*
   PASUL 13 - CREAREA MATERIALIZED VIEW-ULUI

   Rol: Materialized view-ul stocheaza rezultatul unei interogari agregate si poate imbunatati performanta la raportare.

   In acest caz, el memoreaza:
   - numarul de inregistrari de pontaj pentru fiecare angajat
   - totalul de ore lucrate de fiecare angajat

   Observatie:
    - REFRESH COMPLETE ON DEMAND inseamna ca actualizarea nu se face automat la fiecare modificare din tabelele sursa
    - pentru a vedea datele actualizate dupa INSERT/UPDATE/DELETE, materialized view-ul trebuie reimprospatat manual
*/

CREATE MATERIALIZED VIEW mv_employee_total_hours
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
-- Stocheaza sumarul orelor lucrate pentru fiecare angajat, separat pe tipuri de ore.
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

CREATE INDEX ix_mv_employee_total_hours_total
    ON mv_employee_total_hours(total_hours);


/* PASUL 14 - INTEROGARE CU GROUP BY

   Rol: Aceasta interogare calculeaza cate ore s-au pontat pentru fiecare proiect.

*/
-- Afiseaza numarul total de ore pontate pentru fiecare proiect.
SELECT
    p.project_code,
    p.project_name,
    SUM(te.hours_worked) AS total_hours
FROM projects p
JOIN timesheet_entries te
    ON p.project_id = te.project_id
GROUP BY
    p.project_code,
    p.project_name
ORDER BY
    total_hours DESC;


/* PASUL 15 - INTEROGARE CU LEFT JOIN

   Rol: Aceasta interogare afiseaza toti angajatii, inclusiv pe cei care nu au inca niciun timesheet.

*/
-- Afiseaza toti angajatii si pontajele lor, inclusiv angajatii care nu au inca niciun timesheet.
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    t.timesheet_id,
    t.week_start_date,
    t.status
FROM employees e
LEFT JOIN timesheets t
    ON e.employee_id = t.employee_id
ORDER BY
    e.employee_id,
    t.week_start_date;


/* PASUL 16 - INTEROGARE CU FUNCTIE ANALITICA

   Rol: Aceasta interogare calculeaza totalul cumulativ al orelor lucrate pentru fiecare angajat, in ordinea datelor de pontaj.

   Functia analitica folosita:
   - SUM(...) OVER (...)

*/
-- Calculeaza totalul cumulativ al orelor lucrate pentru fiecare angajat in ordinea datelor de pontaj.
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    te.entry_date,
    te.hours_worked,
    SUM(te.hours_worked) OVER
    (
        PARTITION BY e.employee_id
        ORDER BY te.entry_date, te.entry_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_hours
FROM employees e
JOIN timesheets t
    ON e.employee_id = t.employee_id
JOIN timesheet_entries te
    ON t.timesheet_id = te.timesheet_id
ORDER BY
    e.employee_id,
    te.entry_date,
    te.entry_id;


/* PASUL 17 - INTEROGARE PE VIEW-UL NORMAL

   Rol: Aceasta interogare verifica functionarea view-ului normal si afiseaza continutul lui.

*/
-- Afiseaza continutul view-ului care reuneste angajatii, proiectele si liniile de pontaj.
SELECT
    employee_id,
    first_name,
    last_name,
    project_code,
    project_name,
    entry_date,
    hours_worked,
    task_description,
    timesheet_status,
    is_billable
FROM vw_employee_project_hours
ORDER BY
    employee_id,
    entry_date,
    project_code;


/* PASUL 18 - INTEROGARE PE MATERIALIZED VIEW

   Rol: Aceasta interogare verifica functionarea materialized view-ului si afiseaza totalul de ore pentru fiecare angajat.

*/
-- Afiseaza totalul de ore si numarul de inregistrari pentru fiecare angajat din materialized view.
SELECT
    employee_id,
    first_name,
    last_name,
    entry_count,
    total_hours
FROM mv_employee_total_hours
ORDER BY
    total_hours DESC,
    employee_id;

/* PASUL 19 - INTEROGARE PE DATELE JSON

   Rol: Aceasta interogare demonstreaza folosirea efectiva a coloanelor cu date semistructurate in format JSON.

   Ce face:
   - extrage numarul de telefon al angajatului din employees.profile_json
   - extrage modul de lucru si tipul activitatii din timesheet_entries.entry_metadata_json

*/
-- Afiseaza pentru fiecare linie de pontaj telefonul angajatului si detalii extrase din campurile JSON.
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    JSON_VALUE(e.profile_json, '$.phone') AS phone_number,
    te.entry_date,
    te.hours_worked,
    JSON_VALUE(te.entry_metadata_json, '$.workMode') AS work_mode,
    JSON_VALUE(te.entry_metadata_json, '$.taskType') AS task_type
FROM employees e
JOIN timesheets t
    ON e.employee_id = t.employee_id
JOIN timesheet_entries te
    ON t.timesheet_id = te.timesheet_id
ORDER BY
    e.employee_id,
    te.entry_date,
    te.entry_id;
    
    

/* PASUL 20 - VIEW SECURIZAT PENTRU RAPORTARE

   Rol:
   - ascunde partial datele sensibile
   - permite raportare fara acces direct la tabelele de baza
*/
CREATE OR REPLACE VIEW vw_employee_reporting_secure AS
-- Afiseaza raportari de pontaj cu email mascat si fara expunerea directa a coloanelor JSON.
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
    
    
    /* PASUL 21 - TABEL DE AUDIT PENTRU MODIFICARILE DIN TIMESHEET_ENTRIES

   Rol:
   - pastreaza istoricul schimbarilor importante
   - ajuta la trasabilitate si control
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

/* PASUL 22 - TRIGGER DE AUDIT

   Rol:
   - logheaza INSERT/UPDATE/DELETE din timesheet_entries
*/
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
/


/* PASUL 23 - DEMONSTRAREA SI VERIFICAREA AUDITULUI

   Rol:
   - genereaza operatii de tip INSERT, UPDATE si DELETE
   - verifica inregistrarile scrise de trigger in tabela de audit
*/

-- Insereaza o linie temporara pentru a demonstra auditarea operatiei de INSERT.
INSERT INTO timesheet_entries
(
    timesheet_id,
    project_id,
    entry_date,
    hours_worked,
    task_description,
    entry_metadata_json,
    is_billable
)
VALUES
(
    (
        -- Selecteaza timesheet_id-ul aferent angajatului si saptamanii folosite in operatia curenta.
        SELECT t.timesheet_id
        FROM timesheets t
        JOIN employees e
            ON e.employee_id = t.employee_id
        WHERE e.email = 'ana.popescu@company.local'
          AND t.week_start_date = DATE '2025-05-12'
    ),
    (
        -- Selecteaza project_id-ul pe baza codului de proiect folosit in operatia curenta.
        SELECT p.project_id
        FROM projects p
        WHERE p.project_code = 'TS001'
    ),
    DATE '2025-05-14',
    1.00,
    'Test audit temporar',
    '{"workMode":"office","taskType":"audit","billable":false}',
    0
);

-- Modifica aceeasi linie pentru a demonstra auditarea operatiei de UPDATE.
UPDATE timesheet_entries
SET
    hours_worked = 1.50,
    is_billable = 1
WHERE timesheet_id =
      (
          -- Selecteaza timesheet_id-ul aferent angajatului si saptamanii folosite in operatia curenta.
          SELECT t.timesheet_id
          FROM timesheets t
          JOIN employees e
              ON e.employee_id = t.employee_id
          WHERE e.email = 'ana.popescu@company.local'
            AND t.week_start_date = DATE '2025-05-12'
      )
  AND project_id =
      (
          -- Selecteaza project_id-ul pe baza codului de proiect folosit in operatia curenta.
          SELECT p.project_id
          FROM projects p
          WHERE p.project_code = 'TS001'
      )
  AND entry_date = DATE '2025-05-14'
  AND task_description = 'Test audit temporar';

-- Sterge aceeasi linie pentru a demonstra auditarea operatiei de DELETE.
DELETE FROM timesheet_entries
WHERE timesheet_id =
      (
          -- Selecteaza timesheet_id-ul aferent angajatului si saptamanii folosite in operatia curenta.
          SELECT t.timesheet_id
          FROM timesheets t
          JOIN employees e
              ON e.employee_id = t.employee_id
          WHERE e.email = 'ana.popescu@company.local'
            AND t.week_start_date = DATE '2025-05-12'
      )
  AND project_id =
      (
          -- Selecteaza project_id-ul pe baza codului de proiect folosit in operatia curenta.
          SELECT p.project_id
          FROM projects p
          WHERE p.project_code = 'TS001'
      )
  AND entry_date = DATE '2025-05-14'
  AND task_description = 'Test audit temporar';

COMMIT;

-- Afiseaza istoricul modificarilor facute asupra liniilor de pontaj.
SELECT
    audit_id,
    operation_type,
    entry_id,
    old_hours_worked,
    new_hours_worked,
    old_is_billable,
    new_is_billable,
    changed_by,
    changed_at
FROM audit_timesheet_entries
ORDER BY audit_id;


/* PASUL 24 - ROLE-URI SI PRIVILEGII

   Rol:
   - separa accesul de raportare de accesul operational
   - permite rerularea scriptului fara eroare daca rolurile exista deja
*/

GRANT SELECT, INSERT, UPDATE ON timesheets TO role_timesheet_app;
GRANT SELECT, INSERT, UPDATE ON timesheet_entries TO role_timesheet_app;
GRANT SELECT ON projects TO role_timesheet_app;
GRANT SELECT ON employees TO role_timesheet_app;

GRANT SELECT ON vw_employee_reporting_secure TO role_timesheet_report;
GRANT SELECT ON mv_employee_total_hours TO role_timesheet_report;

/* PASUL 25 - INTEROGARE CU DENSE_RANK

   Rol:
   - identifica proiectele pe care fiecare angajat a lucrat cel mai mult
   - foloseste functie analitica pentru clasament pe fiecare angajat
*/
-- Afiseaza pentru fiecare angajat clasamentul proiectelor in functie de numarul total de ore lucrate.
SELECT
    employee_id,
    first_name,
    last_name,
    project_code,
    project_name,
    total_hours,
    DENSE_RANK() OVER
    (
        PARTITION BY employee_id
        ORDER BY total_hours DESC
    ) AS project_rank
FROM
(
    -- Agrega totalul de ore lucrate de fiecare angajat pe fiecare proiect.
    SELECT
        e.employee_id,
        e.first_name,
        e.last_name,
        p.project_code,
        p.project_name,
        SUM(te.hours_worked) AS total_hours
    FROM employees e
    JOIN timesheets t
        ON e.employee_id = t.employee_id
    JOIN timesheet_entries te
        ON t.timesheet_id = te.timesheet_id
    JOIN projects p
        ON te.project_id = p.project_id
    GROUP BY
        e.employee_id,
        e.first_name,
        e.last_name,
        p.project_code,
        p.project_name
) project_hours
ORDER BY
    employee_id,
    project_rank,
    project_code;
    
    
    /* PASUL 26 - INTEROGARE CU LAG

   Rol:
   - compara orele lucrate la o inregistrare cu cele de la inregistrarea anterioara a aceluiasi angajat
*/
-- Afiseaza diferenta dintre orele lucrate la o inregistrare si cele de la inregistrarea anterioara a aceluiasi angajat.
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    te.entry_date,
    te.hours_worked,
    LAG(te.hours_worked) OVER
    (
        PARTITION BY e.employee_id
        ORDER BY te.entry_date, te.entry_id
    ) AS previous_hours,
    te.hours_worked
    - NVL
      (
          LAG(te.hours_worked) OVER
          (
              PARTITION BY e.employee_id
              ORDER BY te.entry_date, te.entry_id
          ),
          0
      ) AS difference_from_previous
FROM employees e
JOIN timesheets t
    ON e.employee_id = t.employee_id
JOIN timesheet_entries te
    ON t.timesheet_id = te.timesheet_id
ORDER BY
    e.employee_id,
    te.entry_date,
    te.entry_id;
    
    /* PASUL 27 - INTEROGARE COMPLEXA CU LEFT JOIN SI AGREGARE CONDITIONALA

   Rol:
   - afiseaza pentru fiecare angajat totalul de ore facturabile si nefacturabile
   - pastreaza si angajatii care nu au pontaje
*/
-- Afiseaza totalul orelor billable si non-billable pentru fiecare angajat, inclusiv pentru cei fara inregistrari.
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    NVL(SUM(CASE WHEN te.is_billable = 1 THEN te.hours_worked ELSE 0 END), 0) AS billable_hours,
    NVL(SUM(CASE WHEN te.is_billable = 0 THEN te.hours_worked ELSE 0 END), 0) AS non_billable_hours,
    NVL(SUM(te.hours_worked), 0) AS total_hours
FROM employees e
LEFT JOIN timesheets t
    ON e.employee_id = t.employee_id
LEFT JOIN timesheet_entries te
    ON t.timesheet_id = te.timesheet_id
GROUP BY
    e.employee_id,
    e.first_name,
    e.last_name
ORDER BY
    total_hours DESC,
    e.employee_id;
    
    /* PASUL 28 - INTEROGARE CU ROLLUP

   Rol:
   - calculeaza subtotaluri pe angajat si total general
*/
-- Afiseaza totalul de ore pe angajat si proiect, plus subtotaluri si total general.
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    p.project_name,
    SUM(te.hours_worked) AS total_hours
FROM employees e
JOIN timesheets t
    ON e.employee_id = t.employee_id
JOIN timesheet_entries te
    ON t.timesheet_id = te.timesheet_id
JOIN projects p
    ON te.project_id = p.project_id
GROUP BY ROLLUP
(
    (e.employee_id, e.first_name, e.last_name),
    p.project_name
)
ORDER BY
    e.employee_id,
    p.project_name;




    
/* PASUL 29 - DEMONSTRAREA REFRESH-ULUI MATERIALIZED VIEW

   Rol:
   - arata ca materialized view-ul trebuie reimprospatat dupa modificarea datelor sursa
*/

/* Inseram o noua linie de pontaj in tabela de baza */

INSERT INTO timesheet_entries
(
    timesheet_id,
    project_id,
    entry_date,
    hours_worked,
    task_description,
    entry_metadata_json,
    is_billable
)
VALUES
(
    (
        -- Selecteaza timesheet_id-ul aferent angajatului si saptamanii folosite in operatia curenta.
        SELECT t.timesheet_id
        FROM timesheets t
        JOIN employees e
            ON e.employee_id = t.employee_id
        WHERE e.email = 'mihai.ionescu@company.local'
          AND t.week_start_date = DATE '2025-05-05'
    ),
    (
        -- Selecteaza project_id-ul pe baza codului de proiect folosit in operatia curenta.
        SELECT p.project_id
        FROM projects p
        WHERE p.project_code = 'CL001'
    ),
    DATE '2025-05-08',
    2.50,
    'Optimizare pachet PL/SQL',
    '{"workMode":"remote","taskType":"optimization","billable":true}',
    1
);

COMMIT;

/* Verificam ca tabela de baza contine noua inregistrare */
-- Afiseaza noua inregistrare inserata in tabela de baza.
SELECT
    entry_id,
    timesheet_id,
    project_id,
    entry_date,
    hours_worked,
    task_description
FROM timesheet_entries
WHERE timesheet_id =
      (
          -- Selecteaza timesheet_id-ul aferent angajatului si saptamanii folosite in operatia curenta.
          SELECT t.timesheet_id
          FROM timesheets t
          JOIN employees e
              ON e.employee_id = t.employee_id
          WHERE e.email = 'mihai.ionescu@company.local'
            AND t.week_start_date = DATE '2025-05-05'
      )
ORDER BY entry_id;

/* Verificam continutul materialized view-ului inainte de refresh */
-- Afiseaza valorile din materialized view inainte de reimprospatare.
SELECT
    employee_id,
    first_name,
    last_name,
    entry_count,
    total_hours,
    billable_hours,
    non_billable_hours
FROM mv_employee_total_hours
ORDER BY employee_id;

/* Reimprospatarea materialized view-ului */
BEGIN
    DBMS_MVIEW.REFRESH('MV_EMPLOYEE_TOTAL_HOURS', 'C');
END;
/

/* Verificam din nou materialized view-ul dupa refresh */
-- Afiseaza valorile actualizate din materialized view dupa reimprospatare.
SELECT
    employee_id,
    first_name,
    last_name,
    entry_count,
    total_hours,
    billable_hours,
    non_billable_hours
FROM mv_employee_total_hours
ORDER BY employee_id;




/* TARADACIUC NICOLAE

   SCRIPT 3 

   - sterge datele vechi din tabelele principale
   - adauga departamentele, proiectele si 15 angajati
   - creeaza cate doua timesheet-uri APPROVED pentru fiecare angajat

*/

SET SERVEROUTPUT ON;

/* Mai intai stergem datele deja existente din tabelele operationale. ( In caz de rerulare a scriptului)*/
DELETE FROM timesheet_entries;
DELETE FROM timesheets;
DELETE FROM employees;
DELETE FROM projects;
DELETE FROM departments;
COMMIT;

/* Adaugarea departamentelor */
INSERT INTO departments (department_code, department_name) VALUES ('HR', 'Human Resources');
INSERT INTO departments (department_code, department_name) VALUES ('DEV', 'Development');
INSERT INTO departments (department_code, department_name) VALUES ('PMO', 'Project Management');

/* Adaugarea proiectelor*/
INSERT INTO projects (project_code, project_name, client_name, start_date, end_date, is_active)
VALUES ('TS001', 'Internal Timesheet System', 'Internal', DATE '2025-01-10', NULL, 1);
INSERT INTO projects (project_code, project_name, client_name, start_date, end_date, is_active)
VALUES ('CL001', 'ERP Implementation', 'Contoso SRL', DATE '2025-02-01', NULL, 1);
INSERT INTO projects (project_code, project_name, client_name, start_date, end_date, is_active)
VALUES ('BI001', 'Reporting Dashboard', 'Fabrikam', DATE '2025-03-01', NULL, 1);

/* Introducerea celor 15 angajati.*/

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
SELECT d.department_id, 'Casian', 'Bahrim', 'casian.bahrim@endava.com', DATE '2023-04-03', 'ACTIVE',
       '{"phone":"0711000101","skills":["SQL","PLSQL","Excel"]}'
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
SELECT d.department_id, 'Razvan', 'Macovei', 'razvan.macovei@endava.com', DATE '2022-11-14', 'ACTIVE',
       '{"phone":"0711000102","skills":["Oracle","Power BI","ETL"]}'
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
SELECT d.department_id, 'Mihai', 'Ginghina', 'mihai.ginghina@endava.com', DATE '2021-08-09', 'ACTIVE',
       '{"phone":"0711000103","skills":["PLSQL","Tuning","Linux"]}'
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
SELECT d.department_id, 'Andrei', 'Murgulet', 'andrei.murgulet@endava.com', DATE '2024-01-15', 'ACTIVE',
       '{"phone":"0711000104","skills":["Java","APIs","SQL"]}'
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
SELECT d.department_id, 'Nicolae', 'Taradaciuc', 'nicolae.taradaciuc@endava.com', DATE '2023-09-18', 'ACTIVE',
       '{"phone":"0711000105","skills":["SQL","Python","Security"]}'
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
SELECT d.department_id, 'Tudor', 'Gradinaru', 'tudor.gradinaru@endava.com', DATE '2020-06-22', 'ACTIVE',
       '{"phone":"0711000106","skills":["Oracle","Bash","Data Modeling"]}'
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
SELECT d.department_id, 'Diana', 'Martisca', 'diana.martisca@endava.com', DATE '2022-03-07', 'ACTIVE',
       '{"phone":"0711000107","skills":["Planning","Reporting","Risk"]}'
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
SELECT d.department_id, 'Iustina', 'Bulai', 'iustina.bulai@endava.com', DATE '2024-04-10', 'ACTIVE',
       '{"phone":"0711000108","skills":["Recruiting","Communication","Excel"]}'
FROM departments d
WHERE d.department_code = 'HR';

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
SELECT d.department_id, 'Alexandru', 'Balosin', 'alexandru.balosin@endava.com', DATE '2023-01-30', 'ACTIVE',
       '{"phone":"0711000109","skills":["APEX","SQL","Testing"]}'
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
SELECT d.department_id, 'Daniel', 'Birgovan', 'daniel.birgovan@endava.com', DATE '2021-12-13', 'ACTIVE',
       '{"phone":"0711000110","skills":["Oracle","Integration","REST"]}'
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
SELECT d.department_id, 'Eusebiu', 'Vatamaniuc', 'eusebiu.vatamaniuc@endava.com', DATE '2020-10-05', 'ACTIVE',
       '{"phone":"0711000111","skills":["HR Ops","Payroll","Excel"]}'
FROM departments d
WHERE d.department_code = 'HR';

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
SELECT d.department_id, 'Elena', 'Aioanei', 'elena.aioanei@endava.com', DATE '2022-07-19', 'ACTIVE',
       '{"phone":"0711000112","skills":["Stakeholder Mgmt","Reporting","Budgeting"]}'
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
SELECT d.department_id, 'Stefan', 'Slanina', 'stefan.slanina@endava.com', DATE '2023-06-26', 'ACTIVE',
       '{"phone":"0711000113","skills":["Performance Tuning","Linux","SQL"]}'
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
SELECT d.department_id, 'Rebecca', 'Sacarescu', 'rebecca.sacarescu@endava.com', DATE '2021-05-17', 'ACTIVE',
       '{"phone":"0711000114","skills":["Onboarding","Communication","Documentation"]}'
FROM departments d
WHERE d.department_code = 'HR';

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
SELECT d.department_id, 'Raluca', 'Bocanet', 'raluca.bocanet@endava.com', DATE '2024-02-12', 'ACTIVE',
       '{"phone":"0711000115","skills":["Planning","PMO","Governance"]}'
FROM departments d
WHERE d.department_code = 'PMO';

COMMIT;

/* 
   De aici incep inserturile pentru TIMESHEETS / pontajele saptamanale

   Fiecare insert creeaza un timesheet saptamanal pentru un angajat.
   Observa ca il identificam dupa email, ca sa fie clar pentru cine
   cream pontajul.


*/

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-23',
    'APPROVED',
    TO_TIMESTAMP('2026-03-27 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-03-28 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'casian.bahrim@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-30',
    'APPROVED',
    TO_TIMESTAMP('2026-04-03 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-04-04 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'casian.bahrim@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-23',
    'APPROVED',
    TO_TIMESTAMP('2026-03-27 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-03-28 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'razvan.macovei@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-30',
    'APPROVED',
    TO_TIMESTAMP('2026-04-03 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-04-04 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'razvan.macovei@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-23',
    'APPROVED',
    TO_TIMESTAMP('2026-03-27 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-03-28 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'mihai.ginghina@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-30',
    'APPROVED',
    TO_TIMESTAMP('2026-04-03 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-04-04 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'mihai.ginghina@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-23',
    'APPROVED',
    TO_TIMESTAMP('2026-03-27 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-03-28 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'andrei.murgulet@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-30',
    'APPROVED',
    TO_TIMESTAMP('2026-04-03 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-04-04 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'andrei.murgulet@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-23',
    'APPROVED',
    TO_TIMESTAMP('2026-03-27 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-03-28 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'nicolae.taradaciuc@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-30',
    'APPROVED',
    TO_TIMESTAMP('2026-04-03 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-04-04 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'nicolae.taradaciuc@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-23',
    'APPROVED',
    TO_TIMESTAMP('2026-03-27 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-03-28 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'tudor.gradinaru@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-30',
    'APPROVED',
    TO_TIMESTAMP('2026-04-03 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-04-04 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'tudor.gradinaru@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-23',
    'APPROVED',
    TO_TIMESTAMP('2026-03-27 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-03-28 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'diana.martisca@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-30',
    'APPROVED',
    TO_TIMESTAMP('2026-04-03 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-04-04 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'diana.martisca@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-23',
    'APPROVED',
    TO_TIMESTAMP('2026-03-27 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-03-28 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'iustina.bulai@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-30',
    'APPROVED',
    TO_TIMESTAMP('2026-04-03 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-04-04 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'iustina.bulai@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-23',
    'APPROVED',
    TO_TIMESTAMP('2026-03-27 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-03-28 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'alexandru.balosin@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-30',
    'APPROVED',
    TO_TIMESTAMP('2026-04-03 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-04-04 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'alexandru.balosin@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-23',
    'APPROVED',
    TO_TIMESTAMP('2026-03-27 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-03-28 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'daniel.birgovan@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-30',
    'APPROVED',
    TO_TIMESTAMP('2026-04-03 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-04-04 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'daniel.birgovan@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-23',
    'APPROVED',
    TO_TIMESTAMP('2026-03-27 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-03-28 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'eusebiu.vatamaniuc@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-30',
    'APPROVED',
    TO_TIMESTAMP('2026-04-03 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-04-04 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'eusebiu.vatamaniuc@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-23',
    'APPROVED',
    TO_TIMESTAMP('2026-03-27 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-03-28 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'elena.aioanei@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-30',
    'APPROVED',
    TO_TIMESTAMP('2026-04-03 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-04-04 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'elena.aioanei@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-23',
    'APPROVED',
    TO_TIMESTAMP('2026-03-27 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-03-28 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'stefan.slanina@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-30',
    'APPROVED',
    TO_TIMESTAMP('2026-04-03 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-04-04 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'stefan.slanina@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-23',
    'APPROVED',
    TO_TIMESTAMP('2026-03-27 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-03-28 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'rebecca.sacarescu@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-30',
    'APPROVED',
    TO_TIMESTAMP('2026-04-03 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-04-04 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'rebecca.sacarescu@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-23',
    'APPROVED',
    TO_TIMESTAMP('2026-03-27 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-03-28 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'raluca.bocanet@endava.com';

INSERT INTO timesheets
(
    employee_id,
    week_start_date,
    status,
    submitted_at,
    approved_at
)
SELECT
    e.employee_id,
    DATE '2026-03-30',
    'APPROVED',
    TO_TIMESTAMP('2026-04-03 17:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_TIMESTAMP('2026-04-04 09:00:00', 'YYYY-MM-DD HH24:MI:SS')
FROM employees e
WHERE e.email = 'raluca.bocanet@endava.com';

/* 
   De aici incep liniile efective de pontaj.

   Fiecare INSERT din aceasta zona inseamna:
   - o anumita zi
   - pentru un anumit angajat
   - pe un anumit proiect
   - cu un anumit numar de ore
   - cu o descriere de task
   - cu metadata JSON despre work mode si task type

   Cu alte cuvinte, aici salvam "ce a facut angajatul intr-o anumita zi".
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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-24',
    8,
    'Analiza cerinte',
    '{"workMode":"remote","taskType":"analysis","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'casian.bahrim@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-26',
    8,
    'Implementare modul',
    '{"workMode":"office","taskType":"development","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'casian.bahrim@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-27',
    8,
    'Testare functionalitati',
    '{"workMode":"hybrid","taskType":"testing","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'casian.bahrim@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-30',
    8,
    'Implementare modul',
    '{"workMode":"remote","taskType":"development","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'casian.bahrim@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-31',
    8,
    'Testare functionalitati',
    '{"workMode":"office","taskType":"testing","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'casian.bahrim@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-01',
    8,
    'Pregatire raportare',
    '{"workMode":"hybrid","taskType":"reporting","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'casian.bahrim@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-02',
    8,
    'Actualizare documentatie',
    '{"workMode":"remote","taskType":"documentation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'casian.bahrim@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-03',
    6.5,
    'Revizuire template',
    '{"workMode":"office","taskType":"review","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'casian.bahrim@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-23',
    8,
    'Testare functionalitati',
    '{"workMode":"office","taskType":"development","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'razvan.macovei@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-24',
    8,
    'Pregatire raportare',
    '{"workMode":"hybrid","taskType":"testing","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'razvan.macovei@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-30',
    8,
    'Pregatire raportare',
    '{"workMode":"office","taskType":"testing","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'razvan.macovei@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-31',
    8,
    'Actualizare documentatie',
    '{"workMode":"hybrid","taskType":"reporting","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'razvan.macovei@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-01',
    8,
    'Revizuire template',
    '{"workMode":"remote","taskType":"documentation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'razvan.macovei@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-03',
    8,
    'Optimizare query',
    '{"workMode":"office","taskType":"review","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'razvan.macovei@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-23',
    8,
    'Actualizare documentatie',
    '{"workMode":"hybrid","taskType":"testing","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'mihai.ginghina@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-24',
    8,
    'Revizuire template',
    '{"workMode":"remote","taskType":"reporting","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'mihai.ginghina@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-25',
    8,
    'Optimizare query',
    '{"workMode":"office","taskType":"documentation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'mihai.ginghina@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-26',
    8,
    'Sedinta proiect',
    '{"workMode":"hybrid","taskType":"review","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'mihai.ginghina@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-27',
    6.5,
    'Validare date',
    '{"workMode":"remote","taskType":"optimization","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'mihai.ginghina@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-31',
    8,
    'Revizuire template',
    '{"workMode":"hybrid","taskType":"reporting","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'mihai.ginghina@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-01',
    8,
    'Optimizare query',
    '{"workMode":"remote","taskType":"documentation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'mihai.ginghina@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-02',
    8,
    'Sedinta proiect',
    '{"workMode":"office","taskType":"review","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'mihai.ginghina@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-03',
    8,
    'Validare date',
    '{"workMode":"hybrid","taskType":"optimization","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'mihai.ginghina@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-23',
    8,
    'Optimizare query',
    '{"workMode":"remote","taskType":"reporting","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'andrei.murgulet@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-24',
    8,
    'Sedinta proiect',
    '{"workMode":"office","taskType":"documentation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'andrei.murgulet@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-27',
    8,
    'Validare date',
    '{"workMode":"hybrid","taskType":"review","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'andrei.murgulet@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-30',
    8,
    'Sedinta proiect',
    '{"workMode":"remote","taskType":"documentation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'andrei.murgulet@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-01',
    8,
    'Validare date',
    '{"workMode":"office","taskType":"review","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'andrei.murgulet@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-03',
    8,
    'Configurare dashboard',
    '{"workMode":"hybrid","taskType":"optimization","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'andrei.murgulet@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-23',
    8,
    'Validare date',
    '{"workMode":"office","taskType":"documentation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'nicolae.taradaciuc@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-24',
    8,
    'Configurare dashboard',
    '{"workMode":"hybrid","taskType":"review","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'nicolae.taradaciuc@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-30',
    8,
    'Configurare dashboard',
    '{"workMode":"office","taskType":"review","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'nicolae.taradaciuc@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-03',
    8,
    'Analiza cerinte',
    '{"workMode":"hybrid","taskType":"optimization","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'nicolae.taradaciuc@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-23',
    8,
    'Analiza cerinte',
    '{"workMode":"hybrid","taskType":"review","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'tudor.gradinaru@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-24',
    8,
    'Implementare modul',
    '{"workMode":"remote","taskType":"optimization","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'tudor.gradinaru@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-25',
    8,
    'Testare functionalitati',
    '{"workMode":"office","taskType":"meeting","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'tudor.gradinaru@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-27',
    8,
    'Pregatire raportare',
    '{"workMode":"hybrid","taskType":"validation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'tudor.gradinaru@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-30',
    8,
    'Implementare modul',
    '{"workMode":"hybrid","taskType":"optimization","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'tudor.gradinaru@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-31',
    8,
    'Testare functionalitati',
    '{"workMode":"remote","taskType":"meeting","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'tudor.gradinaru@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-02',
    8,
    'Pregatire raportare',
    '{"workMode":"office","taskType":"validation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'tudor.gradinaru@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-03',
    8,
    'Actualizare documentatie',
    '{"workMode":"hybrid","taskType":"analysis","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'tudor.gradinaru@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-23',
    8,
    'Testare functionalitati',
    '{"workMode":"remote","taskType":"optimization","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'diana.martisca@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-24',
    8,
    'Pregatire raportare',
    '{"workMode":"office","taskType":"meeting","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'diana.martisca@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-25',
    8,
    'Actualizare documentatie',
    '{"workMode":"hybrid","taskType":"validation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'diana.martisca@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-30',
    8,
    'Pregatire raportare',
    '{"workMode":"remote","taskType":"meeting","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'diana.martisca@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-31',
    8,
    'Actualizare documentatie',
    '{"workMode":"office","taskType":"validation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'diana.martisca@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-01',
    8,
    'Revizuire template',
    '{"workMode":"hybrid","taskType":"analysis","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'diana.martisca@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-23',
    8,
    'Actualizare documentatie',
    '{"workMode":"office","taskType":"meeting","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'iustina.bulai@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-24',
    8,
    'Revizuire template',
    '{"workMode":"hybrid","taskType":"validation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'iustina.bulai@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-25',
    8,
    'Optimizare query',
    '{"workMode":"remote","taskType":"analysis","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'iustina.bulai@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-26',
    8,
    'Sedinta proiect',
    '{"workMode":"office","taskType":"development","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'iustina.bulai@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-27',
    6.5,
    'Validare date',
    '{"workMode":"hybrid","taskType":"testing","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'iustina.bulai@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-30',
    8,
    'Revizuire template',
    '{"workMode":"office","taskType":"validation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'iustina.bulai@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-31',
    8,
    'Optimizare query',
    '{"workMode":"hybrid","taskType":"analysis","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'iustina.bulai@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-01',
    8,
    'Sedinta proiect',
    '{"workMode":"remote","taskType":"development","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'iustina.bulai@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-03',
    8,
    'Validare date',
    '{"workMode":"office","taskType":"testing","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'iustina.bulai@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-23',
    8,
    'Optimizare query',
    '{"workMode":"hybrid","taskType":"validation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'alexandru.balosin@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-24',
    8,
    'Sedinta proiect',
    '{"workMode":"remote","taskType":"analysis","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'alexandru.balosin@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-25',
    8,
    'Validare date',
    '{"workMode":"office","taskType":"development","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'alexandru.balosin@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-26',
    8,
    'Configurare dashboard',
    '{"workMode":"hybrid","taskType":"testing","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'alexandru.balosin@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-27',
    6.5,
    'Analiza cerinte',
    '{"workMode":"remote","taskType":"reporting","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'alexandru.balosin@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-31',
    8,
    'Sedinta proiect',
    '{"workMode":"hybrid","taskType":"analysis","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'alexandru.balosin@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-01',
    8,
    'Validare date',
    '{"workMode":"remote","taskType":"development","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'alexandru.balosin@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-02',
    8,
    'Configurare dashboard',
    '{"workMode":"office","taskType":"testing","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'alexandru.balosin@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-03',
    8,
    'Analiza cerinte',
    '{"workMode":"hybrid","taskType":"reporting","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'alexandru.balosin@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-23',
    8,
    'Validare date',
    '{"workMode":"remote","taskType":"analysis","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'daniel.birgovan@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-24',
    8,
    'Configurare dashboard',
    '{"workMode":"office","taskType":"development","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'daniel.birgovan@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-25',
    8,
    'Analiza cerinte',
    '{"workMode":"hybrid","taskType":"testing","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'daniel.birgovan@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-27',
    8,
    'Implementare modul',
    '{"workMode":"remote","taskType":"reporting","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'daniel.birgovan@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-30',
    8,
    'Configurare dashboard',
    '{"workMode":"remote","taskType":"development","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'daniel.birgovan@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-31',
    8,
    'Analiza cerinte',
    '{"workMode":"office","taskType":"testing","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'daniel.birgovan@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-01',
    8,
    'Implementare modul',
    '{"workMode":"hybrid","taskType":"reporting","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'daniel.birgovan@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-23',
    8,
    'Analiza cerinte',
    '{"workMode":"office","taskType":"development","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'eusebiu.vatamaniuc@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-30',
    8,
    'Implementare modul',
    '{"workMode":"office","taskType":"testing","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'eusebiu.vatamaniuc@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-31',
    8,
    'Testare functionalitati',
    '{"workMode":"hybrid","taskType":"reporting","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'eusebiu.vatamaniuc@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-01',
    8,
    'Pregatire raportare',
    '{"workMode":"remote","taskType":"documentation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'eusebiu.vatamaniuc@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-03',
    8,
    'Actualizare documentatie',
    '{"workMode":"office","taskType":"review","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'eusebiu.vatamaniuc@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-23',
    8,
    'Testare functionalitati',
    '{"workMode":"hybrid","taskType":"testing","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'elena.aioanei@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-24',
    8,
    'Pregatire raportare',
    '{"workMode":"remote","taskType":"reporting","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'elena.aioanei@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-25',
    8,
    'Actualizare documentatie',
    '{"workMode":"office","taskType":"documentation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'elena.aioanei@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-26',
    8,
    'Revizuire template',
    '{"workMode":"hybrid","taskType":"review","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'elena.aioanei@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-27',
    6.5,
    'Optimizare query',
    '{"workMode":"remote","taskType":"optimization","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'elena.aioanei@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-30',
    8,
    'Pregatire raportare',
    '{"workMode":"hybrid","taskType":"reporting","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'elena.aioanei@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-01',
    8,
    'Actualizare documentatie',
    '{"workMode":"remote","taskType":"documentation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'elena.aioanei@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-02',
    8,
    'Revizuire template',
    '{"workMode":"office","taskType":"review","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'elena.aioanei@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-03',
    8,
    'Optimizare query',
    '{"workMode":"hybrid","taskType":"optimization","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'elena.aioanei@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-23',
    8,
    'Actualizare documentatie',
    '{"workMode":"remote","taskType":"reporting","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'stefan.slanina@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-24',
    8,
    'Revizuire template',
    '{"workMode":"office","taskType":"documentation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'stefan.slanina@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-25',
    8,
    'Optimizare query',
    '{"workMode":"hybrid","taskType":"review","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'stefan.slanina@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-26',
    8,
    'Sedinta proiect',
    '{"workMode":"remote","taskType":"optimization","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'stefan.slanina@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-27',
    6.5,
    'Validare date',
    '{"workMode":"office","taskType":"meeting","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'stefan.slanina@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-30',
    8,
    'Revizuire template',
    '{"workMode":"remote","taskType":"documentation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'stefan.slanina@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-31',
    8,
    'Optimizare query',
    '{"workMode":"office","taskType":"review","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'stefan.slanina@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-02',
    8,
    'Sedinta proiect',
    '{"workMode":"hybrid","taskType":"optimization","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'stefan.slanina@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-03',
    8,
    'Validare date',
    '{"workMode":"remote","taskType":"meeting","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'stefan.slanina@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-23',
    8,
    'Optimizare query',
    '{"workMode":"office","taskType":"documentation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'rebecca.sacarescu@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-24',
    8,
    'Sedinta proiect',
    '{"workMode":"hybrid","taskType":"review","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'rebecca.sacarescu@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-30',
    8,
    'Sedinta proiect',
    '{"workMode":"office","taskType":"review","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'rebecca.sacarescu@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-31',
    8,
    'Validare date',
    '{"workMode":"hybrid","taskType":"optimization","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'rebecca.sacarescu@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-01',
    8,
    'Configurare dashboard',
    '{"workMode":"remote","taskType":"meeting","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'rebecca.sacarescu@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-03',
    8,
    'Analiza cerinte',
    '{"workMode":"office","taskType":"validation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'rebecca.sacarescu@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-23',
    8,
    'Validare date',
    '{"workMode":"hybrid","taskType":"review","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'raluca.bocanet@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-25',
    8,
    'Configurare dashboard',
    '{"workMode":"remote","taskType":"optimization","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'raluca.bocanet@endava.com'
  AND t.week_start_date = DATE '2026-03-23';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-30',
    8,
    'Configurare dashboard',
    '{"workMode":"hybrid","taskType":"optimization","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'raluca.bocanet@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-03-31',
    8,
    'Analiza cerinte',
    '{"workMode":"remote","taskType":"meeting","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'CL001'
WHERE e.email = 'raluca.bocanet@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-01',
    8,
    'Implementare modul',
    '{"workMode":"office","taskType":"validation","billable":true}',
    1
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'BI001'
WHERE e.email = 'raluca.bocanet@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

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
SELECT
    t.timesheet_id,
    p.project_id,
    DATE '2026-04-03',
    8,
    'Testare functionalitati',
    '{"workMode":"hybrid","taskType":"analysis","billable":false}',
    0
FROM timesheets t
JOIN employees e
    ON e.employee_id = t.employee_id
JOIN projects p
    ON p.project_code = 'TS001'
WHERE e.email = 'raluca.bocanet@endava.com'
  AND t.week_start_date = DATE '2026-03-30';

COMMIT;

/* Facem un refresh la materialized view-ul MV_EMPLOYEE_TOTAL_HOURS.
*/
BEGIN
    DBMS_MVIEW.REFRESH('MV_EMPLOYEE_TOTAL_HOURS', 'C');
END;
/

/* E doar o verificarea manuala */
SELECT COUNT(*) AS department_count FROM departments;
SELECT COUNT(*) AS project_count FROM projects;
SELECT COUNT(*) AS employee_count FROM employees;
SELECT COUNT(*) AS timesheet_count FROM timesheets;
SELECT COUNT(*) AS entry_count FROM timesheet_entries;

SELECT
    e.first_name,
    e.last_name,
    t.week_start_date,
    t.status,
    te.entry_date,
    p.project_code,
    te.hours_worked,
    JSON_VALUE(te.entry_metadata_json, '$.workMode') AS work_mode  -- extragem modul de lucru din JSON
FROM employees e
JOIN timesheets t
    ON t.employee_id = e.employee_id
LEFT JOIN timesheet_entries te
    ON te.timesheet_id = t.timesheet_id
LEFT JOIN projects p
    ON p.project_id = te.project_id
ORDER BY
    e.last_name,
    e.first_name,
    t.week_start_date,
    te.entry_date;
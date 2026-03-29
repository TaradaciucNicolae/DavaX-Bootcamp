/* TARADACIUC NICOLAE


   Acest script construieste doua view-uri utile

   Primul view aduna intr-un singur loc toata activitatea unui angajat:
   - ce a lucrat in timesheet
   - ce absente are
   - la ce meeting-uri a participat

   Al doilea view rezuma aceasta informatie pe zile, astfel incat sa vezi mai usor:
   - cate ore a lucrat intr-o zi
   - cate ore de absenta are in acea zi
   - cate meeting-uri a avut
   - ce moduri de lucru apar in acea zi

   Ideea principala:
   in loc sa cauti separat in multe tabele, folosesti un view comun care
   unifica sursele de date si apoi un alt view care face sumarul pe zi.
*/

SET DEFINE OFF;

/* Acest view se numeste VW_EMPLOYEE_FULL_HISTORY.

   Fiecare rand din acest view reprezinta un eveniment
   din ce face angajatul.

   Evenimentul poate fi de trei tipuri:
   - TIMESHEET = o activitate normala de lucru, venita din pontaj
   - ABSENCE   = o absenta validata
   - MEETING   = un meeting din lista sanitizata

   Doua CTE-uri:
   - absences_resolved
   - meetings_resolved


*/
CREATE OR REPLACE VIEW vw_employee_full_history AS
WITH absences_resolved AS (
    SELECT
        NVL(a.employee_id, e.employee_id) AS resolved_employee_id,
        a.employee_email_clean,
        a.employee_name_clean,
        a.absence_date AS event_date,
        a.week_start_date,
        a.absence_code_clean,
        a.absence_hours,
        a.reason_text_clean
    FROM absences_sanitized a
    LEFT JOIN employees e
        ON LOWER(TRIM(e.email)) = LOWER(TRIM(a.employee_email_clean))
),
meetings_resolved AS (
    SELECT
        NVL(m.employee_id, e.employee_id) AS resolved_employee_id,
        m.attendee_email_clean,
        m.attendee_name_clean,
        m.meeting_date AS event_date,
        m.meeting_start_date,
        m.meeting_end_date,
        m.meeting_subject_clean,
        m.organizer_clean,
        m.subject_category,
        m.participant_scope
    FROM meetings_sanitized m
    LEFT JOIN employees e
        ON LOWER(TRIM(e.email)) = LOWER(TRIM(m.attendee_email_clean))
)

/*  Aici luam informatia din:
   - employees
   - departments
   - timesheets
   - timesheet_entries
   - projects

   Pe scurt:
   pentru fiecare linie de pontaj salvam cine este angajatul, pe ce proiect
   a lucrat, in ce zi, cate ore a lucrat si ce tip de activitate are.

   event_sort = 1 inseamna ca acest tip de eveniment va aparea primul
   atunci cand ordonam istoricul pe zi.
*/
SELECT
    e.employee_id,
    e.first_name || ' ' || e.last_name AS full_name,
    e.email,
    d.department_name,
    te.entry_date AS event_date,
    1 AS event_sort,
    'TIMESHEET' AS event_source,
    p.project_code,
    p.project_name,
    te.task_description AS event_title,
    JSON_VALUE(te.entry_metadata_json, '$.taskType') AS event_type_detail,
    te.hours_worked AS hours_value,
    JSON_VALUE(te.entry_metadata_json, '$.workMode') AS work_mode,
    t.status AS timesheet_status,
    te.is_billable,
    CAST(NULL AS VARCHAR2(20)) AS absence_code,
    CAST(NULL AS VARCHAR2(200)) AS absence_reason,
    CAST(NULL AS VARCHAR2(300)) AS meeting_subject,
    CAST(NULL AS VARCHAR2(200)) AS organizer_name,
    CAST(NULL AS VARCHAR2(30)) AS participant_scope,
    CAST(NULL AS VARCHAR2(30)) AS subject_category
FROM employees e
JOIN departments d
    ON d.department_id = e.department_id
JOIN timesheets t
    ON t.employee_id = e.employee_id
JOIN timesheet_entries te
    ON te.timesheet_id = t.timesheet_id
JOIN projects p
    ON p.project_id = te.project_id

UNION ALL

/* Aici aducem absentele.

   Pentru absente, nu avem proiect sau task de lucru normal,
   asa ca acele coloane raman NULL.

   In schimb, completam:
   - event_source = ABSENCE
   - absence_code
   - absence_reason
   - hours_value = numarul de ore ale absentei

   work_mode este pus aici ca OUT_OF_OFFICE pentru ca absenta inseamna
   ca angajatul nu este in modul normal de lucru.
*/
SELECT
    e.employee_id,
    e.first_name || ' ' || e.last_name AS full_name,
    e.email,
    d.department_name,
    a.event_date,
    2 AS event_sort,
    'ABSENCE' AS event_source,
    CAST(NULL AS VARCHAR2(20)) AS project_code,
    CAST(NULL AS VARCHAR2(100)) AS project_name,
    NVL(a.reason_text_clean, a.absence_code_clean) AS event_title,
    a.absence_code_clean AS event_type_detail,
    a.absence_hours AS hours_value,
    'OUT_OF_OFFICE' AS work_mode,
    CAST(NULL AS VARCHAR2(20)) AS timesheet_status,
    CAST(NULL AS NUMBER(1)) AS is_billable,
    a.absence_code_clean AS absence_code,
    a.reason_text_clean AS absence_reason,
    CAST(NULL AS VARCHAR2(300)) AS meeting_subject,
    CAST(NULL AS VARCHAR2(200)) AS organizer_name,
    CAST(NULL AS VARCHAR2(30)) AS participant_scope,
    CAST(NULL AS VARCHAR2(30)) AS subject_category
FROM absences_resolved a
JOIN employees e
    ON e.employee_id = a.resolved_employee_id
JOIN departments d
    ON d.department_id = e.department_id

UNION ALL

/* Aici aducem meeting-urile.

   Cmpletam cu:
   - event_source = MEETING
   - event_title = subiectul meeting-ului
   - subject_category = categoria derivata din subiect
   - organizer_name = cine a organizat meeting-ul
*/
SELECT
    e.employee_id,
    e.first_name || ' ' || e.last_name AS full_name,
    e.email,
    d.department_name,
    m.event_date,
    3 AS event_sort,
    'MEETING' AS event_source,
    CAST(NULL AS VARCHAR2(20)) AS project_code,
    CAST(NULL AS VARCHAR2(100)) AS project_name,
    m.meeting_subject_clean AS event_title,
    m.subject_category AS event_type_detail,
    CAST(NULL AS NUMBER(5,2)) AS hours_value,
    CAST(NULL AS VARCHAR2(30)) AS work_mode,
    CAST(NULL AS VARCHAR2(20)) AS timesheet_status,
    CAST(NULL AS NUMBER(1)) AS is_billable,
    CAST(NULL AS VARCHAR2(20)) AS absence_code,
    CAST(NULL AS VARCHAR2(200)) AS absence_reason,
    m.meeting_subject_clean AS meeting_subject,
    m.organizer_clean AS organizer_name,
    m.participant_scope,
    m.subject_category
FROM meetings_resolved m
JOIN employees e
    ON e.employee_id = m.resolved_employee_id
JOIN departments d
    ON d.department_id = e.department_id;

/* Acest al doilea view se numeste VW_EMPLOYEE_DAILY_SUMMARY.

   El foloseste view-ul anterior si il transforma intr-un sumar pe zi.

	Adica:
   - grupeaza datele dupa angajat si data
   - aduna orele lucrate din evenimentele de tip TIMESHEET
   - aduna orele de absenta din evenimentele de tip ABSENCE
   - numara cate meeting-uri sunt in acea zi
   - concateneaza modurile de lucru gasite in acea zi


*/
CREATE OR REPLACE VIEW vw_employee_daily_summary AS
SELECT
    employee_id,
    full_name,
    email,
    department_name,
    event_date,
    SUM(CASE WHEN event_source = 'TIMESHEET' THEN NVL(hours_value, 0) ELSE 0 END) AS worked_hours,
    SUM(CASE WHEN event_source = 'ABSENCE' THEN NVL(hours_value, 0) ELSE 0 END) AS absence_hours,
    COUNT(CASE WHEN event_source = 'MEETING' THEN 1 END) AS meeting_count,
    LISTAGG(DISTINCT work_mode, ', ')
        WITHIN GROUP (ORDER BY work_mode) AS work_modes_seen
FROM vw_employee_full_history
GROUP BY
    employee_id,
    full_name,
    email,
    department_name,
    event_date;

/* Interogari de test
*/
SELECT
    event_date,
    event_source,
    event_title,
    event_type_detail,
    hours_value,
    work_mode,
    project_code,
    project_name,
    timesheet_status,
    absence_code,
    absence_reason,
    meeting_subject,
    organizer_name
FROM vw_employee_full_history
WHERE LOWER(full_name) = LOWER('Nicolae Taradaciuc')
ORDER BY
    event_date,
    event_sort,
    event_title;

/* test
*/
SELECT
    event_date,
    event_source,
    event_title,
    event_type_detail,
    hours_value,
    work_mode,
    project_code,
    project_name,
    timesheet_status,
    absence_code,
    absence_reason,
    meeting_subject,
    organizer_name
FROM vw_employee_full_history
WHERE LOWER(email) = LOWER('nicolae.taradaciuc@endava.com')
ORDER BY
    event_date,
    event_sort,
    event_title;

/* test
*/
SELECT *
FROM vw_employee_daily_summary
WHERE LOWER(full_name) = LOWER('Nicolae Taradaciuc')
ORDER BY event_date;

SET DEFINE ON;

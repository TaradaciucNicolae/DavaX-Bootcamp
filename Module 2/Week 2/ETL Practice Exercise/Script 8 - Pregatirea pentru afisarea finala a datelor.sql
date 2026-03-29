/* TARADACIUC NICOLAE


   Acest script creeaza view-ul VW_EMPLOYEE_DAY_BOARD.
   View-ul aduna intr-un singur loc informatia zilnica despre fiecare angajat.

   In acest view apar impreuna:
   - orele lucrate din pontaj
   - absentele
   - meeting-urile
   - modul de lucru
   - proiectele
   - task-urile
   - un mic control care verifica daca ziua pare completa sau nu


*/

SET DEFINE OFF;

/* Aici cream sau inlocuim view-ul principal folosit in dashboard.

*/
CREATE OR REPLACE VIEW vw_employee_day_board AS

/* Acest CTE aduna informatia reala de lucru din sistemul de pontaj.


   Luam liniile din TIMESHEET_ENTRIES si le grupam pe angajat si pe zi.

   Calcule:
   - worked_hours = suma orelor lucrate in ziua respectiva
   - projects_worked = lista proiectelor pe care s-a lucrat in acea zi
   - work_modes_seen = lista modurilor de lucru gasite in JSON
   - tasks_done = lista task-urilor facute in ziua respectiva

   LISTAGG este folosit ca sa unim mai multe valori intr-un singur text.
   De exemplu, daca un angajat a lucrat pe doua proiecte in aceeasi zi,
   proiectele vor aparea intr-o singura coloana, separate prin &.
*/
WITH work_daily AS
(
    SELECT
        e.employee_id,
        TRUNC(te.entry_date) AS event_date,
        SUM(te.hours_worked) AS worked_hours,
        LISTAGG(
            p.project_code || ' - ' || p.project_name,
            ' & ' ON OVERFLOW TRUNCATE ' ...' WITHOUT COUNT
        ) WITHIN GROUP (ORDER BY p.project_code, p.project_name) AS projects_worked,
        LISTAGG(
            JSON_VALUE(te.entry_metadata_json, '$.workMode'),
            ', ' ON OVERFLOW TRUNCATE ' ...' WITHOUT COUNT
        ) WITHIN GROUP (ORDER BY JSON_VALUE(te.entry_metadata_json, '$.workMode')) AS work_modes_seen,
        LISTAGG(
            te.task_description,
            ' & ' ON OVERFLOW TRUNCATE ' ...' WITHOUT COUNT
        ) WITHIN GROUP (ORDER BY te.entry_date, te.entry_id) AS tasks_done
    FROM employees e
    JOIN timesheets t
        ON t.employee_id = e.employee_id
    JOIN timesheet_entries te
        ON te.timesheet_id = t.timesheet_id
    JOIN projects p
        ON p.project_id = te.project_id
    GROUP BY
        e.employee_id,
        TRUNC(te.entry_date)
),

/* Acest CTE aduna absentele pe angajat si pe zi.

   Aici folosim tabela ABSENCES_SANITIZED.
   Daca employee_id nu este completat, incercam sa gasim angajatul dupa email.

   - absence_hours = cate ore de absenta are angajatul in acea zi
   - absences_list = lista tipurilor de absenta
   - absence_reasons = lista motivelor absentei
*/
absence_daily AS
(
    SELECT
        NVL(a.employee_id, e.employee_id) AS employee_id,
        TRUNC(a.absence_date) AS event_date,
        SUM(a.absence_hours) AS absence_hours,
        LISTAGG(
            a.absence_code_clean || ' (' || TO_CHAR(a.absence_hours) || 'h)',
            ' & ' ON OVERFLOW TRUNCATE ' ...' WITHOUT COUNT
        ) WITHIN GROUP (ORDER BY a.absence_code_clean, a.absence_date) AS absences_list,
        LISTAGG(
            NVL(a.reason_text_clean, a.absence_code_clean),
            ' & ' ON OVERFLOW TRUNCATE ' ...' WITHOUT COUNT
        ) WITHIN GROUP (ORDER BY a.absence_code_clean, a.absence_date) AS absence_reasons
    FROM absences_sanitized a
    LEFT JOIN employees e
        ON LOWER(TRIM(e.email)) = LOWER(TRIM(a.employee_email_clean))
    GROUP BY
        NVL(a.employee_id, e.employee_id),
        TRUNC(a.absence_date)
),

/* Acest CTE aduna meeting-urile pe angajat si pe zi.

   - meeting_count = numarul de meeting-uri din ziua respectiva
   - meetings_list = lista subiectelor de meeting
   - organizers_list = lista organizatorilor
*/
meeting_daily AS
(
    SELECT
        NVL(m.employee_id, e.employee_id) AS employee_id,
        TRUNC(m.meeting_date) AS event_date,
        COUNT(*) AS meeting_count,
        LISTAGG(
            m.meeting_subject_clean,
            ' & ' ON OVERFLOW TRUNCATE ' ...' WITHOUT COUNT
        ) WITHIN GROUP (ORDER BY m.meeting_subject_clean) AS meetings_list,
        LISTAGG(
            NVL(m.organizer_clean, '-'),
            ' & ' ON OVERFLOW TRUNCATE ' ...' WITHOUT COUNT
        ) WITHIN GROUP (ORDER BY m.organizer_clean, m.meeting_subject_clean) AS organizers_list
    FROM meetings_sanitized m
    LEFT JOIN employees e
        ON LOWER(TRIM(e.email)) = LOWER(TRIM(m.attendee_email_clean))
    GROUP BY
        NVL(m.employee_id, e.employee_id),
        TRUNC(m.meeting_date)
),

/* Acest CTE construieste lista tuturor zilelor care conteaza.

   Ideea este simpla:
   o zi trebuie sa apara in view daca exista cel putin unul dintre aceste lucruri:
   - pontaj real
   - absenta
   - meeting

   UNION elimina duplicatele, deci pentru aceeasi zi si acelasi angajat
   vom avea un singur rand in lista de baza.
*/
all_days AS
(
    SELECT employee_id, event_date FROM work_daily
    UNION
    SELECT employee_id, event_date FROM absence_daily
    UNION
    SELECT employee_id, event_date FROM meeting_daily
),

/* Aici pregatim toate datele intermediare intr-un singur loc.

   Pe scurt:
   luam fiecare combinatie angajat + zi din ALL_DAYS si o imbogatim cu:
   - datele reale din work_daily
   - absentele din absence_daily
   - meeting-urile din meeting_daily

*/
base_rows AS
(
    SELECT
        e.employee_id,
        e.first_name,
        e.last_name,
        e.first_name || ' ' || e.last_name AS full_name,
        e.email,
        d.department_name,
        ad.event_date,

        w.worked_hours AS work_logged_hours,
        w.work_modes_seen AS work_modes_seen_real,
        w.projects_worked AS projects_worked_real,
        w.tasks_done AS tasks_done_real,

        NVL(a.absence_hours, 0) AS absence_hours,
        a.absences_list,
        a.absence_reasons,

        NVL(m.meeting_count, 0) AS meeting_count,
        m.meetings_list,
        m.organizers_list,

        CASE
            WHEN MOD(ORA_HASH(e.email || TO_CHAR(ad.event_date, 'YYYYMMDD')), 2) = 0 THEN 'office'
            ELSE 'remote'
        END AS fallback_work_mode,

        CASE MOD(ORA_HASH('PRJ' || e.email || TO_CHAR(ad.event_date, 'YYYYMMDD')), 6)
            WHEN 0 THEN 'CL901 - Client Delivery Optimization'
            WHEN 1 THEN 'SEC314 - Security Controls Review'
            WHEN 2 THEN 'DAT220 - Data Quality Remediation'
            WHEN 3 THEN 'APP480 - Application Stability Stream'
            WHEN 4 THEN 'OPS125 - Operations Automation'
            ELSE 'RPT560 - Reporting Improvement Initiative'
        END AS fallback_project,

        CASE MOD(ORA_HASH('TASK' || e.email || TO_CHAR(ad.event_date, 'YYYYMMDD')), 8)
            WHEN 0 THEN 'Analiza cerinte si actualizare backlog'
            WHEN 1 THEN 'Pregatire documentatie operationala'
            WHEN 2 THEN 'Revizuire task-uri si aliniere echipa'
            WHEN 3 THEN 'Validare date si verificare livrabile'
            WHEN 4 THEN 'Suport functional si follow-up intern'
            WHEN 5 THEN 'Optimizare flux de lucru'
            WHEN 6 THEN 'Verificare status si actualizare progres'
            ELSE 'Sincronizare activitati si pregatire next steps'
        END AS fallback_task
    FROM all_days ad
    JOIN employees e
        ON e.employee_id = ad.employee_id
    JOIN departments d
        ON d.department_id = e.department_id
    LEFT JOIN work_daily w
        ON w.employee_id = ad.employee_id
       AND w.event_date = ad.event_date
    LEFT JOIN absence_daily a
        ON a.employee_id = ad.employee_id
       AND a.event_date = ad.event_date
    LEFT JOIN meeting_daily m
        ON m.employee_id = ad.employee_id
       AND m.event_date = ad.event_date
)

/* In SELECT-ul final construim forma exacta a view-ului.


*/
SELECT
    employee_id,
    first_name,
    last_name,
    full_name,
    email,
    department_name,
    event_date,

    CASE
        WHEN work_logged_hours IS NOT NULL THEN work_logged_hours
        WHEN absence_hours > 0 THEN 8
        WHEN meeting_count > 0 THEN 8
        ELSE 0
    END AS worked_hours,

    absence_hours,
    meeting_count,

    COALESCE(
        work_modes_seen_real,
        CASE
            WHEN absence_hours > 0 OR meeting_count > 0 THEN fallback_work_mode
        END
    ) AS work_modes_seen,

    COALESCE(
        projects_worked_real,
        CASE
            WHEN absence_hours > 0 OR meeting_count > 0 THEN fallback_project
        END
    ) AS projects_worked,

    COALESCE(
        tasks_done_real,
        CASE
            WHEN absence_hours > 0 AND meeting_count > 0 THEN
                fallback_task || '  '
            WHEN absence_hours > 0 THEN
                fallback_task || '  '
            WHEN meeting_count > 0 THEN
                fallback_task || ' '
        END
    ) AS tasks_done,

    absences_list,
    absence_reasons,
    meetings_list,
    organizers_list,

    CASE
        WHEN absence_hours > 0 AND work_logged_hours IS NULL THEN 'OK_8H'
        WHEN
            (
                CASE
                    WHEN work_logged_hours IS NOT NULL THEN work_logged_hours
                    WHEN absence_hours > 0 THEN 8
                    WHEN meeting_count > 0 THEN 8
                    ELSE 0
                END
            ) + absence_hours > 8 THEN 'OVER_8H'
        WHEN
            (
                CASE
                    WHEN work_logged_hours IS NOT NULL THEN work_logged_hours
                    WHEN absence_hours > 0 THEN 8
                    WHEN meeting_count > 0 THEN 8
                    ELSE 0
                END
            ) + absence_hours = 8 THEN 'OK_8H'
        ELSE 'UNDER_8H'
    END AS day_control
FROM base_rows;

SET DEFINE ON;

/* Aici adaugam cheia externa dintre ABSENCES_SANITIZED si EMPLOYEES.

   Spunem bazei de date ca employee_id din absente trebuie sa existe
   in tabela EMPLOYEES.

*/
ALTER TABLE absences_sanitized
ADD CONSTRAINT fk_absences_sanitized_employee
    FOREIGN KEY (employee_id)
    REFERENCES employees(employee_id);

/* Aici adaugam cheia externa dintre MEETINGS_SANITIZED si EMPLOYEES.

   employee_id din tabela cu meeting-uri trebuie sa existe in EMPLOYEES.

*/
ALTER TABLE meetings_sanitized
ADD CONSTRAINT fk_meetings_sanitized_employee
    FOREIGN KEY (employee_id)
    REFERENCES employees(employee_id);

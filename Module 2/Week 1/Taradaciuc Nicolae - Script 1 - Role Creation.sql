/* TARADACIUC NICOLAE
    
   TEMA: Sistem de pontare (Timesheets) - Oracle Database

    Script 1
*/

/*
It needs to be run first, using an admin / DBA account and it has the purpose of 
creating the two roles used in the security part of the project
*/

/*
This role is meant for the operational side of the application. It is intended for users or 
applications that work directly with timesheet data.
*/
BEGIN
    EXECUTE IMMEDIATE 'CREATE ROLE role_timesheet_app';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -1921 THEN
            RAISE;
        END IF;
END;
/

/*
This role is meant for the reporting side of the application. It is intended for users who 
only need to read prepared reporting data, not modify base data.
*/
BEGIN
    EXECUTE IMMEDIATE 'CREATE ROLE role_timesheet_report';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -1921 THEN
            RAISE;
        END IF;
END;
/
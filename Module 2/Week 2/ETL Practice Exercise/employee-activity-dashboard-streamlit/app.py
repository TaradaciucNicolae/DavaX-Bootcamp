"""
TARADACIUC NICOLAE   ->  Sistem de pontare (Timesheets) - Oracle Database

"""



import os
from datetime import date, datetime, timedelta

import oracledb
import pandas as pd
import streamlit as st
from dotenv import load_dotenv

# Incarcam variabilele din fisierul .env.
# Acolo sunt pastrate informatii sensibile sau configurabile,
# cum ar fi userul Oracle, parola si connection string-ul.
load_dotenv()

# Aici configuram pagina Streamlit.
st.set_page_config(
    page_title="Employee Activity Dashboard",
    layout="wide",
)

# Aceasta functie deschide conexiunea la baza de date Oracle.
@st.cache_resource
def get_connection():
    return oracledb.connect(
        user=os.getenv("ORACLE_USER"),
        password=os.getenv("ORACLE_PASSWORD"),
        dsn=os.getenv("ORACLE_CONNECTION_STRING"),
        mode=oracledb.AuthMode.SYSDBA
    )


# Aceasta functie citeste lista de angajati din tabela EMPLOYEES.
@st.cache_data(ttl=60)
def fetch_employees():
    sql = """
        SELECT
            employee_id,
            first_name || ' ' || last_name AS full_name,
            email,
            employment_status
        FROM employees
        ORDER BY LOWER(last_name), LOWER(first_name)
    """
    conn = get_connection()
    df = pd.read_sql(sql, con=conn)
    
    # Transformam numele coloanelor in lowercase ca sa fie mai usor de folosit in Python.
    # De exemplu FULL_NAME devine full_name.
    df.columns = [str(col).lower() for col in df.columns]
    return df


# Aceasta functie citeste activitatea pentru un singur angajat,
# intr-un interval de date ales.
@st.cache_data(ttl=60)
def fetch_activity(employee_id: int, start_date: date, end_date: date):
    sql = """
        SELECT
            employee_id,
            full_name,
            email,
            department_name,
            event_date,
            worked_hours,
            absence_hours,
            meeting_count,
            NVL(work_modes_seen, '-') AS work_modes_seen,
            NVL(projects_worked, '-') AS projects_worked,
            NVL(tasks_done, '-') AS tasks_done,
            NVL(absences_list, '-') AS absences_list,
            NVL(absence_reasons, '-') AS absence_reasons,
            NVL(meetings_list, '-') AS meetings_list,
            NVL(organizers_list, '-') AS organizers_list,
            day_control
        FROM vw_employee_day_board
        WHERE employee_id = :employee_id
          AND event_date BETWEEN :start_date AND :end_date
        ORDER BY event_date
    """
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        sql,
        employee_id=employee_id,
        start_date=start_date,
        end_date=end_date,
    )
    columns = [col[0].lower() for col in cursor.description]
    rows = cursor.fetchall()
    return pd.DataFrame(rows, columns=columns)


# Aceasta functie intoarce ziua de luni pentru data primita.
def get_monday(d: date) -> date:
    return d - timedelta(days=d.weekday())
    
    
# Aceasta functie construieste lista saptamanilor pentru o luna data.
def get_weeks_for_month(year: int, month: int):
    first_day = date(year, month, 1)
    if month == 12:
        last_day = date(year + 1, 1, 1) - timedelta(days=1)
    else:
        last_day = date(year, month + 1, 1) - timedelta(days=1)

    cursor = get_monday(first_day)
    weeks = []
    count = 1

    while cursor <= last_day:
        start = cursor
        end = cursor + timedelta(days=6)
        label = f"Săptămâna {start.strftime('%d.%m')} - {end.strftime('%d.%m')}"
        weeks.append((label, start, end))
        cursor = cursor + timedelta(days=7)
        count += 1

    return weeks

# Aceasta functie calculeaza suma unei coloane numerice din DataFrame.
def metric_value(df: pd.DataFrame, column: str):
    if df.empty:
        return 0
    return float(df[column].fillna(0).sum())

# Titlul principal afisat in pagina.
st.title("Istoric activitate angajat")

# Un text scurt explicativ sub titlu.
st.caption("Alege angajatul, luna și săptămâna, apoi vezi activitatea lui pe zile, direct din Oracle.")


# Verificam daca exista toate variabilele obligatorii in .env.
missing_env = [
    key for key in ["ORACLE_USER", "ORACLE_PASSWORD", "ORACLE_CONNECTION_STRING"]
    if not os.getenv(key)
]

if missing_env:
    st.error(
        "Lipsesc variabilele din .env: " + ", ".join(missing_env)
    )
    st.stop()

# Incercam sa luam lista de angajati.
try:
    employees = fetch_employees()
except Exception as exc:
    st.error(f"Nu m-am putut conecta la Oracle sau nu pot citi EMPLOYEES: {exc}")
    st.stop()


# Daca tabela EMPLOYEES nu are date, afisam un mesaj
if employees.empty:
    st.warning("Nu există angajați în tabelul EMPLOYEES.")
    st.stop()

today = date.today()
default_month = date(today.year, today.month, 1)

col1, col2, col3 = st.columns([2, 1, 2])


# In prima coloana punem lista de angajati.
with col1:
    employee_label = st.selectbox(
        "Angajat",
        options=employees["full_name"].tolist(),
        index=min(0, len(employees) - 1),
    )

# Aici luam randul complet al angajatului selectat.
selected_employee = employees.loc[employees["full_name"] == employee_label].iloc[0]


# In a doua coloana alegem luna.
with col2:
    month_selected = st.date_input(
        "Luna",
        value=default_month,
        format="YYYY-MM-DD",
    )
    month_anchor = date(month_selected.year, month_selected.month, 1)

# Generam lista saptamanilor pentru luna aleasa.
weeks = get_weeks_for_month(month_anchor.year, month_anchor.month)


# In a treia coloana afisam dropdown-ul cu saptamanile disponibile.
with col3:
    week_label = st.selectbox(
        "Săptămână",
        options=[w[0] for w in weeks],
        index=0,
    )

# Din lista de saptamani luam exact saptamana selectata.
selected_week = next(w for w in weeks if w[0] == week_label)
start_date, end_date = selected_week[1], selected_week[2]

# Afisam utilizatorului ce interval este vizualizat.
st.info(
    f"Afisare date pentru **{selected_employee['full_name']}** in intervalul "
    f"**{start_date.strftime('%d.%m.%Y')} - {end_date.strftime('%d.%m.%Y')}**."
)


# Acum citim efectiv activitatea angajatului pentru intervalul ales.
try:
    df = fetch_activity(
        int(selected_employee["employee_id"]),
        start_date,
        end_date,
    )
except Exception as exc:
    st.error(f"Nu am putut citi view-ul VW_EMPLOYEE_DAY_BOARD: {exc}")
    st.stop()


# Aici afisam totaluri pe perioada selectata.
m1, m2, m3, m4 = st.columns(4)
m1.metric("Ore lucrate", f"{metric_value(df, 'worked_hours'):.1f}")
m2.metric("Ore absență", f"{metric_value(df, 'absence_hours'):.1f}")
m3.metric("Meeting-uri", int(metric_value(df, 'meeting_count')))
#m4.metric("Zile afișate", len(df))

if df.empty:
    st.warning("Nu există date pentru selecția curentă.")
    st.stop()

# Facem o copie a DataFrame-ului pentru partea de afisare.
display_df = df.copy()
display_df["event_date"] = pd.to_datetime(display_df["event_date"]).dt.strftime("%d.%m.%Y")


# Redenumim coloanele
display_df = display_df.rename(
    columns={
        "event_date": "Zi",
        "worked_hours": "Ore lucrate",
        "absence_hours": "Ore absență",
        "meeting_count": "Meeting-uri",
        "work_modes_seen": "Mod lucru",
        "projects_worked": "Proiecte",
        "tasks_done": "Task-uri",
        "absences_list": "Absențe",
        "absence_reasons": "Motive absență",
        "meetings_list": "Meeting-uri în zi",
        "organizers_list": "Organizatori",
        "day_control": "Control zi",
        "department_name": "Departament",
    }
)

# Alegem explicit ordinea coloanelor pe care vrem sa le afisam in tabel.
wanted_cols = [
    "Zi",
    "Ore lucrate",
    "Ore absență",
    "Meeting-uri",
    "Mod lucru",
    "Proiecte",
    "Task-uri",
    "Absențe",
    "Motive absență",
    "Meeting-uri în zi",
    "Organizatori",
    "Control zi",
]

# Un subtitlu pentru zona tabelului principal.
st.subheader("Activitate pe zile")

# Afisam tabelul principal.
st.dataframe(
    display_df[wanted_cols],
    use_container_width=True,
    hide_index=True,
)


# Acest expander este o zona care poate fi deschisa la cerere.
# Daca utilizatorul vrea sa vada si datele brute, le poate deschide aici.
with st.expander("Vezi și datele brute"):
    st.dataframe(display_df, use_container_width=True, hide_index=True)

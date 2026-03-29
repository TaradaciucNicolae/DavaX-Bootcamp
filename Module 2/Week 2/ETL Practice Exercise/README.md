## Important

De menționat că datele utilizate în acest proiect nu sunt în totalitate reale.

Singura sursă de date reale este partea de **meeting-uri**, deoarece acestea au fost extrase direct din **Outlook**.

Toate celelalte date utilizate în proiect, inclusiv majoritatea informațiilor legate de **timesheet-uri, angajați, absențe și proiecte**, sunt **date mock/demo**, create doar pentru testare, validare și prezentare.

De asemenea, fiind o versiune demo a aplicației, baza de date a fost populată doar pentru următoarele două săptămâni:

- **23.03.2026 - 29.03.2026**
- **30.03.2026 - 05.04.2026**


# Ghid de instalare, rulare si pornire a proiectului

Acest proiect construieste un sistem de pontaj si raportare a activitatii angajatilor in Oracle Database si il expune apoi intr-o interfata web simpla, construita in Streamlit.

Proiectul lucreaza cu trei surse principale de informatie:
- pontajul intern din sistemul de timesheet
- absentele venite din Excel(mock data)
- meeting-urile extrase din Outlook

## Ce contine proiectul

Structura logica a proiectului este aceasta:

- **Script 1** creeaza rolurile aplicatiei (Reutilizat din tema "Timesheet")
- **Script 2** creeaza schema principala a sistemului de pontaj (Reutilizat din tema "Timesheet", cu mici modificari)
- **Script 3** populeaza datele interne de baza: departamente, proiecte, angajati, timesheets si timesheet_entries
- **Script 4** construieste zona target/staging pentru un flux mai strict de import al absentelor
- **Script 5** sanitizeaza si valideaza absentele brute si produce `ABSENCES_SANITIZED`
- **Script 5.5** extrage participantii care au acceptat meeting-uri din Outlook intr-un CSV
- **Script 6** sanitizeaza meeting-urile brute si produce `MEETINGS_SANITIZED`
- **Script 7** construieste view-urile de istoric complet si sumar zilnic
- **Script 8** construieste view-ul final folosit de dashboard: `VW_EMPLOYEE_DAY_BOARD`
- **app.py** este aplicatia web Streamlit



## Ordinea de rulare


### 1. Ruleaza Scripturile 1,2,3,4,5 in baza de date


### 2. Rulezi Script 5.5 - Extragere meetinguri Outlook.otm

```
Pasi rulare

1.Deschide Microsoft Outlook
  Aceasta solutie functioneaza in **Classic Outlook**, unde VBA este suportat.

2.Intra in editorul VBA
  Apasa: Alt + F11
  Se va deschide **Microsoft Visual Basic for Applications**.

3.Creeaza un modul nou
  In editorul VBA:  - apasa Insert
                  - selecteaza Module

4.Copiaza codul macro in modulul nou
  In partea mare a ferestrei, lipeste tot codul din scriptul **Script 5.5 - Extragere meetinguri Outlook.otm**.

5.Verifica intervalul si locatia fisierului CSV
  In cod, verifica urmatoarele valori:
  - startDate = data de inceput a perioadei din care vrei sa extragi meeting-urile
  - endDate = data de final a perioadei
  - outFile = calea unde se va salva fisierul CSV rezultat

6.Ruleaza macro-ul
  Apasa: F5
  Macro-ul va incepe sa ruleze si va parcurge meeting-urile din calendarul Outlook din intervalul ales, iar la final, Outlook va afisa un mesaj de confirmare de tipul:  Gata: C:\...\accepted_invitees.csv
```


## 3. Ruleaza Script 6,7,8


## 4. Configurare aplicatie web
```
Fisier: app.py

Aplicatia este scrisa in Streamlit si citeste:
  - lista de angajati din `EMPLOYEES`
  - activitatea zilnica din `VW_EMPLOYEE_DAY_BOARD`

Creeaza un mediu virtual:
  - In terminal, din folderul proiectului: (powershell)  python -m venv .venv

Activeaza mediul: (powershell)  .venv\Scripts\Activate.ps1

Instaleaza pachetele necesare: (powershell)  pip install -r requirements.txt

Porneste aplicatia: (powershell)  python -m streamlit run app.py

Deschide in browser: http://localhost:8501
```


### Dashboard:

<img width="1918" height="933" alt="Dashboard" src="https://github.com/user-attachments/assets/4baf1048-fa44-4707-b53b-8ff71663908b" />




### Star Schema / Data Model Diagram: 

<img width="1142" height="689" alt="Diagram" src="https://github.com/user-attachments/assets/950b1b43-4a9b-47a4-b3c5-63bee73e373a" />


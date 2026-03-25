
# Observatii

## Observatie privind implementarea

Am ales ca mesajele de tip `WARN` si `ERROR` sa poata fi salvate in log chiar si atunci cand modul de debug este dezactivat. Desi cerinta de baza conditioneaza logarea de activarea debug mode-ului, aceasta adaptare a fost facuta intentionat din motive de securitate si diagnosticare. In opinia mea, in practica, avertismentele si erorile reprezinta evenimente importante, care trebuie pastrate pentru analiza incidentelor chiar si in afara sesiunilor de debug.

De asemenea, testele si procedurile nu au fost testate direct pe tabelul real `HR.EMPLOYEES`, ci pe o copie de test (`EMPLOYEES_COPY_FOR_TESTING`). Am ales aceasta abordare deoarece un prototip nu trebuie testat pe date reale, pentru a evita modificarea accidentala a informatiilor din sistemul original.

## Observatie privind partea de testare

Pe langa implementarea cerintelor propriu-zise, in ultima parte a scriptului am inclus doua teste demonstrative. Acestea au rolul de a evidentia functionalitatea scriptului si de a valida, in mod practic, faptul ca cerintele din tema au fost implementate corect.

## Observatie suplimentara

Am adaugat si partea de `mask if sensitive`, desi aceasta nu era ceruta explicit. Am ales sa includ aceasta functionalitate din motive de securitate, pentru a preveni afisarea sau salvarea accidentala a informatiilor sensibile. In opinia mea, este o masura utila in practica si completeaza implementarea printr-o abordare mai sigura.
    



# Instalare schema `HR` in Oracle + Adaugarea user-ului HR



## Creare structura locala foldere

In PowerShell, din folderul proiectului:

```powershell
New-Item -ItemType Directory -Force -Path .\init | Out-Null
New-Item -ItemType Directory -Force -Path .\sample-schemas | Out-Null
```

---

## Descarcare sample schemas oficiale de la Oracle


```powershell
Invoke-WebRequest `
  -Uri "https://github.com/oracle-samples/db-sample-schemas/archive/refs/heads/main.zip" `
  -OutFile ".\db-sample-schemas.zip"

if (Test-Path .\db-sample-schemas-main) {
    Remove-Item .\db-sample-schemas-main -Recurse -Force
}

Expand-Archive -Path .\db-sample-schemas.zip -DestinationPath .

if (Test-Path .\sample-schemas\human_resources) {
    Remove-Item .\sample-schemas\human_resources -Recurse -Force
}

Copy-Item -Recurse .\db-sample-schemas-main\human_resources .\sample-schemas\

Remove-Item .\db-sample-schemas.zip -Force
Remove-Item .\db-sample-schemas-main -Recurse -Force
```

Verificare ca fisierele exista:

```powershell
Get-ChildItem .\sample-schemas\human_resources
```


## Pornim containerul Oracle

```powershell
docker compose up -d
```

---

## Verificare ca fisierele `HR` sunt montate in container

```powershell
docker exec -it c-local-oracle_debug-framework bash
```

In container, ruleaza:

```bash
ls -la /opt/hr-schema
```


## Instalarea lor


Tot in container:

```bash
rm -rf /tmp/hr-install
mkdir -p /tmp/hr-install
cp /opt/hr-schema/*.sql /tmp/hr-install/
cd /tmp/hr-install
sqlplus system/"Oraclepass123!"@//localhost:1521/FREEPDB1
```

Acum suntem in SQL*Plus si vom rula:

```sql
@hr_install.sql
HRpass123!
USERS
YES
```

Apoi iesim:

```bash
exit
```

---

## Verificare conectare cu userul `HR`

Din PowerShell:

```powershell
docker exec -it c-local-oracle_debug-framework sqlplus "hr/HRpass123!@//localhost:1521/FREEPDB1"
```

Verificam:

```sql
SELECT COUNT(*) FROM employees;
SELECT COUNT(*) FROM departments;
SELECT COUNT(*) FROM jobs;
```


Apoi iesim:

```bash
exit
```
You did it !!!!

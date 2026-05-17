# Elektritarbimise_optimeerimine_kasvuhoones
Millistel tundidel on kasvuhoones kõige mõistlikum kasutada elektrit nõudvaid seadmeid, et börsihinnaga lepingu korral kulusid vähendada, arvestades ilmaolusid?
# Greenhouse Energy Optimization

## Projekti eesmärk

Selle projekti eesmärk on analüüsida, millal tasub kasvuhoones kasutada elektrit nõudvaid seadmeid (küte, valgustus, ventilatsioon), et vähendada elektrikulusid börsihinnaga elektrilepingu korral.

Projekt kasutab elektri börsihindu ja ilmaandmeid, et leida soodsaimad ajad elektri tarbimiseks.

## Äriküsimus

Millal on kõige soodsam kasutada kasvuhoones:
- kütet
- lisavalgustust
- ventilatsiooni

arvestades:
- elektri börsihinda
- välistemperatuuri
- päikesekiirgust

## Andmeallikad

### Elektrihinnad
- Elering API

### Ilmaandmed
- Ilmateenistuse API

## Tehnoloogiad

- Python
- PostgreSQL / Supabase
- SQL
- cron
- GitHub
- Metabase / Power BI

## Planeeritud töövoog

1. Python script küsib API-dest andmed
2. Andmed salvestatakse PostgreSQL andmebaasi
3. SQL päringud valmistavad andmed analüüsiks ette
4. Dashboard kuvab soovitused ja hinnainfo
5. cron käivitab andmete uuendamise automaatselt

## Projekti struktuur

```text
docs/           dokumentatsioon
scripts/        Python scriptid
sql/            SQL päringud
dashboard/      visualiseeringud

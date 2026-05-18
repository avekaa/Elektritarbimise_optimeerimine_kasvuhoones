
# Progress (nädal 2)

## Valmis
- Näidisprojekti struktuur kopeeritud ja käima pandud.
- Docker teenused (`db`, `pipeline`, `scheduler`, `dashboard`) töötavad.
- A-osa seadistused tehtud: `.env`, cron, API muutujaid edasi andev scheduler.
- Vähemalt üks edukas pipeline run olemas (`success`) ning stagingusse laeti tunniread.

## Järgmised sammud
1. Lisada transformi lõplik kasvuhoone otsuseloogika.
2. Lisada 3+ sisukat kvaliteeditesti:
   - hind ei tohi olla NULL
   - temperatuur mõistlikus vahemikus
   - tunni kirjed peavad olema unikaalsed
3. Kohandada dashboard KPI-dele (küte/vent + hind + kulu).

## Takistused ja leevendus
- Open-Meteo API annab vahel 502/timeout.
- Leevendus:
  - lühike prognoosiaken (`FORECAST_DAYS=2`)
  - vajadusel retry loogika ingestis
  - vajadusel aktiivsete asukohtade arvu ajutine vähendamine.
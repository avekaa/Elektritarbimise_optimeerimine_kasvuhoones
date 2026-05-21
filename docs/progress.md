# Progress (25.05–31.05)

## Valmis
- Näidisprojekti struktuur kopeeritud ja käima pandud.
- Docker teenused (`db`, `pipeline`, `scheduler`, `dashboard`) töötavad.
- A-osa seadistused tehtud: `.env`, cron, API muutujaid edasi andev scheduler.
- Äriloogika ja arhitektuur baastasemel: otsusereeglid, allikad ja andmevoo etapid (Bronze/Silver/Gold).
- Vähemalt üks edukas pipeline run olemas (`success`) ning stagingusse laeti tunniread.

## Järgmised sammud
1. Lisada transformi lõplik kasvuhoone otsuseloogika.
2. Lisada 3+ sisukat kvaliteeditesti: hind ei tohi olla NULL; temperatuur mõistlikus vahemikus; tunni kirjed unikaalsed.
3. Kohandada dashboard KPI-dele (küte/vent + hind + kulu).
4. Teha minimaalne töötav voog: 1 allikas → transformatsioon → 1 visuaal.

## Takistused ja riskid
- Open-Meteo API annab vahel 502/timeout; leevendus: lühike prognoosiaken (`FORECAST_DAYS=2`) ja retry loogika ingestis.
- Ajavööndi ühtlustus ning päikesekiirguse andmete täielikkus võivad tekitada täiendavaid riske.

Märkus: töö toimub repos `sirja-hass/Elektritarbimise_optimeerimine_kasvuhoones`; kursuse nõuded pärinevad repost `KristoR/ut-andmeinseneeria-2026`.

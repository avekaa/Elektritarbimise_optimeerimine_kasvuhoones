# Kasvuhoone elektritarbimise optimeerimine

## Äriküsimus
Millistel tundidel tasub kasvuhoones kasutada elektrit nõudvaid seadmeid (küte, ventilatsioon), et vähendada elektrikulu börsihinna tingimustes, arvestades välistemperatuuri?

## Lihtsustusmudel
- `hinnanguline_sisetemp = välistemp + 5°C`
- `< 12°C` → küte vajalik
- `> 28°C` → ventilatsioon vajalik
- muidu sobiv

Mudelit kasutatakse demonstratsiooniks.

## Andmeallikad ja ulatus

Selles projektis modelleerime kasvuhoone otsuseid piirkondliku ilma põhjal mitmes Eesti asulas.  
Asukohad tabelis `mart.dim_location` esindavad eri piirkondades tegutsevaid kasvuhoone omanikke, et võrrelda kütte- ja ventilatsioonivajadust ning börsihinna mõju üle Eesti.

Põhiandmeallikad:
- **Open-Meteo Forecast API** (välistemperatuur ja teised tunniandmed),
- **Elering NPS API** (börsihind tunni kaupa).

Oluline piirang: Eleringi day-ahead hinnad on otsustamiseks usaldusväärselt kättesaadavad peamiselt tänase ja homse kohta, seega kasutame lühikest otsustusakent (`FORECAST_DAYS=2`).

## Miks FORECAST_DAYS=2?
Elering day-ahead hinnad on otsustamiseks peamiselt tänase ja homse kohta.  
Seega ei ole 7 päeva ette forecast hinnaga hästi võrreldav.

## Käivitamine
```bash
cp .env.example .env
docker compose up -d --build
docker compose exec pipeline python scripts/run_pipeline.py run-all
docker compose exec pipeline python scripts/run_pipeline.py check

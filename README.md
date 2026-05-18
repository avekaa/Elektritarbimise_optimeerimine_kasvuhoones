# Kasvuhoone elektritarbimise optimeerimine

## Äriküsimus
Millistel tundidel tasub kasvuhoones kasutada elektrit nõudvaid seadmeid (küte, ventilatsioon), et vähendada elektrikulu börsihinna tingimustes, arvestades välistemperatuuri?

## Lihtsustusmudel
- `hinnanguline_sisetemp = välistemp + 5°C`
- `< 12°C` → küte vajalik
- `> 28°C` → ventilatsioon vajalik
- muidu sobiv

Mudelit kasutatakse demonstratsiooniks.

## Andmeallikad
- Open-Meteo Forecast API
- Elering NPS API (`/api/nps/price`)

## Miks FORECAST_DAYS=2?
Elering day-ahead hinnad on otsustamiseks peamiselt tänase ja homse kohta.  
Seega ei ole 7 päeva ette forecast hinnaga hästi võrreldav.

## Käivitamine
```bash
cp .env.example .env
docker compose up -d --build
docker compose exec pipeline python scripts/run_pipeline.py run-all
docker compose exec pipeline python scripts/run_pipeline.py check
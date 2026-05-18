
# Arhitektuur (nädal 1)

## Äriküsimus
Millistel tundidel tasub kasvuhoones kasutada kütet/ventilatsiooni, et vähendada elektrikulu börsihinna tingimustes?

## Mõõdikud (KPI)
1. Soovitatud kütte- ja ventilatsioonitunnid päevas.
2. Keskmine börsihind soovitatud tundidel vs päeva keskmine.
3. Hinnanguline päevane energiakulu.

## Andmeallikad
1. **Open-Meteo Forecast API** (ajas muutuv)
2. **Elering NPS price API** (ajas muutuv, day-ahead)

## Oluline andmepiirang
Eleringi day-ahead hind tähendab, et praktiline otsustusaken on lühike (täna + homme).  
Seetõttu kasutame `FORECAST_DAYS=2`.

## Lihtsustusmudel
- `hinnanguline_sisetemp = välistemp + 5°C`
- `<12°C` → küte vajalik
- `>28°C` → ventilatsioon vajalik
- muidu sobiv

## Andmekihid
- `staging`: toorandmed API-dest
- `mart`: otsuseloogika ja koondid
- `quality`: testitulemused

## Tehniline voog
```mermaid
flowchart LR
    A[Open-Meteo API] --> B[Pipeline ingest]
    C[Elering API] --> B
    B --> D[(staging)]
    D --> E[SQL transform]
    E --> F[(mart)]
    F --> G[Dashboard]
    F --> H[Quality tests]

    ## 6) Andmekihid

### staging
API-dest laetud toorandmed (tunnipõhised kirjed).

### mart
Otsustamiseks vajalikud mudel- ja koondtabelid.

### quality
Andmekvaliteedi testide tulemused.

---

## 7) Tehniline voog (otsast lõpuni)

1. Scheduler või käsukäivitus alustab pipeline run’i.
2. Ingest loeb Open-Meteo ja Elering API andmed.
3. Toorandmed salvestatakse `staging` kihti.
4. Transformatsioon loob `mart` kihti otsusetabelid:
   - hinnanguline sisetemperatuur,
   - tegevussoovitus (`heating`, `ventilation`, `none`),
   - hinnapõhised võrdlused.
5. Quality testid kontrollivad andmete usaldusväärsust.
6. Dashboard kuvab KPI-d ja soovitused.

---

## 8) Rollid (4 liiget)

### Osaleja A – ingest + ajastus
- API ühendused (Open-Meteo + Elering)
- `.env` seadistus
- cron/scheduler käivituse kontroll

### Osaleja B – transformatsioonid
- SQL loogika `mart` kihti
- reeglite rakendus (`+5°C`, läved `12°C` / `28°C`)

### Osaleja C – andmekvaliteet
- vähemalt 3 sisukat testi
- testitulemuste jälgimine

### Osaleja D – dashboard + esitlus
- visualiseerimine KPI-de järgi
- README viimistlus ja demo/video

---

## 9) Andmekvaliteedi testid (esmane plaan)

### Kohustuslikud testid
- elektrihind ei tohi olla `NULL`;
- temperatuur peab jääma mõistlikku vahemikku (`-50..50`);
- sama käivituse, asukoha ja tunni kohta peab kirje olema unikaalne.

### Soovitatavad lisatestid
- otsusetabelis peab `action` olema ainult:
  - `heating`
  - `ventilation`
  - `none`
- hinnanguline sisetemperatuur peab jääma mõistlikku vahemikku.

---

## 10) Riskid ja leevendused

### API 502 / timeout vead
**Leevendus:** retry-loogika, väiksem `FORECAST_DAYS`, korduskäivitus.

### Hinna ja ilma ajaline mittekattuvus
**Leevendus:** otsustabelisse lähevad ainult tunnid, kus mõlemad andmed on olemas.

### Ajavööndi nihked
**Leevendus:** ühtne ajavöönd ja kontrollpäringud pärast ingestit.

### Liiga pikk prognoos, millele hinnad puuduvad
**Leevendus:** hoida otsustusaken day-ahead loogikaga kooskõlas (`FORECAST_DAYS=2`).q
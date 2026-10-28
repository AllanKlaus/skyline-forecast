# Weather Forecast API

Rails app with a JSON API and a small HTML UI. It accepts an address or zip code,
returns forecast data, and caches results in Redis for 30 minutes.

Open `http://localhost:3000/` for the search form, or call `/api/v1/forecasts`.

## Requirements

**With Docker**

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker Engine + Compose plugin)

**Without Docker**

- Ruby 4.0+
- Redis
- SQLite

## How to run

### With Docker

From the project root:

```bash
docker compose up --build
```

This builds the image, starts Redis and boots the API at `http://localhost:3000`.

| Service | Role | Port |
|---------|------|------|
| `web` | Rails API (Ruby 4.0) | `http://localhost:3000` |
| `redis` | Forecast cache (30 min TTL) | `localhost:6379` |

Other useful commands:

```bash
docker compose up --build -d
docker compose logs -f web
docker compose down
docker compose run --rm web bundle exec rspec
docker compose run --rm web bundle exec rubocop
docker compose run --rm web bundle exec flog app
docker compose run --rm web bundle exec reek app
docker compose run --rm web bundle exec brakeman -q -w2
```

### Locally without Docker

```bash
cp .env.example .env
bundle install
bin/rails db:prepare
bin/rails server
```

Redis must be reachable at `REDIS_URL` (default `redis://localhost:6379/0`). The API listens on `http://localhost:3000`.

## API usage

```bash
curl "http://localhost:3000/api/v1/forecasts?address=1600%20Amphitheatre%20Parkway,%20Mountain%20View,%20CA%2094043"
curl "http://localhost:3000/api/v1/forecasts?address=1600%20Amphitheatre%20Parkway,%20Mountain%20View,%20CA%2094043&unit=celsius"
curl "http://localhost:3000/api/v1/forecasts?zip=94043"
curl "http://localhost:3000/api/v1/forecasts?address=avenida%20nossa%20senhora%20de%20fatima,%20praia%20grande,%20sp,%20brazil&zip=11706300"
```

Query params: `address` and/or `zip` (at least one required), `unit` (`fahrenheit` or `celsius`, default `fahrenheit`).

### Zip code accuracy

Geocoding an address does not always return the correct zip code. For example,
`avenida nossa senhora de fatima, praia grande, sp, brazil` should resolve to
`11706300`, but the upstream geocoder may return `12305011` instead.

Pass `zip` directly when you already know the correct value. When `zip` is
present it takes priority: coordinates are resolved from the zip only, and the
address string is never sent to the geocoder (it remains display text only).

- `zip` alone resolves location from the zip and caches under that zip.
- `address` + `zip` still resolves location from the zip (skipping address
  geocoding), returns the address for display, and caches under the provided zip.
- `address` alone keeps the original geocode-from-address behavior.

Example success response:

```json
{
  "address": "1600 Amphitheatre Parkway, Mountain View, CA 94043",
  "zip_code": "94043",
  "cached": false,
  "current_temperature": 57.5,
  "high": 67.1,
  "low": 50.0,
  "temperature_unit": "fahrenheit",
  "condition": "Overcast",
  "extended_forecast": [
    { "date": "2026-10-28", "high": 68.0, "low": 45.9, "weather_code": 3, "condition": "Overcast" },
    { "date": "2026-10-29", "high": 68.5, "low": 46.1, "weather_code": 3, "condition": "Overcast" }
  ]
}
```

| Status | Meaning |
|--------|---------|
| 400 | Missing address and zip, or invalid `unit` |
| 422 | Address not found, missing zip, or invalid upstream payload |
| 502 | Upstream timeout, rate limit, DNS failure, or 5xx |


## Architecture, caching, and scale

### Architectural trade-offs

- **Zip-keyed cache vs address-keyed cache.** Forecasts are cached by
  `forecast:zip:<zip>:<unit>`. Zip granularity raises hit rates for nearby
  addresses that share a postal code, at the cost of slightly coarser weather
  than a per-coordinate key. When clients pass `zip`, location and cache key
  both come from that zip (address geocoding is skipped), so the key always
  matches the coordinates that were forecast.
- **Thin controllers, service objects.** Controllers validate input and map
  domain errors to HTTP statuses. `ForecastLookup` owns geocode → weather →
  cache orchestration so the HTML UI and JSON API share one path.
- **Hybrid app instead of API-only.** The same process serves `/` and
  `/api/v1/forecasts`. That keeps the take-home deployable as one container;
  a larger system could split the UI behind a CDN or BFF without changing the
  lookup service.
- **Upstream choices.** Nominatim geocodes addresses; Open-Meteo supplies
  forecasts. Both are called synchronously. Latency and rate limits are
  accepted in exchange for no vendor API keys in the default setup.

### Cache eviction policies

- **TTL eviction (primary).** Entries expire after **30 minutes**
  (`ForecastLookup::CACHE_TTL`). There is no manual invalidate endpoint; stale
  data ages out automatically, which matches the assignment’s freshness window.
- **Unit partitioning.** Fahrenheit and Celsius payloads are separate keys, so
  a unit switch never serves the wrong scale from cache.
- **Redis as the store.** Production/development use Redis so eviction and
  memory pressure are handled by the cache server.
- **No write-through DB.** Forecasts are ephemeral; SQLite is only for Rails
  defaults.

### Concurrency and scaling under heavy load

- **Stampede protection.** `race_condition_ttl: 10.seconds` lets Rails serve a
  slightly stale value while one process refreshes an expiring key, reducing
  thundering-herd hits to Nominatim/Open-Meteo when many clients share a zip.
- **Stateless web tier.** Request handling does not keep forecast state in
  process memory. Horizontal scale-out is “add Puma/web replicas behind a
  load balancer,” with all replicas pointing at the same Redis URL.
- **Shared Redis for correctness.** Cache hits are consistent across instances
  only because the key space lives in Redis. Local memory caches would fragment
  under multi-node load and are avoided outside tests.
- **Upstream as the bottleneck.** Under sustained heavy load the limit is
  usually geocoder/weather quotas and latency, not Rails CPU. Caching by zip
  cuts repeat upstream work.
- **Puma concurrency.** Each worker handles concurrent requests; Redis
  operations are short. Long upstream calls occupy a thread/worker slot, so
  sizing should account for external p95 latency, not only app code.

## Testing and quality

```bash
bundle exec rspec
bundle exec rubocop
bundle exec brakeman -q -w2
bundle exec flog app
bundle exec reek app
```

RuboCop enforces cyclomatic complexity (`Metrics/CyclomaticComplexity`). `flog` reports ABC complexity; `reek` reports code smells.

CI (`.github/workflows/ci.yml`) runs RuboCop, Flog, Reek, Brakeman, and RSpec on Ruby 4.0.

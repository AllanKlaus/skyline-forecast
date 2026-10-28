# Weather Forecast API

Rails API that accepts an address, resolves its zip code, returns forecast data, and caches results in Redis for 30 minutes.

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
```

Query params: `address` (required), `unit` (`fahrenheit` or `celsius`, default `fahrenheit`).

### Zip code accuracy

Geocoding an address does not always return the correct location. For example,
`avenida nossa senhora de fatima, praia grande, sp, brazil` should resolve near
zip `11706300`, but the upstream geocoder may return a point tied to `12305011`
more than 200 km away.

To correct that, the API will accept an optional `zip` query parameter. When
`zip` is present it must take priority over `address` for locating the forecast
(skipping address geocoding).

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
| 400 | Missing or blank address, or invalid `unit` |
| 422 | Address not found, missing zip, or invalid upstream payload |
| 502 | Upstream timeout, rate limit, DNS failure, or 5xx |

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

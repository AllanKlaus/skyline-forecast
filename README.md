# Weather Forecast API

Rails API that accepts an address, resolves its zip code, returns forecast data, and caches results in Redis for 30 minutes.

## Requirements

- Docker and Docker Compose, or
- Ruby 4.0+, Redis, and SQLite

## Quick start (Docker)

```bash
docker compose up --build
```

API: `http://localhost:3000`

## Local setup

```bash
cp .env.example .env
bundle install
bin/rails db:prepare
bin/rails server
```

Redis must be reachable at `REDIS_URL` (default `redis://localhost:6379/0`).

## API usage

```bash
curl "http://localhost:3000/api/v1/forecasts?address=1600%20Amphitheatre%20Parkway,%20Mountain%20View,%20CA%2094043"
curl "http://localhost:3000/api/v1/forecasts?address=1600%20Amphitheatre%20Parkway,%20Mountain%20View,%20CA%2094043&unit=celsius"
```

Query params: `address` (required), `unit` (`fahrenheit` or `celsius`, default `fahrenheit`).

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

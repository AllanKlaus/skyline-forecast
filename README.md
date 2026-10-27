# Weather Forecast API

Rails API that returns weather forecasts for a given address, with Redis caching by zip code.

## Requirements

- Docker and Docker Compose
- Or Ruby 4.0+, Redis, SQLite

## Run with Docker

```bash
docker compose up --build
```

The API listens on `http://localhost:3000`.

## Run locally

```bash
cp .env.example .env
bundle install
bin/rails db:prepare
bin/rails server
```

Redis must be available at `REDIS_URL` (default `redis://localhost:6379/0`).

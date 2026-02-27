# Tech Stack

> **KEEP LEAN**: Max 30 lines.

## Core
| Tech | Version | Purpose |
|------|---------|---------|
| Python | 3.12.x | Runtime |
| uv/pip | latest | Package manager |

## Web Framework
FastAPI 0.110+, Uvicorn, Pydantic v2

## Database
SQLAlchemy 2.x, Alembic (migrations)

## Infra
PostgreSQL 15, Redis 7

## Commands
```bash
uv run dev         # Development (or: python -m uvicorn app:app --reload)
uv run test        # Tests (or: pytest)
uv run lint        # Linting (or: ruff check .)
uv run format      # Format (or: ruff format .)
```

## Requirements
Python >= 3.12, uv >= 0.4 (or pip + venv)

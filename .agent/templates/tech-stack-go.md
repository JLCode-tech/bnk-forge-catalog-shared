# Tech Stack

> **KEEP LEAN**: Max 30 lines.

## Core
| Tech | Version | Purpose |
|------|---------|---------|
| Go | 1.22.x | Runtime + compiler |
| go modules | built-in | Dependency management |

## Web Framework
net/http (stdlib) or Echo/Gin/Chi

## Database
pgx (PostgreSQL), sqlc or GORM

## Infra
PostgreSQL 15, Redis 7

## Commands
```bash
go run ./cmd/server    # Development
go build ./...         # Build
go test ./...          # Tests
golangci-lint run      # Linting
```

## Requirements
Go >= 1.22, golangci-lint

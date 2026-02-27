# Tech Stack

> **KEEP LEAN**: Max 30 lines.

## Core
| Tech | Version | Purpose |
|------|---------|---------|
| Rust | stable (1.77+) | Compiler |
| Cargo | built-in | Build system + package manager |

## Web Framework
Axum or Actix-web, Tower (middleware), Tokio (async runtime)

## Database
SQLx (async, compile-time checked), SeaORM

## Infra
PostgreSQL 15, Redis 7

## Commands
```bash
cargo run              # Development
cargo build --release  # Production build
cargo test             # Tests
cargo clippy           # Linting
cargo fmt              # Format
```

## Requirements
Rust stable toolchain, clippy, rustfmt

# acme-api

Acme Corp backend REST API — Node.js + TypeScript + Fastify. Read this before doing any work.

## Tech stack

- **Runtime**: Node.js 20 (see `.nvmrc`)
- **Framework**: Fastify 4
- **Database**: PostgreSQL via Prisma ORM
- **Cache / queues**: Redis + BullMQ
- **Auth**: JWT (RS256), refresh token rotation
- **Testing**: Jest + Supertest for integration tests

## Commands

```bash
npm run dev           # Start dev server with hot reload (port 3000)
npm run build         # Compile TypeScript → dist/
npm run typecheck     # Type-check without emitting
npm run lint          # ESLint
npm run lint:fix      # ESLint auto-fix
npm run format        # Prettier
npm run test          # All tests
npm run test:unit     # Unit tests only (no DB needed)
npm run test:int      # Integration tests (requires running DB)
npm run db:migrate    # Run pending Prisma migrations
npm run db:seed       # Seed development data
```

Always run `npm run typecheck && npm run lint` before committing.

## Project layout

```
src/
  routes/         ← Fastify route handlers, one file per resource
  services/       ← Business logic, no direct DB access
  repositories/   ← Prisma data access, one class per domain entity
  models/         ← Zod schemas and TypeScript types
  plugins/        ← Fastify plugin registrations (auth, cors, rate-limit)
  jobs/           ← BullMQ job definitions and processors
  utils/          ← Pure utilities (errors, pagination, date helpers)
  config.ts       ← Validated env vars (use this, never process.env directly)
tests/
  unit/           ← Mirrors src/ structure
  integration/    ← Requires running Postgres + Redis
prisma/
  schema.prisma
  migrations/
```

## Rules

- Repositories return domain model types — never expose raw Prisma types to services
- Services depend on repository interfaces, not concrete implementations (DI via fastify decorators)
- All API responses use the envelope: `{ data, meta?, error? }`
- Errors must be `AppError` instances (`src/utils/errors.ts`) — never throw plain `Error`
- All timestamps as ISO 8601 UTC strings
- No `any` in TypeScript — open a PR comment if you're blocked

## Environment

Never hardcode secrets. Copy `.env.example` → `.env` for local dev. Required vars:
- `DATABASE_URL` — PostgreSQL connection string
- `REDIS_URL` — Redis connection string
- `JWT_PRIVATE_KEY` / `JWT_PUBLIC_KEY` — RS256 key pair (base64-encoded PEM)
- `PORT` — defaults to 3000

Use `src/config.ts` for all env access — it validates at startup.

## Git

- Branch: `feat/<ticket>-short-description` or `fix/<ticket>-short-description`
- CI must pass (typecheck + lint + unit tests) before review
- Squash merge into `main`
- Tag releases `v<semver>`

@.claude/instructions/api-patterns.md
@.claude/instructions/error-handling.md

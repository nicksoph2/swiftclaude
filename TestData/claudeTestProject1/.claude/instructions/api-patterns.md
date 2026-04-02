# API patterns — acme-api

## Route handlers

Route handlers live in `src/routes/`. Each file exports a Fastify plugin that registers one or more routes for a resource.

```typescript
// src/routes/users.ts
import { FastifyInstance } from 'fastify'
import { UserService } from '../services/UserService'
import { createUserSchema, getUserSchema } from '../models/user'

export async function userRoutes(fastify: FastifyInstance) {
  const userService = new UserService(fastify.db)

  fastify.get('/:id', { schema: getUserSchema }, async (request, reply) => {
    const user = await userService.findById(request.params.id)
    return reply.send({ data: user })
  })

  fastify.post('/', { schema: createUserSchema }, async (request, reply) => {
    const user = await userService.create(request.body)
    return reply.status(201).send({ data: user })
  })
}
```

## Response envelope

All responses use `{ data, meta?, error? }`:

```typescript
// Success (single resource)
{ "data": { "id": "...", "name": "..." } }

// Success (collection)
{ "data": [...], "meta": { "total": 42, "page": 1, "perPage": 20 } }

// Error
{ "error": { "code": "NOT_FOUND", "message": "User not found" } }
```

## Pagination

Use `src/utils/pagination.ts` for consistent cursor-based pagination. Never return unbounded lists.

```typescript
const { items, nextCursor, total } = await repo.findMany({
  cursor: request.query.cursor,
  limit: request.query.limit ?? 20,
})
return reply.send({
  data: items,
  meta: { total, nextCursor },
})
```

## Input validation

All route inputs are validated via Zod schemas in `src/models/`. Register schemas with Fastify's JSON schema support for automatic validation and OpenAPI generation.

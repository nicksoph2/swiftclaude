# Error handling — acme-api

## AppError

All errors must be `AppError` instances from `src/utils/errors.ts`. Never throw plain `new Error()`.

```typescript
import { AppError } from '../utils/errors'

// Usage
throw new AppError('NOT_FOUND', 'User not found', 404)
throw new AppError('VALIDATION_ERROR', 'Email is required', 400)
throw new AppError('UNAUTHORIZED', 'Invalid or expired token', 401)
throw new AppError('CONFLICT', 'Email already in use', 409)
```

## Error codes

| Code | HTTP | When |
|---|---|---|
| `NOT_FOUND` | 404 | Resource does not exist |
| `UNAUTHORIZED` | 401 | Missing or invalid auth token |
| `FORBIDDEN` | 403 | Authenticated but insufficient permissions |
| `VALIDATION_ERROR` | 400 | Request body/params fail Zod validation |
| `CONFLICT` | 409 | Unique constraint violation |
| `INTERNAL_ERROR` | 500 | Unexpected error — never expose details to clients |

## Fastify error handler

The global error handler in `src/plugins/error-handler.ts` catches all `AppError` instances and formats them as `{ error: { code, message } }`. Unrecognised errors are logged and returned as `INTERNAL_ERROR`.

## Database errors

Wrap Prisma calls that can produce constraint violations:

```typescript
try {
  return await this.prisma.user.create({ data })
} catch (e) {
  if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
    throw new AppError('CONFLICT', 'Email already in use', 409)
  }
  throw e
}
```

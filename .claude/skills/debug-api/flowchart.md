# Request flow in this codebase

```
┌───────────────────────────────────────────────────────────────────────────┐
│                            FLUTTER APP                                    │
│                                                                           │
│  Screen ─► ref.read(<feature>Provider.notifier).<method>()                │
│              │                                                            │
│              ▼                                                            │
│         Riverpod provider                                                 │
│              │                                                            │
│              ▼                                                            │
│         <Repository>.<method>(...)                                        │
│              │  (frontend/lib/data/<resource>/<resource>_repository.dart) │
│              ▼                                                            │
│         _client.dio.<verb>('<path>', ...)                                 │
│              │  (frontend/lib/core/network/api_client.dart)               │
│              ▼                                                            │
│   ┌──────────────────────────────────────────────┐                        │
│   │ _AuthInterceptor.onRequest                   │                        │
│   │   • reads accessToken from secure storage    │                        │
│   │   • sets Authorization: Bearer <token>       │                        │
│   └──────────────────────────────────────────────┘                        │
│              │                                                            │
└──────────────┼────────────────────────────────────────────────────────────┘
               │ HTTP
               ▼
┌──────────────┬────────────────────────────────────────────────────────────┐
│              │                      EXPRESS BACKEND                       │
│              ▼                                                            │
│   ┌──────────────────────────────────────────────┐                        │
│   │ helmet → cors → rateLimit → json/urlencoded │  server.js              │
│   │ → compression → morgan                      │                        │
│   └──────────────────────────────────────────────┘                        │
│              │                                                            │
│              ▼                                                            │
│   ┌──────────────────────────────────────────────┐                        │
│   │ Router: /api/v1/<resource>/...               │  routes/*Routes.js     │
│   │ Per route:                                   │                        │
│   │   authenticate → [express-validator] →       │                        │
│   │   validate → controller.method               │                        │
│   └──────────────────────────────────────────────┘                        │
│              │                                                            │
│              ▼                                                            │
│   ┌──────────────────────────────────────────────┐                        │
│   │ authenticate                                 │  middleware/auth.js    │
│   │   • verify JWT                               │                        │
│   │   • cache.getOrSet(auth:user:<id>, 300s)     │                        │
│   │   • req.user = { id, phone_number, name, …}  │                        │
│   └──────────────────────────────────────────────┘                        │
│              │                                                            │
│              ▼                                                            │
│   ┌──────────────────────────────────────────────┐                        │
│   │ validate                                     │  middleware/validation │
│   │   • returns 400 + { error, details } on fail │                        │
│   └──────────────────────────────────────────────┘                        │
│              │                                                            │
│              ▼                                                            │
│   ┌──────────────────────────────────────────────┐                        │
│   │ Controller                                   │  controllers/*         │
│   │   • GroupService.validateGroupAccess(...)    │                        │
│   │   • Model.<method>(...)                      │                        │
│   │   • Model.invalidate<Scope>(...)             │                        │
│   │   • ActivityService.log<Event>(...)          │                        │
│   │   • res.json({ success, data, message? })    │                        │
│   └──────────────────────────────────────────────┘                        │
│              │                                                            │
│              ▼                                                            │
│   ┌──────────────────────────────────────────────┐                        │
│   │ Model                                        │  models/*              │
│   │   • cache.getOrSet(key, TTL.X, fn)           │                        │
│   │   • query(sql, params)                       │                        │
│   │   • transaction(async client => …)           │                        │
│   └──────────────────────────────────────────────┘                        │
│              │                                                            │
│              ▼                                                            │
│   ┌──────────────────────────────────────────────┐                        │
│   │ pg pool (config/database.js)                 │                        │
│   │   • SQL is logged if > 100ms                 │                        │
│   │   • statement_timeout = 30s                  │                        │
│   └──────────────────────────────────────────────┘                        │
│              │                                                            │
│              ▼                                                            │
│         PostgreSQL                                                       │
│                                                                           │
│  Errors bubble back through next(err) → errorHandler.js                  │
│  which maps PG codes (23505, 23503, 23502) to 409/400/400               │
│  and emits { success: false, error }                                     │
└───────────────────────────────────────────────────────────────────────────┘
```

## What the interceptor does on 401

```
Request → 401
   │
   ▼
_AuthInterceptor.onResponse sees 401 (not /auth/refresh, not already retried)
   │
   ▼
client.refreshAccessToken() ── locked by _refreshing Completer (parallel 401s share one refresh)
   │
   ▼
POST /auth/refresh { refreshToken }
   │
   ├── 200 + { data: { accessToken } } → save new access → fetch(original request, _retried: true) → resolve
   │
   └── any failure → tokens.clear() → emit onUnauthorized → caller sees the original 401
```

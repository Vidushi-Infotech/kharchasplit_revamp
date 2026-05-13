---
name: api-repository
description: Use when adding or extending a Flutter repository under frontend/lib/data/<resource>/<resource>_repository.dart that talks to the KharchaSplit Express backend over Dio (e.g. "call the new /budgets endpoint from Flutter", "wire up groups archive in the app", "add a method to fetch expenses by category"). Generates a Dio repository + Riverpod provider that obeys the project's response envelope ({ success, data }), currency normalization, auth-via-interceptor, and 401-refresh flow.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Add or extend a Flutter API repository

This skill produces a Dio-based repository file that matches the existing pattern in `frontend/lib/data/`. The canonical example is [frontend/lib/data/expenses/expenses_repository.dart](frontend/lib/data/expenses/expenses_repository.dart). Read that file first if you want the whole picture in one sitting.

## File layout (mandatory)

```
frontend/lib/data/<resource>/
└── <resource>_repository.dart
```

One file per backend resource. The repository class exposes ONE method per endpoint and returns model objects from `frontend/lib/models/`.

## What you get for free from `ApiClient`

Defined in [frontend/lib/core/network/api_client.dart](frontend/lib/core/network/api_client.dart):

- `dio.options.baseUrl` is already `<API_BASE_URL>/api/v1`. Use paths like `/expenses`, not `/api/v1/expenses`.
- `Authorization: Bearer <token>` is auto-attached by `_AuthInterceptor`.
- `validateStatus: (s) => s < 500` — Dio will NOT throw on 4xx, you must inspect `response.data['success']` yourself.
- On 401, the interceptor calls `/auth/refresh` once and replays the original request. If refresh fails, tokens are cleared and an `onUnauthorized` event fires.

So: DO NOT manually add auth headers, retry logic, or refresh handling in your repository.

## Response envelope contract (verified across every repository)

Every backend response is one of:
```json
{ "success": true,  "data": <object|array>, "message": "...", "pagination": {...} }
{ "success": false, "error":  "Human readable" }
```

Your repository MUST funnel every response through these three helpers (copy them — they're identical in every repo file in this codebase):

```dart
Map<String, dynamic> _ensureSuccess(Response res) {
  final body = res.data;
  if (body is! Map || body['success'] != true) {
    final msg = (body is Map ? body['error'] : null)?.toString()
        ?? 'Request failed (status ${res.statusCode})';
    throw <Resource>ApiException(msg, statusCode: res.statusCode);
  }
  return body.cast<String, dynamic>();
}

Map<String, dynamic> _ensureMap(Response res) {
  final body = _ensureSuccess(res);
  final data = body['data'];
  if (data is! Map<String, dynamic>) {
    throw <Resource>ApiException('Malformed response — expected object in data');
  }
  return data;
}

List<dynamic> _ensureList(Response res) {
  final body = _ensureSuccess(res);
  final data = body['data'];
  if (data is! List) {
    throw <Resource>ApiException('Malformed response — expected list in data');
  }
  return data;
}
```

And a typed exception class right above the repository class:

```dart
class <Resource>ApiException implements Exception {
  <Resource>ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
```

The auth notifier maps these (and `DioException`s) to friendly error messages in [auth_provider.dart](frontend/lib/modules/auth/state/auth_provider.dart) via `_readableError` — follow the same shape so it works.

## Currency normalization

Backend stores 3-letter codes (`INR`, `USD`, `EUR`, `GBP`). The Flutter state often carries symbols (`₹`, `$`, `€`, `£`). Whenever you send currency to the backend, run it through this helper (copy from `expenses_repository.dart`):

```dart
String _normalizeCurrency(String input) {
  switch (input) {
    case '₹': return 'INR';
    case '\$': return 'USD';
    case '€': return 'EUR';
    case '£': return 'GBP';
    default:  return input.length == 3 ? input.toUpperCase() : 'INR';
  }
}
```

Backend → Flutter: code stays as a code; if the UI needs a symbol, the formatter is `core/utils/currency_formatter.dart`.

## Riverpod provider

Always expose the repository as a `Provider` at the bottom of the file:

```dart
final <resource>RepositoryProvider = Provider<<Resource>Repository>((ref) {
  return <Resource>Repository(ref.watch(apiClientProvider));
});
```

This auto-wires the singleton `ApiClient` from `core/network/api_client.dart`. Never call `Dio()` directly — that bypasses the auth interceptor.

## Step-by-step

1. **Confirm the backend endpoint exists** and read its controller to find:
   - The exact path (relative to `/api/v1`)
   - Required request fields (look at the `body()` validators in the route)
   - Response shape (`data` is a single object, a list, or a list with `pagination`)
2. **Copy `templates/repository.template.dart`** into `frontend/lib/data/<resource>/<resource>_repository.dart`. Replace placeholders.
3. **Map JSON → model** using `<Model>.fromJson`. The factory should accept both snake_case and camelCase (see `expense_model.dart` for the canonical "either or" pattern).
4. **For paginated GETs** the backend returns `{ data: [...], pagination: { hasMore, ... } }`. Either return a tuple-like `{items, hasMore}` or expose two methods (`list` + `next`) depending on consumer needs.
5. **For POSTs that send images** (receipt, profile, group cover) — the backend accepts `base64` strings. Server cap is **2 MB** on the body. Pre-compress with `flutter_image_compress` (already a dep) before encoding.
6. **Run the analyzer** — `cd frontend && flutter analyze`.
7. **Smoke-test** by calling the new method from a temporary `print` in the screen, then wire it through a provider.

## Common mistakes — refuse to commit any of these

| ❌ Wrong                                                       | ✅ Correct                                                      |
|---------------------------------------------------------------|----------------------------------------------------------------|
| `Dio()` instantiated inside the repo                          | `final dio = client.dio;` from `apiClientProvider`            |
| `dio.options.headers['Authorization'] = ...`                  | Let `_AuthInterceptor` handle it                              |
| Path starts with `/api/v1/...`                                | Path starts with `/...` (base url already includes the prefix)|
| Throw on `res.statusCode != 200`                              | Inspect `body['success']`; `validateStatus < 500` is set      |
| Catch `DioException` and swallow it                           | Let it bubble — the provider catches it and surfaces UI error |
| Send `'currency': '₹'`                                        | `'currency': _normalizeCurrency(input)`                       |
| Read `res.data['data']['items']`                              | The envelope is flat: `body['data']` is the data, not nested  |
| Hardcode the BASE URL in the repository                       | Always use `ApiConfig.baseUrl` via `apiClientProvider`        |
| `print(res.data)` in production code                          | Remove debug prints before committing                          |

See `templates/repository.template.dart` and `examples.md` for working files.

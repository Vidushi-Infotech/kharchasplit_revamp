# Examples — wiring a new endpoint into Flutter

## Example 1 — Add `archive(groupId)` to an existing repository

The backend already exposes `POST /api/v1/groups/:id/archive`. Add a method to `groups_repository.dart` and a UI hook.

### 1. Edit `frontend/lib/data/groups/groups_repository.dart`

```dart
Future<void> archive(String groupId) async {
  final res = await _client.dio.post('/groups/$groupId/archive');
  _ensureSuccess(res);
}
```

### 2. Refresh provider state

In the screen that triggered the archive:

```dart
await ref.read(groupsRepositoryProvider).archive(group.id);
ref.invalidate(groupsProvider);                // re-fetch the list
ref.invalidate(groupDetailProvider(group.id)); // re-fetch detail if open
```

### 3. Error surfacing

```dart
try {
  await ref.read(groupsRepositoryProvider).archive(group.id);
  // ...
} on GroupsApiException catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
}
```

---

## Example 2 — New paginated GET, list endpoint with images

Backend: `GET /api/v1/groups/:id/receipts?page=1&limit=20` returns `{ success, data: [{ id, expenseId, imageUrl, createdAt }], pagination }`.

### 1. Model — `frontend/lib/models/receipt_model.dart`

```dart
import 'package:equatable/equatable.dart';

class ReceiptModel extends Equatable {
  const ReceiptModel({
    required this.id,
    required this.expenseId,
    required this.imageUrl,
    required this.createdAt,
  });

  final String id;
  final String expenseId;
  final String imageUrl;
  final DateTime createdAt;

  factory ReceiptModel.fromJson(Map<String, dynamic> json) {
    return ReceiptModel(
      id: json['id'] as String,
      expenseId: (json['expenseId'] ?? json['expense_id']) as String,
      imageUrl: (json['imageUrl'] ?? json['image_url']) as String,
      createdAt: DateTime.parse(
        (json['createdAt'] ?? json['created_at']) as String,
      ),
    );
  }

  @override
  List<Object?> get props => [id, expenseId, imageUrl, createdAt];
}
```

### 2. Repository — `frontend/lib/data/receipts/receipts_repository.dart`

Copy the template, replace `<Receipt>` / `<receipt>`, then change the list method to read pagination:

```dart
class ReceiptsPage {
  ReceiptsPage(this.items, this.hasMore);
  final List<ReceiptModel> items;
  final bool hasMore;
}

Future<ReceiptsPage> listForGroup(String groupId, {int page = 1, int limit = 20}) async {
  final res = await _client.dio.get(
    '/groups/$groupId/receipts',
    queryParameters: {'page': page, 'limit': limit},
  );
  final body = _ensureSuccess(res);
  final list = body['data'] as List? ?? const [];
  final pagination = body['pagination'] as Map?;
  return ReceiptsPage(
    list.whereType<Map<String, dynamic>>().map(ReceiptModel.fromJson).toList(),
    (pagination?['hasMore'] as bool?) ?? false,
  );
}
```

### 3. Render images via `CachedNetworkImage`

Never `Image.network(...)` in a list — that's a CLAUDE.md rule. Use:

```dart
CachedNetworkImage(
  imageUrl: receipt.imageUrl,
  placeholder: (_, __) => const ShimmerBox(...),
  errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
)
```

---

## Example 3 — POST with base64 receipt (image upload)

Backend caps `express.json` at **2 MB**. Compress before encoding.

```dart
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:convert';

Future<ExpenseModel> createWithReceipt({
  required String groupId,
  required String description,
  required double amount,
  required String paidById,
  required String paidByName,
  required String filePath,
  required List<ExpenseParticipant> participants,
}) async {
  // Compress to ~80% quality, max 1600px on the long edge — keeps us under 2 MB.
  final compressed = await FlutterImageCompress.compressWithFile(
    filePath,
    quality: 80,
    minWidth: 1600,
    minHeight: 1600,
  );
  if (compressed == null) {
    throw ExpensesApiException('Could not process receipt image');
  }
  final base64 = base64Encode(compressed);

  return create(
    groupId: groupId,
    description: description,
    amount: amount,
    currency: 'INR',
    paidById: paidById,
    paidByName: paidByName,
    splitType: 'equal',
    receiptBase64: base64,
    participants: participants,
  );
}
```

Backend validator already accepts `receiptBase64` on `POST /expenses` — no change needed there.

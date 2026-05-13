/// Mock invoice scanning service
/// Simulates AI extraction of amount, category, and date from invoice images
/// Backend API integration will replace this mock implementation

class InvoiceScanResult {
  final double amount;
  final String category;
  final DateTime date;
  final String description;
  final bool isConfident;

  InvoiceScanResult({
    required this.amount,
    required this.category,
    required this.date,
    required this.description,
    this.isConfident = false,
  });
}

class InvoiceScannerService {
  /// Mock invoice scanning - simulates AI extraction from image
  /// In production, this will call backend API for OCR + AI analysis
  static Future<InvoiceScanResult> scanInvoiceImage(String imagePath) async {
    // Simulate processing delay
    await Future.delayed(const Duration(seconds: 2));

    // Mock data - simulates different invoice types
    final mockResults = [
      InvoiceScanResult(
        amount: 450.00,
        category: 'Food & Dining',
        date: DateTime.now(),
        description: 'Restaurant Invoice',
        isConfident: true,
      ),
      InvoiceScanResult(
        amount: 120.50,
        category: 'Groceries',
        date: DateTime.now(),
        description: 'Grocery Store',
        isConfident: true,
      ),
      InvoiceScanResult(
        amount: 299.99,
        category: 'Transportation',
        date: DateTime.now().subtract(const Duration(days: 1)),
        description: 'Cab/Ride Share',
        isConfident: false,
      ),
      InvoiceScanResult(
        amount: 75.00,
        category: 'Entertainment',
        date: DateTime.now(),
        description: 'Movie Tickets',
        isConfident: true,
      ),
    ];

    // Return random mock result
    final random = DateTime.now().millisecondsSinceEpoch;
    return mockResults[random % mockResults.length];
  }

  /// Mock validation - checks if image is a valid invoice
  static Future<bool> validateInvoiceImage(String imagePath) async {
    // Simulate validation
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  /// Get category suggestions based on description
  static List<String> getCategorySuggestions(String description) {
    const categories = {
      'restaurant': 'Food & Dining',
      'cafe': 'Food & Dining',
      'hotel': 'Accommodation',
      'flight': 'Travel',
      'taxi': 'Transportation',
      'uber': 'Transportation',
      'grocery': 'Groceries',
      'mall': 'Shopping',
      'movie': 'Entertainment',
      'cinema': 'Entertainment',
      'medicine': 'Health & Medical',
      'hospital': 'Health & Medical',
      'gas': 'Transportation',
      'petrol': 'Transportation',
    };

    final lowerDesc = description.toLowerCase();
    final suggestions = categories.entries
        .where((e) => lowerDesc.contains(e.key))
        .map((e) => e.value)
        .toList();

    return suggestions.isNotEmpty
        ? suggestions
        : [
            'Food & Dining',
            'Transportation',
            'Groceries',
            'Entertainment',
            'Shopping',
          ];
  }
}

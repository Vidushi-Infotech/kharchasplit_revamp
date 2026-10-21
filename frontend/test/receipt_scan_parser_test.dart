import 'package:flutter_test/flutter_test.dart';
import 'package:kharchasplit/core/utils/receipt_scan_fields.dart';
import 'package:kharchasplit/core/utils/receipt_scan_parser.dart';

/// Receipt texts as ML Kit returns them (one row per line, OCR quirks
/// included). "Today" is 21 Oct 2026 throughout.
final _now = DateTime(2026, 10, 21, 18, 30);

ReceiptScanResult _parse(String text) => parseReceiptText(text, now: _now);

void main() {
  test('restaurant bill with CGST / SGST → Grand Total, not Sub Total', () {
    final r = _parse('''
HOTEL SAI PALACE
Family Restaurant & Bar
12, MG Road, Near City Mall
Pune - 411001
GSTIN: 27AABCS1234F1Z5
Ph: 020-24451234
TAX INVOICE
Bill No: 4521   Table: 7
Date: 16/10/2026   Time: 21:34
Item              Qty   Amount
Paneer Butter Masala  1   320.00
Butter Naan           4   240.00
Veg Biryani           2   490.00
Sub Total               1,050.00
CGST @ 2.5%                26.25
SGST @ 2.5%                26.25
Round Off                  -0.50
Grand Total          ₹ 1,102.00
Thank You! Visit Again
''');
    expect(r.total, 1102.00);
    expect(r.totalConfidence, greaterThanOrEqualTo(0.9));
    expect(r.date, DateTime(2026, 10, 16));
    expect(r.merchant, 'Hotel Sai Palace');
  });

  test('Swiggy order summary → To Pay, ignoring item total, fees, GST', () {
    final r = _parse('''
Order Summary
Meghana Foods
Koramangala, Bengaluru
Order #162773849102
Delivered on Oct 12, 2026
1 x Chicken Biryani        ₹380
1 x Gobi Manchurian        ₹170
Item Total                 ₹550.00
Delivery partner fee        ₹35.00
Platform fee                 ₹5.00
GST and Restaurant Charges  ₹29.50
Item Discount             -₹100.00
To Pay                     ₹469.50
''');
    expect(r.total, 469.50);
    expect(r.date, DateTime(2026, 10, 12));
    expect(r.merchant, 'Meghana Foods');
  });

  test('Zomato summary with "Grand Total" and inclusive-of-taxes note', () {
    final r = _parse('''
zomato
Your order from Behrouz Biryani
Subtotal ₹ 649
Taxes ₹ 32.45
Delivery charge ₹ 40
Grand Total (incl. of all taxes) ₹ 721.45
Paid via UPI
19 Oct 2026, 1:42 PM
''');
    expect(r.total, 721.45);
    expect(r.merchant, 'Behrouz Biryani');
    expect(r.date, DateTime(2026, 10, 19));
  });

  test('petrol pump slip → AMOUNT, not rate or volume', () {
    final r = _parse('''
WELCOME
INDIAN OIL
COCO Baner Road Pune
TEL 020-2729 1100
RECEIPT NO 004512
FIP NO 2  NOZZLE NO 1
PRODUCT PETROL
RATE(Rs/L) 106.310
VOLUME(L) 9.406
AMOUNT(Rs.) 1000.00
DATE:14-10-26 TIME:10:22:31
VEHICLE NO MH12AB1234
''');
    expect(r.total, 1000.00);
    expect(r.date, DateTime(2026, 10, 14));
    expect(r.merchant, 'Indian Oil');
  });

  test('supermarket bill → Net Amount, not savings / tendered / change', () {
    final r = _parse('''
DMart
Avenue Supermarts Ltd
Hiranandani Estate, Thane West - 400607
GSTIN 27AACCA8432H1ZQ
Bill Dt: 03-10-2026  14:08
Toor Dal 1kg          2   178.00   356.00
Amul Butter 500g      1   285.00   285.00
Total Qty: 12  Items: 9
Total Savings        ₹210.00
Net Amount       Rs. 2,345.60
Cash Tendered        2,500.00
Change                 154.40
''');
    expect(r.total, 2345.60);
    expect(r.date, DateTime(2026, 10, 3));
    expect(r.merchant, 'DMart');
  });

  test('Google Pay screenshot → the big ₹ amount and "Paid to" name', () {
    final r = _parse('''
₹1,234.50
Paid to Rahul Sharma
Completed
16 Oct 2026, 8:42 pm
UPI transaction ID
628912345678
To: rahul.sharma@okicici
From: State Bank of India 1234
Google transaction ID
CICAgOCYz9X1Bw
''');
    expect(r.total, 1234.50);
    expect(r.merchant, 'Rahul Sharma');
    expect(r.date, DateTime(2026, 10, 16));
  });

  test('PhonePe screen → amount below "Paid to", Indian grouping', () {
    final r = _parse('''
Transaction Successful
10:15 am on 15 Oct 2026
Paid to
SHARMA GENERAL STORE
₹ 1,23,456
Banking Name : RAMESH SHARMA
Transaction ID
T2610151015123456789
''');
    expect(r.total, 123456.00);
    expect(r.merchant, 'Sharma General Store');
    expect(r.date, DateTime(2026, 10, 15));
  });

  test('"Rs.1234/-" totals and Total Items lines', () {
    final r = _parse('''
SHREE KRISHNA SWEETS
Cash Memo
Dt. 20.10.2026
Kaju Katli 500g     650
Rasgulla 1kg        420
Samosa 6           164
Total Items 3
TOTAL Rs.1234/-
''');
    expect(r.total, 1234.00);
    expect(r.date, DateTime(2026, 10, 20));
    expect(r.merchant, 'Shree Krishna Sweets');
  });

  test('label column and amount column read as separate runs', () {
    final r = _parse('''
CAFE MOCHA
Sub Total
CGST 9%
SGST 9%
Grand Total
1,000.00
90.00
90.00
1,180.00
''');
    expect(r.total, 1180.00);
  });

  test('only a sub total and taxes → no total rather than a wrong one', () {
    final r = _parse('''
Sub Total 500.00
CGST 12.50
SGST 12.50
''');
    expect(r.total, isNull);
    expect(r.isEmpty, isTrue);
  });

  test('text that is not a receipt → nothing', () {
    final r = _parse('Meeting notes\nCall Asha about the trip\nBook tickets');
    expect(r.total, isNull);
    expect(r.date, isNull);
  });

  test('a future date is never returned; US month-first only if needed', () {
    expect(_parse('Date: 25/12/2027\nTotal 100.00').date, isNull);
    expect(
      _parse('Date: 10/16/2026\nTotal 100.00').date,
      DateTime(2026, 10, 16),
    );
    expect(_parse('Bill date 2026-10-09').date, DateTime(2026, 10, 9));
  });

  test('two plain totals → the lower (later) one', () {
    final r = _parse('''
Total 1,000.00
Service charge 50.00
Total 1,050.00
''');
    expect(r.total, 1050.00);
  });

  group('amounts', () {
    int? paise(String s) {
      final a = receiptAmountsIn(s);
      return a.isEmpty ? null : a.last.paise;
    }

    test('formats', () {
      expect(paise('₹ 1,234.50'), 123450);
      expect(paise('Rs.1234/-'), 123400);
      expect(paise('INR 1,234'), 123400);
      expect(paise('1,23,456.00'), 12345600);
      expect(paise('Total 1, 234.0O'), 123400);
      expect(paise('Amount 1234,50'), 123450);
    });

    test('not amounts', () {
      expect(paise('Ph 9876543210'), isNull);
      expect(paise('12:45 PM'), isNull);
      expect(paise('GST 18%'), isNull);
      expect(paise('Rate 106.310'), isNull);
      expect(paise('12/10/2026'), isNull);
    });

    test('negative', () {
      expect(receiptAmountsIn('Discount -₹100.00').single.isNegative, isTrue);
      expect(receiptAmountsIn('Round Off -0.50').single.isNegative, isTrue);
    });
  });
}

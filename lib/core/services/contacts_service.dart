import 'package:flutter_contacts/flutter_contacts.dart';
import '../../models/contact_model.dart';
import '../utils/phone_formatter.dart';

/// Service for fetching device contacts
class ContactsService {
  /// Request contact permissions
  Future<bool> requestContactPermission() async {
    try {
      final permissionStatus = await FlutterContacts.requestPermission();
      print('[ContactsService] Permission status: $permissionStatus');
      return permissionStatus;
    } catch (e) {
      print('[ContactsService] Permission error: $e');
      return false;
    }
  }

  /// Check if contacts permission is granted
  Future<bool> hasContactPermission() async {
    try {
      return await FlutterContacts.requestPermission(readonly: true);
    } catch (e) {
      print('[ContactsService] Permission check error: $e');
      return false;
    }
  }

  /// Get all device contacts
  Future<List<ContactModel>> getAllContacts() async {
    try {
      // Check permission first
      final hasPermission = await hasContactPermission();
      if (!hasPermission) {
        print('[ContactsService] No contact permission');
        return [];
      }

      // Fetch real contacts from device
      print('[ContactsService] Fetching real device contacts');
      final contacts = await FlutterContacts.getContacts();

      return contacts.map((contact) {
        final phones = contact.phones
            .where((p) => p.number.isNotEmpty)
            .map((p) => PhoneFormatter.normalizePhone(p.number))
            .where((p) => p.isNotEmpty)
            .toList();

        final emails = contact.emails
            .where((e) => e.address.isNotEmpty)
            .map((e) => e.address)
            .toList();

        return ContactModel(
          recordId: contact.id,
          displayName: contact.displayName,
          phoneNumbers: phones,
          emailAddresses: emails,
        );
      }).toList();
    } catch (e) {
      print('[ContactsService] Error fetching contacts: $e');
      // Fallback to mock data for development/testing
      print('[ContactsService] Falling back to mock data');
      return _getMockContacts();
    }
  }

  /// Get contacts with valid phone numbers
  Future<List<ContactModel>> getValidContacts() async {
    final allContacts = await getAllContacts();
    return allContacts
        .where((contact) =>
            contact.phoneNumbers.isNotEmpty &&
            contact.phoneNumbers.any((phone) => PhoneFormatter.isValidPhone(phone)))
        .toList();
  }

  /// Search contacts by name or phone
  Future<List<ContactModel>> searchContacts(String query) async {
    if (query.isEmpty) {
      return getValidContacts();
    }

    final allContacts = await getValidContacts();
    final lowerQuery = query.toLowerCase();

    return allContacts
        .where((contact) =>
            contact.displayName.toLowerCase().contains(lowerQuery) ||
            contact.phoneNumbers.any((phone) =>
                PhoneFormatter.normalizePhone(phone).contains(lowerQuery)))
        .toList();
  }

  /// Mock contacts data (for development)
  List<ContactModel> _getMockContacts() {
    return [
      ContactModel(
        recordId: '1',
        displayName: 'Amit Kumar',
        phoneNumbers: ['+91 98765 43210'],
        emailAddresses: ['amit@example.com'],
      ),
      ContactModel(
        recordId: '2',
        displayName: 'Priya Singh',
        phoneNumbers: ['+91 97654 32109'],
        emailAddresses: ['priya@example.com'],
      ),
      ContactModel(
        recordId: '3',
        displayName: 'Rahul Patel',
        phoneNumbers: ['+91 96543 21098'],
        emailAddresses: ['rahul@example.com'],
      ),
      ContactModel(
        recordId: '4',
        displayName: 'Neha Verma',
        phoneNumbers: ['+91 95432 10987'],
        emailAddresses: ['neha@example.com'],
      ),
      ContactModel(
        recordId: '5',
        displayName: 'Sanjay Gupta',
        phoneNumbers: ['+91 94321 09876'],
        emailAddresses: ['sanjay@example.com'],
      ),
      ContactModel(
        recordId: '6',
        displayName: 'Anjali Sharma',
        phoneNumbers: ['+91 93210 98765'],
        emailAddresses: ['anjali@example.com'],
      ),
      ContactModel(
        recordId: '7',
        displayName: 'Vikram Singh',
        phoneNumbers: ['+91 92109 87654'],
        emailAddresses: ['vikram@example.com'],
      ),
      ContactModel(
        recordId: '8',
        displayName: 'Divya Reddy',
        phoneNumbers: ['+91 91098 76543'],
        emailAddresses: ['divya@example.com'],
      ),
      ContactModel(
        recordId: '9',
        displayName: 'Arjun Desai',
        phoneNumbers: ['+91 90987 65432'],
        emailAddresses: ['arjun@example.com'],
      ),
      ContactModel(
        recordId: '10',
        displayName: 'Sneha Kapoor',
        phoneNumbers: ['+91 99876 54321'],
        emailAddresses: ['sneha@example.com'],
      ),
    ];
  }
}

/// Singleton instance
final contactsService = ContactsService();

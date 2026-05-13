import 'package:intl/intl.dart';

/// Date formatting utility
/// Handles relative dates, grouping headers, and display formats
class DateFormatter {
  /// Format as relative time (e.g., "2 hours ago", "3 days ago")
  static String relativeTime(DateTime dateTime) {
    return _relativeTime(dateTime);
  }

  /// Format as relative date (e.g., "Today", "2 hours ago")
  static String relative(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (date == today) {
      return _relativeTime(dateTime);
    } else if (date == yesterday) {
      return 'Yesterday';
    } else if (date.isAfter(today.subtract(const Duration(days: 7)))) {
      return DateFormat('EEEE').format(dateTime);
    } else if (date.year == today.year) {
      return DateFormat('MMM dd').format(dateTime);
    }
    return DateFormat('MMM dd, yyyy').format(dateTime);
  }

  /// Format as relative time (e.g., "2 hours ago", "3 days ago")
  static String _relativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(dateTime);
    }
  }

  /// Format as group header for activity/transaction lists
  /// e.g., "Today", "Yesterday", "January 2025"
  static String groupHeaderDate(DateTime dateTime) => groupHeader(dateTime);

  /// Format as group header for activity/transaction lists
  /// e.g., "Today", "Yesterday", "January 2025"
  static String groupHeader(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (date == today) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else if (date.year == today.year) {
      return DateFormat('MMMM dd').format(dateTime);
    }
    return DateFormat('MMMM dd, yyyy').format(dateTime);
  }

  /// Format as display date (e.g., "Mon 12 Jan", "12 Jan 2024")
  static String display(DateTime dateTime) {
    final now = DateTime.now();

    if (dateTime.year == now.year) {
      return DateFormat('MMM dd').format(dateTime);
    }
    return DateFormat('MMM dd, yyyy').format(dateTime);
  }

  /// Format as full date with time (e.g., "Jan 12, 2024 at 2:30 PM")
  static String fullDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy \'at\' hh:mm a').format(dateTime);
  }

  /// Format as time only (e.g., "2:30 PM")
  static String timeOnly(DateTime dateTime) {
    return DateFormat('hh:mm a').format(dateTime);
  }

  /// Format as month header (e.g., "January 2025")
  static String monthHeader(DateTime dateTime) {
    return DateFormat('MMMM yyyy').format(dateTime);
  }

  /// Get greeting based on time of day
  static String getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else if (hour < 21) {
      return 'Good evening';
    }
    return 'Good night';
  }

  /// Format date for input field (e.g., "12/01/2024")
  static String inputFormat(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  /// Parse input format date string back to DateTime
  static DateTime? parseInputFormat(String dateString) {
    try {
      return DateFormat('dd/MM/yyyy').parse(dateString);
    } catch (e) {
      return null;
    }
  }

  /// Check if date is today
  static bool isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  /// Check if date is yesterday
  static bool isYesterday(DateTime dateTime) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return dateTime.year == yesterday.year &&
        dateTime.month == yesterday.month &&
        dateTime.day == yesterday.day;
  }

  /// Format duration (e.g., "2d 3h ago")
  static String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ago';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ago';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ago';
    }
    return '${duration.inSeconds}s ago';
  }
}

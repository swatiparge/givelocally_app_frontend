import '../models/donation.dart';

/// Mock data for demonstration purposes
/// These are sample locations around Hyderabad, India
class MockData {
  static List<Donation> getSampleDonations() {
    return [
      Donation(
        id: 'don_001',
        latitude: 17.3850,
        longitude: 78.4867,
        category: 'food',
        title: 'Fresh Home-cooked Meals',
        snippet: '2 servings of rice and curry',
        description: 'Prepared today morning. Vegetarian. Pickup by 8 PM.',
        donorName: 'Priya Sharma',
        condition: 'fresh',
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Donation(
        id: 'don_002',
        latitude: 17.3900,
        longitude: 78.4800,
        category: 'appliances',
        title: 'Microwave Oven',
        snippet: 'Working condition, 2 years old',
        description:
            'LG microwave in good working condition. Moving out, need to give away.',
        donorName: 'Rahul Kumar',
        condition: 'good',
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      Donation(
        id: 'don_003',
        latitude: 17.3750,
        longitude: 78.4950,
        category: 'blood',
        title: 'Urgent: O+ Blood Needed',
        snippet: 'Apollo Hospital, critical',
        description:
            'Patient needs 2 units of O+ blood at Apollo Hospital. Please contact immediately.',
        donorName: 'Meera Reddy',
        condition: 'urgent',
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      Donation(
        id: 'don_004',
        latitude: 17.3950,
        longitude: 78.4750,
        category: 'stationery',
        title: 'Class 10 CBSE Books',
        snippet: 'Complete set, good condition',
        description:
            'Mathematics, Science, Social Studies textbooks. Some pencil marks.',
        donorName: 'Amit Singh',
        condition: 'good',
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      Donation(
        id: 'don_005',
        latitude: 17.3800,
        longitude: 78.4900,
        category: 'food',
        title: 'Bread and Vegetables',
        snippet: 'Fresh vegetables from market',
        description:
            '2 loaves of bread, tomatoes, onions, potatoes. Best before tomorrow.',
        donorName: 'Sunita Devi',
        condition: 'fresh',
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Donation(
        id: 'don_006',
        latitude: 17.3880,
        longitude: 78.4850,
        category: 'appliances',
        title: 'Table Fan',
        snippet: '3-speed, working perfectly',
        description: 'Crompton table fan. Used for 1 year. All speeds working.',
        donorName: 'Vijay Rao',
        condition: 'good',
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      Donation(
        id: 'don_007',
        latitude: 17.3820,
        longitude: 78.4780,
        category: 'blood',
        title: 'A- Blood Required',
        snippet: 'Yashoda Hospital',
        description: 'Surgery scheduled tomorrow. Need 1 unit of A- blood.',
        donorName: 'Dr. Krishna',
        condition: 'urgent',
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Donation(
        id: 'don_008',
        latitude: 17.3920,
        longitude: 78.4920,
        category: 'stationery',
        title: 'Notebook Bundle',
        snippet: '10 unused notebooks',
        description: 'A4 size ruled notebooks. Perfect for students.',
        donorName: 'Lakshmi N',
        condition: 'new',
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      Donation(
        id: 'don_009',
        latitude: 17.3780,
        longitude: 78.4820,
        category: 'food',
        title: 'Rice and Dal',
        snippet: '5 kg rice, 2 kg dal',
        description: 'Sealed packets. Expiry date: 6 months from now.',
        donorName: 'Ramesh G',
        condition: 'new',
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      Donation(
        id: 'don_010',
        latitude: 17.3860,
        longitude: 78.4880,
        category: 'appliances',
        title: 'Water Purifier',
        snippet: 'Kent RO, needs filter change',
        description:
            'Working condition. Filter needs replacement. Pickup only.',
        donorName: 'Suresh K',
        condition: 'fair',
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(hours: 7)),
      ),
    ];
  }

  /// Filter donations by category
  static List<Donation> getDonationsByCategory(String category) {
    return getSampleDonations().where((d) => d.category == category).toList();
  }

  /// Get donation by ID
  static Donation? getDonationById(String id) {
    try {
      return getSampleDonations().firstWhere((d) => d.id == id);
    } catch (e) {
      return null;
    }
  }
}

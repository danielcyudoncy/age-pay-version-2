/// Canonical list of the 36 States in Nigeria plus the Federal Capital Territory (FCT).
const List<String> kNigerianStates = [
  'Abia',
  'Adamawa',
  'Akwa Ibom',
  'Anambra',
  'Bauchi',
  'Bayelsa',
  'Benue',
  'Borno',
  'Cross River',
  'Delta',
  'Ebonyi',
  'Edo',
  'Ekiti',
  'Enugu',
  'FCT - Abuja',
  'Gombe',
  'Imo',
  'Jigawa',
  'Kaduna',
  'Kano',
  'Katsina',
  'Kebbi',
  'Kogi',
  'Kwara',
  'Lagos',
  'Nasarawa',
  'Niger',
  'Ogun',
  'Ondo',
  'Osun',
  'Oyo',
  'Plateau',
  'Rivers',
  'Sokoto',
  'Taraba',
  'Yobe',
  'Zamfara',
];

/// Common diaspora & commercial state hubs where traditional age grades frequently establish chapters.
const List<String> kCommonAgeGradeHubs = [
  'Lagos',
  'FCT - Abuja',
  'Rivers',
  'Abia',
  'Anambra',
  'Enugu',
  'Imo',
  'Delta',
  'Kano',
  'Oyo',
];

/// Standardizes branch naming convention for a Nigerian state.
String getStandardBranchName(String state) {
  final clean = state.trim();
  if (clean == 'FCT - Abuja' || clean == 'Abuja' || clean == 'FCT') {
    return 'Abuja Branch';
  }
  if (clean.toLowerCase().endsWith('branch')) {
    return clean;
  }
  return '$clean Branch';
}

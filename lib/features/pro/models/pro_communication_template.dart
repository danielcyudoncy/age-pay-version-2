// features/pro/models/pro_communication_template.dart

class ProCommunicationTemplate {
  final String id;
  final String name;
  final String title;
  final String body;
  final String urgency;
  final String category;

  const ProCommunicationTemplate({
    required this.id,
    required this.name,
    required this.title,
    required this.body,
    this.urgency = 'normal',
    this.category = 'General',
  });

  static const List<ProCommunicationTemplate> defaultTemplates = [
    ProCommunicationTemplate(
      id: 'meeting_notice',
      name: 'Meeting Notice',
      title: 'General Assembly Meeting Notice',
      body:
          'Greetings esteemed members. Please be reminded of our upcoming general meeting. '
          'Attendance is mandatory, roll call will be recorded, and punctuality is requested. '
          'Check the Community Calendar in your AgePay app for agenda and details.',
      urgency: 'important',
      category: 'Meetings',
    ),
    ProCommunicationTemplate(
      id: 'dues_reminder',
      name: 'Dues & Levies Reminder',
      title: 'Outstanding Dues & Levies Settlement Reminder',
      body:
          'Dear members, kindly check your AgePay dashboard and settle all outstanding monthly dues '
          'and active project levies. Timely contribution enables us to execute projects smoothly. '
          'Instant digital receipts are issued upon payment.',
      urgency: 'normal',
      category: 'Finance',
    ),
    ProCommunicationTemplate(
      id: 'urgent_notice',
      name: 'Urgent Advisory',
      title: 'URGENT: Executive Community Advisory',
      body:
          'Please take note of this urgent advisory regarding member welfare and organisational decorum. '
          'All members are expected to comply with the standard guidelines. '
          'Thank you for your prompt cooperation.',
      urgency: 'urgent',
      category: 'Advisory',
    ),
    ProCommunicationTemplate(
      id: 'community_event',
      name: 'Community Mobilization',
      title: 'Special Community Mobilization & Event',
      body:
          'All members are warmly invited to participate in our upcoming community mobilization event. '
          'Your active participation, attendance, and unity strengthen our community. '
          'United we stand!',
      urgency: 'normal',
      category: 'Events',
    ),
    ProCommunicationTemplate(
      id: 'goodwill_wishes',
      name: 'Goodwill & Felicitation',
      title: 'Warm Goodwill Greetings to All Members',
      body:
          'The executives and the entire organisation family extend warm goodwill greetings and congratulations '
          'to our members and their families on this special occasion. '
          'May peace, prosperity, and success abide with us all.',
      urgency: 'normal',
      category: 'Social',
    ),
  ];
}

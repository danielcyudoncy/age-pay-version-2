/// Bindings for the secretary feature.
///
/// Aggregates models, repositories, controllers, and views for
/// dependency injection and easy imports.
library;

export "../models/announcement_model.dart";
export "../models/attendance_model.dart";
export "../models/document_model.dart";
export "../models/calendar_event_model.dart";
export "../repositories/announcement_repository.dart";
export "../repositories/attendance_repository.dart";
export "../repositories/document_repository.dart";
export "../repositories/calendar_event_repository.dart";
export "../controllers/secretary_dashboard_provider.dart";
export "../controllers/search_provider.dart";
export "../views/secretary_dashboard.dart";
export "../views/members_management_screen.dart";
export "../views/announcements_screen.dart";
export "../views/attendance_screen.dart";
export "../views/documents_screen.dart";
export "../views/calendar_screen.dart";
export "../views/search_screen.dart";
export "../views/secretary_profile_screen.dart";
export "../../settings/views/settings_screen.dart";
export "../../settings/views/help_screen.dart";

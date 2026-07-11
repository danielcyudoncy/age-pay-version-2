/// Bindings for the dashboard feature.
///
/// This file aggregates all controllers, models, repositories,
/// services, and widgets for dependency injection and easy imports.
library;

export "../controllers/member_dashboard_provider.dart";
export "../controllers/president_dashboard_provider.dart";
export "../controllers/treasurer_dashboard_provider.dart" hide totalMembersProvider;

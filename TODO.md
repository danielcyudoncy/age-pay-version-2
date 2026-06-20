# TODO - Production mode cleanup

- [x] Remove/disable demo mode wiring (DEMO_MODE / kForceDemo) so app never seeds demo data in production.

- [ ] Ensure no demo code is imported/compiled in main app runtime (remove lib/demo usage from lib/main.dart).
- [x] Optionally restrict demo overrides file to non-production builds only (if still needed for tests/dev).

- [ ] Run `flutter test` (and/or `flutter analyze`) to confirm no breakages.


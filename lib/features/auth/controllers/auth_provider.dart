import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../../../core/constants/enums.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Resolves the organizationId the current user belongs to. For org owners
/// (secretary/admin/president) this is their own id, which matches the tenant
/// key used when announcements were created. For members whose profile may not
/// yet carry an organizationId, it falls back to the existing organization's
/// id so they read the same shared announcements.
final organizationIdProvider = FutureProvider.autoDispose<String>((ref) async {
  final authState = ref.watch(authProvider);
  final user = authState.valueOrNull;
  if (user != null && user.organizationId.isNotEmpty) {
    return user.organizationId;
  }
  if (user == null) return '';
  return ref.watch(authServiceProvider).getActiveOrganizationId();
});

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
      final authService = ref.watch(authServiceProvider);
      return AuthNotifier(authService);
    });

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      state = const AsyncValue.data(null);
      final user = await _authService.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.signInWithEmailAndPassword(
        email,
        password,
      );
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String phoneNumber,
    required UserRole role,
    required String organizationId,
    DateTime? dateOfBirth,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.registerWithEmailAndPassword(
        email: email,
        password: password,
        displayName: displayName,
        phoneNumber: phoneNumber,
        role: role,
        organizationId: organizationId,
        dateOfBirth: dateOfBirth,
      );
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> refreshUser() async {
    try {
      final user = await _authService.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void setUser(UserModel user) {
    state = AsyncValue.data(user);
  }
}

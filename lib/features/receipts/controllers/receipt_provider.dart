import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/features/receipts/models/receipt_model.dart';
import 'package:cls/features/receipts/repositories/receipt_repository.dart';
import 'package:cls/features/receipts/services/receipt_service.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../admin/controllers/admin_provider.dart';

final receiptRepositoryProvider = Provider<ReceiptRepository>((ref) {
  return ReceiptRepository();
});

final _receiptServiceProvider = Provider<ReceiptService>((ref) {
  return ReceiptService();
});

/// Stream of all receipts for a specific member.
final memberReceiptsStreamProvider = StreamProvider.autoDispose
    .family<List<ReceiptModel>, String>((ref, memberId) {
      final repo = ref.watch(receiptRepositoryProvider);
      return repo.getMemberReceipts(memberId);
    });

/// FutureProvider for a single receipt by ID.
final receiptByIdProvider = FutureProvider.autoDispose
    .family<ReceiptModel?, String>((ref, receiptId) {
      final repo = ref.watch(receiptRepositoryProvider);
      return repo.getReceiptById(receiptId);
    });

/// FutureProvider for a single receipt by payment ID.
final receiptByPaymentIdProvider = FutureProvider.autoDispose
    .family<ReceiptModel?, String>((ref, paymentId) {
      final repo = ref.watch(receiptRepositoryProvider);
      return repo.getReceiptByPaymentId(paymentId);
    });

/// FutureProvider that generates PDF bytes for a receipt.
final receiptPdfGenerationProvider = FutureProvider.autoDispose
    .family<Uint8List, ReceiptModel>((ref, receipt) async {
      final service = ref.watch(_receiptServiceProvider);
      String orgName = 'Age Grade Association';
      try {
        final orgId = await ref.watch(organizationIdProvider.future);
        if (orgId.isNotEmpty) {
          final org = await ref
              .watch(organizationRepositoryProvider)
              .getOrganizationById(orgId);
          if (org != null && org.name.isNotEmpty) {
            orgName = org.name;
          }
        }
      } catch (_) {}
      return service.generateReceiptPdf(
        receipt: receipt,
        associationName: orgName,
      );
    });

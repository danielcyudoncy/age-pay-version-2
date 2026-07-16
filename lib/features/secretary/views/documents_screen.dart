import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/secretary/controllers/document_provider.dart';
import 'package:cls/features/secretary/models/document_model.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  final _picker = ImagePicker();
  DocumentCategory _selectedCategory = DocumentCategory.otherDocuments;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;
    final orgId = user?.uid ?? '';
    final documentsAsync = ref.watch(documentsStreamProvider(orgId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () => _showUploadDialog(context, user),
          ),
        ],
      ),
      body: documentsAsync.when(
        data: (documents) {
          if (documents.isEmpty) {
            return Center(
              child: Column(
                children: [
                  Icon(Icons.folder_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No documents uploaded yet'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(documentsStreamProvider(orgId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: documents.length,
              itemBuilder: (context, index) {
                final doc = documents[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _categoryColor(doc.category).withValues(alpha: 0.12),
                      child: Icon(_categoryIcon(doc.category), color: _categoryColor(doc.category), size: 20),
                    ),
                    title: Text(doc.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${doc.category.name.replaceAll('_', ' ').toUpperCase()} \u2022 ${_formatSize(doc.fileSize)}'),
                    trailing: IconButton(icon: const Icon(Icons.download, size: 18), onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final uri = Uri.parse(doc.fileUrl);
                      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
                      if (!success && mounted) {
                        messenger.showSnackBar(const SnackBar(content: Text('Could not open file')));
                      }
                    }),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Error: $error', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => ref.invalidate(documentsStreamProvider(orgId)), child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }

  void _showUploadDialog(BuildContext context, UserModel? user) {
    if (user == null) return;
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    File? pickedFile;
    String pickedFileName = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Upload Document'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 12),
                TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
                const SizedBox(height: 12),
                DropdownButtonFormField<DocumentCategory>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: DocumentCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.name.replaceAll('_', ' ').toUpperCase()))).toList(),
                  onChanged: (v) { if (v != null) setDialogState(() => _selectedCategory = v); },
                ),
                const SizedBox(height: 12),
                if (pickedFile != null)
                  Card(
                    child: ListTile(
                      title: Text(pickedFileName),
                      subtitle: const Text('Ready to upload'),
                      trailing: IconButton(icon: const Icon(Icons.close), onPressed: () {
                        setDialogState(() {
                          pickedFile = null;
                          pickedFileName = '';
                        });
                      }),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await _picker.pickImage(source: ImageSource.gallery);
                      if (picked != null) {
                        setDialogState(() {
                          pickedFile = File(picked.path);
                          pickedFileName = picked.name;
                        });
                      }
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Select File'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty || pickedFile == null) return;
                final controller = ref.read(documentControllerProvider);
                final doc = DocumentModel(
                  id: '',
                  organizationId: user.uid,
                  title: titleController.text.trim(),
                  description: descriptionController.text.trim(),
                  category: _selectedCategory,
                  fileUrl: '',
                  fileName: pickedFileName,
                  fileSize: 0,
                  mimeType: 'image/jpeg',
                  uploadedBy: user.uid,
                  uploadedAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                final docId = await controller.createDocument(doc);
                final result = await controller.uploadFile(docId, pickedFile!, pickedFileName);
                await controller.updateDocument(doc.copyWith(id: docId, fileUrl: result['url']!));
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(documentsStreamProvider(user.uid));
              },
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(DocumentCategory category) {
    switch (category) {
      case DocumentCategory.constitution: return Colors.brown;
      case DocumentCategory.meetingMinutes: return Colors.blue;
      case DocumentCategory.reports: return Colors.green;
      case DocumentCategory.financialReports: return Colors.teal;
      case DocumentCategory.membershipForms: return Colors.purple;
      case DocumentCategory.policies: return Colors.orange;
      case DocumentCategory.images: return Colors.pink;
      case DocumentCategory.videos: return Colors.red;
      case DocumentCategory.otherDocuments: return Colors.grey;
    }
  }

  IconData _categoryIcon(DocumentCategory category) {
    switch (category) {
      case DocumentCategory.constitution: return Icons.gavel;
      case DocumentCategory.meetingMinutes: return Icons.description;
      case DocumentCategory.reports: return Icons.assessment;
      case DocumentCategory.financialReports: return Icons.account_balance_wallet;
      case DocumentCategory.membershipForms: return Icons.person_add;
      case DocumentCategory.policies: return Icons.policy;
      case DocumentCategory.images: return Icons.image;
      case DocumentCategory.videos: return Icons.video_library;
      case DocumentCategory.otherDocuments: return Icons.insert_drive_file;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

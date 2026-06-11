import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

class FeedbackView extends ConsumerStatefulWidget {
  const FeedbackView({super.key});

  @override
  ConsumerState<FeedbackView> createState() => _FeedbackViewState();
}

class _FeedbackType {
  const _FeedbackType(this.value, this.label);

  final String value;
  final String label;
}

class _FeedbackViewState extends ConsumerState<FeedbackView> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _contactController = TextEditingController();
  final List<File> _screenshots = [];
  String _type = 'APP_BUG';

  @override
  void dispose() {
    _descriptionController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  List<_FeedbackType> _feedbackTypes(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return [
      _FeedbackType('APP_BUG', appLocalizations.appBug),
      _FeedbackType('CONNECTION_ISSUE', appLocalizations.connectionIssue),
      _FeedbackType('SPEED_ISSUE', appLocalizations.speedIssue),
      _FeedbackType('ACCOUNT_ISSUE', appLocalizations.accountIssue),
      _FeedbackType('SUGGESTION', appLocalizations.suggestion),
      _FeedbackType('OTHER', appLocalizations.otherFeedback),
    ];
  }

  Future<void> _pickScreenshots() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      initialDirectory: await appPath.downloadDirPath,
    );
    final files = result?.files ?? [];
    if (files.isEmpty) return;
    setState(() {
      for (final file in files) {
        final path = file.path;
        if (path == null || _screenshots.any((item) => item.path == path)) {
          continue;
        }
        _screenshots.add(File(path));
      }
    });
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final loadingNotifier = ref.read(
      loadingProvider(LoadingTag.feedback).notifier,
    );
    loadingNotifier.start();
    try {
      final imageUrls = <String>[];
      for (final screenshot in _screenshots) {
        final uploadedFile = await request.uploadFeedbackImage(screenshot);
        imageUrls.add(uploadedFile.url);
      }
      await request.submitFeedback(
        type: _type,
        description: _descriptionController.text.trim(),
        contact: _contactController.text.trim(),
        imageUrls: imageUrls,
      );
      if (!mounted) return;
      context.showNotifier(context.appLocalizations.feedbackSubmitSuccess);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      await globalState.showMessage(
        title: context.appLocalizations.feedbackSubmitFailed,
        message: TextSpan(text: e.toString()),
      );
    } finally {
      await loadingNotifier.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final feedbackTypes = _feedbackTypes(context);
    final isLoading = ref.watch(loadingProvider(LoadingTag.feedback));
    return CommonScaffold(
      title: appLocalizations.feedback,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16).copyWith(bottom: 88),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.category_outlined),
                border: const OutlineInputBorder(),
                labelText: appLocalizations.feedbackType,
              ),
              items: feedbackTypes
                  .map(
                    (type) => DropdownMenuItem(
                      value: type.value,
                      child: Text(type.label),
                    ),
                  )
                  .toList(),
              onChanged: isLoading
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _type = value;
                      });
                    },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              enabled: !isLoading,
              minLines: 5,
              maxLines: 8,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.notes_outlined),
                border: const OutlineInputBorder(),
                labelText: appLocalizations.feedbackContent,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return appLocalizations.emptyTip(
                    appLocalizations.feedbackContent,
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactController,
              enabled: !isLoading,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.alternate_email_outlined),
                border: const OutlineInputBorder(),
                labelText: appLocalizations.contact,
              ),
            ),
            const SizedBox(height: 16),
            CommonCard(
              onPressed: isLoading ? null : _pickScreenshots,
              child: Padding(
                padding: baseInfoEdgeInsets,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.image_outlined,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            appLocalizations.screenshot,
                            style: context.textTheme.titleSmall?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: appLocalizations.addScreenshot,
                          onPressed: isLoading ? null : _pickScreenshots,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                        ),
                      ],
                    ),
                    if (_screenshots.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          appLocalizations.noScreenshot,
                          style: context.textTheme.bodySmall?.toLight,
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final file in _screenshots)
                              InputChip(
                                label: Text(
                                  p.basename(file.path),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onDeleted: isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          _screenshots.remove(file);
                                        });
                                      },
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: isLoading ? null : _submit,
              icon: isLoading
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(
                isLoading
                    ? appLocalizations.submitting
                    : appLocalizations.submitFeedback,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

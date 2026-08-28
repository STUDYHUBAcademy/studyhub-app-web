import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/contact_links.dart';
import '../../../../core/utils/reauth.dart';
import '../../../../core/widgets/realtime_error_view.dart';
import '../../domain/entities/marketer.dart';
import '../providers/marketers_providers.dart';

Future<void> _editMarketer(
  BuildContext context,
  WidgetRef ref, {
  Marketer? marketer,
}) async {
  final nameController = TextEditingController(text: marketer?.name ?? '');
  final phoneController = TextEditingController(
    text: marketer?.phoneWhatsapp ?? '',
  );
  final commissionController = TextEditingController(
    text: marketer?.defaultCommissionAmount != null
        ? marketer!.defaultCommissionAmount!.toStringAsFixed(0)
        : '',
  );
  final notesController = TextEditingController(text: marketer?.notes ?? '');
  String? formError;

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(marketer == null ? 'إضافة مسوق' : 'تعديل بيانات المسوق'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم المسوق'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'رقم الواتساب (اختياري)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commissionController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'عمولة افتراضية (مبلغ، اختياري)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                  ),
                ),
                if (formError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    formError!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                setState(() => formError = 'لازم تكتب اسم المسوق');
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );

  if (saved != true) return;
  final commissionAmount = double.tryParse(commissionController.text.trim());
  if (marketer == null) {
    await ref
        .read(marketersRepositoryProvider)
        .addMarketer(
          name: nameController.text.trim(),
          phoneWhatsapp: phoneController.text.trim().isEmpty
              ? null
              : phoneController.text.trim(),
          defaultCommissionAmount: commissionAmount,
          notes: notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
        );
  } else {
    await ref
        .read(marketersRepositoryProvider)
        .updateMarketer(
          id: marketer.id,
          name: nameController.text.trim(),
          phoneWhatsapp: phoneController.text.trim().isEmpty
              ? null
              : phoneController.text.trim(),
          defaultCommissionAmount: commissionAmount,
          notes: notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
        );
  }
}

class MarketersScreen extends ConsumerStatefulWidget {
  const MarketersScreen({super.key});

  @override
  ConsumerState<MarketersScreen> createState() => _MarketersScreenState();
}

class _MarketersScreenState extends ConsumerState<MarketersScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _delete(Marketer marketer) async {
    final confirmed = await confirmWithPassword(
      context,
      title: 'حذف المسوق نهائيًا',
      message:
          'هيتم حذف "${marketer.name}" نهائيًا — التسجيلات القديمة اللي فيها اسمه هتفضل زي ما هي. اكتب كلمة المرور للتأكيد.',
    );
    if (!confirmed) return;
    await ref.read(marketersRepositoryProvider).deleteMarketer(marketer.id);
  }

  @override
  Widget build(BuildContext context) {
    final marketersAsync = ref.watch(marketersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('📣 المسوقين')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editMarketer(context, ref),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'ابحث بالاسم',
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: marketersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => RealtimeErrorView(
                error: err,
                onRetry: () => ref.invalidate(marketersProvider),
              ),
              data: (marketers) {
                final filtered = _query.isEmpty
                    ? marketers
                    : marketers
                          .where(
                            (m) => m.name.toLowerCase().contains(
                              _query.toLowerCase(),
                            ),
                          )
                          .toList();
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'مفيش مسوقين مطابقين',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 90),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final m = filtered[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(m.name),
                        subtitle: Text(
                          [
                            ?m.phoneWhatsapp,
                            if (m.defaultCommissionAmount != null)
                              'عمولة افتراضية: ${m.defaultCommissionAmount!.toStringAsFixed(0)}',
                          ].join(' • '),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (m.phoneWhatsapp != null)
                              IconButton(
                                icon: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 20,
                                  color: AppColors.success,
                                ),
                                onPressed: () =>
                                    launchWhatsapp(m.phoneWhatsapp!),
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () =>
                                  _editMarketer(context, ref, marketer: m),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: AppColors.textMuted,
                              ),
                              onPressed: () => _delete(m),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/contact_links.dart';
import '../../../../core/utils/reauth.dart';
import '../../../../core/widgets/realtime_error_view.dart';
import '../../domain/entities/student.dart';
import '../providers/students_providers.dart';
import '../widgets/student_source_fields.dart';

Future<void> _editStudent(
  BuildContext context,
  WidgetRef ref,
  Student student,
) async {
  final nameController = TextEditingController(text: student.name);
  final phoneController = TextEditingController(
    text: student.phoneWhatsapp ?? '',
  );
  String? formError;

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Text('تعديل بيانات الطالب'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم الطالب'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'رقم الواتساب'),
                ),
                const SizedBox(height: 4),
                const Text(
                  'مصدر الطالب (مباشر / حراج / مسوق) بيتحدد لكل كورس أو حصة على حدة — عدّله من صفحة الكورس أو الحصة نفسها.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
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
                setState(() => formError = 'لازم تكتب اسم الطالب');
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
  await ref
      .read(studentsRepositoryProvider)
      .updateStudent(
        id: student.id,
        name: nameController.text.trim(),
        phoneWhatsapp: phoneController.text.trim().isEmpty
            ? null
            : phoneController.text.trim(),
        acquisitionSource: student.acquisitionSource,
        marketerName: student.marketerName,
        commissionPct: student.commissionPct,
        commissionAmount: student.commissionAmount,
      );
}

Future<void> _deleteStudent(
  BuildContext context,
  WidgetRef ref,
  Student student,
) async {
  final confirmed = await confirmWithPassword(
    context,
    title: 'حذف الطالب نهائيًا',
    message:
        'هيتم حذف "${student.name}" وكل تسجيلاته في الكورسات نهائيًا. اكتب كلمة المرور للتأكيد.',
  );
  if (!confirmed) return;
  try {
    await ref.read(studentsRepositoryProvider).deleteStudent(student.id);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('حصل خطأ أثناء الحذف: $e')));
    }
  }
}

class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addStudent() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String source = 'direct';
    String? marketerName;
    double? commissionPct;
    double? commissionAmount;
    String? formError;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const Text('إضافة طالب'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'اسم الطالب'),
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
                  const SizedBox(height: 4),
                  StudentSourceFields(
                    onChanged: (s, m, pct, amount) {
                      source = s;
                      marketerName = m;
                      commissionPct = pct;
                      commissionAmount = amount;
                    },
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
                  setState(() => formError = 'لازم تكتب اسم الطالب');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    try {
      await ref
          .read(studentsRepositoryProvider)
          .addStudent(
            name: nameController.text.trim(),
            phoneWhatsapp: phoneController.text.trim().isEmpty
                ? null
                : phoneController.text.trim(),
            acquisitionSource: source,
            marketerName: marketerName,
            commissionPct: commissionPct,
            commissionAmount: commissionAmount,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حصل خطأ أثناء إضافة الطالب: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('👨‍🎓 الطلاب')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addStudent,
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
            child: studentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => RealtimeErrorView(
                error: err,
                onRetry: () => ref.invalidate(studentsProvider),
              ),
              data: (students) {
                final filtered = _query.isEmpty
                    ? students
                    : students
                          .where(
                            (s) => s.name.toLowerCase().contains(
                              _query.toLowerCase(),
                            ),
                          )
                          .toList();
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'مفيش طلاب مطابقين',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final s = filtered[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(s.name),
                        subtitle: s.phoneWhatsapp != null
                            ? Text(
                                s.phoneWhatsapp!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (s.phoneWhatsapp != null)
                              IconButton(
                                icon: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 20,
                                  color: AppColors.success,
                                ),
                                onPressed: () =>
                                    launchWhatsapp(s.phoneWhatsapp!),
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _editStudent(context, ref, s),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: AppColors.textMuted,
                              ),
                              onPressed: () => _deleteStudent(context, ref, s),
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

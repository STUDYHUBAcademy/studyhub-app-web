import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/acquisition_source.dart';
import '../../../../core/utils/contact_links.dart';
import '../../../../core/utils/reauth.dart';
import '../../../../core/widgets/phone_number_field.dart';
import '../../../../core/widgets/realtime_error_view.dart';
import '../../../courses/domain/entities/enrollment.dart';
import '../../../courses/domain/entities/tutor_payment.dart';
import '../../../courses/presentation/providers/courses_providers.dart';
import '../../../students/domain/entities/student.dart';
import '../../../students/presentation/providers/students_providers.dart';
import '../../../students/presentation/widgets/student_source_fields.dart';
import '../../../tutors/domain/entities/tutor.dart';
import '../../../settings/presentation/providers/app_settings_providers.dart';
import '../../../tutors/presentation/providers/tutors_providers.dart';
import '../../domain/entities/private_session.dart';
import '../providers/sessions_providers.dart';

const _statusLabels = {
  'scheduled': 'مجدولة',
  'completed': 'مكتملة',
  'cancelled': 'ملغاة',
};
const _statusColors = {
  'scheduled': AppColors.info,
  'completed': AppColors.success,
  'cancelled': AppColors.error,
};
const _paymentMethodLabels = {
  'cash': '💵 كاش',
  'visa': '💳 فيزا',
  'tabby': '🟣 تابي',
  'tamara': '🟢 تمارا',
};
const _ledgerTypeLabels = {
  'deposit': 'دفعة',
  'final_settlement': 'تسوية نهائية',
  'revshare_payout': 'نسبة من الإيراد',
  'private_session_payout': 'دفعة حصة خصوصي',
};

String _fmtMoney(double v) =>
    v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);

String _fmtDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m د';
  if (m == 0) return '$h س';
  return '$h س $m د';
}

class _NamePick<T> {
  const _NamePick({this.selected, required this.name, this.phone});
  final T? selected;
  final String name;
  final String? phone;
}

/// A search-as-you-type picker: filters [items] by [nameOf] as the user
/// types, with a leading "add new" row whenever the typed text doesn't
/// exactly match an existing item. Implemented as a plain nested dialog
/// (not a dropdown/autocomplete overlay) so it behaves predictably inside
/// an already-scrollable AlertDialog on mobile.
///
/// When [requirePhoneForNew] is set, adding a brand-new entry also requires
/// a WhatsApp number (so reminder messages can actually reach them later).
Future<_NamePick<T>?> _pickWithSearch<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required String Function(T) nameOf,
  String initialQuery = '',
  bool requirePhoneForNew = false,
}) {
  final controller = TextEditingController(text: initialQuery);
  String? composedPhone;
  return showDialog<_NamePick<T>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final query = controller.text.trim();
        final lowerQuery = query.toLowerCase();
        final filtered = lowerQuery.isEmpty
            ? items
            : items
                  .where((i) => nameOf(i).toLowerCase().contains(lowerQuery))
                  .toList();
        final exactMatch = items.any(
          (i) => nameOf(i).toLowerCase() == lowerQuery,
        );
        final showAddNew = query.isNotEmpty && !exactMatch;

        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            height: 420,
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'ابحث بالاسم أو اكتب اسم جديد',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (showAddNew && requirePhoneForNew) ...[
                  const SizedBox(height: 8),
                  PhoneNumberField(
                    label: 'رقم الواتساب *',
                    onChanged: (v) => composedPhone = v,
                  ),
                ],
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      if (showAddNew)
                        ListTile(
                          leading: const Icon(
                            Icons.add,
                            color: AppColors.accent,
                          ),
                          title: Text(
                            'إضافة "$query" كجديد',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onTap: () {
                            if (requirePhoneForNew && composedPhone == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('لازم تكتب رقم الواتساب'),
                                ),
                              );
                              return;
                            }
                            Navigator.pop(
                              context,
                              _NamePick<T>(name: query, phone: composedPhone),
                            );
                          },
                        ),
                      for (final item in filtered)
                        ListTile(
                          title: Text(nameOf(item)),
                          onTap: () => Navigator.pop(
                            context,
                            _NamePick<T>(selected: item, name: nameOf(item)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
          ],
        );
      },
    ),
  );
}

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  String _statusFilter = 'scheduled';

  Future<void> _openSessionForm(
    BuildContext context,
    WidgetRef ref, {
    required List<Tutor> tutors,
    required List<Student> students,
    PrivateSession? existing,
  }) async {
    _NamePick<Tutor>? tutorPick;
    if (existing != null) {
      final t = tutors.where((t) => t.id == existing.tutorId).firstOrNull;
      if (t != null) tutorPick = _NamePick(selected: t, name: t.name);
    }

    _NamePick<Student>? studentPick;
    if (existing != null) {
      final s = students.where((s) => s.id == existing.studentId).firstOrNull;
      if (s != null) studentPick = _NamePick(selected: s, name: s.name);
    }
    String? formError;
    String sessionSource = 'direct';
    String? sessionMarketer;
    double? sessionCommissionPct;
    double? sessionCommissionAmount;

    ResolvedSource initialSourceFor(Student? selected) {
      final sameStudentAsExisting =
          existing != null && selected?.id == existing.studentId;
      return resolveAcquisitionSource(
        overrideSource: sameStudentAsExisting
            ? existing.acquisitionSource
            : null,
        overrideMarketerName: sameStudentAsExisting
            ? existing.marketerName
            : null,
        overrideCommissionPct: sameStudentAsExisting
            ? existing.commissionPct
            : null,
        overrideCommissionAmount: sameStudentAsExisting
            ? existing.commissionAmount
            : null,
        studentSource: selected?.acquisitionSource,
        studentMarketerName: selected?.marketerName,
        studentCommissionPct: selected?.commissionPct,
        studentCommissionAmount: selected?.commissionAmount,
      );
    }

    final writeOffController = TextEditingController(
      text: existing != null && existing.writeOffAmount > 0.01
          ? existing.writeOffAmount.toStringAsFixed(0)
          : '',
    );
    String? writeOffReason = existing?.writeOffReason;

    final subjectController = TextEditingController(
      text: existing?.subject ?? '',
    );
    DateTime? scheduledAt = existing?.scheduledAt;
    final hoursController = TextEditingController(
      text: ((existing?.durationMinutes ?? 60) ~/ 60).toString(),
    );
    final minutesController = TextEditingController(
      text: ((existing?.durationMinutes ?? 60) % 60).toString(),
    );
    final studentHourlyRateController = TextEditingController(
      text: existing?.studentHourlyRate?.toStringAsFixed(0) ?? '',
    );
    final studentTotalController = TextEditingController(
      text: existing?.studentTotal?.toStringAsFixed(0) ?? '',
    );
    final studentReceivedController = TextEditingController(
      text: existing?.studentAmountReceived?.toStringAsFixed(0) ?? '',
    );
    final tutorHourlyRateController = TextEditingController(
      text: existing?.tutorHourlyRate?.toStringAsFixed(0) ?? '',
    );
    final tutorPayoutController = TextEditingController(
      text: existing?.tutorPayout?.toStringAsFixed(0) ?? '',
    );
    final notesController = TextEditingController(
      text: existing?.materialNote ?? '',
    );
    var studentCurrency = existing?.studentTotalCurrency ?? 'SAR';
    var tutorCurrency = existing?.tutorPayoutCurrency ?? 'EGP';
    var paymentMethod = existing?.paymentMethod ?? 'cash';
    final tabbyTamaraFeePct =
        ref.read(appSettingsProvider).valueOrNull?.tabbyTamaraFeePct ?? 8;

    void suggestGatewayFee() {
      if (paymentMethod != 'tabby' && paymentMethod != 'tamara') return;
      if (writeOffController.text.trim().isNotEmpty) return;
      final total = double.tryParse(studentTotalController.text.trim());
      if (total == null) return;
      final fee = total * tabbyTamaraFeePct / 100;
      if (fee > 0.01) {
        writeOffController.text = fee.toStringAsFixed(0);
        writeOffReason ??= 'gateway_fee';
      }
    }

    double durationHours() {
      final h = int.tryParse(hoursController.text.trim()) ?? 0;
      final m = int.tryParse(minutesController.text.trim()) ?? 0;
      return h + m / 60;
    }

    void recalcStudentTotal() {
      final rate = double.tryParse(studentHourlyRateController.text.trim());
      if (rate == null) return;
      studentTotalController.text = (rate * durationHours()).toStringAsFixed(0);
    }

    void recalcTutorPayout() {
      final rate = double.tryParse(tutorHourlyRateController.text.trim());
      if (rate == null) return;
      tutorPayoutController.text = (rate * durationHours()).toStringAsFixed(0);
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(existing == null ? 'إضافة حصة فردية' : 'تعديل الحصة'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () async {
                      final pick = await _pickWithSearch<Tutor>(
                        context: context,
                        title: 'اختيار المدرس',
                        items: tutors,
                        nameOf: (t) => t.name,
                        initialQuery: tutorPick?.name ?? '',
                      );
                      if (pick != null) setState(() => tutorPick = pick);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'المدرس *'),
                      child: Text(
                        tutorPick?.name ?? 'اضغط للاختيار أو الإضافة',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final pick = await _pickWithSearch<Student>(
                        context: context,
                        title: 'اختيار الطالب',
                        items: students,
                        nameOf: (s) => s.name,
                        initialQuery: studentPick?.name ?? '',
                        requirePhoneForNew: true,
                      );
                      if (pick != null) setState(() => studentPick = pick);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'الطالب *'),
                      child: Text(
                        studentPick?.name ?? 'اضغط للاختيار أو الإضافة',
                      ),
                    ),
                  ),
                  if (studentPick != null) ...[
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final initial = initialSourceFor(studentPick!.selected);
                        return StudentSourceFields(
                          key: ValueKey(studentPick!.selected?.id ?? 'new'),
                          initialSource: initial.source,
                          initialMarketerName: initial.marketerName,
                          initialCommissionPct: initial.commissionPct,
                          initialCommissionAmount: initial.commissionAmount,
                          onChanged: (source, marketer, pct, amount) {
                            sessionSource = source;
                            sessionMarketer = marketer;
                            sessionCommissionPct = pct;
                            sessionCommissionAmount = amount;
                          },
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(labelText: 'المادة'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: scheduledAt ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (date == null) return;
                            if (!context.mounted) return;
                            final time = await showTimePicker(
                              context: context,
                              initialTime: scheduledAt != null
                                  ? TimeOfDay.fromDateTime(scheduledAt!)
                                  : TimeOfDay.now(),
                            );
                            setState(
                              () => scheduledAt = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time?.hour ?? 0,
                                time?.minute ?? 0,
                              ),
                            );
                          },
                          child: Text(
                            scheduledAt == null
                                ? 'موعد الحصة *'
                                : intl.DateFormat(
                                    'd MMM yyyy — h:mm a',
                                    'ar',
                                  ).format(scheduledAt!),
                          ),
                        ),
                      ),
                      if (scheduledAt != null)
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => scheduledAt = null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: hoursController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'المدة (ساعات)',
                          ),
                          onChanged: (_) => setState(() {
                            recalcStudentTotal();
                            recalcTutorPayout();
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: minutesController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'المدة (دقايق)',
                          ),
                          onChanged: (_) => setState(() {
                            recalcStudentTotal();
                            recalcTutorPayout();
                          }),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text(
                    'الطالب',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: studentHourlyRateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'سعر الساعة للطالب (SAR)',
                    ),
                    onChanged: (_) => setState(recalcStudentTotal),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: studentTotalController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'إجمالي المبلغ من الطالب',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: studentCurrency,
                        items: const ['SAR', 'EGP', 'USD', 'AED']
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => studentCurrency = v ?? 'SAR'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    decoration: const InputDecoration(labelText: 'وسيلة الدفع'),
                    items: _paymentMethodLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      paymentMethod = v ?? 'cash';
                      suggestGatewayFee();
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: studentReceivedController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ الفعلي المستلم بعد الرسوم (اختياري)',
                      helperText: 'لو تابي أو تمارا خصموا رسوم — اسيبه فاضي لو مفيش خصم',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        final total = double.tryParse(
                          studentTotalController.text.trim(),
                        );
                        final received = double.tryParse(
                          studentReceivedController.text.trim(),
                        );
                        if (total == null || received == null) return;
                        final gap = total - received;
                        if (gap > 0.01) {
                          setState(() {
                            writeOffController.text = gap.toStringAsFixed(0);
                            writeOffReason ??= 'gateway_fee';
                            studentReceivedController.clear();
                          });
                        }
                      },
                      child: const Text(
                        'الفرق مش هيتحصّل؟ سجّله كخصم أو رسوم',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const Text(
                    'خصم أو رسوم بوابة دفع (اختياري)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: writeOffController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المتنازل عنه',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: writeOffReason,
                    decoration: const InputDecoration(labelText: 'السبب'),
                    items: enrollmentWriteOffReasons.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => writeOffReason = v),
                  ),
                  const Divider(height: 24),
                  const Text(
                    'المدرس',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: tutorHourlyRateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'سعر الساعة للمدرس (EGP)',
                    ),
                    onChanged: (_) => setState(recalcTutorPayout),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: tutorPayoutController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'إجمالي المبلغ المتفق عليه للمدرس',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: tutorCurrency,
                        items: const ['EGP', 'SAR', 'USD', 'AED']
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => tutorCurrency = v ?? 'EGP'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات / مواد (اختياري)',
                    ),
                  ),
                  if (formError != null) ...[
                    const SizedBox(height: 12),
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
                final missing = <String>[];
                if (tutorPick == null) missing.add('المدرس');
                if (studentPick == null) missing.add('اسم الطالب');
                if (scheduledAt == null) missing.add('موعد الحصة');
                if (missing.isNotEmpty) {
                  setState(
                    () => formError = 'لازم تحدد: ${missing.join('، ')}',
                  );
                  return;
                }
                final total = double.tryParse(
                  studentTotalController.text.trim(),
                );
                final received = double.tryParse(
                  studentReceivedController.text.trim(),
                );
                final writeOff =
                    double.tryParse(writeOffController.text.trim()) ?? 0;
                if (writeOff > 0 && writeOffReason == null) {
                  setState(() => formError = 'اختار سبب الخصم/الرسوم');
                  return;
                }
                if (total != null &&
                    (received ?? 0) + writeOff > total + 0.01) {
                  setState(
                    () => formError =
                        'المبلغ المستلم والخصم مع بعض أكبر من إجمالي مبلغ الطالب ($total)',
                  );
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
    try {
      String tutorId;
      if (tutorPick!.selected != null) {
        tutorId = tutorPick!.selected!.id;
      } else {
        final newTutor = await ref
            .read(tutorsRepositoryProvider)
            .addTutorQuick(tutorPick!.name);
        tutorId = newTutor.id;
      }

      String studentId;
      if (studentPick!.selected != null) {
        studentId = studentPick!.selected!.id;
      } else {
        final newStudent = await ref
            .read(studentsRepositoryProvider)
            .addStudent(
              name: studentPick!.name,
              phoneWhatsapp: studentPick!.phone,
              acquisitionSource: sessionSource,
              marketerName: sessionMarketer,
              commissionPct: sessionCommissionPct,
              commissionAmount: sessionCommissionAmount,
            );
        studentId = newStudent.id;
      }

      final durationMinutes =
          (int.tryParse(hoursController.text.trim()) ?? 0) * 60 +
          (int.tryParse(minutesController.text.trim()) ?? 0);

      if (existing == null) {
        await ref
            .read(sessionsRepositoryProvider)
            .addSession(
              tutorId: tutorId,
              studentId: studentId,
              subject: subjectController.text.trim().isEmpty
                  ? 'حصة خصوصي'
                  : subjectController.text.trim(),
              scheduledAt: scheduledAt,
              durationMinutes: durationMinutes == 0 ? 60 : durationMinutes,
              studentHourlyRate: double.tryParse(
                studentHourlyRateController.text.trim(),
              ),
              studentTotal: double.tryParse(studentTotalController.text.trim()),
              studentTotalCurrency: studentCurrency,
              studentAmountReceived: double.tryParse(
                studentReceivedController.text.trim(),
              ),
              paymentMethod: paymentMethod,
              tutorHourlyRate: double.tryParse(
                tutorHourlyRateController.text.trim(),
              ),
              tutorPayout: double.tryParse(tutorPayoutController.text.trim()),
              tutorPayoutCurrency: tutorCurrency,
              materialNote: notesController.text.trim().isEmpty
                  ? null
                  : notesController.text.trim(),
              writeOffAmount:
                  double.tryParse(writeOffController.text.trim()) ?? 0,
              writeOffReason: writeOffReason,
              acquisitionSource: sessionSource,
              marketerName: sessionMarketer,
              commissionPct: sessionCommissionPct,
              commissionAmount: sessionCommissionAmount,
            );
      } else {
        await ref
            .read(sessionsRepositoryProvider)
            .updateSession(
              id: existing.id,
              tutorId: tutorId,
              studentId: studentId,
              subject: subjectController.text.trim().isEmpty
                  ? 'حصة خصوصي'
                  : subjectController.text.trim(),
              scheduledAt: scheduledAt,
              durationMinutes: durationMinutes == 0 ? 60 : durationMinutes,
              studentHourlyRate: double.tryParse(
                studentHourlyRateController.text.trim(),
              ),
              studentTotal: double.tryParse(studentTotalController.text.trim()),
              studentTotalCurrency: studentCurrency,
              studentAmountReceived: double.tryParse(
                studentReceivedController.text.trim(),
              ),
              paymentMethod: paymentMethod,
              tutorHourlyRate: double.tryParse(
                tutorHourlyRateController.text.trim(),
              ),
              tutorPayout: double.tryParse(tutorPayoutController.text.trim()),
              tutorPayoutCurrency: tutorCurrency,
              materialNote: notesController.text.trim().isEmpty
                  ? null
                  : notesController.text.trim(),
              writeOffAmount:
                  double.tryParse(writeOffController.text.trim()) ?? 0,
              writeOffReason: writeOffReason,
              acquisitionSource: sessionSource,
              marketerName: sessionMarketer,
              commissionPct: sessionCommissionPct,
              commissionAmount: sessionCommissionAmount,
            );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حصل خطأ أثناء حفظ الحصة: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsProvider);
    final tutors = ref.watch(tutorsProvider).valueOrNull ?? [];
    final tutorsById = {for (final t in tutors) t.id: t};
    final students = ref.watch(studentsProvider).valueOrNull ?? [];
    final studentsById = {for (final s in students) s.id: s};

    return Scaffold(
      appBar: AppBar(title: const Text('🗓️ الحصص الفردية')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _StatusChip(
                    label: 'الكل',
                    selected: _statusFilter == 'all',
                    onTap: () => setState(() => _statusFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  for (final entry in _statusLabels.entries) ...[
                    _StatusChip(
                      label: entry.value,
                      selected: _statusFilter == entry.key,
                      onTap: () => setState(() => _statusFilter = entry.key),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: sessionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => RealtimeErrorView(
                error: err,
                onRetry: () => ref.invalidate(sessionsProvider),
              ),
              data: (sessions) {
                final filtered = _statusFilter == 'all'
                    ? sessions
                    : sessions.where((s) => s.status == _statusFilter).toList();
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'مفيش حصص',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final s = filtered[i];
                    return _SessionCard(
                      session: s,
                      tutor: s.tutorId != null ? tutorsById[s.tutorId] : null,
                      student: s.studentId != null
                          ? studentsById[s.studentId]
                          : null,
                      onEdit: () => _openSessionForm(
                        context,
                        ref,
                        tutors: tutors,
                        students: students,
                        existing: s,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            _openSessionForm(context, ref, tutors: tutors, students: students),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.accent.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: selected ? AppColors.accent : AppColors.textMuted,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({
    required this.session,
    required this.tutor,
    required this.student,
    required this.onEdit,
  });

  final PrivateSession session;
  final Tutor? tutor;
  final Student? student;
  final VoidCallback onEdit;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmWithPassword(
      context,
      title: 'حذف الحصة نهائيًا',
      message: 'هيتم حذف الحصة نهائيًا. اكتب كلمة المرور للتأكيد.',
    );
    if (!confirmed) return;
    await ref.read(sessionsRepositoryProvider).deleteSession(session.id);
  }

  Future<void> _sendWhatsappReminder(String phone) async {
    final scheduledAt = session.scheduledAt;
    if (scheduledAt == null) return;
    final date = intl.DateFormat('d MMMM yyyy', 'ar').format(scheduledAt);
    final time = intl.DateFormat('h:mm a', 'ar').format(scheduledAt);
    final message =
        'عندك حصة مع أكاديمية StudyHub يوم $date الساعة $time في مادة ${session.subject}.';
    await launchWhatsapp(phone, text: message);
  }

  Future<void> _recordPayment(BuildContext context, WidgetRef ref) async {
    if (tutor == null) return;
    final amountController = TextEditingController();
    final sarEquivalentController = TextEditingController();
    final notesController = TextEditingController();
    final needsEquivalent = session.tutorPayoutCurrency != 'SAR';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Text('تسجيل دفعة للمدرس'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'المبلغ (${session.tutorPayoutCurrency})',
                  ),
                ),
                if (needsEquivalent) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: sarEquivalentController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ما يعادلها بالريال (SAR)',
                      helperText: 'عشان نحسب ربح الأكاديمية بالريال',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                  ),
                ),
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تسجيل'),
          ),
        ],
      ),
    );

    if (saved != true) return;
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) return;
    await ref
        .read(coursesRepositoryProvider)
        .addTutorPayment(
          tutorId: tutor!.id,
          privateSessionId: session.id,
          amount: amount,
          currency: session.tutorPayoutCurrency,
          equivalentSarAmount: needsEquivalent
              ? double.tryParse(sarEquivalentController.text.trim())
              : amount,
          type: 'private_session_payout',
          notes: notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
        );
  }

  void _showPaymentHistory(BuildContext context, WidgetRef ref) {
    if (tutor == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SessionPaymentHistorySheet(
        sessionId: session.id,
        tutorId: tutor!.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _statusColors[session.status] ?? AppColors.textMuted;

    double paid = 0;
    if (tutor != null) {
      final ledger =
          ref.watch(tutorLedgerProvider(tutor!.id)).valueOrNull ?? [];
      paid = ledger
          .where(
            (p) =>
                p.privateSessionId == session.id &&
                p.currency == session.tutorPayoutCurrency,
          )
          .fold(0.0, (sum, p) => sum + p.amount);
    }
    final target = session.tutorPayout;
    final remaining = target != null ? target - paid : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.subject,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabels[session.status] ?? session.status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.scheduledAt == null
                        ? '⏳ الموعد لسه هيتحدد'
                        : intl.DateFormat(
                            'd MMM yyyy — h:mm a',
                            'ar',
                          ).format(session.scheduledAt!),
                    style: TextStyle(
                      fontSize: 12,
                      color: session.scheduledAt == null
                          ? AppColors.warning
                          : AppColors.textMuted,
                      fontWeight: session.scheduledAt == null
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
                Text(
                  _fmtDuration(session.durationMinutes),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ContactRow(
                    icon: Icons.school_outlined,
                    label: tutor?.name ?? '؟',
                    phone: tutor?.phoneWhatsapp,
                  ),
                ),
                Expanded(
                  child: _ContactRow(
                    icon: Icons.person_outline,
                    label: student?.name ?? '؟',
                    phone: student?.phoneWhatsapp,
                  ),
                ),
              ],
            ),
            if (session.scheduledAt != null &&
                (tutor?.phoneWhatsapp != null ||
                    student?.phoneWhatsapp != null)) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                children: [
                  if (tutor?.phoneWhatsapp != null)
                    TextButton.icon(
                      onPressed: () =>
                          _sendWhatsappReminder(tutor!.phoneWhatsapp!),
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Text(
                        'تذكير واتساب للمدرس',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  if (student?.phoneWhatsapp != null)
                    TextButton.icon(
                      onPressed: () =>
                          _sendWhatsappReminder(student!.phoneWhatsapp!),
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Text(
                        'تذكير واتساب للطالب',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ],
            if (session.studentTotal != null) ...[
              const SizedBox(height: 8),
              Text(
                'من الطالب: ${_fmtMoney(session.studentTotal!)} ${session.studentTotalCurrency}'
                ' • ${_paymentMethodLabels[session.paymentMethod] ?? session.paymentMethod}'
                '${session.studentAmountReceived != null ? ' • صافي: ${_fmtMoney(session.studentAmountReceived!)} ${session.studentTotalCurrency}' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            if (session.materialNote != null &&
                session.materialNote!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                session.materialNote!,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            if (tutor != null && target != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'مدرس: ${_fmtMoney(paid)} من ${_fmtMoney(target)} ${session.tutorPayoutCurrency}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: (remaining ?? 0) > 0
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showPaymentHistory(context, ref),
                    child: const Text(
                      'سجل الدفعات',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _recordPayment(context, ref),
                    child: const Text(
                      'تسجيل دفعة',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilterChip(
                    label: const Text(
                      'دفع الطالب',
                      style: TextStyle(fontSize: 11),
                    ),
                    selected: session.studentPaid,
                    onSelected: (v) => ref
                        .read(sessionsRepositoryProvider)
                        .updateSessionPaymentFlags(session.id, studentPaid: v),
                    selectedColor: AppColors.success.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: session.status,
                    isDense: true,
                    decoration: const InputDecoration(isDense: true),
                    items: _statusLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        ref
                            .read(sessionsRepositoryProvider)
                            .updateSessionStatus(session.id, v);
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => _delete(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.label, this.phone});

  final IconData icon;
  final String label;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
    if (phone == null || phone!.isEmpty) return child;
    return InkWell(onTap: () => launchWhatsapp(phone!), child: child);
  }
}

class _SessionPaymentHistorySheet extends ConsumerWidget {
  const _SessionPaymentHistorySheet({
    required this.sessionId,
    required this.tutorId,
  });

  final String sessionId;
  final String tutorId;

  Future<void> _editPayment(
    BuildContext context,
    WidgetRef ref,
    TutorPayment payment,
  ) async {
    final amountController = TextEditingController(
      text: _fmtMoney(payment.amount),
    );
    final sarEquivalentController = TextEditingController(
      text: payment.equivalentSarAmount != null
          ? _fmtMoney(payment.equivalentSarAmount!)
          : '',
    );
    final notesController = TextEditingController(text: payment.notes ?? '');
    var currency = payment.currency;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const Text('تعديل الدفعة'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'المبلغ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: currency,
                        items: const ['EGP', 'SAR', 'USD', 'AED']
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => currency = v ?? currency),
                      ),
                    ],
                  ),
                  if (currency != 'SAR') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: sarEquivalentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ما يعادلها بالريال (SAR)',
                        helperText: 'عشان نحسب ربح الأكاديمية بالريال',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
                    ),
                  ),
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
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) return;
    await ref
        .read(coursesRepositoryProvider)
        .updateTutorPayment(
          id: payment.id,
          amount: amount,
          currency: currency,
          equivalentSarAmount: currency == 'SAR'
              ? amount
              : double.tryParse(sarEquivalentController.text.trim()),
          notes: notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = (ref.watch(tutorLedgerProvider(tutorId)).valueOrNull ?? [])
        .where((p) => p.privateSessionId == sessionId)
        .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سجل الدفعات للمدرس',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 12),
            if (payments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'لسه مفيش دفعات مسجلة',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: payments.length,
                  separatorBuilder: (context, i) => const Divider(height: 16),
                  itemBuilder: (context, i) {
                    final p = payments[i];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_fmtMoney(p.amount)} ${p.currency}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              if (p.equivalentSarAmount != null &&
                                  p.currency != 'SAR')
                                Text(
                                  '≈ ${_fmtMoney(p.equivalentSarAmount!)} SAR',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              Text(
                                _ledgerTypeLabels[p.type] ?? p.type,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              if (p.notes != null && p.notes!.isNotEmpty)
                                Text(
                                  p.notes!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              intl.DateFormat(
                                'd MMM yyyy',
                                'ar',
                              ).format(p.date),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _editPayment(context, ref, p),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

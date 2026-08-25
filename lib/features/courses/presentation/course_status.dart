import '../../../core/theme/app_colors.dart';

const courseStatusLabels = {
  'planning': 'تخطيط',
  'active': 'نشط',
  'inactive': 'غير نشط',
  'archived': 'مؤرشف',
};

const courseStatusColors = {
  'planning': AppColors.info,
  'active': AppColors.success,
  'inactive': AppColors.textMuted,
  'archived': AppColors.textMuted,
};

const explanationStatusLabels = {
  'not_started': 'غير مشروح',
  'in_progress': 'قيد الشرح',
  'completed': 'الشرح كامل',
};

const explanationStatusColors = {
  'not_started': AppColors.error,
  'in_progress': AppColors.warning,
  'completed': AppColors.success,
};

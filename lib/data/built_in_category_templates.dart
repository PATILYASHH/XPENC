import 'category_template_file.dart';

/// Ready-made category templates XPENC offers on Category templates (GitHub
/// #187). Names reuse the default categories wherever they can, so switching
/// to one moves the categories you already have into place, history and
/// all, instead of starting new ones beside them.
const kBuiltInCategoryTemplates = [_fiftyThirtyTwenty];

/// 50/30/20: needs about half of what comes in, wants about a third, and
/// the last fifth set aside. Set aside means moved into a Goal — a
/// transfer, not spending — so it has no expense group of its own here.
const _fiftyThirtyTwenty = CategoryTemplateFile(
  name: '50/30/20',
  description:
      'Two groups for everything you spend: Needs (about 50% of what comes '
      'in) and Wants (about 30%). Put the last 20% into Goals — saving is a '
      'transfer, not spending.',
  income: [
    TemplateCategory(name: 'Salary', iconKey: 'salary', colorValue: 0xFF16A34A),
    TemplateCategory(name: 'Profit', iconKey: 'profit', colorValue: 0xFF0EA5E9),
    TemplateCategory(name: 'Gift', iconKey: 'gift', colorValue: 0xFFA855F7),
    TemplateCategory(name: 'Cash', iconKey: 'cash', colorValue: 0xFF22C55E),
    TemplateCategory(
      name: 'Interest',
      iconKey: 'interest',
      colorValue: 0xFF14B8A6,
    ),
    TemplateCategory(name: 'Refund', iconKey: 'refund', colorValue: 0xFF64748B),
  ],
  expense: [
    TemplateCategory(
      name: 'Needs',
      iconKey: 'house',
      colorValue: 0xFF2563EB,
      children: [
        TemplateCategory(name: 'Rent', iconKey: 'rent', colorValue: 0xFFDC2626),
        TemplateCategory(
          name: 'Groceries',
          iconKey: 'groceries',
          colorValue: 0xFF84CC16,
        ),
        TemplateCategory(
          name: 'Bills',
          iconKey: 'bills',
          colorValue: 0xFF8B5CF6,
        ),
        TemplateCategory(
          name: 'Transport',
          iconKey: 'transport',
          colorValue: 0xFF3B82F6,
        ),
        TemplateCategory(
          name: 'Health',
          iconKey: 'health',
          colorValue: 0xFFEF4444,
        ),
        TemplateCategory(name: 'EMI', iconKey: 'emi', colorValue: 0xFF78716C),
        TemplateCategory(
          name: 'Insurance',
          iconKey: 'insurance',
          colorValue: 0xFF0EA5E9,
        ),
        TemplateCategory(
          name: 'Education',
          iconKey: 'education',
          colorValue: 0xFFF59E0B,
        ),
      ],
    ),
    TemplateCategory(
      name: 'Wants',
      iconKey: 'festival',
      colorValue: 0xFFEC4899,
      children: [
        TemplateCategory(name: 'Food', iconKey: 'food', colorValue: 0xFFF97316),
        TemplateCategory(
          name: 'Shopping',
          iconKey: 'shopping',
          colorValue: 0xFFDB2777,
        ),
        TemplateCategory(
          name: 'Entertainment',
          iconKey: 'entertainment',
          colorValue: 0xFF06B6D4,
        ),
        TemplateCategory(
          name: 'Travel',
          iconKey: 'travel',
          colorValue: 0xFF14B8A6,
        ),
        TemplateCategory(
          name: 'Subscriptions',
          iconKey: 'streaming',
          colorValue: 0xFF6366F1,
        ),
        TemplateCategory(
          name: 'Personal care',
          iconKey: 'spa',
          colorValue: 0xFFF472B6,
        ),
      ],
    ),
  ],
);

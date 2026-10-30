import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../models/category_model.dart';
import '../../../../models/personal_summary_model.dart';
import 'insights_card.dart';

/// Where the month's money went: a donut by category with the total (or
/// the touched category) in the middle, and a row per category with its
/// share and the change against last month.
class CategoryBreakdownCard extends StatefulWidget {
  const CategoryBreakdownCard({super.key, required this.summary});

  final PersonalSummary summary;

  @override
  State<CategoryBreakdownCard> createState() => _CategoryBreakdownCardState();
}

class _CategoryBreakdownCardState extends State<CategoryBreakdownCard> {
  int? _selected;

  void _select(int? i) {
    if (i == _selected) return;
    if (i != null) HapticService.instance.selection();
    setState(() => _selected = i);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = widget.summary.spent;
    final rows = widget.summary.categories.where((c) => c.amount > 0).toList();
    final gone = widget.summary.categories.where((c) => c.amount == 0).toList();
    final selected = _selected != null && _selected! < rows.length
        ? rows[_selected!]
        : null;
    final selectedCat = selected == null
        ? null
        : CategoryModel.fromId(selected.category)!;

    return InsightsCard(
      title: AppStrings.insightsByCategory,
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 58,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (!event.isInterestedForInteractions) return;
                        final i = response?.touchedSection?.touchedSectionIndex;
                        _select(i != null && i >= 0 ? i : null);
                      },
                    ),
                    sections: [
                      for (var i = 0; i < rows.length; i++)
                        PieChartSectionData(
                          value: rows[i].amount,
                          color: CategoryModel.fromId(rows[i].category)!.color,
                          radius: i == _selected ? 30 : 24,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
                IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedCat?.name ?? AppStrings.insightsTotal,
                        style: AppTextStyles.caption(
                          isDark,
                        ).copyWith(color: AppColors.textSecondary(isDark)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.compact(selected?.amount ?? total),
                        style: AppTextStyles.body1(
                          isDark,
                        ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                      if (selected != null && total > 0)
                        Text(
                          '${(selected.amount / total * 100).round()}%',
                          style: AppTextStyles.caption(
                            isDark,
                          ).copyWith(color: AppColors.textSecondary(isDark)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++)
            _CategoryRow(
              spend: rows[i],
              total: total,
              selected: i == _selected,
              onTap: () => _select(i == _selected ? null : i),
            ),
          for (final c in gone)
            _CategoryRow(spend: c, total: total, selected: false),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.spend,
    required this.total,
    required this.selected,
    this.onTap,
  });

  final CategorySpend spend;
  final double total;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cat = CategoryModel.fromId(spend.category)!;
    final share = total > 0 ? spend.amount / total : 0.0;
    final diff = spend.amount - spend.previousAmount;
    final caption = AppTextStyles.caption(
      isDark,
    ).copyWith(color: AppColors.textSecondary(isDark), fontSize: 12);

    return Material(
      color: selected
          ? cat.color.withValues(alpha: isDark ? 0.16 : 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(cat.icon, size: 17, color: cat.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.name,
                      style: AppTextStyles.body1(
                        isDark,
                      ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: share,
                        minHeight: 5,
                        color: cat.color,
                        backgroundColor: AppColors.divider(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(spend.amount, currency: '₹'),
                    style: AppTextStyles.body1(
                      isDark,
                    ).copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  _Diff(
                    diff: diff,
                    hadBefore: spend.previousAmount > 0,
                    style: caption,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "▲ ₹200" in orange when more than last month, "▼ ₹200" in green when
/// less, "New" when the category had nothing last month.
class _Diff extends StatelessWidget {
  const _Diff({
    required this.diff,
    required this.hadBefore,
    required this.style,
  });

  final double diff;
  final bool hadBefore;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (!hadBefore) return Text(AppStrings.insightsNew, style: style);
    if (diff.abs() < 0.5) return Text(AppStrings.insightsSame, style: style);
    final up = diff > 0;
    final color = up ? AppColors.warning : AppColors.success;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 12,
          color: color,
        ),
        Text(
          CurrencyFormatter.compact(diff.abs()),
          style: style.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../components/components.dart';
import '../../../models/models.dart';

/// Screen for creating a new group
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  late TextEditingController _groupNameController;
  late TextEditingController _descriptionController;
  GroupCategory _selectedCategory = GroupCategory.other;
  String _selectedEmoji = '👥';

  final List<String> _emojiList = [
    '👥', '🏠', '🏝️', '✈️', '🎉', '🍽️', '🏋️', '🎮', '📚', '🚗',
    '⚽', '🎬', '🎵', '🏖️', '🧳', '💼', '🎓', '🏥', '🌍', '💰',
  ];

  @override
  void initState() {
    super.initState();
    _groupNameController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _createGroup() {
    if (_groupNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    // Navigate back to groups screen after creation
    context.go('/home/groups');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Group "${_groupNameController.text}" created!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        leading: Semantics(
          button: true,
          label: 'Go back',
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        title: Text(
          'Create Group',
          style: AppTextStyles.headline3(isDark),
        ),
        elevation: 0,
        backgroundColor: AppColors.cardBg(isDark),
        foregroundColor: AppColors.textPrimary(isDark),
      ),
      body: screenWidth < 600
          ? _buildCompactLayout(isDark)
          : screenWidth < 1100
              ? _buildStandardLayout(isDark)
              : _buildLargeLayout(isDark),
    );
  }

  Widget _buildCompactLayout(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildForm(isDark),
    );
  }

  Widget _buildStandardLayout(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _buildForm(isDark),
        ),
      ),
    );
  }

  Widget _buildLargeLayout(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: _buildForm(isDark),
        ),
      ),
    );
  }

  Widget _buildForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Emoji Selector
        Text(
          'Choose an emoji',
          style: AppTextStyles.body1(isDark),
        ),
        const SizedBox(height: 12),
        _buildEmojiSelector(isDark),
        const SizedBox(height: 32),

        // Group Name
        Text(
          'Group Name',
          style: AppTextStyles.body1(isDark),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Group name input',
          child: AppTextField(
            controller: _groupNameController,
            hint: 'e.g., Goa Trip',
            label: 'Group Name',
          ),
        ),
        const SizedBox(height: 24),

        // Category Selector
        Text(
          'Category',
          style: AppTextStyles.body1(isDark),
        ),
        const SizedBox(height: 12),
        _buildCategorySelector(isDark),
        const SizedBox(height: 32),

        // Description
        Text(
          'Description (Optional)',
          style: AppTextStyles.body1(isDark),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Group description input',
          child: AppTextField(
            controller: _descriptionController,
            hint: 'Add notes about this group...',
            label: 'Description',
            maxLines: 3,
          ),
        ),
        const SizedBox(height: 32),

        // Create Button
        Semantics(
          button: true,
          label: 'Create group button',
          child: SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Create Group',
              onPressed: _createGroup,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiSelector(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.divider(isDark),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: _emojiList.length,
        itemBuilder: (context, index) {
          final emoji = _emojiList[index];
          final isSelected = emoji == _selectedEmoji;

          return Semantics(
            button: true,
            label: 'Select emoji $emoji',
            child: GestureDetector(
              onTap: () => setState(() => _selectedEmoji = emoji),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.brand.withOpacity(0.2)
                      : AppColors.surface(isDark),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.brand
                        : AppColors.divider(isDark),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategorySelector(bool isDark) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: GroupCategory.values.map((category) {
        final isSelected = category == _selectedCategory;
        final categoryName = category.toString().split('.').last;

        return Semantics(
          button: true,
          label: 'Category $categoryName',
          child: GestureDetector(
            onTap: () => setState(() => _selectedCategory = category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brand
                    : AppColors.surface(isDark),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.brand
                      : AppColors.divider(isDark),
                  width: 1,
                ),
              ),
              child: Text(
                categoryName[0].toUpperCase() + categoryName.substring(1),
                style: AppTextStyles.body2(isDark).copyWith(
                  color: isSelected
                      ? Colors.white
                      : AppColors.textPrimary(isDark),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

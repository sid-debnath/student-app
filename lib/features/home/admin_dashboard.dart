import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/admin_dashboard.dart';
import '../../models/announcement.dart';
import '../../models/app_user.dart';
import '../../widgets/async_body.dart';
import 'dashboard_actions.dart';

/// Admin home dashboard: live enrollment + today's attendance totals plus a few
/// other at-a-glance metrics and a short list of recent announcements.
class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = user.displayName.isEmpty ? user.email : user.displayName;
    final dashboard = ref.watch(adminDashboardProvider);

    return AsyncBody(
      value: dashboard,
      builder: (data) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _WelcomeHeader(name: name),
            const SizedBox(height: 16),
            _PrimaryStats(data: data),
            const SizedBox(height: 16),
            _TodayAttendanceCard(data: data),
            const SizedBox(height: 16),
            _SecondaryStats(data: data),
            const SizedBox(height: 16),
            _RecentAnnouncements(announcements: data.announcements),
            const SizedBox(height: 24),
            Text('Quick actions', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final action in dashboardActions(UserRole.admin))
                  ActionChip(
                    avatar: Icon(action.icon, size: 18),
                    label: Text(action.label),
                    onPressed: () => context.go(action.path),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome, $name', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PrimaryStats extends StatelessWidget {
  const _PrimaryStats({required this.data});

  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<StatusPalette>()!;
    return _MetricGrid(
      children: [
        _StatCard(
          icon: Icons.groups_outlined,
          label: 'Total students',
          value: '${data.totalStudents}',
          color: theme.colorScheme.primary,
          onTap: () => context.go('/students'),
        ),
        _StatCard(
          icon: Icons.check_circle_outline,
          label: 'Present today',
          value: '${data.presentToday}',
          color: palette.success,
          onTap: () => context.go('/attendance'),
        ),
        _StatCard(
          icon: Icons.cancel_outlined,
          label: 'Absent today',
          value: '${data.absentToday}',
          color: palette.danger,
          onTap: () => context.go('/attendance'),
        ),
      ],
    );
  }
}

class _SecondaryStats extends StatelessWidget {
  const _SecondaryStats({required this.data});

  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _MetricGrid(
      children: [
        _StatCard(
          icon: Icons.school_outlined,
          label: 'Classes',
          value: '${data.totalClasses}',
          color: theme.colorScheme.primary,
          onTap: () => context.go('/roster'),
        ),
        _StatCard(
          icon: Icons.badge_outlined,
          label: 'Teachers & staff',
          value: '${data.staffCount}',
          color: theme.colorScheme.primary,
          onTap: () => context.go('/users'),
        ),
        _StatCard(
          icon: Icons.menu_book_outlined,
          label: 'Upcoming homework',
          value: '${data.upcomingHomework}',
          color: theme.colorScheme.primary,
          onTap: () => context.go('/homework'),
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900 ? 3 : (width >= 560 ? 2 : 1);
        const spacing = 12.0;
        final cardWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: cardWidth, child: child),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayAttendanceCard extends StatelessWidget {
  const _TodayAttendanceCard({required this.data});

  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<StatusPalette>()!;
    final marked = data.markedToday;
    final rate = data.attendanceRateToday;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fact_check_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text("Today's attendance", style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            if (marked == 0)
              Text(
                'No attendance has been marked today yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${rate!.round()}%',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: palette.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'present today',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: rate / 100,
                  minHeight: 8,
                  backgroundColor: palette.danger.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(palette.success),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _AttendanceMetric(
                      label: 'Present',
                      value: data.presentToday,
                      color: palette.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AttendanceMetric(
                      label: 'Absent',
                      value: data.absentToday,
                      color: palette.danger,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttendanceMetric extends StatelessWidget {
  const _AttendanceMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$value',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentAnnouncements extends StatelessWidget {
  const _RecentAnnouncements({required this.announcements});

  final List<Announcement> announcements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = announcements.take(3).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.campaign_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Announcements', style: theme.textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/announcements'),
                  child: const Text('View all'),
                ),
              ],
            ),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'No announcements yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final announcement in recent)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.campaign),
                  title: Text(
                    announcement.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    _formatAnnouncementDate(announcement.createdAt),
                  ),
                  onTap: () => context.go('/announcements'),
                ),
          ],
        ),
      ),
    );
  }
}

String _formatAnnouncementDate(DateTime? value) {
  if (value == null) return '';
  return DateFormat('dd MMM yyyy').format(value.toLocal());
}




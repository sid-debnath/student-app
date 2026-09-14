import 'package:flutter/material.dart';

import '../../models/app_user.dart';

/// A single quick-action chip shown on home dashboards.
class DashboardAction {
  const DashboardAction(this.label, this.path, this.icon);

  final String label;
  final String path;
  final IconData icon;
}

/// Quick actions for each role. Kept in one place so home dashboards and any
/// other entry points stay in sync.
List<DashboardAction> dashboardActions(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return const [
        DashboardAction('Roster', '/roster', Icons.groups_outlined),
        DashboardAction('Invite users', '/users', Icons.person_add_outlined),
        DashboardAction(
          'Timetable',
          '/timetable',
          Icons.calendar_view_week_outlined,
        ),
        DashboardAction('Announcements', '/announcements', Icons.campaign_outlined),
        DashboardAction('Exams & reports', '/marks', Icons.grade_outlined),
      ];
    case UserRole.teacher:
      return const [
        DashboardAction('Attendance', '/attendance', Icons.fact_check_outlined),
        DashboardAction('Homework', '/homework', Icons.menu_book_outlined),
        DashboardAction('Marks', '/marks', Icons.grade_outlined),
        DashboardAction(
          'Timetable',
          '/timetable',
          Icons.calendar_view_week_outlined,
        ),
        DashboardAction('Announcements', '/announcements', Icons.campaign_outlined),
      ];
    case UserRole.floorIncharge:
      return const [
        DashboardAction('Attendance', '/attendance', Icons.fact_check_outlined),
        DashboardAction('Homework', '/homework', Icons.menu_book_outlined),
        DashboardAction('Marks', '/marks', Icons.grade_outlined),
        DashboardAction(
          'Timetable',
          '/timetable',
          Icons.calendar_view_week_outlined,
        ),
        DashboardAction('Announcements', '/announcements', Icons.campaign_outlined),
      ];
    case UserRole.viewer:
      return const [
        DashboardAction('Attendance', '/attendance', Icons.fact_check_outlined),
        DashboardAction('Homework', '/homework', Icons.menu_book_outlined),
        DashboardAction(
          'Timetable',
          '/timetable',
          Icons.calendar_view_week_outlined,
        ),
        DashboardAction('Report card', '/marks', Icons.grade_outlined),
        DashboardAction('Announcements', '/announcements', Icons.campaign_outlined),
      ];
  }
}

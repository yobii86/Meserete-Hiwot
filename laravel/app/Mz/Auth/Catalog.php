<?php

namespace App\Mz\Auth;

/** Permission keys and definitions (port of permissions/catalog.js — the single source of truth). */
final class Catalog
{
    public const DEFINITIONS = [
        ['users.view', 'users', 'View user accounts'],
        ['users.create', 'users', 'Create user accounts'],
        ['users.update', 'users', 'Edit user accounts'],
        ['users.disable', 'users', 'Disable / enable user accounts'],
        ['users.reset_device', 'users', 'Reset a user\'s registered device and force logout'],
        ['mezmurs.view', 'mezmurs', 'View Mezmurs in the admin panel (including drafts)'],
        ['mezmurs.create', 'mezmurs', 'Create Mezmurs'],
        ['mezmurs.update', 'mezmurs', 'Edit Mezmurs, audio and covers'],
        ['mezmurs.delete', 'mezmurs', 'Delete Mezmurs'],
        ['categories.manage', 'content', 'Manage categories'],
        ['ads.manage', 'content', 'Manage advertisement banners'],
        ['pages.manage', 'content', 'Manage internal pages'],
        ['programs.manage', 'programs', 'Manage programs and participants'],
        ['programs.reminders_enforce', 'programs', 'Make a program\'s reminders mandatory for its members'],
        ['attendance.manage', 'programs', 'Take attendance: scan, mark and record permissions while the session is open'],
        ['notifications.send', 'notifications', 'Send notifications to individual / selected / filtered users'],
        ['notifications.send_all', 'notifications', 'Send notifications to all users'],
        ['borrowing.manage', 'library', 'Issue and return borrowed items'],
        ['items.manage', 'library', 'Manage library items'],
        ['fines.manage', 'library', 'Configure fine policy and override fines'],
        ['library.circulate', 'library', 'Circulate Sunday-school library books (checkout, return, copy management)'],
        ['reports.view', 'reports', 'View dashboard and reports'],
        ['audit_logs.view', 'reports', 'View the admin audit log'],
        ['activity_logs.view', 'reports', 'View user activity logs'],
        ['admins.view', 'admins', 'View administrator accounts'],
        ['admins.manage', 'admins', 'Create and configure lower-level administrators'],
        ['settings.manage', 'system', 'Manage system settings'],
        ['releases.manage', 'system', 'Publish app versions (download page / force update)'],
        ['departments.manage', 'system', 'Create departments and choose their leads'],
        ['hr.manage', 'hr', 'Assign members to departments and give them role labels'],
        ['payments.manage', 'payments', 'Record monthly payments'],
        ['education.manage', 'education', 'Manage classes, courses, teachers and attendance takers'],
        ['education.register', 'education', 'Register members (new or existing) into classes and their courses'],
        ['education.content', 'education', 'Manage subject categories, curriculum (subjects, units, lessons, materials) and the featured banner'],
        ['education.certify', 'education', 'Issue, revoke and correct course completion certificates'],
        ['education.reports', 'education', 'View education reports, academic scores and engagement metrics'],
        ['education.view', 'education', 'View education dashboard and overview'],
        ['education.classes', 'education', 'Manage classes and student enrollments'],
        ['education.curriculum', 'education', 'Manage curriculum structure, canonical grades, and courses'],
        ['education.lessons', 'education', 'Manage units, lessons, and lesson topics'],
        ['education.materials', 'education', 'Create and manage learning materials'],
        ['education.materials_approve', 'education', 'Review, approve and publish learning materials'],
        ['education.quizzes', 'education', 'Create and manage course and lesson quizzes'],
        ['education.exams', 'education', 'Create, configure and manage closing/final exams'],
        ['education.assessments', 'education', 'Manage course assessments, rubrics and assignment guidelines'],
        ['education.marks', 'education', 'Enter grades, score assessments and publish report cards'],
        ['education.attendance_view', 'education', 'View education attendance rosters and statistics (HR records)'],
        ['education.settings', 'education', 'Configure academic year, terms and education settings'],
        ['program_categories.manage', 'programs', 'Create and edit program categories'],
        ['attendance.reports', 'programs', 'View attendance statistics and calendars of members'],
        ['choir.manage', 'choir', 'Manage wedding ceremony choir services (መዝሙር አገልግሎት)'],
        ['payments.configure', 'payments', 'Set student / worker monthly payment rates'],
        ['attendance.view', 'programs', 'View attendance rosters, calendars and summaries'],
        ['attendance.close', 'programs', 'Close an attendance session before the program ends'],
        ['attendance.correction.request', 'programs', 'Submit attendance comments and correction requests'],
        ['attendance.correction.approve', 'programs', 'Review attendance correction requests'],
        ['attendance.override', 'programs', 'Change attendance after the session has closed'],
        ['attendance.configure', 'programs', 'Configure attendance (signature rules, sessions) — HR'],
        ['attendance.assign', 'programs', 'Assign the one attendance taker of each program occurrence (HR)'],
        ['payments.view', 'payments', 'View monthly contributions and reports (read-only)'],
        ['property.request', 'property', 'Request property for a department'],
        ['property.review', 'property', 'Review, approve, reject and issue department property requests'],
        ['borrowing.approve', 'library', 'Approve direct borrowings that need approval'],
        ['borrowing.configure', 'library', 'Configure which items and members can borrow directly'],
        ['selection.view', 'choir', 'View holiday selections and their results'],
        ['selection.configure', 'choir', 'Create and configure holiday selections (period, weights, rules)'],
        ['selection.exams', 'choir', 'Set whether exam results are required for a holiday selection'],
        ['selection.review', 'choir', 'Review holiday selection results and record exceptions'],
        ['selection.finalize', 'choir', 'Finalize holiday selections'],
        ['member_id.configure', 'users', 'Configure member ID prefixes and display style'],
        ['member_groups.manage', 'users', 'Create and edit member types (groups) used by programs and attendance'],
        ['chat.supervise', 'departments', 'Read and moderate every department chat'],
        ['projects.view', 'projects', 'View department projects (members always see their own department)'],
        ['projects.manage', 'projects', 'Create and manage projects, tasks and teams in the departments one administers'],
        ['projects.expenses.approve', 'projects', 'Approve project budgets, expenses and budget adjustments (Finance)'],
        ['projects.reports', 'projects', 'View project and task reports'],
        ['projects.all_departments', 'projects', 'Access the projects of every department'],
    ];

    public const ROLE_SYSTEM = 'system_authority';
    public const ROLE_HIGH_ADMIN = 'high_admin';
    public const ROLE_ADMIN = 'admin';

    public const DEFAULT_ROLE_PERMISSIONS_ADMIN = ['users.view', 'mezmurs.view', 'mezmurs.create', 'mezmurs.update', 'categories.manage', 'programs.manage', 'attendance.manage', 'borrowing.manage', 'items.manage', 'reports.view'];

    /** @return string[] */
    public static function allKeys(): array
    {
        return array_column(self::DEFINITIONS, 0);
    }
}

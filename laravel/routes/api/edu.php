<?php

use App\Mz\Http\Ctx;
use App\Mz\Http\Upload;
use App\Mz\Services\Edu;
use App\Mz\Services\EduCertificates;
use App\Mz\Services\EduLearning;
use App\Mz\Services\EduOutcomes;
use App\Mz\Services\EduRetakes;
use App\Mz\Services\EduScores;
use App\Mz\Support\Dates;
use App\Mz\Support\EduSchemas;
use App\Mz\Support\Http;
use App\Mz\Support\Page;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// ትምህርት API (port of edu.routes.js). Moderator routes need education.manage; everything else
// is checked per class / course inside Edu (students, the course teacher, attendance takers).
Route::prefix('edu')->middleware(['mz', 'mz.module:education'])->group(function () {
    // ---- everyone: overview, registration, my class ----
    Route::get('overview', fn () => Http::ok(Edu::overview(Ctx::auth())));
    Route::get('classes/open', fn () => Http::ok(Edu::openClasses(Ctx::auth())));
    Route::post('classes/{id}/enroll', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['program' => Z::enum(['regular', 'distance'])]));
        return Http::ok(Edu::enroll(Ctx::auth(), $id, $b['program']));
    });
    Route::delete('classes/{id}/enroll', function () {
        Edu::withdraw(Ctx::auth(), Ctx::id());
        return Http::ok(null);
    });
    Route::get('classes/{id}', fn () => Http::ok(Edu::classDetail(Ctx::auth(), Ctx::id())));
    Route::get('classes/{id}/my-attendance', fn () => Http::ok(Edu::myAttendance(Ctx::auth(), Ctx::id())));
    Route::get('classes/{id}/my-assignments', fn () => Http::ok(Edu::myAssignments(Ctx::auth(), Ctx::id())));
    Route::get('classes/{id}/my-results', fn () => Http::ok(Edu::myResults(Ctx::auth(), Ctx::id())));
    Route::get('my-outcomes', fn () => Http::ok(EduOutcomes::forStudent(Ctx::auth())));
    Route::get('my-certificates', fn () => Http::ok(EduCertificates::myCertificates(Ctx::auth()->id)));
    Route::get('me/report-card', fn () => Http::ok(\App\Mz\Services\EduReportCard::generateData(Ctx::auth(), Ctx::auth()->id)));
    Route::get('students/{id}/report-card', fn () => Http::ok(\App\Mz\Services\EduReportCard::generateData(Ctx::auth(), Ctx::id())));
    Route::get('me/report-card/pdf', function () {
        $pdf = \App\Mz\Services\EduReportCard::generatePdf(Ctx::auth(), Ctx::auth()->id);
        return response($pdf, 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'inline; filename="report_card.pdf"',
        ]);
    });
    Route::get('students/{id}/report-card/pdf', function () {
        $pdf = \App\Mz\Services\EduReportCard::generatePdf(Ctx::auth(), Ctx::id());
        return response($pdf, 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'inline; filename="student_' . Ctx::id() . '_report_card.pdf"',
        ]);
    });
    Route::get('courses/{id}/completion', function () {
        $auth = Ctx::auth();
        $targetUid = $auth->id;
        $courseId = Ctx::id();
        $q = Ctx::q();
        if (! empty($q['user_id']) && is_numeric($q['user_id'])) {
            $reqUid = (int) $q['user_id'];
            if ($reqUid === $auth->id || $auth->isAdmin || $auth->can('education.manage') || $auth->can('education.view') || $auth->can('education.reports')) {
                $targetUid = $reqUid;
            } else {
                $course = DB::table('edu_courses')->where('id', $courseId)->first();
                $isAuthorizedTeacher = false;
                if ($course) {
                    $isAuthorizedTeacher = ($course->teacher_user_id == $auth->id)
                        || (Schema::hasTable('edu_course_teachers') && DB::table('edu_course_teachers')->where(['course_id' => $courseId, 'user_id' => $auth->id, 'status' => 'active'])->exists())
                        || ($course->class_id && Schema::hasTable('edu_class_staff') && DB::table('edu_class_staff')->where(['class_id' => $course->class_id, 'user_id' => $auth->id])->exists());
                }
                if ($isAuthorizedTeacher) {
                    $targetUid = $reqUid;
                } else {
                    throw ApiError::forbidden('FORBIDDEN', 'You cannot inspect another student\'s progress');
                }
            }
        }
        return Http::ok(EduLearning::courseCompletion($targetUid, $courseId));
    });
    Route::get('classes/{id}/students', function () {
        $id = Ctx::id();
        $q = Ctx::q();
        return Http::page(Edu::students(Ctx::auth(), $id, is_string($q['q'] ?? null) ? $q['q'] : null, Page::params($q)));
    });

    // ---- attendance (takers, teachers, moderator) ----
    Route::get('classes/{id}/attendance', function () {
        $id = Ctx::id();
        $d = Ctx::q()['date'] ?? '';
        $date = is_string($d) && preg_match('/^\d{4}-\d{2}-\d{2}$/', $d) ? $d : Dates::todayLocal();
        return Http::ok(Edu::roster(Ctx::auth(), $id, $date), ['date' => $date]);
    });
    Route::put('classes/{id}/attendance', function () {
        $id = Ctx::id();
        return Http::ok(Edu::mark(Ctx::auth(), $id, Ctx::body(Z::object(['date' => V::dateOnly(), 'user_id' => V::id(), 'status' => EduSchemas::status()]))));
    });
    Route::post('classes/{id}/attendance/scan', function () {
        $id = Ctx::id();
        return Http::ok(Edu::markByQr(Ctx::auth(), $id, Ctx::body(Z::object(['date' => V::dateOnly(), 'uuid' => Z::string()->uuid('INVALID_QR'), 'status' => EduSchemas::status()->default('present')]))));
    });

    // ---- teachers ----
    Route::get('courses/{id}', fn () => Http::ok(Edu::courseForTeacher(Ctx::auth(), Ctx::id())));
    Route::post('courses/{id}/groups', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['name' => V::text(1, 100), 'user_ids' => Z::array(V::id())->max(500)->optional()]));
        return Http::created(Edu::createGroup(Ctx::auth(), $id, $b['name'], $b['user_ids'] ?? []));
    });
    Route::put('groups/{id}/members', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['user_ids' => Z::array(V::id())->max(500)]));
        return Http::ok(Edu::setGroupMembers(Ctx::auth(), $id, $b['user_ids']));
    });
    Route::delete('groups/{id}', fn () => Http::ok(Edu::deleteGroup(Ctx::auth(), Ctx::id())));
    Route::post('assignments/{id}/file', function () {
        $id = Ctx::id();
        return Http::ok(Edu::setAssignmentFile(Ctx::auth(), $id, Upload::single('document')));
    });
    Route::put('submissions/{id}/grade', function () {
        $id = Ctx::id();
        return Http::ok(Edu::grade(Ctx::auth(), $id, Ctx::body(Z::object(['score' => EduSchemas::score()->nullable(), 'feedback' => V::optionalText(2000)]))));
    });
    Route::get('submissions/{id}/versions', fn () => Http::ok(Edu::submissionVersions(Ctx::auth(), Ctx::id())));
    Route::get('courses/{id}/assessments', fn () => Http::ok(Edu::assessments(Ctx::auth(), Ctx::id())));
    Route::post('courses/{id}/assessments', function () {
        $id = Ctx::id();
        return Http::created(Edu::createAssessment(Ctx::auth(), $id, Ctx::body(EduSchemas::assessment())));
    });
    Route::patch('assessments/{id}', function () {
        $id = Ctx::id();
        return Http::ok(Edu::updateAssessment(Ctx::auth(), $id, Ctx::body(EduSchemas::assessment()->partial()->strict())));
    });
    Route::delete('assessments/{id}', function () {
        Edu::deleteAssessment(Ctx::auth(), Ctx::id());
        return Http::ok(null);
    });
    Route::get('assessments/{id}/scores', fn () => Http::ok(Edu::scoreSheet(Ctx::auth(), Ctx::id())));
    Route::put('assessments/{id}/scores', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['scores' => Z::array(Z::object(['user_id' => V::id(), 'score' => EduSchemas::score()->nullable(), 'remark' => V::optionalText(300)]))->max(2000)]));
        return Http::ok(Edu::saveScores(Ctx::auth(), $id, $b['scores']));
    });

    // ---- outcomes (F10) & retakes (F11) ----
    Route::get('courses/{id}/outcomes', fn () => Http::ok(EduOutcomes::forCourse(Ctx::auth(), Ctx::id())));
    Route::post('courses/{id}/outcomes/compute', fn () => Http::ok(EduOutcomes::compute(Ctx::id())));
    Route::post('courses/{id}/outcomes/finalize', function () {
        $id = Ctx::id();
        $b = Ctx::input();
        $ids = isset($b['ids']) && is_array($b['ids']) ? $b['ids'] : null;
        return Http::ok(EduOutcomes::finalize(Ctx::auth(), $id, $ids));
    });
    Route::post('outcomes/{id}/counting', function () {
        $id = Ctx::id();
        $b = Ctx::input();
        $reason = is_string($b['reason'] ?? null) ? $b['reason'] : 'Set counting';
        return Http::ok(EduOutcomes::setCounting(Ctx::auth(), $id, $reason));
    });

    Route::post('outcomes/{id}/retake', fn () => Http::created(EduRetakes::request(Ctx::auth(), Ctx::id())));
    Route::get('retakes', fn () => Http::ok(EduRetakes::list(Ctx::auth(), Ctx::q())));
    Route::post('retakes/{id}/decide', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object([
            'decision' => Z::enum(['approved', 'rejected']),
            'note' => V::optionalText(500),
        ])->strict());
        return Http::ok(EduRetakes::decide(Ctx::auth(), $id, $b['decision'], $b['note'] ?? null));
    });

    // ---- certificates (F13) ----
    Route::get('courses/{id}/certificates/eligible', fn () => Http::ok(EduCertificates::eligible(Ctx::auth(), Ctx::id())));
    Route::post('courses/{id}/certificates/issue', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['user_ids' => Z::array(V::id())->min(1)]));
        return Http::created(EduCertificates::issue(Ctx::auth(), $id, $b['user_ids']));
    });
    Route::get('certificates', function () {
        $q = Ctx::q();
        $courseId = isset($q['course_id']) ? (int) $q['course_id'] : null;
        $userId = isset($q['user_id']) ? (int) $q['user_id'] : null;
        return Http::ok(EduCertificates::list(Ctx::auth(), $courseId, $userId));
    });
    Route::post('certificates/{id}/revoke', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['reason' => V::text(500)]));
        return Http::ok(EduCertificates::revoke(Ctx::auth(), $id, $b['reason']));
    });
    Route::post('certificates/{id}/reissue', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['reason' => V::text(500)]));
        return Http::created(EduCertificates::reissue(Ctx::auth(), $id, $b['reason']));
    });
    Route::get('certificates/{id}/pdf', function () {
        $pdf = EduCertificates::renderPdf(Ctx::id());
        return response($pdf, 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'inline; filename="certificate.pdf"',
        ]);
    });

    // ---- admin scores & activity (F15) ----
    Route::get('admin/scores', function () {
        $q = Ctx::q();
        $yearId = isset($q['year_id']) ? (int) $q['year_id'] : (isset($q['academic_year_id']) ? (int) $q['academic_year_id'] : null);
        $termId = isset($q['term_id']) ? (int) $q['term_id'] : null;
        $classId = isset($q['class_id']) ? (int) $q['class_id'] : null;
        $courseId = isset($q['course_id']) ? (int) $q['course_id'] : null;
        $group = isset($q['group']) ? (string) $q['group'] : null;
        $scores = EduScores::forPeriod(Ctx::auth(), $yearId, $termId, $classId, $courseId, $group);
        return Http::ok(['scores' => $scores]);
    });
    Route::get('admin/activity', function () {
        $q = Ctx::q();
        $yearId = isset($q['year_id']) ? (int) $q['year_id'] : (isset($q['academic_year_id']) ? (int) $q['academic_year_id'] : null);
        $classId = isset($q['class_id']) ? (int) $q['class_id'] : null;
        return Http::ok(EduScores::activityReport(Ctx::auth(), $yearId, $classId));
    });

    // ---- moderator ----
    // Student registration by an administrator (registrar role: education.register).
    Route::middleware('mz:any,education.register,education.manage')->prefix('registrations')->group(function () {
        Route::get('classes', fn () => Http::ok(\App\Mz\Services\EduRegistration::classes(isset(Ctx::q()['academic_year_id']) ? (int) Ctx::q()['academic_year_id'] : null)));
        Route::get('classes/{id}/students', fn () => Http::ok(\App\Mz\Services\EduRegistration::students(Ctx::id())));
        Route::get('classes/{id}/assignable', function () {
            $id = Ctx::id();
            $q = Ctx::q();
            return Http::page(\App\Mz\Services\EduRegistration::assignable($id, is_string($q['q'] ?? null) ? $q['q'] : null, is_string($q['group'] ?? null) ? $q['group'] : null, Page::params($q)));
        });
        Route::post('classes/{id}/assign', function () {
            $id = Ctx::id();
            return Http::ok(\App\Mz\Services\EduRegistration::assign(Ctx::actx(), $id, Ctx::body(EduSchemas::assign())));
        });
        Route::post('/', function () {
            $b = Ctx::body(Z::object([
                'class_id' => V::id(),
                'program' => Z::enum(['regular', 'distance'])->default('regular'),
                'user_ids' => Z::array(V::id())->max(500)->optional(),
                'new_user' => Z::object([
                    'full_name' => V::text(2, 150),
                    'phone' => V::phone(),
                    'member_group' => V::memberGroup()->optional(),
                    'member_type' => Z::enum(['student', 'worker'])->nullable()->optional(),
                ])->optional(),
            ]));
            return Http::created(\App\Mz\Services\EduRegistration::register(Ctx::actx(), $b));
        });
        Route::delete('classes/{id}/students/{userId}', fn () => Http::ok(\App\Mz\Services\EduRegistration::unregister(Ctx::actx(), Ctx::id(), Ctx::id('userId'))));
    });

    // Level route aliases so /edu/levels/$id resolves seamlessly
    Route::middleware('mz:all,education.manage')->group(function () {
        Route::get('levels', fn () => Http::ok(\App\Mz\Services\EduAcademicYears::listLevels()));
        Route::patch('levels/{id}', function () {
            $id = Ctx::id();
            return Http::ok(\App\Mz\Services\EduAcademicYears::updateLevel(Ctx::actx(), $id, Ctx::body(EduSchemas::level()->partial()->strict())));
        });
    });

    // Class Assignment & Enrolment (accessible by education.register and education.manage)
    Route::middleware('mz:any,education.register,education.manage')->prefix('admin')->group(function () {
        Route::get('classes/{id}/assignable', function () {
            $id = Ctx::id();
            $q = Ctx::q();
            return Http::page(\App\Mz\Services\EduRegistration::assignable($id, is_string($q['q'] ?? null) ? $q['q'] : null, is_string($q['group'] ?? null) ? $q['group'] : null, Page::params($q)));
        });
        Route::post('classes/{id}/assign', function () {
            $id = Ctx::id();
            return Http::ok(\App\Mz\Services\EduRegistration::assign(Ctx::actx(), $id, Ctx::body(EduSchemas::assign())));
        });
    });

    // Education Attendance Dashboard (Admin)
    Route::middleware('mz:any,education.manage,education.view,education.reports,education.attendance_view,attendance.manage,attendance.view')
        ->prefix('admin/attendance')->group(function () {
            Route::get('dashboard', fn () => Http::ok(\App\Mz\Services\EduAttendance::dashboard(Ctx::auth(), Ctx::q())));
            Route::get('student/{userId}', fn () => Http::ok(\App\Mz\Services\EduAttendance::studentProfile(Ctx::auth(), Ctx::id('userId'), Ctx::q())));
            Route::get('record/{id}', fn () => Http::ok(\App\Mz\Services\EduAttendance::recordDetail(Ctx::auth(), Ctx::id())));
        });

    Route::middleware('mz:all,education.manage')->prefix('admin')->group(function () {
        Route::get('classes', fn () => Http::ok(Edu::adminClasses(is_string(Ctx::q()['status'] ?? null) ? Ctx::q()['status'] : null, isset(Ctx::q()['academic_year_id']) ? (int) Ctx::q()['academic_year_id'] : null)));
        Route::post('classes', fn () => Http::created(Edu::createClass(Ctx::actx(), Ctx::body(EduSchemas::klass()))));
        Route::patch('classes/{id}', function () {
            $id = Ctx::id();
            return Http::ok(Edu::updateClass(Ctx::actx(), $id, Ctx::body(EduSchemas::klass()->partial()->strict())));
        });
        Route::delete('classes/{id}', function () {
            Edu::deleteClass(Ctx::actx(), Ctx::id());
            return Http::ok(null);
        });
        Route::get('curriculum/preview/{levelId}', fn () => Http::ok(Edu::curriculumPreview(Ctx::id('levelId'))));
        Route::post('curriculum/sync', fn () => Http::ok(Edu::syncCurriculum(Ctx::actx())));
        Route::post('classes/{id}/sync-curriculum', fn () => Http::ok(Edu::syncClassCurriculum(Ctx::actx(), Ctx::id())));
        Route::post('classes/sync-grades', function () {
            $b = Ctx::input();
            $yearId = isset($b['academic_year_id']) ? (int) $b['academic_year_id'] : null;
            return Http::ok(Edu::ensureGradeClasses($yearId));
        });

        // Class Transfers & Promotion (F2)
        Route::post('enrollments/{id}/transfer', function () {
            $id = Ctx::id();
            $b = Ctx::body(EduSchemas::transfer());
            return Http::ok(\App\Mz\Services\EduRegistration::transfer(Ctx::actx(), $id, (int) $b['target_class_id'], $b['reason']));
        });
        Route::post('enrollments/{id}/promote', function () {
            $id = Ctx::id();
            $b = Ctx::body(EduSchemas::transfer());
            return Http::ok(\App\Mz\Services\EduRegistration::promote(Ctx::actx(), $id, (int) $b['target_class_id'], $b['reason']));
        });

        // Academic Calendar: Years, Terms, Levels (F1)
        Route::get('academic-years', fn () => Http::ok(\App\Mz\Services\EduAcademicYears::listYears(Ctx::q())));
        Route::post('academic-years', fn () => Http::created(\App\Mz\Services\EduAcademicYears::createYear(Ctx::actx(), Ctx::body(EduSchemas::academicYear()))));
        Route::get('academic-years/{id}', fn () => Http::ok(\App\Mz\Services\EduAcademicYears::getYear(Ctx::id())));
        Route::patch('academic-years/{id}', function () {
            $id = Ctx::id();
            return Http::ok(\App\Mz\Services\EduAcademicYears::updateYear(Ctx::actx(), $id, Ctx::body(EduSchemas::academicYear()->partial()->strict())));
        });
        Route::post('academic-years/{id}/current', fn () => Http::ok(\App\Mz\Services\EduAcademicYears::setCurrent(Ctx::actx(), Ctx::id())));
        Route::post('academic-years/{id}/close', fn () => Http::ok(\App\Mz\Services\EduAcademicYears::closeYear(Ctx::actx(), Ctx::id())));
        Route::delete('academic-years/{id}', function () {
            \App\Mz\Services\EduAcademicYears::deleteYear(Ctx::actx(), Ctx::id());
            return Http::ok(null);
        });

        Route::get('academic-years/{id}/terms', fn () => Http::ok(\App\Mz\Services\EduAcademicYears::listTerms(Ctx::id())));
        Route::post('academic-years/{id}/terms', function () {
            $yearId = Ctx::id();
            return Http::created(\App\Mz\Services\EduAcademicYears::createTerm(Ctx::actx(), $yearId, Ctx::body(EduSchemas::term())));
        });
        Route::patch('terms/{id}', function () {
            $id = Ctx::id();
            return Http::ok(\App\Mz\Services\EduAcademicYears::updateTerm(Ctx::actx(), $id, Ctx::body(EduSchemas::term()->partial()->strict())));
        });
        Route::delete('terms/{id}', function () {
            \App\Mz\Services\EduAcademicYears::deleteTerm(Ctx::actx(), Ctx::id());
            return Http::ok(null);
        });

        Route::get('levels', fn () => Http::ok(\App\Mz\Services\EduAcademicYears::listLevels()));
        Route::get('grades', fn () => Http::ok(\App\Mz\Services\EduAcademicYears::adminGrades(Ctx::auth())));
        Route::get('grades/{id}', fn () => Http::ok(\App\Mz\Services\EduAcademicYears::getGradeDetail(Ctx::auth(), Ctx::id())));
        Route::post('levels', fn () => Http::created(\App\Mz\Services\EduAcademicYears::createLevel(Ctx::actx(), Ctx::body(EduSchemas::level()))));
        Route::patch('levels/{id}', function () {
            $id = Ctx::id();
            return Http::ok(\App\Mz\Services\EduAcademicYears::updateLevel(Ctx::actx(), $id, Ctx::body(EduSchemas::level()->partial()->strict())));
        });
        Route::delete('levels/{id}', function () {
            \App\Mz\Services\EduAcademicYears::deleteLevel(Ctx::actx(), Ctx::id());
            return Http::ok(null);
        });

        Route::post('classes/{id}/courses', function () {
            $id = Ctx::id();
            return Http::created(Edu::createCourse(Ctx::actx(), $id, Ctx::body(EduSchemas::course())));
        });
        Route::patch('courses/{id}', function () {
            $id = Ctx::id();
            return Http::ok(Edu::updateCourse(Ctx::actx(), $id, Ctx::body(EduSchemas::course()->partial()->strict())));
        });
        Route::delete('courses/{id}', function () {
            Edu::deleteCourse(Ctx::actx(), Ctx::id());
            return Http::ok(null);
        });
        Route::get('schedules', function () {
            $q = Ctx::query(Z::object([
                'academic_year_id' => V::id()->optional(),
                'class_id' => V::id()->optional(),
            ]));
            return Http::ok(Edu::allSchedules($q['academic_year_id'] ?? null, $q['class_id'] ?? null));
        });
        Route::get('classes/{id}/schedule', fn () => Http::ok(Edu::schedule(Ctx::id())));
        Route::put('classes/{id}/schedule', function () {
            $id = Ctx::id();
            $b = Ctx::body(Z::object(['items' => Z::array(Z::object([
                'course_id' => V::id()->nullable()->optional(),
                'weekday' => Z::number()->int()->min(1)->max(7),
                // weekly (2 / 4 days a week = 2 / 4 rows) or monthly (1st–4th / 5 = last such weekday of the Ethiopian month)
                'frequency' => Z::enum(['weekly', 'monthly'])->optional(),
                'week_of_month' => Z::number()->int()->min(1)->max(5)->nullable()->optional(),
                'program' => Z::enum(['all', 'regular', 'distance'])->optional(),
                'mode' => Z::enum(['in_person', 'online'])->optional(),
                'starts' => EduSchemas::time(),
                'ends' => EduSchemas::time(),
                'location' => V::optionalText(150),
            ]))->max(100)]));
            return Http::ok(Edu::setSchedule(Ctx::actx(), $id, $b['items']));
        });
        Route::get('classes/{id}/staff', fn () => Http::ok(Edu::staff(Ctx::id())));
        Route::post('classes/{id}/staff', function () {
            $id = Ctx::id();
            $b = Ctx::body(Z::object(['user_id' => V::id()]));
            return Http::ok(Edu::addStaff(Ctx::actx(), $id, $b['user_id']));
        });
        Route::delete('classes/{id}/staff/{userId}', fn () => Http::ok(Edu::removeStaff(Ctx::actx(), Ctx::id(), Ctx::id('userId'))));
        Route::delete('classes/{id}/students/{userId}', function () {
            Edu::removeEnrollment(Ctx::actx(), Ctx::id(), Ctx::id('userId'));
            return Http::ok(null);
        });
    });
});

<?php

use App\Mz\Http\Ctx;
use App\Mz\Http\Upload;
use App\Mz\Services\EduDashboard;
use App\Mz\Services\EduLearning;
use App\Mz\Services\EduMagazines;
use App\Mz\Services\EduQuizzes;
use App\Mz\Services\EduScores;
use App\Mz\Support\EduSchemas;
use App\Mz\Support\Http;
use App\Mz\Support\Page;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// ትምህርት learning platform: the home dashboard, the catalog (categories → subjects → units →
// lessons → materials), progress, search, the featured banner and digital quizzes. Every rule is
// enforced in the services (EduLearning, EduQuizzes); the app only hides what is not allowed.
// Public streaming & download for magazine PDFs (allows guests and in-app readers)
Route::get('edu/magazines/{id}/pdf', fn () => EduMagazines::streamPdf(Ctx::id()));
Route::get('edu/magazines/{id}/download', fn () => EduMagazines::streamPdf(Ctx::id(), true));

Route::prefix('edu')->middleware(['mz', 'mz.module:education'])->group(function () {
    $all = fn () => in_array(Ctx::q()['all'] ?? null, ['1', 'true'], true);

    // ---- home / progress / scores / search ----
    Route::get('me/dashboard', fn () => Http::ok(EduDashboard::forUser(Ctx::auth())));
    Route::get('me/progress', fn () => Http::ok(EduDashboard::progress(Ctx::auth())));
    Route::get('me/scores', fn () => Http::ok(EduScores::forStudent(Ctx::auth(), Ctx::auth()->id)));
    Route::get('students/{id}/scores', fn () => Http::ok(EduScores::forStudent(Ctx::auth(), Ctx::id())));
    Route::get('me/bookmarks', fn () => Http::ok(EduLearning::bookmarks(Ctx::auth())));
    Route::get('search', fn () => Http::ok(EduLearning::search(Ctx::auth(), mb_substr((string) (Ctx::q()['q'] ?? ''), 0, 100))));

    // ---- catalog (members) ----
    Route::get('categories', fn () => Http::ok(EduLearning::categories(Ctx::auth(), $all())));
    Route::get('categories/{id}/subjects', fn () => Http::ok(EduLearning::subjects(Ctx::auth(), Ctx::id(), $all())));
    Route::get('subjects', fn () => Http::ok(EduLearning::subjects(Ctx::auth(), null, $all())));
    Route::get('subjects/authoring', fn () => Http::ok(EduLearning::editableSubjects(Ctx::auth())));
    Route::get('subjects/{id}', fn () => Http::ok(EduLearning::subjectDetail(Ctx::auth(), Ctx::id())));
    Route::get('subjects/{id}/grades', fn () => Http::ok(EduLearning::subjectGrades(Ctx::auth(), Ctx::id())));
    Route::get('subjects/{id}/grades/{grade}', fn () => Http::ok(EduLearning::subjectGradeContent(Ctx::auth(), Ctx::id(), (int) request()->route('grade'))));
    Route::get('lessons/{id}', fn () => Http::ok(EduLearning::lessonDetail(Ctx::auth(), Ctx::id())));
    Route::post('lessons/{id}/progress', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['action' => Z::enum(['complete', 'uncomplete', 'bookmark', 'unbookmark'])])->strict());
        return Http::ok(EduLearning::setProgress(Ctx::auth(), $id, $b['action']));
    });
    Route::get('materials', fn () => Http::ok(EduLearning::allMaterials(Ctx::auth(), Ctx::q())));
    Route::get('materials/{id}/file', function () {
        $f = EduLearning::materialFile(Ctx::auth(), Ctx::id());
        return response()->file($f['abs'], [
            'Content-Type' => $f['mime'],
            'Cache-Control' => 'private, no-store',
            'Content-Disposition' => "attachment; filename*=UTF-8''" . rawurlencode($f['name']),
        ]);
    });
    Route::get('featured', fn () => Http::ok(EduLearning::featured(Ctx::auth(), $all())));

    // ---- authoring: units, lessons, materials (content editors, or the subject's active teachers) ----
    Route::get('units/{id}', fn () => Http::ok(EduLearning::unitDetail(Ctx::auth(), Ctx::id())));
    Route::post('units', function () {
        $b = Ctx::body(EduSchemas::unit()->extend(['subject_id' => V::id()])->strict());
        $subjectId = (int) $b['subject_id'];
        unset($b['subject_id']);
        return Http::created(EduLearning::createUnit(Ctx::actx(), $subjectId, $b));
    });
    Route::post('subjects/{id}/units', function () {
        $id = Ctx::id();
        $b = Ctx::body(EduSchemas::unit());
        unset($b['subject_id']);
        return Http::created(EduLearning::createUnit(Ctx::actx(), $id, $b));
    });
    Route::put('subjects/{id}/units/order', function () {
        $id = Ctx::id();
        return Http::ok(EduLearning::reorderUnits(Ctx::actx(), $id, Ctx::body(EduSchemas::ids())['ids']));
    });
    Route::patch('units/{id}', function () {
        $id = Ctx::id();
        $b = Ctx::body(EduSchemas::unit()->partial()->strict());
        unset($b['subject_id']);
        return Http::ok(EduLearning::updateUnit(Ctx::actx(), $id, $b));
    });
    Route::delete('units/{id}', fn () => Http::ok(EduLearning::deleteUnit(Ctx::actx(), Ctx::id())));
    Route::post('subjects/{id}/lessons', function () {
        $id = Ctx::id();
        return Http::created(EduLearning::createLesson(Ctx::actx(), $id, Ctx::body(EduSchemas::lesson())));
    });
    Route::put('subjects/{id}/lessons/order', function () {
        $id = Ctx::id();
        return Http::ok(EduLearning::reorderLessons(Ctx::actx(), $id, Ctx::body(EduSchemas::ids())['ids']));
    });
    Route::patch('lessons/{id}', function () {
        $id = Ctx::id();
        return Http::ok(EduLearning::updateLesson(Ctx::actx(), $id, Ctx::body(EduSchemas::lesson()->partial()->strict())));
    });
    Route::delete('lessons/{id}', function () {
        EduLearning::deleteLesson(Ctx::actx(), Ctx::id());
        return Http::ok(null);
    });
    Route::post('lessons/{id}/materials', function () {
        $id = Ctx::id();
        $file = Upload::single('lesson');
        $title = Ctx::input()['title'] ?? null;
        return Http::created(EduLearning::addMaterialFile(Ctx::actx(), $id, $file, is_string($title) ? (mb_substr(trim($title), 0, 200) ?: null) : null));
    });
    Route::post('lessons/{id}/links', function () {
        $id = Ctx::id();
        return Http::created(EduLearning::addMaterialLink(Ctx::actx(), $id, Ctx::body(EduSchemas::materialLink())));
    });
    Route::patch('materials/{id}', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['title' => V::text(1, 200)->optional(), 'sort_order' => Z::number()->int()->min(0)->max(100000)->optional(), 'url' => Z::string()->trim()->max(1000)->regex('#^https?://\S+$#i', 'INVALID_URL')->optional()])->strict());
        return Http::ok(EduLearning::updateMaterial(Ctx::actx(), $id, $b));
    });
    Route::delete('materials/{id}', function () {
        EduLearning::deleteMaterial(Ctx::actx(), Ctx::id());
        return Http::ok(null);
    });

    // ---- direct materials (Category & Grade without a lesson) ----
    Route::get('categories/{id}/grades/{grade}/materials', function () {
        return Http::ok(EduLearning::directMaterials(Ctx::auth(), Ctx::id(), (int) request()->route('grade')));
    });
    Route::post('categories/{id}/grades/{grade}/materials', function () {
        $catId = Ctx::id();
        $grade = (int) request()->route('grade');
        $file = Upload::single('material');
        $input = Ctx::input();
        $meta = [
            'category_id' => $catId,
            'grade' => $grade,
            'subject_id' => ! empty($input['subject_id']) ? (int) $input['subject_id'] : null,
            'title' => $input['title'] ?? null,
            'title_en' => $input['title_en'] ?? null,
            'description' => $input['description'] ?? null,
            'description_en' => $input['description_en'] ?? null,
            'status' => $input['status'] ?? 'published',
            'kind' => $input['kind'] ?? ($file ? 'file' : 'link'),
            'url' => $input['url'] ?? null,
        ];
        if ($file) {
            return Http::created(EduLearning::addDirectMaterialFile(Ctx::actx(), $meta, $file));
        }
        return Http::created(EduLearning::addDirectMaterialLink(Ctx::actx(), $meta));
    });
    Route::post('categories/{id}/grades/{grade}/materials/link', function () {
        $catId = Ctx::id();
        $grade = (int) request()->route('grade');
        $b = Ctx::body(EduSchemas::materialLink()->extend([
            'category_id' => V::id()->optional(),
            'grade' => Z::coerceNumber()->int()->min(1)->max(12)->optional(),
            'subject_id' => V::id()->optional(),
        ]));
        $meta = [
            'category_id' => $catId,
            'grade' => $grade,
            'subject_id' => ! empty($b['subject_id']) ? (int) $b['subject_id'] : null,
            'title' => $b['title'],
            'title_en' => $b['title_en'] ?? null,
            'description' => $b['description'] ?? null,
            'description_en' => $b['description_en'] ?? null,
            'status' => 'published',
            'kind' => $b['kind'] ?? 'link',
            'url' => $b['url'],
        ];
        return Http::created(EduLearning::addDirectMaterialLink(Ctx::actx(), $meta));
    });

    // ---- content editors: categories, subjects, featured (education.content / education.manage) ----
    Route::middleware('mz:any,education.content,education.manage')->prefix('content')->group(function () {
        Route::post('categories', fn () => Http::created(EduLearning::createCategory(Ctx::actx(), Ctx::body(EduSchemas::category()))));
        Route::put('categories/order', fn () => Http::ok(EduLearning::reorderCategories(Ctx::actx(), Ctx::body(EduSchemas::ids())['ids'])));
        Route::patch('categories/{id}', function () {
            $id = Ctx::id();
            return Http::ok(EduLearning::updateCategory(Ctx::actx(), $id, Ctx::body(EduSchemas::category()->partial()->strict())));
        });
        Route::post('categories/{id}/image', fn () => Http::ok(EduLearning::setCategoryImage(Ctx::actx(), Ctx::id(), Upload::single('image'))));
        Route::delete('categories/{id}/image', fn () => Http::ok(EduLearning::setCategoryImage(Ctx::actx(), Ctx::id(), null)));
        Route::delete('categories/{id}', function () {
            EduLearning::deleteCategory(Ctx::actx(), Ctx::id());
            return Http::ok(null);
        });
        Route::post('subjects', fn () => Http::created(EduLearning::createSubject(Ctx::actx(), Ctx::body(EduSchemas::subject()))));
        Route::patch('subjects/{id}', function () {
            $id = Ctx::id();
            return Http::ok(EduLearning::updateSubject(Ctx::actx(), $id, Ctx::body(EduSchemas::subject()->partial()->strict())));
        });
        Route::post('subjects/{id}/cover', fn () => Http::ok(EduLearning::setSubjectCover(Ctx::actx(), Ctx::id(), Upload::single('image'))));
        Route::delete('subjects/{id}/cover', fn () => Http::ok(EduLearning::setSubjectCover(Ctx::actx(), Ctx::id(), null)));
        Route::delete('subjects/{id}', function () {
            EduLearning::deleteSubject(Ctx::actx(), Ctx::id());
            return Http::ok(null);
        });
        Route::post('featured', fn () => Http::created(EduLearning::createFeatured(Ctx::actx(), Ctx::body(EduSchemas::featured()))));
        Route::patch('featured/{id}', function () {
            $id = Ctx::id();
            return Http::ok(EduLearning::updateFeatured(Ctx::actx(), $id, Ctx::body(EduSchemas::featured()->partial()->strict())));
        });
        Route::post('featured/{id}/image', fn () => Http::ok(EduLearning::setFeaturedImage(Ctx::actx(), Ctx::id(), Upload::single('image'))));
        Route::delete('featured/{id}', fn () => Http::ok(EduLearning::deleteFeatured(Ctx::actx(), Ctx::id())));
    });

    // ---- quizzes: students ----
    Route::get('me/quizzes', function () {
        $c = Ctx::q()['course_id'] ?? null;
        return Http::ok(EduQuizzes::mine(Ctx::auth(), is_numeric($c) ? (int) $c : null));
    });
    Route::post('quizzes/{id}/attempts', fn () => Http::ok(EduQuizzes::start(Ctx::auth(), Ctx::id())));
    Route::get('attempts/{id}', fn () => Http::ok(EduQuizzes::studentAttempt(Ctx::auth(), Ctx::id())));
    Route::put('attempts/{id}/answers', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['answers' => EduSchemas::answers()])->strict());
        return Http::ok(EduQuizzes::saveAnswers(Ctx::auth(), $id, $b['answers']));
    });
    Route::post('attempts/{id}/check', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['question_id' => V::id(), 'response' => Z::any()->optional()])->strict());
        return Http::ok(EduQuizzes::check(Ctx::auth(), $id, $b['question_id'], $b['response'] ?? null));
    });
    Route::post('attempts/{id}/submit', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['answers' => EduSchemas::answers()->optional()])->strict());
        return Http::ok(EduQuizzes::submit(Ctx::auth(), $id, $b['answers'] ?? null));
    });

    // ---- quizzes: teachers & subject editors ----
    Route::get('admin/quizzes', fn () => Http::ok(EduQuizzes::allAdminQuizzes(Ctx::auth(), Ctx::q())));
    Route::get('quizzes/{id}/prerequisites', fn () => Http::ok(EduQuizzes::checkPrerequisites(Ctx::id())));
    Route::post('courses/{id}/assessments/ensure-final', function () {
        $courseId = Ctx::id();
        $auth = Ctx::auth();
        $course = DB::table('edu_courses')->where('id', $courseId)->first();
        if (! $course) throw \App\Mz\Support\ApiError::notFound('COURSE_NOT_FOUND', 'Course not found');
        if (! (App\Mz\Services\Edu::isModerator($auth) || App\Mz\Services\EduTeachers::isActive($courseId, $auth->id) || (! empty($course->subject_id) && App\Mz\Services\EduLearning::canEditSubject($auth, (int) $course->subject_id)))) {
            App\Mz\Services\Edu::assertTeachesCourse($auth, $courseId);
        }
        $existing = DB::table('edu_assessments')
            ->where('course_id', $courseId)
            ->where(function ($w) {
                $w->where('title', 'like', '%final%')
                  ->orWhere('title', 'like', '%exam%')
                  ->orWhere('title', 'like', '%ማጠቃለያ%');
            })
            ->first();
        if ($existing) {
            return Http::ok([
                'id' => (int) $existing->id,
                'assessment_id' => (int) $existing->id,
                'title' => $existing->title,
            ]);
        }
        $firstAss = DB::table('edu_assessments')->where('course_id', $courseId)->first();
        if ($firstAss) {
            return Http::ok([
                'id' => (int) $firstAss->id,
                'assessment_id' => (int) $firstAss->id,
                'title' => $firstAss->title,
            ]);
        }
        $insert = [
            'course_id' => $courseId,
            'title' => ($course->name ?? 'Course') . ' - Final Exam (የማጠቃለያ ፈተና)',
            'created_at' => now(),
            'updated_at' => now(),
        ];
        if (\Illuminate\Support\Facades\Schema::hasColumn('edu_assessments', 'max_score')) $insert['max_score'] = 100;
        if (\Illuminate\Support\Facades\Schema::hasColumn('edu_assessments', 'weight')) $insert['weight'] = 50;
        if (\Illuminate\Support\Facades\Schema::hasColumn('edu_assessments', 'held_on')) $insert['held_on'] = \App\Mz\Support\Dates::sql(\App\Mz\Support\Dates::now());
        $newId = DB::table('edu_assessments')->insertGetId($insert);
        return Http::created([
            'id' => (int) $newId,
            'assessment_id' => (int) $newId,
            'title' => $insert['title'],
        ]);
    });
    Route::get('courses/{id}/quizzes', fn () => Http::ok(EduQuizzes::forCourse(Ctx::auth(), Ctx::id())));
    Route::post('courses/{id}/quizzes', function () {
        $id = Ctx::id();
        return Http::created(EduQuizzes::create(Ctx::actx(), $id, Ctx::body(EduSchemas::quiz())));
    });
    Route::get('subjects/{id}/quizzes', fn () => Http::ok(EduQuizzes::forSubject(Ctx::auth(), Ctx::id())));
    Route::post('subjects/{id}/quizzes', function () {
        $id = Ctx::id();
        return Http::created(EduQuizzes::createForSubject(Ctx::actx(), $id, Ctx::body(EduSchemas::quiz())));
    });
    Route::get('quizzes/{id}', fn () => Http::ok(EduQuizzes::quizDetail(Ctx::auth(), Ctx::id())));
    Route::patch('quizzes/{id}', function () {
        $id = Ctx::id();
        return Http::ok(EduQuizzes::update(Ctx::actx(), $id, Ctx::body(EduSchemas::quiz()->partial()->strict())));
    });
    Route::delete('quizzes/{id}', function () {
        EduQuizzes::delete(Ctx::actx(), Ctx::id());
        return Http::ok(null);
    });
    Route::put('quizzes/{id}/questions', function () {
        $id = Ctx::id();
        return Http::ok(EduQuizzes::setQuestions(Ctx::actx(), $id, Ctx::body(EduSchemas::questions())['questions']));
    });
    Route::get('quizzes/{id}/results', fn () => Http::ok(EduQuizzes::results(Ctx::auth(), Ctx::id())));
    Route::get('quiz-attempts/{id}', fn () => Http::ok(EduQuizzes::teacherAttempt(Ctx::auth(), Ctx::id())));
    Route::put('quiz-attempts/{id}/grade', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object([
            'question_id' => V::id(),
            'points' => Z::number()->min(0)->max(1000),
            'feedback' => Z::string()->max(2000)->nullable()->optional(),
        ])->strict());
        return Http::ok(EduQuizzes::gradeAnswer(Ctx::actx(), $id, $b['question_id'], (float) $b['points'], $b['feedback'] ?? null));
    });
    Route::post('quizzes/{id}/transfer', fn () => Http::ok(EduQuizzes::transfer(Ctx::actx(), Ctx::id())));

    // ---- question banks & draws (F12) ----
    Route::get('subjects/{id}/question-banks', fn () => Http::ok(EduQuizzes::listBanks(Ctx::auth(), Ctx::id())));
    Route::post('subjects/{id}/question-banks', function () {
        $id = Ctx::id();
        return Http::created(EduQuizzes::createBank(Ctx::actx(), $id, Ctx::body(EduSchemas::questionBank())));
    });
    Route::get('question-banks/{id}', fn () => Http::ok(EduQuizzes::getBank(Ctx::auth(), Ctx::id())));
    Route::put('question-banks/{id}/questions', function () {
        $id = Ctx::id();
        return Http::ok(EduQuizzes::setBankQuestions(Ctx::actx(), $id, Ctx::body(EduSchemas::questions())['questions']));
    });
    Route::delete('question-banks/{id}', function () {
        EduQuizzes::deleteBank(Ctx::actx(), Ctx::id());
        return Http::ok(null);
    });
    Route::get('quizzes/{id}/draws', fn () => Http::ok(EduQuizzes::getDraws(Ctx::auth(), Ctx::id())));
    Route::put('quizzes/{id}/draws', function () {
        $id = Ctx::id();
        return Http::ok(EduQuizzes::setDraws(Ctx::actx(), $id, Ctx::body(EduSchemas::draws())['draws']));
    });

    // ---- ሰሌዳ መጽሔት (Seleda Magazine) ----
    Route::get('magazines', function () {
        return Http::ok(EduMagazines::list(Ctx::auth(), Ctx::q(), Page::params(Ctx::q())));
    });
    Route::get('magazines/latest', fn () => Http::ok(EduMagazines::latest(Ctx::auth())));
    Route::get('magazines/{id}', fn () => Http::ok(EduMagazines::detail(Ctx::auth(), Ctx::id())));
    Route::post('magazines', function () {
        return Http::created(EduMagazines::create(Ctx::actx(), Ctx::body(EduSchemas::magazine())));
    });
    Route::put('magazines/{id}', function () {
        return Http::ok(EduMagazines::update(Ctx::actx(), Ctx::id(), Ctx::body(EduSchemas::magazineUpdate())));
    });
    Route::delete('magazines/{id}', function () {
        EduMagazines::delete(Ctx::actx(), Ctx::id());
        return Http::ok(null);
    });
    Route::post('magazines/{id}/file', function () {
        $file = Upload::single('document');
        return Http::ok(EduMagazines::uploadPdf(Ctx::actx(), Ctx::id(), $file));
    });
    Route::post('magazines/{id}/image', function () {
        $file = Upload::single('image');
        return Http::ok(EduMagazines::uploadCover(Ctx::actx(), Ctx::id(), $file));
    });
    Route::delete('magazines/{id}/image', function () {
        return Http::ok(EduMagazines::removeCover(Ctx::actx(), Ctx::id()));
    });
    Route::get('magazines/{id}/quizzes', fn () => Http::ok(EduMagazines::quizzes(Ctx::auth(), Ctx::id())));
    Route::post('magazines/{id}/quizzes', function () {
        $id = Ctx::id();
        $b = Ctx::body(EduSchemas::quiz());
        return Http::created(EduMagazines::createQuiz(Ctx::actx(), $id, $b));
    });
});

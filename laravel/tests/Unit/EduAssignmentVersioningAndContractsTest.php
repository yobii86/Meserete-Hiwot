<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\EduAnnouncements;
use App\Mz\Services\EduAssignments;
use App\Mz\Services\EduLearning;
use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class EduAssignmentVersioningAndContractsTest extends TestCase
{
    private AuthContext $adminAuth;
    private AuthContext $teacherAuth;
    private AuthContext $studentAuth1;
    private array $adminActx;
    private array $teacherActx;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();

        $this->adminAuth = $this->makeAuth(1, 'Admin', ['education.manage' => true, 'education.content' => true]);
        $this->teacherAuth = $this->makeAuth(2, 'Teacher Petros', ['education.content' => true]);
        $this->studentAuth1 = $this->makeAuth(3, 'Student Yohannes', []);

        $this->adminActx = ['auth' => $this->adminAuth];
        $this->teacherActx = ['auth' => $this->teacherAuth];

        foreach ([
            [1, 'Admin', 'admin'],
            [2, 'Teacher Petros', 'user'],
            [3, 'Student Yohannes', 'user'],
        ] as [$uid, $name, $type]) {
            DB::table('users')->updateOrInsert(['id' => $uid], [
                'full_name' => $name,
                'status' => 'active',
                'account_type' => $type,
                'created_at' => Dates::now(),
                'updated_at' => Dates::now(),
            ]);
        }
    }

    private function makeAuth(int $id, string $name, array $perms = []): AuthContext
    {
        $auth = new AuthContext();
        $auth->id = $id;
        $auth->fullName = $name;
        $auth->status = 'active';
        $auth->accountType = ! empty($perms['education.manage']) ? 'admin' : 'user';
        $auth->isAdmin = ! empty($perms['education.manage']);
        $auth->permissions = $perms;
        return $auth;
    }

    private function setUpSchema(): void
    {
        if (! Schema::hasTable('users')) {
            Schema::create('users', function ($table) {
                $table->id();
                $table->string('full_name');
                $table->string('status')->default('active');
                $table->string('account_type')->default('user');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_classes')) {
            Schema::create('edu_classes', function ($table) {
                $table->id();
                $table->string('name');
                $table->unsignedTinyInteger('grade')->nullable();
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_enrollments')) {
            Schema::create('edu_enrollments', function ($table) {
                $table->id();
                $table->unsignedInteger('class_id');
                $table->unsignedInteger('user_id');
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_courses')) {
            Schema::create('edu_courses', function ($table) {
                $table->id();
                $table->unsignedInteger('class_id')->nullable();
                $table->unsignedInteger('subject_id')->nullable();
                $table->string('name');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_course_enrollments')) {
            Schema::create('edu_course_enrollments', function ($table) {
                $table->id();
                $table->unsignedInteger('course_id');
                $table->unsignedInteger('user_id');
                $table->string('status')->default('enrolled');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_course_teachers')) {
            Schema::create('edu_course_teachers', function ($table) {
                $table->id();
                $table->unsignedInteger('course_id');
                $table->unsignedInteger('user_id');
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_assignments')) {
            Schema::create('edu_assignments', function ($table) {
                $table->id();
                $table->unsignedInteger('course_id')->nullable();
                $table->unsignedInteger('class_id')->nullable();
                $table->unsignedInteger('subject_id')->nullable();
                $table->unsignedTinyInteger('grade')->nullable();
                $table->unsignedInteger('teacher_id');
                $table->string('title');
                $table->string('title_en')->nullable();
                $table->text('instructions')->nullable();
                $table->text('instructions_en')->nullable();
                $table->json('attachments')->nullable();
                $table->decimal('max_score', 6, 2)->default(100.00);
                $table->dateTime('due_at')->nullable();
                $table->string('status')->default('published');
                $table->boolean('allow_late')->default(true);
                $table->boolean('allow_resubmit')->default(true);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_assignment_submissions')) {
            Schema::create('edu_assignment_submissions', function ($table) {
                $table->id();
                $table->unsignedInteger('assignment_id');
                $table->unsignedInteger('user_id');
                $table->text('text_response')->nullable();
                $table->json('attachments')->nullable();
                $table->dateTime('submitted_at')->nullable();
                $table->boolean('is_late')->default(false);
                $table->string('status')->default('submitted');
                $table->decimal('score', 6, 2)->nullable();
                $table->text('feedback')->nullable();
                $table->unsignedInteger('graded_by')->nullable();
                $table->dateTime('graded_at')->nullable();
                $table->dateTime('released_at')->nullable();
                $table->timestamps();
                $table->unique(['assignment_id', 'user_id']);
            });
        }

        if (! Schema::hasTable('edu_submissions')) {
            Schema::create('edu_submissions', function ($table) {
                $table->id();
                $table->unsignedInteger('assignment_id');
                $table->unsignedInteger('user_id');
                $table->unsignedInteger('group_id')->nullable();
                $table->text('text')->nullable();
                $table->string('file')->nullable();
                $table->string('file_name')->nullable();
                $table->boolean('is_late')->default(false);
                $table->dateTime('submitted_at')->nullable();
                $table->decimal('score', 6, 2)->nullable();
                $table->text('feedback')->nullable();
                $table->unsignedInteger('graded_by')->nullable();
                $table->dateTime('graded_at')->nullable();
            });
        }

        if (! Schema::hasTable('edu_submission_versions')) {
            Schema::create('edu_submission_versions', function ($table) {
                $table->id();
                $table->unsignedInteger('submission_id');
                $table->text('text')->nullable();
                $table->string('file')->nullable();
                $table->string('file_name')->nullable();
                $table->dateTime('submitted_at');
                $table->boolean('is_late')->default(false);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_announcements')) {
            Schema::create('edu_announcements', function ($table) {
                $table->id();
                $table->unsignedInteger('course_id')->nullable();
                $table->unsignedInteger('class_id')->nullable();
                $table->unsignedInteger('subject_id')->nullable();
                $table->unsignedTinyInteger('grade')->nullable();
                $table->unsignedInteger('teacher_id');
                $table->string('title')->nullable();
                $table->string('title_en')->nullable();
                $table->text('body');
                $table->text('body_en')->nullable();
                $table->json('attachments')->nullable();
                $table->string('status')->default('published');
                $table->dateTime('published_at')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('notifications')) {
            Schema::create('notifications', function ($table) {
                $table->id();
                $table->unsignedInteger('user_id');
                $table->string('type');
                $table->string('topic')->default('education');
                $table->string('title');
                $table->text('body');
                $table->string('entity_type')->nullable();
                $table->unsignedInteger('entity_id')->nullable();
                $table->text('data')->nullable();
                $table->unsignedInteger('broadcast_id')->nullable();
                $table->unsignedInteger('resent_from_id')->nullable();
                $table->unsignedInteger('sent_by')->nullable();
                $table->string('email_status')->default('none');
                $table->string('dedupe_key')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_categories')) {
            Schema::create('edu_categories', function ($table) {
                $table->id();
                $table->string('name');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_subjects')) {
            Schema::create('edu_subjects', function ($table) {
                $table->id();
                $table->unsignedInteger('category_id')->nullable();
                $table->string('name');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_lesson_materials')) {
            Schema::create('edu_lesson_materials', function ($table) {
                $table->id();
                $table->unsignedInteger('lesson_id')->nullable();
                $table->unsignedInteger('category_id')->nullable();
                $table->unsignedInteger('subject_id')->nullable();
                $table->unsignedTinyInteger('grade')->nullable();
                $table->string('kind');
                $table->string('title');
                $table->string('title_en')->nullable();
                $table->text('description')->nullable();
                $table->text('description_en')->nullable();
                $table->string('url')->nullable();
                $table->integer('sort_order')->default(0);
                $table->string('status')->default('published');
                $table->unsignedInteger('uploaded_by')->nullable();
                $table->timestamps();
            });
        }
    }

    public function test_assignment_submission_and_resubmission_creates_immutable_versions(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => '7ኛ', 'grade' => 7]);
        $courseId = DB::table('edu_courses')->insertGetId(['class_id' => $classId, 'name' => 'Theology 7']);
        DB::table('edu_course_teachers')->insert(['course_id' => $courseId, 'user_id' => $this->teacherAuth->id, 'status' => 'active']);
        DB::table('edu_course_enrollments')->insert(['course_id' => $courseId, 'user_id' => $this->studentAuth1->id, 'status' => 'enrolled']);

        $assignment = EduAssignments::create($this->teacherActx, [
            'course_id' => $courseId,
            'title' => 'St. Paul Epistles Analysis',
            'max_score' => 100,
            'status' => 'published',
            'allow_resubmit' => true,
        ]);
        $assignmentId = (int) $assignment['id'];

        // 1. Initial submission draft
        $sub1 = EduAssignments::submit($this->studentAuth1, $assignmentId, [
            'text_response' => 'Draft 1: Initial reflection on Romans 8.',
        ]);
        $this->assertEquals('submitted', $sub1['status']);
        $this->assertEquals('Draft 1: Initial reflection on Romans 8.', $sub1['text_response']);

        // Check versions table: 1 version must exist
        $primarySub = DB::table('edu_submissions')->where(['assignment_id' => $assignmentId, 'user_id' => $this->studentAuth1->id])->first();
        $this->assertNotNull($primarySub);
        $v1Count = DB::table('edu_submission_versions')->where('submission_id', $primarySub->id)->count();
        $this->assertEquals(1, $v1Count);

        // 2. Student resubmits revised work
        $sub2 = EduAssignments::submit($this->studentAuth1, $assignmentId, [
            'text_response' => 'Draft 2: Expanded analysis with patristic citations.',
        ]);
        $this->assertEquals('resubmitted', $sub2['status']);
        $this->assertEquals('Draft 2: Expanded analysis with patristic citations.', $sub2['text_response']);

        // Check versions table: 2 versions must exist! Prior history was NOT destroyed!
        $versions = DB::table('edu_submission_versions')->where('submission_id', $primarySub->id)->orderBy('id')->get();
        $this->assertCount(2, $versions);
        $this->assertEquals('Draft 1: Initial reflection on Romans 8.', $versions[0]->text);
        $this->assertEquals('Draft 2: Expanded analysis with patristic citations.', $versions[1]->text);

        // Serialized submission exposes versions
        $detail = EduAssignments::studentDetail($this->studentAuth1, $assignmentId);
        $this->assertNotEmpty($detail['my_submission']['versions']);
        $this->assertCount(2, $detail['my_submission']['versions']);
    }

    public function test_formative_feedback_is_visible_when_scores_are_withheld(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => '8ኛ', 'grade' => 8]);
        $courseId = DB::table('edu_courses')->insertGetId(['class_id' => $classId, 'name' => 'Church History 8']);
        DB::table('edu_course_teachers')->insert(['course_id' => $courseId, 'user_id' => $this->teacherAuth->id, 'status' => 'active']);
        DB::table('edu_course_enrollments')->insert(['course_id' => $courseId, 'user_id' => $this->studentAuth1->id, 'status' => 'enrolled']);

        $assignment = EduAssignments::create($this->teacherActx, [
            'course_id' => $courseId,
            'title' => 'Ecumenical Councils',
            'max_score' => 50,
            'status' => 'published',
        ]);
        $assignmentId = (int) $assignment['id'];

        $sub = EduAssignments::submit($this->studentAuth1, $assignmentId, [
            'text_response' => 'My council paper.',
        ]);

        // Teacher grades submission with release=false (marks withheld pending moderator approval)
        $subs = EduAssignments::listSubmissions($this->teacherAuth, $assignmentId);
        EduAssignments::gradeSubmission($this->teacherActx, (int) $subs[0]['id'], 45.0, 'Good structure, revise Section 2.', false);

        // When student views the assignment detail, numerical score is hidden (null), but feedback is VISIBLE!
        $studentDetail = EduAssignments::studentDetail($this->studentAuth1, $assignmentId);
        $this->assertNull($studentDetail['my_submission']['score'], 'Numerical score must be withheld when release is false');
        $this->assertEquals('Good structure, revise Section 2.', $studentDetail['my_submission']['feedback'], 'Formative teacher feedback must remain visible');
    }

    public function test_grade_targeted_announcements_resolve_enrolled_recipients(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => '7ኛ-A', 'grade' => 7]);
        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => $this->studentAuth1->id, 'status' => 'active']);

        // Admin posts announcement targeted to Grade 7 with no courseId or classId
        $ann = EduAnnouncements::create($this->adminActx, [
            'grade' => 7,
            'title' => 'Grade 7 Annual Retreat',
            'body' => 'Please bring hymn books on Saturday morning.',
            'status' => 'published',
        ]);

        $this->assertNotNull($ann['id']);
        // Verify notification was created for student 3
        $notif = DB::table('notifications')->where(['user_id' => $this->studentAuth1->id, 'type' => 'education'])->first();
        $this->assertNotNull($notif);
        $this->assertStringContainsString('Grade 7 Annual Retreat', $notif->title);
    }

    public function test_direct_material_link_creation(): void
    {
        $catId = DB::table('edu_categories')->insertGetId(['name' => 'Theology']);
        $res = EduLearning::addDirectMaterialLink($this->adminActx, [
            'category_id' => $catId,
            'grade' => 7,
            'title' => 'St. Yared Hymnology Lecture',
            'kind' => 'video_link',
            'url' => 'https://example.org/lecture-7',
            'status' => 'published',
        ]);

        $this->assertEquals('St. Yared Hymnology Lecture', $res['title']);
        $this->assertEquals('video_link', $res['kind']);
        $this->assertEquals('https://example.org/lecture-7', $res['url']);
        $this->assertEquals(7, $res['grade']);
    }
}

import 'dart:typed_data';

import '../core/network/api_client.dart';
import '../models/activity.dart';
import '../models/json.dart';

/// ትምህርት: classes, enrollment, attendance, assignments, results; teacher and moderator tools.
class EduRepository {
  EduRepository(this._api);
  final ApiClient _api;
  ApiClient get api => _api;

  // ---- everyone ----
  Future<Json> overview() => _api.get('/edu/overview', parse: asJson);
  Future<List<Json>> openClasses() => _api.get('/edu/classes/open', parse: asJsonList);
  Future<Json> enroll(int classId, String program) => _api.post('/edu/classes/$classId/enroll', body: {'program': program}, parse: asJson);
  Future<void> withdraw(int classId) => _api.delete<void>('/edu/classes/$classId/enroll');
  Future<Json> classDetail(int id) => _api.get('/edu/classes/$id', parse: asJson);
  Future<Json> myAttendance(int classId) => _api.get('/edu/classes/$classId/my-attendance', parse: asJson);
  Future<List<Json>> myAssignments(int classId) => _api.get('/edu/classes/$classId/my-assignments', parse: asJsonList);
  Future<Json> myResults(int classId) => _api.get('/edu/classes/$classId/my-results', parse: asJson);
  Future<Json> submit(int assignmentId, {String? text, String? filePath}) => filePath == null
      ? _api.post('/edu/assignments/$assignmentId/submit', body: {'text': text}, parse: asJson)
      : _api.upload('/edu/assignments/$assignmentId/submit', filePath: filePath, fields: {'text': ?text}, parse: asJson);
  Future<Paged<Json>> students(int classId, {String? q, int page = 1}) =>
      _api.getPage('/edu/classes/$classId/students', (j) => j, page: page, query: {'q': q});

  // ---- attendance ----
  Future<List<Json>> roster(int classId, String date) => _api.get('/edu/classes/$classId/attendance', query: {'date': date}, parse: asJsonList);
  Future<Json> mark(int classId, {required String date, required int userId, required String status}) =>
      _api.put('/edu/classes/$classId/attendance', body: {'date': date, 'user_id': userId, 'status': status}, parse: asJson);
  Future<Json> scan(int classId, {required String date, required String uuid, String status = 'present'}) =>
      _api.post('/edu/classes/$classId/attendance/scan', body: {'date': date, 'uuid': uuid, 'status': status}, parse: asJson);

  // ---- teachers ----
  Future<Json> course(int id) => _api.get('/edu/courses/$id', parse: asJson);
  Future<List<Json>> createGroup(int courseId, String name, List<int> userIds) =>
      _api.post('/edu/courses/$courseId/groups', body: {'name': name, 'user_ids': userIds}, parse: asJsonList);
  Future<List<Json>> setGroupMembers(int groupId, List<int> userIds) => _api.put('/edu/groups/$groupId/members', body: {'user_ids': userIds}, parse: asJsonList);
  Future<List<Json>> deleteGroup(int groupId) => _api.delete('/edu/groups/$groupId', parse: asJsonList);
  Future<List<Json>> assignments(int courseId) => _api.get('/edu/courses/$courseId/assignments', parse: asJsonList);
  Future<Json> createAssignment(int courseId, Json body) => _api.post('/edu/courses/$courseId/assignments', body: body, parse: asJson);
  Future<Json> updateAssignment(int id, Json body) => _api.patch('/edu/assignments/$id', body: body, parse: asJson);
  Future<void> deleteAssignment(int id) => _api.delete<void>('/edu/assignments/$id');
  Future<Json> uploadAssignmentFile(int id, String path) => _api.upload('/edu/assignments/$id/file', filePath: path, parse: asJson);
  Future<Json> submissions(int assignmentId) => _api.get('/edu/assignments/$assignmentId/submissions', parse: asJson);
  Future<Json> grade(int submissionId, {double? score, String? feedback}) =>
      _api.put('/edu/submissions/$submissionId/grade', body: {'score': score, 'feedback': feedback}, parse: asJson);
  Future<List<Json>> assessments(int courseId) => _api.get('/edu/courses/$courseId/assessments', parse: asJsonList);
  Future<Json> createAssessment(int courseId, Json body) => _api.post('/edu/courses/$courseId/assessments', body: body, parse: asJson);
  Future<void> deleteAssessment(int id) => _api.delete<void>('/edu/assessments/$id');
  Future<Json> scoreSheet(int assessmentId) => _api.get('/edu/assessments/$assessmentId/scores', parse: asJson);
  Future<Json> saveScores(int assessmentId, List<Json> scores) => _api.put('/edu/assessments/$assessmentId/scores', body: {'scores': scores}, parse: asJson);

  // ---- moderator ----
  Future<List<Json>> adminClasses({String? status, int? academicYearId}) =>
      _api.get('/edu/admin/classes', query: {'status': ?status, 'academic_year_id': ?academicYearId}, parse: asJsonList);
  Future<Json> createClass(Json body) => _api.post('/edu/admin/classes', body: body, parse: asJson);
  Future<Json> updateClass(int id, Json body) => _api.patch('/edu/admin/classes/$id', body: body, parse: asJson);
  Future<void> deleteClass(int id) => _api.delete<void>('/edu/admin/classes/$id');
  Future<Json> createCourse(int classId, Json body) => _api.post('/edu/admin/classes/$classId/courses', body: body, parse: asJson);
  Future<Json> updateCourse(int id, Json body) => _api.patch('/edu/admin/courses/$id', body: body, parse: asJson);
  Future<void> deleteCourse(int id) => _api.delete<void>('/edu/admin/courses/$id');
  Future<List<Json>> setSchedule(int classId, List<Json> items) => _api.put('/edu/admin/classes/$classId/schedule', body: {'items': items}, parse: asJsonList);
  Future<List<Json>> classSchedule(int classId) => _api.get('/edu/classes/$classId/schedule', parse: asJsonList);
  Future<List<Json>> allSchedules({int? academicYearId, int? classId}) =>
      _api.get('/edu/schedules', query: {'academic_year_id': ?academicYearId, 'class_id': ?classId}, parse: asJsonList);
  Future<List<Json>> staff(int classId) => _api.get('/edu/admin/classes/$classId/staff', parse: asJsonList);
  Future<List<Json>> addStaff(int classId, int userId) => _api.post('/edu/admin/classes/$classId/staff', body: {'user_id': userId}, parse: asJsonList);
  Future<List<Json>> removeStaff(int classId, int userId) => _api.delete('/edu/admin/classes/$classId/staff/$userId', parse: asJsonList);
  Future<void> removeStudent(int classId, int userId) => _api.delete<void>('/edu/admin/classes/$classId/students/$userId');

  // ---- academic calendar (F1) ----
  Future<List<Json>> academicYears({String? status, bool? isCurrent}) =>
      _api.get('/edu/admin/academic-years', query: {'status': ?status, if (isCurrent != null) 'is_current': isCurrent ? 1 : 0}, parse: asJsonList);
  Future<Json> academicYear(int id) => _api.get('/edu/admin/academic-years/$id', parse: asJson);
  Future<Json> createAcademicYear(Json body) => _api.post('/edu/admin/academic-years', body: body, parse: asJson);
  Future<Json> updateAcademicYear(int id, Json body) => _api.patch('/edu/admin/academic-years/$id', body: body, parse: asJson);
  Future<Json> setCurrentAcademicYear(int id) => _api.post('/edu/admin/academic-years/$id/current', body: <String, dynamic>{}, parse: asJson);
  Future<Json> closeAcademicYear(int id) => _api.post('/edu/admin/academic-years/$id/close', body: <String, dynamic>{}, parse: asJson);
  Future<void> deleteAcademicYear(int id) => _api.delete<void>('/edu/admin/academic-years/$id');

  Future<List<Json>> terms(int yearId) => _api.get('/edu/admin/academic-years/$yearId/terms', parse: asJsonList);
  Future<Json> createTerm(int yearId, Json body) => _api.post('/edu/admin/academic-years/$yearId/terms', body: body, parse: asJson);
  Future<Json> updateTerm(int id, Json body) => _api.patch('/edu/admin/terms/$id', body: body, parse: asJson);
  Future<void> deleteTerm(int id) => _api.delete<void>('/edu/admin/terms/$id');

  Future<List<Json>> levels() => _api.get('/edu/admin/levels', parse: asJsonList);
  Future<Json> createLevel(Json body) => _api.post('/edu/admin/levels', body: body, parse: asJson);
  Future<Json> updateLevel(int id, Json body) => _api.patch('/edu/admin/levels/$id', body: body, parse: asJson);
  Future<void> deleteLevel(int id) => _api.delete<void>('/edu/admin/levels/$id');

  // ---- class assignment & exclusivity (F2) ----
  Future<Paged<Json>> assignableStudents(int classId, {String? q, String? group, int page = 1}) =>
      _api.getPage('/edu/admin/classes/$classId/assignable', (j) => j, page: page, query: {'q': q, 'group': group});
  Future<Json> assignStudents(int classId, List<int> userIds, {String program = 'regular'}) =>
      _api.post('/edu/admin/classes/$classId/assign', body: {'user_ids': userIds, 'program': program}, parse: asJson);
  Future<Json> transferEnrollment(int enrollmentId, int targetClassId, String reason) =>
      _api.post('/edu/admin/enrollments/$enrollmentId/transfer', body: {'target_class_id': targetClassId, 'reason': reason}, parse: asJson);
  Future<Json> promoteEnrollment(int enrollmentId, int targetClassId, String reason) =>
      _api.post('/edu/admin/enrollments/$enrollmentId/promote', body: {'target_class_id': targetClassId, 'reason': reason}, parse: asJson);

  // ---- teachers: marks for review ----
  Future<List<Json>> teaching() => _api.get('/edu/teaching', parse: asJsonList);
  Future<Json> submitMarks(int assessmentId) => _api.post('/edu/assessments/$assessmentId/submit', body: <String, dynamic>{}, parse: asJson);

  // ---- students: requests, complaints, journey ----
  Future<Paged<Json>> journey({int page = 1}) => _api.getPage('/edu/me/journey', (j) => j, page: page);
  Future<List<Json>> myRequests() => _api.get('/edu/me/requests', parse: asJsonList);
  Future<Json> createRequest(Json body) => _api.post('/edu/me/requests', body: body, parse: asJson);
  Future<Json> cancelRequest(int id) => _api.delete('/edu/me/requests/$id', parse: asJson);
  Future<List<Json>> myComplaints() => _api.get('/edu/me/complaints', parse: asJsonList);
  Future<Json> createComplaint(Json fields, {String? filePath}) => filePath == null
      ? _api.post('/edu/me/complaints', body: fields, parse: asJson)
      : _api.upload('/edu/me/complaints', filePath: filePath, fields: {for (final e in fields.entries) e.key: '${e.value}'}, parse: asJson);
  Future<Json> myComplaint(int id) => _api.get('/edu/me/complaints/$id', parse: asJson);
  Future<Json> complaintMessage(int id, String body) => _api.post('/edu/me/complaints/$id/messages', body: {'body': body}, parse: asJson);

  // ---- education administrators ----
  Future<List<Json>> courseTeachers(int courseId) => _api.get('/edu/admin/courses/$courseId/teachers', parse: asJsonList);
  Future<List<Json>> assignTeacher(int courseId, int userId, {String? note}) =>
      _api.post('/edu/admin/courses/$courseId/teachers', body: {'user_id': userId, 'note': ?note}, parse: asJsonList);
  Future<List<Json>> setTeacherStatus(int assignmentId, String status, {String? note}) =>
      _api.patch('/edu/admin/course-teachers/$assignmentId', body: {'status': status, 'note': ?note}, parse: asJsonList);
  Future<Paged<Json>> marksQueue({String status = 'submitted', int page = 1}) => _api.getPage('/edu/admin/marks', (j) => j, page: page, query: {'status': status});
  Future<Json> reviewMarks(int assessmentId, {required bool approve, String? note, bool publish = false}) =>
      _api.post('/edu/admin/assessments/$assessmentId/review', body: {'decision': approve ? 'approve' : 'reject', 'note': ?note, if (publish) 'publish': true}, parse: asJson);
  Future<Json> publishMarks(int assessmentId) => _api.post('/edu/admin/assessments/$assessmentId/publish', body: <String, dynamic>{}, parse: asJson);
  Future<Json> amendMark(int assessmentId, int userId, double? score, String reason) =>
      _api.post('/edu/admin/assessments/$assessmentId/amend', body: {'user_id': userId, 'score': score, 'reason': reason}, parse: asJson);
  Future<List<Json>> markHistory(int assessmentId) => _api.get('/edu/admin/assessments/$assessmentId/history', parse: asJsonList);
  Future<Paged<Json>> adminRequests({String? status, int page = 1}) => _api.getPage('/edu/admin/requests', (j) => j, page: page, query: {'status': status});
  Future<Json> reviewRequest(int id, {required bool approve, String? note}) =>
      _api.post('/edu/admin/requests/$id/review', body: {'decision': approve ? 'approve' : 'reject', 'note': ?note}, parse: asJson);
  Future<Paged<Json>> adminComplaints({String? status, int page = 1}) => _api.getPage('/edu/admin/complaints', (j) => j, page: page, query: {'status': status});
  Future<Json> adminComplaint(int id) => _api.get('/edu/admin/complaints/$id', parse: asJson);
  Future<Json> complaintAction(int id, Json body) => _api.post('/edu/admin/complaints/$id/actions', body: body, parse: asJson);
  Future<Paged<Json>> studentJourney(int userId, {int page = 1}) => _api.getPage('/edu/admin/students/$userId/journey', (j) => j, page: page);

  // ---- learning platform: home, catalog, lessons, progress ----
  Future<Json> dashboard() => _api.get('/edu/me/dashboard', parse: asJson);
  Future<Json> progress() => _api.get('/edu/me/progress', parse: asJson);
  Future<List<Json>> bookmarks() => _api.get('/edu/me/bookmarks', parse: asJsonList);
  Future<Json> search(String q) => _api.get('/edu/search', query: {'q': q}, parse: asJson);
  Future<List<Json>> categories({bool all = false}) => _api.get('/edu/categories', query: {if (all) 'all': 1}, parse: asJsonList);
  Future<List<Json>> categorySubjects(int categoryId, {bool all = false}) => _api.get('/edu/categories/$categoryId/subjects', query: {if (all) 'all': 1}, parse: asJsonList);
  Future<List<Json>> subjects({bool all = false}) => _api.get('/edu/subjects', query: {if (all) 'all': 1}, parse: asJsonList);
  Future<List<Json>> authoringSubjects() => _api.get('/edu/subjects/authoring', parse: asJsonList);
  Future<Json> subject(int id) => _api.get('/edu/subjects/$id', parse: asJson);
  Future<Json> subjectGrades(int subjectId) => _api.get('/edu/subjects/$subjectId/grades', parse: asJson);
  Future<Json> subjectGradeContent(int subjectId, int grade) => _api.get('/edu/subjects/$subjectId/grades/$grade', parse: asJson);
  Future<Json> lesson(int id) => _api.get('/edu/lessons/$id', parse: asJson);
  Future<Json> lessonProgress(int id, String action) => _api.post('/edu/lessons/$id/progress', body: {'action': action}, parse: asJson);
  Future<Uint8List> materialBytes(int id, {void Function(int, int)? onProgress}) => _api.downloadBytes('/edu/materials/$id/file', onProgress: onProgress);
  Future<List<Json>> featured({bool all = false}) => _api.get('/edu/featured', query: {if (all) 'all': 1}, parse: asJsonList);

  // ---- authoring (content editors, or the subject's active teachers) ----
  Future<Json> unit(int id) => _api.get('/edu/units/$id', parse: asJson);
  Future<Json> createUnit(int subjectId, Json body) => _api.post('/edu/subjects/$subjectId/units', body: body, parse: asJson);
  Future<Json> updateUnit(int id, Json body) => _api.patch('/edu/units/$id', body: body, parse: asJson);
  Future<Json> deleteUnit(int id) => _api.delete('/edu/units/$id', parse: asJson);
  Future<Json> reorderUnits(int subjectId, List<int> ids) => _api.put('/edu/subjects/$subjectId/units/order', body: {'ids': ids}, parse: asJson);
  Future<Json> createLesson(int subjectId, Json body) => _api.post('/edu/subjects/$subjectId/lessons', body: body, parse: asJson);
  Future<Json> updateLesson(int id, Json body) => _api.patch('/edu/lessons/$id', body: body, parse: asJson);
  Future<void> deleteLesson(int id) => _api.delete<void>('/edu/lessons/$id');
  Future<Json> reorderLessons(int subjectId, List<int> ids) => _api.put('/edu/subjects/$subjectId/lessons/order', body: {'ids': ids}, parse: asJson);
  Future<Json> uploadMaterial(int lessonId, String path, {String? title, void Function(double)? onProgress}) =>
      _api.upload('/edu/lessons/$lessonId/materials', filePath: path, fields: {'title': ?title}, onProgress: onProgress, parse: asJson);
  Future<Json> addLink(int lessonId, {required String kind, required String title, required String url}) =>
      _api.post('/edu/lessons/$lessonId/links', body: {'kind': kind, 'title': title, 'url': url}, parse: asJson);
  Future<Json> updateMaterial(int id, Json body) => _api.patch('/edu/materials/$id', body: body, parse: asJson);
  Future<void> deleteMaterial(int id) => _api.delete<void>('/edu/materials/$id');

  // ---- content editors: categories, subjects, featured ----
  Future<Json> createCategory(Json body) => _api.post('/edu/content/categories', body: body, parse: asJson);
  Future<Json> updateCategory(int id, Json body) => _api.patch('/edu/content/categories/$id', body: body, parse: asJson);
  Future<List<Json>> reorderCategories(List<int> ids) => _api.put('/edu/content/categories/order', body: {'ids': ids}, parse: asJsonList);
  Future<Json> setCategoryImage(int id, String path) => _api.upload('/edu/content/categories/$id/image', filePath: path, parse: asJson);
  Future<Json> removeCategoryImage(int id) => _api.delete('/edu/content/categories/$id/image', parse: asJson);
  Future<void> deleteCategory(int id) => _api.delete<void>('/edu/content/categories/$id');
  Future<Json> createSubject(Json body) => _api.post('/edu/content/subjects', body: body, parse: asJson);
  Future<Json> updateSubject(int id, Json body) => _api.patch('/edu/content/subjects/$id', body: body, parse: asJson);
  Future<Json> setSubjectCover(int id, String path) => _api.upload('/edu/content/subjects/$id/cover', filePath: path, parse: asJson);
  Future<Json> removeSubjectCover(int id) => _api.delete('/edu/content/subjects/$id/cover', parse: asJson);
  Future<void> deleteSubject(int id) => _api.delete<void>('/edu/content/subjects/$id');
  Future<List<Json>> createFeatured(Json body) => _api.post('/edu/content/featured', body: body, parse: asJsonList);
  Future<List<Json>> updateFeatured(int id, Json body) => _api.patch('/edu/content/featured/$id', body: body, parse: asJsonList);
  Future<List<Json>> setFeaturedImage(int id, String path) => _api.upload('/edu/content/featured/$id/image', filePath: path, parse: asJsonList);
  Future<List<Json>> deleteFeatured(int id) => _api.delete('/edu/content/featured/$id', parse: asJsonList);

  // ---- quizzes: students ----
  Future<List<Json>> myQuizzes({int? courseId}) => _api.get('/edu/me/quizzes', query: {'course_id': courseId}, parse: asJsonList);
  Future<Json> quiz(int id) => _api.get('/edu/quizzes/$id', parse: asJson);
  Future<Json> startQuiz(int quizId) => _api.post('/edu/quizzes/$quizId/attempts', parse: asJson);
  Future<Json> attempt(int id) => _api.get('/edu/attempts/$id', parse: asJson);
  Future<Json> saveAnswers(int attemptId, List<Json> answers) => _api.put('/edu/attempts/$attemptId/answers', body: {'answers': answers}, parse: asJson);
  Future<Json> checkAnswer(int attemptId, int questionId, Object? response) =>
      _api.post('/edu/attempts/$attemptId/check', body: {'question_id': questionId, 'response': response}, parse: asJson);
  Future<Json> submitAttempt(int attemptId, List<Json> answers) => _api.post('/edu/attempts/$attemptId/submit', body: {'answers': answers}, parse: asJson);

  // ---- quizzes: teachers ----
  Future<List<Json>> courseQuizzes(int courseId) => _api.get('/edu/courses/$courseId/quizzes', parse: asJsonList);
  Future<Json> createQuiz(int courseId, Json body) => _api.post('/edu/courses/$courseId/quizzes', body: body, parse: asJson);
  Future<List<Json>> subjectQuizzes(int subjectId) => _api.get('/edu/subjects/$subjectId/quizzes', parse: asJsonList);
  Future<Json> createSubjectQuiz(int subjectId, Json body) => _api.post('/edu/subjects/$subjectId/quizzes', body: body, parse: asJson);
  Future<Json> teacherQuiz(int id) => _api.get('/edu/quizzes/$id', parse: asJson);
  Future<Json> updateQuiz(int id, Json body) => _api.patch('/edu/quizzes/$id', body: body, parse: asJson);
  Future<void> deleteQuiz(int id) => _api.delete<void>('/edu/quizzes/$id');
  Future<Json> setQuestions(int id, List<Json> questions) => _api.put('/edu/quizzes/$id/questions', body: {'questions': questions}, parse: asJson);
  Future<Json> quizResults(int id) => _api.get('/edu/quizzes/$id/results', parse: asJson);
  Future<Json> teacherAttempt(int id) => _api.get('/edu/quiz-attempts/$id', parse: asJson);
  Future<Json> gradeAnswer(int attemptId, int questionId, double points, {String? feedback}) =>
      _api.put('/edu/quiz-attempts/$attemptId/grade', body: {'question_id': questionId, 'points': points, 'feedback': ?feedback}, parse: asJson);
  Future<Json> transferQuiz(int id) => _api.post('/edu/quizzes/$id/transfer', parse: asJson);

  // ---- Magazines (ሰሌዳ መጽሔት) ----
  Future<List<Json>> magazines({int? year, String? status}) =>
      _api.get('/edu/magazines', query: {'year': ?year, 'status': ?status}, parse: asJsonList);
  Future<Json?> latestMagazine() =>
      _api.get('/edu/magazines/latest', parse: (v) => v == null ? null : asJson(v));
  Future<Json> magazineDetail(int id) =>
      _api.get('/edu/magazines/$id', parse: asJson);
  Future<Json> createMagazine(Json body) =>
      _api.post('/edu/magazines', body: body, parse: asJson);
  Future<Json> updateMagazine(int id, Json body) =>
      _api.put('/edu/magazines/$id', body: body, parse: asJson);
  Future<void> deleteMagazine(int id) =>
      _api.delete<void>('/edu/magazines/$id');
  Future<List<Json>> magazineQuizzes(int magazineId) =>
      _api.get('/edu/magazines/$magazineId/quizzes', parse: asJsonList);
  Future<Json> createMagazineQuiz(int magazineId, Json body) =>
      _api.post('/edu/magazines/$magazineId/quizzes', body: body, parse: asJson);

  // ---- F8: online course completion ----
  Future<Json> courseCompletion(int courseId, {int? userId}) => _api.get('/edu/courses/$courseId/completion', query: {'user_id': ?userId}, parse: asJson);

  // ---- F9: submission versions ----
  Future<List<Json>> submissionVersions(int submissionId) => _api.get('/edu/submissions/$submissionId/versions', parse: asJsonList);

  // ---- F10: course outcomes ----
  Future<List<Json>> myOutcomes() => _api.get('/edu/my-outcomes', parse: asJsonList);
  Future<List<Json>> courseOutcomes(int courseId) => _api.get('/edu/courses/$courseId/outcomes', parse: asJsonList);
  Future<List<Json>> computeCourseOutcomes(int courseId) => _api.post('/edu/courses/$courseId/outcomes/compute', body: <String, dynamic>{}, parse: asJsonList);
  Future<Json> finalizeCourseOutcomes(int courseId, {List<int>? userIds}) => _api.post('/edu/courses/$courseId/outcomes/finalize', body: {'ids': ?userIds}, parse: asJson);
  Future<Json> setCountingOutcome(int outcomeId, [String reason = 'Admin resolution']) => _api.post('/edu/outcomes/$outcomeId/counting', body: {'reason': reason}, parse: asJson);

  // ---- F11: retakes ----
  Future<Json> requestRetake(int outcomeId) => _api.post('/edu/outcomes/$outcomeId/retake', body: <String, dynamic>{}, parse: asJson);
  Future<List<Json>> retakes({int? courseId, int? userId, String? status}) =>
      _api.get('/edu/retakes', query: {'course_id': ?courseId, 'user_id': ?userId, 'status': ?status}, parse: asJsonList);
  Future<Json> decideRetake(int retakeId, String decision, {String? note}) =>
      _api.post('/edu/retakes/$retakeId/decide', body: {'decision': decision, 'note': ?note}, parse: asJson);

  // ---- F12: question banks & draws ----
  Future<List<Json>> questionBanks(int subjectId) => _api.get('/edu/subjects/$subjectId/question-banks', parse: asJsonList);
  Future<Json> createQuestionBank(int subjectId, Json body) => _api.post('/edu/subjects/$subjectId/question-banks', body: body, parse: asJson);
  Future<Json> questionBank(int id) => _api.get('/edu/question-banks/$id', parse: asJson);
  Future<Json> setQuestionBankQuestions(int id, List<Json> questions) => _api.put('/edu/question-banks/$id/questions', body: {'questions': questions}, parse: asJson);
  Future<List<Json>> quizDraws(int quizId) => _api.get('/edu/quizzes/$quizId/draws', parse: asJsonList);
  Future<List<Json>> setQuizDraws(int quizId, List<Json> draws) => _api.put('/edu/quizzes/$quizId/draws', body: {'draws': draws}, parse: asJsonList);

  // ---- F13: certificates ----
  Future<List<Json>> myCertificates() => _api.get('/edu/my-certificates', parse: asJsonList);
  Future<List<Json>> courseEligibleCertificates(int courseId, {int? userId}) =>
      _api.get('/edu/courses/$courseId/certificates/eligible', query: {'user_id': ?userId}, parse: asJsonList);
  Future<List<Json>> issueCertificates(int courseId, List<int> userIds) =>
      _api.post('/edu/courses/$courseId/certificates/issue', body: {'user_ids': userIds}, parse: asJsonList);
  Future<List<Json>> certificates({int? courseId, int? userId, String? status}) =>
      _api.get('/edu/certificates', query: {'course_id': ?courseId, 'user_id': ?userId, 'status': ?status}, parse: asJsonList);
  Future<Json> revokeCertificate(int certId, String reason) =>
      _api.post('/edu/certificates/$certId/revoke', body: {'reason': reason}, parse: asJson);
  Future<Json> reissueCertificate(int certId, String reason) =>
      _api.post('/edu/certificates/$certId/reissue', body: {'reason': reason}, parse: asJson);
  Future<Uint8List> certificatePdf(int certId, {void Function(int, int)? onProgress}) =>
      _api.downloadBytes('/edu/certificates/$certId/pdf', onProgress: onProgress);

  // ---- F15: admin scores & activity ----
  Future<Json> adminScores({int? yearId, int? termId, int? classId, int? courseId, String? group}) =>
      _api.get('/edu/admin/scores', query: {
        'year_id': ?yearId,
        'term_id': ?termId,
        'class_id': ?classId,
        'course_id': ?courseId,
        'group': ?group,
      }, parse: (res) {
        if (res is List) return {'scores': res};
        if (res is Map<String, dynamic>) {
          if (res.containsKey('scores')) return res;
          if (res['data'] is List) return {'scores': res['data']};
          return res;
        }
        return {'scores': <Json>[]};
      });
  Future<Json> adminActivity({int? yearId, int? termId, int? classId}) =>
      _api.get('/edu/admin/activity', query: {
        'year_id': ?yearId,
        'term_id': ?termId,
        'class_id': ?classId,
      }, parse: (res) {
        if (res is List) return {'activity': res};
        if (res is Map<String, dynamic>) {
          if (res.containsKey('activity')) return res;
          if (res['data'] is List) return {'activity': res['data']};
          return res;
        }
        return {'activity': <Json>[]};
      });
  Future<Json> myScores() => _api.get('/edu/me/scores', parse: asJson);
  Future<Json> studentScores(int studentId) => _api.get('/edu/students/$studentId/scores', parse: asJson);

  // ---- Feature B: Direct Course Materials ----
  Future<List<Json>> directMaterials(int categoryId, int grade) =>
      _api.get('/edu/categories/$categoryId/grades/$grade/materials', parse: asJsonList);
  Future<Json> addDirectMaterialFile(int categoryId, int grade, String path, {String? title, void Function(double)? onProgress}) =>
      _api.upload('/edu/categories/$categoryId/grades/$grade/materials', filePath: path, fields: {'title': ?title}, onProgress: onProgress, parse: asJson);
  Future<Json> addDirectMaterialLink(int categoryId, int grade, {required String kind, required String title, required String url}) =>
      _api.post('/edu/categories/$categoryId/grades/$grade/materials/link', body: {'kind': kind, 'title': title, 'url': url}, parse: asJson);

  // ---- Feature C: Canonical Admin Grades CRUD ----
  Future<List<Json>> adminGrades() => _api.get('/edu/admin/grades', parse: asJsonList);
  Future<Json> adminGradeDetail(int id) => _api.get('/edu/admin/grades/$id', parse: asJson);
  Future<Json> updateGradeLevel(int id, Json body) => _api.patch('/edu/levels/$id', body: body, parse: asJson);

  // ---- Feature D: Classroom Assignments ----
  Future<List<Json>> classroomAssignments({int? courseId}) =>
      _api.get('/edu/me/assignments', query: {'course_id': ?courseId}, parse: asJsonList);
  Future<Json> classroomAssignmentDetail(int id) =>
      _api.get('/edu/me/assignments/$id', parse: asJson);
  Future<Json> submitClassroomAssignment(int id, {String? text, String? filePath}) => filePath == null
      ? _api.post('/edu/me/assignments/$id/submit', body: {'text_response': ?text}, parse: asJson)
      : _api.upload('/edu/me/assignments/$id/submit', filePath: filePath, fields: {'text_response': ?text}, parse: asJson);
  Future<List<Json>> teacherClassroomAssignments({int? courseId}) =>
      _api.get('/edu/teacher/assignments', query: {'course_id': ?courseId}, parse: asJsonList);
  Future<List<Json>> classroomSubmissions(int id) =>
      _api.get('/edu/teacher/assignments/$id/submissions', parse: asJsonList);
  Future<Json> gradeClassroomSubmission(int id, {required double score, String? feedback, bool release = true}) =>
      _api.post('/edu/teacher/submissions/$id/grade', body: {'score': score, 'feedback': ?feedback, 'release': release}, parse: asJson);
  Future<Json> releaseClassroomGrades(int id) =>
      _api.post('/edu/teacher/assignments/$id/release-grades', body: <String, dynamic>{}, parse: asJson);
  Future<Json> createClassroomAssignment(Json body) =>
      _api.post('/edu/teacher/assignments', body: body, parse: asJson);
  Future<Json> updateClassroomAssignment(int id, Json body) =>
      _api.patch('/edu/teacher/assignments/$id', body: body, parse: asJson);
  Future<void> deleteClassroomAssignment(int id) =>
      _api.delete<void>('/edu/teacher/assignments/$id');

  // ---- Feature E: Teacher Announcements ----
  Future<List<Json>> announcementsFeed({int? courseId, int? classId}) =>
      _api.get('/edu/me/announcements', query: {'course_id': ?courseId, 'class_id': ?classId}, parse: asJsonList);
  Future<Json> announcementDetail(int id) =>
      _api.get('/edu/me/announcements/$id', parse: asJson);
  Future<List<Json>> teacherAnnouncements({int? courseId}) =>
      _api.get('/edu/teacher/announcements', query: {'course_id': ?courseId}, parse: asJsonList);
  Future<Json> postAnnouncement(Json body) =>
      _api.post('/edu/teacher/announcements', body: body, parse: asJson);
  Future<Json> updateAnnouncement(int id, Json body) =>
      _api.patch('/edu/teacher/announcements/$id', body: body, parse: asJson);
  Future<void> deleteAnnouncement(int id) =>
      _api.delete<void>('/edu/teacher/announcements/$id');
}

/// ስለ እኔ + departments, HR, payments and QR lookups.
class OrgRepository {
  OrgRepository(this._api);
  final ApiClient _api;

  Future<Json> myCard() => _api.get('/me/card', parse: asJson);
  Future<Json> myPayments() => _api.get('/me/payments', parse: asJson);
  Future<Json> submitReceipt({required int months, String? period, double? amount, String? note, required String filePath, void Function(double)? onProgress}) =>
      _api.upload('/me/payments/receipt', filePath: filePath, fields: {
        'months': months.toString(),
        'period': ?period,
        if (amount != null) 'amount': amount.toString(),
        'note': ?note,
      }, onProgress: onProgress, parse: asJson);
  Future<List<Json>> myReceipts() => _api.get('/me/payments/receipts', parse: asJsonList);
  Future<Paged<Json>> receiptList({String? status, int page = 1}) =>
      _api.getPage('/payments/receipts', (j) => j, page: page, query: {if (status != null && status != 'all') 'status': status});
  Future<Json> approveReceipt(int id) => _api.post('/payments/receipts/$id/approve', parse: asJson);
  Future<Json> rejectReceipt(int id, String reason) => _api.post('/payments/receipts/$id/reject', body: {'reason': reason}, parse: asJson);
  Future<Json> member(String uuid) => _api.get('/members/$uuid', parse: asJson);

// ---- the 7 departments ----
  Future<List<Json>> departments() => _api.get('/departments', parse: asJsonList);
  Future<Json> updateDepartment(int id, Json body) => _api.patch('/departments/$id', body: body, parse: asJson);
  Future<Paged<Json>> departmentMembers(int id, {String? q, int page = 1}) => _api.getPage('/departments/$id/members', (j) => j, page: page, query: {'q': q});

  /// Add members (multi-select) and/or set the one leader.
  Future<Json> addMembers(int departmentId, {List<int> memberIds = const [], int? leaderId}) =>
      _api.post('/departments/$departmentId/members', body: {'member_ids': memberIds, 'leader_id': ?leaderId}, parse: asJson);
  Future<Json> setRole(int departmentId, int userId, String role) => _api.patch('/departments/$departmentId/members/$userId', body: {'role': role}, parse: asJson);
  Future<void> unassign(int departmentId, int userId) => _api.delete<void>('/departments/$departmentId/members/$userId');

  // ---- department leaders: monthly participation ----
  Future<List<Json>> ledDepartments() => _api.get('/departments/led', parse: asJsonList);
  Future<Json> participationSheet(int departmentId, String period) => _api.get('/departments/$departmentId/participation', query: {'period': period}, parse: asJson);
  Future<Json> saveParticipation(int departmentId, String period, List<Json> entries) =>
      _api.put('/departments/$departmentId/participation', body: {'period': period, 'entries': entries}, parse: asJson);

  Future<Json> paymentPolicy() => _api.get('/payments/policy', parse: asJson);
  Future<Json> savePaymentPolicy(Json body) => _api.put('/payments/policy', body: body, parse: asJson);
  Future<Paged<Json>> payments({required String period, String? status, String? q, String? memberType, int page = 1}) =>
      _api.getPage('/payments', (j) => j, page: page, query: {'period': period, 'status': status, 'q': q, 'member_type': memberType});
  Future<List<Json>> paymentRates() => _api.get('/payments/rates', parse: asJsonList);
  Future<void> addPaymentRate(Json body) => _api.post<void>('/payments/rates', body: body);
  Future<void> updatePaymentRate(int id, Json body) => _api.patch<void>('/payments/rates/$id', body: body);
  Future<void> deletePaymentRate(int id) => _api.delete<void>('/payments/rates/$id');
  Future<Json> verifyPayment(int id) => _api.post('/payments/$id/verify', parse: asJson);
  Future<Json> recordPayment(Json body) => _api.post('/payments', body: body, parse: asJson);
  Future<void> deletePayment(int id) => _api.delete<void>('/payments/$id');
  Future<Json> uploadReceipt(int id, String path) => _api.upload('/payments/$id/receipt', filePath: path, parse: asJson);
  Future<Json> memberPayments(int userId) => _api.get('/payments/member/$userId', parse: asJson);

  // ---- Monthly Contribution Receipts ----
  Future<Json> calculateContributionReceipt({required String period, required int months}) =>
      _api.get('/me/contribution-receipts/calculate', query: {'period': period, 'months': '$months'}, parse: asJson);

  Future<Json> submitContributionReceipt({
    required String filePath,
    required String period,
    required int months,
    required double submittedAmount,
    required String method,
    required String paidOn,
    String? reference,
    String? note,
  }) =>
      _api.upload(
        '/me/contribution-receipts',
        filePath: filePath,
        fields: {
          'period': period,
          'months': '$months',
          'submitted_amount': '$submittedAmount',
          'method': method,
          'paid_on': paidOn,
          if (reference != null && reference.isNotEmpty) 'reference': reference,
          if (note != null && note.isNotEmpty) 'member_note': note,
        },
        parse: asJson,
      );

  Future<List<Json>> myContributionReceipts() => _api.get('/me/contribution-receipts', parse: asJsonList);

  Future<Paged<Json>> adminContributionReceipts({String? status, String? period, String? q, int page = 1}) =>
      _api.getPage('/org/contribution-receipts', (j) => j, page: page, query: {'status': status, 'period': period, 'q': q});

  Future<Json> reviewContributionReceipt(int id, {required String status, String? note}) =>
      _api.post('/org/contribution-receipts/$id/review', body: {'status': status, if (note != null) 'review_note': note}, parse: asJson);

}

/// Choir (መዘምራን): my result in the current holiday selection (selections themselves: StageRepository).
class ChoirRepository {
  ChoirRepository(this._api);
  final ApiClient _api;

  Future<Json> me() => _api.get('/choir/me', parse: asJson);
  /// Class sessions attended, as a calendar (Education category).
  Future<AttendanceCalendar> educationCalendar({required String from, required String to}) =>
      _api.get('/choir/me/education-calendar', query: {'from': from, 'to': to}, parse: (d) => AttendanceCalendar.fromJson(asJson(d)));
}

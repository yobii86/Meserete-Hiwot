<?php

namespace App\Mz\Notifications;

use App\Mz\Db\Locks;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/** In-app notifications + push delivery (port of notificationService.js). */
final class Notifications
{
    private const INSERT_CHUNK = 1000;

    /** Topics the member can switch on / off (push and email; the in-app record is always kept). */
    public const TOPICS = ['program', 'attendance', 'project', 'department', 'education', 'property', 'payment', 'mezmur', 'system', 'sinksar'];
    public const CHANNELS = ['push', 'email'];

    private const TOPIC_OF = [
        'program' => 'program', 'program_reminder' => 'program',
        'attendance' => 'attendance',
        'project' => 'project', 'task' => 'project',
        'chat' => 'department', 'department' => 'department',
        'education' => 'education', 'edu_quiz' => 'education', 'edu_grading' => 'education', 'edu_assignment' => 'education', 'edu_announcement' => 'education',
        'borrowing' => 'property', 'borrowing_due' => 'property', 'borrowing_overdue' => 'property', 'property' => 'property',
        'payment' => 'payment', 'finance' => 'payment',
        'mezmur' => 'mezmur', 'choir' => 'mezmur',
        'sinksar' => 'sinksar', 'holy_day' => 'sinksar',
    ];

    /**
     * Always delivered (cannot be switched off by the member): mandatory categories required by policy.
     */
    public const MANDATORY = [
        'system',
        'admin_message',
        'announcement',
        'borrowing_due',
        'borrowing_overdue',
        'borrowing',
        'property',
        'program',
        'program_reminder',
        'attendance',
        'project',
        'task',
        'education',
        'edu_quiz',
        'edu_grading',
        'edu_assignment',
        'edu_announcement',
        'payment',
        'finance',
    ];

    public const MANDATORY_TOPICS = [
        'system',
        'program',
        'attendance',
        'project',
        'property',
        'education',
        'payment',
    ];

    /** Android notification channels (created by the app). */
    private const CHANNEL = [
        'program_reminder' => 'reminders',
        'program' => 'programs',
        'borrowing' => 'borrowing',
        'borrowing_due' => 'borrowing',
        'borrowing_overdue' => 'borrowing',
        'chat' => 'chat',
    ];

    /** Emails sent per dispatcher run (the rest wait for the next run; keeps a request short). */
    private const EMAIL_BATCH = 40;

    private static bool $kicked = false;

    public static function topicOf(string $type): string
    {
        return self::TOPIC_OF[$type] ?? 'system';
    }

    public static function isMandatory(string $type): bool
    {
        $topic = self::topicOf($type);
        return in_array($type, self::MANDATORY, true) || in_array($topic, self::MANDATORY_TOPICS, true);
    }

    /**
     * Bulk-create notifications (INSERT IGNORE on dedupe_key). Push / email delivery happens after
     * the response. A failure here is logged and never cancels the action that caused it.
     * $n = [type, title, body, entityType?, entityId?, data?, broadcastId?, dedupeKey?: fn(int $uid): string,
     *       email?: bool (also send it by email), resentFromId?, sentBy?]
     */
    public static function createForUsers(array $userIds, array $n): int
    {
        $inserted = 0;
        $unique = array_values(array_unique(array_filter(array_map('intval', $userIds), fn ($id) => $id > 0)));
        $topic = self::topicOf($n['type']);
        try {
            foreach (array_chunk($unique, self::INSERT_CHUNK) as $chunk) {
                $rows = array_map(fn ($uid) => [
                    'user_id' => $uid,
                    'type' => $n['type'],
                    'topic' => $topic,
                    'title' => mb_substr((string) $n['title'], 0, 255),
                    'body' => mb_substr((string) $n['body'], 0, 2000),
                    'entity_type' => $n['entityType'] ?? null,
                    'entity_id' => $n['entityId'] ?? null,
                    'data' => isset($n['data']) ? json_encode($n['data'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) : null,
                    'broadcast_id' => $n['broadcastId'] ?? null,
                    'resent_from_id' => $n['resentFromId'] ?? null,
                    'sent_by' => $n['sentBy'] ?? null,
                    'email_status' => ! empty($n['email']) ? 'pending' : 'none',
                    'dedupe_key' => isset($n['dedupeKey']) ? mb_substr(($n['dedupeKey'])($uid), 0, 150) : null,
                ], $chunk);
                $inserted += DB::table('notifications')->insertOrIgnore($rows);
            }
        } catch (\Throwable $e) {
            Log::error('notification insert failed', ['type' => $n['type'] ?? null, 'error' => $e->getMessage()]);
        }
        if ($inserted) self::kick();
        return $inserted;
    }

    public static function notifyUser(int $userId, array $n): int
    {
        return self::createForUsers([$userId], $n);
    }

    /**
     * Broadcast a notification to all active members and administrators.
     */
    public static function sendToAll(array $n): int
    {
        try {
            $query = DB::table('users');
            if (class_exists(\App\Mz\Auth\MemberIds::class)) {
                $query = \App\Mz\Auth\MemberIds::membersAndAdmins($query);
            }
            $userIds = $query->where('status', 'active')
                ->whereNull('deleted_at')
                ->pluck('id')
                ->all();

            if (empty($userIds)) {
                return 0;
            }

            return self::createForUsers($userIds, $n);
        } catch (\Throwable $e) {
            Log::error('Notifications::sendToAll failed', ['error' => $e->getMessage()]);
            return 0;
        }
    }

    /** Deliver pending pushes / emails after the response has been sent (never blocks the request). */
    public static function kick(): void
    {
        if (self::$kicked) {
            return;
        }
        self::$kicked = true;
        app()->terminating(function () {
            self::$kicked = false;
            try {
                self::dispatchPending();
            } catch (\Throwable $e) {
                Log::error('notification dispatch failed', ['error' => $e->getMessage()]);
            }
        });
    }

    // ------------------------------------------------------------------ preferences
    /** topic => [push => bool, email => bool] for one member (defaults: everything on). */
    public static function preferencesOf(?string $json): array
    {
        $saved = $json ? (json_decode($json, true) ?: []) : [];
        $out = [];
        foreach (self::TOPICS as $t) {
            foreach (self::CHANNELS as $c) $out[$t][$c] = (bool) ($saved[$t][$c] ?? true);
        }
        return $out;
    }

    /** May this notification go out on this channel for this member? */
    public static function allowed(string $type, ?string $topic, string $channel, ?object $prefsRow): bool
    {
        if (self::isMandatory($type)) return true;
        if ($prefsRow && $prefsRow->notifications_enabled !== null && (int) $prefsRow->notifications_enabled === 0) return false;
        $topic = $topic ?: self::topicOf($type);
        return self::preferencesOf($prefsRow->notification_topics ?? null)[$topic][$channel] ?? true;
    }

    /** Of these members, the ones who receive pushes of a type (chat sends its pushes itself). */
    public static function pushRecipients(array $userIds, string $type): array
    {
        if (! $userIds) return [];
        $prefs = DB::table('user_preferences')->whereIn('user_id', $userIds)->get(['user_id', 'notifications_enabled', 'notification_topics'])->keyBy('user_id');
        return array_values(array_filter($userIds, fn ($id) => self::allowed($type, null, 'push', $prefs[$id] ?? null)));
    }

    // ------------------------------------------------------------------ delivery
    /** Deliver pending notifications through FCM and email, honouring each member's preferences. */
    public static function dispatchPending(int $batchSize = 500): array
    {
        return Locks::named('mz:notification-dispatch', function () use ($batchSize) {
            $total = 0;
            $fcmOn = Fcm::enabled();
            while (true) {
                $pending = DB::table('notifications as n')
                    ->leftJoin('user_preferences as p', 'p.user_id', '=', 'n.user_id')
                    ->where('n.delivery_status', 'pending')
                    ->orderBy('n.id')
                    ->limit($batchSize)
                    ->select('n.id', 'n.user_id', 'n.type', 'n.topic', 'n.title', 'n.body', 'n.entity_type', 'n.entity_id', 'n.data', 'p.notifications_enabled', 'p.notification_topics')
                    ->get()->all();
                if (! $pending) {
                    break;
                }
                $total += count($pending);
                $skipped = [];
                $deliverable = [];
                foreach ($pending as $n) {
                    if (! $fcmOn || ! self::allowed($n->type, $n->topic, 'push', $n)) {
                        $skipped[] = $n->id;
                    } else {
                        $deliverable[] = $n;
                    }
                }
                if ($skipped) {
                    DB::table('notifications')->whereIn('id', $skipped)->update(['delivery_status' => 'skipped']);
                }
                if (! $deliverable) {
                    continue;
                }
                $tokens = DB::table('fcm_tokens')->whereIn('user_id', array_unique(array_map(fn ($n) => $n->user_id, $deliverable)))->whereNull('invalidated_at')->select('user_id', 'token')->get();
                $byUser = [];
                foreach ($tokens as $t) {
                    $byUser[$t->user_id][] = $t->token;
                }
                $messages = [];
                $noToken = [];
                foreach ($deliverable as $n) {
                    $userTokens = $byUser[$n->user_id] ?? [];
                    if (! $userTokens) {
                        $noToken[] = $n->id;
                    }
                    $payloadData = [
                        'notification_id' => (string) $n->id,
                        'type' => (string) $n->type,
                        'entity_type' => (string) ($n->entity_type ?: ''),
                        'entity_id' => $n->entity_id ? (string) $n->entity_id : '',
                        'channel' => self::CHANNEL[$n->type] ?? 'default',
                    ];
                    if (! empty($n->data)) {
                        $decoded = is_string($n->data) ? json_decode($n->data, true) : (array) $n->data;
                        if (is_array($decoded)) {
                            foreach ($decoded as $dk => $dv) {
                                if (is_scalar($dv) || $dv === null) {
                                    $payloadData[(string) $dk] = (string) ($dv ?? '');
                                }
                            }
                        }
                    }
                    foreach ($userTokens as $token) {
                        $messages[] = [
                            'notificationId' => $n->id,
                            'token' => $token,
                            'title' => $n->title,
                            'body' => mb_substr((string) $n->body, 0, 1000),
                            'data' => $payloadData,
                        ];
                    }
                }
                if ($noToken) {
                    DB::table('notifications')->whereIn('id', $noToken)->update(['delivery_status' => 'skipped']);
                }
                try {
                    $results = Fcm::sendBatch($messages);
                } catch (\Throwable $e) {
                    Log::error('FCM send failed', ['error' => $e->getMessage()]);
                    $results = array_map(fn ($m) => ['token' => $m['token'], 'ok' => false, 'dead' => false], $messages);
                }
                $okIds = [];
                $dead = [];
                foreach ($results as $i => $r) {
                    if ($r['ok']) $okIds[$messages[$i]['notificationId']] = true;
                    if ($r['dead']) $dead[] = $r['token'];
                }
                $attempted = array_unique(array_map(fn ($m) => $m['notificationId'], $messages));
                $failed = array_values(array_filter($attempted, fn ($id) => ! isset($okIds[$id])));
                if ($okIds) DB::table('notifications')->whereIn('id', array_keys($okIds))->update(['delivery_status' => 'sent', 'sent_at' => DB::raw('NOW()')]);
                if ($failed) DB::table('notifications')->whereIn('id', $failed)->update(['delivery_status' => 'failed']);
                // Invalid / unregistered tokens are switched off and never tried again.
                if ($dead) DB::table('fcm_tokens')->whereIn('token', array_values(array_unique($dead)))->update(['invalidated_at' => DB::raw('NOW()')]);
            }
            return ['processed' => $total, 'emails' => self::dispatchEmails()];
        }) ?? ['busy' => true];
    }

    /**
     * The email channel of the same notifications: the member's registered address, their topic
     * preference, one branded template. No address / switched off → skipped; an SMTP error → failed.
     * Neither touches the in-app notification or the push.
     */
    public static function dispatchEmails(): array
    {
        $rows = DB::table('notifications as n')->join('users as u', 'u.id', '=', 'n.user_id')->leftJoin('user_preferences as p', 'p.user_id', '=', 'n.user_id')
            ->where('n.email_status', 'pending')->orderBy('n.id')->limit(self::EMAIL_BATCH)
            ->get(['n.id', 'n.type', 'n.topic', 'n.title', 'n.body', 'n.entity_type', 'n.entity_id', 'n.created_at', 'u.email', 'u.full_name', 'u.deleted_at', 'p.notifications_enabled', 'p.notification_topics'])->all();
        if (! $rows) return ['sent' => 0];
        $sent = $skipped = $failed = [];
        $configured = Mailer::configured();
        foreach ($rows as $r) {
            $email = trim((string) $r->email);
            if (! $configured || $r->deleted_at || ! filter_var($email, FILTER_VALIDATE_EMAIL) || ! self::allowed($r->type, $r->topic, 'email', $r)) {
                $skipped[] = $r->id;
                continue;
            }
            $ok = Mailer::sendNotification($email, [
                'name' => $r->full_name,
                'title' => $r->title,
                'body' => $r->body,
                'topic' => $r->topic ?: self::topicOf($r->type),
                'at' => $r->created_at,
                'link' => DeepLinks::forEntity($r->entity_type, $r->entity_id),
            ]);
            if ($ok) $sent[] = $r->id; else $failed[] = $r->id;
        }
        if ($sent) DB::table('notifications')->whereIn('id', $sent)->update(['email_status' => 'sent', 'emailed_at' => DB::raw('NOW()')]);
        if ($skipped) DB::table('notifications')->whereIn('id', $skipped)->update(['email_status' => 'skipped']);
        if ($failed) DB::table('notifications')->whereIn('id', $failed)->update(['email_status' => 'failed']);
        return ['sent' => count($sent), 'skipped' => count($skipped), 'failed' => count($failed)];
    }

    /** Where the delivery chain stands (admin diagnostics): counts per channel and status, jobs, providers. */
    public static function health(): array
    {
        $since = gmdate('Y-m-d H:i:s', time() - 7 * 86400);
        $push = DB::table('notifications')->where('created_at', '>=', $since)->groupBy('delivery_status')->selectRaw('delivery_status as s, COUNT(*) as c')->pluck('c', 's')->all();
        $email = DB::table('notifications')->where('created_at', '>=', $since)->groupBy('email_status')->selectRaw('email_status as s, COUNT(*) as c')->pluck('c', 's')->all();
        return [
            'push' => array_map('intval', $push),
            'email' => array_map('intval', $email),
            'oldest_pending' => DB::table('notifications')->where('delivery_status', 'pending')->min('created_at'),
            'scheduled_pending' => DB::table('scheduled_notifications')->where('status', 'pending')->count(),
            'fcm' => Fcm::status(),
            'email_configured' => Mailer::configured(),
            'devices' => DB::table('fcm_tokens')->whereNull('invalidated_at')->count(),
            'jobs_enabled' => (bool) config('mz.jobs_enabled'),
            'jobs' => \App\Mz\Jobs\Jobs::status(),
        ];
    }

    // ------------------------------------------------------------------ user-facing center
    public static function serialize(object $n): array
    {
        return [
            'id' => $n->id,
            'type' => $n->type,
            'title' => $n->title,
            'body' => $n->body,
            'entity_type' => $n->entity_type,
            'entity_id' => $n->entity_id,
            'data' => is_string($n->data) ? json_decode($n->data, true) : $n->data,
            'is_read' => (bool) $n->read_at,
            'read_at' => $n->read_at,
            'created_at' => $n->created_at,
        ];
    }

    public static function listForUser(int $userId, bool $unreadOnly, ?string $q, int $limit, int $offset): array
    {
        $qb = DB::table('notifications')->where('user_id', $userId);
        if ($unreadOnly) $qb->whereNull('read_at');
        if ($q) {
            // The body is stored encrypted (MZ-Seal), so the database cannot search it: match the
            // member's own notifications here (bounded to the latest 2000) and page the matches.
            $needle = mb_strtolower($q);
            $ids = (clone $qb)->orderByDesc('created_at')->orderByDesc('id')->limit(2000)->get(['id', 'title', 'body'])
                ->filter(fn ($n) => str_contains(mb_strtolower((string) $n->title), $needle) || str_contains(mb_strtolower((string) $n->body), $needle))
                ->pluck('id')->all();
            $qb->whereIn('id', $ids ?: [0]);
        }
        $total = (clone $qb)->count();
        $rows = $qb->orderByDesc('created_at')->orderByDesc('id')->limit($limit)->offset($offset)->get();
        return ['items' => $rows->map(fn ($r) => self::serialize($r))->all(), 'total' => $total];
    }

    public static function unreadCount(int $userId): int
    {
        return DB::table('notifications')->where('user_id', $userId)->whereNull('read_at')->count();
    }

    public static function markRead(int $userId, int $id): bool
    {
        $n = DB::table('notifications')->where(['id' => $id, 'user_id' => $userId])->first(['id', 'read_at']);
        if (! $n) return false;
        if (! $n->read_at) DB::table('notifications')->where('id', $id)->update(['read_at' => DB::raw('NOW()')]);
        return true;
    }

    public static function markAllRead(int $userId): int
    {
        return DB::table('notifications')->where('user_id', $userId)->whereNull('read_at')->update(['read_at' => DB::raw('NOW()')]);
    }

    // ------------------------------------------------------------------ Educational & Payment notifications
    public static function notifyEduQuizSubmitted(int $quizId, int $attemptId, int $studentId): void
    {
        $quiz = DB::table('edu_quizzes')->where('id', $quizId)->first(['id', 'title', 'course_id']);
        if (! $quiz) return;
        $student = DB::table('users')->where('id', $studentId)->first(['id', 'full_name']);
        $studentName = $student?->full_name ?? 'ተማሪ';

        // Find teachers of the course / graders
        $teacherIds = [];
        if ($quiz->course_id) {
            $course = DB::table('edu_courses')->where('id', $quiz->course_id)->first(['teacher_user_id', 'subject_id']);
            if ($course?->teacher_user_id) $teacherIds[] = (int) $course->teacher_user_id;
            if ($course?->subject_id) {
                $subTeachers = DB::table('edu_subject_teachers')->where('subject_id', $course->subject_id)->pluck('user_id')->all();
                $teacherIds = array_merge($teacherIds, array_map('intval', $subTeachers));
            }
        }
        $teacherIds = array_unique(array_filter($teacherIds));
        if (! $teacherIds) {
            // Fallback to education admins
            $teacherIds = DB::table('users')->where('role_id', '<=', 2)->pluck('id')->all();
        }

        self::createForUsers($teacherIds, [
            'type' => 'edu_quiz',
            'title' => "የፈተና መልስ ቀርቧል: {$quiz->title}",
            'body' => "ተማሪ {$studentName} የፈተናውን መልስ አስገብቷል። እባክዎ እርምት ያድርጉ።",
            'entityType' => 'edu_quiz',
            'entityId' => $quizId,
            'data' => ['quiz_id' => $quizId, 'attempt_id' => $attemptId, 'student_id' => $studentId],
            'dedupeKey' => fn (int $uid) => "edu_quiz_sub:{$attemptId}:{$uid}",
        ]);
    }

    public static function notifyEduStudentSubmitted(int $attemptId, int $studentId, int $quizId, bool $isPendingGrading): void
    {
        $quiz = DB::table('edu_quizzes')->where('id', $quizId)->first(['id', 'title']);
        $title = $quiz?->title ?? 'ፈተና';

        $body = $isPendingGrading
            ? "የፈተና መልስዎ ገብቷል። የጽሑፍ ጥያቄዎች በአስተማሪው ታርመው ሲያልቁ ውጤቱ ይገለጻል።"
            : "የፈተና መልስዎ በተሳካ ሁኔታ ገብቷል። ውጤቱን በእንቅስቃሴ ገጽዎ መመልከት ይችላሉ።";

        self::notifyUser($studentId, [
            'type' => 'education',
            'title' => "የፈተና መልስ ገብቷል: {$title}",
            'body' => $body,
            'entityType' => 'edu_quiz',
            'entityId' => $quizId,
            'data' => ['quiz_id' => $quizId, 'attempt_id' => $attemptId],
            'dedupeKey' => fn (int $uid) => "edu_quiz_sub_stud:{$attemptId}:{$uid}",
        ]);
    }

    public static function notifyEduGradingComplete(int $attemptId, int $studentId, int $quizId): void
    {
        $quiz = DB::table('edu_quizzes')->where('id', $quizId)->first(['id', 'title']);
        $title = $quiz?->title ?? 'ፈተና';

        self::notifyUser($studentId, [
            'type' => 'edu_grading',
            'title' => "የፈተና ውጤት ወጥቷል: {$title}",
            'body' => "የፈተናዎ እርምት ተጠናቆ ውጤት ተለቋል። አሁን መመልከት ይችላሉ።",
            'entityType' => 'edu_quiz',
            'entityId' => $quizId,
            'data' => ['quiz_id' => $quizId, 'attempt_id' => $attemptId],
            'dedupeKey' => fn (int $uid) => "edu_quiz_res:{$attemptId}:{$uid}",
        ]);
    }

    public static function notifyEduClassAssigned(int $studentId, int $classId): void
    {
        $class = DB::table('edu_classes')->where('id', $classId)->first(['name']);
        $className = $class?->name ?? 'ክፍል';

        self::notifyUser($studentId, [
            'type' => 'education',
            'title' => "የክፍል ምደባ: {$className}",
            'body' => "ወደ {$className} ክፍል ተመድበዋል። የትምህርት መርሐግብርዎን መመልከት ይችላሉ።",
            'entityType' => 'edu_class',
            'entityId' => $classId,
            'data' => ['class_id' => $classId],
            'dedupeKey' => fn (int $uid) => "edu_class_assign:{$classId}:{$uid}",
        ]);
    }

    public static function notifyEduPromotion(int $studentId, string $toClassName): void
    {
        self::notifyUser($studentId, [
            'type' => 'education',
            'title' => "የክፍል ዝውውር / እድገት",
            'body' => "እንኳን ደስ አለዎት! ወደ {$toClassName} ተዛውረዋል / አድገዋል።",
            'entityType' => 'education',
            'entityId' => $studentId,
            'data' => ['class' => $toClassName],
            'dedupeKey' => fn (int $uid) => "edu_promo:{$studentId}:" . md5($toClassName),
        ]);
    }

    public static function notifyReceiptSubmitted(int $receiptId, int $userId): void
    {
        $user = DB::table('users')->where('id', $userId)->first(['full_name', 'member_no']);
        $name = $user?->full_name ?? 'አባል';

        // Notify finance managers / admins
        $financeAdmins = DB::table('users')->where('role_id', '<=', 2)->pluck('id')->all();
        if ($financeAdmins) {
            self::createForUsers($financeAdmins, [
                'type' => 'payment',
                'title' => "አዲስ የወርሃዊ መዋጮ ደረሰኝ ቀርቧል",
                'body' => "አባል {$name} የክፍያ ደረሰኝ አስገብተዋል። እባክዎ ገምግመው ያጽድቁ።",
                'entityType' => 'payment_receipt',
                'entityId' => $receiptId,
                'data' => ['receipt_id' => $receiptId, 'user_id' => $userId],
                'dedupeKey' => fn (int $uid) => "rec_sub:{$receiptId}:{$uid}",
            ]);
        }
    }

    public static function notifyReceiptReviewed(int $userId, int $receiptId, bool $approved, ?string $reason = null): void
    {
        $title = $approved ? "የወርሃዊ መዋጮ ደረሰኝዎ ጸድቋል" : "የወርሃዊ መዋጮ ደረሰኝዎ ውድቅ ተደርጓል";
        $body = $approved
            ? "ያቀረቡት የክፍያ ደረሰኝ ተረጋግጦ ጸድቋል። እናመሰግናለን!"
            : "ያቀረቡት የክፍያ ደረሰኝ ተቀባይነት አላገኘም። ምክንያት: " . ($reason ?: 'ያልተገለጸ');

        self::notifyUser($userId, [
            'type' => 'payment',
            'title' => $title,
            'body' => $body,
            'entityType' => 'payment_receipt',
            'entityId' => $receiptId,
            'data' => ['receipt_id' => $receiptId, 'approved' => $approved, 'reason' => $reason],
            'dedupeKey' => fn (int $uid) => "rec_rev:{$receiptId}:{$uid}",
        ]);
    }
}


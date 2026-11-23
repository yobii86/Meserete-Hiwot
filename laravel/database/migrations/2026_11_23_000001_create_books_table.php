<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('books')) {
            Schema::create('books', function (Blueprint $table) {
                $table->increments('id');
                $table->string('name', 200);
                $table->string('subtitle', 255)->nullable();
                $table->string('author', 200)->nullable();
                $table->string('publisher', 200)->nullable();
                $table->unsignedSmallInteger('publication_year')->nullable();
                $table->string('language', 64)->default('am');
                $table->string('code', 60)->unique();
                $table->string('category', 100)->default('books');
                $table->unsignedInteger('library_category_id')->nullable()->index();
                $table->unsignedInteger('course_id')->nullable()->index();
                $table->unsignedInteger('subject_id')->nullable()->index();
                $table->unsignedInteger('unit_id')->nullable();
                $table->unsignedInteger('lesson_id')->nullable();
                $table->unsignedInteger('magazine_id')->nullable()->index();
                $table->string('description', 1000)->nullable();
                $table->unsignedInteger('quantity')->default(1);
                $table->unsignedInteger('available_quantity')->default(1);
                $table->string('condition', 100)->nullable();
                $table->string('status', 20)->default('active')->index();
                $table->string('image', 255)->nullable();
                $table->string('location', 200)->nullable();
                $table->string('notes', 1000)->nullable();
                $table->unsignedInteger('created_by')->nullable();
                $table->unsignedInteger('updated_by')->nullable();
                $table->dateTime('created_at')->useCurrent();
                $table->dateTime('updated_at')->useCurrent();
                $table->dateTime('deleted_at')->nullable();
                $table->string('domain', 50)->default('mezmur')->index();
                $table->string('kind', 20)->default('physical')->index(); // physical, digital
                $table->unsignedInteger('department_id')->nullable();
                $table->string('file_path', 255)->nullable();
                $table->string('file_mime', 100)->nullable();
                $table->unsignedInteger('file_size')->nullable();
                $table->string('narration_path', 255)->nullable();
                $table->string('narration_mime', 100)->nullable();
                $table->unsignedInteger('narration_duration')->nullable();
                $table->unsignedInteger('downloads')->default(0);

                $table->index('name');
            });
        }

        // Migrate existing books from items table to books table if books table is empty
        if (Schema::hasTable('items') && Schema::hasTable('books') && DB::table('books')->count() === 0) {
            $bookItems = DB::table('items')
                ->where(function ($w) {
                    $w->where('category', 'books')
                      ->orWhere('kind', 'digital')
                      ->orWhereNotNull('library_category_id');
                })
                ->get();

            foreach ($bookItems as $b) {
                DB::table('books')->insertOrIgnore([
                    'id' => $b->id,
                    'name' => $b->name,
                    'subtitle' => $b->subtitle,
                    'author' => $b->author,
                    'publisher' => $b->publisher,
                    'publication_year' => $b->publication_year,
                    'language' => $b->language ?: 'am',
                    'code' => $b->code,
                    'category' => 'books',
                    'library_category_id' => $b->library_category_id,
                    'course_id' => $b->course_id,
                    'subject_id' => $b->subject_id,
                    'unit_id' => $b->unit_id,
                    'lesson_id' => $b->lesson_id,
                    'magazine_id' => $b->magazine_id,
                    'description' => $b->description,
                    'quantity' => $b->quantity,
                    'available_quantity' => $b->available_quantity,
                    'condition' => $b->condition,
                    'status' => $b->status,
                    'image' => $b->image,
                    'location' => $b->location,
                    'notes' => $b->notes,
                    'created_by' => $b->created_by,
                    'updated_by' => $b->updated_by,
                    'created_at' => $b->created_at,
                    'updated_at' => $b->updated_at,
                    'deleted_at' => $b->deleted_at,
                    'domain' => $b->domain,
                    'kind' => $b->kind ?: 'physical',
                    'department_id' => $b->department_id,
                    'file_path' => $b->file_path,
                    'file_mime' => $b->file_mime,
                    'file_size' => $b->file_size,
                    'narration_path' => $b->narration_path,
                    'narration_mime' => $b->narration_mime,
                    'narration_duration' => $b->narration_duration,
                    'downloads' => $b->downloads ?? 0,
                ]);
            }
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('books');
    }
};

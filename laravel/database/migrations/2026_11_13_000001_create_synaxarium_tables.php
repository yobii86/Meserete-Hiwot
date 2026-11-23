<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        // 1. Static Reference: 13 Ethiopian Months
        if (!Schema::hasTable('synaxarium_months')) {
            Schema::create('synaxarium_months', function (Blueprint $table) {
                $table->increments('id');
                $table->unsignedTinyInteger('month_number')->unique();
                $table->string('name_am', 50);
                $table->string('name_en', 50);
                $table->string('name_geez', 50)->nullable();
                $table->unsignedTinyInteger('days_count')->default(30);
                $table->unsignedTinyInteger('order_index')->default(0);
                $table->string('season_am', 50)->nullable();
                $table->timestamps();
            });
        }

        // 2. Ingestion Audit Trail: 26 Amharic Source Files (B001-B013, B028-B040)
        if (!Schema::hasTable('synaxarium_sources')) {
            Schema::create('synaxarium_sources', function (Blueprint $table) {
                $table->bigIncrements('id');
                $table->string('book_id', 10)->unique();
                $table->string('classification', 50)->default('main_reading'); // 'main_reading' or 'saints_list'
                $table->unsignedTinyInteger('month_number')->nullable()->index();
                $table->string('filename', 255);
                $table->string('collection', 100)->default('C12_Synaxarium_Senkisar');
                $table->string('group', 50)->default('Sinksar_Amharic');
                $table->string('title', 255);
                $table->string('language', 10)->default('am');
                $table->unsignedInteger('total_chapters')->default(0);
                $table->unsignedBigInteger('file_size')->default(0);
                $table->string('checksum', 64)->nullable();
                $table->string('import_status', 20)->default('pending');
                $table->timestamp('imported_at')->nullable();
                $table->timestamps();
            });
        }

        // 3. Daily Liturgical Readings: 366 Rows (12 x 30 + Pagumen 6)
        if (!Schema::hasTable('synaxarium_entries')) {
            Schema::create('synaxarium_entries', function (Blueprint $table) {
                $table->bigIncrements('id');
                $table->unsignedTinyInteger('month')->index();
                $table->unsignedTinyInteger('day')->index();
                $table->string('unique_code', 10)->unique(); // e.g. "01-01"
                $table->string('title', 255);
                $table->string('date_heading', 100)->nullable();
                $table->text('summary')->nullable();
                $table->longText('body_am');
                $table->longText('raw_content')->nullable();
                $table->json('annual_feasts')->nullable();
                $table->json('monthly_feasts')->nullable();
                $table->text('verses')->nullable();
                $table->string('source_book_id', 10)->nullable()->index();
                $table->unsignedInteger('chapter_number')->nullable();
                $table->unsignedInteger('char_count')->default(0);
                $table->unsignedInteger('word_count')->default(0);
                $table->string('editorial_status', 20)->default('imported'); // 'imported', 'in_review', 'verified'
                $table->boolean('is_editorially_verified')->default(false);
                $table->text('editorial_notes')->nullable();
                $table->unsignedBigInteger('verified_by')->nullable();
                $table->timestamp('verified_at')->nullable();
                $table->timestamps();

                $table->unique(['month', 'day'], 'uq_synaxarium_month_day');
            });
        }

        // 4. Complete Authoritative Daily Saints Section: 366 Rows (B028 - B040)
        if (!Schema::hasTable('synaxarium_daily_saints')) {
            Schema::create('synaxarium_daily_saints', function (Blueprint $table) {
                $table->bigIncrements('id');
                $table->unsignedBigInteger('entry_id')->nullable()->index();
                $table->unsignedTinyInteger('month')->index();
                $table->unsignedTinyInteger('day')->index();
                $table->string('source_book_id', 10)->nullable()->index();
                $table->string('title', 255);
                $table->longText('section_text_clean');
                $table->longText('section_text_raw')->nullable();
                $table->unsignedInteger('commemoration_lines_count')->default(0);
                $table->string('editorial_status', 20)->default('imported');
                $table->boolean('is_editorially_verified')->default(false);
                $table->timestamps();

                $table->unique(['month', 'day'], 'uq_synax_daily_saints_date');
            });
        }

        // 5. Individual Saint Accounts / Commemoration Paragraphs (Extracted with is_editorially_verified = false)
        if (!Schema::hasTable('synaxarium_saints')) {
            Schema::create('synaxarium_saints', function (Blueprint $table) {
                $table->bigIncrements('id');
                $table->unsignedBigInteger('entry_id')->nullable()->index();
                $table->unsignedTinyInteger('month')->index();
                $table->unsignedTinyInteger('day')->index();
                $table->unsignedInteger('order_index')->default(0);
                $table->string('name', 255)->index();
                $table->string('type', 100)->nullable();
                $table->string('feast_type', 50)->default('annual');
                $table->longText('biography')->nullable();
                $table->string('source_reference', 255)->nullable();
                $table->longText('raw_content')->nullable();
                $table->string('source_book_id', 10)->nullable()->index();
                $table->string('editorial_status', 20)->default('imported');
                $table->boolean('is_editorially_verified')->default(false);
                $table->timestamps();

                $table->index(['month', 'day'], 'idx_synaxarium_saints_date');
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('synaxarium_saints');
        Schema::dropIfExists('synaxarium_daily_saints');
        Schema::dropIfExists('synaxarium_entries');
        Schema::dropIfExists('synaxarium_sources');
        Schema::dropIfExists('synaxarium_months');
    }
};

<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. PDF Pages table for pre-rendered WebP pages
        if (!Schema::hasTable('pdf_document_pages')) {
            Schema::create('pdf_document_pages', function (Blueprint $table) {
                $table->id();
                $table->string('document_type', 64)->index(); // 'item', 'magazine', 'lesson_material', 'chat', 'general'
                $table->unsignedBigInteger('document_id')->nullable()->index();
                $table->string('original_pdf_path', 500)->index();
                $table->unsignedInteger('page_number')->index();
                $table->string('webp_path', 500);
                $table->unsignedInteger('width')->default(0);
                $table->unsignedInteger('height')->default(0);
                $table->unsignedBigInteger('file_size')->default(0);
                $table->string('status', 32)->default('completed')->index(); // 'pending', 'processing', 'completed', 'failed'
                $table->timestamps();

                $table->unique(['original_pdf_path', 'page_number'], 'pdf_page_uniq');
            });
        }

        // 2. Media conversions & migration tracking
        if (!Schema::hasTable('media_conversions')) {
            Schema::create('media_conversions', function (Blueprint $table) {
                $table->id();
                $table->string('media_type', 32)->index(); // 'audio', 'image', 'pdf'
                $table->string('entity_type', 64)->index(); // 'mezmur', 'user', 'item', 'magazine', etc.
                $table->unsignedBigInteger('entity_id')->nullable()->index();
                $table->string('source_column', 64)->nullable();
                $table->string('original_path', 500)->index();
                $table->string('original_format', 32)->nullable();
                $table->unsignedBigInteger('original_size')->default(0);
                $table->string('converted_path', 500)->nullable();
                $table->string('converted_format', 32)->nullable(); // 'flac', 'webp'
                $table->unsignedBigInteger('converted_size')->default(0);
                $table->string('status', 32)->default('pending')->index(); // 'pending', 'processing', 'completed', 'failed', 'skipped'
                $table->unsignedSmallInteger('retry_count')->default(0);
                $table->text('error_message')->nullable();
                $table->timestamp('started_at')->nullable();
                $table->timestamp('completed_at')->nullable();
                $table->timestamps();

                $table->unique(['original_path', 'converted_format'], 'media_conv_uniq');
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('pdf_document_pages');
        Schema::dropIfExists('media_conversions');
    }
};


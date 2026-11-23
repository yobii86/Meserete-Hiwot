<?php

namespace Tests\Unit;

use App\Mz\Services\MediaMigration;
use App\Mz\Services\MediaProcessing;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class MediaProcessingAndMigrationTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        if (! Schema::hasTable('media_conversions')) {
            Schema::create('media_conversions', function ($table) {
                $table->id();
                $table->string('media_type', 32);
                $table->string('entity_type', 64)->nullable();
                $table->unsignedBigInteger('entity_id')->nullable();
                $table->string('source_column', 64)->nullable();
                $table->string('original_path', 500);
                $table->string('original_format', 32)->nullable();
                $table->unsignedBigInteger('original_size')->default(0);
                $table->string('converted_path', 500)->nullable();
                $table->string('converted_format', 32)->nullable();
                $table->unsignedBigInteger('converted_size')->default(0);
                $table->string('status', 32)->default('pending');
                $table->unsignedSmallInteger('retry_count')->default(0);
                $table->text('error_message')->nullable();
                $table->timestamp('started_at')->nullable();
                $table->timestamp('completed_at')->nullable();
                $table->timestamps();
            });
        }
    }

    public function test_webp_conversion_creates_valid_webp(): void
    {
        if (! function_exists('imagewebp')) {
            $this->markTestSkipped('GD imagewebp not available in this test environment');
        }

        $tmpPng = tempnam(sys_get_temp_dir(), 'test_img_') . '.png';
        $im = imagecreatetruecolor(50, 50);
        $red = imagecolorallocate($im, 255, 0, 0);
        imagefilledrectangle($im, 0, 0, 49, 49, $red);
        imagepng($im, $tmpPng);
        imagedestroy($im);

        $tmpWebp = tempnam(sys_get_temp_dir(), 'test_out_') . '.webp';

        try {
            $res = MediaProcessing::convertToWebp($tmpPng, $tmpWebp, 80);
            $this->assertTrue($res['success']);
            $this->assertFileExists($tmpWebp);
            $this->assertGreaterThan(0, $res['size']);
            $this->assertEquals('image/webp', $res['mime']);

            $header = file_get_contents($tmpWebp, false, null, 0, 12);
            $this->assertStringStartsWith('RIFF', $header);
            $this->assertEquals('WEBP', substr($header, 8, 4));
        } finally {
            @unlink($tmpPng);
            @unlink($tmpWebp);
        }
    }

    public function test_pdf_page_count_from_pdf_stream(): void
    {
        $tmpPdf = tempnam(sys_get_temp_dir(), 'test_pdf_') . '.pdf';
        $content = "%PDF-1.4\n1 0 obj <</Type /Catalog /Pages 2 0 R>> endobj\n2 0 obj <</Type /Pages /Kids [3 0 R 4 0 R] /Count 2>> endobj\n3 0 obj <</Type /Page /Parent 2 0 R>> endobj\n4 0 obj <</Type /Page /Parent 2 0 R>> endobj\nxref\n0 5\ntrailer <</Root 1 0 R>>\n%%EOF";
        file_put_contents($tmpPdf, $content);

        try {
            $count = MediaProcessing::getPdfPageCount($tmpPdf);
            $this->assertEquals(2, $count);
        } finally {
            @unlink($tmpPdf);
        }
    }

    public function test_media_migration_summary_structure(): void
    {
        $summary = MediaMigration::summary();
        $this->assertArrayHasKey('total_items', $summary);
        $this->assertArrayHasKey('pending', $summary);
        $this->assertArrayHasKey('completed', $summary);
        $this->assertArrayHasKey('failed', $summary);
        $this->assertArrayHasKey('types', $summary);
        $this->assertArrayHasKey('storage', $summary);
        $this->assertArrayHasKey('bytes_saved', $summary['storage']);
    }

    public function test_retry_failed_marks_missing_source_files_as_skipped(): void
    {
        \Illuminate\Support\Facades\DB::table('media_conversions')->insert([
            'media_type' => 'pdf',
            'original_path' => 'public/magazines/non_existent_file_12345.pdf',
            'status' => 'failed',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $reset = MediaMigration::retryFailed();
        $this->assertEquals(0, $reset);

        $row = \Illuminate\Support\Facades\DB::table('media_conversions')
            ->where('original_path', 'public/magazines/non_existent_file_12345.pdf')
            ->first();

        $this->assertEquals('skipped', $row->status);
        $this->assertStringContainsString('Source file not found on disk', $row->error_message);
    }
}


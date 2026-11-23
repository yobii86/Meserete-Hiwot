<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SynaxariumDailySaint extends Model
{
    protected $table = 'synaxarium_daily_saints';

    protected $fillable = [
        'entry_id',
        'month',
        'day',
        'source_book_id',
        'title',
        'section_text_clean',
        'section_text_raw',
        'commemoration_lines_count',
        'editorial_status',
        'is_editorially_verified',
    ];

    protected $casts = [
        'entry_id' => 'integer',
        'month' => 'integer',
        'day' => 'integer',
        'commemoration_lines_count' => 'integer',
        'is_editorially_verified' => 'boolean',
    ];

    public function entry(): BelongsTo
    {
        return $this->belongsTo(SynaxariumEntry::class, 'entry_id');
    }

    public function monthModel(): BelongsTo
    {
        return $this->belongsTo(SynaxariumMonth::class, 'month', 'month_number');
    }

    public function source(): BelongsTo
    {
        return $this->belongsTo(SynaxariumSource::class, 'source_book_id', 'book_id');
    }
}

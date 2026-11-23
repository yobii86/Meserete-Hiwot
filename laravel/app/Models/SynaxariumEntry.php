<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class SynaxariumEntry extends Model
{
    protected $table = 'synaxarium_entries';

    protected $fillable = [
        'month',
        'day',
        'unique_code',
        'title',
        'date_heading',
        'summary',
        'body_am',
        'raw_content',
        'annual_feasts',
        'monthly_feasts',
        'verses',
        'source_book_id',
        'chapter_number',
        'char_count',
        'word_count',
        'editorial_status',
        'is_editorially_verified',
        'editorial_notes',
        'verified_by',
        'verified_at',
    ];

    protected $casts = [
        'month' => 'integer',
        'day' => 'integer',
        'chapter_number' => 'integer',
        'char_count' => 'integer',
        'word_count' => 'integer',
        'is_editorially_verified' => 'boolean',
        'annual_feasts' => 'array',
        'monthly_feasts' => 'array',
        'verified_at' => 'datetime',
    ];

    public function monthModel(): BelongsTo
    {
        return $this->belongsTo(SynaxariumMonth::class, 'month', 'month_number');
    }

    public function source(): BelongsTo
    {
        return $this->belongsTo(SynaxariumSource::class, 'source_book_id', 'book_id');
    }

    public function dailySaint(): HasOne
    {
        return $this->hasOne(SynaxariumDailySaint::class, 'entry_id');
    }

    public function saints(): HasMany
    {
        return $this->hasMany(SynaxariumSaint::class, 'entry_id');
    }
}

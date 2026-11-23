<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SynaxariumSaint extends Model
{
    protected $table = 'synaxarium_saints';

    protected $fillable = [
        'entry_id',
        'month',
        'day',
        'order_index',
        'name',
        'type',
        'feast_type',
        'biography',
        'source_reference',
        'raw_content',
        'source_book_id',
        'editorial_status',
        'is_editorially_verified',
    ];

    protected $casts = [
        'entry_id' => 'integer',
        'month' => 'integer',
        'day' => 'integer',
        'order_index' => 'integer',
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

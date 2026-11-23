<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SynaxariumSource extends Model
{
    protected $table = 'synaxarium_sources';

    protected $fillable = [
        'book_id',
        'classification',
        'month_number',
        'filename',
        'collection',
        'group',
        'title',
        'language',
        'total_chapters',
        'file_size',
        'checksum',
        'import_status',
        'imported_at',
    ];

    protected $casts = [
        'month_number' => 'integer',
        'total_chapters' => 'integer',
        'file_size' => 'integer',
        'imported_at' => 'datetime',
    ];

    public function entries(): HasMany
    {
        return $this->hasMany(SynaxariumEntry::class, 'source_book_id', 'book_id');
    }

    public function dailySaints(): HasMany
    {
        return $this->hasMany(SynaxariumDailySaint::class, 'source_book_id', 'book_id');
    }

    public function saints(): HasMany
    {
        return $this->hasMany(SynaxariumSaint::class, 'source_book_id', 'book_id');
    }
}

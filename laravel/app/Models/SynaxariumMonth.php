<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SynaxariumMonth extends Model
{
    protected $table = 'synaxarium_months';

    protected $fillable = [
        'month_number',
        'name_am',
        'name_en',
        'name_geez',
        'days_count',
        'order_index',
        'season_am',
    ];

    protected $casts = [
        'month_number' => 'integer',
        'days_count' => 'integer',
        'order_index' => 'integer',
    ];

    public function entries(): HasMany
    {
        return $this->hasMany(SynaxariumEntry::class, 'month', 'month_number');
    }

    public function dailySaints(): HasMany
    {
        return $this->hasMany(SynaxariumDailySaint::class, 'month', 'month_number');
    }

    public function saints(): HasMany
    {
        return $this->hasMany(SynaxariumSaint::class, 'month', 'month_number');
    }
}

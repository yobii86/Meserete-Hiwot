<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Ensure any existing categories with empty or null domain belong to 'timhirt'
        DB::table('library_categories')
            ->where(function ($q) {
                $q->whereNull('domain')->orWhere('domain', '');
            })
            ->update(['domain' => 'timhirt']);

        // 2. Standard Ethiopian Orthodox Sunday School Education Library Categories
        $standardCategories = [
            [
                'name' => 'ትምህርተ ሃይማኖት',
                'name_en' => 'Dogma & Theology',
                'code' => 'THEO',
                'category_type' => 'both',
                'description' => 'የኦርቶዶክስ ተዋሕዶ ሃይማኖት መሠረታዊ አስተምህሮዎችና ዶግማ',
                'sort_order' => 1,
            ],
            [
                'name' => 'መጽሐፍ ቅዱስ ጥናት',
                'name_en' => 'Biblical Studies',
                'code' => 'BIBLE',
                'category_type' => 'both',
                'description' => 'የብሉይና የሐዲስ ኪዳን መጻሕፍት ትርጓሜና ጥናት',
                'sort_order' => 2,
            ],
            [
                'name' => 'የቤተክርስቲያን ታሪክ',
                'name_en' => 'Church History',
                'code' => 'HIST',
                'category_type' => 'both',
                'description' => 'የኢትዮጵያ ኦርቶዶክስ ተዋሕዶ ቤተክርስቲያንና የዓለም አብያተ ክርስቲያናት ታሪክ',
                'sort_order' => 3,
            ],
            [
                'name' => 'ሥርዓተ ቤተክርስቲያን',
                'name_en' => 'Liturgy & Sacraments',
                'code' => 'LIT',
                'category_type' => 'both',
                'description' => 'የቅዳሴ፣ የምስጢራተ ቤተክርስቲያንና የበዓላት ሥርዓቶች',
                'sort_order' => 4,
            ],
            [
                'name' => 'ክርስቲያናዊ ሥነ-ምግባር',
                'name_en' => 'Christian Ethics & Spirituality',
                'code' => 'ETHIC',
                'category_type' => 'both',
                'description' => 'ክርስቲያናዊ ሕይወት፣ መንፈሳዊ ተጋድሎና ሥነ-ምግባር',
                'sort_order' => 5,
            ],
            [
                'name' => 'የሕጻናት መጻሕፍት',
                'name_en' => 'Children Books',
                'code' => 'KIDS',
                'category_type' => 'both',
                'description' => 'ለሰንበት ትምህርት ቤት ሕጻናትና ታዳጊዎች የተዘጋጁ መጻሕፍት',
                'sort_order' => 6,
            ],
            [
                'name' => 'ማጣቀሻ መጻሕፍት',
                'name_en' => 'Reference & Dictionaries',
                'code' => 'REF',
                'category_type' => 'both',
                'description' => 'የግዕዝ መዝገበ ቃላት፣ የዜማና የጥናት ማጣቀሻዎች',
                'sort_order' => 7,
            ],
            [
                'name' => 'ዝማሬና ቅኔ',
                'name_en' => 'Hymnody & Sacred Poetry',
                'code' => 'HYMN',
                'category_type' => 'both',
                'description' => 'የቅዱስ ያሬድ ዜማዎች፣ የመዝሙርና የቅኔ ጥናት መጻሕፍት',
                'sort_order' => 8,
            ],
            [
                'name' => 'መጽሔቶችና ጋዜጦች',
                'name_en' => 'Periodicals & Magazines',
                'code' => 'MAG',
                'category_type' => 'both',
                'description' => 'ወቅታዊ የሰንበት ትምህርት ቤት መጽሔቶችና ጽሑፎች',
                'sort_order' => 9,
            ],
        ];

        foreach ($standardCategories as $cat) {
            $existing = DB::table('library_categories')
                ->where('domain', 'timhirt')
                ->where(function ($w) use ($cat) {
                    $w->where('name', $cat['name'])
                      ->orWhere('code', $cat['code']);
                })
                ->first();

            if ($existing) {
                DB::table('library_categories')->where('id', $existing->id)->update([
                    'domain' => 'timhirt',
                    'name_en' => $existing->name_en ?: $cat['name_en'],
                    'code' => $existing->code ?: $cat['code'],
                    'category_type' => $existing->category_type ?: $cat['category_type'],
                    'description' => $existing->description ?: $cat['description'],
                    'sort_order' => $cat['sort_order'],
                    'updated_at' => now(),
                ]);
            } else {
                DB::table('library_categories')->insert([
                    'domain' => 'timhirt',
                    'name' => $cat['name'],
                    'name_en' => $cat['name_en'],
                    'code' => $cat['code'],
                    'category_type' => $cat['category_type'],
                    'description' => $cat['description'],
                    'sort_order' => $cat['sort_order'],
                    'is_active' => true,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }
        }

        // 3. Normalize existing items with category 'books'
        $theoId = DB::table('library_categories')->where('code', 'THEO')->value('id');
        if ($theoId) {
            // For items that had "ትምህርተ ሐይማኖት", link to THEO
            DB::table('items')
                ->where('category', 'like', '%ትምህርተ%')
                ->whereNull('library_category_id')
                ->update(['library_category_id' => $theoId]);
        }
    }

    public function down(): void
    {
        // Non-destructive rollback
    }
};

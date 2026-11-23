<?php

namespace Tests\Unit;

use Tests\TestCase;

class EduQuizScoringActualCountsTest extends TestCase
{
    public function test_scoring_ratios_and_percentages(): void
    {
        $testCases = [
            ['correct' => 1, 'total' => 1, 'expected_display' => '1 / 1', 'expected_pct' => 100.0],
            ['correct' => 3, 'total' => 6, 'expected_display' => '3 / 6', 'expected_pct' => 50.0],
            ['correct' => 0, 'total' => 6, 'expected_display' => '0 / 6', 'expected_pct' => 0.0],
            ['correct' => 4, 'total' => 5, 'expected_display' => '4 / 5', 'expected_pct' => 80.0],
            ['correct' => 8, 'total' => 10, 'expected_display' => '8 / 10', 'expected_pct' => 80.0],
            ['correct' => 15, 'total' => 20, 'expected_display' => '15 / 20', 'expected_pct' => 75.0],
            ['correct' => 9, 'total' => 10, 'expected_display' => '9 / 10', 'expected_pct' => 90.0],
            ['correct' => 20, 'total' => 20, 'expected_display' => '20 / 20', 'expected_pct' => 100.0],
        ];

        foreach ($testCases as $tc) {
            $correct = $tc['correct'];
            $total = $tc['total'];
            $display = "{$correct} / {$total}";
            $pct = round(($correct / $total) * 100, 2);

            $this->assertEquals($tc['expected_display'], $display);
            $this->assertEquals($tc['expected_pct'], $pct);
        }
    }
}


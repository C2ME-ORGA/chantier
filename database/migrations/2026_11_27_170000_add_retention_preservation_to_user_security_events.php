<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * @phase expand
 *
 * @ticket CHAN-45
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('user_security_events', function (Blueprint $table): void {
            $table->timestamp('preserved_at')->nullable()->after('occurred_at');
            $table->string('preservation_reason', 500)->nullable()->after('preserved_at');
            $table->index(['preserved_at', 'occurred_at']);
        });
    }

    public function down(): void
    {
        Schema::table('user_security_events', function (Blueprint $table): void {
            $table->dropIndex(['preserved_at', 'occurred_at']);
            $table->dropColumn(['preserved_at', 'preservation_reason']);
        });
    }
};

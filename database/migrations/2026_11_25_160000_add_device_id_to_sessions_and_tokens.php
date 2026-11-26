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
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('sessions', function (Blueprint $table) {
            $table->foreignId('device_id')
                ->nullable()
                ->after('user_id')
                ->constrained('user_devices')
                ->nullOnDelete();
        });

        Schema::table('personal_access_tokens', function (Blueprint $table) {
            $table->foreignId('device_id')
                ->nullable()
                ->after('tokenable_id')
                ->constrained('user_devices')
                ->nullOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('personal_access_tokens', function (Blueprint $table) {
            $table->dropConstrainedForeignId('device_id');
        });

        Schema::table('sessions', function (Blueprint $table) {
            $table->dropConstrainedForeignId('device_id');
        });
    }
};

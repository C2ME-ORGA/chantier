<?php

namespace App\Domains\Identity\Listeners;

use Illuminate\Foundation\Http\Events\RequestHandled;
use Illuminate\Support\Facades\DB;

final class AssociateDeviceWithSession
{
    public function handle(RequestHandled $event): void
    {
        $request = $event->request;
        $association = $request->attributes->get('identity.session_device');

        if (
            ! is_array($association)
            || config('session.driver') !== 'database'
            || ! isset($association['device_id'], $association['user_id'], $association['session_id'])
        ) {
            return;
        }

        DB::connection(config('session.connection'))
            ->table(config('session.table', 'sessions'))
            ->where('id', $association['session_id'])
            ->where('user_id', $association['user_id'])
            ->update(['device_id' => $association['device_id']]);
    }
}

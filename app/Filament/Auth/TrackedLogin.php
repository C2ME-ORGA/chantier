<?php

namespace App\Filament\Auth;

use App\Domains\Identity\Actions\RecordSecurityEvent;
use App\Models\User;
use Filament\Auth\Http\Responses\Contracts\LoginResponse;
use Filament\Auth\Pages\Login;
use Filament\Facades\Filament;
use Filament\Support\Components\Attributes\Exposed;
use Illuminate\Validation\ValidationException;

final class TrackedLogin extends Login
{
    #[Exposed]
    public function authenticate(): ?LoginResponse
    {
        $isMultiFactorChallenge = filled($this->userUndertakingMultiFactorAuthentication);
        $challengeUser = $isMultiFactorChallenge
            ? $this->getUserUndertakingMultiFactorAuthentication()
            : null;

        try {
            $response = parent::authenticate();
        } catch (ValidationException $exception) {
            app(RecordSecurityEvent::class)->handle(
                $isMultiFactorChallenge ? 'mfa.failed' : 'authentication.failed',
                'filament',
                $challengeUser instanceof User ? $challengeUser : null,
                context: [
                    'method' => $isMultiFactorChallenge ? 'totp' : 'password',
                    'failure_code' => $isMultiFactorChallenge ? 'invalid_mfa_challenge' : 'invalid_credentials',
                    'source' => 'filament_login',
                ],
            );

            throw $exception;
        }

        $authenticatedUser = Filament::auth()->user();

        if ($response !== null && $authenticatedUser instanceof User) {
            app(RecordSecurityEvent::class)->handle(
                'authentication.succeeded',
                'filament',
                $authenticatedUser,
                context: ['source' => 'filament_login'],
            );
        }

        return $response;
    }
}

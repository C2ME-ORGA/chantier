<#
.SYNOPSIS
    Valide la syntaxe des blocs PowerShell extraits par docs-check.php.

.DESCRIPTION
    Lit tous les fichiers .ps1 générés depuis les documents CHAN-99 et vérifie
    qu'ils se parsèment sans erreur. Aucun bloc n'est exécuté.

.PARAMETER Directory
    Répertoire contenant les blocs .ps1 émis par docs-check.php.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts/simulation/check-docs.ps1 -Directory <dossier>
#>

param(
    [Parameter(Mandatory = $true)]
    [string] $Directory
)

$ErrorActionPreference = 'Stop'
$errors = @()
$checked = 0

if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
    Write-Error "Répertoire introuvable : $Directory"
    exit 2
}

Get-ChildItem -LiteralPath $Directory -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object {
    $checked++
    $tokens = $null
    $parseErrors = $null

    [System.Management.Automation.Language.Parser]::ParseFile(
        $_.FullName,
        [ref] $tokens,
        [ref] $parseErrors
    ) | Out-Null

    foreach ($parseError in $parseErrors) {
        $errors += "$($_.Name):$($parseError.Extent.StartLineNumber): $($parseError.Message)"
    }
}

if ($checked -eq 0) {
    Write-Output 'POWERSHELL_BLOCKS=0'
    Write-Output 'POWERSHELL_VERDICT=NOT RUN'
    exit 3
}

foreach ($errorMessage in $errors) {
    Write-Output "POWERSHELL_ERROR=$errorMessage"
}

Write-Output "POWERSHELL_BLOCKS=$checked"
Write-Output "POWERSHELL_ERRORS=$($errors.Count)"

if ($errors.Count -gt 0) {
    Write-Output 'POWERSHELL_VERDICT=FAIL'
    exit 1
}

Write-Output 'POWERSHELL_VERDICT=PASS'
exit 0

<#
Preflight an approved restricted-data root without changing ACLs. This script is
evidence-gathering only; it cannot certify institutional approval, encryption,
backup, retention, or incident-response compliance.

The report contains no raw data. Store it only in the approved restricted-data
root or another approved restricted operational location.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RestrictedRoot,

    [string]$ReportPath,

    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

function Get-NormalizedPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\', '/')
}

function Test-FilesystemRoot {
    param([Parameter(Mandatory = $true)][string]$Path)
    $pathValue = $Path.TrimEnd('\', '/')
    $rootValue = [IO.Path]::GetPathRoot($Path).TrimEnd('\', '/')
    $pathValue.Equals($rootValue, [StringComparison]::OrdinalIgnoreCase)
}

function Test-PathWithin {
    param(
        [Parameter(Mandatory = $true)][string]$Child,
        [Parameter(Mandatory = $true)][string]$Parent
    )
    $childValue = $Child.TrimEnd('\', '/')
    $parentValue = $Parent.TrimEnd('\', '/')
    $childValue.Equals($parentValue, [StringComparison]::OrdinalIgnoreCase) -or
        $childValue.StartsWith($parentValue + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
        $childValue.StartsWith($parentValue + [IO.Path]::AltDirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function Test-GitRepositoryPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $git = Get-Command -Name git -ErrorAction SilentlyContinue
    $gitPath = if ($null -ne $git) { $git.Source } else { 'C:\Program Files\Git\cmd\git.exe' }
    if (-not (Test-Path -LiteralPath $gitPath)) {
        throw 'Git is required to verify that restricted storage is outside a Git repository.'
    }
    $previousErrorActionPreference = $ErrorActionPreference
    $nativePreference = Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue
    if ($null -ne $nativePreference) {
        $previousNativePreference = $nativePreference.Value
    }
    try {
        # `git rev-parse` returns 128 for an ordinary non-repository directory.
        # Capture that expected diagnostic locally so global Stop preferences do
        # not turn it into a terminating preflight failure.
        $ErrorActionPreference = 'Continue'
        if ($null -ne $nativePreference) {
            $PSNativeCommandUseErrorActionPreference = $false
        }
        $output = & $gitPath -C $Path rev-parse --is-inside-work-tree --is-bare-repository 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
        if ($null -ne $nativePreference) {
            $PSNativeCommandUseErrorActionPreference = $previousNativePreference
        }
    }
    if ($exitCode -ne 0) {
        $diagnostic = (@($output) | ForEach-Object { $_.ToString() }) -join "`n"
        if ($diagnostic -match '(?i)not a git repository') {
            return $false
        }
        throw 'Unable to determine whether the restricted root is inside a Git repository.'
    }
    @($output | ForEach-Object { $_.ToString().Trim().ToLowerInvariant() }) -contains 'true'
}

$resolvedRoot = Get-NormalizedPath -Path $RestrictedRoot
$resolvedProject = Get-NormalizedPath -Path $ProjectRoot
$downloadsPath = Join-Path -Path $env:USERPROFILE -ChildPath 'Downloads'
$resolvedDownloads = if (Test-Path -LiteralPath $downloadsPath) { Get-NormalizedPath -Path $downloadsPath } else { $null }

if (Test-FilesystemRoot -Path $resolvedRoot) {
    throw 'Restricted root must be a dedicated directory, not a filesystem root.'
}

if (Test-PathWithin -Child $resolvedRoot -Parent $resolvedProject) {
    throw 'Restricted root must be outside the repository.'
}
if ($null -ne $resolvedDownloads -and (Test-PathWithin -Child $resolvedRoot -Parent $resolvedDownloads)) {
    throw 'Restricted root must be outside the Downloads workspace.'
}
if (Test-GitRepositoryPath -Path $resolvedRoot) {
    throw 'Restricted root must not be inside a Git working tree or repository.'
}

$canonicalReportPath = Join-Path -Path $resolvedRoot -ChildPath 'governance\restricted-root-preflight.json'
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = $canonicalReportPath
} else {
    $requestedReportPath = [IO.Path]::GetFullPath($ReportPath)
    $canonicalFullReportPath = [IO.Path]::GetFullPath($canonicalReportPath)
    if (-not $requestedReportPath.Equals($canonicalFullReportPath, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Restricted-root preflight report must use the canonical governance path under the restricted root.'
    }
    $ReportPath = $canonicalReportPath
}

$acl = Get-Acl -LiteralPath $resolvedRoot
# Detect built-in broad groups and sandbox-created groups without relying on a
# machine-specific principal name.
$broadPrincipalPatterns = @(
    '(?i)(^|\\)Everyone$',
    '(?i)(^|\\)Users$',
    '(?i)(^|\\)Authenticated Users$',
    '(?i)sandbox'
)
$broadRead = @(
    $acl.Access | Where-Object {
        $accessEntry = $_
        $identity = $accessEntry.IdentityReference.Value
        $isBroad = @($broadPrincipalPatterns | Where-Object { $identity -match $_ }).Count -gt 0
        $accessEntry.AccessControlType -eq 'Allow' -and
        ($accessEntry.FileSystemRights.ToString() -match 'Read|FullControl|Modify|Write') -and
        $isBroad
    }
)

$result = [ordered]@{
    schema_version = '1.1'
    checked_at_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    root_path_recorded = $false
    dedicated_directory = $true
    outside_repository = $true
    outside_downloads = $true
    git_worktree_checked = $true
    is_git_worktree = $false
    broad_read_entries = @($broadRead | ForEach-Object {
        [ordered]@{
            identity = $_.IdentityReference.Value
            rights = $_.FileSystemRights.ToString()
            inherited = $_.IsInherited
        }
    })
    access_control_passed = ($broadRead.Count -eq 0)
    institutional_controls_pending = @('approval', 'encryption', 'backup', 'retention', 'incident_response')
}

$reportDirectory = Split-Path -Parent $canonicalReportPath
if (-not (Test-Path -LiteralPath $reportDirectory)) {
    New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
}
$temporaryReport = Join-Path -Path $reportDirectory -ChildPath ('.restricted-root-preflight.tmp-' + $PID + '.json')
try {
    $result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $temporaryReport -Encoding utf8
    Move-Item -LiteralPath $temporaryReport -Destination $canonicalReportPath -Force
} finally {
    if (Test-Path -LiteralPath $temporaryReport) {
        Remove-Item -LiteralPath $temporaryReport -Force
    }
}
if (-not $result.access_control_passed) {
    throw 'Restricted-root preflight found broad read/write access. Review ACLs before any real-data use.'
}
Write-Output 'Restricted-root preflight passed. Institutional controls remain a manual governance requirement.'

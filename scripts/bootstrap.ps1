[CmdletBinding()]
param(
    [string]$PythonCommand,
    [switch]$NoUpgradePip
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$venvPath = Join-Path $projectRoot ".venv"

function Test-PythonRuntime {
    param(
        [Parameter(Mandatory)][string]$Command,
        [string[]]$Prefix = @()
    )

    try {
        & $Command @Prefix -c "import sys; raise SystemExit(sys.version_info < (3, 11))" 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
    }
    catch {
        return $false
    }
    return $false
}

function Resolve-PythonRuntime {
    param([string]$RequestedCommand)

    $candidates = New-Object System.Collections.ArrayList

    if (-not [string]::IsNullOrWhiteSpace($RequestedCommand)) {
        [void]$candidates.Add(@{ Command = $RequestedCommand; Prefix = @() })
    }

    foreach ($variableName in @("ARENA_PYTHON_EXE", "PYTHON_EXE")) {
        $candidate = [Environment]::GetEnvironmentVariable($variableName)
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            [void]$candidates.Add(@{ Command = $candidate; Prefix = @() })
        }
    }

    if (Get-Command py -ErrorAction SilentlyContinue) {
        foreach ($version in @("-3.13", "-3.12", "-3.11")) {
            [void]$candidates.Add(@{ Command = "py"; Prefix = @($version) })
        }
    }

    foreach ($commandName in @("python", "python3")) {
        if (Get-Command $commandName -ErrorAction SilentlyContinue) {
            [void]$candidates.Add(@{ Command = $commandName; Prefix = @() })
        }
    }

    $searchPatterns = @(
        "C:\Program Files\Python3*\python.exe",
        "C:\Program Files (x86)\Python3*\python.exe",
        "C:\Python3*\python.exe",
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python3*\python.exe")
    )
    foreach ($pattern in $searchPatterns) {
        if ([string]::IsNullOrWhiteSpace($pattern)) {
            continue
        }
        foreach ($found in (Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Sort-Object FullName -Descending)) {
            [void]$candidates.Add(@{ Command = $found.FullName; Prefix = @() })
        }
    }

    foreach ($candidate in $candidates) {
        if (Test-PythonRuntime -Command $candidate.Command -Prefix $candidate.Prefix) {
            return $candidate
        }
    }

    throw "Python 3.11 or newer is required. Install Python 3.11+ or rerun with -PythonCommand, for example: -PythonCommand 'C:\Program Files\Python313\python.exe'."
}

$pythonRuntime = Resolve-PythonRuntime -RequestedCommand $PythonCommand
$PythonCommand = $pythonRuntime.Command
$pythonPrefix = $pythonRuntime.Prefix
Write-Host "Using Python runtime: $PythonCommand $($pythonPrefix -join ' ')"

if (-not (Test-Path -LiteralPath $venvPath -PathType Container)) {
    & $PythonCommand @pythonPrefix -m venv $venvPath
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create the virtual environment."
    }
}

$venvPython = Join-Path $venvPath "Scripts\python.exe"
if (-not $NoUpgradePip) {
    & $venvPython -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to upgrade pip."
    }
}
& $venvPython -m pip install --require-hashes -r (Join-Path $projectRoot "requirements-build.lock")
if ($LASTEXITCODE -ne 0) {
    throw "Failed to install locked build dependencies."
}
& $venvPython -m pip install --require-hashes -r (Join-Path $projectRoot "requirements.lock")
if ($LASTEXITCODE -ne 0) {
    throw "Failed to install locked runtime dependencies."
}
& $venvPython -m pip install --no-deps --no-build-isolation --editable $projectRoot
if ($LASTEXITCODE -ne 0) {
    throw "Failed to install arena-hero-agent."
}
& $venvPython -m pip check
if ($LASTEXITCODE -ne 0) {
    throw "The installed dependency set is inconsistent."
}

Write-Host "Environment ready. Start with .\start_agent.ps1 or .\start_agent.cmd."

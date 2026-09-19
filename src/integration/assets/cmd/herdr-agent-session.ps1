# managed by herdr; reinstalling the integration replaces this file.
# HERDR_INTEGRATION_ID=cmd
# HERDR_INTEGRATION_VERSION=1

param([string]$Action = "")

if ($Action -ne "session") { exit 0 }
if ($env:HERDR_ENV -ne "1") { exit 0 }
if ([string]::IsNullOrWhiteSpace($env:HERDR_PANE_ID)) { exit 0 }
if ([string]::IsNullOrWhiteSpace($env:HERDR_SOCKET_PATH)) { exit 0 }

# Session identity only: the screen manifest owns agent state, so this must
# never report an agent state. Everything stays silent on every path.
$inputText = [Console]::In.ReadToEnd()
try {
    $payload = if ([string]::IsNullOrWhiteSpace($inputText)) { $null } else { $inputText | ConvertFrom-Json }
} catch {
    $payload = $null
}
if ($null -eq $payload) { exit 0 }

$event = [string]$payload.hook_event_name
if (-not [string]::IsNullOrWhiteSpace($event) -and $event -ne "SessionStart") { exit 0 }
if ([string]::IsNullOrWhiteSpace($payload.session_id)) { exit 0 }

$herdr = if ([string]::IsNullOrWhiteSpace($env:HERDR_BIN_PATH)) { "herdr" } else { $env:HERDR_BIN_PATH }
$commandArgs = @(
    "pane", "report-agent-session", $env:HERDR_PANE_ID,
    "--source", "herdr:cmd", "--agent", "cmd",
    "--agent-session-id", [string]$payload.session_id,
    "--seq", [string][DateTime]::UtcNow.Ticks,
    "--session-start-source", "new"
)
$job = $null
try {
    $job = Start-Job -ScriptBlock {
        param($Executable, [object[]]$Arguments)
        & $Executable @Arguments *> $null
    } -ArgumentList $herdr, (,$commandArgs)
    if ($null -eq (Wait-Job -Job $job -Timeout 1)) {
        Stop-Job -Job $job
    }
} catch {
    # Hook failures must stay silent.
    $null = $_
} finally {
    if ($null -ne $job) {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
}

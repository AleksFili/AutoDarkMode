param([switch]$Installed)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Solar.ps1"

function Assert-Equal($Actual, $Expected, [string]$Name) {
    if ($Actual -ne $Expected) {
        throw "${Name}: expected '$Expected', received '$Actual'."
    }
    Write-Output "PASS $Name"
}

$moscow = @{ Latitude = 55.7558; Longitude = 37.6173 }
$noon = [datetimeoffset]'2026-11-27T12:00:00+03:00'
$schedule = Get-ThemeSchedule $noon @moscow
Assert-Equal $schedule.Theme Light 'Moscow in daylight'
Assert-Equal ($schedule.Sunset - $schedule.DarkAt).TotalMinutes 20 'Exact 20-minute offset'
Assert-Equal ([Math]::Abs(($schedule.Sunrise - [datetime]'2026-11-27T05:27:00').TotalMinutes) -lt 2) $true 'Moscow sunrise reference'
Assert-Equal ([Math]::Abs(($schedule.Sunset - [datetime]'2026-11-27T13:06:00').TotalMinutes) -lt 2) $true 'Moscow sunset reference'
Assert-Equal (Get-ThemeSchedule ($schedule.Sunrise.AddSeconds(-1)) @moscow).Theme Dark 'Before sunrise'
Assert-Equal (Get-ThemeSchedule $schedule.Sunrise @moscow).Theme Light 'At sunrise'
Assert-Equal (Get-ThemeSchedule ($schedule.DarkAt.AddSeconds(-1)) @moscow).Theme Light 'Before evening switch'
Assert-Equal (Get-ThemeSchedule $schedule.DarkAt @moscow).Theme Dark 'At evening switch'
Assert-Equal (Get-ThemeSchedule $schedule.Sunset @moscow).Theme Dark 'At sunset'
Assert-Equal (Get-ThemeSchedule ($noon.ToOffset([timespan]::FromHours(-8))) @moscow).Sunrise $schedule.Sunrise 'Independent of clock offset'

$tromso = @{ Latitude = 69.6492; Longitude = 18.9553 }
Assert-Equal (Get-ThemeSchedule ([datetimeoffset]'2026-06-21T00:00:00Z') @tromso).Theme Light 'Midnight sun'
Assert-Equal (Get-ThemeSchedule ([datetimeoffset]'2026-12-21T12:00:00Z') @tromso).Theme Dark 'Polar night'

$east = Get-ThemeSchedule ([datetimeoffset]'2028-02-29T00:00:00Z') 0 179
$west = Get-ThemeSchedule ([datetimeoffset]'2028-02-29T00:00:00Z') 0 -179
Assert-Equal $east.Theme Light 'Leap day east of date line'
Assert-Equal $west.Theme Light 'Leap day west of date line'
Assert-Equal $east.Sunrise.Date ([datetime]'2028-02-28') 'Sunrise on previous UTC date'

Assert-Equal (Get-ThemeSchedule ([datetimeoffset]'2026-11-28T11:00:00+03:00') @moscow).Theme Light 'Catch up after missing sunrise'
Assert-Equal (Get-ThemeSchedule ([datetimeoffset]'2026-11-28T22:00:00+03:00') @moscow).Theme Dark 'Catch up after missing evening switch'
Assert-Equal (Get-ThemeSchedule ([datetimeoffset]'2026-11-28T00:01:00+03:00') @moscow).Theme Dark 'Remain dark after local midnight'
Assert-Equal $schedule.Sunrise.Kind Utc 'Solar events are UTC'
Assert-Equal (Get-ThemeSchedule ([datetimeoffset]'2026-06-21T12:00:00Z') -90 0).State PolarNight 'South Pole in June'
Assert-Equal (Get-ThemeSchedule ([datetimeoffset]'2026-12-21T12:00:00Z') -90 0).State PolarDay 'South Pole in December'

$validPreview = & {
    function Get-Content { '{"Latitude":55.7558,"Longitude":37.6173}' }

    & "$PSScriptRoot\Update-Theme.ps1" -Preview
}
Assert-Equal $validPreview.State Normal 'Accepts decimal coordinates from the installer'

foreach ($example in @(
    @{ Name = 'Missing latitude'; Json = '{"Longitude":37}'; ErrorText = 'must contain numeric' }
    @{ Name = 'Null longitude'; Json = '{"Latitude":55,"Longitude":null}'; ErrorText = 'must contain numeric' }
    @{ Name = 'Non-numeric coordinates'; Json = '{"Latitude":true,"Longitude":"37"}'; ErrorText = 'must contain numeric' }
    @{ Name = 'Out-of-range latitude'; Json = '{"Latitude":91,"Longitude":37}'; ErrorText = 'Latitude' }
    @{ Name = 'Out-of-range longitude'; Json = '{"Latitude":55,"Longitude":181}'; ErrorText = 'Longitude' }
)) {
    $message = & {
        function Get-Content { $example.Json }

        try {
            $null = & "$PSScriptRoot\Update-Theme.ps1" -Preview
        } catch {
            $_.Exception.Message
        }
    }
    Assert-Equal ($message -like "*$($example.ErrorText)*") $true $example.Name
}

if ($Installed) {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $taskName = "AutoDarkMode-$($identity.User.Value)"
    $task = Get-ScheduledTask -TaskName $taskName
    $definition = [xml](Export-ScheduledTask -TaskName $taskName)
    $triggers = $definition.Task.Triggers
    $settings = $definition.Task.Settings
    $principal = $definition.Task.Principals.Principal
    $action = $definition.Task.Actions.Exec

    Assert-Equal $task.Settings.Enabled $true 'Task is enabled'
    Assert-Equal $principal.UserId $identity.User.Value 'Task belongs to this Windows user'
    Assert-Equal $principal.LogonType InteractiveToken 'Runs in the interactive session'
    Assert-Equal $triggers.LogonTrigger.UserId $identity.Name 'Runs at sign-in'
    Assert-Equal $triggers.SessionStateChangeTrigger.UserId $identity.Name 'Unlock trigger belongs to this user'
    Assert-Equal $triggers.SessionStateChangeTrigger.StateChange SessionUnlock 'Runs at unlock'
    $subscription = [xml]$triggers.EventTrigger.Subscription
    $resumeQuery = $subscription.QueryList.Query.Select
    Assert-Equal $resumeQuery.Path System 'Listens for wake events in the System log'
    Assert-Equal $resumeQuery.InnerText "*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and EventID=1]]" 'Runs on the Windows wake event'
    Assert-Equal $triggers.TimeTrigger.Repetition.Interval PT1M 'Repeats every minute'
    Assert-Equal ([bool]$triggers.TimeTrigger.Repetition.Duration) $false 'Periodic trigger does not expire'
    Assert-Equal $settings.StartWhenAvailable 'true' 'Catches up after a missed time trigger'
    Assert-Equal $settings.DisallowStartIfOnBatteries 'false' 'Starts on battery'
    Assert-Equal $settings.StopIfGoingOnBatteries 'false' 'Continues when unplugged'
    Assert-Equal $settings.MultipleInstancesPolicy IgnoreNew 'Prevents overlapping updates'
    Assert-Equal $action.Command "$env:SystemRoot\System32\wscript.exe" 'Uses Windows Script Host'
    Assert-Equal $action.Arguments "//B //NoLogo `"$PSScriptRoot\Run-Hidden.vbs`"" 'Runs the hidden launcher from this checkout'

    $initialRun = ($task | Get-ScheduledTaskInfo).LastRunTime
    $deadline = (Get-Date).AddSeconds(75)
    do {
        Start-Sleep -Seconds 2
        $run = $task | Get-ScheduledTaskInfo
    } until ($run.LastRunTime -gt $initialRun -or (Get-Date) -ge $deadline)
    Assert-Equal ($run.LastRunTime -gt $initialRun) $true 'Task runs automatically within 75 seconds'
    while ((Get-ScheduledTask -TaskName $taskName).State -eq 'Running' -and (Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 1
    }
    $run = $task | Get-ScheduledTaskInfo
    Assert-Equal $run.LastTaskResult 0 'Scheduled run completes successfully'
    $preview = & "$PSScriptRoot\Update-Theme.ps1" -Preview
    $expected = [int]($preview.Theme -eq 'Light')
    $theme = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    Assert-Equal $theme.AppsUseLightTheme $expected 'Application theme matches the schedule'
    Assert-Equal $theme.SystemUsesLightTheme $expected 'System theme matches the schedule'
}

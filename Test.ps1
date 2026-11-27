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

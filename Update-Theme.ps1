param([switch]$Preview)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Solar.ps1"

$location = Get-Content -LiteralPath "$PSScriptRoot\location.json" -Raw | ConvertFrom-Json
foreach ($coordinate in $location.Latitude, $location.Longitude) {
    if ($coordinate -isnot [int] -and $coordinate -isnot [long] -and $coordinate -isnot [double] -and $coordinate -isnot [decimal]) {
        throw 'location.json must contain numeric Latitude and Longitude. Run Install.ps1 to configure them.'
    }
}
$schedule = Get-ThemeSchedule ([datetimeoffset]::Now) $location.Latitude $location.Longitude
if ($Preview) {
    [pscustomobject]@{
        Theme = $schedule.Theme
        State = $schedule.State
        Sunrise = $(if ($schedule.Sunrise) { $schedule.Sunrise.ToLocalTime() })
        Sunset = $(if ($schedule.Sunset) { $schedule.Sunset.ToLocalTime() })
        DarkAt = $(if ($schedule.DarkAt) { $schedule.DarkAt.ToLocalTime() })
    }
    return
}

$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$value = [int]($schedule.Theme -eq 'Light')
if (-not (Test-Path -LiteralPath $key)) {
    New-Item -Path $key -Force | Out-Null
}
$current = Get-ItemProperty -LiteralPath $key
$changed = $false
foreach ($name in 'AppsUseLightTheme', 'SystemUsesLightTheme') {
    if ($current.$name -ne $value) {
        New-ItemProperty -LiteralPath $key -Name $name -Value $value -PropertyType DWord -Force | Out-Null
        $changed = $true
    }
}

if ($changed) {
    Add-Type -Namespace AutoDarkMode -Name NativeMethods -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern System.IntPtr SendMessageTimeout(
    System.IntPtr window, uint message, System.UIntPtr wParam, string lParam,
    uint flags, uint timeout, out System.UIntPtr result);
'@
    $result = [UIntPtr]::Zero
    [AutoDarkMode.NativeMethods]::SendMessageTimeout(
        [IntPtr]0xffff, 0x1a, [UIntPtr]::Zero, 'ImmersiveColorSet', 2, 100, [ref]$result
    ) | Out-Null
}

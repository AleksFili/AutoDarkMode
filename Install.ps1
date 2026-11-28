param(
    [Parameter(Mandatory)][ValidateRange(-90, 90)][double]$Latitude,
    [Parameter(Mandatory)][ValidateRange(-180, 180)][double]$Longitude
)

$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$taskName = "AutoDarkMode-$($identity.User.Value)"
$launcher = Join-Path $PSScriptRoot 'Run-Hidden.vbs'
$action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\wscript.exe" -Argument "//B //NoLogo `"$launcher`""
$logon = New-ScheduledTaskTrigger -AtLogOn -User $identity.Name
$periodic = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1)
$triggerNamespace = 'Root/Microsoft/Windows/TaskScheduler'
$resume = New-CimInstance -ClientOnly -CimClass (Get-CimClass -Namespace $triggerNamespace -ClassName MSFT_TaskEventTrigger) -Property @{
    Enabled = $true
    Subscription = "<QueryList><Query Id='0' Path='System'><Select Path='System'>*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and EventID=1]]</Select></Query></QueryList>"
}
$unlock = New-CimInstance -ClientOnly -CimClass (Get-CimClass -Namespace $triggerNamespace -ClassName MSFT_TaskSessionStateChangeTrigger) -Property @{
    Enabled = $true
    StateChange = [uint32]8 # TASK_SESSION_UNLOCK
    UserId = $identity.Name
}
$principal = New-ScheduledTaskPrincipal -UserId $identity.Name -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 2)

@{ Latitude = $Latitude; Longitude = $Longitude } | ConvertTo-Json |
    Set-Content -LiteralPath "$PSScriptRoot\location.json" -Encoding ASCII
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($logon, $periodic, $resume, $unlock) -Principal $principal -Settings $settings -Description 'Changes Windows theme at sunrise and 20 minutes before sunset.' -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

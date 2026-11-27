function Get-SolarDay {
    param([datetime]$UtcDate, [double]$Latitude, [double]$Longitude)

    $radians = [Math]::PI / 180
    $utcMidnight = [datetime]::SpecifyKind($UtcDate.Date, 'Utc')
    $meanNoon = $utcMidnight.AddMinutes(720 - 4 * $Longitude)
    $century = ($meanNoon.ToOADate() - 36526.5) / 36525
    $meanLongitude = (280.46646 + $century * (36000.76983 + 0.0003032 * $century)) % 360
    $anomaly = (357.52911 + $century * (35999.05029 - 0.0001537 * $century)) * $radians
    $eccentricity = 0.016708634 - $century * (0.000042037 + 0.0000001267 * $century)
    $center = [Math]::Sin($anomaly) * (1.914602 - $century * (0.004817 + 0.000014 * $century)) +
        [Math]::Sin(2 * $anomaly) * (0.019993 - 0.000101 * $century) + 0.000289 * [Math]::Sin(3 * $anomaly)
    $omega = (125.04 - 1934.136 * $century) * $radians
    $obliquity = (23 + (26 + (21.448 - $century * (46.815 + $century * (0.00059 - 0.001813 * $century))) / 60) / 60 +
        0.00256 * [Math]::Cos($omega)) * $radians
    $apparentLongitude = ($meanLongitude + $center - 0.00569 - 0.00478 * [Math]::Sin($omega)) * $radians
    $declination = [Math]::Asin([Math]::Sin($obliquity) * [Math]::Sin($apparentLongitude))
    $y = [Math]::Pow([Math]::Tan($obliquity / 2), 2)
    $longitudeAngle = $meanLongitude * $radians
    $equation = 4 / $radians * ($y * [Math]::Sin(2 * $longitudeAngle) - 2 * $eccentricity * [Math]::Sin($anomaly) +
        4 * $eccentricity * $y * [Math]::Sin($anomaly) * [Math]::Cos(2 * $longitudeAngle) -
        0.5 * $y * $y * [Math]::Sin(4 * $longitudeAngle) - 1.25 * $eccentricity * $eccentricity * [Math]::Sin(2 * $anomaly))

    $noon = $meanNoon.AddMinutes(-$equation)
    $latitudeAngle = $Latitude * $radians
    $horizon = [Math]::Cos(90.833 * $radians)
    $middle = [Math]::Sin($latitudeAngle) * [Math]::Sin($declination)
    $amplitude = [Math]::Cos($latitudeAngle) * [Math]::Cos($declination)
    if ($middle - $amplitude -ge $horizon) {
        return [pscustomobject]@{ Noon = $noon; State = 'PolarDay'; Sunrise = $null; Sunset = $null }
    }
    if ($middle + $amplitude -le $horizon) {
        return [pscustomobject]@{ Noon = $noon; State = 'PolarNight'; Sunrise = $null; Sunset = $null }
    }
    $halfDay = 4 * [Math]::Acos(($horizon - $middle) / $amplitude) / $radians
    [pscustomobject]@{
        Noon = $noon
        State = 'Normal'
        Sunrise = $noon.AddMinutes(-$halfDay)
        Sunset = $noon.AddMinutes($halfDay)
    }
}

function Get-ThemeSchedule {
    param(
        [datetimeoffset]$Now,
        [ValidateRange(-90, 90)][double]$Latitude,
        [ValidateRange(-180, 180)][double]$Longitude
    )

    $utc = $Now.UtcDateTime
    $solarDate = $utc.AddMinutes(4 * $Longitude).Date
    $days = foreach ($offset in -1, 0, 1) {
        Get-SolarDay $solarDate.AddDays($offset) $Latitude $Longitude
    }
    $day = $days | Sort-Object { [Math]::Abs(($_.Noon - $utc).TotalMinutes) } | Select-Object -First 1
    $darkAt = $null
    $light = $day.State -eq 'PolarDay'
    if ($day.State -eq 'Normal') {
        $darkAt = $day.Sunset.AddMinutes(-20)
        $light = $utc -ge $day.Sunrise -and $utc -lt $darkAt
    }
    [pscustomobject]@{
        State = $day.State
        Theme = $(if ($light) { 'Light' } else { 'Dark' })
        Sunrise = $day.Sunrise
        Sunset = $day.Sunset
        DarkAt = $darkAt
    }
}

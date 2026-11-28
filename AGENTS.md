# Repository Guidelines

## Project Structure

AutoDarkMode switches the current Windows user's system and application themes on a sunrise and sunset schedule. All scripts live in the repository root. `Solar.ps1` calculates sunrise, sunset, and the 20-minute evening offset. `Update-Theme.ps1` reads local coordinates and applies the theme. `Install.ps1` registers the scheduled task, `Run-Hidden.vbs` runs the theme updater without a console window, and `Uninstall.ps1` removes it. `Test.ps1` covers schedule behavior. User setup is documented in `README.md`.

## Development Commands

Use Windows PowerShell 5.1 from the repository root. The project runs directly from source. Scheduled execution requires VBScript.

- `.\Test.ps1` runs the schedule tests without installing a task or changing the Windows theme.
- `.\Install.ps1 -Latitude 55.7558 -Longitude 37.6173` configures example coordinates for Moscow, registers the current-user task, and starts it immediately.
- `.\Update-Theme.ps1 -Preview` displays the current schedule in local time after coordinates are configured.
- `.\Uninstall.ps1` stops and removes the scheduled task.

## Coding Style

Use four-space indentation in PowerShell, Verb-Noun function names such as `Get-ThemeSchedule`, and descriptive variables such as `$utcMidnight`. Reference sibling scripts and configuration through `$PSScriptRoot` so scheduled runs work from any working directory. Keep time calculations in `Solar.ps1` and Windows registry or task operations in the scripts that own those side effects.

## Testing

Use the existing `Assert-Equal` helper in `Test.ps1`. Give each assertion a short, descriptive scenario name and use fixed dates with explicit UTC offsets. Preserve coverage around sunrise, the evening cutoff, polar conditions, and UTC date boundaries. For changes to installation or theme application, also verify task registration, preview output, and removal on Windows.

## Commits and Pull Requests

Use short imperative subjects, following examples such as `Add background Windows theme switching by sunrise and sunset`. Explain the user-visible change and how you verified it. Link relevant issues and include screenshots when they demonstrate a visual change. Keep `location.json` local and exclude personal coordinates from commits and screenshots.

# Ramizom System Health Toolkit

> This project was mainly generated with AI under human direction. It may still
> contain mistakes. Please review and test the code before using or distributing
> it.

A small Flutter application for viewing Windows system information and using a
few common settings and repair tools.

| Item | Details |
| --- | --- |
| Version | 7.0.0 |
| Platform | Windows |
| Publisher | Ching-kai Huang |
| Website | [Ramizom.com](https://ramizom.com) |
| Privacy policy | [ramizom.com/privacy](https://ramizom.com/privacy) |

## What's the goal of this project?

To make some Windows health information easier to find and read.

## What problem does this project solve?

Windows system information is spread across several pages and tools. This
application puts a selection of that information in one place.

## Why did I develop it?

I wanted a simple desktop tool for checking a Windows computer without opening
many separate system utilities.

## Who is the target user?

Regular Windows users who want a basic overview of their computer. It is not a
replacement for professional diagnostic or repair software.

## What are the use cases?

- View CPU, memory, graphics, and system-drive usage.
- Read battery capacity, health, cycle count, and history.
- View available disk health and usage data.
- Open common Windows privacy settings.
- Open common Windows Settings pages.
- Pause or resume Windows Update.
- Refresh network components or the Windows icon cache.

## Functions and tutorial

```text
Home         System overview
Battery      Battery report and history
Disk Health  Drive information
Recommend    Suggestions, privacy settings, and tools
Settings     Theme, language, and refresh rate
```

On a narrow window, navigation moves to the bottom and some pages appear under
**More**.

### Home

View the basic system summary and open related Windows Settings pages.

### Battery

Open **Battery** and wait for Windows to generate a report. The app reads its
capacity and history data, then removes the temporary file.

```text
Open Battery
     |
     v
Windows creates battery-report.html
     |
     v
The app reads and displays the report, then removes it
```

Some batteries do not provide a cycle count or complete history.

### Disk Health

Choose a drive and review the values provided by Windows. Some drives and USB
enclosures provide only limited information.

### Recommend

This page shows basic suggestions, shortcuts to Windows location, camera,
microphone, and device-encryption settings, and the following tools:

| Tool | Action |
| --- | --- |
| Pause updates | Pauses Windows updates until September 5, 2042 |
| Resume updates | Restores the previous update values when available |
| Repair network | Turns off app and WinHTTP proxies, flushes DNS, and resets Winsock |
| Repair icons | Refreshes the Windows icon cache |
| Repair system files | Runs SFC /scannow |
| Repair Windows image | Runs DISM /Online /Cleanup-Image /RestoreHealth |
| Scan system disk | Runs CHKDSK /scan on the Windows drive; requires NTFS |
| Flush DNS cache | Clears cached DNS answers without modifying network/proxy settings |
| Clean component store | Runs DISM /StartComponentCleanup; does not use ResetBase |

Read the confirmation before running a tool. Network repair may require a
restart.
SFC and DISM can take several minutes; wait for completion. A successful DISM
exit code of 3010 is reported as requiring restart. Failures show the exit code;
Windows diagnostic logs are in `%SystemRoot%\Logs\CBS\CBS.log` and
`%SystemRoot%\Logs\DISM\dism.log`. This application never restarts automatically.

### Settings

Change the theme, accent color, language, and Home refresh interval. With
**Use system setting**:

- Simplified Chinese Windows locales use Simplified Chinese.
- Other locales, including Traditional Chinese, use English.

## Data and permissions

The app reads local data through PowerShell, CIM, `powercfg`, and Windows
storage interfaces. It has no telemetry or online account system.

Most checks and privacy shortcuts are read-only. Update and repair tools change
Windows settings and may require administrator permission. Read the confirmation
shown by the app before running them.

## Build

Requirements:

- Flutter with a Dart 3.11 compatible toolchain
- Visual Studio with **Desktop development with C++**

Run:

```powershell
flutter pub get
flutter run -d windows
```

Test and build:

```powershell
flutter analyze
flutter test
flutter build windows --release
```

The release build is placed in `build\windows\x64\runner\Release`. Local builds
are not automatically code-signed.

Create a Microsoft Store upload package with:

```powershell
dart run msix:create
```

The generated package is written under `build\msix` and is intentionally ignored
by Git. The package identity in `pubspec.yaml` belongs to the Microsoft Store
listing and should only be changed when publishing under a different listing.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a change. Security
problems should be reported using the process in [SECURITY.md](SECURITY.md).

## License

This project is licensed under the [MIT License](LICENSE).

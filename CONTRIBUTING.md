# Contributing

Thank you for helping improve Ramizom System Health Toolkit.

## Before making a change

- Keep the interface understandable for people who are not familiar with Windows administration.
- Update both English and Simplified Chinese text when changing user-facing content.
- Do not add telemetry, credentials, signing certificates, generated packages, or device-specific reports.
- Treat commands that change Windows settings as sensitive. Show a clear confirmation, use the narrowest command possible, and report failures to the user.
- Do not run maintenance commands on a contributor's computer as part of automated tests.

## Validate a change

Run the checks that apply to your change:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

When changing an elevated Windows command, review the exact command and test its parsing and user-facing flow without executing the command itself.

## Pull requests

Describe the user-visible behavior, affected Windows versions, and the checks you ran. Keep unrelated changes in separate pull requests.

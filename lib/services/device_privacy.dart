/// Scripts use PnP device state, not application permission preferences.
/// Record only devices changed by us, in the administrator-owned registry.
class DevicePrivacy {
  static const functions = r'''
function Get-PrivacyDevices($kind) {
  $devices = @(Get-PnpDevice -PresentOnly -ErrorAction Stop)
  if ($kind -eq 'camera') {
    return @($devices | Where-Object {
      if ($_.Class -eq 'Camera') { return $true }
      if ($_.Class -ne 'Image') { return $false }
      # Some image devices (for example scanners) have no device-service
      # property. They are not cameras and must not make this operation fail.
      $service = Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName 'DEVPKEY_Device_Service' -ErrorAction SilentlyContinue
      return $null -ne $service -and $service.Data -eq 'usbvideo'
    })
  }
  # Match capture endpoint GUIDs, never localized names or speaker devices.
  $capturePath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Capture'
  $ids = @()
  if (Test-Path $capturePath) {
    $ids = @(Get-ChildItem $capturePath -ErrorAction Stop | ForEach-Object { $_.PSChildName })
  }
  return @($devices | Where-Object {
    $_.Class -eq 'AudioEndpoint' -and ($ids -contains ($_.InstanceId -replace '^.*\.(\{[^}]+\})$', '$1'))
  })
}
function Test-Disabled($device) {
  return [int](Get-PnpDeviceProperty -InstanceId $device.InstanceId -KeyName 'DEVPKEY_Device_ProblemCode' -ErrorAction Stop).Data -eq 22
}
function Set-PrivacyDevices($kind, $disable) {
  $path = "HKLM:\SOFTWARE\SystemHealthToolkit\DeviceBackup\$kind"
  New-Item -Path $path -Force | Out-Null
  if ($disable) {
    foreach ($device in @(Get-PrivacyDevices $kind)) {
      if (Test-Disabled $device) { continue }
      $name = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($device.InstanceId))
      Disable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction Stop
      if (-not (Test-Disabled $device)) { throw 'Device disable requires restart or failed' }
      # Record ownership only after this tool has confirmed the state change.
      # A failed disable must never cause a later restore to enable a device
      # that the user or another administrator disabled independently.
      try {
        New-ItemProperty -Path $path -Name $name -Value $device.InstanceId -PropertyType String -Force | Out-Null
      } catch {
        # Do not leave a disabled device without a recoverable ownership record.
        Enable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
        if (Test-Disabled $device) { throw 'Device was disabled but could not be recorded or restored' }
        throw
      }
    }
  } else {
    $key = Get-Item $path
    foreach ($name in $key.GetValueNames()) {
      $id = [string]$key.GetValue($name)
      $device = Get-PnpDevice -InstanceId $id -ErrorAction Stop
      if (Test-Disabled $device) {
        Enable-PnpDevice -InstanceId $id -Confirm:$false -ErrorAction Stop
        if (Test-Disabled $device) { throw 'Device restore requires restart or failed' }
      }
      Remove-ItemProperty -Path $path -Name $name -ErrorAction Stop
    }
  }
}
function Test-PrivacyDevices($kind) {
  $devices = @(Get-PrivacyDevices $kind)
  if ($devices.Count -eq 0) { return $false }
  foreach ($device in $devices) {
    if (-not (Test-Disabled $device)) { return $false }
  }
  return $true
}
''';
}

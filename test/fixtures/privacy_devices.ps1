# In-memory doubles: this fixture never calls Windows device/registry cmdlets.
$script:values = @{}
$script:disabled = @()
$script:enabled = @()
$script:problems = @{ 'audio.{MIC}' = 0; 'audio.{OFF}' = 22; 'audio.{SPEAKER}' = 0; 'camera' = 0; 'scanner' = 0 }
$script:devices = @(
  [pscustomobject]@{ InstanceId = 'audio.{MIC}'; Class = 'AudioEndpoint' },
  [pscustomobject]@{ InstanceId = 'audio.{OFF}'; Class = 'AudioEndpoint' },
  [pscustomobject]@{ InstanceId = 'audio.{SPEAKER}'; Class = 'AudioEndpoint' },
  [pscustomobject]@{ InstanceId = 'camera'; Class = 'Camera' },
  [pscustomobject]@{ InstanceId = 'scanner'; Class = 'Image' }
)
function Get-PnpDevice {
  [CmdletBinding()] param([switch]$PresentOnly, [string]$InstanceId)
  if ($InstanceId) { return $script:devices | Where-Object InstanceId -eq $InstanceId }
  return $script:devices
}
function Get-PnpDeviceProperty {
  [CmdletBinding()] param($InstanceId, $KeyName)
  if ($KeyName -eq 'DEVPKEY_Device_Service') { return [pscustomobject]@{ Data = 'scanner' } }
  return [pscustomobject]@{ Data = $script:problems[$InstanceId] }
}
function Test-Path { param($Path) return $true }
function Get-ChildItem {
  [CmdletBinding()] param($Path)
  return @([pscustomobject]@{ PSChildName = '{MIC}' }, [pscustomobject]@{ PSChildName = '{OFF}' })
}
function New-Item { [CmdletBinding()] param($Path, [switch]$Force) }
function New-ItemProperty {
  [CmdletBinding()] param($Path, $Name, $Value, $PropertyType, [switch]$Force)
  $script:values[$Name] = $Value
}
function Disable-PnpDevice {
  [CmdletBinding(SupportsShouldProcess)] param($InstanceId)
  $script:disabled += $InstanceId
  $script:problems[$InstanceId] = 22
}
function Enable-PnpDevice {
  [CmdletBinding(SupportsShouldProcess)] param($InstanceId)
  $script:enabled += $InstanceId
  $script:problems[$InstanceId] = 0
}
function Get-Item {
  param($Path)
  $key = [pscustomobject]@{}
  $key | Add-Member ScriptMethod GetValueNames { return @($script:values.Keys) }
  $key | Add-Member ScriptMethod GetValue { param($Name) return $script:values[$Name] }
  return $key
}
function Remove-ItemProperty {
  [CmdletBinding()] param($Path, $Name)
  $script:values.Remove($Name)
}
Set-PrivacyDevices microphone $true
if ($script:disabled.Count -ne 1 -or $script:disabled[0] -ne 'audio.{MIC}') { throw 'Disabled a speaker or pre-disabled device' }
if (-not (Test-PrivacyDevices microphone)) { throw 'Disabled endpoints not recognized' }
Set-PrivacyDevices microphone $true
if ($script:disabled.Count -ne 1) { throw 'Repeated protection is not idempotent' }
Set-PrivacyDevices microphone $false
if ($script:enabled.Count -ne 1 -or $script:enabled[0] -ne 'audio.{MIC}') { throw 'Restored a device we did not disable' }
if ($script:problems['audio.{OFF}'] -ne 22) { throw 'Changed pre-disabled device' }
if (Test-PrivacyDevices microphone) { throw 'Active endpoint falsely reported protected' }
Set-PrivacyDevices camera $true
if ($script:disabled[-1] -ne 'camera' -or $script:problems['scanner'] -ne 0) { throw 'Camera selection included scanner' }
$script:devices = @()
if (Test-PrivacyDevices microphone) { throw 'No microphone falsely reported protected' }
Write-Output 'PASS'

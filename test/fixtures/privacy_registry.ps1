# Shadow every registry operation with an in-memory implementation.
$script:registry = @{}
function New-Item { [CmdletBinding()] param($Path, [switch]$Force) }
function Get-ItemProperty {
  [CmdletBinding()] param($Path, $Name)
  $key = "$Path|$Name"
  if (-not $script:registry.ContainsKey($key)) {
    if ($ErrorActionPreference -eq 'Stop') { throw 'Missing value' }
    return $null
  }
  return [pscustomobject]@{ $Name = $script:registry[$key] }
}
function Set-ItemProperty {
  [CmdletBinding()] param($Path, $Name, $Type, $Value)
  $script:registry["$Path|$Name"] = $Value
}
function Remove-ItemProperty {
  [CmdletBinding()] param($Path, $Name)
  $script:registry.Remove("$Path|$Name")
}

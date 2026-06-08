$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-JsonLine {
  param([Parameter(Mandatory = $true)] [object] $Value)
  $Value | ConvertTo-Json -Compress -Depth 8
  [Console]::Out.Flush()
}

Write-JsonLine @{
  type = "ready"
  pid = $PID
  cwd = (Get-Location).Path
  shell = "Windows PowerShell $($PSVersionTable.PSVersion)"
  computerName = $env:COMPUTERNAME
}

while ($null -ne ($line = [Console]::In.ReadLine())) {
  $command = $line.Trim()
  if ($command -eq "") {
    continue
  }
  if ($command -eq ":quit" -or $command -eq ":exit") {
    Write-JsonLine @{ type = "bye" }
    break
  }

  $started = Get-Date
  $global:LASTEXITCODE = $null
  $Error.Clear()

  try {
    $scriptBlock = [scriptblock]::Create($line)
    $raw = . $scriptBlock 2>&1
    $success = $?
    $stdout = @()
    $stderr = @()
    foreach ($item in @($raw)) {
      if ($item -is [System.Management.Automation.ErrorRecord]) {
        $stderr += $item.ToString()
      } else {
        $stdout += (($item | Out-String).TrimEnd())
      }
    }
    $durationMs = [int]((Get-Date) - $started).TotalMilliseconds
    Write-JsonLine @{
      type = "result"
      ok = ($success -and $stderr.Count -eq 0 -and ($null -eq $global:LASTEXITCODE -or $global:LASTEXITCODE -eq 0))
      command = $line
      cwd = (Get-Location).Path
      exitCode = $global:LASTEXITCODE
      durationMs = $durationMs
      stdout = $stdout
      stderr = $stderr
    }
  } catch {
    $durationMs = [int]((Get-Date) - $started).TotalMilliseconds
    Write-JsonLine @{
      type = "result"
      ok = $false
      command = $line
      cwd = (Get-Location).Path
      exitCode = $global:LASTEXITCODE
      durationMs = $durationMs
      stdout = @()
      stderr = @($_.Exception.Message)
    }
  }
}


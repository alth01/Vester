#requires -Modules Pester
#requires -Modules VMware.VimAutomation.Core

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true,Position = 0,HelpMessage = 'Remediation toggle')]
    [ValidateNotNullorEmpty()]
    [switch]$Remediate
)

Process {
# Configuration
Invoke-Expression -Command (Get-Item -Path ($PSScriptRoot + '\Config.ps1'))
[array]$esxntp = $global:config.host.esxntp

# Tests
Describe -Name 'Host Configuration: NTP Server(s)' -Fixture {
    foreach ($server in (Get-VMHost)) 
    {
        It -name "$($server.name) Host NTP settings" -test {
            $value = Get-VMHostNtpServer -VMHost $server
            try 
            {
                Compare-Object -ReferenceObject $esxntp -DifferenceObject $value | Should Be $null
            }
            catch 
            {
                if ($Remediate) 
                {
                    Write-Warning -Message $_
                    Write-Warning -Message "Remediating $server"
                    Get-VMHostNtpServer -VMHost $server | ForEach-Object -Process {
                        Remove-VMHostNtpServer -VMHost $server -NtpServer $_ -Confirm:$false -ErrorAction Stop
                    }
                    Add-VMHostNtpServer -VMHost $server -NtpServer $esxntp -ErrorAction Stop
                    $ntpclient = Get-VMHostService -VMHost $server | Where-Object -FilterScript {
                        $_.Key -match 'ntpd'
                    }
                    $ntpclient | Set-VMHostService -Policy:On -Confirm:$false -ErrorAction:Stop
                    $ntpclient | Restart-VMHostService -Confirm:$false -ErrorAction:Stop
                }
                else 
                {
                    throw $_
                }
            }
        }
    }
}
}
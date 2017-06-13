


import-module ACMESharp

# Loading logging functions
$ScriptPath = Split-Path -parent $PSCommandPath
. "$ScriptPath\EmailLogging.ps1"

#
# Script parameters
#

$domain = "example.com"
$alias = "example"
$certname = "example-$(get-date -format yyyy-MM-dd--HH-mm)"
$PSEmailServer = "mail.com"
$LocalEmailAddress = "acme@example.com"
$OwnerEmailAddress = "admin@example.com"

$ErrorActionPreference = "Stop"

Try {
    Write-Log "Attempting to renew Let's Encrypt certificate for $domain"

    # Generate a certificate
    Write-Log "Generating certificate for $alias"
    New-ACMECertificate $alias -Generate -Alias $certname

    # Submit the certificate
    Submit-ACMECertificate $certname

    # Check the status of the certificate every 6 seconds until we have an answer; fail after a minute
    $i = 0
    do {
        $certinfo = Update-AcmeCertificate $certname
        if($certinfo.SerialNumber -ne "") {
        Start-Sleep 6
        $i++
        }
    } until($certinfo.SerialNumber -ne "" -or $i -gt 10)

    if($i -gt 10) {
        Write-Log "We did not receive a completed certificate after 60 seconds"
        Send-Log -From $LocalEmailAddress -To $OwnerEmailAddress -Subject "Attempting to renew Let's Encrypt certificate for $domain" -EmailServer $PSEmailServer
        Exit
    }

    # Export Certificate to Grafana and restart service
    Write-Log "Exporting certificate"
    Get-ACMECertificate $certname -ExportKeyPEM $KeyPath `
        -ExportCertificatePEM $CertPath -Overwrite
    Write-Log "Export Completed"



    # Finished
    Write-Log "Finished"
    Send-Log -From $LocalEmailAddress -To $OwnerEmailAddress -Subject "Let's Encrypt certificate renewed for $domain" -EmailServer $PSEmailServer

} Catch {
    Write-Host $_.Exception
    $ErrorMessage = $_.Exception | format-list -force | out-string
    Write-Log "Let's Encrypt certificate renewal for $domain failed with exception`n$ErrorMessage`r`n`r`n"
    Send-Log -From $LocalEmailAddress -To $OwnerEmailAddress -Subject "Let's Encrypt certificate renewal for $domain failed with exception" -EmailServer $PSEmailServer
    return
}
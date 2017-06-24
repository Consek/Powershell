<#
    .SYNOPSIS
    Creates and exports LetsEncrypt certificate.

    .DESCRIPTION
    Automates the process of requesting and exporting LetsEncrypt certificate
    along with Vault and Registration creation.

    .PARAMETER Email
    Email address used for Registration to LetsEncrypt CA when no registration
    is present.

    .PARAMETER CertDNSName
    DNS name which will be on the certificate.

    .PARAMETER CertAlias
    Alias used for certificate creation. Use a new alias to create new certificate
    otherwise already existing cert will be exported.

    .PARAMETER KeyPath
    Path where cert key should be exported. Existing file will be overwritten.

    .PARAMETER CertPemPath
    Path where cert should be exported in PEM format. Existing file will be overwritten.

    .PARAMETER CertPkcs12Path
    Path where cert should be exported in Pkcs12 format. Existing file will be overwritten.

    .EXAMPLE
    .\Create-ACMECertificate.ps1 -Email example@example.com -CertDNSName example.com

    Creates certificate for example.com FQDN. Cert can be exported later with Get-ACMECertificate.

    .EXAMPLE
    .\Create-ACMECertificate.ps1 -Email example@example.com -CertDNSName example.com -CertPkcs12Path .\cert.pfx
    
    Creates certificate for example.com FQDN and exports it to current working directory.

    .NOTES
    Dependencies:
    ACMESharp Module (https://github.com/ebekker/ACMESharp)

    .LINK
    https://github.com/ebekker/ACMESharp
#>
param(
    [Parameter(Mandatory=$true)]
    $Email,
    [Parameter(Mandatory=$true)]
    $CertDNSName,
    $CertAlias = "cert-$(get-date -format yyyy-MM-dd--HH-mm-ss)",
    $KeyPath,
    $CertPemPath,
    $CertPkcs12Path
)

Import-Module ACMESharp -EA STOP

# ACMESharp Module does not support EA SilentlyContinue hence try catch blocks

$Vault = Get-ACMEVault

if(-not $Vault){
    Initialize-ACMEVault | Out-Null
}

try{ 
    $Registration = Get-ACMERegistration -EA SilentlyContinue
    Update-ACMERegistration -Contacts "mailto:$Email" | Out-Null
    Write-Host "ACME Registration updated."
}catch{}

if(-not $Registration){
    Write-Host "No ACME Registration detected. Creating new."
    New-ACMERegistration -Contacts "mailto:$Email" -AcceptTOS | Out-Null
}

try{ 
    
    $Identifiers = Get-ACMEIdentifier | Where-Object { $_.Dns -eq $CertDNSName }
    $Identifiers = $Identifiers | 
        ForEach-Object { 
            $Alias = $_.Alias
            Update-ACMEIdentifier -IdentifierRef $_.Alias | Add-Member Alias $Alias -PassThru
        }
    $Identifiers = $Identifiers | 
        Where-Object { $_.Status -eq "Valid" -or $_.Status -eq "Pending" }
    $Identifiers = $Identifiers |
        Where-Object { $_.Challenges | Where-Object {$_.Type -eq "dns-01" -and $_.Status -ne "Invalid"} }
    $Identifier = $Identifiers | Sort-Object -Descending Status | Select-Object -First 1
    $IdentifierAlias = $Identifier.Alias
    if($Identifier){
        Write-Host "ACME identifier $IdentifierAlias will be used."
    }else{
        throw "Error"
    }
    
}catch{
    Write-Host "No ACME identifier detected, creating new."
    $IdentifierAlias = "identifier-$(get-date -format yyyy-MM-dd--HH-mm-ss)"
    $Identifier = New-ACMEIdentifier -Dns $CertDNSName -Alias $IdentifierAlias
}

if($Identifier.Status -ne "valid"){

    $Handler = $Identifier.Challenges | Where-Object { $_.Type -eq "dns-01" }

    if($Handler.Status -eq "invalid"){
        Write-Host "DNS challenge is in invalid state. Run script again with different IdentifierAlias." -ForegroundColor Red
        return 
    }

    if(-not $Handler.HandlerHandleDate){
        Write-Host "No challenge detected, creating new one."
        Write-Host "Complete steps listed below to finish challenge."
        Complete-ACMEChallenge $IdentifierAlias -ChallengeType dns-01 -Handler manual
    }elseif(-not $Handler.SubmitDate){
        Write-Host "Challenge detected."
        Write-Host "Complete steps listed below to finish challenge."
        Complete-ACMEChallenge $IdentifierAlias -ChallengeType dns-01 -Handler manual -Repeat
    }

    if(-not $Handler.SubmitDate){
        Write-Host "Submit challenge only when dns entry is created and propagated. " +
            "If not, the challange will fail and new IdentifierAlias will have to be used." -ForegroundColor Yellow
        $choice = ''
        while ($choice -notmatch "^(y|n)$") {
            Write-Host "Do you want to submit challenge? (Y/N)"
            $choice = Read-Host
        }
        if($choice -eq 'y'){
            Write-Host "Submitting challenge."
            Submit-ACMEChallenge -IdentifierRef $IdentifierAlias -ChallengeType dns-01 | Out-Null
        }else{
            return
        }
    }else{
        Write-Host "Challenge already submitted."
    }

    Write-Host "Checking results..."
    $i = 0
    do{
        $i += 5
        Start-Sleep -Seconds 5
        $Handler = Update-ACMEIdentifier -IdentifierRef $IdentifierAlias -ChallengeType dns-01 | 
        Select-Object -ExpandProperty Challenges | Where-Object {$_.Type -eq "dns-01"}
    }while($Handler.Status -eq "pending" -and $i -le 60)


    if($Handler.Status -eq "Pending"){
        Write-Host "Challege is still pending after a minute. Wait some time and rerun the script."
        return 
    }elseif($Handler.Status -eq "invalid"){
        Write-Host "Challenge is in invalid state, the procedure needs to be repeated. Rerun the script with new IdentifierAlias."
        return 
    }elseif($Handler.Status -eq "valid"){
        Write-Host "Challenge completed successfuly."
    }

}else{
    Write-Host "Challenge already completed successfuly."
}

try{
    $cert = Get-ACMECertificate | Where-Object { $_.Alias -eq $CertAlias }
    if(-not $cert){
        throw "Error"
    }
}catch{
    Write-Host "Creating and submitting certificate with alias: $CertAlias."
    New-ACMECertificate -IdentifierRef $IdentifierAlias -Alias $CertAlias -Generate | Out-Null
    Submit-ACMECertificate -CertificateRef $CertAlias | Out-Null
}

$i = 0
while((Update-ACMECertificate -CertificateRef $CertAlias).SerialNumber -eq ""){
    if($i -gt 60){
        Write-Host "Certificate was not issued for a minute. Wait some time and rerun the script."
        return
    }
    $i += 5
    Start-Sleep -Seconds 5
}



if($CertPemPath){
    Write-Host "Exporting certificate PEM file."
    Get-ACMECertificate $CertAlias -ExportCertificatePEM $KeyPath -Overwrite | Out-Null    
}
if($CertPkcs12Path){
    Write-Host "Exporting certificate Pkcs12 file."
    Get-ACMECertificate $CertAlias -ExportPkcs12 $KeyPath -Overwrite | Out-Null    
}
if($CertKeyPath){
    Write-Host "Exporting certificate Key file."
    Get-ACMECertificate $CertAlias -ExportKeyPEM $KeyPath -Overwrite | Out-Null    
}
Write-Host "Export Completed"




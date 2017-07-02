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
    https://github.com/Consek/Powershell
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
    $CertPkcs12Path,
    [Parameter(Mandatory=$true)]
    [ValidateSet('dns-01','http-01')]
    $ChallengeType
)

Import-Module ACMESharp -EA STOP

#### ACMESharp Module does not support EA SilentlyContinue hence try catch blocks

## Get existing vault and create new one if there is none
$Vault = Get-ACMEVault
if(-not $Vault){
    Initialize-ACMEVault | Out-Null
}

## Get existing registration and update email contact, create new one if none present
try{ 
    $Registration = Get-ACMERegistration 
    Update-ACMERegistration -Contacts "mailto:$Email" | Out-Null
    Write-Host "ACME Registration updated."
}catch{}
if(-not $Registration){
    Write-Host "No ACME Registration detected. Creating new."
    New-ACMERegistration -Contacts "mailto:$Email" -AcceptTOS | Out-Null
}

try{ 

    ## Get already existing identifiers for CertDNSName and Update each to get full info
    $Identifiers = Get-ACMEIdentifier | Where-Object { $_.Dns -eq $CertDNSName }
    $Identifiers = $Identifiers | 
        ForEach-Object { 
            $Alias = $_.Alias
            Update-ACMEIdentifier -IdentifierRef $_.Alias -ChallengeType $ChallengeType | 
                Add-Member Alias $Alias -PassThru
        }
    
    ## Filter invalid identifiers and sort them so that valid are first
    $Identifiers = $Identifiers | 
        Where-Object { $_.Status -eq "Valid" -or $_.Status -eq "Pending" } |
        Sort-Object -Descending Status

    ## If at least one is valid challange check can be skipped 
    if($Identifiers[0].Status -ne "Valid"){
        $Identifiers = $Identifiers |
            Where-Object { $_.Challenges | Where-Object {$_.Type -eq "$ChallengeType" -and $_.Status -ne "Invalid"} }
    }

    ## Select first identifier if none present then throw error so new one can be created
    $Identifier = $Identifiers | Select-Object -First 1
    $IdentifierAlias = $Identifier.Alias
    if($Identifier){
        Write-Host "ACME identifier $IdentifierAlias will be used."
    }else{
        throw "Error"
    }
    
}catch{

    ## Create new identifier
    Write-Host "No usable ACME identifier detected, creating new."
    $IdentifierAlias = "identifier-$(get-date -format yyyy-MM-dd--HH-mm-ss)"
    $Identifier = New-ACMEIdentifier -Dns $CertDNSName -Alias $IdentifierAlias
}

## If identifier is not already valid then perform dns challange
if($Identifier.Status -ne "valid"){

    ## Get dns challenge for later use
    $Handler = $Identifier.Challenges | Where-Object { $_.Type -eq "$ChallengeType" }

    ## List challenge acceptance requirements by completing challenge 
    ## If required because -Repeat argument cannot always be used
    if(-not $Handler.HandlerHandleDate){
        Write-Host "No challenge detected, creating new one."
        Complete-ACMEChallenge $IdentifierAlias -ChallengeType $ChallengeType -Handler manual -Regenerate
    }elseif(-not $Handler.SubmitDate){
        Write-Host "Challenge detected."
        Complete-ACMEChallenge $IdentifierAlias -ChallengeType $ChallengeType -Handler manual -Repeat
    }

    ## Asks for confirmation before submitting challenge
    if(-not $Handler.SubmitDate){
        Write-Host "Complete steps listed above to finish challenge." -ForegroundColor Yellow
        Write-Host -ForegroundColor Yellow -Object ("Submit challenge only when dns entry is created and propagated. " +
            "If not, the challange will fail and new IdentifierAlias will have to be used.")
        $choice = ''
        while ($choice -notmatch "^(y|n)$") {
            Write-Host "Do you want to submit challenge? (Y/N)"
            $choice = Read-Host
        }
        if($choice -eq 'y'){
            Write-Host "Submitting challenge."
            Submit-ACMEChallenge -IdentifierRef $IdentifierAlias -ChallengeType $ChallengeType | Out-Null
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
        $Handler = Update-ACMEIdentifier -IdentifierRef $IdentifierAlias -ChallengeType $ChallengeType | 
            Select-Object -ExpandProperty Challenges | Where-Object {$_.Type -eq "$ChallengeType"}
    }while($Handler.Status -eq "pending" -and $i -le 60)

    if($Handler.Status -eq "Pending"){
        Write-Host "Challege is still pending after a minute. Wait some time and rerun the script."
        return 
    }elseif($Handler.Status -eq "invalid"){
        Write-Error "Challenge is in invalid state, the procedure needs to be repeated. Rerun the script with new IdentifierAlias."
        return 
    }elseif($Handler.Status -eq "valid"){
        Write-Host "Challenge completed successfuly."
    }

}else{
    Write-Host "Challenge already completed successfuly."
}

Write-Host "Creating and submitting certificate with alias: $CertAlias."
New-ACMECertificate -IdentifierRef $IdentifierAlias -Alias $CertAlias -Generate | Out-Null
Submit-ACMECertificate -CertificateRef $CertAlias | Out-Null

## Wait for certificate, stop script after minute of waiting
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
    Get-ACMECertificate $CertAlias -ExportCertificatePEM $CertPemPath -Overwrite | Out-Null    
}
if($CertPkcs12Path){
    Write-Host "Exporting certificate Pkcs12 file."
    Get-ACMECertificate $CertAlias -ExportPkcs12 $CertPkcs12Path -Overwrite | Out-Null    
}
if($CertKeyPath){
    Write-Host "Exporting certificate Key file."
    Get-ACMECertificate $CertAlias -ExportKeyPEM $KeyPath -Overwrite | Out-Null    
}





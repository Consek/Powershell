<#
    .NOTES
    Dependencies:
    ACMESharp Module (https://github.com/ebekker/ACMESharp)
    Email logging.ps1

    .LINK
    https://github.com/ebekker/ACMESharp
#>
param(
    $Email = "example@example.com",
    $CertDNSName = "example.com",
    [Parameter(Mandatory=$false)]
    $IdentfierAlias = "identifier-$(get-date -format yyyy-MM-dd--HH-mm-ss)",
    [Parameter(Mandatory=$false)]
    $CertAlias = "cert-$(get-date -format yyyy-MM-dd--HH-mm-ss)",
    $KeyPath,
    $CertPath
)

Import-Module ACMESharp -EA STOP

$Vault = Get-ACMEVault

if(-not $Vault){
    Initialize-ACMEVault | Out-Null
}

#Get-ACMERegistration does not support EA SilentlyContinue hence try catch block
try{ 
    $Registration = Get-ACMERegistration -EA SilentlyContinue
    Write-Host "ACME Registration detected."
}catch{}

if(-not $Registration){
    Write-Host "No ACME Registration detected. Creating new."
    New-ACMERegistration -Contacts mailto:$Email -AcceptTOS | Out-Null
}

try{ 
    $Identifier = Get-ACMEIdentifier -IdentifierRef $IdentfierAlias
    if($Identifier.Dns -eq $CertDNSName){
        Write-Host "ACME identifier present."
    }else{
        Write-Host "ACME identifier present for different CertDNSName, rerun script with new CertIdentifier."
        return
    }

}catch{
    Write-Host "No ACME identifier detected, creating new."
    $Identifier = New-ACMEIdentifier -Dns $CertDNSName -Alias $IdentfierAlias
}

if($Identifier.Status -ne "valid"){

    $Handler = $Identifier.Challenges | Where-Object { $_.Type -eq "dns-01" }

    if($Handler.Status -eq "invalid"){
        Write-Host "DNS challenge is in invalid state. Run script again with different IdentfierAlias." -ForegroundColor Red
        return 
    }

    if(-not $Handler.HandlerHandleDate){
        Write-Host "No challenge detected, creating new one."
        Write-Host "Complete steps listed below to finish challenge."
        Complete-ACMEChallenge $IdentfierAlias -ChallengeType dns-01 -Handler manual
    }elseif(-not $Handler.SubmitDate){
        Write-Host "Challenge detected."
        Write-Host "Complete steps listed below to finish challenge."
        Complete-ACMEChallenge $IdentfierAlias -ChallengeType dns-01 -Handler manual -Repeat
    }

    if(-not $Handler.SubmitDate){
        Write-Host "Submit challenge only when dns entry is created and propagated. 
        If not, the challange will fail and new IdentfierAlias will have to be used." -ForegroundColor Yellow
        $choice = ''
        while ($choice -notmatch "^(y|n)$") {
            Write-Host "Do you want to submit challenge? (Y/N)"
            $choice = Read-Host
        }
        if($choice -eq 'y'){
            Write-Host "Submitting challenge."
            Submit-ACMEChallenge -IdentifierRef $IdentfierAlias -ChallengeType dns-01 | Out-Null
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
        $Handler = Update-ACMEIdentifier -IdentifierRef $IdentfierAlias -ChallengeType dns-01 | 
        Select-Object -ExpandProperty Challenges | Where-Object {$_.Type -eq "dns-01"}
    }while($Handler.Status -eq "pending" -and $i -le 60)


    if($Handler.Status -eq "Pending"){
        Write-Host "Challege is still pending after a minute. Wait some time and rerun the script."
        return 
    }elseif($Handler.Status -eq "invalid"){
        Write-Host "Challenge is in invalid state, the procedure needs to be repeated. Rerun the script with new IdentfierAlias."
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
    Write-Host "Creating and submitting certificate."
    New-ACMECertificate -IdentifierRef $IdentfierAlias -Alias $CertAlias -Generate | Out-Null
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


Write-Host "Exporting certificate"
Get-ACMECertificate $CertAlias -ExportKeyPEM $KeyPath -ExportCertificatePEM $CertPath -Overwrite | Out-Null
Write-Host "Export Completed"




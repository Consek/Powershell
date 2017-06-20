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
    $CertAlias = "example"
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
    $Identifier = Get-ACMEIdentifier -IdentifierRef $CertAlias
    Write-Host "ACME identifier present."
}catch{
    Write-Host "No ACME identifier detected, creating new."
    $Identifier = New-ACMEIdentifier -Dns $CertDNSName -Alias $CertAlias
    Write-Host "Complete steps listed below to finish challenge." -ForegroundColor Yellow
    Complete-ACMEChallenge $CertAlias -ChallengeType dns-01 -Handler manual
}

if($Identifier.Status -ne "valid"){
    if($Handler.Status -eq "invalid"){
        Write-Host "DNS challenge is in invalid state. Run script again with different CertAlias." -ForegroundColor Red
        return 
    }

    $Handler = $Identifier.Challenges | Where-Object { $_.Type -eq "dns-01" }

    if(-not $Handler.HandlerHandleDate){
        Write-Host "No challenge detected, creating new one."
        Write-Host "Complete steps listed below to finish challenge."
        Complete-ACMEChallenge $CertAlias -ChallengeType dns-01 -Handler manual
    }else{
        Write-Host "Challenge detected."
        Write-Host "Complete steps listed below to finish challenge."
        Complete-ACMEChallenge $CertAlias -ChallengeType dns-01 -Handler manual -Repeat
    }

    if(-not $Handler.SubmitDate){
        Write-Host "Submit challenge only when dns entry is created and propagated. 
        If not, the challange will fail and new CertAlias will have to be used." -ForegroundColor Yellow
        $choice = ''
        while ($choice -notmatch "^(y|n)$") {
            Write-Host "Do you want to submit challenge? (Y/N)"
            $choice = Read-Host
        }
        if($choice -eq 'y'){
            Write-Host "Submitting challenge."
            Submit-ACMEChallenge -IdentifierRef $CertAlias -ChallengeType dns-01
        }else{
            return
        }
    }else{
        Write-Host "Challenge already submitted."
    }

    Write-Host "Checking results..."
    $Handler = Update-ACMEIdentifier -IdentifierRef $CertAlias -ChallengeType dns-01 | 
        Select-Object -ExpandProperty Challenges | Where-Object {$_.Type -eq "dns-01"}

    if($Handler.Status -eq "Pending"){
        Write-Host "Challege is still pending. Wait some time and rerun the script."
        return 
    }elseif($Handler.Status -eq "invalid"){
        Write-Host "Challenge is in invalid state, the procedure needs to be repeated. Rerun the script with new CertAlias."
        return 
    }elseif($Handler.Status -eq "valid"){
        Write-Host "Challenge completed successfuly."
    }

}else{
    Write-Host "Challenge already completed successfuly."
}

try{
    if((Update-ACMEIdentifier -IdentifierRef $CertAlias).Status -eq "valid"){
        Write-Host "Creating and submitting certificate."
        New-ACMECertificate -IdentifierRef $CertAlias -Alias $CertAlias -Generate | Out-Null
        Submit-ACMECertificate -CertificateRef $CertAlias | Out-Null
    }
}catch{
    
}



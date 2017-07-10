<#
    .SYNOPSIS
    Creates and exports LetsEncrypt certificate.

    .DESCRIPTION
    Automates the process of requesting and exporting LetsEncrypt certificate
    along with Vault and Registration creation. Returns Challenge for use by outside
    function and after that, submits challenge for verification.

    .PARAMETER Email
    Email address used for Registration to LetsEncrypt CA when no registration
    is present.

    .PARAMETER CertDNSName
    DNS name which will be on the certificate.

    .PARAMETER ChallengeType
    Accepts only dns-01 and http-01, specifies which kind of challenge will be used for
    domain validation

    .PARAMETER Complete
    Automatically submits challenge for verification, irrelevant after domain is verified and at least
    one non-expired Identifier exists.

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
    $Challenge = New-LECertificate -Email admin@example.com -CertDNSName example.com -ChallengeType http-01 -KeyPath .\key.pem -CertPemPath .\cert.pem
    if($Challenge){
        ### Insert function for creating file on web server using $Challenge ###
        New-LECertificate -Email admin@example.com -CertDNSName example.com -ChallengeType http-01 -Complete -KeyPath .\key.pem -CertPemPath .\cert.pem
    }

    Creates challenge and uses external function to create required file on web server, then challenge is submitted
    and key along with cert are exported to current directory.

    If domain is already verified first function will export key and cert, and no other action will be required.

    .NOTES
    Dependencies:
    ACMESharp Module (https://github.com/ebekker/ACMESharp)

    .LINK
    https://github.com/Consek/Powershell
    https://github.com/ebekker/ACMESharp

    .NOTES
    Use -Verbose for progress output.
#>

function New-LECertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$Email,
        [Parameter(Mandatory=$true)]
        [Alias('DNS')]
        [String]$CertDNSName,
        [Parameter(Mandatory=$true)]
        [ValidateSet('dns-01','http-01')]
        [String]$ChallengeType,
        [Alias('Quiet')]
        [Switch]$Complete,
        [String]$CertAlias = "cert-$(get-date -format yyyy-MM-dd--HH-mm-ss)",
        [String]$KeyPath,
        [String]$CertPemPath,
        [String]$CertPkcs12Path
    )

    Import-Module ACMESharp -EA STOP -Verbose:$false

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
        Write-Verbose "ACME Registration updated."
    }catch{}
    if(-not $Registration){
        Write-Verbose "No ACME Registration detected. Creating new."
        New-ACMERegistration -Contacts "mailto:$Email" -AcceptTOS | Out-Null
    }

    try{ 

        ## Get already existing identifiers for CertDNSName, filter expired and Update each to get full info
        $Identifiers = Get-ACMEIdentifier | Where-Object { $_.Dns -eq $CertDNSName }
        $Identifiers = $Identifiers | 
            ForEach-Object { 
                $Alias = $_.Alias
                Get-ACMEIdentifier -IdentifierRef $_.Alias | 
                    Add-Member Alias $Alias -PassThru
            } | Where-Object { $_.Expires -gt (Get-Date) }
        $Identifiers = $Identifiers | 
            ForEach-Object { 
                $Alias = $_.Alias
                Update-ACMEIdentifier -IdentifierRef $_.Alias | 
                    Add-Member Alias $Alias -PassThru
            }
        
        ## Filter invalid identifiers and sort them so that valid and newest are first
        $Identifiers = $Identifiers | 
            Where-Object { $_.Status -eq "Valid" -or $_.Status -eq "Pending" } |
            Sort-Object -Descending Status,Expires

        ## If at least one is valid challange check can be skipped 
        if($Identifiers[0].Status -ne "Valid"){
            ## Update Challenge information and filter invalid identifiers
            $Identifiers = $Identifiers | 
                ForEach-Object { 
                    $Alias = $_.Alias
                    Update-ACMEIdentifier -IdentifierRef $_.Alias -ChallengeType $ChallengeType | 
                        Add-Member Alias $Alias -PassThru
                } | Where-Object { ($_.Challenges | Where-Object {$_.Type -eq "$ChallengeType" -and $_.Status -ne "Invalid"}) }
        }

        ## Select first identifier if none present then throw error so new one can be created
        $Identifier = $Identifiers | Select-Object -First 1
        $IdentifierAlias = $Identifier.Alias
        if($Identifier){
            Write-Verbose "ACME identifier $IdentifierAlias will be used."
        }else{
            throw "Error"
        }

    }catch{
        ## Create new identifier
        $IdentifierAlias = "identifier-$(get-date -format yyyy-MM-dd--HH-mm-ss)"
        Write-Verbose "No usable ACME identifier detected, creating new with alias $IdentifierAlias."
        $Identifier = New-ACMEIdentifier -Dns $CertDNSName -Alias $IdentifierAlias
    }

    ## If identifier is not already valid then perform challange
    if($Identifier.Status -ne "valid"){
        ## Get dns challenge for later use
        $Handler = $Identifier.Challenges | Where-Object { $_.Type -eq "$ChallengeType" }
        ## List challenge acceptance requirements by completing challenge 
        ## If required because -Repeat argument cannot always be used
        if(-not $Handler.HandlerHandleDate){
            Write-Verbose "No challenge detected, creating new one."
            $Identifier =  Complete-ACMEChallenge $IdentifierAlias -ChallengeType $ChallengeType -Handler manual -Regenerate
        }elseif(-not $Handler.SubmitDate){
            Write-Verbose "Challenge detected."
            $Identifier = Complete-ACMEChallenge $IdentifierAlias -ChallengeType $ChallengeType -Handler manual -Repeat
        }

        if(-not $Complete){
            $Challenge = $Identifier.Challenges | Where-Object { $_.Type -eq $ChallengeType } | 
                Select-Object -ExpandProperty Challenge
            return $Challenge
        }

        ## Asks for confirmation before submitting challenge
        if(-not $Handler.SubmitDate){
            Write-Verbose "Submitting challenge."
            Submit-ACMEChallenge -IdentifierRef $IdentifierAlias -ChallengeType $ChallengeType | Out-Null
        }else{
            Write-Verbose "Challenge already submitted."
        }

        Write-Verbose "Checking results..."
        $i = 0
        do{
            $i += 5
            Start-Sleep -Seconds 5
            $Handler = Update-ACMEIdentifier -IdentifierRef $IdentifierAlias -ChallengeType $ChallengeType | 
                Select-Object -ExpandProperty Challenges | Where-Object {$_.Type -eq "$ChallengeType"}
        }while($Handler.Status -eq "pending" -and $i -le 60)

        if($Handler.Status -eq "Pending"){
            Write-Warning "Challege is still pending after a minute. Wait some time and rerun the script."
            return 
        }elseif($Handler.Status -eq "invalid"){
            Write-Error "Challenge is in invalid state, the procedure needs to be repeated. Rerun the script with new IdentifierAlias."
            return 
        }elseif($Handler.Status -eq "valid"){
            Write-Verbose "Challenge completed successfuly."
        }

    }else{
        Write-Verbose "Challenge already completed successfuly."
    }

    Write-Verbose "Creating and submitting certificate with alias: $CertAlias."
    New-ACMECertificate -IdentifierRef $IdentifierAlias -Alias $CertAlias -Generate | Out-Null
    Submit-ACMECertificate -CertificateRef $CertAlias | Out-Null

    ## Wait for certificate, stop script after minute of waiting
    $i = 0
    while((Update-ACMECertificate -CertificateRef $CertAlias).SerialNumber -eq ""){
        if($i -gt 60){
            Write-Warning "Certificate was not issued for a minute. Wait some time and export certificate using Get-ACMECertificate $CertAlias."
            return
        }
        $i += 5
        Start-Sleep -Seconds 5
    }

    if($CertPemPath){
        Write-Verbose "Exporting certificate PEM file."
        Get-ACMECertificate $CertAlias -ExportCertificatePEM $CertPemPath -Overwrite | Out-Null    
    }
    if($CertPkcs12Path){
        Write-Verbose "Exporting certificate Pkcs12 file."
        Get-ACMECertificate $CertAlias -ExportPkcs12 $CertPkcs12Path -Overwrite | Out-Null    
    }
    if($KeyPath){
        Write-Verbose "Exporting certificate Key file."
        Get-ACMECertificate $CertAlias -ExportKeyPEM $KeyPath -Overwrite | Out-Null    
    }

}#function
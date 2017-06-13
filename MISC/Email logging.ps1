#Functions for logging to email

$EmailLog = @()

function Write-Log {
  Write-Host $args[0]
  $script:EmailLog  += $args[0]
}

function Send-Log {
    Param(
        [parameter(Mandatory=$true,Position=0)]
        [Alias("From")]
        [String]
        $FromAddress,
        [parameter(Mandatory=$true,Position=1)]
        [Alias("To")]
        [String]
        $ToAddress,
        [parameter(Mandatory=$false)]
        [Alias("Title")]
        [String]
        $Subject = 'Powershell Log',
        [parameter(Mandatory=$true)]
        [Alias("Server")]
        [String]
        $EmailServer,
        [PSCredential]$Credential
    )

    $Body = ($EmailLog | Out-String).TrimEnd()
    if($Username -and $Password){
        Send-MailMessage -From $FromAddress -To $ToAddress -Subject $Subject -Body $Body -SmtpServer $EmailServer -Credential $Credential
    }else{
        Send-MailMessage -From $FromAddress -To $ToAddress -Subject $Subject -Body $Body -SmtpServer $EmailServer
    }
    }
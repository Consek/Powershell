function Write-Log {
    <#
    .SYNOPSIS
    Outputs log to console and/or file.

    .DESCRIPTION
    Logs output to console and file. Output is formatted before displaying. If $logPath
    is not set before running command, '.\PSLog.log' is used as output file.

    .PARAMETER Message
    Message or object which is logged.

    .PARAMETER ForegroundColor
    Specifies text color. Considered only when $Level is not specified.

    .PARAMETER Level
    Specifies logging level of message. Accepts Error,Warning,Info.
    Defaults to Info.

    .PARAMETER Quiet
    Saves logs only to file.

    .EXAMPLE
    
    #>
    param(
        [Parameter(Position=0,ValueFromPipeline=$true)]
        [Alias('Object','Obj')]
        [Object[]]$Message,
        [Parameter(Mandatory=$false)]
        [System.ConsoleColor]$ForegroundColor,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Error","Warning","Info")]
        [String]$Level="Info",
        [Parameter(Mandatory=$false)]
        [Switch]$Quiet
    )

    begin{
        if(-not $logPath){
            $logPath = '\PSLog.log'
        }
        $isExists = Test-Path ( Split-Path -Parent $logPath)

        if(-not $isExists){
            New-Item $logPath -ItemType File -Force 
        }
    }#begin

    process{
        $Message = $Message | Out-String
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss" 
        if(-not $Quiet){
            switch ($Level) { 
                'Error' { 
                    Write-Host "ERROR: $Message" -ForegroundColor Red
                    $LevelText = 'ERROR:' 
                    } 
                'Warning' { 
                    Write-Host "WARNING: $Message" -ForegroundColor Yellow 
                    $LevelText = 'WARNING:' 
                    } 
                default { 
                    if($ForegroundColor){
                        Write-Host $Message -ForegroundColor $ForegroundColor
                    }else{
                        Write-Host $Message
                    }
                    $LevelText = 'INFO:' 
                    } 
            }#switch
        }else{
            $LevelText = 'QUIET:'
        }#ifelse
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $logPath -Append 
    }#process


}


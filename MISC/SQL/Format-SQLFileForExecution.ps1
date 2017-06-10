function Format-SQLFileForExecution{
    <#
    .SYNOPSIS
    Formats commands from .sql files for execution by SqlClient
    
    .DESCRIPTION
    Splits content from .sql files to separate commands which can be 
    executed serially by SqlClient

    .PARAMETER Content
    Content of .sql file from Get-Content cmdlet
    
    .EXAMPLE
    $command = Get-Content .\confDB.sql | Format-SQLFileForExecution
    
    Gets content from confDB.sql file, formats it and saves to $command variable
    #>

    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [Alias("str")]
        [String[]]$Content
    )
    begin{

    }

    process{
        $Content = $Content -replace "^GO$","GO;;;" | Where-Object {$_}
        $Content = $Content | Out-String
        $Content = $Content -split "GO;;;" | Where-Object {$_ -match "\w"}
        return ,$Content
    }
}

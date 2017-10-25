function Get-ExplicitPermissions{
    <#
    .SYNOPSIS
    Gets explicit permissions from path.
    
    .DESCRIPTION
    Gets explicit permissions assigned to files and folders in specified location.
    Supports recursive search.
    
    .PARAMETER Principal
    Username or group name whose permissions are to be checked (eg. user01).
    
    .PARAMETER Path
    Paths to folders in which checking is to be done.
    
    .PARAMETER Depth
    When specified recursive search is performed to depth.
    
    .PARAMETER IncludeFiles
    Returns explicit permissions to files not only directories.
    
    .EXAMPLE
    Get-ExplicitPermissions C:\TEMP -IncludeFiles

    Path                FileSystemRights IsInherited IdentityReference
    ----                ---------------- ----------- -----------------
    C:\TEMP\TEST     Modify, Synchronize       False BUILTIN\Użytkownicy
    C:\TEMP\TEST.txt               Write       False BUILTIN\Użytkownicy
    
    Gets explicit permissions of files and folders in C:\TEMP.

    .EXAMPLE
    Get-ExplicitPermissions C:\TEMP -Depth 1 -Principal "Użytkownicy"

    Path                    FileSystemRights IsInherited IdentityReference
    ----                    ---------------- ----------- -----------------
    C:\TEMP\TEST         Modify, Synchronize       False BUILTIN\Użytkownicy
    C:\TEMP\TEST\NEW.txt         FullControl       False BUILTIN\Użytkownicy
    
    Gets explcit permissions of folders in C:\TEMP with recursive search of 
    depth 1, and principal "Użytkownicy".

    #>
    param(
        [Parameter(
            Mandatory=$false,
            Position=1
            )]
        [String]$Principal,
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0
            )]
        [Alias("FullName")]
        [String[]]$Path,
        [Parameter(Mandatory=$false)]
        [Int]$Depth,
        [Parameter(Mandatory=$false)]
        [Switch]$IncludeFiles
    )

    begin{
        $ExplicitRights = @()
    }#begin

    process{
        foreach($DirPath in $Path){         
            if($Depth){
                $Dir = Get-ChildItem $DirPath -Recurse -Depth $Depth
                $Dir += Get-Item $DirPath
            }else{
                $Dir = Get-Item $DirPath 
            }

            if(-not $IncludeFiles){
                $Dir = $Dir | Where-Object {$_.Attributes -match "Directory"}
            }

            ForEach ($DirEntry in $Dir) {
                $ExplicitRights += (Get-ACL -Path $DirEntry.FullName).Access | 
                    Select-Object @{n="Path";e={ $DirEntry.FullName }}, FileSystemRights, IsInherited, IdentityReference |
                    Where-Object { ($_.IdentityReference.Value) -match $Principal -and $_.IsInherited -eq $false }
            }
        }
    }#process

    end{
        return $ExplicitRights
    }#end
    
}

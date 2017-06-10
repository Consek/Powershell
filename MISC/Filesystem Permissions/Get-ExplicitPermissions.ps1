function Get-ExplicitPermissions{

    param(
        [Parameter(
            Mandatory=$false,
            Position=1
            )]
        [String]$Principal,
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            Position=0
            )]
        [String[]]$Path,
        [Parameter(Mandatory=$false)]
        [Int]$Depth,
        [Parameter(Mandatory=$false)]
        [Switch]$IncludeFiles
    )

    begin{}#begin

    process{
    
        $ExplicitRights = @()

        if($Depth){
            $Dir = Get-ChildItem $Path -Recurse -Depth $Depth
        }else{
            $Dir = Get-ChildItem $Path 
        }

        if(-not $IncludeFiles){
            $Dir = $Dir | Where-Object {$_.Attributes -match "Directory"}
        }

        ForEach ($DirEntry in $Dir) {
            $ExplicitRights += (Get-ACL -Path $DirEntry.FullName).Access | 
                Select-Object @{n="Path";e={ $DirEntry.FullName }}, FileSystemRights, IsInherited, IdentityReference |
                Where-Object { ($_.IdentityReference.Value) -match $Principal -and $_.IsInherited -eq $false }
        }

        return $ExplicitRights

    }#process

    end{}#end
    
}

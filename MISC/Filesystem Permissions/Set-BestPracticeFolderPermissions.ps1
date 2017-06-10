function Set-BestPracticeFolderPermissions{

    #To rewrite

    param(
        [Parameter(Mandatory=$true,ParameterSetName='Display only')]
        [Parameter(Mandatory=$true,ParameterSetName='Rest')]
        [String]$FolderPath,
        [Parameter(Mandatory=$false,ParameterSetName='Display only')]
        [Parameter(Mandatory=$true,ParameterSetName='Rest')]
        [String]$GroupsPrefix,
        [Parameter(Mandatory=$false,ParameterSetName='Rest')]
        [String]$GroupOUPath='OU=CFS,OU=Folders Group,OU=Queris,DC=QUERIS,DC=local',
        [Parameter(Mandatory=$false,ParameterSetName='Rest')]
        [Switch]$CreateGroups,
        [Parameter(Mandatory=$false,ParameterSetName='Rest')]
        [String]$DomainNetBIOSName = $env:userdomain,
        [Parameter(Mandatory=$false,ParameterSetName='Rest')]
        [Switch]$UpdateGroupMembers,
        [Parameter(Mandatory=$false,ParameterSetName='Rest')]
        [Switch]$SkipWrite,
        [Parameter(Mandatory=$false,ParameterSetName='Rest')]
        [Switch]$SkipReadAndExecute,
        [Parameter(Mandatory=$false,ParameterSetName='Rest')]
        [Switch]$SkipModify,
        [Parameter(Mandatory=$false,ParameterSetName='Rest')]
        [Switch]$SkipListFolderContents,
        [Parameter(Mandatory=$true,ParameterSetName='Display only')]
        [Switch]$OnlyDisplay

    )
    ################################################################
    # Get acl from folder

    $acl = Get-ACL -Path $FolderPath

    ################################################################
    # Convert ACL to Userlist and if skip then nullify skipped

    $UserLists = Get-UserListFromAcl -acl $acl

    "Users and groups not matching filters:"
    $UserLists[4]

    $UserLists[4] = $null

    if($SkipWrite){ $UserLists[2].Value = $null }
    if($SkipReadAndExecute){ $UserLists[0].Value = $null }
    if($SkipModify){ $UserLists[3].Value = $null }
    if($SkipListFolderContents){ $UserLists[1].Value = $null }

    ################################################################
    # List permissions if specified

    if($OnlyDisplay){
        foreach($UserList in $UserLists){
            if($UserList.Value -ne $null){
                "******" + $UserList.Type + "******" | Write-Output
                $UserList.Value | ft
                "" | Write-Output
            }
        }
        return
    }

    ################################################################
    # Get Domain users list from usernames


    [System.Collections.ArrayList]$permGroups = New-Object System.Collections.ArrayList


    foreach($userlist in $UserLists){
        if($userlist.Value -ne $null){
            $permGroups += ,(Get-ADUserListFromString -UserList $userlist.Value -StringIdentifier $userlist.Type )
        }else{
            $permGroups += ,($null)
        }
    }
 
    ################################################################
    # Create Groups if specified


    if($CreateGroups -eq $true){
        if($permGroups[0] -ne $null -and -not $SkipReadAndExecute){
            try{
                Get-ADGroup "$GroupsPrefix R" | Out-Null
                Write-Warning "Group $GroupsPrefix R already exists."
            }catch{
                New-ADGroup "$GroupsPrefix R" -Path $GroupOUPath -GroupScope DomainLocal
                Write-Information "Group $GroupsPrefix R was created."
            }
        }
        if($permGroups[1] -ne $null -and -not $SkipListFolderContents){
            try{
                Get-ADGroup "$GroupsPrefix L" | Out-Null
                Write-Warning "Group $GroupsPrefix L already exists."
            }catch{
                New-ADGroup "$GroupsPrefix L" -Path $GroupOUPath -GroupScope DomainLocal
                Write-Information "Group $GroupsPrefix R was created."
            }        
        }
        if($permGroups[2] -ne $null -and -not $SkipWrite){
            try{
                Get-ADGroup "$GroupsPrefix W" | Out-Null
                Write-Warning "Group $GroupsPrefix W already exists."
            }catch{
                New-ADGroup "$GroupsPrefix W" -Path $GroupOUPath -GroupScope DomainLocal
                Write-Information "Group $GroupsPrefix R was created."
            }        
        }
        if($permGroups[3] -ne $null -and -not $SkipModify){
            try{
                Get-ADGroup "$GroupsPrefix M" | Out-Null
                Write-Warning "Group $GroupsPrefix M already exists."
            }catch{
                New-ADGroup "$GroupsPrefix M" -Path $GroupOUPath -GroupScope DomainLocal
                Write-Information "Group $GroupsPrefix R was created."
            }        
        }
    }

    ################################################################
    # Update group membership

    if($CreateGroups -eq $true -or $UpdateGroupMembers -eq $true){
        if($permGroups[0] -ne $null -and -not $SkipReadAndExecute){
            $gr = Get-ADGroup "$GroupsPrefix R" 
            Add-ADGroupMember "$GroupsPrefix R" -Members ($permGroups[0] | where -Property Name -ne $gr.Name )
        }
        if($permGroups[1] -ne $null -and -not $SkipListFolderContents){
            $gr = Get-ADGroup "$GroupsPrefix L" 
            Add-ADGroupMember "$GroupsPrefix L" -Members ($permGroups[1] | where -Property Name -ne $gr.Name )
        }
        if($permGroups[2] -ne $null -and -not $SkipWrite){
            $gr = Get-ADGroup "$GroupsPrefix W" 
            Add-ADGroupMember "$GroupsPrefix W" -Members ($permGroups[2] | where -Property Name -ne $gr.Name )
        }
        if($permGroups[3] -ne $null -and -not $SkipModify){
            $gr = Get-ADGroup "$GroupsPrefix M" 
            Add-ADGroupMember "$GroupsPrefix M" -Members ($permGroups[3] | where -Property Name -ne $gr.Name )
        }
    }

    ################################################################
    # Display difference between 

    if($permGroups[0] -ne $null){
        ("******" + $UserLists[0].Type + "******") | Write-Output 
        Test-PermissionGroupMembership -ADUsers $permGroups[0] -GroupName ($GroupsPrefix + " R") | ft
    }
    if($permGroups[1] -ne $null){
        ("******" + $UserLists[1].Type + "******") | Write-Output 
        Test-PermissionGroupMembership -ADUsers $permGroups[1] -GroupName ($GroupsPrefix + " L")  | ft
    }
    if($permGroups[2] -ne $null){
        ("******" + $UserLists[2].Type + "******") | Write-Output 
        Test-PermissionGroupMembership -ADUsers $permGroups[2] -GroupName ($GroupsPrefix + " W")  | ft
    }
    if($permGroups[3] -ne $null){
        ("******" + $UserLists[3].Type + "******") | Write-Output 
        Test-PermissionGroupMembership -ADUsers $permGroups[3] -GroupName ($GroupsPrefix + " M")  | ft
    }

}
################################################################



################################################################
## Helper functions ############################################
################################################################



function Remove-StringFromArray(){
    param(
    [Parameter(Mandatory=$true)]
    [String[]]$StringArray, 
    [Parameter(Mandatory=$true)]
    [String]$StringToRemove)


    $NewStringArray = New-Object System.Collections.ArrayList

    foreach($Str in $StringArray){

        $Str = $Str.replace($StringToRemove,"")
        $NewStringArray += $Str

    }

    return $NewStringArray    
}

function Get-ADUserListFromString(){

    param(
    [Parameter(Mandatory=$true)]
    [String[]]$UserList,
    [String]$StringIdentifier
    )

    
    
    $ADusers = New-Object System.Collections.ArrayList

    foreach($entry in $UserList){
    
        try{
            $user = get-aduser $entry
            $ADusers += $user
            Continue
        }catch{
            #Write-Output "Użytkownik $entry nie istnienie, nie można dodać do grupy $StringIdentifier" -ForegroundColor DarkGray
        }
        try{
            $group = Get-ADGroup $entry
            $ADusers += $group
        }catch{
            "Obiekt $entry nie istnienie, nie można dodać do grupy $StringIdentifier" | Write-Warning
        }
    }
    return $ADusers

}

function Test-PermissionGroupMembership(){
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADPrincipal[]]$ADUsers,
        [Parameter(Mandatory=$true)]
        [String]$GroupName
    )

    try{
        $GroupUsers = Get-ADGroupMember $GroupName 
    }catch{
        "Grupa $GroupName nie istnieje, nie można sprawdzić poprawności uprawnień" | Write-Warning
        return
    }
    try{
        Compare-Object -ReferenceObject $ADUsers -DifferenceObject $GroupUsers -IncludeEqual
    }catch{
        "Błąd przy porównywaniu członków grupy $GroupName z listą dostępu folderu. Możliwe że grupa jest pusta." | Write-Warning 
    }
}

function Get-UserListFromAcl (){
    
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory=$true)]
        [System.Security.AccessControl.DirectorySecurity]$acl,
        [Parameter(Mandatory=$false)]
        [String]$domain = ($env:userdomain + "\")

    )


    [System.Collections.ArrayList]$aclaccess = $acl.Access

    $ReadAndExecute = $aclaccess  | Where-Object {( ($_.FileSystemRights) -like "ReadAndExecute, Synchronize") -and ($_.InheritanceFlags -like "ContainerInherit, ObjectInherit") } 

    $ListFolderContents = $aclaccess | Where-Object {( ($_.FileSystemRights) -like "ReadAndExecute, Synchronize") -and ($_.InheritanceFlags -like "ContainerInherit") } 

    $Write = $aclaccess  | Where-Object {( ($_.FileSystemRights) -like "Write, ReadAndExecute, Synchronize") -and ($_.InheritanceFlags -like "ContainerInherit, ObjectInherit") } 

    $Modify = $aclaccess  | Where-Object {( ($_.FileSystemRights) -like "Modify, Synchronize") -and ($_.InheritanceFlags -like "ContainerInherit, ObjectInherit") } 

    ($ReadAndExecute + $ListFolderContents + $Write + $Modify) | % { $aclaccess.Remove($_) } 


    $Rest = $aclaccess | select IdentityReference,FileSystemRights,InheritanceFlags | fl 


    $ReadAndExecute = $ReadAndExecute | select -ExpandProperty IdentityReference | select -ExpandProperty Value

    $ListFolderContents = $ListFolderContents | select -ExpandProperty IdentityReference | select -ExpandProperty Value

    $Write = $Write | select -ExpandProperty IdentityReference | select -ExpandProperty Value

    $Modify = $Modify | select -ExpandProperty IdentityReference | select -ExpandProperty Value

    $RAndE = [PSCustomObject]@{Type = "ReadAndExecute" ; Value = $ReadAndExecute}
    $LFC = [PSCustomObject]@{Type = "ListFolderContents" ; Value = $ListFolderContents}
    $W = [PSCustomObject]@{Type = "Write" ; Value = $Write}
    $M = [PSCustomObject]@{Type = "Modify" ; Value = $Modify}

    $retval = ($RAndE,$LFC,$W,$M,$Rest)

    for( $i = 0; $i -lt 4; $i++){
        
        if($retval[$i].Value -ne $null){
            $retval[$i].Value = Remove-StringFromArray -StringArray ($retval[$i] | select -ExpandProperty Value) -StringToRemove ($domain.ToUpper())
        }
    }

    return ,$retval

}
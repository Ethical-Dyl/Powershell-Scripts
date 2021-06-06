$A = "Group 1"
$B = "Group 2"

Compare-Object (Get-ADGroupMember $A) (Get-ADGroupMember $B) -Property 'Name' -IncludeEqual | 
    sort-object name  | 
    where-object -filter {$_.SideIndicator -eq '=>'}
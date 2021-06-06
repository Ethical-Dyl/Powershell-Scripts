$Users = "User1","User2","User3","User4","User5"

$Users | ForEach-Object {Get-ADPrincipalGroupMembership "$_" | 
    get-adgroup -property description, groupcategory} | 
    Group-Object name |
    Select-Object name, count |
    Sort-Object count -Descending |
    Format-Table -AutoSize
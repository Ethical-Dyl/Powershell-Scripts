Get-ADPrincipalGroupMembership "$UserOrGroup" | 
    get-adgroup -property description, groupcategory | 
    select-object name, groupcategory, description |
    Sort-Object groupcategory, name |
    Format-Table -AutoSize
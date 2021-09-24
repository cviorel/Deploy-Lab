function New-RandomUser {
    <#
        .SYNOPSIS
            Generate random user data from https://randomuser.me/.
        .DESCRIPTION
            This function uses the free API for generating random user data from https://randomuser.me/
        .EXAMPLE
            Get-RandomUser 10
        .EXAMPLE
            Get-RandomUser -Amount 25 -Nationality us,gb
        .LINK
            https://randomuser.me/
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [ValidateRange(1, 500)]
        [int] $Amount,

        [Parameter()]
        [ValidateSet('Male', 'Female')]
        [string] $Gender,

        # Supported nationalities: AU, BR, CA, CH, DE, DK, ES, FI, FR, GB, IE, IR, NL, NZ, TR, US
        [Parameter()]
        [string[]] $Nationality,

        [Parameter()]
        [ValidateSet('json', 'csv', 'xml')]
        [string] $Format = 'json',

        # Fields to include in the results.
        # Supported values: gender, name, location, email, login, registered, dob, phone, cell, id, picture, nat
        [Parameter()]
        [string[]] $IncludeFields,

        # Fields to exclude from the the results.
        # Supported values: gender, name, location, email, login, registered, dob, phone, cell, id, picture, nat
        [Parameter()]
        [string[]] $ExcludeFields
    )

    $rootUrl = "http://api.randomuser.me/?format=$($Format)"

    if ($Amount) {
        $rootUrl += "&results=$($Amount)"
    }

    if ($Gender) {
        $rootUrl += "&gender=$($Gender)"
    }

    if ($Nationality) {
        $rootUrl += "&nat=$($Nationality -join ',')"
    }

    if ($IncludeFields) {
        $rootUrl += "&inc=$($IncludeFields -join ',')"
    }

    if ($ExcludeFields) {
        $rootUrl += "&exc=$($ExcludeFields -join ',')"
    }
    Invoke-RestMethod -Uri $rootUrl
}

# Create Organizational Unit (OU)
$fqdn = Get-ADDomain -Current LocalComputer
$fullDomain = $fqdn.DNSRoot
$domain = $fullDomain.split(".")
$Dom = $domain[0]
$Ext = $domain[1]

# Informations
$Sites = ("Lyon", "New-York", "London")
$Services = ("Production", "Marketing", "IT", "Direction", "Helpdesk")
$FirstOU = "Sites"
$userPassword = 'UserPass123~'

New-ADOrganizationalUnit -Name $FirstOU -Description $FirstOU -Path "DC=$Dom,DC=$Ext" -ProtectedFromAccidentalDeletion $true

Do {
    $testApi = New-RandomUser -Amount 1 -Nationality us -ErrorAction SilentlyContinue
    $testApi
} until ($null -ne $testApi)

if ($null -ne $testApi) {
    foreach ($S in $Sites) {
        New-ADOrganizationalUnit -Name $S -Description "$S"  -Path "OU=$FirstOU,DC=$Dom,DC=$Ext" -ProtectedFromAccidentalDeletion $true

        foreach ($Serv in $Services) {
            New-ADOrganizationalUnit -Name $Serv -Description "$S $Serv"  -Path "OU=$S,OU=$FirstOU,DC=$Dom,DC=$Ext" -ProtectedFromAccidentalDeletion $true

            switch ($S) {
                'Lyon' {
                    $Employees = New-RandomUser -Amount 20 -Nationality fr -IncludeFields name, dob, phone, cell -ExcludeFields picture | Select-Object -ExpandProperty results
                    $Directors = New-RandomUser -Amount 5 -Nationality fr -IncludeFields name, dob, phone, cell -ExcludeFields picture | Select-Object -ExpandProperty results
                }
                'New-York' {
                    $Employees = New-RandomUser -Amount 20 -Nationality us -IncludeFields name, dob, phone, cell -ExcludeFields picture | Select-Object -ExpandProperty results
                    $Directors = New-RandomUser -Amount 5 -Nationality us -IncludeFields name, dob, phone, cell -ExcludeFields picture | Select-Object -ExpandProperty results
                }
                'London' {
                    $Employees = New-RandomUser -Amount 20 -Nationality gb -IncludeFields name, dob, phone, cell -ExcludeFields picture | Select-Object -ExpandProperty results
                    $Directors = New-RandomUser -Amount 5 -Nationality gb -IncludeFields name, dob, phone, cell -ExcludeFields picture | Select-Object -ExpandProperty results
                }
                Default { }
            }

            foreach ($user in $Employees) {
                $newUserProperties = @{
                    Name              = "$($user.name.first) $($user.name.last)"
                    City              = "$S"
                    GivenName         = $user.name.first
                    Surname           = $user.name.last
                    Path              = "OU=$Serv,OU=$S,OU=$FirstOU,dc=$Dom,dc=$Ext"
                    title             = "Employees"
                    department        = "$Serv"
                    OfficePhone       = $user.phone
                    MobilePhone       = $user.cell
                    Company           = "$Dom"
                    EmailAddress      = "$($user.name.first).$($user.name.last)@$($fulldomain)"
                    AccountPassword   = (ConvertTo-SecureString $userPassword -AsPlainText -Force)
                    SamAccountName    = $($user.name.first).Substring(0, 1) + $($user.name.last)
                    UserPrincipalName = "$(($user.name.first).Substring(0,1)+$($user.name.last))@$($fulldomain)"
                    Enabled           = $true
                }

                Try { New-ADUser @newUserProperties }
                Catch { }
            }

            foreach ($user in $Directors) {
                $newUserProperties = @{
                    Name              = "$($user.name.first) $($user.name.last)"
                    City              = "$S"
                    GivenName         = $user.name.first
                    Surname           = $user.name.last
                    Path              = "OU=$Serv,OU=$S,OU=$FirstOU,dc=$Dom,dc=$Ext"
                    title             = "Directors"
                    department        = "$Serv"
                    OfficePhone       = $user.phone
                    MobilePhone       = $user.cell
                    Company           = "$Dom"
                    EmailAddress      = "$($user.name.first).$($user.name.last)@$($fulldomain)"
                    AccountPassword   = (ConvertTo-SecureString $userPassword -AsPlainText -Force)
                    SamAccountName    = $($user.name.first).Substring(0, 1) + $($user.name.last)
                    UserPrincipalName = "$(($user.name.first).Substring(0,1)+$($user.name.last))@$($fulldomain)"
                    Enabled           = $true
                }

                Try { New-ADUser @newUserProperties }
                Catch { }
            }
        }
    }
} else {
    Write-Verbose 'The API cannot be reached!'
}

# Define users
$srcuser = Read-Host "Please specify the source user from which you want to copy the AD groups (SamAccountName). "
$tgtuser = Read-Host "please specify the target user to which you want to copy  the AD groups (SamAccountName). "

$sourceUser = "$srcuser"
$targetUser = "$tgtuser"

# Define log path
$userlog = "$env:USERPROFILE"
$LogFile = "$userlog\CopyUserGroups-LogFile.log"
if (-not (Test-Path $LogFile)) {
    New-Item -Path $LogFile -ItemType File -Force | Out-Null
}

# Logging function
function Write-Log {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Error', 'Information', 'Success', 'Warning')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )
    $prefix = switch ($Level.ToLower()) {
        'error'        { '[ERROR]' }
        'information'  { '[INFO]' }
        'success'      { '[SUCCESS]' }
        'warning'      { '[WARNING]' }
    }
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $LogFile -Value "$timestamp $prefix $Message"
}

Write-Log -Level 'Information' -Message "Script started."

# Load AD module
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Log -Level 'Error' -Message "ActiveDirectory module is missing. Please install it before running this script."
    exit
}
Import-Module ActiveDirectory

# Copy groups
function Copy-ADUserGroups {
    param(
        [Parameter(Mandatory)][string]$SourceUser,
        [Parameter(Mandatory)][string]$TargetUser
    )

    try {
        # Verify both users exist
        $source = Get-ADUser -Identity $SourceUser -ErrorAction Stop
        $target = Get-ADUser -Identity $TargetUser -ErrorAction Stop
    } catch {
        Write-Log -Level 'Error' -Message "One of the users does not exist: $_ Skipping group copy."
        return
    }

    try {
        $sourceGroups = Get-ADPrincipalGroupMembership -Identity $SourceUser
        $targetGroups = Get-ADPrincipalGroupMembership -Identity $TargetUser

        if (-not $sourceGroups) {
            Write-Log -Level 'Information' -Message "No groups found for $SourceUser."
            return
        }

        Write-Log -Level 'Information' -Message "Found $($sourceGroups.Count) groups for $SourceUser."

        $targetGroupNames = $targetGroups | Select-Object -ExpandProperty DistinguishedName

        foreach ($group in $sourceGroups) {
            if ($targetGroupNames -contains $group.DistinguishedName) {
                Write-Log -Level 'Information' -Message "$TargetUser is already in $($group.Name)."
            } else {
                try {
                    Write-Log -Level 'Information' -Message "Adding $TargetUser to $($group.Name)."
                    Add-ADGroupMember -Identity $group -Members $TargetUser -ErrorAction Stop
                    Write-Log -Level 'Success' -Message "$TargetUser added to $($group.Name)."
                } catch {
                    Write-Log -Level 'Error' -Message "Failed to add $TargetUser to $($group.Name): $_"
                }
            }
        }

        Write-Log -Level 'Success' -Message "All groups processed for $TargetUser."
    } catch {
        Write-Log -Level 'Error' -Message "Unexpected error: $_"
    }
}

# Run it
Copy-ADUserGroups -SourceUser $sourceUser -TargetUser $targetUser

Write-Log -Level 'Information' -Message "Script completed."
Write-Host "Script execution completed. Press any key to exit..."

# exit
# End of script

param
(
    [string]$project
)

# --------- INIT ---------
$assemblyInfo = $project + 'Properties\AssemblyInfo.cs'

if (!$assemblyInfo -or !(Test-Path $assemblyInfo)) {
    Write-Host 'Could not find AssemblyInfo.cs on ' $assemblyInfo
    exit 1
}

# --------- backup copy --------
move ($assemblyInfo + '.bkp') $assemblyInfo -force


# strongly based on: https://gist.githubusercontent.com/virtualdreams/3949d80ac61590160159/raw/34633b9761e3b18352ad0a76ae520766edb3f02f/git-hash.ps1
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
copy $assemblyInfo ($assemblyInfo + '.bkp') -force

# --------- GIT ---------
$revision = git rev-parse HEAD 2>&1 | %{ "$_" } #doidera
$pointRelease = -1

# —-----— SVN —-------
if ($revision.Contains('fatal')) {
    Write-Host 'Labeling with svn revision: ' $revision
    $revision = svn info | select-string "^Last Changed Rev" | foreach {$_.line.split(":")[1].trim()}
    for ($i = 0; $i -lt 5; $i++) {
        if (Test-Path '.svn') {
            $revision = svn info | select-string "^Last Changed Rev" | foreach {$_.line.split(":")[1].trim()}
            break
        }
        Push-Location ..
    }
    for (; $i -gt 0; $i--) {
        Pop-Location
    }
    $pointRelease = [int]$revision
    Write-Host $revision
} else {
    Write-Host 'Labeling with git revision: ' $revision
}

if (-not $revision) {
    Write-Host 'Could not find any supported VCS'
    exit 1
}

# ----- WRITING FILE ------
$content = Get-Content $assemblyInfo -Encoding UTF8

$newAssemblyInfo = @()

$updatedInformational = "[assembly: AssemblyInformationalVersion(""{0}"")]" -f $revision
$informationalPattern = "\[assembly: AssemblyInformationalVersion\(""(.*)""\)\]"

$informationalFound = $false
$isVersionUpdate = $false

foreach ($line in $content) {
    # --------- informational ----------
    if ($line -match $informationalPattern) {
        $informationalFound = $true
        $currentRevision = [string]$matches[1]

        if($currentRevision -ne $revision) {
            $line = $updatedInformational
            $isVersionUpdate = $true
            Write-Host 'Hash updated to: ' $revision
        }
    }
    $newAssemblyInfo += [Array]$line
}

# --------- assembly version ----------
if ($isVersionUpdate -and $pointRelease -ge 0) {
    $updateVersion = "[assembly: AssemblyVersion(""{0}.{1}"")]"
    $versionPattern = "\[assembly: AssemblyVersion\(""(\d+\.\d+\.\d+)\.(\d+)""\)\]"

    $updateFileVersion = "[assembly: AssemblyFileVersion(""{0}.{1}"")]"
    $fileVersionPattern = "\[assembly: AssemblyFileVersion\(""(\d+\.\d+\.\d+)\.(\d+)""\)\]"

    for ($i=1; $i -le $newAssemblyInfo.Length; $i++) {
        $line = $newAssemblyInfo[$i]

        if ($line -match $versionPattern) {
            $semanticVersion = [string]$matches[1]

            $message = 'Updating version of {0} to point-release {1}' -f $semanticVersion, $pointRelease
            $newAssemblyInfo[$i] = $updateVersion -f $semanticVersion, $pointRelease

        } elseif ($line -match $fileVersionPattern) {
            $semanticVersion = [string]$matches[1]
            $message = 'Updating file version of {0} to point-release {1}' -f $semanticVersion, $pointRelease
            $newAssemblyInfo[$i] = $updateFileVersion -f $semanticVersion, $pointRelease
        }
    }
}

if ($informationalFound -eq $false) {
    Write-Host 'Appending revision number: ' $revision
    $newAssemblyInfo += [Array]$updatedInformational
}

$newAssemblyInfo | Out-File $assemblyInfo -Encoding UTF8 -force



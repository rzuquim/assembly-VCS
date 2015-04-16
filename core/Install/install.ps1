param (
    $InstallPath,
    $ToolsPath,
    $Package,
    $Project
)

$TargetsFile = 'VCSVersioning.targets'
$TargetsPath = $ToolsPath | Join-Path -ChildPath $TargetsFile

Add-Type -AssemblyName 'Microsoft.Build, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a'

$MSBProject = [Microsoft.Build.Evaluation.ProjectCollection]::GlobalProjectCollection.GetLoadedProjects($Project.FullName) |
    Select-Object -First 1

$ProjectUri = New-Object -TypeName Uri -ArgumentList "file://$($Project.FullName)"
$TargetUri = New-Object -TypeName Uri -ArgumentList "file://$TargetsPath"

$RelativePath = $ProjectUri.MakeRelativeUri($TargetUri) -replace '/','\'

# inserting .targets
$ExistingImports = $MSBProject.Xml.Imports | Where-Object { $_.Project -like "*\$TargetsFile" }

if ($ExistingImports) {
    $ExistingImports | 
        ForEach-Object {
            $MSBProject.Xml.RemoveChild($_) | Out-Null
        }
}
$importElement = $MSBProject.Xml.AddImport($RelativePath)
$importElement.Condition = "Exists('" + $RelativePath + "')"

#writing after-build
$AfterBuildTarget = $MSBProject.Xml.Targets | Where-Object { $_.Name -eq "AfterBuild" }

if (-Not $AfterBuildTarget) {
    $MSBProject.Xml.AddTarget("AfterBuild")
}

#writing before-build
$BeforeBuildTarget = $MSBProject.Xml.Targets | Where-Object { $_.Name -eq "BeforeBuild" }

if (-Not $BeforeBuildTarget) {
    $MSBProject.Xml.AddTarget("BeforeBuild")
}

$Project.Save()

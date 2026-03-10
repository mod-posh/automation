[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Org,

    [Parameter()]
    [string[]]$Repos = @(),

    [Parameter()]
    [string]$Token = $env:GITHUB_TOKEN,

    [Parameter()]
    [string]$OutputJson = "./reports/latest/repo-inventory.json",

    [Parameter()]
    [string]$OutputMarkdown = "./reports/latest/repo-inventory.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

trap {
    $err = $_
    $inv = $err.InvocationInfo

    Write-Host ''
    Write-Host '==== UNHANDLED ERROR ====' -ForegroundColor Red
    Write-Host "Message     : $($err.Exception.Message)" -ForegroundColor Red
    Write-Host "Category    : $($err.CategoryInfo)" -ForegroundColor Yellow

    if ($inv) {
        Write-Host "Script      : $($inv.ScriptName)"
        Write-Host "Function    : $($inv.MyCommand)"
        Write-Host "Line        : $($inv.ScriptLineNumber)"
        Write-Host "Position    : $($inv.OffsetInLine)"
        Write-Host "Statement   : $($inv.Line.Trim())"
    }

    if ($err.ScriptStackTrace) {
        Write-Host 'StackTrace  :' -ForegroundColor Yellow
        Write-Host $err.ScriptStackTrace
    }

    exit 1
}

function Invoke-GitHubApi {
    param(
        [Parameter(Mandatory)]
        [string]$Uri
    )

    if ([string]::IsNullOrWhiteSpace($Token)) {
        throw "GitHub token not provided. Set -Token or GITHUB_TOKEN."
    }

    $headers = @{
        Authorization = "Bearer $Token"
        Accept        = "application/vnd.github+json"
        'User-Agent'  = 'mod-posh-automation-audit'
    }

    Write-Verbose "GET $Uri"
    Invoke-RestMethod -Uri $Uri -Headers $headers -Method Get
}

function Get-OrgRepos {
    param([string]$Org)

    if (@($Repos).Count -gt 0) {
        return @($Repos)
    }

    $page = 1
    $names = @()

    do {
        $uri = "https://api.github.com/orgs/${Org}/repos?per_page=100&page=$page"
        $result = @(Invoke-GitHubApi -Uri $uri)

        if (@($result).Count -eq 0) {
            break
        }

        $names += @($result | ForEach-Object { $_.name })
        $page++
    }
    while (@($result).Count -gt 0)

    return @($names | Sort-Object -Unique)
}

function Get-RepoTree {
    param(
        [string]$Org,
        [string]$Repo
    )

    $repoInfo = Invoke-GitHubApi -Uri "https://api.github.com/repos/${Org}/${Repo}"
    $defaultBranch = $repoInfo.default_branch
    $treeUrl = "https://api.github.com/repos/${Org}/${Repo}/git/trees/${defaultBranch}?recursive=1"
    $treeInfo = Invoke-GitHubApi -Uri $treeUrl

    [pscustomobject]@{
        Repo          = $Repo
        DefaultBranch = $defaultBranch
        Tree          = @($treeInfo.tree)
    }
}

function Get-MatchingPaths {
    param(
        [object[]]$Tree,
        [string[]]$Patterns
    )

    $matches = New-Object System.Collections.Generic.List[string]

    foreach ($item in @($Tree)) {
        foreach ($pattern in @($Patterns)) {
            if ($item.path -like $pattern) {
                $matches.Add($item.path)
                break
            }
        }
    }

    return @($matches | Sort-Object -Unique)
}

function Get-RepoContents {
    param(
        [string]$Org,
        [string]$Repo,
        [string]$Path
    )

    $encodedPath = [uri]::EscapeDataString($Path)
    $uri = "https://api.github.com/repos/${Org}/${Repo}/contents/${encodedPath}"

    try {
        Invoke-GitHubApi -Uri $uri
    }
    catch {
        Write-Verbose "Could not read ${Repo}:${Path}"
        return $null
    }
}

function Get-FileText {
    param(
        [string]$Org,
        [string]$Repo,
        [string]$Path
    )

    $content = Get-RepoContents -Org $Org -Repo $Repo -Path $Path
    if (-not $content) { return $null }
    if (-not $content.content) { return $null }

    $bytes = [Convert]::FromBase64String(($content.content -replace "`n", ''))
    return [Text.Encoding]::UTF8.GetString($bytes)
}

function Get-WorkflowClassification {
    param(
        [string]$Org,
        [string]$Repo,
        [string[]]$WorkflowPaths
    )

    $results = foreach ($workflowPath in @($WorkflowPaths)) {
        $text = Get-FileText -Org $Org -Repo $Repo -Path $workflowPath
        if (-not $text) { continue }

        [pscustomobject]@{
            Path                = $workflowPath
            IsPullRequest       = $text -match '(?m)^\s*pull_request\s*:'
            IsWorkflowCall      = $text -match '(?m)^\s*workflow_call\s*:'
            UsesDotNetTest      = $text -match 'dotnet test'
            UsesPester          = $text -match 'Invoke-Pester'
            LooksLikeValidation = ($text -match 'dotnet test') -or ($text -match 'Invoke-Pester')
        }
    }

    return @($results)
}

function Get-DependabotSummary {
    param(
        [string]$Org,
        [string]$Repo
    )

    $path = '.github/dependabot.yml'
    $text = Get-FileText -Org $Org -Repo $Repo -Path $path

    if (-not $text) {
        return [pscustomobject]@{
            HasDependabotConfig = $false
            Path                = $null
            Ecosystems          = @()
        }
    }

    $ecosystems = @(
        [regex]::Matches($text, 'package-ecosystem:\s*"([^"]+)"') |
        ForEach-Object { $_.Groups[1].Value }
    ) | Sort-Object -Unique

    return [pscustomobject]@{
        HasDependabotConfig = $true
        Path                = $path
        Ecosystems          = @($ecosystems)
    }
}

function Get-RepoClassification {
    param(
        [string]$Org,
        [string]$Repo
    )

    $repoTree = Get-RepoTree -Org $Org -Repo $Repo
    $tree = @($repoTree.Tree)

    $solutionPaths = @(Get-MatchingPaths -Tree $tree -Patterns @('*.sln'))
    $csprojPaths = @(Get-MatchingPaths -Tree $tree -Patterns @('*.csproj'))
    $psd1Paths = @(Get-MatchingPaths -Tree $tree -Patterns @('*.psd1'))
    $psm1Paths = @(Get-MatchingPaths -Tree $tree -Patterns @('*.psm1'))
    $workflowPaths = @(Get-MatchingPaths -Tree $tree -Patterns @('.github/workflows/*.yml', '.github/workflows/*.yaml'))
    $testPaths = @(Get-MatchingPaths -Tree $tree -Patterns @('*Tests.csproj', 'tests/*', 'tests/**/*', '*.Tests.ps1'))

    $workflowInfo = @(Get-WorkflowClassification -Org $Org -Repo $Repo -WorkflowPaths $workflowPaths)
    $dependabot = Get-DependabotSummary -Org $Org -Repo $Repo

    $isDotNet = (@($solutionPaths).Count -gt 0) -or (@($csprojPaths).Count -gt 0)
    $isPowerShell = (@($psd1Paths).Count -gt 0) -or (@($psm1Paths).Count -gt 0)

    $hasDotNetTests = @($testPaths | Where-Object { $_ -like '*Tests.csproj' })
    $hasPsTests = @($testPaths | Where-Object { $_ -like '*.Tests.ps1' -or $_ -like 'tests/*' })

    $hasTests = (@($hasDotNetTests).Count -gt 0) -or (@($hasPsTests).Count -gt 0)
    $hasValidationWorkflow = @($workflowInfo | Where-Object { $_.LooksLikeValidation }).Count -gt 0

    $notes = New-Object System.Collections.Generic.List[string]

    if ($isDotNet -and @($hasDotNetTests).Count -eq 0) {
        $notes.Add('Looks like .NET code exists but no obvious .NET test project was found.')
    }

    if ($isPowerShell -and @($hasPsTests).Count -eq 0) {
        $notes.Add('Looks like PowerShell code exists but no obvious Pester tests were found.')
    }

    if (-not $hasValidationWorkflow) {
        $notes.Add('No PR validation workflow detected.')
    }

    if (-not $dependabot.HasDependabotConfig) {
        $notes.Add('No .github/dependabot.yml found.')
    }

    return [pscustomobject]@{
        Name                    = $Repo
        DefaultBranch           = $repoTree.DefaultBranch
        IsDotNet                = $isDotNet
        IsPowerShell            = $isPowerShell
        SolutionPaths           = @($solutionPaths)
        CsprojPaths             = @($csprojPaths)
        PowerShellManifestPaths = @($psd1Paths)
        PowerShellModulePaths   = @($psm1Paths)
        HasTests                = $hasTests
        TestPaths               = @($testPaths)
        WorkflowPaths           = @($workflowPaths)
        HasValidationWorkflow   = $hasValidationWorkflow
        ValidationWorkflowPaths = @($workflowInfo | Where-Object { $_.LooksLikeValidation } | ForEach-Object Path)
        HasDependabotConfig     = $dependabot.HasDependabotConfig
        DependabotPath          = $dependabot.Path
        DependabotEcosystems    = @($dependabot.Ecosystems)
        AutoMergeReady          = ($hasTests -and $hasValidationWorkflow -and $dependabot.HasDependabotConfig)
        Notes                   = @($notes)
    }
}

function New-MarkdownReport {
    param(
        [object[]]$Inventory
    )

    $total = @($Inventory).Count
    $ready = @($Inventory | Where-Object AutoMergeReady).Count
    $hasTests = @($Inventory | Where-Object HasTests).Count
    $hasWorkflows = @($Inventory | Where-Object HasValidationWorkflow).Count
    $hasDependabot = @($Inventory | Where-Object HasDependabotConfig).Count

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Repository Inventory')
    $lines.Add('')
    $lines.Add('## Summary')
    $lines.Add('')
    $lines.Add("- Total repos audited: $total")
    $lines.Add("- Repos with tests: $hasTests")
    $lines.Add("- Repos with PR validation: $hasWorkflows")
    $lines.Add("- Repos with Dependabot config: $hasDependabot")
    $lines.Add("- Repos currently auto-merge ready: $ready")
    $lines.Add('')
    $lines.Add('## Inventory')
    $lines.Add('')
    $lines.Add('| Repo | Type | Tests | PR Validation | Dependabot | Auto-Merge Ready |')
    $lines.Add('|---|---|---:|---:|---:|---:|')

    foreach ($repo in @($Inventory | Sort-Object Name)) {
        $type = if ($repo.IsDotNet -and $repo.IsPowerShell) {
            '.NET + PowerShell'
        }
        elseif ($repo.IsDotNet) {
            '.NET'
        }
        elseif ($repo.IsPowerShell) {
            'PowerShell'
        }
        else {
            'Other'
        }

        $lines.Add("| $($repo.Name) | $type | $($repo.HasTests) | $($repo.HasValidationWorkflow) | $($repo.HasDependabotConfig) | $($repo.AutoMergeReady) |")

        if (@($repo.Notes).Count -gt 0) {
            $lines.Add('')
            foreach ($note in @($repo.Notes)) {
                $lines.Add("- **$($repo.Name):** $note")
            }
            $lines.Add('')
        }
    }

    return ($lines -join "`n")
}

$repoNames = @(Get-OrgRepos -Org $Org)

$inventory = foreach ($repo in @($repoNames)) {
    try {
        Write-Host "Auditing repo: $repo" -ForegroundColor Cyan
        Get-RepoClassification -Org $Org -Repo $repo
    }
    catch {
        $err = $_
        $inv = $err.InvocationInfo

        Write-Host ''
        Write-Host "FAILED while auditing repo: $repo" -ForegroundColor Red
        Write-Host "Message   : $($err.Exception.Message)" -ForegroundColor Red

        if ($inv) {
            Write-Host "Function  : $($inv.MyCommand)"
            Write-Host "Line      : $($inv.ScriptLineNumber)"
            Write-Host "Statement : $($inv.Line.Trim())"
        }

        throw
    }
}

$null = New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName((Resolve-Path -LiteralPath .).Path + '/' + $OutputJson))
$null = New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName((Resolve-Path -LiteralPath .).Path + '/' + $OutputMarkdown))

$inventory | ConvertTo-Json -Depth 8 | Set-Content -Path $OutputJson -Encoding UTF8
$markdown = New-MarkdownReport -Inventory $inventory
$markdown | Set-Content -Path $OutputMarkdown -Encoding UTF8

Write-Host "Wrote JSON report: $OutputJson"
Write-Host "Wrote Markdown report: $OutputMarkdown"

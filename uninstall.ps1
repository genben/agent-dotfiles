#Requires -Version 5.1
<#
    Uninstall script for agent-dotfiles (Windows / PowerShell)
    Removes links from the appropriate agent config location.

    Only links (symlinks, junctions, hard links) pointing to this repository are
    removed. Anything else is left untouched.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Agent,

    [Alias('h')]
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot

# The agents resolve "~" to USERPROFILE, which is not always the same as
# PowerShell's $HOME (HOMEDRIVE+HOMEPATH can point at a network share).
$HomeDir = if ($env:USERPROFILE) { $env:USERPROFILE.TrimEnd('\') } else { $HOME.TrimEnd('\') }

# ---------------------------------------------------------------- helpers ---

# Convert absolute path to use ~\ if under home directory
function ConvertTo-DisplayPath {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { return '' }
    if ($Path.ToLower().StartsWith($HomeDir.ToLower() + '\')) {
        return '~' + $Path.Substring($HomeDir.Length)
    }
    return $Path
}

function ConvertTo-NormalizedPath {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { return '' }
    $p = $Path -replace '^\\\\\?\\', '' -replace '^\\\?\?\\', ''
    $p = $p -replace '/', '\'
    return $p.TrimEnd('\')
}

function Write-Tag {
    param([string]$Tag, [string]$Color, [string]$Message)
    Write-Host "  [$Tag] " -ForegroundColor $Color -NoNewline
    Write-Host $Message
}

function Write-Rule {
    Write-Host '----------------------------------------'
}

function Show-Usage {
    Write-Host 'Uninstall agent-dotfiles for AI coding agents'
    Write-Host ''
    Write-Host 'Usage: .\uninstall.ps1 <agent> [OPTIONS]'
    Write-Host ''
    Write-Host 'Targets:'
    Write-Host '  claude    Uninstall from Claude Code CLI (~\.claude\)'
    Write-Host '  codex     Uninstall from Codex CLI (~\.codex\)'
    Write-Host '  pi        Uninstall from PI (~\.pi\)'
    Write-Host '  shared    Uninstall shared resources (~\.agents\)'
    Write-Host ''
    Write-Host 'Options:'
    Write-Host '  -Help, -h  Show this help message'
    Write-Host ''
    Write-Host 'Examples:'
    Write-Host '  .\uninstall.ps1 claude   Uninstall from Claude Code'
    Write-Host '  .\uninstall.ps1 codex    Uninstall from Codex'
    Write-Host '  .\uninstall.ps1 shared   Uninstall shared resources only'
    Write-Host ''
    Write-Host 'Only links pointing to this repository are removed.'
    Write-Host 'Links pointing elsewhere are left unchanged.'
}

# Returns $null when the path does not exist, otherwise information about it.
function Get-LinkInfo {
    param([string]$Path)

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return $null }

    $isReparse = ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq [IO.FileAttributes]::ReparsePoint
    $linkType = $item.LinkType
    $targets = @()
    if ($item.Target) { $targets = @($item.Target) }

    return [PSCustomObject]@{
        Item        = $item
        IsContainer = $item.PSIsContainer
        IsLink      = ($isReparse -or $linkType -eq 'HardLink')
        LinkType    = if ($linkType) { $linkType } elseif ($isReparse) { 'ReparsePoint' } else { $null }
        Targets     = $targets
    }
}

# Hard-link targets are reported without a drive letter, so compare loosely.
function Test-TargetMatch {
    param([string[]]$Targets, [string]$Src)

    $srcN = (ConvertTo-NormalizedPath $Src).ToLower()
    foreach ($t in $Targets) {
        if ([string]::IsNullOrEmpty($t)) { continue }
        $tN = (ConvertTo-NormalizedPath $t).ToLower()
        if ($tN -eq $srcN) { return $true }
        if ($tN.StartsWith('\') -and $srcN.EndsWith($tN)) { return $true }
    }
    return $false
}

function Format-Targets {
    param([string[]]$Targets)
    if (-not $Targets -or $Targets.Count -eq 0) { return '<unknown>' }
    return ($Targets -join ', ')
}

function Format-LinkKind {
    param([string]$LinkType)
    switch ($LinkType) {
        'SymbolicLink' { 'symlink' }
        'HardLink'     { 'hard link' }
        'Junction'     { 'junction' }
        default        { 'link' }
    }
}

# Delete a link without following it into the target directory.
function Remove-Link {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer) {
        [System.IO.Directory]::Delete($Path)
    } else {
        [System.IO.File]::Delete($Path)
    }
}

# ------------------------------------------------------------- arguments ---

if ($Help) { Show-Usage; exit 0 }

if ([string]::IsNullOrEmpty($Agent)) {
    Write-Host 'Error: No agent specified.' -ForegroundColor Red
    Write-Host ''
    Show-Usage
    exit 1
}

$Agent = $Agent.ToLower()
if ($Agent -notin @('claude', 'codex', 'pi', 'shared')) {
    Write-Host "Unknown target: $Agent" -ForegroundColor Red
    Write-Host ''
    Show-Usage
    exit 1
}

# ---------------------------------------------------------- configuration ---

# Format: "source:destination"
switch ($Agent) {
    'shared' {
        $AgentHome = Join-Path $HomeDir '.agents'
        $Mappings = @('skills:skills')
        $FileMappings = @()
        $AgentDisplay = 'shared resources'
    }
    'claude' {
        $AgentHome = Join-Path $HomeDir '.claude'
        $Mappings = @('skills:skills')
        $FileMappings = @('claude\CLAUDE.md:CLAUDE.md')
        $AgentDisplay = 'Claude Code'
    }
    'codex' {
        $AgentHome = Join-Path $HomeDir '.codex'
        $Mappings = @()
        $FileMappings = @('codex\AGENTS.md:AGENTS.md')
        $AgentDisplay = 'Codex'
    }
    'pi' {
        $AgentHome = Join-Path $HomeDir '.pi\agent'
        $Mappings = @('pi\extensions:extensions', 'pi\themes:themes')
        $FileMappings = @()
        $AgentDisplay = 'PI'
    }
}

$AgentHomeDisplay = ConvertTo-DisplayPath $AgentHome

$removed = New-Object System.Collections.Generic.List[string]
$skippedNotLink = New-Object System.Collections.Generic.List[string]
$skippedDifferentTarget = New-Object System.Collections.Generic.List[string]
$skippedNotExist = New-Object System.Collections.Generic.List[string]
$errors = New-Object System.Collections.Generic.List[string]

# -------------------------------------------------------------- uninstall ---

function Remove-ManagedLink {
    param([string]$Src, [string]$Dest, [string]$Label)

    $destDisplay = ConvertTo-DisplayPath $Dest
    $info = Get-LinkInfo $Dest

    if (-not $info) {
        Write-Tag 'SKIP' Cyan "${Label}: does not exist"
        $skippedNotExist.Add($destDisplay)
        return
    }

    if (-not $info.IsLink) {
        Write-Tag 'SKIP' Yellow "${Label}: not a link (regular directory/file)"
        $skippedNotLink.Add($destDisplay)
        return
    }

    if (-not (Test-TargetMatch $info.Targets $Src)) {
        Write-Tag 'SKIP' Yellow "${Label}: link points to $(Format-Targets $info.Targets)"
        $skippedDifferentTarget.Add($destDisplay)
        return
    }

    try {
        Remove-Link $Dest
        Write-Tag 'DONE' Green "${Label}: $(Format-LinkKind $info.LinkType) removed"
        $removed.Add($destDisplay)
    } catch {
        Write-Tag 'ERROR' Red "${Label}: failed to remove link - $($_.Exception.Message)"
        $errors.Add($destDisplay)
    }
}

Write-Host "Uninstalling agent-dotfiles for $AgentDisplay from $AgentHomeDisplay..." -ForegroundColor White
Write-Host ''

# Remove directory links
foreach ($entry in $Mappings) {
    $parts = $entry.Split(':', 2)
    $srcDir = $parts[0]
    $destDir = if ($parts.Count -gt 1 -and $parts[1]) { $parts[1] } else { $srcDir }
    Remove-ManagedLink -Src (Join-Path $ScriptDir $srcDir) -Dest (Join-Path $AgentHome $destDir) -Label $destDir
}

# Remove agent-specific file links
foreach ($entry in $FileMappings) {
    $parts = $entry.Split(':', 2)
    $srcFile = $parts[0]
    $destFile = $parts[1]
    Remove-ManagedLink -Src (Join-Path $ScriptDir $srcFile) -Dest (Join-Path $AgentHome $destFile) -Label $destFile
}

Write-Host ''
Write-Rule
Write-Host ''

# Summary
if ($removed.Count -gt 0) {
    Write-Host 'Successfully removed:' -ForegroundColor Green
    Write-Host ''
    foreach ($item in $removed) { Write-Host "  $item" -ForegroundColor Green }
}

if ($skippedNotLink.Count -gt 0 -or $skippedDifferentTarget.Count -gt 0) {
    if ($removed.Count -gt 0) {
        Write-Host ''
        Write-Rule
    }
    Write-Host ''
    Write-Host 'Skipped (not managed by this repo):' -ForegroundColor Yellow
    Write-Host ''
    foreach ($item in $skippedNotLink) { Write-Host "  $item (not a link)" -ForegroundColor Yellow }
    foreach ($item in $skippedDifferentTarget) { Write-Host "  $item (points elsewhere)" -ForegroundColor Yellow }
}

if ($errors.Count -gt 0) {
    if ($removed.Count -gt 0 -or $skippedNotLink.Count -gt 0 -or $skippedDifferentTarget.Count -gt 0) {
        Write-Host ''
        Write-Rule
    }
    Write-Host ''
    Write-Host 'Failed to remove:' -ForegroundColor Red
    Write-Host ''
    foreach ($item in $errors) { Write-Host "  $item" -ForegroundColor Red }
    exit 1
}

if ($removed.Count -eq 0 -and $skippedNotLink.Count -eq 0 -and $skippedDifferentTarget.Count -eq 0) {
    Write-Host 'Nothing to uninstall.'
}

exit 0

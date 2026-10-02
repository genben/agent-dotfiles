#Requires -Version 5.1
<#
    Install script for agent-dotfiles (Windows / PowerShell)
    Links directories and files to the appropriate agent config location.

    Windows notes:
      - Symlinks need either Developer Mode (Settings > System > For developers)
        or an elevated shell. With Developer Mode on, they are created via mklink
        because PowerShell 5.1's New-Item cannot create them unprivileged.
      - When symlinks are not permitted at all, directories fall back to a
        junction and files to a hard link on the same volume.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Agent,

    [Alias('n')]
    [switch]$NonInteractive,

    [Alias('h')]
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$Interactive = -not $NonInteractive
if (-not [Environment]::UserInteractive) { $Interactive = $false }

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

function Read-YesNo {
    param([string]$Prompt)
    $reply = Read-Host "  $Prompt [y/N]"
    return ($reply -match '^\s*[Yy]')
}

function Show-Usage {
    Write-Host 'Install agent-dotfiles for AI coding agents'
    Write-Host ''
    Write-Host 'Usage: .\install.ps1 <agent> [OPTIONS]'
    Write-Host ''
    Write-Host 'Agents:'
    Write-Host '  claude    Install for Claude Code CLI (~\.claude\)'
    Write-Host '  codex     Install for Codex CLI (~\.codex\)'
    Write-Host '  pi        Install for PI (~\.pi\)'
    Write-Host ''
    Write-Host 'Skills are installed to ~\.agents\skills\ regardless of which agent is selected.'
    Write-Host ''
    Write-Host 'Options:'
    Write-Host '  -NonInteractive, -n  Run without prompts. Exits with error on conflicts'
    Write-Host '                       instead of asking the user. Useful for CI/automation.'
    Write-Host '  -Help, -h            Show this help message'
    Write-Host ''
    Write-Host 'Examples:'
    Write-Host '  .\install.ps1 claude       Install for Claude Code'
    Write-Host '  .\install.ps1 codex -n     Install for Codex (non-interactive)'
    Write-Host ''
    Write-Host 'The script is idempotent: running it multiple times is safe. Existing'
    Write-Host 'links pointing to the correct location are left unchanged.'
    Write-Host ''
    Write-Host 'Conflict handling:'
    Write-Host '  If a destination directory already exists (not as a link), the script'
    Write-Host '  will ask whether to skip it. In non-interactive mode, it exits with an error.'
    Write-Host ''
    Write-Host 'Windows notes:'
    Write-Host '  Symlinks require Developer Mode (Settings > System > For developers) or an'
    Write-Host '  elevated shell. Without either, directories fall back to a junction and'
    Write-Host '  files to a hard link on the same volume. The script reports which kind of'
    Write-Host '  link it created for each entry.'
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

# Windows PowerShell 5.1 predates Developer Mode: New-Item -ItemType SymbolicLink
# never passes SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE, so it fails with
# "Administrator privilege required" even when Developer Mode is on. mklink does
# pass the flag, so it is tried next before falling back to a junction/hard link.
function New-Symlink {
    param([string]$Src, [string]$Dest, [switch]$Directory)

    try {
        New-Item -ItemType SymbolicLink -Path $Dest -Value $Src -ErrorAction Stop | Out-Null
        return $true
    } catch { }

    if ($Directory) {
        $null = & cmd.exe /c mklink /D "$Dest" "$Src" 2>$null
    } else {
        $null = & cmd.exe /c mklink "$Dest" "$Src" 2>$null
    }
    return ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $Dest))
}

# Create a directory link. Returns the kind of link that was created.
function New-DirLink {
    param([string]$Src, [string]$Dest)
    if (New-Symlink -Src $Src -Dest $Dest -Directory) { return 'symlink' }
    New-Item -ItemType Junction -Path $Dest -Value $Src -ErrorAction Stop | Out-Null
    return 'junction'
}

# Create a file link. Returns the kind of link that was created.
function New-FileLink {
    param([string]$Src, [string]$Dest)
    if (New-Symlink -Src $Src -Dest $Dest) { return 'symlink' }
    New-Item -ItemType HardLink -Path $Dest -Value $Src -ErrorAction Stop | Out-Null
    return 'hard link'
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
if ($Agent -notin @('claude', 'codex', 'pi')) {
    Write-Host "Unknown agent: $Agent" -ForegroundColor Red
    Write-Host ''
    Show-Usage
    exit 1
}

# ---------------------------------------------------------- configuration ---

# Shared configuration (installed for all agents)
$SharedHome = Join-Path $HomeDir '.agents'
$SharedMappings = @('skills')

# Agent-specific configuration
# Format: "source:destination"
switch ($Agent) {
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
$SharedHomeDisplay = ConvertTo-DisplayPath $SharedHome

$installed = New-Object System.Collections.Generic.List[string]
$alreadyLinked = New-Object System.Collections.Generic.List[string]
$skipped = New-Object System.Collections.Generic.List[string]
$errors = New-Object System.Collections.Generic.List[string]
$hardLinked = New-Object System.Collections.Generic.List[string]

# ---------------------------------------------------------------- install ---

function Install-Link {
    param(
        [string]$Src,
        [string]$Dest,
        [string]$Label,
        [ValidateSet('directory', 'file')]
        [string]$Kind
    )

    $display = "$(ConvertTo-DisplayPath $Dest) => $(ConvertTo-DisplayPath $Src)"

    # Source must exist
    $srcExists = if ($Kind -eq 'directory') { Test-Path -LiteralPath $Src -PathType Container } else { Test-Path -LiteralPath $Src -PathType Leaf }
    if (-not $srcExists) {
        Write-Tag 'SKIP' Yellow "${Label}: source $Kind does not exist"
        $skipped.Add($display)
        return
    }

    $info = Get-LinkInfo $Dest

    # Destination is already a link
    if ($info -and $info.IsLink) {
        if (Test-TargetMatch $info.Targets $Src) {
            Write-Tag 'OK' Cyan "${Label}: $(Format-LinkKind $info.LinkType) already exists"
            $alreadyLinked.Add($display)
            return
        }

        Write-Tag 'WARN' Yellow "${Label}: link exists but points to $(Format-Targets $info.Targets)"
        if (-not $Interactive) {
            Write-Tag 'ERROR' Red "${Label}: link conflict (non-interactive mode)"
            $errors.Add($Label)
            return
        }
        if (-not (Read-YesNo 'Replace link?')) {
            Write-Tag 'SKIP' Yellow "${Label}: skipped by user"
            $skipped.Add($display)
            return
        }
        Remove-Link $Dest
        $created = if ($Kind -eq 'directory') { New-DirLink $Src $Dest } else { New-FileLink $Src $Dest }
        Write-Tag 'DONE' Green "${Label}: $created updated"
        if ($created -eq 'hard link') { $hardLinked.Add($display) }
        $installed.Add($display)
        return
    }

    # Destination exists as a real file or directory
    if ($info) {
        if ($Kind -eq 'file' -and -not $info.IsContainer) {
            Write-Tag 'CONFLICT' Yellow "${Label}: file already exists at $Dest"
            if (-not $Interactive) {
                Write-Tag 'ERROR' Red "${Label}: file conflict (non-interactive mode)"
                $errors.Add($Label)
                return
            }
            if (-not (Read-YesNo 'Replace file? (existing file will be backed up)')) {
                Write-Tag 'SKIP' Yellow "${Label}: skipped by user"
                $skipped.Add($display)
                return
            }
            $backupFile = [IO.Path]::ChangeExtension($Dest, $null).TrimEnd('.') + ".backup_$(Get-Date -Format 'yyyy_MM_dd')" + [IO.Path]::GetExtension($Dest)
            Move-Item -LiteralPath $Dest -Destination $backupFile -Force
            Write-Tag 'BACKUP' Cyan "${Label}: backed up to $(ConvertTo-DisplayPath $backupFile)"
            $created = New-FileLink $Src $Dest
            Write-Tag 'DONE' Green "${Label}: $created created"
            if ($created -eq 'hard link') { $hardLinked.Add($display) }
            $installed.Add($display)
            return
        }

        $what = if ($info.IsContainer) { 'directory' } else { 'file' }
        Write-Tag 'CONFLICT' Red "${Label}: $what already exists at $Dest"
        if (-not $Interactive) {
            Write-Tag 'ERROR' Red "${Label}: cannot create link (non-interactive mode)"
            $errors.Add($Label)
            return
        }
        if (Read-YesNo "Skip this $what and continue?") {
            Write-Tag 'SKIP' Yellow "${Label}: skipped by user"
            $skipped.Add($display)
            return
        }
        Write-Host ''
        Write-Host "Aborted. Please remove or rename $Dest and try again." -ForegroundColor Red
        exit 1
    }

    # Create the link
    try {
        $created = if ($Kind -eq 'directory') { New-DirLink $Src $Dest } else { New-FileLink $Src $Dest }
    } catch {
        Write-Tag 'ERROR' Red "${Label}: failed to create link - $($_.Exception.Message)"
        $errors.Add($Label)
        return
    }
    Write-Tag 'DONE' Green "${Label}: $created created"
    if ($created -eq 'hard link') { $hardLinked.Add($display) }
    $installed.Add($display)
}

Write-Host "Installing agent-dotfiles for $AgentDisplay..." -ForegroundColor White
Write-Host ''

# Ensure directories exist
foreach ($dir in @($SharedHome, $AgentHome)) {
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        Write-Host "Creating $(ConvertTo-DisplayPath $dir)..."
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# Install shared links (skills) to ~\.agents\
Write-Host "Shared resources ($SharedHomeDisplay):" -ForegroundColor White
foreach ($entry in $SharedMappings) {
    Install-Link -Src (Join-Path $ScriptDir $entry) -Dest (Join-Path $SharedHome $entry) -Label $entry -Kind directory
}
Write-Host ''

# Install agent-specific directory links
Write-Host "$AgentDisplay-specific ($AgentHomeDisplay):" -ForegroundColor White
foreach ($entry in $Mappings) {
    $parts = $entry.Split(':', 2)
    $srcDir = $parts[0]
    $destDir = if ($parts.Count -gt 1 -and $parts[1]) { $parts[1] } else { $srcDir }
    Install-Link -Src (Join-Path $ScriptDir $srcDir) -Dest (Join-Path $AgentHome $destDir) -Label $destDir -Kind directory
}

# Install agent-specific file links
foreach ($entry in $FileMappings) {
    $parts = $entry.Split(':', 2)
    $srcFile = $parts[0]
    $destFile = $parts[1]
    Install-Link -Src (Join-Path $ScriptDir $srcFile) -Dest (Join-Path $AgentHome $destFile) -Label $destFile -Kind file
}

Write-Host ''
Write-Rule
Write-Host ''

# Exit with error if there were conflicts
if ($errors.Count -gt 0) {
    Write-Host "Failed to install: $($errors -join ', ')" -ForegroundColor Red
    Write-Host 'Run in interactive mode or resolve conflicts manually.'
    Write-Host 'If link creation was denied, enable Developer Mode (Settings > System > For'
    Write-Host 'developers) or re-run this script from an elevated PowerShell.'
    exit 1
}

# Summary
if ($installed.Count -gt 0) {
    Write-Host 'Successfully installed (links):' -ForegroundColor Green
    Write-Host ''
    foreach ($item in $installed) { Write-Host "  $item" -ForegroundColor Green }
    Write-Host ''
    Write-Host "Restart $AgentDisplay or start a new session to use them."
}

if ($alreadyLinked.Count -gt 0) {
    if ($installed.Count -gt 0) {
        Write-Host ''
        Write-Rule
        Write-Host ''
    }
    Write-Host 'Already installed (no changes):' -ForegroundColor Cyan
    Write-Host ''
    foreach ($item in $alreadyLinked) { Write-Host "  $item" -ForegroundColor Cyan }
}

if ($skipped.Count -gt 0) {
    if ($installed.Count -gt 0 -or $alreadyLinked.Count -gt 0) {
        Write-Host ''
        Write-Rule
    }
    Write-Host ''
    Write-Host 'NOT INSTALLED (skipped):' -ForegroundColor Red
    Write-Host ''
    foreach ($item in $skipped) { Write-Host "  $item" -ForegroundColor Red }
}

if ($hardLinked.Count -gt 0) {
    Write-Host ''
    Write-Rule
    Write-Host ''
    Write-Host 'Note: the following were created as hard links because symlinks are not' -ForegroundColor Yellow
    Write-Host 'permitted on this machine:' -ForegroundColor Yellow
    Write-Host ''
    foreach ($item in $hardLinked) { Write-Host "  $item" -ForegroundColor Yellow }
    Write-Host ''
    Write-Host 'A hard link breaks when git replaces the source file (pull, checkout, stash),'
    Write-Host 'so re-run this script after updating the repository. To get real symlinks,'
    Write-Host 'enable Developer Mode (Settings > System > For developers) and re-run.'
}

exit 0

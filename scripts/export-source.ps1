param(
    [Parameter(Mandatory = $false)]
    [string]$SourcePath = (Split-Path $PSScriptRoot -Parent),

    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = (
Join-Path (Split-Path $PSScriptRoot -Parent) "scripts/exports"
),

    [Parameter(Mandatory = $false)]
    [int]$MaxFileSizeKB = 2048
)

$ErrorActionPreference = "Stop"

# =============================================================================
# Pet Cam Revamp - Source Export Script
#
# Purpose:
#   Creates a lightweight source-only ZIP suitable for code review.
#
# Keeps:
#   - Kotlin / Gradle source
#   - manifests and XML resources
#   - version catalog
#   - Gradle wrapper configuration
#   - tests
#   - documentation
#   - PowerShell scripts
#   - Git status/log/diff summary
#   - project tree
#
# Excludes:
#   - build outputs
#   - IDE/cache directories
#   - APK/AAB/JAR/class files
#   - images/audio/video
#   - local.properties
#   - keystores
#   - google-services.json
#   - archives
#   - oversized files
#
# IMPORTANT:
#   Always inspect the generated ZIP before uploading it.
# =============================================================================


# -----------------------------------------------------------------------------
# Resolve paths
# -----------------------------------------------------------------------------

if (-not (Test-Path $SourcePath)) {
    throw "Source path does not exist: $SourcePath"
}

$source = (Resolve-Path $SourcePath).Path.TrimEnd('\', '/')

if (-not (Test-Path $OutputDirectory)) {
    New-Item `
        -ItemType Directory `
        -Path $OutputDirectory `
        -Force | Out-Null
}

$output = (Resolve-Path $OutputDirectory).Path

$sourceName = Split-Path $source -Leaf

if ([string]::IsNullOrWhiteSpace($sourceName)) {
    $sourceName = "PetCam"
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

$zipName = "$sourceName-source-$timestamp.zip"
$zipPath = Join-Path $output $zipName

$tempRoot = Join-Path `
    $env:TEMP `
    "petcam-source-export-$timestamp"

$stagingRoot = Join-Path `
    $tempRoot `
    $sourceName


# -----------------------------------------------------------------------------
# Directories to exclude completely
# -----------------------------------------------------------------------------

$excludedDirectories = @(
    ".git",
    ".gradle",
    ".idea",
    ".kotlin",
    ".externalNativeBuild",
    ".cxx",
    ".fleet",
    ".vscode",

    "build",
    "captures",
    "outputs",
    "generated",
    "intermediates",
    "tmp",

    "node_modules",
    "exports"
)


# -----------------------------------------------------------------------------
# Sensitive/local files
# -----------------------------------------------------------------------------

$excludedFileNames = @(
    "local.properties",
    "keystore.properties",
    "google-services.json",
    "service-account.json",
    "secrets.properties",
    ".env",
    ".env.local",
    ".env.production"
)


# -----------------------------------------------------------------------------
# Binary / generated / large asset extensions
# -----------------------------------------------------------------------------

$excludedExtensions = @(
# Android/build binaries
    ".apk",
    ".aab",
    ".aar",
    ".jar",
    ".class",
    ".dex",

    # Signing/security
    ".keystore",
    ".jks",
    ".p12",
    ".pfx",
    ".pem",
    ".key",
    ".cer",
    ".crt",

    # Images
    ".png",
    ".jpg",
    ".jpeg",
    ".webp",
    ".gif",
    ".bmp",
    ".ico",

    # Audio
    ".mp3",
    ".wav",
    ".ogg",
    ".m4a",
    ".aac",
    ".flac",

    # Video
    ".mp4",
    ".mov",
    ".mkv",
    ".avi",
    ".webm",

    # Archives
    ".zip",
    ".7z",
    ".rar",
    ".tar",
    ".gz"
)


# -----------------------------------------------------------------------------
# Allowed source/config/document extensions
# -----------------------------------------------------------------------------

$allowedExtensions = @(
    ".kt",
    ".kts",
    ".java",

    ".gradle",
    ".toml",

    ".xml",

    ".properties",

    ".md",
    ".txt",

    ".pro",
    ".rules",

    ".json",

    ".yaml",
    ".yml",

    ".ps1",
    ".bat",
    ".cmd",

    ".gitignore",
    ".gitattributes"
)


# -----------------------------------------------------------------------------
# Important extensionless files
# -----------------------------------------------------------------------------

$allowedExactFileNames = @(
    "gradlew",
    ".gitignore",
    ".gitattributes",
    ".editorconfig"
)


# -----------------------------------------------------------------------------
# Statistics
# -----------------------------------------------------------------------------

$copiedCount = 0
$skippedLargeCount = 0
$skippedSensitiveCount = 0
$skippedBinaryCount = 0


# -----------------------------------------------------------------------------
# Prepare staging directory
# -----------------------------------------------------------------------------

if (Test-Path $tempRoot) {
    Remove-Item `
        -Path $tempRoot `
        -Recurse `
        -Force
}

New-Item `
    -ItemType Directory `
    -Path $stagingRoot `
    -Force | Out-Null


Write-Host ""
Write-Host "========================================="
Write-Host " Pet Cam Revamp - Source Export"
Write-Host "========================================="
Write-Host ""
Write-Host "Source:"
Write-Host "  $source"
Write-Host ""
Write-Host "Output:"
Write-Host "  $zipPath"
Write-Host ""
Write-Host "Max file size:"
Write-Host "  $MaxFileSizeKB KB"
Write-Host ""


# -----------------------------------------------------------------------------
# Helper: determine whether path contains excluded directory
# -----------------------------------------------------------------------------

function Test-IsInsideExcludedDirectory {

    param(
        [string]$RelativePath
    )

    $parts = $RelativePath -split '[\\/]'

    foreach ($part in $parts) {

        if ($excludedDirectories -contains $part) {
            return $true
        }
    }

    return $false
}


# -----------------------------------------------------------------------------
# Enumerate files
# -----------------------------------------------------------------------------

Get-ChildItem `
    -Path $source `
    -File `
    -Recurse `
    -Force |
        ForEach-Object {

            $file = $_

            $relativePath = $file.FullName.Substring($source.Length).TrimStart([char[]]"\/")

            # -------------------------------------------------------------------------
            # Excluded directories
            # -------------------------------------------------------------------------

            if (Test-IsInsideExcludedDirectory $relativePath) {
                return
            }


            # -------------------------------------------------------------------------
            # Sensitive/local files
            # -------------------------------------------------------------------------

            if ($excludedFileNames -contains $file.Name) {

                Write-Warning "Sensitive/local file skipped: $relativePath"

                $script:skippedSensitiveCount++

                return
            }


            # -------------------------------------------------------------------------
            # Extension
            # -------------------------------------------------------------------------

            $extension = $file.Extension.ToLowerInvariant()


            # -------------------------------------------------------------------------
            # Explicit binary exclusion
            # -------------------------------------------------------------------------

            if ($excludedExtensions -contains $extension) {

                $script:skippedBinaryCount++

                return
            }


            # -------------------------------------------------------------------------
            # Determine whether file is useful
            # -------------------------------------------------------------------------

            $allowed = $false


            if ($allowedExtensions -contains $extension) {
                $allowed = $true
            }


            if ($allowedExactFileNames -contains $file.Name) {
                $allowed = $true
            }


            # Explicitly preserve Gradle wrapper properties.
            if (
            $relativePath -eq "gradle\wrapper\gradle-wrapper.properties" -or
                    $relativePath -eq "gradle/wrapper/gradle-wrapper.properties"
            ) {
                $allowed = $true
            }


            # Explicitly preserve version catalog.
            if (
            $relativePath -eq "gradle\libs.versions.toml" -or
                    $relativePath -eq "gradle/libs.versions.toml"
            ) {
                $allowed = $true
            }


            if (-not $allowed) {
                return
            }


            # -------------------------------------------------------------------------
            # Maximum individual file size
            # -------------------------------------------------------------------------

            $sizeKB = [math]::Ceiling(
                    $file.Length / 1KB
            )


            if ($sizeKB -gt $MaxFileSizeKB) {

                Write-Warning `
            "Large file skipped ($sizeKB KB): $relativePath"

                $script:skippedLargeCount++

                return
            }


            # -------------------------------------------------------------------------
            # Destination
            # -------------------------------------------------------------------------

            $destination = Join-Path `
        $stagingRoot `
        $relativePath

            $destinationDirectory = Split-Path `
        $destination `
        -Parent


            if (-not (Test-Path $destinationDirectory)) {

                New-Item `
            -ItemType Directory `
            -Path $destinationDirectory `
            -Force | Out-Null
            }


            # -------------------------------------------------------------------------
            # Copy
            # -------------------------------------------------------------------------

            Copy-Item `
        -Path $file.FullName `
        -Destination $destination `
        -Force


            $script:copiedCount++
        }


# -----------------------------------------------------------------------------
# Git information
# -----------------------------------------------------------------------------

$gitDirectory = Join-Path `
    $source `
    ".git"


if (Test-Path $gitDirectory) {

    Write-Host "Collecting Git information..."

    Push-Location $source

    try {

        git status --short |
                Out-File `
                (Join-Path $stagingRoot "GIT_STATUS.txt") `
                -Encoding utf8


        git log --oneline --decorate -n 30 |
                Out-File `
                (Join-Path $stagingRoot "GIT_LOG.txt") `
                -Encoding utf8


        git diff |
                Out-File `
                (Join-Path $stagingRoot "GIT_DIFF.txt") `
                -Encoding utf8


        git diff --stat |
                Out-File `
                (Join-Path $stagingRoot "GIT_DIFF_STAT.txt") `
                -Encoding utf8


        git branch --show-current |
                Out-File `
                (Join-Path $stagingRoot "GIT_BRANCH.txt") `
                -Encoding utf8
    }
    catch {

        Write-Warning `
            "Git metadata could not be completely exported."
    }
    finally {

        Pop-Location
    }
}


# -----------------------------------------------------------------------------
# Generate project tree
# -----------------------------------------------------------------------------

Write-Host "Generating project tree..."

$treeFile = Join-Path `
    $stagingRoot `
    "PROJECT_TREE.txt"


Get-ChildItem `
    -Path $stagingRoot `
    -Recurse `
    -Force |
        Sort-Object FullName |
        ForEach-Object {

            $relative = $_.FullName.Substring($stagingRoot.Length).TrimStart([char[]]"\/")

            if ($_.PSIsContainer) {
                "[DIR]  $relative"
            }
            else {
                "[FILE] $relative"
            }

        } |
        Out-File `
    $treeFile `
    -Encoding utf8


# -----------------------------------------------------------------------------
# Generate export information
# -----------------------------------------------------------------------------

$infoFile = Join-Path `
    $stagingRoot `
    "EXPORT_INFO.txt"


@"
Pet Cam Revamp Source Export

Export date:
$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Original source:
$source

Files copied:
$copiedCount

Large files skipped:
$skippedLargeCount

Sensitive/local files skipped:
$skippedSensitiveCount

Binary files skipped:
$skippedBinaryCount

Maximum individual file size:
$MaxFileSizeKB KB

This archive intentionally excludes:
- build outputs
- IDE caches
- Gradle caches
- APK/AAB files
- compiled binaries
- images
- audio
- video
- archives
- local.properties
- keystores
- known secret/configuration files

Always inspect the archive manually before sharing it.
"@ |
        Out-File `
    $infoFile `
    -Encoding utf8


# -----------------------------------------------------------------------------
# ZIP
# -----------------------------------------------------------------------------

Write-Host "Creating ZIP..."

if (Test-Path $zipPath) {

    Remove-Item `
        $zipPath `
        -Force
}


Compress-Archive `
    -Path $stagingRoot `
    -DestinationPath $zipPath `
    -CompressionLevel Optimal `
    -Force


# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------

Remove-Item `
    -Path $tempRoot `
    -Recurse `
    -Force


# -----------------------------------------------------------------------------
# Final information
# -----------------------------------------------------------------------------

$zipInfo = Get-Item $zipPath

$zipSizeMB = [math]::Round(
        $zipInfo.Length / 1MB,
        2
)


Write-Host ""
Write-Host "========================================="
Write-Host " Export complete"
Write-Host "========================================="
Write-Host ""

Write-Host "Files copied:"
Write-Host "  $copiedCount"

Write-Host ""

Write-Host "Large files skipped:"
Write-Host "  $skippedLargeCount"

Write-Host ""

Write-Host "Sensitive/local files skipped:"
Write-Host "  $skippedSensitiveCount"

Write-Host ""

Write-Host "Binary files skipped:"
Write-Host "  $skippedBinaryCount"

Write-Host ""

Write-Host "ZIP size:"
Write-Host "  $zipSizeMB MB"

Write-Host ""

Write-Host "ZIP created at:"
Write-Host "  $zipPath"

Write-Host ""
Write-Host "IMPORTANT:"
Write-Host "Inspect the ZIP before uploading it."
Write-Host ""


# -----------------------------------------------------------------------------
# Optional quick archive listing
# -----------------------------------------------------------------------------

Write-Host "You can inspect it with:"
Write-Host ""
Write-Host "  tar -tf `"$zipPath`""
Write-Host ""
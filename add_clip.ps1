# ==============================================================================
# MODULAR & INTERACTIVE VIDEO CLIP PARSER FOR ISLAM MAKHACHEV MEME VAULT
# ==============================================================================
# Features:
#  - Automatic Cache Memory (Pressing Enter / 0 reuses the LATEST folder/file source)
#  - Hardcoded "2-3 Years Dagestan" Origin Meme support
#  - Smart 1-step interactive prompts (Press Enter for defaults, or drag & drop path)
#  - Option 0 = Default project CSVs (data/ & brief/)
#  - Option 1 = Existing custom CSV file path
#  - Option 2 = Create brand NEW CSV file (Name & Directory)
#  - Strict Islam Makhachev relevance filter (requires Islam/Makhachev/Dagestan/Khabib/Poirier/Oliveira/Topuria)
#  - Strict Video ID & Title Deduplication (prevents duplicate interview entries)
#  - Safe UTF-8 timestamp parser (splits ranges with [^\d:]+ to avoid encoding issues)
#  - Recursive directory batch scanning (.md, .txt, .clip, .log)
#  - Multi-clip block splitting in a single file (ignores '---' dividers)
#  - Automatic sync with js/data.js
#  - Rich Structured Cache Generation (add_clip_cache.json) recording choices
# ==============================================================================

[CmdletBinding()]
param(
    [Parameter(Position=0, ValueFromPipeline=$true)]
    [string]$InputPath,

    [Parameter()]
    [string]$RawText,

    [Parameter()]
    [int]$Mode = -1,

    [Parameter()]
    [string]$CsvPath,

    [Parameter()]
    [switch]$NoJsSync
)

# ------------------------------------------------------------------------------
# READ EXECUTION CACHE (add_clip_cache.json)
# ------------------------------------------------------------------------------
$cacheFilePath = Join-Path $PSScriptRoot "add_clip_cache.json"
$cachedObj = $null
if (Test-Path $cacheFilePath) {
    try {
        $cacheRaw = Get-Content $cacheFilePath -Raw
        if (-not [string]::IsNullOrWhiteSpace($cacheRaw)) {
            $cachedObj = $cacheRaw | ConvertFrom-Json
        }
    } catch {}
}

$lastSourceType = if ($cachedObj) { $cachedObj.SelectedSourceType } else { $null }
$lastSourcePathOrText = if ($cachedObj) { $cachedObj.SourcePathOrText } else { $null }

# ------------------------------------------------------------------------------
# FUNCTION: Safe-ParseInt
# Safely extracts integers from strings
# ------------------------------------------------------------------------------
function Safe-ParseInt {
    param([string]$val)
    if ([string]::IsNullOrWhiteSpace($val)) { return 0 }
    $cleanDigits = $val -replace '[^\d]', ''
    if ([string]::IsNullOrWhiteSpace($cleanDigits)) { return 0 }
    return [int]$cleanDigits
}

# ------------------------------------------------------------------------------
# FUNCTION: Clean-UserPath
# Handles drag-and-drop paths from Windows Terminal / PowerShell
# ------------------------------------------------------------------------------
function Clean-UserPath {
    param([string]$pathStr)
    if ([string]::IsNullOrWhiteSpace($pathStr)) { return "" }
    
    $p = $pathStr.Trim()
    $p = $p -replace '^\s*&\s*', ''
    $p = $p.Trim()

    while (($p.StartsWith("'") -and $p.EndsWith("'")) -or ($p.StartsWith('"') -and $p.EndsWith('"'))) {
        if ($p.Length -ge 2) {
            $p = $p.Substring(1, $p.Length - 2).Trim()
        } else {
            break
        }
    }
    
    $p = $p.Trim("'", '"', " ")
    return $p
}

# Clean incoming parameters
$InputPath = Clean-UserPath -pathStr $InputPath
$CsvPath = Clean-UserPath -pathStr $CsvPath

# ------------------------------------------------------------------------------
# INTERACTIVE PROMPT ENGINE (When parameters are omitted)
# ------------------------------------------------------------------------------

$selectedCsvModeLabel = 0

# 1. Target CSV Mode & Path Resolution
if ($Mode -eq -1 -and [string]::IsNullOrWhiteSpace($CsvPath)) {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "   Islam Makhachev Meme Vault Quick-Add   " -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Target CSV Location:" -ForegroundColor Yellow
    Write-Host "  [0] Default project CSVs (data/ & brief/) [Press Enter]" -ForegroundColor Green
    Write-Host "  [1] Existing custom CSV file path (Drag & drop or paste)" -ForegroundColor White
    Write-Host "  [2] Create a brand NEW CSV file (Specify Name & Directory)" -ForegroundColor Cyan
    
    $csvChoiceRaw = Read-Host -Prompt "Choice (0/1/2 or Drag & Drop CSV path) [default: 0]"
    $cleanCsvChoice = Clean-UserPath -pathStr $csvChoiceRaw

    if ([string]::IsNullOrWhiteSpace($cleanCsvChoice) -or $cleanCsvChoice -eq "0") {
        $Mode = 0
        $selectedCsvModeLabel = 0
    } elseif ($cleanCsvChoice -eq "1") {
        $Mode = 1
        $selectedCsvModeLabel = 1
        $CsvPath = Clean-UserPath -pathStr (Read-Host -Prompt "Drag & drop or enter custom CSV file path")
    } elseif ($cleanCsvChoice -eq "2") {
        $Mode = 1
        $selectedCsvModeLabel = 2
        
        Write-Host ""
        Write-Host "--- Create Brand New CSV File ---" -ForegroundColor Cyan
        $newName = Read-Host -Prompt "Enter NEW CSV File Name (e.g. my_clips.csv)"
        $newName = Clean-UserPath -pathStr $newName
        if (-not $newName.EndsWith(".csv", [System.StringComparison]::OrdinalIgnoreCase)) {
            $newName = $newName + ".csv"
        }
        
        $newDir = Read-Host -Prompt "Enter directory folder to save CSV (or Drag & drop folder) [Press Enter for current directory]"
        $newDir = Clean-UserPath -pathStr $newDir
        if ([string]::IsNullOrWhiteSpace($newDir)) {
            $newDir = $PSScriptRoot
        }
        if (-not (Test-Path $newDir)) {
            New-Item -ItemType Directory -Path $newDir -Force | Out-Null
        }
        
        $fullNewCsvPath = Join-Path $newDir $newName
        if (-not (Test-Path $fullNewCsvPath)) {
            Set-Content -Path $fullNewCsvPath -Value "title yt,yt url,yt channel,tipe,vid duration,vid duration start at,date inputted"
            Write-Host ("  [CREATED] Initialized new CSV file: " + $fullNewCsvPath) -ForegroundColor Green
        }
        $CsvPath = $fullNewCsvPath
    } else {
        if ($cleanCsvChoice.EndsWith(".csv", [System.StringComparison]::OrdinalIgnoreCase) -or (Test-Path $cleanCsvChoice)) {
            $Mode = 1
            $selectedCsvModeLabel = 1
            $CsvPath = $cleanCsvChoice
        } else {
            $Mode = 0
            $selectedCsvModeLabel = 0
        }
    }
} elseif ($Mode -eq 1 -and [string]::IsNullOrWhiteSpace($CsvPath)) {
    $CsvPath = Clean-UserPath -pathStr (Read-Host -Prompt "Drag & drop or enter custom CSV file path")
    $selectedCsvModeLabel = 1
}

# 2. Source Content Input Resolution
$selectedSourceType = "Unknown"
$sourcePathOrTextLog = ""

if ([string]::IsNullOrWhiteSpace($InputPath) -and [string]::IsNullOrWhiteSpace($RawText)) {
    # Determine default label to show user
    $defaultSourceLabel = "Clipboard"
    if ($lastSourcePathOrText -and $lastSourcePathOrText -ne "Clipboard") {
        $defaultSourceLabel = "Latest Cache Source: " + $lastSourcePathOrText
    }

    Write-Host ""
    Write-Host "Select Input Source:" -ForegroundColor Yellow
    Write-Host ("  - Press [Enter] to use default [" + $defaultSourceLabel + "]") -ForegroundColor Green
    Write-Host "  - Type 'C' or 'clipboard' to read from Clipboard" -ForegroundColor White
    Write-Host "  - OR drag & drop File path (.md/.txt), Folder path (batch scan), or paste Raw text" -ForegroundColor White
    
    $srcInputRaw = Read-Host -Prompt ("Input Source [default: " + $defaultSourceLabel + "]")
    $cleanSrcInput = Clean-UserPath -pathStr $srcInputRaw

    if ([string]::IsNullOrWhiteSpace($cleanSrcInput) -or $cleanSrcInput -eq "0") {
        # Check if we have a valid cached file or directory source to reuse
        if ($lastSourcePathOrText -and $lastSourcePathOrText -ne "Clipboard" -and (Test-Path $lastSourcePathOrText)) {
            Write-Host ("  [CACHE REUSE] Using latest source from cache: " + $lastSourcePathOrText) -ForegroundColor Green
            $InputPath = $lastSourcePathOrText
            if (Test-Path $lastSourcePathOrText -PathType Container) {
                $selectedSourceType = "Directory"
            } else {
                $selectedSourceType = "File"
            }
            $sourcePathOrTextLog = $lastSourcePathOrText
        } else {
            $selectedSourceType = "Clipboard"
            $sourcePathOrTextLog = "Clipboard"
        }
    } elseif ($cleanSrcInput -eq "c" -or $cleanSrcInput -eq "clipboard") {
        $selectedSourceType = "Clipboard"
        $sourcePathOrTextLog = "Clipboard"
    } else {
        if (Test-Path $cleanSrcInput) {
            $InputPath = $cleanSrcInput
            if (Test-Path $cleanSrcInput -PathType Container) {
                $selectedSourceType = "Directory"
            } else {
                $selectedSourceType = "File"
            }
            $sourcePathOrTextLog = $cleanSrcInput
        } else {
            $RawText = $cleanSrcInput
            $selectedSourceType = "RawText"
            $sourcePathOrTextLog = if ($cleanSrcInput.Length -gt 60) { $cleanSrcInput.Substring(0, 57) + "..." } else { $cleanSrcInput }
        }
    }
} else {
    if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
        if (Test-Path $InputPath -PathType Container) {
            $selectedSourceType = "Directory"
        } else {
            $selectedSourceType = "File"
        }
        $sourcePathOrTextLog = $InputPath
    } elseif (-not [string]::IsNullOrWhiteSpace($RawText)) {
        $selectedSourceType = "RawText"
        $sourcePathOrTextLog = if ($RawText.Length -gt 60) { $RawText.Substring(0, 57) + "..." } else { $RawText }
    }
}

# ------------------------------------------------------------------------------
# FUNCTION: Split-ClipBlocks
# Splits text into distinct clip blocks if multiple clips exist in one file
# ------------------------------------------------------------------------------
function Split-ClipBlocks {
    param([string]$raw)

    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }

    # Split by horizontal rule divider '---'
    $blocks = $raw -split '(?m)^\s*---\s*$' | Where-Object { $_.Trim().Length -gt 0 }
    
    if ($blocks.Count -le 1) {
        # Fallback to splitting by title quotes or header lines if no '---' divider found
        $blocks = $raw -split '(?m)^(?=^[\s]*"[^"\r\n]+"|^[\s]*#+\s+|-Islam Makhachev)' | Where-Object { $_.Trim().Length -gt 0 }
    }

    if ($blocks.Count -eq 0) {
        return @($raw)
    }

    return $blocks
}

# ------------------------------------------------------------------------------
# FUNCTION: Parse-ClipText
# ------------------------------------------------------------------------------
function Parse-ClipText {
    param([string]$text)

    if ([string]::IsNullOrWhiteSpace($text)) { return $null }

    # Strict Relevance Filter: Must specifically be about Islam Makhachev subjects
    $isIslamRelated = ($text -match 'Islam|Makhachev|Dagestan|Khabib|Poirier|Oliveira|Topuria|Chanko|Black Belt|2-3 Years')
    if (-not $isIslamRelated) {
        return $null
    }

    # Ignore empty lines and '---' divider lines
    $lines = $text -split '\r?\n' | Where-Object { $_.Trim().Length -gt 0 -and $_.Trim() -ne '---' }
    if ($lines.Count -eq 0) { return $null }

    $firstLine = $lines[0].Trim()

    # Reject junk lines / PowerShell errors / single letters
    if ($firstLine.Length -le 2 -or $firstLine -eq '---' -or $firstLine -match 'InputPath' -or $firstLine -match 'Command:' -or $firstLine -match 'PowerShell' -or $firstLine -match 'Write-Host') {
        return $null
    }

    # 1. Parse Title (Strip leading Markdown headers '# ', quotes, etc.)
    $title = $firstLine -replace '^\s*#+\s*', ''
    if ($title -match '"([^"]+)"') {
        $title = $Matches[1]
    } else {
        $title = $title -replace '\s*-\s*Islam Makhachev.*', '' -replace '#Shorts', '' -replace '^\s*["'']|["'']\s*$', ''
    }
    $title = $title.Trim()

    if ([string]::IsNullOrWhiteSpace($title) -or $title.Length -le 2 -or $title -eq '---') { 
        return $null 
    }

    # 2. Determine Type (yt-short vs yt-biasa)
    $tipe = "yt-biasa"
    if ($text -match '#Shorts' -or $text -match 'Shorts_' -or $text -match '/shorts/') {
        $tipe = "yt-short"
    }

    # 3. Parse YouTube or Video URL
    $ytUrl = ""
    if ($text -match 'https?://[^\s\)\>\]"''\>]+') {
        $ytUrl = $Matches[0]
    }
    if ($ytUrl -match 'youtu\.be/([^/\&\?]+)') {
        $vId = $Matches[1]
        $ytUrl = "https://www.youtube.com/watch?v=" + $vId
    }

    # 4. Parse Timestamps (Start At & Duration) with robust non-digit splitting
    $startAt = "00:00"
    $duration = "00:10"

    if ($text -match 'Clip transcript\s*\(([^\)]+)\)') {
        $transRange = $Matches[1].Trim()
        $rangeParts = $transRange -split '[^\d:]+' | Where-Object { $_.Trim().Length -gt 0 }
        if ($rangeParts.Count -ge 2) {
            $rawStart = $rangeParts[0].Trim()
            $rawEnd = $rangeParts[1].Trim()

            $startParts = $rawStart -split ':'
            if ($startParts.Count -eq 2) {
                $s0 = Safe-ParseInt -val $startParts[0]
                $s1 = Safe-ParseInt -val $startParts[1]
                $startAt = "{0:D2}:{1:D2}" -f $s0, $s1
            }
            $endParts = $rawEnd -split ':'
            if ($endParts.Count -eq 2) {
                $e0 = Safe-ParseInt -val $endParts[0]
                $e1 = Safe-ParseInt -val $endParts[1]
                $duration = "{0:D2}:{1:D2}" -f $e0, $e1
            }
        }
    } elseif ($text -match '00-00-(\d\d-\d\d)_to_00-00-(\d\d-\d\d)') {
        $startAt = $Matches[1] -replace '-', ':'
        $duration = $Matches[2] -replace '-', ':'
    }

    # Calculate Seconds
    $startParts = $startAt -split ':'
    $startSec = 0
    if ($startParts.Count -eq 2) {
        $s0 = Safe-ParseInt -val $startParts[0]
        $s1 = Safe-ParseInt -val $startParts[1]
        $startSec = ($s0 * 60) + $s1
    }

    # Format timestamp in URL cleanly with ?t= or &t=
    if ($ytUrl -and $ytUrl -notmatch 't=') {
        if ($ytUrl.Contains('?')) {
            $ytUrl = $ytUrl + "&t=" + $startSec + "s"
        } else {
            $ytUrl = $ytUrl + "?t=" + $startSec + "s"
        }
    }

    # 5. Determine Channel
    $channel = "Daniel Cormier"
    if ($text -match '#ESPN' -or $text -match 'ESPN MMA') {
        $channel = "ESPN MMA"
    } elseif ($text -match 'MIGHTY' -or $text -match 'Demetrious Johnson' -or $text -match 'Mighty Mouse') {
        $channel = "Mighty Mouse"
    } elseif ($text -match '#UFC' -and $text -notmatch '#DanielCormier') {
        $channel = "UFC - Ultimate Fighting Championship"
    } elseif ($text -match '#DanielCormier' -or $text -match 'DC Check-In' -or $text -match 'danielcormierwrestling\.com' -or $text -match '@dc_mma') {
        $channel = "Daniel Cormier"
    }

    # 6. Date Inputted (Non-public Reference Date)
    $dateInputted = Get-Date -Format "yyyy-MM-dd"

    # 7. Transcript Quote Snippet
    $quoteText = $title
    $transcriptMatches = $text -split '\r?\n' | Where-Object { $_ -match '\[\d+:\d+\]\s*(.+)' }
    if ($transcriptMatches -and $transcriptMatches.Count -gt 0) {
        $cleanLines = $transcriptMatches | ForEach-Object { $_ -replace '\[\d+:\d+\]\s*', '' }
        $quoteText = ($cleanLines -join ' ').Trim()
        if ($quoteText.Length -gt 120) {
            $quoteText = $quoteText.Substring(0, 117) + "..."
        }
    }

    return @{
        Title        = $title
        YtUrl        = $ytUrl
        Channel      = $channel
        Tipe         = $tipe
        Duration     = $duration
        StartAt      = $startAt
        StartSeconds = $startSec
        DateInputted = $dateInputted
        QuoteText    = $quoteText
    }
}

# ------------------------------------------------------------------------------
# FUNCTION: Add-ClipToCsv
# ------------------------------------------------------------------------------
function Add-ClipToCsv {
    param(
        [hashtable]$clip,
        [string[]]$csvTargetPaths
    )

    if (-not $clip) { return }

    $t = $clip.Title
    $u = $clip.YtUrl
    $c = $clip.Channel
    $tp = $clip.Tipe
    $d = $clip.Duration
    $st = $clip.StartAt
    $dt = $clip.DateInputted

    $csvLine = '"' + $t + '",' + $u + ',' + $c + ',' + $tp + ',' + $d + ',' + $st + ',' + $dt

    foreach ($targetFile in $csvTargetPaths) {
        $cleanTarget = Clean-UserPath -pathStr $targetFile
        if ([string]::IsNullOrWhiteSpace($cleanTarget)) { continue }

        if (-not (Test-Path $cleanTarget)) {
            $parentDir = Split-Path $cleanTarget -Parent
            if ($parentDir -and -not (Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }
            Set-Content -Path $cleanTarget -Value "title yt,yt url,yt channel,tipe,vid duration,vid duration start at,date inputted"
        }

        $existingContent = Get-Content $cleanTarget -Raw
        
        $videoId = ""
        if ($clip.YtUrl -match 'v=([^/\&\?]+)') {
            $videoId = $Matches[1]
        } elseif ($clip.YtUrl -match 'youtu\.be/([^/\&\?]+)') {
            $videoId = $Matches[1]
        }

        $vIdEscaped = if ($videoId) { [regex]::Escape($videoId) } else { $null }
        $titleCheck = [regex]::Escape($clip.Title)

        if ($vIdEscaped -and $existingContent -match $vIdEscaped) {
            Write-Host ("  [INFO] Already exists in CSV (skipped duplicate Video ID " + $videoId + "): " + $cleanTarget) -ForegroundColor Yellow
        } elseif ($existingContent -match $titleCheck) {
            Write-Host ("  [INFO] Already exists in CSV (skipped duplicate Title): " + $cleanTarget) -ForegroundColor Yellow
        } else {
            Add-Content -Path $targetFile -Value $csvLine
            Write-Host ("  [OK] Appended to CSV: " + $cleanTarget) -ForegroundColor Green
        }
    }
}

# ------------------------------------------------------------------------------
# FUNCTION: Sync-JsData
# Cleanly updates js/data.js without string escape corruption
# ------------------------------------------------------------------------------
function Sync-JsData {
    param(
        [hashtable]$clip,
        [string]$jsPath
    )

    if (-not (Test-Path $jsPath) -or -not $clip) { return }

    $videoId = ""
    if ($clip.YtUrl -match 'v=([^/\&\?]+)') {
        $videoId = $Matches[1]
    } elseif ($clip.YtUrl -match 'youtu\.be/([^/\&\?]+)') {
        $videoId = $Matches[1]
    }

    $jsContent = Get-Content $jsPath -Raw
    $vIdEscaped = if ($videoId) { [regex]::Escape($videoId) } else { $null }

    if ($vIdEscaped -and $jsContent -match $vIdEscaped) {
        Write-Host "  [INFO] Already synced in js/data.js (skipped duplicate Video ID)" -ForegroundColor Yellow
        return
    }

    $nl = [Environment]::NewLine

    if ($clip.Tipe -eq "yt-short") {
        $shortId = "short-" + (Get-Random -Minimum 100 -Maximum 999)
        $jsObj = @{
            id           = $shortId
            videoId      = $videoId
            title        = $clip.Title
            channel      = $clip.Channel
            tipe         = "yt-short"
            duration     = $clip.Duration
            startAt      = $clip.StartAt
            startSeconds = $clip.StartSeconds
            views        = "1M views"
            gradient     = "linear-gradient(180deg, #1C1917 0%, #292524 100%)"
            quote        = $clip.QuoteText
            context      = ("Islam Makhachev clip from " + $clip.Channel + ".")
            sourceUrl    = $clip.YtUrl
            embedUrl     = ("https://www.youtube.com/embed/" + $videoId + "?start=" + $clip.StartSeconds)
        }
        $jsonStr = $jsObj | ConvertTo-Json -Depth 4
        
        $targetMarker = '"shortsMemes": ['
        if ($jsContent.Contains($targetMarker)) {
            $idx = $jsContent.IndexOf($targetMarker) + $targetMarker.Length
            $jsContent = $jsContent.Substring(0, $idx) + $nl + "    " + $jsonStr + "," + $jsContent.Substring($idx)
        }
    } else {
        $memeId = "meme-" + (Get-Random -Minimum 100 -Maximum 999)
        $jsObj = @{
            id           = $memeId
            dateYear     = 2026.0
            videoId      = $videoId
            timestamp    = "2026"
            title        = $clip.Title
            channel      = $clip.Channel
            tipe         = "yt-biasa"
            duration     = $clip.Duration
            startAt      = $clip.StartAt
            startSeconds = $clip.StartSeconds
            views        = "1M views"
            quote        = $clip.QuoteText
            context      = ("Islam Makhachev clip from " + $clip.Channel + ".")
            embedType    = "youtube"
            embedUrl     = ("https://www.youtube.com/embed/" + $videoId + "?start=" + $clip.StartSeconds)
            sourceUrl    = $clip.YtUrl
        }
        $jsonStr = $jsObj | ConvertTo-Json -Depth 4

        $targetMarker = '"timestampedMemes": ['
        if ($jsContent.Contains($targetMarker)) {
            $idx = $jsContent.IndexOf($targetMarker) + $targetMarker.Length
            $jsContent = $jsContent.Substring(0, $idx) + $nl + "    " + $jsonStr + "," + $jsContent.Substring($idx)
        }
    }

    Set-Content -Path $jsPath -Value $jsContent
    Write-Host "  [OK] Synced to js/data.js" -ForegroundColor Green
}

# ==============================================================================
# MAIN EXECUTION ROUTINE
# ==============================================================================

# Determine Target CSV Paths based on Mode
$targetCsvs = @()
if ($Mode -eq 1) {
    if ([string]::IsNullOrWhiteSpace($CsvPath)) {
        Write-Host "[ERROR] Mode 1 selected: Please specify -CsvPath 'path/to/custom.csv'" -ForegroundColor Red
        exit 1
    }
    $targetCsvs = @($CsvPath)
} else {
    # Default Mode 0: Project default CSV paths
    $targetCsvs = @(
        "$PSScriptRoot\data\videos_data.csv",
        "$PSScriptRoot\brief\videos_data.csv"
    )
}

# Resolve Items to Process (Direct Text, File, Folder Directory, or Clipboard)
$textItemsToProcess = @()

if (-not [string]::IsNullOrWhiteSpace($RawText)) {
    $blocks = Split-ClipBlocks -raw $RawText
    foreach ($b in $blocks) {
        $textItemsToProcess += @{ Source = "RawText Parameter"; Content = $b }
    }
} elseif (-not [string]::IsNullOrWhiteSpace($InputPath)) {
    if (Test-Path $InputPath -PathType Container) {
        Write-Host (" [DIR] Processing directory recursively: " + $InputPath) -ForegroundColor Cyan
        $files = Get-ChildItem -Path $InputPath -Recurse -File -Include "*.txt", "*.md", "*.clip", "*.log"
        Write-Host ("       Found " + $files.Count + " clip file(s).") -ForegroundColor Gray
        foreach ($f in $files) {
            $c = Get-Content $f.FullName -Raw
            if (-not [string]::IsNullOrWhiteSpace($c)) {
                $blocks = Split-ClipBlocks -raw $c
                foreach ($b in $blocks) {
                    $textItemsToProcess += @{ Source = $f.FullName; Content = $b }
                }
            }
        }
    } elseif (Test-Path $InputPath -PathType Leaf) {
        Write-Host (" [FILE] Processing single file: " + $InputPath) -ForegroundColor Cyan
        $c = Get-Content $InputPath -Raw
        if (-not [string]::IsNullOrWhiteSpace($c)) {
            $blocks = Split-ClipBlocks -raw $c
            foreach ($b in $blocks) {
                $textItemsToProcess += @{ Source = $InputPath; Content = $b }
            }
        }
    } else {
        Write-Host ("[ERROR] InputPath '" + $InputPath + "' not found!") -ForegroundColor Red
        exit 1
    }
} else {
    # Fallback to Clipboard
    try {
        $clipText = Get-Clipboard -Raw
        if (-not [string]::IsNullOrWhiteSpace($clipText)) {
            Write-Host "[CLIPBOARD] Processing content from Clipboard..." -ForegroundColor Cyan
            $blocks = Split-ClipBlocks -raw $clipText
            foreach ($b in $blocks) {
                $textItemsToProcess += @{ Source = "Clipboard"; Content = $b }
            }
        }
    } catch {}
}

if ($textItemsToProcess.Count -eq 0) {
    Write-Host "[ERROR] No text or files found to parse! Provide -InputPath (file/folder), -RawText, or copy clip to clipboard." -ForegroundColor Red
    exit 1
}

# Process each clip
$successCount = 0
$lastParsedClipObj = $null

foreach ($item in $textItemsToProcess) {
    Write-Host ""
    Write-Host ("--- Processing: " + $item.Source + " ---") -ForegroundColor Gray
    
    $parsedClip = Parse-ClipText -text $item.Content
    if ($parsedClip) {
        $lastParsedClipObj = $parsedClip
        Write-Host ("  Title:     " + $parsedClip.Title) -ForegroundColor White
        Write-Host ("  URL:       " + $parsedClip.YtUrl) -ForegroundColor White
        Write-Host ("  Channel:   " + $parsedClip.Channel) -ForegroundColor White
        Write-Host ("  Type:      " + $parsedClip.Tipe) -ForegroundColor White
        Write-Host ("  Duration:  " + $parsedClip.Duration + " (Start @ " + $parsedClip.StartAt + ")") -ForegroundColor White
        
        Add-ClipToCsv -clip $parsedClip -csvTargetPaths $targetCsvs

        if (-not $NoJsSync) {
            Sync-JsData -clip $parsedClip -jsPath "$PSScriptRoot\js\data.js"
        }

        $successCount++
    } else {
        Write-Host ("  [WARN] Could not parse valid clip text from " + $item.Source + " (Skipped)") -ForegroundColor Yellow
    }
}

# Save Enhanced Cache File: add_clip_cache.json
if ($lastParsedClipObj -or $successCount -ge 0) {
    $cacheFilePath = Join-Path $PSScriptRoot "add_clip_cache.json"
    $cacheObj = @{
        Script              = "add_clip.ps1"
        Timestamp           = (Get-Date -Format "o")
        SelectedCsvMode     = $selectedCsvModeLabel
        TargetCsvs          = $targetCsvs
        SelectedSourceType  = $selectedSourceType
        SourcePathOrText    = $sourcePathOrTextLog
        ProcessedCount      = $successCount
        LastParsedClip      = $lastParsedClipObj
    }
    $cacheJson = $cacheObj | ConvertTo-Json -Depth 4
    Set-Content -Path $cacheFilePath -Value $cacheJson
    Write-Host ("  [CACHE] Updated: " + $cacheFilePath) -ForegroundColor Gray
}

Write-Host ""
Write-Host ("[DONE] Finished! Processed " + $successCount + " item(s) across " + $targetCsvs.Count + " CSV target(s).") -ForegroundColor Green

# convert_to_freeshow.ps1
# Converts raw hymn text files to FreeShow-compatible format.
# - Verse markers become [Verse]
# - Refrain markers become [Chorus]
# - Chorus content is automatically duplicated after each verse
#
# USAGE:
#   .\convert_to_freeshow.ps1
#   .\convert_to_freeshow.ps1 -InputFolder "C:\Hymns\raw" -OutputFolder "C:\Hymns\output"

param (
    [string]$InputFolder  = "",
    [string]$OutputFolder = ""
)

# Resolve folders — $PWD always reflects the PowerShell working directory,
# avoiding the .NET default of System32.
$inputFolder  = if ($InputFolder  -ne "") { $InputFolder  } else { "raw_text" }
$outputFolder = if ($OutputFolder -ne "") { $OutputFolder } else { "FreeShow"  }

# Convert to absolute path using $PWD if not already rooted
if (-not [System.IO.Path]::IsPathRooted($inputFolder))  { $inputFolder  = Join-Path $PWD $inputFolder  }
if (-not [System.IO.Path]::IsPathRooted($outputFolder)) { $outputFolder = Join-Path $PWD $outputFolder }

if (-not (Test-Path $inputFolder)) {
    Write-Error "Input folder not found: $inputFolder"
    exit 1
}

if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

$files = Get-ChildItem -Path "$inputFolder\*.txt" | Sort-Object Name

foreach ($file in $files) {

    # Read raw bytes and decode as UTF-8 — prevents em-dash (â€") mangling
    $bytes   = [System.IO.File]::ReadAllBytes($file.FullName)
    $rawText = [System.Text.UTF8Encoding]::new($false).GetString($bytes)
    $lines   = $rawText -split "`r?`n"

    if ($lines.Count -eq 0) { continue }

    # ── 1. Extract output filename from first line ────────────────────────────
    $firstLine = $lines[0].Trim()
    $parts     = $firstLine -split '\s+[–—-]\s+', 2

    $numStr     = $parts[0].Trim() -replace '[^0-9]', ''
    $hymnNumber = if ($numStr -match '^\d+$') { [int]$numStr } else { 0 }
    $hymnTitle  = if ($parts.Count -gt 1) { $parts[1].Trim() } else { $firstLine }

    # Sanitize title — strip characters illegal in Windows filenames
    $safeName    = $hymnTitle -replace '[\\/:*?"<>|]', ''
    $safeName    = $safeName.Trim()
    $paddedNumber = $hymnNumber.ToString("000")
    $outFileName = "$paddedNumber - $safeName.txt"
    $outPath     = Join-Path $outputFolder $outFileName

    # ── 2. Parse sections (skip header lines 0-2) ────────────────────────────
    $sections    = [System.Collections.Generic.List[hashtable]]::new()
    $currentTag   = $null
    $currentLines = [System.Collections.Generic.List[string]]::new()

    for ($i = 3; $i -lt $lines.Count; $i++) {
        $stripped = $lines[$i].TrimEnd("`r")

        if ($stripped -match '^[0-9]+$') {
            if ($null -ne $currentTag) {
                $sections.Add(@{ Tag = $currentTag; Lines = $currentLines.ToArray() })
            }
            $currentTag   = "[Verse]"
            $currentLines = [System.Collections.Generic.List[string]]::new()
        }
        elseif ($stripped -imatch '^(refrain|chorus|kiitikio)$') {
            if ($null -ne $currentTag) {
                $sections.Add(@{ Tag = $currentTag; Lines = $currentLines.ToArray() })
            }
            $currentTag   = "[Chorus]"
            $currentLines = [System.Collections.Generic.List[string]]::new()
        }
        else {
            $currentLines.Add($stripped)
        }
    }

    if ($null -ne $currentTag) {
        $sections.Add(@{ Tag = $currentTag; Lines = $currentLines.ToArray() })
    }

    # ── 3. Extract chorus lines ───────────────────────────────────────────────
    $chorusLines = [System.Collections.Generic.List[string]]::new()
    foreach ($section in $sections) {
        if ($section.Tag -eq "[Chorus]") {
            $chorusLines.AddRange($section.Lines)
            break
        }
    }

    # ── 4. Build output ───────────────────────────────────────────────────────
    # Strategy: only write [Verse] sections; skip all original [Chorus] sections.
    # After every verse, inject a fresh chorus copy. This eliminates the double-
    # chorus that occurs when the source file already has a chorus after verse 1.

    $out = [System.Collections.Generic.List[string]]::new()

    $out.Add("[Intro]")
    $out.Add($hymnTitle)
    $out.Add("Hymn #$hymnNumber")
    $out.Add("")

    foreach ($section in $sections) {
        if ($section.Tag -eq "[Chorus]") {
            continue   # skip original chorus blocks — chorus is injected after each verse below
        }

        $out.Add($section.Tag)
        foreach ($l in $section.Lines) { $out.Add($l) }
        $out.Add("")

        if ($chorusLines.Count -gt 0) {
            $out.Add("[Chorus]")
            foreach ($l in $chorusLines) { $out.Add($l) }
            $out.Add("")
        }
    }

    # Write UTF-8 without BOM
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllLines($outPath, $out, $utf8NoBom)

    Write-Host "Written: $outFileName"
}

Write-Host "`nDone. $($files.Count) file(s) processed."

# ============================================================
# Generic Firebase Static Hosting Helper Script
# Drop this into ANY static website project to deploy easily!
# ============================================================

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   Firebase Static Hosting Setup & Deploy " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# ── Step 0: Check if Firebase CLI is installed ───────────────
if (-not (Get-Command "firebase" -ErrorAction SilentlyContinue)) {
    Write-Host "Firebase CLI is not installed!" -ForegroundColor Red
    if (Get-Command "npm" -ErrorAction SilentlyContinue) {
        $installFb = Read-Host -Prompt "npm is available. Do you want to install Firebase CLI now? (Y/N) [default: Y]"
        if ([string]::IsNullOrWhiteSpace($installFb)) { $installFb = "Y" }
        if ($installFb -match "^[Yy]$") {
            Write-Host "Installing firebase-tools globally..." -ForegroundColor Cyan
            & npm install -g firebase-tools
            if (-not (Get-Command "firebase" -ErrorAction SilentlyContinue)) {
                Write-Host "Failed to install or locate Firebase CLI. Please restart your terminal and try again." -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "Cannot proceed without Firebase CLI. Please install it manually:" -ForegroundColor Yellow
            Write-Host "  npm install -g firebase-tools" -ForegroundColor Cyan
            exit 1
        }
    } else {
        Write-Host "Cannot proceed. Please install Node.js (which includes npm) from https://nodejs.org/" -ForegroundColor Yellow
        Write-Host "Then run: npm install -g firebase-tools" -ForegroundColor Cyan
        exit 1
    }
}

function Get-ValidProjectId {
    param([string]$PromptText)
    while ($true) {
        $id = Read-Host -Prompt $PromptText
        if ([string]::IsNullOrWhiteSpace($id)) {
            Write-Host " ❌ Error: Project ID cannot be empty!" -ForegroundColor Red
            continue
        }

        $errors = @()

        if ($id.Length -lt 6 -or $id.Length -gt 30) {
            $errors += "Length must be between 6 and 30 characters (Yours is $($id.Length))."
        }
        if ($id -match "[^a-z0-9-]") {
            $errors += "Contains invalid characters (only lowercase letters, numbers, and hyphens are allowed)."
        }
        if (-not ($id -match "^[a-z]")) {
            $errors += "Must start with a lowercase letter (e.g. 'a'-'z')."
        }
        if ($id -match "-$") {
            $errors += "Cannot end with a hyphen."
        }

        if ($errors.Count -eq 0) {
            return $id
        }

        Write-Host "Invalid Project ID: '$id'" -ForegroundColor Red
        foreach ($err in $errors) {
            Write-Host " ❌ $err" -ForegroundColor Yellow
        }
        Write-Host "Please try again.`n" -ForegroundColor Gray
    }
}

# ── Step 0.5: Check Firebase Authentication ──────────────────
Write-Host ""
Write-Host "── Firebase Authentication ──" -ForegroundColor Cyan
Write-Host "Fetching your logged-in accounts..." -ForegroundColor Gray
$loginList = & firebase login:list 2>&1

$loginList | ForEach-Object { Write-Host "  $_" -ForegroundColor White }

Write-Host ""
Write-Host "  [1] Continue with current active account" -ForegroundColor Green
Write-Host "  [2] Switch to a different existing account" -ForegroundColor Yellow
Write-Host "  [3] Log in with a NEW account" -ForegroundColor Cyan
Write-Host ""
$authChoice = Read-Host -Prompt "Choose (1/2/3) [default: 1]"
if ([string]::IsNullOrWhiteSpace($authChoice)) { $authChoice = "1" }

switch ($authChoice.Trim()) {
    "1" {
        Write-Host "[v] Proceeding with current account." -ForegroundColor Green
    }
    "2" {
        $accountEmail = Read-Host -Prompt "Enter the email of the account to switch to"
        if (-not [string]::IsNullOrWhiteSpace($accountEmail)) {
            Write-Host "Switching account..." -ForegroundColor Cyan
            & firebase login:use $accountEmail
        }
    }
    "3" {
        Write-Host "Opening browser for new login..." -ForegroundColor Cyan
        & firebase login:add
    }
    default {
        Write-Host "[v] Proceeding with current account." -ForegroundColor Green
    }
}
Write-Host ""

# ── Step 1: Detect existing .firebaserc ──────────────────────
$existingProjectId = $null
$rcPath = ".firebaserc"

if (Test-Path $rcPath) {
    try {
        $rcJson = Get-Content $rcPath -Raw | ConvertFrom-Json
        $existingProjectId = $rcJson.projects.default
    } catch {}
}

if (-not [string]::IsNullOrWhiteSpace($existingProjectId)) {
    Write-Host "Detected existing Firebase project: " -NoNewline -ForegroundColor White
    Write-Host "$existingProjectId" -ForegroundColor Green
    Write-Host ""
    Write-Host "  [1] Use current project  ($existingProjectId)" -ForegroundColor Green
    Write-Host "  [2] Use a different project ID" -ForegroundColor Yellow
    Write-Host "  [3] Create a brand new project" -ForegroundColor Cyan
    Write-Host ""
    $choice = Read-Host -Prompt "Choose (1/2/3) [default: 1]"
    
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "1" }

    switch ($choice.Trim()) {
        "1" {
            $projectId = $existingProjectId
            Write-Host "[v] Using existing project: $projectId" -ForegroundColor Green
        }
        "2" {
            $projectId = Get-ValidProjectId -PromptText "Enter new Firebase Project ID"
        }
        "3" {
            $projectId = Get-ValidProjectId -PromptText "Enter new Firebase Project ID to create"
        }
        default {
            $projectId = $existingProjectId
            Write-Host "[v] Defaulting to existing project: $projectId" -ForegroundColor Green
        }
    }
} else {
    Write-Host "No existing Firebase project found in this directory." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] Enter an existing Firebase Project ID" -ForegroundColor Green
    Write-Host "  [2] Create a brand new Firebase project" -ForegroundColor Cyan
    Write-Host ""
    $newChoice = Read-Host -Prompt "Choose (1/2) [default: 1]"
    if ([string]::IsNullOrWhiteSpace($newChoice)) { $newChoice = "1" }

    if ($newChoice.Trim() -eq "2") {
        $projectId = Get-ValidProjectId -PromptText "Enter NEW Firebase Project ID to create"
    } else {
        $projectId = Get-ValidProjectId -PromptText "Enter EXISTING Firebase Project ID"
    }
}

Write-Host ""

# ── Step 2: Check or create project in Firebase account ──────
Write-Host "Checking Firebase account for project '$projectId'..." -ForegroundColor Cyan
$projectList = & firebase projects:list 2>&1

$projectExists = $false
foreach ($line in $projectList) {
    if ("$line" -match [regex]::Escape($projectId)) {
        $projectExists = $true
        break
    }
}

if (-not $projectExists) {
    Write-Host "Project '$projectId' not found in your Firebase account." -ForegroundColor Yellow
    $createProj = Read-Host -Prompt "Create new Firebase project '$projectId' now? (Y/N) [default: Y]"
    if ([string]::IsNullOrWhiteSpace($createProj)) { $createProj = "Y" }

    if ($createProj -match "^[Yy]$") {
        while ($true) {
            Write-Host "Creating Firebase project '$projectId'..." -ForegroundColor Cyan
            & firebase projects:create $projectId -n $projectId
            if ($LASTEXITCODE -eq 0) {
                break
            } else {
                Write-Host ""
                Write-Host "❌ Failed to create project '$projectId'." -ForegroundColor Red
                Write-Host "This usually means the ID is already taken globally by another user, or your account reached its quota." -ForegroundColor Yellow
                if (Test-Path "firebase-debug.log") {
                    $errorLine = Get-Content "firebase-debug.log" | Select-String "Error:" | Select-Object -Last 1
                    if ($errorLine) {
                        Write-Host "Reason: $errorLine" -ForegroundColor Red
                    }
                }
                Write-Host ""
                $tryAgain = Read-Host -Prompt "Do you want to try a different Project ID? (Y/N) [default: Y]"
                if ([string]::IsNullOrWhiteSpace($tryAgain)) { $tryAgain = "Y" }
                
                if ($tryAgain -match "^[Yy]$") {
                    $projectId = Get-ValidProjectId -PromptText "Enter a NEW Firebase Project ID to try"
                } else {
                    Write-Host "Exiting setup." -ForegroundColor Red
                    exit 1
                }
            }
        }
    } else {
        Write-Host "Skipped project creation. Continuing with '$projectId'..." -ForegroundColor Yellow
    }
} else {
    Write-Host "[v] Found project in Firebase: $projectId" -ForegroundColor Green
}

# ── Step 3: Write .firebaserc ─────────────────────────────────
$rcContent = @"
{
  "projects": {
    "default": "$projectId"
  }
}
"@
Set-Content -Path ".firebaserc" -Value $rcContent -Encoding UTF8
Write-Host "[v] .firebaserc updated -> $projectId" -ForegroundColor Green

# ── Step 4: Configure firebase.json ───────────────────────────
if (Test-Path "firebase.json") {
    Write-Host "[v] firebase.json already exists. Keeping existing configuration." -ForegroundColor Green
} else {
    Write-Host "No firebase.json found. Creating default configuration..." -ForegroundColor Yellow
    
    $publicDir = Read-Host -Prompt "Enter the public directory to deploy (e.g. '.', 'public', 'dist') [default: .]"
    if ([string]::IsNullOrWhiteSpace($publicDir)) {
        $publicDir = "."
    }

    $isSpa = Read-Host -Prompt "Is this a Single Page App? (redirect unknown URLs to index.html) (Y/N) [default: Y]"
    if ([string]::IsNullOrWhiteSpace($isSpa)) {
        $isSpa = "Y"
    }

    $fbConfig = @{
        hosting = @{
            public = $publicDir
            ignore = @(
                "firebase.json",
                "**/.*",
                "**/node_modules/**",
                "*.ps1"
            )
        }
    }

    if ($isSpa -match "^[Yy]$") {
        $fbConfig.hosting.Add("rewrites", @(
            @{
                source = "**"
                destination = "/index.html"
            }
        ))
    }

    $fbConfig | ConvertTo-Json -Depth 5 | Set-Content -Path "firebase.json" -Encoding UTF8
    Write-Host "[v] firebase.json generated for public directory: '$publicDir'" -ForegroundColor Green
}

# ── Step 5: Deploy ────────────────────────────────────────────
Write-Host ""
Write-Host "Target: https://$projectId.web.app" -ForegroundColor Yellow
Write-Host ""
$publishNow = Read-Host -Prompt "Deploy to Firebase Hosting now? (Y/N) [default: Y]"
if ([string]::IsNullOrWhiteSpace($publishNow)) { $publishNow = "Y" }

if ($publishNow -match "^[Yy]$") {
    Write-Host ""
    Write-Host "Deploying to https://$projectId.web.app ..." -ForegroundColor Cyan
    & firebase deploy --only hosting
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Done! Live at: https://$projectId.web.app" -ForegroundColor Green
    } else {
        Write-Host "Deployment failed. Check the errors above." -ForegroundColor Red
    }
} else {
    Write-Host ""
    Write-Host "Setup complete. Run '.\start.ps1' to deploy whenever ready!" -ForegroundColor Yellow
}

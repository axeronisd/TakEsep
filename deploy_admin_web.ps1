# ═══════════════════════════════════════════════════════════════
# TakEsep Admin — Build Web & Deploy to GitHub Pages
# ═══════════════════════════════════════════════════════════════

Write-Host "`n╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   TakEsep Admin — Web Build & Deploy         ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$ErrorActionPreference = "Stop"
$rootDir = "c:\Project TakEsep\TakEsep"
$adminDir = "$rootDir\apps\admin"
$docsAppDir = "$rootDir\docs\app"

# ── Step 1: Get dependencies ──
Write-Host "📦 [1/5] Getting dependencies..." -ForegroundColor Yellow
Set-Location $adminDir
flutter pub get
if ($LASTEXITCODE -ne 0) { Write-Host "❌ flutter pub get failed!" -ForegroundColor Red; exit 1 }
Write-Host "✅ Dependencies resolved`n" -ForegroundColor Green

# ── Step 2: Build Flutter Web ──
Write-Host "🔨 [2/5] Building Flutter Web (release)..." -ForegroundColor Yellow
flutter build web --release --base-href "/TakEsep/app/" --web-renderer canvaskit
if ($LASTEXITCODE -ne 0) { Write-Host "❌ Flutter web build failed!" -ForegroundColor Red; exit 1 }
Write-Host "✅ Web build complete`n" -ForegroundColor Green

# ── Step 3: Deploy to docs/app ──
Write-Host "📂 [3/5] Deploying to docs/app..." -ForegroundColor Yellow
if (Test-Path $docsAppDir) {
    Remove-Item -Recurse -Force $docsAppDir
}
Copy-Item -Recurse "$adminDir\build\web" $docsAppDir
Write-Host "✅ Deployed to docs/app`n" -ForegroundColor Green

# ── Step 4: Git add & commit ──
Write-Host "📝 [4/5] Committing changes..." -ForegroundColor Yellow
Set-Location $rootDir
git add docs/app
git add -A
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
git commit -m "🚀 Deploy Admin Web — $timestamp"
Write-Host "✅ Changes committed`n" -ForegroundColor Green

# ── Step 5: Push to GitHub ──
Write-Host "🚀 [5/5] Pushing to GitHub..." -ForegroundColor Yellow
git push
if ($LASTEXITCODE -ne 0) { Write-Host "❌ Git push failed!" -ForegroundColor Red; exit 1 }
Write-Host "✅ Pushed to GitHub`n" -ForegroundColor Green

Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   ✅ Admin deployed successfully!            ║" -ForegroundColor Green
Write-Host "║   🌐 https://axeronisd.github.io/TakEsep/app/ ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════╝`n" -ForegroundColor Green

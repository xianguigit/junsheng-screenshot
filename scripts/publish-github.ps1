# 君圣截图 · 首次发布到 GitHub
#
# 做四件事：建公开仓库 -> 推送 main -> 开启 GitHub Pages(main /docs) -> 等构建完成
# 用法：在 PowerShell 里执行
#   powershell -NoProfile -ExecutionPolicy Bypass -File "D:\我的小工具\君圣截图成品\scripts\publish-github.ps1"
#
# token 只在本次进程内使用：不写 .git/config、不写 .git-credentials、不回显；
# 推送结束后请到 https://github.com/settings/tokens 撤销。

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Owner = 'xianguigit'
$Repo  = 'junsheng-screenshot'
$Root  = Split-Path -Parent $PSScriptRoot
$Api   = 'https://api.github.com'
$Site  = "https://$Owner.github.io/$Repo/"

function Info($m) { Write-Host "[*]  $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[OK] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[!]  $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "[x]  $m" -ForegroundColor Red; exit 1 }

# ---------- 代理 ----------
$ProxyUrl = $null
try {
    $ie = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
    if ($ie.ProxyEnable -eq 1 -and $ie.ProxyServer) {
        $raw = [string]$ie.ProxyServer
        $m = [regex]::Match($raw, '([\w\.\-]+:\d+)')
        if ($m.Success) { $ProxyUrl = 'http://' + $m.Groups[1].Value }
    }
} catch { }
if ($ProxyUrl) { Info "系统代理 $ProxyUrl" } else { Warn '未检测到系统代理，尝试直连（国内直连 github 通常不通）' }

$Prox = @{}
if ($ProxyUrl) { $Prox['Proxy'] = $ProxyUrl }

# ---------- token ----------
Write-Host ''
Write-Host '需要 GitHub Personal Access Token（classic，勾 repo 权限）' -ForegroundColor White
Write-Host '生成地址：https://github.com/settings/tokens/new' -ForegroundColor DarkGray
Write-Host ''
$secure = Read-Host '粘贴 token 后回车（输入不显示）' -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
$Token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
$Token = $Token.Trim()
if ([string]::IsNullOrWhiteSpace($Token)) { Die 'token 为空' }

$H = @{
    Authorization = "token $Token"
    Accept        = 'application/vnd.github+json'
    'User-Agent'  = 'junsheng-deploy'
}

Info '校验 token...'
try {
    $me = Invoke-RestMethod -Uri "$Api/user" -Headers $H @Prox
} catch {
    Die 'token 无效或网络不通（401/超时）'
}
if ($me.login -ne $Owner) { Warn "token 属于 $($me.login)，和预期账号 $Owner 不一致，继续但请确认" }
Ok "已登录 $($me.login)"

# ---------- 建仓库 ----------
Info "检查仓库 $Owner/$Repo ..."
$repoExists = $true
try {
    Invoke-RestMethod -Uri "$Api/repos/$Owner/$Repo" -Headers $H @Prox | Out-Null
    Ok '仓库已存在'
} catch {
    $code = 0
    try { $code = [int]$_.Exception.Response.StatusCode } catch { }
    if ($code -eq 404) { $repoExists = $false } else { Die "读取仓库失败（HTTP $code）" }
}

if (-not $repoExists) {
    Info '创建公开仓库...'
    $body = @{
        name        = $Repo
        description = '君圣截图 · Windows 截图与录屏工具（成品与官网）'
        private     = $false
        has_issues  = $false
        has_wiki    = $false
        has_projects = $false
    } | ConvertTo-Json
    try {
        Invoke-RestMethod -Method Post -Uri "$Api/user/repos" -Headers $H -Body $body -ContentType 'application/json' @Prox | Out-Null
        Ok "已创建 https://github.com/$Owner/$Repo"
    } catch {
        Die "创建仓库失败：$($_.Exception.Message)"
    }
}

# ---------- 推送 ----------
$st = & git -C $Root status --porcelain 2>&1
if ($st) { Warn '工作区有未提交改动，本次只推送已提交的版本' }

Info '推送 main（约 38 MB，1~2 分钟）...'
$url = "https://$Token@github.com/$Owner/$Repo.git"
$pushArgs = @('-C', $Root)
if ($ProxyUrl) { $pushArgs += @('-c', "http.proxy=$ProxyUrl", '-c', "https.proxy=$ProxyUrl") }
$pushArgs += @('push', '-f', $url, 'main')

& git @pushArgs 2>&1 | ForEach-Object { Write-Host ($_ -replace [regex]::Escape($Token), '***') }
if ($LASTEXITCODE -ne 0) { Die '推送失败，检查代理或 token 权限' }
Ok '推送完成'

# ---------- 开启 Pages ----------
$pagesUri = "$Api/repos/$Owner/$Repo/pages"
$hasPages = $true
try { Invoke-RestMethod -Uri $pagesUri -Headers $H @Prox | Out-Null }
catch {
    $c = 0
    try { $c = [int]$_.Exception.Response.StatusCode } catch { }
    if ($c -eq 404) { $hasPages = $false } else { Warn "读取 Pages 状态失败（HTTP $c）" }
}

Info '配置 GitHub Pages：main 分支 /docs 目录...'
$pbody = @{ source = @{ branch = 'main'; path = '/docs' } } | ConvertTo-Json -Depth 4
try {
    if ($hasPages) {
        Invoke-RestMethod -Method Put -Uri $pagesUri -Headers $H -Body $pbody -ContentType 'application/json' @Prox | Out-Null
        Ok 'Pages 已重新指向 main /docs'
    } else {
        Invoke-RestMethod -Method Post -Uri $pagesUri -Headers $H -Body $pbody -ContentType 'application/json' @Prox | Out-Null
        Ok 'Pages 已开启'
    }
} catch {
    Warn "Pages 配置返回：$($_.Exception.Message)"
    Warn '可以在网页里手动开：Settings -> Pages -> main / docs'
}

# ---------- 等构建 ----------
Info '等待 Pages 构建（最多 2 分钟）...'
$status = ''
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Seconds 3
    try {
        $b = Invoke-RestMethod -Uri "$pagesUri/builds/latest" -Headers $H @Prox
        $status = [string]$b.status
        if ($status -and $status -ne 'building' -and $status -ne 'queued') { break }
    } catch { }
}
if ($status -eq 'built') { Ok 'Pages 构建完成' }
elseif ($status) { Warn "Pages 构建状态：$status（稍后会自动完成）" }
else { Warn '暂时读不到构建状态，稍后刷新即可' }

# ---------- 结果 ----------
Write-Host ''
Ok "官网地址：$Site"
Ok "仓库地址：https://github.com/$Owner/$Repo"
Write-Host ''
Write-Host '发布完成后请撤销这个 token：https://github.com/settings/tokens' -ForegroundColor Yellow
Write-Host '（若打开官网还是 404，等 1~2 分钟 Pages 生效后再刷新）' -ForegroundColor DarkGray

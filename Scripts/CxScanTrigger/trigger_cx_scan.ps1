<#
.SYNOPSIS
    自動觸發 Checkmarx SAST 程式碼掃描的 PowerShell 腳本。

.DESCRIPTION
    此腳本會自動執行以下流程：
    1. 登入 Checkmarx 取得 Access Token。
    2. 根據專案名稱搜尋 Project ID。
    3. 呼叫 API 觸發新的掃描任務 (支援增量掃描設定)。
    4. 回傳新建立的 Scan ID。

.PARAMETER CxServer
    Checkmarx 伺服器網址 (例如 https://cx-server.local)。

.PARAMETER Username
    使用者帳號。

.PARAMETER Password
    使用者密碼。

.PARAMETER ProjectName
    要觸發掃描的專案名稱 (支援模糊搜尋，但建議精確名稱以免誤觸)。

.PARAMETER Incremental
    [Switch] 是否執行增量掃描 (預設為完整掃描)。

.PARAMETER ForceScan
    [Switch] 是否強制掃描 (即使程式碼無變更)。

.EXAMPLE
    .\trigger_cx_scan.ps1 -CxServer "https://cx.example.com" -Username "admin" -Password "123456" -ProjectName "MyProject" -Incremental
#>

[CmdletBinding()]
param (
    [string]$CxServer,

    [string]$Username,

    [string]$Password,

    [string]$ProjectName,

    [switch]$Incremental,

    [switch]$ForceScan,

    [switch]$Help,

    [Parameter(ValueFromRemainingArguments=$true)]
    $RemainingArgs
)

function Show-Usage {
    Write-Host "用法 (Usage):" -ForegroundColor Cyan
    Write-Host "    .\trigger_cx_scan.ps1 -CxServer <URL> -Username <User> -Password <Pass> -ProjectName <Project> [-Incremental] [-ForceScan]"
    Write-Host ""
    Write-Host "參數說明:"
    Write-Host "    -CxServer      (必要) Checkmarx 伺服器網址 (例如 https://cx-server.local)"
    Write-Host "    -Username      (必要) 使用者帳號"
    Write-Host "    -Password      (必要) 使用者密碼"
    Write-Host "    -ProjectName   (必要) 要觸發掃描的專案名稱"
    Write-Host "    -Incremental   (選填) 是否執行增量掃描 (預設: 完整掃描)"
    Write-Host "    -ForceScan     (選填) 是否強制掃描 (預設: 否)"
    Write-Host "    -Help          顯示此說明"
    Write-Host ""
}

# 1. 檢查是否要求顯示說明
if ($Help) {
    Show-Usage
    exit 0
}

# 2. 檢查是否有未識別的多餘參數
if ($null -ne $RemainingArgs -and $RemainingArgs.Count -gt 0) {
    Write-Host ("錯誤：偵測到未識別的參數或值: {0}" -f ($RemainingArgs -join ", ")) -ForegroundColor Red
    Show-Usage
    exit 1
}

# 3. 檢查必要參數
if ([string]::IsNullOrWhiteSpace($CxServer) -or 
    [string]::IsNullOrWhiteSpace($Username) -or 
    [string]::IsNullOrWhiteSpace($Password) -or 
    [string]::IsNullOrWhiteSpace($ProjectName)) {
    Write-Host "錯誤：缺少必要參數。" -ForegroundColor Red
    Write-Host ""
    Show-Usage
    exit 1
}

# --- 忽略 SSL 憑證錯誤 (僅限地端版自簽憑證環境) ---
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# --- 輔助函式：顯示訊息 ---
function Log-Info { param([string]$msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Log-Error { param([string]$msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }
function Log-Success { param([string]$msg) Write-Host "[SUCCESS] $msg" -ForegroundColor Green }

try {
    # 1. 取得 Access Token
    Log-Info "正在登入 Checkmarx ($CxServer)..."
    $tokenUrl = "$CxServer/cxrestapi/auth/identity/connect/token"
    $authBody = @{
        grant_type    = "password"
        username      = $Username
        password      = $Password
        scope         = "sast_rest_api"
        client_id     = "resource_owner_client"
        client_secret = "014DF517-39D1-4453-B7B3-9930C563627C"
    }

    $authResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -ContentType "application/x-www-form-urlencoded" -Body $authBody
    $token = $authResponse.access_token
    $headers = @{ "Authorization" = "Bearer $token" }
    Log-Info "登入成功！"

    # 2. 搜尋專案以取得 Project ID
    Log-Info "正在搜尋專案 '$ProjectName'цій..."
    $projectsUrl = "$CxServer/cxrestapi/projects?projectName=$ProjectName"
    $projects = Invoke-RestMethod -Uri $projectsUrl -Method Get -Headers $headers
    
    if ($projects.Count -eq 0) {
        throw "找不到名稱包含 '$ProjectName' 的專案。"
    }
    
    # 取第一個匹配的專案
    $targetProject = $projects | Select-Object -First 1
    $projectId = $targetProject.id
    Log-Info "找到專案: $($targetProject.name) (ID: $projectId)"

    # 3. 觸發掃描
    Log-Info "準備觸發掃描..."
    if ($Incremental) { Log-Info "模式: 增量掃描 (Incremental)" } else { Log-Info "模式: 完整掃描 (Full Scan)" }

    $scanUrl = "$CxServer/cxrestapi/sast/scans"
    $scanBody = @{
        projectId     = $projectId
        isIncremental = [bool]$Incremental
        isPublic      = $true
        forceScan     = [bool]$ForceScan
        comment       = "Triggered via PowerShell Automation Script"
    } | ConvertTo-Json

    $scanResponse = Invoke-RestMethod -Uri $scanUrl -Method Post -Headers $headers -ContentType "application/json" -Body $scanBody
    
    $newScanId = $scanResponse.id
    Log-Success "掃描觸發成功！"
    Log-Success "New Scan ID: $newScanId"
    
    Write-Host ""
    Write-Host "您可以稍後使用下載腳本，指定 Scan ID 或再次使用專案名稱來下載報告。" -ForegroundColor Gray

} catch {
    Log-Error "發生錯誤: $_"
    if ($_.Exception.Response) {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = New-Object System.IO.StreamReader($stream)
            $responseBody = $reader.ReadToEnd()
            Log-Error "伺服器回應詳細內容 (Server Response Details): $responseBody"
        }
    }
    exit 1
}

<#
.SYNOPSIS
    自動下載 Checkmarx SAST 掃描報告的 PowerShell 腳本。

.DESCRIPTION
    此腳本會自動執行以下流程：
    1. 登入 Checkmarx 取得 Access Token。
    2. 根據專案名稱搜尋最新的 Scan ID。
    3. 請求產生報告 (預設為 PDF)。
    4. 輪詢檢查報告產生狀態。
    5. 下載報告至指定路徑。

.PARAMETER CxServer
    Checkmarx 伺服器網址 (例如 https://cx-server.local)。

.PARAMETER Username
    使用者帳號。

.PARAMETER Password
    使用者密碼。

.PARAMETER ProjectName
    要下載報告的專案名稱 (支援模糊搜尋)。

.PARAMETER ReportType
    報告格式 (PDF, XML, CSV, RTF)。預設為 PDF。

.PARAMETER OutputPath
    報告儲存路徑。若未指定，將儲存於當前目錄。

.EXAMPLE
    .\download_cx_report.ps1 -CxServer "https://cx.example.com" -Username "admin" -Password "123456" -ProjectName "MyProject"
#>

[CmdletBinding()]
param (
    [string]$CxServer,

    [string]$Username,

    [string]$Password,

    [string]$ProjectName,

    [ValidateSet("PDF", "XML", "CSV", "RTF")]
    [string]$ReportType = "PDF",

    [string]$OutputPath = ".\CxReport",

    [string]$ReportFileName,

    [switch]$Help,

    [Parameter(ValueFromRemainingArguments=$true)]
    $RemainingArgs
)

function Show-Usage {
    Write-Host "用法 (Usage):" -ForegroundColor Cyan
    Write-Host "    .\download_cx_report.ps1 -CxServer <URL> -Username <User> -Password <Pass> -ProjectName <Project> [-ReportType <Type>] [-OutputPath <Path>] [-ReportFileName <Name>]"
    Write-Host ""
    Write-Host "參數說明:"
    Write-Host "    -CxServer      (必要) Checkmarx 伺服器網址 (例如 https://cx-server.local)"
    Write-Host "    -Username      (必要) 使用者帳號"
    Write-Host "    -Password      (必要) 使用者密碼"
    Write-Host "    -ProjectName   (必要) 要下載報告的專案名稱 (支援模糊搜尋)"
    Write-Host "    -ReportType    (選填) 報告格式: PDF, XML, CSV, RTF (預設: PDF)"
    Write-Host "    -OutputPath    (選填) 報告儲存路徑 (預設: .\CxReport)"
    Write-Host "    -ReportFileName (選填) 指定輸出的檔案名稱 (預設: 自動產生 {Project}_{ScanID}_{Time})"
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
    Log-Info "正在搜尋專案 '$ProjectName'..."
    $projectsUrl = "$CxServer/cxrestapi/projects?projectName=$ProjectName"
    $projects = Invoke-RestMethod -Uri $projectsUrl -Method Get -Headers $headers
    
    if ($projects.Count -eq 0) {
        throw "找不到名稱包含 '$ProjectName' 的專案。"
    }
    
    # 取第一個匹配的專案 (若有多個，可在此邏輯調整)
    $targetProject = $projects | Select-Object -First 1
    $projectId = $targetProject.id
    Log-Info "找到專案: $($targetProject.name) (ID: $projectId)"

    # 3. 取得該專案最新的 Scan ID
    Log-Info "正在取得最新的掃描紀錄..."
    $scansUrl = "$CxServer/cxrestapi/sast/scans?projectId=$projectId&last=1&scanStatus=Finished"
    $scans = Invoke-RestMethod -Uri $scansUrl -Method Get -Headers $headers

    if ($scans.Count -eq 0) {
        throw "該專案沒有已完成的掃描紀錄。"
    }

    $scanId = $scans[0].id
    Log-Info "最新 Scan ID: $scanId (完成時間: $($scans[0].dateAndTime.finished))"

    # 4. 請求產生報告
    Log-Info "請求產生 $ReportType 報告..."
    $reportUrl = "$CxServer/cxrestapi/reports/sastScan"
    $reportBody = @{
        reportType = $ReportType
        scanId     = $scanId
    } | ConvertTo-Json

    $reportResponse = Invoke-RestMethod -Uri $reportUrl -Method Post -Headers $headers -ContentType "application/json" -Body $reportBody
    $reportId = $reportResponse.reportId
    Log-Info "報告請求已送出，Report ID: $reportId"

    # 5. 輪詢檢查報告狀態
    $statusUrl = "$CxServer/cxrestapi/reports/sastScan/$reportId/status"
    do {
        Start-Sleep -Seconds 3
        $statusResponse = Invoke-RestMethod -Uri $statusUrl -Method Get -Headers $headers
        $status = $statusResponse.status.value
        Log-Info "報告狀態: $status..."
    } while ($status -notin @("Created", "Failed"))

    if ($status -ne "Created") {
        # 注意: API 回傳 "Created" 代表完成，或是部分版本回傳 "Finished"
        # 若狀態不是這兩者且迴圈結束，可能失敗
        # 這裡的邏輯依賴 Checkmarx 版本，通常 Created 後即可下載
        # 嚴謹檢查：若 API 失敗會回傳 Failed
        if ($status -eq "Failed") { throw "報告產生失敗。" }
    }

    # 6. 下載報告
    Log-Info "正在下載報告..."
    
    # 處理輸出檔名
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
    }
    
    if (-not [string]::IsNullOrWhiteSpace($ReportFileName)) {
        # 若使用者有指定檔名，檢查是否包含副檔名，若無則自動補上
        $ext = "." + $ReportType.ToLower()
        if (-not $ReportFileName.EndsWith($ext, [System.StringComparison]::OrdinalIgnoreCase)) {
            $ReportFileName += $ext
        }
        $fileName = $ReportFileName
    } else {
        # 預設檔名格式: ProjectName_ScanID_TimeStamp.pdf
        $timeStamp = Get-Date -Format "yyyyMMdd-HHmm"
        $fileName = "$($targetProject.name)_Scan$($scanId)_$timeStamp.$($ReportType.ToLower())"
    }
    
    $fullPath = Join-Path $OutputPath $fileName

    $downloadUrl = "$CxServer/cxrestapi/reports/sastScan/$reportId"
    Invoke-RestMethod -Uri $downloadUrl -Method Get -Headers $headers -OutFile $fullPath

    Log-Info "報告下載完成！"
    Log-Info "檔案位置: $fullPath"

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

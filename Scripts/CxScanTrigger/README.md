# CxScanTrigger

此目錄包含用於自動觸發 Checkmarx SAST 掃描的工具腳本。

## trigger_cx_scan.ps1

這是一個 PowerShell 腳本，用於呼叫 Checkmarx API 觸發新的程式碼掃描任務。

### 功能
*   **自動登入**：自動處理 OAuth2 驗證流程。
*   **專案對應**：透過專案名稱查找 Project ID。
*   **掃描控制**：支援完整掃描與增量掃描 (Incremental)。

### 參數說明

| 參數 | 說明 | 是否必填 | 預設值 |
| :--- | :--- | :--- | :--- |
| `-CxServer` | Checkmarx 伺服器網址 | 是 | 無 |
| `-Username` | 登入帳號 | 是 | 無 |
| `-Password` | 登入密碼 | 是 | 無 |
| `-ProjectName` | 專案名稱 | 是 | 無 |
| `-Incremental` | 是否啟用增量掃描 | 否 | False |
| `-ForceScan` | 強制掃描 (即使無變更) | 否 | False |

### 使用範例

**執行增量掃描**
```powershell
.\trigger_cx_scan.ps1 -CxServer "https://cx.local" -Username "admin" -Password "pw" -ProjectName "MyApp" -Incremental
```


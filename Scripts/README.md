# Checkmarx 自動化工具腳本

本目錄包含用於與 Checkmarx SAST 互動的實用腳本。

## download_cx_report.ps1

這是一個 PowerShell 腳本，用於自動下載指定專案最新的 SAST 掃描報告。

### 執行方式

您可以使用 PowerShell 直接執行，或使用提供的批次檔 wrapper：

**方式 1：PowerShell 直接執行**
```powershell
.\download_cx_report.ps1 ...
```

**方式 2：使用 Batch 檔 (CMD)**
```batch
.\run_download_cx_report.bat ...
```
*(此批次檔會自動設定 ExecutionPolicy Bypass，方便在受限環境下執行)*

### 功能
*   **自動登入**：自動處理 OAuth2 驗證流程，取得 Access Token。
*   **智慧搜尋**：根據專案名稱搜尋 Project ID。
*   **報告生成**：自動請求生成最新一次掃描的報告（支援 PDF, XML, CSV, RTF）。
*   **自動下載**：輪詢檢查報告狀態，待生成完畢後自動下載至指定路徑。

### 參數說明

| 參數 | 說明 | 是否必填 | 預設值 |
| :--- | :--- | :--- | :--- |
| `-CxServer` | Checkmarx 伺服器網址 (如 `https://cx.local`) | 是 | 無 |
| `-Username` | 登入帳號 | 是 | 無 |
| `-Password` | 登入密碼 | 是 | 無 |
| `-ProjectName` | 專案名稱 (支援模糊搜尋) | 是 | 無 |
| `-ReportType` | 報告格式 (PDF, XML, CSV, RTF) | 否 | PDF |
| `-OutputPath` | 檔案儲存路徑 | 否 | `.\CxReport` |
| `-ReportFileName` | 指定輸出的檔案名稱 | 否 | 自動產生 ({Project}_{ScanID}_{Time}) |

### 使用範例

**基本用法 (下載 PDF)**
```powershell
.\download_cx_report.ps1 -CxServer "https://cx-server.local" `
                         -Username "admin" `
                         -Password "123456" `
                         -ProjectName "MyWebProject"
```

**自訂檔名與輸出格式**
```powershell
.\download_cx_report.ps1 -CxServer "https://cx-server.local" `
                         -Username "admin" `
                         -Password "123456" `
                         -ProjectName "MyWebProject" `
                         -ReportType "PDF" `
                         -OutputPath ".\Reports" `
                         -ReportFileName "MyCustomReport"
# 結果檔案: .\Reports\MyCustomReport.pdf (副檔名會自動補上)
```

**下載 XML 報告至指定資料夾**
```powershell
.\download_cx_report.ps1 -CxServer "https://cx-server.local" `
                         -Username "admin" `
                         -Password "123456" `
                         -ProjectName "MyWebProject" `
                         -ReportType "XML" `
                         -OutputPath "C:\Temp\Reports"
```

### 注意事項
*   此腳本預設會忽略 SSL 憑證錯誤 (`ServerCertificateValidationCallback = { $true }`)，以支援使用自簽憑證的地端環境。

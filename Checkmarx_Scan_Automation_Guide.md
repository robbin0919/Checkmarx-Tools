# Checkmarx SAST 掃描自動化指南

本文件說明如何將 Checkmarx SAST (Static Application Security Testing) 掃描流程自動化，以整合至 CI/CD Pipeline 或排程任務中。

## 掃描自動化的兩種主要途徑

目前主要有兩種方式可以達成自動化掃描：

### 1. 使用 Checkmarx CLI (CxConsole)
官方提供的命令行工具 (Java-based)，適合大多數 CI/CD 場景。

*   **優點**：
    *   官方維護與支援。
    *   指令參數完整 (支援檔案過濾、報告生成、門檻設定等)。
    *   封裝了複雜的 API 互動邏輯。
*   **缺點**：
    *   需要依賴 Java 環境。
    *   需要下載並安裝 CLI 工具包。
*   **適用場景**：Jenkins, Azure DevOps, GitLab CI 等標準流水線。

**指令範例**：
```bash
./runCxConsole.sh scan -v -Projectname "MyProject" -CxServer "https://cx.local" -CxUser "admin" -CxPassword "password" -LocationType folder -LocationPath "/source/code"
```

---


### 2. 使用 REST API (PowerShell / Python 腳本)
直接呼叫 Checkmarx REST API，適合輕量級自動化或自定義需求。

*   **優點**：
    *   **輕量**：無需安裝額外軟體 (只要有 PowerShell 或 Python)。
    *   **彈性**：可自由控制邏輯 (例如：掃描前先檢查 Git 狀態，或掃描後自動發送 Teams 通知)。
    *   **易於整合**：適合用在 Windows 排程、簡易 Batch 腳本或管理員維運工具中。
*   **缺點**：
    *   需自行處理身份驗證 (Auth) 與 Token 管理。
*   **適用場景**：管理員維運腳本、無法安裝 Java 的環境、高度客製化流程。

## PowerShell 自動化腳本範例

我們提供了一個 PowerShell 腳本範例，展示如何透過 API 觸發掃描。

### 腳本位置
`Scripts/CxScanTrigger/trigger_cx_scan.ps1`

### 功能
*   **自動登入**：取得 Access Token。
*   **智慧搜尋**：根據專案名稱自動查找 Project ID。
*   **觸發掃描**：支援設定「增量掃描 (Incremental)」與「強制掃描 (Force Scan)」。

### 使用方式

**基本掃描 (完整掃描)**
```powershell
.\trigger_cx_scan.ps1 -CxServer "https://cx.local" -Username "admin" -Password "123456" -ProjectName "MyProject"
```

**增量掃描 (速度較快，僅掃描變更部分)**
```powershell
.\trigger_cx_scan.ps1 -CxServer "https://cx.local" -Username "admin" -Password "123456" -ProjectName "MyProject" -Incremental
```

### 腳本邏輯解析

該腳本主要呼叫以下 API：

1.  **登入** (`POST /auth/identity/connect/token`): 取得 Bearer Token。
2.  **查詢專案** (`GET /projects?projectName=...`): 獲取專案的內部 ID。
3.  **建立掃描** (`POST /sast/scans`): 
    *   Payload 範例：
        ```json
        {
          "projectId": 12345,
          "isIncremental": true,
          "isPublic": true,
          "forceScan": false,
          "comment": "Triggered via Automation"
        }
        ```

## 常見問題 (FAQ)

**Q: 掃描需要多久？**
A: 取決於程式碼行數 (LOC) 與複雜度。建議在自動化流程中設定 `Asynchronous` (非同步) 模式，觸發後即結束腳本，後續再透過輪詢 (Polling) 檢查狀態，以免 CI Job Timeout。

**Q: 什麼時候該用增量掃描？**
A: 平時 CI/CD (如每次 Commit 或 PR) 建議使用 **增量掃描** 以節省時間。但在重大版本發布或每週定期排程時，建議執行 **完整掃描** 以確保涵蓋率。

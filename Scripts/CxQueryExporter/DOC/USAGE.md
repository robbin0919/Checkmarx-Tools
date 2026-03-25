# CxQueryExporter 使用指南

本文件說明如何配置、編譯及執行 `CxQueryExporter` 工具，以從 Checkmarx SAST 伺服器匯出 CxQL 查詢腳本。

## 前置作業

1.  **環境需求**：
    *   安裝有 **.NET 8 SDK** 的 Windows、Linux 或 macOS 環境。
    *   可連通 Checkmarx SAST 伺服器的網路環境。
2.  **權限需求**：
    *   一個具備 API 存取權限的 Checkmarx 帳號（建議具備管理員權限以確保能讀取所有查詢）。

## 使用步驟

### 1. (選填) 修改預設配置

檔案路徑：`checkmarx/Automation/Scripts/CxQueryExporter/Program.cs`

若您不希望在執行時提供參數，可以預先修改 `_cxServer`、`_username` 等變數。

### 2. 透過 CLI 執行 (推薦)

您可以直接在執行時提供參數，這非常適合整合進 CI/CD 或自動化腳本。

```bash
# 進入專案目錄
cd checkmarx/Automation/Scripts/CxQueryExporter

# 顯示幫助資訊
dotnet run -- --help

# 完整匯出指令範例
dotnet run -- -s https://cx.example.com -u admin -p 123456 -o ./CxQueries_Export
```

**參數選項：**
*   `-s, --server <URL>`：Checkmarx 伺服器網址
*   `-u, --user <Username>`：使用者帳號
*   `-p, --pass <Password>`：使用者密碼
*   `-o, --output <Dir>`：匯出儲存目錄 (預設: ./CxQueries_Export)
*   `-h, --help`：顯示幫助訊息

### 3. 查看結果

執行成功後，程式會在 `OutputDir` 指定的目錄下建立結構化的檔案。

**目錄結構範例：**
```text
CxQueries_Export/
├── CSharp/
│   ├── General/
│   │   ├── Find_XSS_Sanitize.txt
│   │   └── Find_SQL_Injection.txt
│   └── CSharp_High_Risk/
│       └── SQL_Injection.txt
├── Java/
│   └── ...
└── ...
```

## 進階說明

### SSL 憑證問題
如果您的 Checkmarx 伺服器使用自簽憑證（Self-signed Certificate），程式預設已開啟「忽略 SSL 驗證」功能：
```csharp
var handler = new HttpClientHandler
{
    ServerCertificateCustomValidationCallback = (message, cert, chain, errors) => true
};
```
*註：若在正式生產環境且有匯入憑證，可視安全性需求調整此設定。*

### 檔案名稱處理
由於 Checkmarx 查詢名稱可能包含 Windows 檔案系統不允許的字元（如 `:`），本工具會自動將非法字元替換為底線 `_`，以確保檔案能成功建立。

## 常見問題排查

1.  **認證失敗 (401 Unauthorized)**：
    *   請檢查 `Username` 與 `Password`。
    *   檢查 `ClientSecret` 是否與伺服器設定一致（預設值適用於大多數環境）。
2.  **連線超時 (Timeout)**：
    *   請檢查 `CxServer` 網址是否正確。
    *   確認防火牆是否允許存取該伺服器的 443 或 80 埠。

---
*文件產生於 2026-03-25*

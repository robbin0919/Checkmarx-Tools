# CxQueryExporter 使用指南

本文件說明如何配置、編譯及執行 `CxQueryExporter` 工具，以從 Checkmarx SAST 伺服器匯出 CxQL 查詢腳本。

## 前置作業

1.  **環境需求**：
    *   安裝有 **.NET 8 SDK** 的 Windows、Linux 或 macOS 環境。
    *   可連通 Checkmarx SAST 伺服器的網路環境。
2.  **權限需求**：
    *   一個具備 API 存取權限的 Checkmarx 帳號（建議具備管理員權限以確保能讀取所有查詢）。

## 使用步驟

### 1. 修改配置資訊

在執行之前，您必須修改 `Program.cs` 中的配置區塊：

檔案路徑：`checkmarx/Automation/Scripts/CxQueryExporter/Program.cs`

```csharp
// --- 配置區 ---
private const string CxServer = "https://your-checkmarx-server"; // 修改為您的 Cx 伺服器網址
private const string Username = "your_username";               // 修改為您的帳號
private const string Password = "your_password";               // 修改為您的密碼
private const string OutputDir = "./CxQueries_Export";         // 匯出檔案的儲存目錄
```

### 2. 編譯與執行

在終端機（Terminal 或 PowerShell）中進入專案目錄，執行以下指令：

```bash
# 進入專案目錄
cd checkmarx/Automation/Scripts/CxQueryExporter

# 執行程式
dotnet run
```

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

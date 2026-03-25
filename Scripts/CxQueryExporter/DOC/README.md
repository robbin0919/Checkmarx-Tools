# CxQueryExporter 功能說明文件

`CxQueryExporter` 是一個基於 .NET 8 開發的自動化工具，專門用於從 Checkmarx SAST 伺服器匯出靜態應用程式安全測試 (SAST) 的程式碼分析查詢腳本 (CxQL)。

## 核心功能

### 1. 自動化身份認證 (OAuth2 Authentication)
*   **認證流程**：實作了 Checkmarx 標準的 OAuth2 `password` 授權模式。
*   **Token 取得**：自動向伺服器的 Token 端點 (`/cxrestapi/auth/identity/connect/token`) 請求 `access_token`。
*   **安全驗證**：支援使用 `client_id` 與 `client_secret` 進行身分驗證，確保連線安全性。

### 2. 全量抓取與解析 (REST API Integration)
*   **API 串接**：透過 Checkmarx REST API (`/cxrestapi/sast/queries/all`) 抓取伺服器上所有受支援語言（如 C#、Java、Python、JavaScript 等）的查詢腳本。
*   **高效解析**：使用 `System.Text.Json` 解析複雜的巢狀 JSON 數據結構，確保處理大量查詢時的效能與穩定性。

### 3. 結構化目錄與檔案管理 (Structured Export)
*   **自動分類儲存**：根據查詢所屬的「程式語言」與「群組類別」自動建立多層級資料夾結構。
    *   範例路徑：`./CxQueries_Export/CSharp/SQL_Injection/SQL_Injection.txt`
*   **檔名安全性處理**：自動偵測並清理查詢名稱中不符合 Windows/Linux 檔案系統規範的非法字元（如 `:`、`*`、`?`、`"`、`<`、`>`、`|` 等），確保檔案能正確儲存。

### 4. 企業環境相容性 (Enterprise Readiness)
*   **忽略 SSL 驗證**：針對內部網路常見的「自簽憑證 (Self-signed Certificate)」環境，提供忽略 SSL 驗證的處理機制，避免連線失敗。
*   **異步處理 (Async/Await)**：採用現代化的異步 I/O 模型，在處理數千個查詢檔案時能保持最佳效能。

## 專案用途
*   **版本控制**：方便將 CxQL 查詢腳本匯出並存入 Git 倉庫，追蹤安全規則的變更歷程。
*   **離線研究**：在不連接 Checkmarx 伺服器的情況下，直接閱讀與分析內建或自定義的掃描規則。
*   **環境備份與遷移**：作為備份工具，方便在不同 Checkmarx 環境間遷移自定義查詢規則。

## 檔案結構
*   `Program.cs`: 主要邏輯實作。
*   `CxQueryExporter.csproj`: 專案配置文件與依賴項。
*   `CHANGELOG.md`: 變更記錄檔。
*   `DOC/README.md`: 本說明文件。

---
*文件產生於 2026-03-25*

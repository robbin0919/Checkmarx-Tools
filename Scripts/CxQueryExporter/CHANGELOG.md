# 變更紀錄 - CxQueryExporter

此專案的所有顯著變更都將記錄在此檔案中。

## [1.0.0] - 2026-03-25

### 新增內容
- 建立 .NET 8 控制台應用程式的初始專案結構。
- `CxQueryExporter.csproj`：包含 `System.Text.Json` 依賴項的專案配置。
- `Program.cs`：實作 Checkmarx CxQL 查詢腳本匯出邏輯（使用 REST API）。
  - 支援 OAuth2 身份認證（密碼授權模式 Password Grant Type）。
  - 根據程式語言與群組名稱自動建立目錄結構。
  - 對查詢名稱進行檔名清理，確保檔案系統儲存安全。
  - 支援內部伺服器忽略 SSL 憑證驗證。
- `CHANGELOG.md`：追蹤專案變更的說明文件。

---
*由 Robbin Lee 建立*

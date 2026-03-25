# 身份認證 Client Secret 差異說明

本文件說明 `CxQueryExporter` (C#) 與 `download_cx_report.ps1` (PowerShell) 在身份認證時使用不同 `client_secret` 的原因及其影響。

## 數值比對

| 工具名稱 | 開發語言 | Client Secret 數值 |
| :--- | :--- | :--- |
| **download_cx_report.ps1** | PowerShell | `014DF517-39D1-4453-B7B3-9930C563627C` |
| **CxQueryExporter** | C# (.NET 8) | `014498e2-4d10-4f4c-87f1-fa14f4f7cd78` |

## 差異原因

這兩個數值都是 Checkmarx 系統中**內建且公開的預設值**。它們之所以不同，是因為源自於不同的 Checkmarx 官方技術資源：

1.  **`014498e2...` (常用於 API)**：
    這是 Checkmarx REST API 官方文件中最通用的 `resource_owner_client` 預設 Secret。目前的 `CxQueryExporter` 採用此值。
2.  **`014DF517...` (常用於 CLI)**：
    這是 Checkmarx 某些特定版本、範例腳本或內建工具（如舊版 CLI 掃描工具）使用的預設值。`download_cx_report.ps1` 參考了此類實作。

## 相容性與影響

*   **功能等價性**：在大多數的 Checkmarx 環境中，認證伺服器（CxAuth）同時接受這兩個預設 Secret。只要其中一個能成功取得 `access_token`，就表示該 Secret 在您的環境中是有效的。
*   **權限範圍**：兩者取得的 Token 權限範圍通常都包含 `sast_rest_api`，足以執行查詢匯出與報告下載。
*   **安全性**：由於這些是公開的預設值，若您的組織有加固 Checkmarx 安全性並更換了自定義的 Client Secret，則這兩個腳本都必須更新為該自定義值。

## 建議做法

*   **維持現狀**：若兩個工具在您的環境中都能正常運作，則不一定需要修改。
*   **追求一致性**：若為了管理方便，建議您可以統一使用 `014498e2-4d10-4f4c-87f1-fa14f4f7cd78`，這是目前官方 API 串接最標準的數值。

---
*文件產生於 2026-03-25*

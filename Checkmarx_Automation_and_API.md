# Checkmarx 自動化開發與身份驗證指南

本文件說明如何使用 Checkmarx 的身份驗證機制來支援自動化開發、CI/CD 整合與 API 操作。

## 概覽

Checkmarx 支援類似 Personal Access Tokens (PAT) 的功能，但具體實作取決於您使用的平台版本：
- **Checkmarx One** (雲端原生平台)：使用 **API Keys**。
- **CxSAST** (傳統在地部署版)：使用 **OAuth2 Access Tokens**。

---

## 1. Checkmarx One：使用 API Keys

在 Checkmarx One 中，API Key 的功能等同於長效的 Personal Access Token (PAT)。

### 特性
- **用途**：專為 CI/CD 整合 (如 Jenkins, GitHub Actions) 與 API 自動化腳本設計。
- **有效期**：可設定過期時間（例如 30 天至 365 天）。
- **權限**：繼承生成該 Key 的使用者帳戶權限。

### 如何生成
1. 登入 Checkmarx One 入口網站。
2. 前往 **Settings** > **Identity and Access Management**。
3. 選擇 **API Keys** 分頁。
4. 點擊 **Create API Key**，設定名稱與過期時間後生成。

---

## 2. CxSAST (傳統版)：使用 OAuth2 Access Tokens

傳統版 CxSAST 通常不使用單一長效 Token，而是透過 OAuth2 流程進行動態驗證。

### 運作機制
- **Access Token**：短效憑證（通常 1 小時內有效），用於 API 請求。
- **Refresh Token**：用於在 Access Token 過期時自動獲取新 Token，無需重複輸入密碼。

### 自動化實作方式
您的自動化腳本需要包含一個登入步驟來獲取 Token。

**API 端點**：
- `POST /cxrestapi/auth/identity/connect/token`

**請求範例 (cURL)**：
```bash
curl -X POST "https://<CX_SERVER>/cxrestapi/auth/identity/connect/token" \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "username=<USER>&password=<PASS>&grant_type=password&scope=sast_rest_api&client_id=resource_owner_client&client_secret=014DF517-39D1-4453-B7B3-9930C563627C"
```
*(注意：client_secret 通常為固定值，請參考官方文件確認)*

**使用方式**：
獲取 Token 後，在後續 API 請求的 Header 中帶入：
`Authorization: Bearer <ACCESS_TOKEN>`

---

## 3. 使用 CLI 工具 (CxConsole)

如果您不想自行撰寫 API 驗證邏輯，可以使用官方提供的 **Checkmarx CLI (CxConsole)**。

### 特性
- 封裝了 API 驗證細節。
- 可直接在指令參數中傳遞帳密，或讀取設定檔。
- 易於整合至 Jenkins Pipeline 或 Shell Script 中。

### 範例指令
```bash
./runCxConsole.sh scan -v -Projectname "MyProject" -CxServer "http://localhost" -CxUser "admin" -CxPassword "password" -LocationType folder -LocationPath "/source/code"
```

---

## 建議總結

- **CI/CD 整合**：優先檢查您的 Checkmarx 版本。
    - 若為 **Checkmarx One**，請務必使用 **API Key**。
    - 若為 **CxSAST**，建議撰寫腳本動態獲取 Token，或使用 CxConsole CLI。
- **安全性**：無論使用哪種方式，請避免將帳號密碼或 API Key 直接寫死 (Hardcode) 在程式碼中，應使用環境變數或 Secret Management 工具管理。

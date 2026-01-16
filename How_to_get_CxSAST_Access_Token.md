# 如何取得 Checkmarx SAST (地端版 / Legacy) 的 Access Token

本文件詳細說明如何透過 OAuth 2.0 身份驗證服務取得 CxSAST 的存取權杖 (Access Token)，以便進行 REST API 自動化操作。

---

## 1. 準備工作

在進行身份驗證之前，請確保您擁有以下資訊：

| 參數名稱 | 說明 | 範例 / 預設值 |
| :--- | :--- | :--- |
| **Base URL** | Checkmarx 伺服器的位址 | `https://cx-server.yourdomain.com` |
| **Username** | 具有 API 存取權限的帳號 | `admin` |
| **Password** | 該帳號的密碼 | `********` |
| **Client ID** | OAuth 2.0 用戶端識別碼 | `resource_owner_client` |
| **Client Secret** | OAuth 2.0 用戶端密鑰 | `014DF517-39D1-4453-B7B3-9930C563F27B` |

> **注意**：上述 `Client Secret` 是 Checkmarx 官方預設的常數，除非您的系統管理員有修改過，否則通常可以直接使用。

---

## 2. 身份驗證方式

### 方法 A：使用 cURL (快速測試)

根據您的執行環境，選擇對應的指令格式。建議加上 `-k` (或 `--insecure`) 以忽略地端伺服器常見的自簽憑證問題。

#### 1. Linux / macOS / Git Bash (多行)
使用 `\` 換行：
```bash
curl -k -X POST "https://<你的伺服器>/cxrestapi/auth/identity/connect/token" \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "grant_type=password" \
     -d "username=<使用者名稱>" \
     -d "password=<密碼>" \
     -d "scope=sast_rest_api" \
     -d "client_id=resource_owner_client" \
     -d "client_secret=014DF517-39D1-4453-B7B3-9930C563F27B"
```

#### 2. Windows CMD (多行)
使用 `^` 換行：
```cmd
curl -k -X POST "https://<你的伺服器>/cxrestapi/auth/identity/connect/token" ^
     -H "Content-Type: application/x-www-form-urlencoded" ^
     -d "grant_type=password" ^
     -d "username=<使用者名稱>" ^
     -d "password=<密碼>" ^
     -d "scope=sast_rest_api" ^
     -d "client_id=resource_owner_client" ^
     -d "client_secret=014DF517-39D1-4453-B7B3-9930C563F27B"
```

#### 3. 通用單行指令 (方便直接複製)
```bash
curl -k -X POST "https://<你的伺服器>/cxrestapi/auth/identity/connect/token" -H "Content-Type: application/x-www-form-urlencoded" -d "grant_type=password" -d "username=<使用者名稱>" -d "password=<密碼>" -d "scope=sast_rest_api" -d "client_id=resource_owner_client" -d "client_secret=014DF517-39D1-4453-B7B3-9930C563F27B"
```

### 方法 B：使用 Python (自動化腳本)

推薦在開發整合工具時使用 Python 的 `requests` 程式庫：

```python
import requests

def get_cx_token(base_url, username, password):
    # 身份驗證端點
    url = f"{base_url}/cxrestapi/auth/identity/connect/token"
    
    # 請求酬載
    payload = {
        "grant_type": "password",
        "username": username,
        "password": password,
        "scope": "sast_rest_api",
        "client_id": "resource_owner_client",
        "client_secret": "014DF517-39D1-4453-B7B3-9930C563F27B"
    }
    
    # 發送請求 (地端版若無正式 SSL 憑證，需設 verify=False)
    response = requests.post(url, data=payload, verify=False)
    
    if response.status_code == 200:
        data = response.json()
        print("Token 取得成功！")
        return data.get("access_token")
    else:
        print(f"登入失敗！狀態碼：{response.status_code}")
        print(f"錯誤訊息：{response.text}")
        return None

# 呼叫範例
# token = get_cx_token("https://cx-server.local", "my_user", "my_password")
```

---

## 3. 回傳結果說明

成功登入後，您會收到一個包含以下欄位的 JSON 回應：

- **`access_token`**: 長字串，用於後續 API 呼叫。
- **`expires_in`**: 有效期限（秒），預設通常為 3600 (1小時)。
- **`token_type`**: 通常為 `Bearer`。
- **`refresh_token`**: 用於在 Access Token 過期時刷新，無需重新輸入帳密。

---

## 4. 如何使用 Access Token

取得 Access Token 後，請在所有 REST API 請求的 HTTP Header 中加入 `Authorization` 欄位：

**Header 格式**：
`Authorization: Bearer <YOUR_ACCESS_TOKEN>`

**cURL 範例**：
```bash
curl -X GET "https://<你的伺服器>/cxrestapi/projects" \
     -H "Authorization: Bearer <取得的存取權杖>" \
     -H "Accept: application/json"
```

---

## 5. 常見問題 (Troubleshooting)

1. **SSL 錯誤**：地端伺服器常使用自簽憑證。請確保您的工具（如 cURL 的 `-k` 或 Python 的 `verify=False`）已跳過 SSL 驗證。
2. **400 Bad Request**：通常是 `username` 或 `password` 錯誤，或者 `grant_type` 設定不正確。
3. **401 Unauthorized**：請檢查 `client_id` 與 `client_secret` 是否正確。

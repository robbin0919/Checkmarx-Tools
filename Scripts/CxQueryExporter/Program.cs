using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Threading.Tasks;

namespace CxQueryExporter;

class Program
{
    // --- 配置區 ---
    private const string CxServer = "https://your-checkmarx-server"; // 您的 Checkmarx 伺服器網址
    private const string Username = "your_username";
    private const string Password = "your_password";
    private const string OutputDir = "./CxQueries_Export";
    private const string ClientSecret = "014498e2-4d10-4f4c-87f1-fa14f4f7cd78"; // 預設 Secret

    static async Task Main(string[] args)
    {
        try
        {
            Console.WriteLine("🚀 開始 Checkmarx 查詢腳本匯出程序...");
            var exporter = new Program();
            await exporter.ExecuteExportAsync();
            Console.WriteLine($"\n✅ 匯出完成！檔案儲存於: {Path.GetFullPath(OutputDir)}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"\n❌ 發生錯誤: {ex.Message}");
        }
    }

    public async Task ExecuteExportAsync()
    {
        // 忽略自簽憑證錯誤 (可依需求移除)
        var handler = new HttpClientHandler
        {
            ServerCertificateCustomValidationCallback = (message, cert, chain, errors) => true
        };

        using var client = new HttpClient(handler);
        client.BaseAddress = new Uri(CxServer);

        // 1. 取得 Access Token
        string token = await GetAccessTokenAsync(client);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // 2. 抓取所有查詢內容
        Console.WriteLine("正在從伺服器抓取所有查詢數據...");
        var response = await client.GetAsync("/cxrestapi/sast/queries/all");
        response.EnsureSuccessStatusCode();

        var jsonString = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(jsonString);

        // 3. 遍歷並儲存檔案
        foreach (var langGroup in doc.RootElement.EnumerateArray())
        {
            string langName = langGroup.TryGetProperty("LanguageName", out var langProp) ? langProp.GetString() ?? "Unknown" : "Unknown";

            foreach (var group in langGroup.GetProperty("Groups").EnumerateArray())
            {
                string groupName = group.TryGetProperty("Name", out var groupProp) ? groupProp.GetString() ?? "General" : "General";

                foreach (var query in group.GetProperty("Queries").EnumerateArray())
                {
                    string? queryName = query.TryGetProperty("Name", out var queryNameProp) ? queryNameProp.GetString() : null;
                    string sourceCode = query.TryGetProperty("Source", out var sourceProp) ? sourceProp.GetString() ?? "" : "";

                    if (string.IsNullOrEmpty(queryName)) continue;

                    // 建立路徑: ./CxQueries_Export/語言/類別/
                    string folderPath = Path.Combine(OutputDir, langName, groupName);
                    Directory.CreateDirectory(folderPath);

                    // 清理檔名中的非法字元
                    string safeFileName = string.Join("_", queryName.Split(Path.GetInvalidFileNameChars())) + ".txt";
                    string filePath = Path.Combine(folderPath, safeFileName);

                    await File.WriteAllTextAsync(filePath, sourceCode);
                    Console.Write("."); // 進度提示
                }
            }
        }
    }

    private async Task<string> GetAccessTokenAsync(HttpClient client)
    {
        var dict = new Dictionary<string, string>
        {
            { "username", Username },
            { "password", Password },
            { "grant_type", "password" },
            { "scope", "sast_rest_api" },
            { "client_id", "resource_owner_client" },
            { "client_secret", ClientSecret }
        };

        var req = new HttpRequestMessage(HttpMethod.Post, "/cxrestapi/auth/identity/connect/token")
        {
            Content = new FormUrlEncodedContent(dict)
        };

        var res = await client.SendAsync(req);
        res.EnsureSuccessStatusCode();

        var json = await res.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        return doc.RootElement.GetProperty("access_token").GetString() ?? throw new Exception("Token not found");
    }
}

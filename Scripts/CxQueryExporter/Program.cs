using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Threading.Tasks;
using System.Linq;
using Spectre.Console;
using Serilog;

namespace CxQueryExporter;

class Program
{
    private string _cxServer = "https://your-checkmarx-server";
    private string _username = "your_username";
    private string _password = "your_password";
    private string _outputDir = "./CxQueries_Export";
    private const string ClientSecret = "014498e2-4d10-4f4c-87f1-fa14f4f7cd78";

    static async Task Main(string[] args)
    {
        // 初始化日誌記錄
        Log.Logger = new LoggerConfiguration()
            .MinimumLevel.Debug()
            .WriteTo.File("logs/exporter_.log", 
                rollingInterval: RollingInterval.Day,
                outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}")
            .CreateLogger();

        Log.Information("CxQueryExporter 已啟動，參數: {Args}", string.Join(" ", args));

        var program = new Program();
        
        if (args.Contains("-h") || args.Contains("--help"))
        {
            program.ShowHelp();
            Log.Information("顯示幫助訊息後結束。");
            return;
        }

        program.ParseArgs(args);

        AnsiConsole.Write(new FigletText("CxQuery").Color(Color.Cyan1));
        
        var table = new Table().Border(TableBorder.Rounded);
        table.AddColumn("[yellow]設定項[/]");
        table.AddColumn("[yellow]值[/]");
        table.AddRow("🌐 伺服器", $"[white]{program._cxServer}[/]");
        table.AddRow("👤 帳號", $"[white]{program._username}[/]");
        table.AddRow("📂 輸出目錄", $"[white]{Path.GetFullPath(program._outputDir)}[/]");
        AnsiConsole.Write(table);

        try
        {
            await program.ExecuteExportAsync();
            AnsiConsole.MarkupLine("\n[bold green]✅ 匯出程序已成功完成！[/]");
            Log.Information("匯出程序成功完成。");
        }
        catch (Exception ex)
        {
            AnsiConsole.WriteException(ex);
            Log.Fatal(ex, "程式執行過程中發生未預期的錯誤。");
            Environment.Exit(1);
        }
        finally
        {
            await Log.CloseAndFlushAsync();
        }
    }

    private void ShowHelp()
    {
        AnsiConsole.MarkupLine("[bold yellow]用法:[/] CxQueryExporter [選項]");
        Console.WriteLine("");
        AnsiConsole.MarkupLine("[bold yellow]選項:[/]");
        Console.WriteLine("  -s, --server <URL>      Checkmarx 伺服器網址");
        Console.WriteLine("  -u, --user <Username>   使用者帳號");
        Console.WriteLine("  -p, --pass <Password>   使用者密碼");
        Console.WriteLine("  -o, --output <Dir>      匯出儲存目錄 (預設: ./CxQueries_Export)");
        Console.WriteLine("  -h, --help              顯示此說明訊息");
    }

    private void ParseArgs(string[] args)
    {
        for (int i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "-s": case "--server": if (i + 1 < args.Length) _cxServer = args[++i]; break;
                case "-u": case "--user":   if (i + 1 < args.Length) _username = args[++i]; break;
                case "-p": case "--pass":   if (i + 1 < args.Length) _password = args[++i]; break;
                case "-o": case "--output": if (i + 1 < args.Length) _outputDir = args[++i]; break;
            }
        }
    }

    public async Task ExecuteExportAsync()
    {
        var handler = new HttpClientHandler { ServerCertificateCustomValidationCallback = (m, c, ch, e) => true };
        using var client = new HttpClient(handler);
        client.BaseAddress = new Uri(_cxServer);
        client.Timeout = TimeSpan.FromMinutes(5);

        Log.Information("開始連接至伺服器: {Server}", _cxServer);

        // 1. 認證與抓取
        JsonDocument? doc = null;
        await AnsiConsole.Status()
            .StartAsync("正在進行身份認證與抓取數據...", async ctx => {
                try
                {
                    ctx.Status("🔑 正在取得 Access Token...");
                    Log.Information("正在向 {Server} 請求 Access Token...", _cxServer);
                    string token = await GetAccessTokenAsync(client);
                    client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
                    Log.Information("成功取得 Access Token。");
                    
                    ctx.Status("📡 正在從伺服器抓取查詢清單...");
                    Log.Information("正在呼叫 API: /cxrestapi/sast/queries/all");
                    var response = await client.GetAsync("/cxrestapi/sast/queries/all");
                    response.EnsureSuccessStatusCode();
                    var jsonString = await response.Content.ReadAsStringAsync();
                    doc = JsonDocument.Parse(jsonString);
                    Log.Information("成功抓取並解析查詢清單數據。");
                }
                catch (Exception ex)
                {
                    Log.Error(ex, "身份認證或抓取數據時失敗。");
                    throw;
                }
            });

        if (doc == null) 
        {
            Log.Warning("抓取結果為空，取消後續操作。");
            throw new Exception("無法解析查詢清單數據。");
        }

        // 2. 統計總數
        var allQueries = new List<(string lang, string group, string name, string source)>();
        foreach (var langGroup in doc.RootElement.EnumerateArray())
        {
            string lang = langGroup.TryGetProperty("LanguageName", out var lp) ? lp.GetString() ?? "Unknown" : "Unknown";
            foreach (var group in langGroup.GetProperty("Groups").EnumerateArray())
            {
                string grp = group.TryGetProperty("Name", out var gp) ? gp.GetString() ?? "General" : "General";
                foreach (var q in group.GetProperty("Queries").EnumerateArray())
                {
                    string? name = q.TryGetProperty("Name", out var np) ? np.GetString() : null;
                    string source = q.TryGetProperty("Source", out var sp) ? sp.GetString() ?? "" : "";
                    if (!string.IsNullOrEmpty(name)) allQueries.Add((lang, grp, name, source));
                }
            }
        }

        Log.Information("解析完成，準備匯出 {Count} 個查詢腳本。", allQueries.Count);

        // 3. 執行匯出並顯示進度條
        await AnsiConsole.Progress()
            .Columns(new ProgressColumn[] {
                new TaskDescriptionColumn(),
                new ProgressBarColumn(),
                new PercentageColumn(),
                new RemainingTimeColumn(),
                new SpinnerColumn(),
            })
            .StartAsync(async ctx => {
                var task = ctx.AddTask("[green]匯出 CxQL 查詢腳本[/]", maxValue: allQueries.Count);
                
                foreach (var q in allQueries)
                {
                    try
                    {
                        task.Description = $"[grey]正在匯出: {q.lang} -> [/][white]{q.name}[/]";
                        
                        string folderPath = Path.Combine(_outputDir, q.lang, q.group);
                        if (!Directory.Exists(folderPath)) Directory.CreateDirectory(folderPath);

                        string safeFileName = string.Join("_", q.name.Split(Path.GetInvalidFileNameChars())) + ".txt";
                        string filePath = Path.Combine(folderPath, safeFileName);

                        await File.WriteAllTextAsync(filePath, q.source);
                        task.Increment(1);
                    }
                    catch (Exception ex)
                    {
                        Log.Error(ex, "匯出腳本時失敗: {Lang} -> {Name}", q.lang, q.name);
                    }
                }
            });

        AnsiConsole.MarkupLine($"\n✨ [bold]總計匯出檔案數: {allQueries.Count}[/]");
    }

    private async Task<string> GetAccessTokenAsync(HttpClient client)
    {
        var dict = new Dictionary<string, string>
        {
            { "username", _username }, { "password", _password },
            { "grant_type", "password" }, { "scope", "sast_rest_api" },
            { "client_id", "resource_owner_client" }, { "client_secret", ClientSecret }
        };

        var req = new HttpRequestMessage(HttpMethod.Post, "/cxrestapi/auth/identity/connect/token") { Content = new FormUrlEncodedContent(dict) };
        var res = await client.SendAsync(req);
        if (!res.IsSuccessStatusCode)
        {
            var errorContent = await res.Content.ReadAsStringAsync();
            Log.Error("認證 API 回傳錯誤狀態碼: {StatusCode}, 內容: {Content}", res.StatusCode, errorContent);
            throw new Exception($"認證失敗: {res.StatusCode}");
        }

        var json = await res.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        return doc.RootElement.GetProperty("access_token").GetString() ?? throw new Exception("Token 解析失敗");
    }
}

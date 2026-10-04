using System.Net.Http.Headers;
using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

namespace ClauseTracker;

static class Program
{
    [STAThread]
    static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new MainForm());
    }
}

/// <summary>Stores the server address chosen on this PC.</summary>
static class Settings
{
    static readonly string Dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "ClauseTracker");
    static readonly string FilePath = Path.Combine(Dir, "client.json");
    public const string DefaultUrl = "http://localhost:5080";

    public static string LoadUrl()
    {
        try
        {
            if (File.Exists(FilePath) && JsonDocument.Parse(File.ReadAllText(FilePath)).RootElement.TryGetProperty("serverUrl", out var v)
                && !string.IsNullOrWhiteSpace(v.GetString())) return v.GetString()!;
        }
        catch { }
        return DefaultUrl;
    }

    public static void SaveUrl(string url)
    {
        Directory.CreateDirectory(Dir);
        File.WriteAllText(FilePath, JsonSerializer.Serialize(new { serverUrl = url }));
    }

    public static string Normalize(string url)
    {
        url = url.Trim().TrimEnd('/');
        if (url.Length == 0) throw new InvalidOperationException("أدخل عنوان الخادم.");
        if (!url.Contains("://")) url = "http://" + url;
        if (!Uri.TryCreate(url, UriKind.Absolute, out var u) || (u.Scheme != "http" && u.Scheme != "https"))
            throw new InvalidOperationException("عنوان الخادم غير صالح. مثال: https://clausetracker.example.com");
        if (u.Scheme == "http" && !IsPrivateHost(u.Host))
            throw new InvalidOperationException("للاتصال عبر الإنترنت يجب أن يبدأ العنوان بـ https:// لحماية كلمات المرور.");
        return url;
    }

    /// <summary>Plain HTTP is only acceptable on this PC or a private office network.</summary>
    static bool IsPrivateHost(string host)
    {
        if (host.Equals("localhost", StringComparison.OrdinalIgnoreCase)) return true;
        if (!System.Net.IPAddress.TryParse(host, out var ip)) return !host.Contains('.');   // bare machine name on the LAN
        if (System.Net.IPAddress.IsLoopback(ip)) return true;
        var b = ip.GetAddressBytes();
        return ip.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork &&
               (b[0] == 10 || (b[0] == 172 && b[1] is >= 16 and <= 31) || (b[0] == 192 && b[1] == 168));
    }
}

class MainForm : Form
{
    readonly WebView2 web = new() { Dock = DockStyle.Fill, DefaultBackgroundColor = Color.FromArgb(244, 246, 250) };
    readonly HttpClient http = new() { Timeout = TimeSpan.FromSeconds(60) };
    string serverUrl = Settings.LoadUrl();
    string? token;

    public MainForm()
    {
        Text = "متتبع مراجعة البنود";
        Width = 1360; Height = 860; MinimumSize = new Size(1000, 660);
        StartPosition = FormStartPosition.CenterScreen;
        RightToLeft = RightToLeft.Yes; RightToLeftLayout = true;
        Icon = SystemIcons.Application;
        Controls.Add(web);
        Load += async (_, _) => await InitWeb();
    }

    async Task InitWeb()
    {
        var data = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ClauseTracker", "WebView2");
        var env = await CoreWebView2Environment.CreateAsync(null, data);
        await web.EnsureCoreWebView2Async(env);
        var s = web.CoreWebView2.Settings;
        s.AreDevToolsEnabled = false;
        s.AreDefaultContextMenusEnabled = false;
        s.IsZoomControlEnabled = false;
        s.IsStatusBarEnabled = false;
        s.AreBrowserAcceleratorKeysEnabled = false;
        web.CoreWebView2.WebMessageReceived += OnMessage;
        web.CoreWebView2.NewWindowRequested += (_, e) => e.Handled = true;
        web.CoreWebView2.NavigationStarting += (_, e) => { if (!e.Uri.StartsWith("data:")) e.Cancel = true; };

        using var st = Assembly.GetExecutingAssembly().GetManifestResourceStream("ui.index.html")!;
        using var rd = new StreamReader(st);
        web.CoreWebView2.NavigateToString(rd.ReadToEnd());
    }

    /// <summary>Sends one RPC to the server. Returns the parsed envelope {ok,result|error,token}.</summary>
    async Task<JsonNode> Rpc(string method, JsonNode? args)
    {
        var body = new JsonObject { ["method"] = method, ["args"] = args ?? new JsonObject() };
        using var req = new HttpRequestMessage(HttpMethod.Post, serverUrl + "/api/rpc") { Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json") };
        if (token != null) req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        using var resp = await http.SendAsync(req);
        var env = JsonNode.Parse(await resp.Content.ReadAsStringAsync()) ?? throw new Exception("رد غير صالح من الخادم.");
        if (env["token"]?.GetValue<string>() is { } t) token = t;
        if (method == "logout") token = null;
        return env;
    }

    async void OnMessage(object? sender, CoreWebView2WebMessageReceivedEventArgs e)
    {
        var root = JsonNode.Parse(e.WebMessageAsJson)!;
        var id = root["id"]!.GetValue<int>();
        var method = root["method"]!.GetValue<string>();
        var args = root["args"] as JsonObject ?? new JsonObject();
        var reply = new JsonObject { ["id"] = id };
        try
        {
            switch (method)
            {
                case "setServer":
                    serverUrl = Settings.Normalize(args["url"]?.GetValue<string>() ?? "");
                    Settings.SaveUrl(serverUrl);
                    token = null;
                    await Boot(reply);
                    break;

                case "boot":
                    await Boot(reply);
                    break;

                case "exportCsv":
                {
                    args["tz"] = (int)TimeZoneInfo.Local.GetUtcOffset(DateTime.Now).TotalMinutes;
                    var env = await Rpc(method, args);
                    if (env["ok"]!.GetValue<bool>())
                    {
                        var r = env["result"]!;
                        using var d = new SaveFileDialog { Filter = "ملف CSV|*.csv", FileName = r["fileName"]!.GetValue<string>() };
                        string? saved = null;
                        if (d.ShowDialog(this) == DialogResult.OK)
                        {
                            File.WriteAllText(d.FileName, r["csv"]!.GetValue<string>(), new UTF8Encoding(true));
                            saved = d.FileName;
                        }
                        reply["ok"] = true; reply["result"] = saved;
                    }
                    else { reply["ok"] = false; reply["error"] = env["error"]!.GetValue<string>(); }
                    break;
                }

                default:
                {
                    var env = await Rpc(method, args);
                    reply["ok"] = env["ok"]!.GetValue<bool>();
                    if (reply["ok"]!.GetValue<bool>()) reply["result"] = env["result"]?.DeepClone();
                    else reply["error"] = env["error"]!.GetValue<string>();
                    break;
                }
            }
        }
        catch (InvalidOperationException ex) { reply["ok"] = false; reply["error"] = ex.Message; }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException)
        {
            reply["ok"] = false; reply["error"] = "تعذر الاتصال بالخادم. تحقق من الشبكة وعنوان الخادم.";
        }
        catch (Exception ex) { reply["ok"] = false; reply["error"] = "خطأ غير متوقع: " + ex.Message; }
        web.CoreWebView2.PostWebMessageAsJson(reply.ToJsonString());
    }

    /// <summary>Boot never fails outright: an unreachable server is reported as dbError so the UI can show connection settings.</summary>
    async Task Boot(JsonObject reply)
    {
        JsonObject result;
        try
        {
            var env = await Rpc("boot", null);
            result = env["ok"]!.GetValue<bool>() ? (JsonObject)env["result"]!.DeepClone() : new JsonObject { ["dbError"] = env["error"]!.GetValue<string>() };
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException)
        {
            result = new JsonObject { ["dbError"] = "تعذر الاتصال بالخادم. تحقق من أن الخادم يعمل وأن العنوان صحيح." };
        }
        result["serverUrl"] = serverUrl;
        reply["ok"] = true; reply["result"] = result;
    }
}


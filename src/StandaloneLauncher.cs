using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

public static class StandaloneLauncher
{
    [STAThread]
    public static void Main()
    {
        // Embed the UI and icon so copying only OneL.exe to the desktop works.
        // Keep each release in its own cache; never execute an older loose script.
        string appCache = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "OneClickBeautify", "app", "1.0.7");
        string script = Path.Combine(appCache, "AppLauncher.ps1");
        try
        {
            Directory.CreateDirectory(appCache);
            ExtractResource("OneL.AppLauncher.ps1", script);
            ExtractResource("OneL.OneL.ico", Path.Combine(appCache, "OneL.ico"));
        }
        catch (Exception ex)
        {
            MessageBox.Show("无法准备程序文件：" + ex.Message, "OneL", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }
        // The release launcher is 32-bit so it can run with the bundled x86
        // .NET runtime.  A 32-bit process sees System32 as SysWOW64; that
        // redirects the script to 32-bit PowerShell and can prevent WPF from
        // loading correctly.  Use Sysnative to reach the native 64-bit host
        // whenever it is available, then fall back to the normal system path.
        string windowsDir = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        string powershell = Path.Combine(windowsDir, "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
        if (Environment.Is64BitOperatingSystem && !Environment.Is64BitProcess)
        {
            string nativePath = Path.Combine(windowsDir, "Sysnative", "WindowsPowerShell", "v1.0", "powershell.exe");
            if (File.Exists(nativePath)) powershell = nativePath;
        }
        if (!File.Exists(powershell))
        {
            string wowPath = Path.Combine(windowsDir, "SysWOW64", "WindowsPowerShell", "v1.0", "powershell.exe");
            if (File.Exists(wowPath)) powershell = wowPath;
        }
        var info = new ProcessStartInfo(powershell, "-NoProfile -STA -ExecutionPolicy Bypass -File \"" + script + "\"");
        // The script uses this for the Windows startup entry (the cache has no EXE).
        info.EnvironmentVariables["ONEL_EXE_PATH"] = Environment.ProcessPath;
        info.WorkingDirectory = AppDomain.CurrentDomain.BaseDirectory;
        info.UseShellExecute = false;
        info.CreateNoWindow = true;
        info.WindowStyle = ProcessWindowStyle.Hidden;
        info.EnvironmentVariables["ONEL_INSTALL_ROOT"] = appCache;
        string diagnostics = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "OneClickBeautify", "launcher.log");
        try
        {
            Process child = Process.Start(info);
            File.AppendAllText(diagnostics, DateTime.Now.ToString("s") + " powershell=" + powershell + " pid=" + (child == null ? "null" : child.Id.ToString()) + Environment.NewLine);
        }
        catch (Exception ex)
        {
            File.AppendAllText(diagnostics, DateTime.Now.ToString("s") + " powershell=" + powershell + " error=" + ex + Environment.NewLine);
            MessageBox.Show("无法启动快捷键服务：" + ex.Message, "一键桌面美化", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private static void ExtractResource(string name, string path)
    {
        using (Stream resource = Assembly.GetExecutingAssembly().GetManifestResourceStream(name))
        {
            if (resource == null) throw new InvalidOperationException("缺少内置资源：" + name);
            // Write atomically: a simultaneous double-click must not leave a
            // partially written script for the first PowerShell process.
            string temporary = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
            try
            {
                using (FileStream output = File.Create(temporary)) resource.CopyTo(output);
                File.Move(temporary, path, true);
            }
            finally { if (File.Exists(temporary)) File.Delete(temporary); }
        }
    }
}

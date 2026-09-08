using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

[assembly: AssemblyTitle("HaruHana Updater")]
[assembly: AssemblyDescription("Installs verified HaruHana releases")]
[assembly: AssemblyCompany("HaruHana")]
[assembly: AssemblyProduct("HaruHana")]
[assembly: AssemblyVersion("1.1.0.0")]
[assembly: AssemblyFileVersion("1.1.0.0")]

internal static class HaruHanaUpdater
{
    private const string MainExecutable = "하루하나.exe";
    private const string CharacterCreatorExecutable = "캐릭터 크리에이터.exe";
    private const string BubbleCreatorExecutable = "말풍선 크리에이터.exe";
    private const string UpdaterExecutable = "HaruHanaUpdater.exe";
    private const string FinalizerExecutable = "HaruHanaUpdater.finalize.exe";
    private const string NativeLibrary = "mouse_passthrough.windows.template_release.x86_64.dll";
    private const int DeleteOnReboot = 4;

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool MoveFileEx(string existingFileName, string newFileName, int flags);

    [STAThread]
    private static int Main(string[] args)
    {
        Dictionary<string, string> options = ParseArguments(args);
        if (options.ContainsKey("finalize"))
            return FinalizeUpdate(options);
        if (!options.ContainsKey("apply-update"))
            return 2;
        return PrepareUpdate(options);
    }

    private static int PrepareUpdate(Dictionary<string, string> options)
    {
        string statusPath = GetOption(options, "status-file");
        try
        {
            string packagePath = GetRequiredPath(options, "package");
            string installDirectory = GetRequiredPath(options, "install-dir");
            string restartPath = GetRequiredPath(options, "restart");
            statusPath = GetRequiredPath(options, "status-file");
            int mainProcessId = GetRequiredProcessId(options, "wait-pid");
            ValidateRequest(packagePath, installDirectory, restartPath, statusPath);

            string updateDirectory = Path.GetDirectoryName(statusPath);
            string stagingDirectory = Path.Combine(updateDirectory, "staged");
            string finalizerPath = Path.Combine(updateDirectory, FinalizerExecutable);
            DeleteDirectory(stagingDirectory);
            Directory.CreateDirectory(stagingDirectory);
            ExtractPackage(packagePath, stagingDirectory);
            stagingDirectory = ResolvePackageRoot(stagingDirectory);
            ValidatePackage(stagingDirectory);
            DeleteDirectory(Path.Combine(stagingDirectory, "characters"));
            DeleteDirectory(Path.Combine(stagingDirectory, "bubbles"));

            TryDeleteFile(finalizerPath);
            File.Copy(Process.GetCurrentProcess().MainModule.FileName, finalizerPath, true);
            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.FileName = finalizerPath;
            startInfo.Arguments = BuildFinalizerArguments(
                packagePath,
                installDirectory,
                restartPath,
                statusPath,
                mainProcessId,
                Process.GetCurrentProcess().Id
            );
            startInfo.UseShellExecute = false;
            startInfo.CreateNoWindow = true;
            Process finalizer = Process.Start(startInfo);
            if (finalizer == null)
                throw new UpdateException("finalizer_launch_failed");
            finalizer.Dispose();
            WriteStatus(statusPath, true, "");
            return 0;
        }
        catch (Exception exception)
        {
            WriteStatus(statusPath, false, ErrorCode(exception, "updater_prepare_failed"));
            return 1;
        }
    }

    private static int FinalizeUpdate(Dictionary<string, string> options)
    {
        string statusPath = GetOption(options, "status-file");
        try
        {
            string packagePath = GetRequiredPath(options, "package");
            string installDirectory = GetRequiredPath(options, "install-dir");
            string restartPath = GetRequiredPath(options, "restart");
            statusPath = GetRequiredPath(options, "status-file");
            int mainProcessId = GetRequiredProcessId(options, "wait-pid");
            int updaterProcessId = GetRequiredProcessId(options, "updater-pid");
            ValidateRequest(packagePath, installDirectory, restartPath, statusPath);

            string updateDirectory = Path.GetDirectoryName(statusPath);
            string stagingDirectory = Path.Combine(updateDirectory, "staged");
            string errorPath = Path.Combine(updateDirectory, "update_error.txt");
            stagingDirectory = ResolvePackageRoot(stagingDirectory);
            WaitForExit(mainProcessId, TimeSpan.FromSeconds(130));
            WaitForExit(updaterProcessId, TimeSpan.FromSeconds(15));
            if (!Directory.Exists(stagingDirectory))
                throw new UpdateException("staging_missing");
            WaitForApplications(installDirectory, TimeSpan.FromSeconds(130));
            InstallTransaction(stagingDirectory, installDirectory, Path.Combine(updateDirectory, "rollback"));
            DeleteDirectory(stagingDirectory);
            TryDeleteFile(packagePath);
            TryDeleteFile(errorPath);
            StartApplication(restartPath);
            ScheduleSelfDeletion();
            return 0;
        }
        catch (Exception exception)
        {
            WriteErrorFile(statusPath, ErrorCode(exception, "update_install_failed"));
            if (!(exception is UpdateException) || ((UpdateException)exception).Code != "rollback_failed")
                TryRestart(options);
            ScheduleSelfDeletion();
            return 1;
        }
    }

    private static Dictionary<string, string> ParseArguments(string[] args)
    {
        Dictionary<string, string> options = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (string argument in args)
        {
            if (!argument.StartsWith("--", StringComparison.Ordinal))
                continue;
            int separator = argument.IndexOf('=');
            if (separator < 0)
                options[argument.Substring(2)] = "";
            else
                options[argument.Substring(2, separator - 2)] = argument.Substring(separator + 1);
        }
        return options;
    }

    private static string GetOption(Dictionary<string, string> options, string name)
    {
        string value;
        return options.TryGetValue(name, out value) ? value : "";
    }

    private static string GetRequiredPath(Dictionary<string, string> options, string name)
    {
        string value = GetOption(options, name);
        if (String.IsNullOrWhiteSpace(value))
            throw new UpdateException("update_request_incomplete");
        return Path.GetFullPath(value);
    }

    private static int GetRequiredProcessId(Dictionary<string, string> options, string name)
    {
        int processId;
        if (!Int32.TryParse(GetOption(options, name), out processId) || processId <= 0)
            throw new UpdateException("update_request_incomplete");
        return processId;
    }

    private static void ValidateRequest(
        string packagePath,
        string installDirectory,
        string restartPath,
        string statusPath
    )
    {
        if (!File.Exists(packagePath))
            throw new UpdateException("package_missing");
        if (!Directory.Exists(installDirectory))
            throw new UpdateException("install_directory_missing");
        if (!PathsEqual(Path.GetDirectoryName(restartPath), installDirectory))
            throw new UpdateException("update_request_incomplete");
        if (!String.Equals(Path.GetFileName(restartPath), MainExecutable, StringComparison.OrdinalIgnoreCase))
            throw new UpdateException("update_request_incomplete");
        string statusDirectory = Path.GetDirectoryName(statusPath);
        if (String.IsNullOrWhiteSpace(statusDirectory))
            throw new UpdateException("update_request_incomplete");
        Directory.CreateDirectory(statusDirectory);
    }

    private static string ResolvePackageRoot(string root)
    {
        if (File.Exists(Path.Combine(root, MainExecutable))) return root;
        string[] directories = Directory.GetDirectories(root);
        if (Directory.GetFiles(root).Length == 0 && directories.Length == 1 &&
            File.Exists(Path.Combine(directories[0], MainExecutable))) return directories[0];
        throw new UpdateException("package_layout_invalid");
    }

    private static void ExtractPackage(string packagePath, string stagingDirectory)
    {
        string root = EnsureTrailingSeparator(Path.GetFullPath(stagingDirectory));
        HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        long total = 0;
        using (ZipArchive archive = ZipFile.OpenRead(packagePath))
        {
            if (archive.Entries.Count > 4096) throw new UpdateException("package_too_large");
            foreach (ZipArchiveEntry entry in archive.Entries)
            {
                string name = entry.FullName.Replace('\\', '/');
                if (name.StartsWith("/") || name.Contains(":") || name.Contains("../") || name.Contains("./") || name.Contains("\t"))
                    throw new UpdateException("unsafe_package_path");
                string targetPath = Path.GetFullPath(Path.Combine(stagingDirectory, name));
                if (!targetPath.StartsWith(root, StringComparison.OrdinalIgnoreCase) || !seen.Add(targetPath))
                    throw new UpdateException("unsafe_package_path");
                if (String.IsNullOrEmpty(entry.Name)) { Directory.CreateDirectory(targetPath); continue; }
                total += entry.Length;
                if (entry.Length > 512L * 1024 * 1024 || total > 1536L * 1024 * 1024)
                    throw new UpdateException("package_too_large");
                Directory.CreateDirectory(Path.GetDirectoryName(targetPath));
                using (Stream input = entry.Open())
                using (FileStream output = new FileStream(targetPath, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                {
                    byte[] buffer = new byte[65536];
                    long written = 0;
                    int read;
                    while ((read = input.Read(buffer, 0, buffer.Length)) > 0)
                    {
                        written += read;
                        if (written > entry.Length) throw new UpdateException("package_too_large");
                        output.Write(buffer, 0, read);
                    }
                    if (written != entry.Length) throw new UpdateException("package_layout_invalid");
                }
            }
        }
    }

    private static void ValidatePackage(string stagingDirectory)
    {
        string[] requiredFiles = {
            MainExecutable,
            CharacterCreatorExecutable,
            BubbleCreatorExecutable,
            UpdaterExecutable,
            NativeLibrary
        };
        foreach (string fileName in requiredFiles)
        {
            if (!File.Exists(Path.Combine(stagingDirectory, fileName)) || new FileInfo(Path.Combine(stagingDirectory, fileName)).Length == 0)
                throw new UpdateException("package_layout_invalid");
        }
    }

    private static void WaitForApplications(string installDirectory, TimeSpan timeout)
    {
        DateTime deadline = DateTime.UtcNow + timeout;
        string[] names = { MainExecutable, CharacterCreatorExecutable, BubbleCreatorExecutable };
        foreach (string name in names)
        foreach (Process process in Process.GetProcessesByName(Path.GetFileNameWithoutExtension(name)))
        using (process)
        {
            try
            {
                if (!PathsEqual(process.MainModule.FileName, Path.Combine(installDirectory, name))) continue;
                int remaining = Math.Max(0, (int)(deadline - DateTime.UtcNow).TotalMilliseconds);
                if (!process.WaitForExit(remaining)) throw new UpdateException("close_creators_required");
            }
            catch (InvalidOperationException) { } // Process already exited.
        }
    }

    private static string SafeChild(string root, string relative)
    {
        string path = Path.GetFullPath(Path.Combine(root, relative));
        if (!path.StartsWith(EnsureTrailingSeparator(Path.GetFullPath(root)), StringComparison.OrdinalIgnoreCase))
            throw new UpdateException("unsafe_package_path");
        return path;
    }

    private static bool IsManagedFile(string relative)
    {
        return relative == MainExecutable || relative == CharacterCreatorExecutable ||
            relative == BubbleCreatorExecutable || relative == UpdaterExecutable || relative == NativeLibrary;
    }

    // The journal and originals survive interruption. The next attempt restores them first.
    private static void InstallTransaction(string source, string destination, string rollback)
    {
        try { RecoverTransaction(destination, rollback); }
        catch { throw new UpdateException("rollback_failed"); }
        ValidatePackage(source);
        List<string> files = new List<string>();
        foreach (string path in Directory.GetFiles(source, "*", SearchOption.AllDirectories))
        {
            string relative = path.Substring(source.Length).TrimStart(Path.DirectorySeparatorChar);
            // Existing custom fonts, bubbles and characters belong to the user.
            bool newFont = relative.StartsWith("fonts" + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)
                && Path.GetExtension(relative).Equals(".ttf", StringComparison.OrdinalIgnoreCase)
                && !File.Exists(SafeChild(destination, relative));
            if (IsManagedFile(relative) || newFont) files.Add(relative);
        }
        foreach (string relative in files)
        {
            string target = SafeChild(destination, relative);
            if (File.Exists(target))
                using (FileStream probe = new FileStream(target, FileMode.Open, FileAccess.ReadWrite, FileShare.None)) { }
        }
        Directory.CreateDirectory(rollback);
        List<string> journal = new List<string>();
        foreach (string relative in files)
        {
            string target = SafeChild(destination, relative);
            bool existed = File.Exists(target);
            if (existed)
            {
                string backup = SafeChild(rollback, relative);
                Directory.CreateDirectory(Path.GetDirectoryName(backup));
                File.Copy(target, backup, true);
            }
            journal.Add((existed ? "1" : "0") + "\t" + relative);
        }
        string journalPath = Path.Combine(rollback, "journal.txt");
        File.WriteAllLines(journalPath, journal.ToArray(), new UTF8Encoding(false));
        try
        {
            int installed = 0;
            foreach (string relative in files)
            {
                ReplaceFile(SafeChild(source, relative), SafeChild(destination, relative));
                installed++;
#if UPDATER_TESTS
                if (TestFailAfter == installed) throw new IOException("Injected interrupted update");
#endif
            }
            File.Delete(journalPath); // Commit before cleanup; stale backups alone never trigger rollback.
        }
        catch
        {
            try { RecoverTransaction(destination, rollback); }
            catch { throw new UpdateException("rollback_failed"); }
            throw;
        }
        try { DeleteDirectory(rollback); } catch { }
    }

#if UPDATER_TESTS
    internal static int TestFailAfter = -1;
#endif

    private static void RecoverTransaction(string destination, string rollback)
    {
        string journal = Path.Combine(rollback, "journal.txt");
        if (!File.Exists(journal)) return;
        foreach (string entry in File.ReadAllLines(journal))
        {
            string[] parts = entry.Split(new char[] { '\t' }, 2);
            if (parts.Length != 2 || (!IsManagedFile(parts[1]) && !parts[1].StartsWith("fonts" + Path.DirectorySeparatorChar)))
                throw new UpdateException("rollback_failed");
            string target = SafeChild(destination, parts[1]);
            if (parts[0] == "1") ReplaceFile(SafeChild(rollback, parts[1]), target);
            else if (parts[0] == "0" && File.Exists(target)) File.Delete(target);
            TryDeleteFile(target + ".update-new");
        }
        File.Delete(journal);
        DeleteDirectory(rollback);
    }

    private static void ReplaceFile(string source, string target)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(target));
        string temporary = target + ".update-new";
        File.Copy(source, temporary, true);
        if (File.Exists(target)) File.Replace(temporary, target, null);
        else File.Move(temporary, target);
    }

    private static void WaitForExit(int processId, TimeSpan timeout)
    {
        try
        {
            using (Process process = Process.GetProcessById(processId))
            {
                if (!process.WaitForExit((int)timeout.TotalMilliseconds))
                    throw new UpdateException("process_exit_timeout");
            }
        }
        catch (ArgumentException)
        {
        }
    }

    private static string BuildFinalizerArguments(
        string packagePath,
        string installDirectory,
        string restartPath,
        string statusPath,
        int mainProcessId,
        int updaterProcessId
    )
    {
        return "--finalize"
            + " --package=" + Quote(packagePath)
            + " --install-dir=" + Quote(installDirectory)
            + " --restart=" + Quote(restartPath)
            + " --status-file=" + Quote(statusPath)
            + " --wait-pid=" + mainProcessId
            + " --updater-pid=" + updaterProcessId;
    }

    private static string Quote(string value)
    {
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }

    private static void WriteStatus(string path, bool ok, string error)
    {
        if (String.IsNullOrWhiteSpace(path))
            return;
        try
        {
            string parent = Path.GetDirectoryName(path);
            if (!String.IsNullOrEmpty(parent))
                Directory.CreateDirectory(parent);
            string json = ok
                ? "{\"ok\":true,\"error\":\"\"}"
                : "{\"ok\":false,\"error\":\"" + JsonEscape(error) + "\"}";
            File.WriteAllText(path + ".tmp", json, new UTF8Encoding(false));
            if (File.Exists(path)) File.Replace(path + ".tmp", path, null);
            else File.Move(path + ".tmp", path);
        }
        catch
        {
        }
    }

    private static void WriteErrorFile(string statusPath, string error)
    {
        if (String.IsNullOrWhiteSpace(statusPath))
            return;
        try
        {
            string directory = Path.GetDirectoryName(statusPath);
            if (String.IsNullOrWhiteSpace(directory))
                return;
            Directory.CreateDirectory(directory);
            File.WriteAllText(Path.Combine(directory, "update_error.txt"), error, new UTF8Encoding(false));
        }
        catch
        {
        }
    }

    private static string JsonEscape(string value)
    {
        return (value ?? "").Replace("\\", "\\\\").Replace("\"", "\\\"");
    }

    private static string ErrorCode(Exception exception, string fallback)
    {
        UpdateException updateException = exception as UpdateException;
        return updateException == null ? fallback : updateException.Code;
    }

    private static void StartApplication(string path)
    {
        ProcessStartInfo startInfo = new ProcessStartInfo();
        startInfo.FileName = path;
        startInfo.WorkingDirectory = Path.GetDirectoryName(path);
        startInfo.UseShellExecute = true;
        Process process = Process.Start(startInfo);
        if (process == null)
            throw new UpdateException("restart_failed");
        process.Dispose();
    }

    private static void TryRestart(Dictionary<string, string> options)
    {
        try
        {
            string restartPath = GetOption(options, "restart");
            if (!String.IsNullOrWhiteSpace(restartPath) && File.Exists(restartPath))
                StartApplication(Path.GetFullPath(restartPath));
        }
        catch
        {
        }
    }

    private static void ScheduleSelfDeletion()
    {
        try
        {
            MoveFileEx(Process.GetCurrentProcess().MainModule.FileName, null, DeleteOnReboot);
        }
        catch
        {
        }
    }

    private static void DeleteDirectory(string path)
    {
        if (Directory.Exists(path))
            Directory.Delete(path, true);
    }

    private static void TryDeleteFile(string path)
    {
        try
        {
            if (File.Exists(path))
                File.Delete(path);
        }
        catch
        {
        }
    }

    private static bool PathsEqual(string first, string second)
    {
        if (String.IsNullOrWhiteSpace(first) || String.IsNullOrWhiteSpace(second))
            return false;
        return String.Equals(
            Path.GetFullPath(first).TrimEnd(Path.DirectorySeparatorChar),
            Path.GetFullPath(second).TrimEnd(Path.DirectorySeparatorChar),
            StringComparison.OrdinalIgnoreCase
        );
    }

    private static string EnsureTrailingSeparator(string path)
    {
        return path.EndsWith(Path.DirectorySeparatorChar.ToString(), StringComparison.Ordinal)
            ? path
            : path + Path.DirectorySeparatorChar;
    }

    private sealed class UpdateException : Exception
    {
        internal readonly string Code;

        internal UpdateException(string code)
            : base(code)
        {
            Code = code;
        }
    }
}

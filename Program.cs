using System.Diagnostics;

Environment.SetEnvironmentVariable("TFS_BASE_URL", "123");
Environment.SetEnvironmentVariable("TFS_PAT", "123");
var runner = "E:/Programs SSD/Git/bin/bash.exe";
var arguments = "-c \"/AiSkills/codex.sh -p YarProject -w 1 --review\"";

var info = new ProcessStartInfo()
{
  FileName = runner,
  Arguments = arguments,
  CreateNoWindow = true,
  RedirectStandardError = true,
  RedirectStandardOutput = true,
};

var process = Process.Start(info) ?? throw new YarkovProcessNotStartedException(info);

var outputReader = process.StandardOutput;
var errorReader = process.StandardError;
var output = "";
var error = "";
while (((output = await outputReader.ReadLineAsync()) is not null) ||
  (error = await errorReader.ReadLineAsync()) is not null)
{
  if (!string.IsNullOrEmpty(output))
  {
    Console.WriteLine($"[LOG]: {output}");
  }
  if (!string.IsNullOrEmpty(error))
  {
    Console.WriteLine($"[ERROR]: {error}");
  }
}

public class YarkovProcessNotStartedException(ProcessStartInfo info) : Exception($"{info.FileName} {info.Arguments}")
{
}
import 'dart:io';

class TrayHelper {
  Process? _process;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    if (!Platform.isWindows) return;
    _started = true;
    const script = r'''
param($exe)
Add-Type -AssemblyName System.Windows.Forms
$n = New-Object System.Windows.Forms.NotifyIcon
$n.Icon = [System.Drawing.SystemIcons]::Application
$n.Text = "ClipShare"
$n.Visible = $true
$open = { if (-not (Get-Process clipshare -ErrorAction SilentlyContinue)) { Start-Process $exe } }
$quit = {
  $n.Visible = $false
  $n.Dispose()
  Stop-Process -Name clipshare -Force -ErrorAction SilentlyContinue
  [Environment]::Exit(0)
}
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$openItem = New-Object System.Windows.Forms.ToolStripMenuItem("Open ClipShare")
$quitItem = New-Object System.Windows.Forms.ToolStripMenuItem("Quit")
$openItem.Add_Click($open)
$quitItem.Add_Click($quit)
$menu.Items.AddRange(@($openItem, $quitItem))
$n.ContextMenuStrip = $menu
$n.Add_MouseClick({ param($s, $e) if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { & $open } })
$watcher = New-Object System.Windows.Forms.Timer
$watcher.Interval = 2000
$watcher.Add_Tick({
  if (-not (Get-Process clipshare -ErrorAction SilentlyContinue)) {
    $n.Visible = $false
    $n.Dispose()
    [Environment]::Exit(0)
  }
})
$watcher.Start()
[System.Windows.Forms.Application]::Run()
''';
    try {
      _process = await Process.start('powershell', [
        '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-Command', script,
        Platform.resolvedExecutable,
      ]);
    } catch (_) {
      _started = false;
    }
  }

  Future<void> stop() async {
    _process?.kill();
    _process = null;
    _started = false;
  }
}

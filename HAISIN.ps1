# Win32API定義（SendMessage含む）

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

$SW_HIDE = 0
$hWnd = [Win32]::GetConsoleWindow()
if ($hWnd -ne [IntPtr]::Zero) {
    [Win32]::ShowWindow($hWnd, $SW_HIDE)
}

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern int SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);
}
"@

$SW_MINIMIZE = 6
$SW_HIDE = 0
$WM_COMMAND = 0x111
$MIN_ALL = 419

# .NET GUI準備
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Edgeパス
$edgePaths = @(
    "$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
)

# --- メインフォーム ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "　【　配　信　＆　ゲ　ー　ミ　ン　グ　ラ　ン　チ　ャ　ー　】"
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object Drawing.Size(540, 360)
$form.TopMost = $true
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 255)

# --- Write-Log 関数 ---
function Write-Log($msg) {
    try {
        $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $msg`r`n")
    } catch { Write-Host "ログ出力エラー: $_" }
}

# --- 配信開始ボタン押下時：OBS最小化 ---
$btnStart.Add_Click({
    try {
        $obsHwnd = [Win32]::FindWindow("Qt5QWindowIcon", $null)
        if ($obsHwnd -ne [IntPtr]::Zero) {
            [Win32]::ShowWindow($obsHwnd, $SW_MINIMIZE)
        }
        Write-Log "配信開始ボタン押下→OBS最小化！"
        $statusLabel.Text = "【配信中！】"
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(200, 40, 40)
        Start-Game
    } catch { Write-Log "OBS最小化エラー: $_" }
})

# --- OBS「配信開始」ボタン押下監視で最小化 ---
Start-Job -ScriptBlock {
    $SW_MINIMIZE = 6
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@ -ErrorAction SilentlyContinue
    $obsProcessName = "obs64"
    $alreadyMinimized = $false
    while ($true) {
        $obsProc = Get-Process -Name $obsProcessName -ErrorAction SilentlyContinue
        if ($obsProc) {
            foreach ($proc in $obsProc) {
                $hwnd = [Win32]::FindWindow($null, $proc.MainWindowTitle)
                if ($hwnd -ne 0 -and $proc.MainWindowTitle -match "配信中") {
                    if (-not $alreadyMinimized) {
                        [Win32]::ShowWindow($hwnd, $SW_MINIMIZE)
                        $alreadyMinimized = $true
                    }
                } else {
                    $alreadyMinimized = $false
                }
            }
        }
        Start-Sleep -Seconds 1
    }
} | Out-Null

# --- デスクトップ全部最小化 ---
$hShellTrayWnd = [Win32]::FindWindow("Shell_TrayWnd", $null)
if ($hShellTrayWnd -ne [IntPtr]::Zero) {
    [Win32.NativeMethods]::SendMessage($hShellTrayWnd, $WM_COMMAND, $MIN_ALL, 0)
    Write-Host "デスクトップ最小化コマンド送信完了！"
}

# --- フォームクローズ時イベント名修正！ ---
$form.Add_FormClosing({
    $_.Cancel = $true
    Show-AfterExitMenu
})

# デバッグ用に、表示中のウィンドウ全部ログ出す関数を1個つけとくと鬼便利！

function Show-AllWindows {
    $signature = @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class Win32Enum {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
}
"@
    Add-Type $signature -ErrorAction SilentlyContinue

    [Win32Enum+EnumWindowsProc]$callback = {
        param($hWnd, $lParam)
        $builder = New-Object System.Text.StringBuilder 1024
        [void][Win32Enum]::GetWindowText($hWnd, $builder, 1024)
        if ($builder.Length -gt 0) {
            Write-Host "Window: $($builder.ToString())"
        }
        return $true
    }

    [Win32Enum]::EnumWindows($callback, [IntPtr]::Zero)
}

# --- .NET GUI準備 ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

function Show-AfterExitMenu {
    # --- フォーム本体 ---
    $menuForm = New-Object System.Windows.Forms.Form
    $menuForm.Text = "　Windows 終了しますか？　"
    $menuForm.FormBorderStyle = 'FixedDialog'
    $menuForm.MaximizeBox = $false
    $menuForm.MinimizeBox = $false
    $menuForm.StartPosition = 'CenterScreen'
    $menuForm.Size = New-Object Drawing.Size(320,200)
    $menuForm.TopMost = $true
    $menuForm.BackColor = [System.Drawing.Color]::FromArgb(240,250,255)

    # 再起動ボタン
    $btnRestart = New-Object System.Windows.Forms.Button
    $btnRestart.Text = "再起動"
    $btnRestart.Location = New-Object Drawing.Point(30,30)
    $btnRestart.Size = New-Object Drawing.Size(110,36)
    $btnRestart.Font = New-Object Drawing.Font("Meiryo UI", 12, [Drawing.FontStyle]::Bold)
    $btnRestart.Add_Click({ 
        [System.Windows.Forms.MessageBox]::Show("龍神様が再起動ぶっ飛ばすばい！") 
        Restart-Computer
    })
    $menuForm.Controls.Add($btnRestart)

    # サスペンドボタン
    $btnSuspend = New-Object System.Windows.Forms.Button
    $btnSuspend.Text = "サスペンド"
    $btnSuspend.Location = New-Object Drawing.Point(160,30)
    $btnSuspend.Size = New-Object Drawing.Size(110,36)
    $btnSuspend.Font = New-Object Drawing.Font("Meiryo UI", 12, [Drawing.FontStyle]::Bold)
    $btnSuspend.Add_Click({
        [System.Windows.Forms.MessageBox]::Show("龍神様で眠らせるばい…zzz")
        Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class PowerState { [DllImport("Powrprof.dll", SetLastError=true)] public static extern bool SetSuspendState(bool hibernate, bool forceCritical, bool disableWakeEvent); }' -ErrorAction SilentlyContinue
        [void][PowerState]::SetSuspendState($false, $true, $true)
    })
    $menuForm.Controls.Add($btnSuspend)

    # シャットダウンボタン
    $btnShutdown = New-Object System.Windows.Forms.Button
    $btnShutdown.Text = "シャットダウン"
    $btnShutdown.Location = New-Object Drawing.Point(30,90)
    $btnShutdown.Size = New-Object Drawing.Size(110,36)
    $btnShutdown.Font = New-Object Drawing.Font("Meiryo UI", 12, [Drawing.FontStyle]::Bold)
    $btnShutdown.Add_Click({
        [System.Windows.Forms.MessageBox]::Show("龍神様がシャットダウンごり押しするばい！")
        Stop-Computer
    })
    $menuForm.Controls.Add($btnShutdown)

    # "終わらない"ボタン（Edgeでx.com開いてF11全画面）
    $btnEdge = New-Object System.Windows.Forms.Button
    $btnEdge.Text = "終わらない"
    $btnEdge.Location = New-Object Drawing.Point(160,90)
    $btnEdge.Size = New-Object Drawing.Size(110,36)
    $btnEdge.Font = New-Object Drawing.Font("Meiryo UI", 12, [Drawing.FontStyle]::Bold)

   $btnEdge.Add_Click({
    Start-Process "msedge.exe" "https://x.com"
    Start-Sleep -Seconds 3
    $wshell = New-Object -ComObject wscript.shell
    $wshell.SendKeys('{F11}')
})

    $menuForm.Controls.Add($btnEdge)

    # フォーム表示
    $menuForm.ShowDialog()
}

# Edgeのパス（必要ならここに追記できる）
$edgePaths = @(
    "$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
)

# --- GUI本体 ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "　【　配　信　＆　ゲ　ー　ミ　ン　グ　ラ　ン　チ　ャ　ー　】"
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object Drawing.Size(540, 360)
$form.TopMost = $true
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 255)

# --- 各部品 ---
$gameLabel = New-Object System.Windows.Forms.Label
$gameLabel.Text = "Platform："
$gameLabel.Location = New-Object Drawing.Point(40, 20)
$gameLabel.Size = New-Object Drawing.Size(80, 24)
$form.Controls.Add($gameLabel)

$chkTwitch = New-Object System.Windows.Forms.CheckBox
$chkTwitch.Text = "Twitch"
$chkTwitch.Location = New-Object Drawing.Point(130, 20)
$chkTwitch.Size = New-Object Drawing.Size(70, 20)
$form.Controls.Add($chkTwitch)

$chkYouTube = New-Object System.Windows.Forms.CheckBox
$chkYouTube.Text = "YouTube"
$chkYouTube.Location = New-Object Drawing.Point(210, 20)
$chkYouTube.Size = New-Object Drawing.Size(80, 20)
$form.Controls.Add($chkYouTube)

$chkTikTok = New-Object System.Windows.Forms.CheckBox
$chkTikTok.Text = "TikTok"
$chkTikTok.Location = New-Object Drawing.Point(310, 20)
$chkTikTok.Size = New-Object Drawing.Size(70, 20)
$form.Controls.Add($chkTikTok)

$gameLabel2 = New-Object System.Windows.Forms.Label
$gameLabel2.Text = "ゲーム選択："
$gameLabel2.Location = New-Object Drawing.Point(40, 60)
$gameLabel2.Size = New-Object Drawing.Size(80, 24)
$form.Controls.Add($gameLabel2)

$gameBox = New-Object Windows.Forms.ComboBox
$gameBox.Location = New-Object Drawing.Point(130, 56)
$gameBox.Size = New-Object Drawing.Size(260, 28)
$gameBox.Font = New-Object Drawing.Font("Meiryo UI", 10)
$gameBox.DropDownStyle = 'DropDownList'
$gameBox.Items.AddRange(@(
    "Apex Legends",
    "Asphalt Legends Unite",
    "鬼滅の刃ヒノカミ血風譚",
    "DISSIDIA Final Fantasy NT Free Edition",
    "Final Fantasy Ⅶ - EVER CRISIS",
    "Flash Party",
    "War Robots",
    "Hero Wars",
    "RAID: Shadow Legends"
))
$gameBox.SelectedIndex = 0
$form.Controls.Add($gameBox)

$timeLabel = New-Object System.Windows.Forms.Label
$timeLabel.Text = "配信時間："
$timeLabel.Location = New-Object Drawing.Point(40, 100)
$timeLabel.Size = New-Object Drawing.Size(80, 24)
$form.Controls.Add($timeLabel)

$timeBox = New-Object System.Windows.Forms.ComboBox
$timeBox.Location = New-Object Drawing.Point(130, 98)
$timeBox.Size = New-Object Drawing.Size(120, 28)
$timeBox.Font = New-Object Drawing.Font("Meiryo UI", 10)
$timeBox.DropDownStyle = 'DropDownList'
$timeBox.Items.AddRange(@("60分", "90分", "120分", "180分"))
$timeBox.SelectedIndex = 0
$form.Controls.Add($timeBox)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "【待機中】"
$statusLabel.Font = New-Object Drawing.Font("Meiryo UI", 10, [Drawing.FontStyle]::Bold)
$statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(60, 60, 180)
$statusLabel.Location = New-Object Drawing.Point(40, 140)
$statusLabel.Size = New-Object Drawing.Size(400, 24)
$form.Controls.Add($statusLabel)

$logLabel = New-Object System.Windows.Forms.Label
$logLabel.Text = "ログ："
$logLabel.Location = New-Object Drawing.Point(40, 170)
$logLabel.Size = New-Object Drawing.Size(50, 20)
$form.Controls.Add($logLabel)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ReadOnly = $true
$logBox.ScrollBars = "Vertical"
$logBox.Size = New-Object Drawing.Size(440, 70)
$logBox.Location = New-Object Drawing.Point(40, 190)
$logBox.BackColor = [System.Drawing.Color]::White
$logBox.Font = New-Object Drawing.Font("Consolas", 9)
$form.Controls.Add($logBox)

# --- ボタン定義（1回だけ！） ---
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "配信開始＋ゲーム起動"
$btnStart.Font = New-Object Drawing.Font("Meiryo UI", 10, [Drawing.FontStyle]::Bold)
$btnStart.BackColor = [System.Drawing.Color]::FromArgb(180, 240, 180)
$btnStart.Size = New-Object Drawing.Size(180, 36)
$btnStart.Location = New-Object Drawing.Point(40, 270)
$btnStart.Enabled = $false

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text = "配信停止"
$btnStop.Font = New-Object Drawing.Font("Meiryo UI", 10, [Drawing.FontStyle]::Bold)
$btnStop.BackColor = [System.Drawing.Color]::FromArgb(240, 210, 180)
$btnStop.Size = New-Object Drawing.Size(100, 36)
$btnStop.Location = New-Object Drawing.Point(240, 270)
$btnStop.Enabled = $false

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "終了"
$btnExit.Font = New-Object Drawing.Font("Meiryo UI", 10)
$btnExit.BackColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
$btnExit.Size = New-Object Drawing.Size(70, 36)
$btnExit.Location = New-Object Drawing.Point(370, 270)

$form.Controls.Add($btnStart)
$form.Controls.Add($btnStop)
$form.Controls.Add($btnExit)

$form.add_FormClosing({
    param($sender, $e)
    $e.Cancel = $true  # ← いったん終了キャンセル！
})

# --- Write-Log 関数 ---
function Write-Log($msg) {
    try {
        $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $msg`r`n")
    } catch { Write-Host "ログ出力エラー: $_" }
}

# --- Start-Game 関数 ---
function Start-Game {
    try {
        $game = $gameBox.SelectedItem
        switch -Wildcard ($game) {
            "*Hero Wars*" {
                $edgePaths = @(
                    "D:\\Microsoft\\Edge\\Application\\msedge.exe",
                    "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"
                )
                $edge = $edgePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
                if ($edge) {
                    Start-Process $edge -ArgumentList "https://www.hero-wars.com/"
                    Start-Sleep -Seconds 4
                    try { [System.Windows.Forms.SendKeys]::SendWait("{F11}") } catch { Write-Log "F11送信失敗: $_" }
                } else {
                    Write-Log "Edgeが見つからんばい！"
                }
            }
            "*Apex Legends*" { Start-Process "steam://rungameid/1172470" }
            "*Asphalt Legends Unite*" { Start-Process "steam://rungameid/2348720" }
            "*RAID: Shadow Legends*" { Start-Process "steam://rungameid/2333480" }
            "*DISSIDIA*" { Start-Process "steam://rungameid/921590" }
            "*鬼滅の刃*" { Start-Process "steam://rungameid/1490890" }
            "*FINAL FANTASY VII*" { Start-Process "steam://rungameid/2394010" }
            "*Flash Party*" { Start-Process "steam://rungameid/1934040" }
            "*War Robots*" { Start-Process "steam://rungameid/771410" }
            default { Write-Log "未対応ゲームばい！" }
        }
    } catch { Write-Log "ゲーム起動エラー: $_" }
}

# --- OBS配信開始自動クリック＋非表示 ---
function Start-OBS-With-Minimize {
    # OBS起動（Steam経由）→30秒待機→最小化
    $obsProcess = Start-Process "steam://run/1905180" -PassThru
    Start-Sleep -Seconds 30
    $hOBS = [Win32]::FindWindow("Qt5QWindowIcon", $null)
    if ($hOBS -ne [IntPtr]::Zero) {
        [Win32]::ShowWindow($hOBS, $SW_MINIMIZE)
        Write-Host "OBSウィンドウ最小化完了！（30秒後）"
    } else {
        Write-Host "OBSウィンドウ見つからんやったばい！"
    }
}

$btnStartOBS.Add_Click({
    Start-OBS-With-Minimize
})

# --- ボタンイベント登録 ---
$btnStart.Add_Click({
    try {
        $form.WindowState = 'Minimized'
        Start-Job -ScriptBlock {
            Start-Sleep -Seconds 30
            Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@ -ErrorAction SilentlyContinue
            $SW_MINIMIZE = 6
            $obsHwnd = [Win32]::FindWindow("Qt5QWindowIcon", $null)
            if ($obsHwnd -ne [IntPtr]::Zero) {
                [Win32]::ShowWindow($obsHwnd, $SW_MINIMIZE)
            }
        } | Out-Null
        $statusLabel.Text = "【配信中！】"
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(200, 40, 40)
        Write-Log "配信開始！"
        Click-OBS-StartStreaming
        Start-Game
        Write-Log "配信タイマー: $($timeBox.SelectedItem)"
    } catch { Write-Log "配信開始エラー: $_" }
})

$btnStop.Add_Click({
    try {
        $statusLabel.Text = "【配信停止＆全アプリ終了】"
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(60, 60, 180)
        Write-Log "配信停止＆全部終了ばい！"

        # Steam終了
        Get-Process steam -ErrorAction SilentlyContinue | ForEach-Object {
            $_.CloseMainWindow() | Out-Null
            Start-Sleep -Milliseconds 500
            if (!$_.HasExited) { $_.Kill() }
        }
        Write-Log "Steam終了！"

        # OBS終了
        Get-Process obs64 -ErrorAction SilentlyContinue | ForEach-Object {
            $_.CloseMainWindow() | Out-Null
            Start-Sleep -Milliseconds 500
            if (!$_.HasExited) { $_.Kill() }
        }
        Write-Log "OBS終了！"

        # ゲーム（起動タイトルでプロセス名変えてね！）
        $game = $gameBox.SelectedItem
        $gameProcMap = @{
            "Apex Legends" = "r5apex"
            "Asphalt Legends Unite" = "AsphaltLegendsUnite"
            "鬼滅の刃ヒノカミ血風譚" = "Hinokami"
            "DISSIDIA Final Fantasy NT Free Edition" = "DFFNT"
            "Final Fantasy Ⅶ - EVER CRISIS" = "ff7_ec"
            "Flash Party" = "FlashParty"
            "War Robots" = "WarRobots"
            "Hero Wars" = "msedge" # ブラウザで開く場合
            "RAID: Shadow Legends" = "Raid"
        }
        if ($gameProcMap.ContainsKey($game)) {
            $procname = $gameProcMap[$game]
            Get-Process $procname -ErrorAction SilentlyContinue | ForEach-Object {
                $_.CloseMainWindow() | Out-Null
                Start-Sleep -Milliseconds 500
                if (!$_.HasExited) { $_.Kill() }
            }
            Write-Log "$game 終了！"
        } else {
            Write-Log "ゲームプロセス名未設定やけん、手動で閉じてね！"
        }

        Write-Log "全部終わったばい！"
        # 必要ならフォームも閉じる
        $form.Close()
    } catch { Write-Log "全終了エラー: $_" }
})

$btnExit.Add_Click({
    try {
        $form.Hide()
        Show-AfterExitMenu
        $form.Close()
        $form.Dispose()
    } catch { [System.Windows.Forms.MessageBox]::Show("終了エラー: $_") }
})

$mainForm.Add_FormClosing({
    $_.Cancel = $true  # 閉じるのを止める
    Show-AfterExitMenu
})

# --- チェックボックス状態でボタン有効化 ---
$updateStartButtonState = {
    $enabled = $chkTwitch.Checked -or $chkYouTube.Checked -or $chkTikTok.Checked
    $btnStart.Enabled = $enabled
    $btnStop.Enabled = $enabled
}
$chkTwitch.Add_CheckedChanged($updateStartButtonState)
$chkYouTube.Add_CheckedChanged($updateStartButtonState)
$chkTikTok.Add_CheckedChanged($updateStartButtonState)

# --- GUI表示時の初期処理 ---
$form.Add_Shown({
    Write-Log "ようこそ！Platformをチェックせんと配信できんばい！"
    try {
        Start-Process "steam://rungameid/1905180"
        Start-Sleep -Seconds 3
        $steamClass = "CUIEngineWin32"
        $hSteam = [Win32]::FindWindow($steamClass, $null)
        if ($hSteam -ne 0) {
            [Win32]::ShowWindow($hSteam, $SW_HIDE)
            Write-Log "Steam非表示完了！"
        } else {
            Write-Log "Steamウィンドウ見つからんかったばい！"
        }
    } catch {
        Write-Log "Steam非表示エラー: $_"
    }
    # OBS配信開始を押したら最小化（無限ループJob）
    Start-Job -ScriptBlock {
        param($SW_MINIMIZE)
        Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@ -ErrorAction SilentlyContinue
        $obsProcessName = "obs64"
        $obsTitleMatch = "【配信中】"
        while ($true) {
            $obsProc = Get-Process -Name $obsProcessName -ErrorAction SilentlyContinue
            if ($obsProc) {
                foreach ($proc in $obsProc) {
                    $obsHwnd = [Win32]::FindWindow($null, $proc.MainWindowTitle)
                    if ($obsHwnd -ne 0) {
                        if ($proc.MainWindowTitle -match $obsTitleMatch) {
                            [Win32]::ShowWindow($obsHwnd, $SW_MINIMIZE)
                            break 2
                        }
                    }
                }
            }
            Start-Sleep -Seconds 2
        }
    } -ArgumentList $SW_MINIMIZE | Out-Null
})

[void]$form.ShowDialog()


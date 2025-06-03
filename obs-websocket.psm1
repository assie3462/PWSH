function Connect-OBSWebSocket {
    param (
        [string]$Url,
        [string]$Password
    )
    try {
        Write-Host "[MOCK] Connect-OBSWebSocket → URL: $Url / Password: $Password"
        return $true  # 接続成功を模擬
    } catch {
        Write-Host "[OBS] WebSocket接続エラー: $_"
        return $false
    }
}

function Start-OBSStream {
    try {
        Write-Host "[OBS] 配信開始（ダミー）"
    } catch {
        Write-Host "[OBS] 配信開始失敗: $_"
    }
}

function Stop-OBSStream {
    try {
        Write-Host "[OBS] 配信停止（ダミー）"
    } catch {
        Write-Host "[OBS] 配信停止失敗: $_"
    }
}

function Disconnect-OBSWebSocket {
    try {
        Write-Host "[MOCK] Disconnect-OBSWebSocket → 接続切断（ダミー）"
    } catch {
        Write-Host "[OBS] 切断エラー: $_"
    }
}

function Ensure-OBSRunning {
    try {
        if (-not (Get-Process -Name "obs64" -ErrorAction SilentlyContinue)) {
            Write-Host "[OBS] 起動してないけん、Steam経由で起動中..."
            Start-Process "steam://run/1905180"
            Start-Sleep -Seconds 7
            
            # 起動確認（最大3回試行）
            $maxRetries = 3
            for ($i = 1; $i -le $maxRetries; $i++) {
                if (Get-Process -Name "obs64" -ErrorAction SilentlyContinue) {
                    Write-Host "[OBS] 起動確認: OK"
                    break
                }
                Write-Host "[OBS] 起動未確認、再試行 ($i 回目)"
                Start-Sleep -Seconds 3
            }
        } else {
            Write-Host "[OBS] 既に起動中やけん、そのまま続行！"
        }
    } catch {
        Write-Host "[OBS] 起動エラー: $_"
    }
}

# **プロセスの存在確認後に終了**
function Stop-AllProcesses {
    try {
        if (Get-Process -Name "obs64" -ErrorAction SilentlyContinue) {
            Stop-Process -Name "obs64" -Force  # OBS 終了
            Write-Host "[終了] OBSを終了しました"
        }

        if (Get-Process -Name "ゲームの実行ファイル名をここに記入" -ErrorAction SilentlyContinue) {
            Stop-Process -Name "ゲームの実行ファイル名をここに記入" -Force  # ゲーム終了
            Write-Host "[終了] ゲームを終了しました"
        }

        if (Get-Process -Name "powershell" -ErrorAction SilentlyContinue) {
            Stop-Process -Name "powershell" -Force  # HAISIN.ps1 終了
            Write-Host "[終了] HAISIN.ps1 を終了しました"
        }
    } catch {
        Write-Host "[終了処理] エラー発生: $_"
    }
}

Export-ModuleMember -Function Connect-OBSWebSocket, Start-OBSStream, Stop-OBSStream, Disconnect-OBSWebSocket, Ensure-OBSRunning, Stop-AllProcesses

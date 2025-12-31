Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- 配置加载 ---
$configFile = "$PSScriptRoot\config.ini"
$config = @{ Color = "Cyan"; FontSize = "18"; X = "-1"; Y = "-1" }
if (Test-Path $configFile) { 
    $saved = ConvertFrom-StringData (Get-Content $configFile -Raw)
    foreach($k in $saved.Keys){ $config[$k] = $saved[$k] }
}

$workTime = 1200   # 20分钟工作 (1200秒)
$restTime = 20     # 20秒休息
$global:timeLeft = $workTime
$global:isResting = $false

# --- 窗口初始化 ---
$form = New-Object Windows.Forms.Form
$form.Size = New-Object Drawing.Size(160, 70)
$form.FormBorderStyle = "None"
$form.Topmost = $true
$form.ShowInTaskbar = $false 
$form.StartPosition = "Manual"
$form.BackColor = [Drawing.Color]::Maroon 
$form.TransparencyKey = [Drawing.Color]::Maroon 

if ($config.X -eq "-1") {
    $area = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $form.Location = New-Object Drawing.Point(($area.Width - 160), ($area.Height - 70))
} else {
    $form.Location = New-Object Drawing.Point([int]$config.X, [int]$config.Y)
}

$label = New-Object Windows.Forms.Label
$label.Dock = "Fill"
$label.TextAlign = "MiddleCenter"
$label.Font = New-Object Drawing.Font("Consolas", [float]$config.FontSize, [Drawing.FontStyle]::Bold)
$label.ForeColor = [Drawing.Color]::FromName($config.Color)
$label.BackColor = [Drawing.Color]::Transparent
$form.Controls.Add($label)

# --- 系统托盘 ---
$notifyIcon = New-Object Windows.Forms.NotifyIcon
$notifyIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Get-Process -Id $PID).Path)
$notifyIcon.Visible = $true
$notifyIcon.Text = "护眼助手 - 运行中"

# --- 逻辑保存 ---
function Save-Settings {
    $x = $form.Location.X; $y = $form.Location.Y; $fs = $label.Font.Size; $fc = $label.ForeColor.Name
    # 注意：这里保存的是用户设置的颜色，红色作为临时提醒状态不建议保存到配置文件
    if (-not $global:isResting) {
        "Color=$fc`nFontSize=$fs`nX=$x`nY=$y" | Set-Content $configFile
    } else {
        "Color=$($config.Color)`nFontSize=$fs`nX=$x`nY=$y" | Set-Content $configFile
    }
}

# --- 右键菜单 ---
$menu = New-Object Windows.Forms.ContextMenu
$mColor = $menu.MenuItems.Add("文字颜色 (Color)")
@("Cyan","Lime","White","Yellow","OrangeRed").ForEach({
    $c=$_; $it=$mColor.MenuItems.Add($c); $it.add_Click({
        $config.Color = $this.Text # 更新内存配置
        if(-not $global:isResting){ $label.ForeColor=[Drawing.Color]::FromName($this.Text) }
        Save-Settings
    })
})
$mSize = $menu.MenuItems.Add("字体大小 (Size)")
@(18,24,32,40,50).ForEach({
    $s=$_; $it=$mSize.MenuItems.Add("$s pt"); $it.add_Click({$sz=[float]($this.Text.Replace(" pt","")); $label.Font=New-Object Drawing.Font("Consolas",$sz,7); Save-Settings})
})
$menu.MenuItems.Add("立刻重置计时", { $global:timeLeft = $workTime; $global:isResting = $false; $label.ForeColor = [Drawing.Color]::FromName($config.Color) }) | Out-Null
$menu.MenuItems.Add("-") | Out-Null
$menu.MenuItems.Add("退出程序", { $notifyIcon.Visible = $false; Save-Settings; $form.Close(); Stop-Process -Id $PID }) | Out-Null
$notifyIcon.ContextMenu = $menu

# --- 增强拖拽 ---
$global:drag = $false
$label.Add_MouseDown({ if($_.Button -eq "Left"){$global:drag=$true; $global:mP=[Windows.Forms.Control]::MousePosition; $global:fP=$form.Location} })
$label.Add_MouseMove({ if($global:drag){$cP=[Windows.Forms.Control]::MousePosition; $form.Location=New-Object Drawing.Point(($global:fP.X+$cP.X-$global:mP.X),($global:fP.Y+$cP.Y-$global:mP.Y))} })
$label.Add_MouseUp({ $global:drag=$false; Save-Settings })

# --- 计时器核心逻辑 ---
$timer = New-Object Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({
    if ($global:timeLeft -gt 0) {
        $global:timeLeft--
        $label.Text = "{0:D2}:{1:D2}" -f ([int][Math]::Floor($global:timeLeft / 60)), ([int]($global:timeLeft % 60))
    } else {
        # 状态切换逻辑
        if (-not $global:isResting) {
            # 进入休息状态
            $global:isResting = $true
            $global:timeLeft = $restTime
            $label.ForeColor = [Drawing.Color]::Red  # 休息时变红
            $notifyIcon.ShowBalloonTip(1000, "护眼助手", "工作结束，红色20秒倒计时开始", [Windows.Forms.ToolTipIcon]::Info)
        } else {
            # 进入工作状态
            $global:isResting = $false
            $global:timeLeft = $workTime
            $label.ForeColor = [Drawing.Color]::FromName($config.Color) # 恢复设定颜色
            $notifyIcon.ShowBalloonTip(1000, "护眼助手", "休息结束，开始工作", [Windows.Forms.ToolTipIcon]::Info)
        }
    }
})

$timer.Start()
[Windows.Forms.Application]::Run($form)
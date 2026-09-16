$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing
Add-Type @'
using System;
using System.Threading;
using System.Runtime.InteropServices;
public static class OneClickInstance {
  private static Mutex mutex;
  private delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern IntPtr FindWindow(string cls, string title);
  [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr hwnd, System.Text.StringBuilder text, int max);
  [DllImport("user32.dll")] private static extern bool ShowWindow(IntPtr hwnd, int command);
  [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hwnd);
  public static bool Acquire() {
    bool created;
    mutex = new Mutex(true, "Local\\OneClickBeautify", out created);
    return created;
  }
  public static bool ActivateExisting() {
    IntPtr hwnd = FindWindow(null, "OneL");
    if (hwnd == IntPtr.Zero) {
      EnumWindows((candidate, unused) => {
        var title = new System.Text.StringBuilder(128);
        GetWindowText(candidate, title, title.Capacity);
        if (title.ToString() == "OneL") { hwnd = candidate; return false; }
        return true;
      }, IntPtr.Zero);
    }
    if (hwnd != IntPtr.Zero) {
      ShowWindow(hwnd, 9);
      SetForegroundWindow(hwnd);
      return true;
    }
    return false;
  }
}
'@
if (-not [OneClickInstance]::Acquire()) {
    if (-not [OneClickInstance]::ActivateExisting()) {
        [System.Windows.Forms.MessageBox]::Show('OneL 已经在后台运行，但找不到窗口。请在任务管理器中结束旧实例后重试。', 'OneL', 'OK', 'Warning') | Out-Null
    }
    [Environment]::Exit(0)
}

# The UI is hosted by powershell.exe, so without an explicit identity the
# taskbar groups this window under the generic PowerShell icon.  Claim our own
# AppUserModelID so the taskbar button uses the OneL window icon instead.
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class OneLAppId {
  [DllImport("shell32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  public static extern int SetCurrentProcessExplicitAppUserModelID(string appId);
}
'@
[void][OneLAppId]::SetCurrentProcessExplicitAppUserModelID('OneL.DesktopBeautify')

$appRoot = Split-Path -Parent $PSCommandPath
$dataRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'OneClickBeautify'
$probePath = Join-Path $dataRoot ([IO.Path]::GetRandomFileName())
try {
    [IO.Directory]::CreateDirectory($dataRoot) | Out-Null
    [IO.File]::WriteAllText($probePath, 'ok', [Text.UTF8Encoding]::new($false))
    [IO.File]::Delete($probePath)
} catch {
    if (Test-Path -LiteralPath $probePath) { Remove-Item -LiteralPath $probePath -Force -ErrorAction SilentlyContinue }
    $dataRoot = $appRoot
}
$configPath = Join-Path $dataRoot 'shortcuts.json'
$legacyConfigPath = Join-Path $appRoot 'shortcut-config.json'

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="OneL" Width="1080" Height="720" MinWidth="900" MinHeight="600" WindowStartupLocation="CenterScreen" Background="#FDF2F7" FontFamily="Segoe UI">
  <Window.Resources>
    <Style TargetType="Button">
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Padding" Value="16,8"/>
      <Setter Property="Margin" Value="0,0,8,0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="SnapsToDevicePixels" Value="True"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Border Name="bg" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="17"/>
              <Border Name="pressMask" Background="#28000000" CornerRadius="17" Opacity="0"/>
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="pressMask" Property="Opacity" Value="1"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.5"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ListBoxItem">
      <Setter Property="SnapsToDevicePixels" Value="True"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <Border Name="itemBg" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="30" Padding="{TemplateBinding Padding}">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="itemBg" Property="Background" Value="#FDF0F6"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="itemBg" Property="Background" Value="#FBE3EE"/>
                <Setter TargetName="itemBg" Property="BorderBrush" Value="#F2A9C6"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="#C0FFFFFF"/>
      <Setter Property="BorderBrush" Value="#EFC7D9"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="SnapsToDevicePixels" Value="True"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="18" Padding="18,0">
              <ScrollViewer x:Name="PART_ContentHost" Focusable="False" HorizontalScrollBarVisibility="Hidden" VerticalScrollBarVisibility="Hidden" VerticalAlignment="Center"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ComboBox">
      <Setter Property="Background" Value="#C0FFFFFF"/>
      <Setter Property="BorderBrush" Value="#EFC7D9"/>
      <Setter Property="SnapsToDevicePixels" Value="True"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBox">
            <Grid>
              <Border Name="cbBg" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="18"/>
              <ToggleButton Name="cbToggle" Focusable="False" ClickMode="Press" Background="Transparent" IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}">
                <ToggleButton.Template>
                  <ControlTemplate TargetType="ToggleButton">
                    <Border Background="Transparent"/>
                  </ControlTemplate>
                </ToggleButton.Template>
              </ToggleButton>
              <ContentPresenter Margin="18,0,36,0" VerticalAlignment="Center" HorizontalAlignment="Left" Content="{TemplateBinding SelectionBoxItem}" IsHitTestVisible="False"/>
              <Path Data="M0,0 L9,0 L4.5,5.5 Z" Fill="#8B7A85" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,16,0" IsHitTestVisible="False"/>
              <Popup AllowsTransparency="True" Focusable="False" Placement="Bottom" PopupAnimation="Slide" IsOpen="{TemplateBinding IsDropDownOpen}">
                <Border Background="White" BorderBrush="#F3D9E5" BorderThickness="1" CornerRadius="12" SnapsToDevicePixels="True" MinWidth="{Binding ActualWidth, RelativeSource={RelativeSource TemplatedParent}}">
                  <ScrollViewer MaxHeight="240">
                    <ItemsPresenter Margin="4"/>
                  </ScrollViewer>
                </Border>
              </Popup>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>
  <Grid Margin="22">
    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
    <DockPanel Grid.Row="0" Margin="0,0,0,18">
      <StackPanel DockPanel.Dock="Left">
        <TextBlock Text="OneL" FontSize="26" FontWeight="SemiBold" Foreground="#3E2A33"/>
        <TextBlock Text="把常用桌面状态收进快捷键，工作和美化一键切换" Margin="0,5,0,0" Foreground="#8B7A85" FontSize="13"/>
      </StackPanel>
      <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" VerticalAlignment="Center">
        <Button Name="AddShortcutButton" Content="＋ 新增快捷键" Background="#C0EE6FA8" Foreground="White" BorderThickness="0" ToolTip="创建一组新的快捷键配置"/>
        <Button Name="SettingsButton" Content="⚙ 设置" Background="#C0FFFFFF" Foreground="#4A3A42" BorderBrush="#EFC7D9" ToolTip="打开软件设置"/>
      </StackPanel>
    </DockPanel>
    <Grid Grid.Row="1">
      <Grid.ColumnDefinitions><ColumnDefinition Width="285"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
      <Border Grid.Column="0" Background="White" BorderBrush="#F3D9E5" BorderThickness="1" CornerRadius="8" Padding="14" Margin="0,0,16,0">
        <DockPanel>
          <StackPanel DockPanel.Dock="Top" Margin="4,2,4,12">
            <TextBlock Text="我的快捷键" FontSize="17" FontWeight="SemiBold" Foreground="#3E2A33"/>
            <TextBlock Name="ShortcutCountText" Text="0 组配置" Foreground="#9A8794" FontSize="12" Margin="0,4,0,0"/>
          </StackPanel>
          <ListBox Name="ShortcutList" BorderThickness="0" Background="Transparent" ScrollViewer.HorizontalScrollBarVisibility="Disabled"/>
        </DockPanel>
      </Border>
      <Border Grid.Column="1" Background="White" BorderBrush="#F3D9E5" BorderThickness="1" CornerRadius="8" Padding="24">
        <Grid>
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
          <DockPanel Grid.Row="0" Margin="0,0,0,18">
            <StackPanel DockPanel.Dock="Left">
              <TextBlock Text="当前快捷键" Foreground="#9A8794" FontSize="12"/>
              <TextBlock Name="SelectedTitle" Text="未选择快捷键" FontSize="23" FontWeight="SemiBold" Foreground="#3E2A33" Margin="0,3,0,0"/>
            </StackPanel>
            <StackPanel DockPanel.Dock="Right" HorizontalAlignment="Right">
              <TextBlock Text="组合键" Foreground="#9A8794" FontSize="11" HorizontalAlignment="Right"/>
              <TextBlock Name="SelectedHotkey" Text="未设置" Foreground="#35A0B8" FontSize="19" FontWeight="SemiBold" HorizontalAlignment="Right" Margin="0,3,0,0"/>
            </StackPanel>
          </DockPanel>
          <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel>
              <Border Background="#FBF4F7" BorderBrush="#E7F3F6" BorderThickness="1" CornerRadius="6" Padding="16" Margin="0,0,0,14">
                <StackPanel>
                  <TextBlock Text="快捷键信息" FontSize="15" FontWeight="SemiBold" Foreground="#3E2A33"/>
                  <TextBlock Text="名称会显示在左侧列表中，点击列表项即可编辑它。" Foreground="#8B7A85" FontSize="12" Margin="0,5,0,14"/>
                  <TextBlock Text="快捷键名称" Foreground="#6E5A66" FontSize="12"/>
                  <TextBox Name="ShortcutNameBox" Height="36" Margin="0,6,0,14" Padding="18,7" FontSize="15" MaxLength="40" ToolTip="给这组启动动作取一个名字"/>
                  <Grid>
                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="120"/></Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0" Margin="0,0,12,0">
                      <TextBlock Text="组合键" Foreground="#6E5A66" FontSize="12"/>
                      <ComboBox Name="ModifierBox" Height="36" Margin="0,6,0,0" SelectedIndex="1">
                        <ComboBoxItem Content="Ctrl + Alt" Tag="CtrlAlt"/>
                        <ComboBoxItem Content="Ctrl + Alt + Shift" Tag="CtrlAltShift"/>
                        <ComboBoxItem Content="Ctrl + Shift" Tag="CtrlShift"/>
                        <ComboBoxItem Content="Alt + Shift" Tag="AltShift"/>
                        <ComboBoxItem Content="Win + Alt" Tag="WinAlt"/>
                      </ComboBox>
                    </StackPanel>
                    <StackPanel Grid.Column="1">
                      <TextBlock Text="主键" Foreground="#6E5A66" FontSize="12"/>
                      <TextBox Name="KeyBox" Height="36" Margin="0,6,0,0" Padding="18,7" FontSize="16" MaxLength="1" ToolTip="输入一个字母或数字"/>
                    </StackPanel>
                  </Grid>
                  <TextBlock Name="ValidationText" Text="" FontSize="14" FontWeight="SemiBold" Foreground="#8B7A85" TextWrapping="Wrap" Margin="0,10,0,0"/>
                </StackPanel>
              </Border>
              <TextBlock Text="启动内容" FontSize="15" FontWeight="SemiBold" Foreground="#3E2A33" Margin="2,2,0,10"/>
              <TextBlock Text="已安装软件会自动列出，可滚动选择需要一起启动的应用" Foreground="#9A8794" FontSize="12" Margin="2,0,0,12"/>
              <StackPanel Name="SoftwareList">
                <Border Background="White" BorderBrush="#E7F3F6" BorderThickness="1" CornerRadius="6" Padding="14" Margin="0,0,0,10">
                  <CheckBox Name="DesktopIconsToggle" Content="隐藏桌面图标" IsChecked="False" FontSize="14" Foreground="#3E2A33"/>
                </Border>
                <Border Background="White" BorderBrush="#E7F3F6" BorderThickness="1" CornerRadius="6" Padding="14" Margin="0,0,0,10">
                  <CheckBox Name="TaskbarToggle" Content="隐藏任务栏" IsChecked="False" FontSize="14" Foreground="#3E2A33"/>
                </Border>
                <Border Background="White" BorderBrush="#E7F3F6" BorderThickness="1" CornerRadius="6" Padding="14" Margin="0,0,0,10">
                  <CheckBox Name="AutoHideTaskbarToggle" Content="自动隐藏任务栏" IsChecked="False" FontSize="14" Foreground="#3E2A33" ToolTip="开启后任务栏收起，鼠标移到屏幕底部自动浮现；关闭则任务栏始终显示。与「隐藏任务栏」互斥。"/>
                </Border>
              </StackPanel>
            </StackPanel>
          </ScrollViewer>
          <DockPanel Grid.Row="2" Margin="0,18,0,0">
            <Button Name="DeleteShortcutButton" Content="删除当前快捷键" DockPanel.Dock="Left" Background="#C0FFFFFF" Foreground="#D14D70" BorderBrush="#F2C3D2"/>
            <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
              <Button Name="SaveButton" Content="保存快捷键" Background="#C0EE6FA8" Foreground="White" BorderThickness="0" FontWeight="SemiBold" Margin="0"/>
            </StackPanel>
          </DockPanel>
        </Grid>
      </Border>
    </Grid>
  </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
$iconPath = Join-Path $appRoot 'OneL.ico'
if (Test-Path -LiteralPath $iconPath) {
    $iconStream = [IO.File]::OpenRead($iconPath)
    try {
        $iconFrame = [Windows.Media.Imaging.BitmapFrame]::Create($iconStream, [Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat, [Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
        $window.Icon = $iconFrame
    } finally { $iconStream.Dispose() }
}

$shortcutList = $window.FindName('ShortcutList')
$shortcutCountText = $window.FindName('ShortcutCountText')
$selectedTitle = $window.FindName('SelectedTitle')
$selectedHotkey = $window.FindName('SelectedHotkey')
$shortcutNameBox = $window.FindName('ShortcutNameBox')
$modifierBox = $window.FindName('ModifierBox')
$keyBox = $window.FindName('KeyBox')
$validationText = $window.FindName('ValidationText')
$softwareList = $window.FindName('SoftwareList')
$desktopIconsToggle = $window.FindName('DesktopIconsToggle')
$taskbarToggle = $window.FindName('TaskbarToggle')
$autoHideTaskbarToggle = $window.FindName('AutoHideTaskbarToggle')
$addShortcutButton = $window.FindName('AddShortcutButton')
$settingsButton = $window.FindName('SettingsButton')
$saveButton = $window.FindName('SaveButton')
$deleteShortcutButton = $window.FindName('DeleteShortcutButton')

# --- Hover scale: buttons gently grow while the pointer is over them and
# shrink back on leave.  The pressed-state darkening is handled by the pill
# ControlTemplate's pressMask overlay.
function Start-HoverScale($button, [double]$target) {
    $st = $button.RenderTransform.Children[0]
    $ease = New-Object System.Windows.Media.Animation.CubicEase
    $ease.EasingMode = 'EaseOut'
    foreach ($prop in @([System.Windows.Media.ScaleTransform]::ScaleXProperty, [System.Windows.Media.ScaleTransform]::ScaleYProperty)) {
        $anim = New-Object System.Windows.Media.Animation.DoubleAnimation
        $anim.To = $target
        $anim.Duration = New-Object System.Windows.Duration([TimeSpan]::FromMilliseconds(170))
        $anim.EasingFunction = $ease
        $st.BeginAnimation($prop, $anim)
    }
}

function Attach-HoverScale($button) {
    $button.RenderTransformOrigin = [Windows.Point]::new(0.5, 0.5)
    $group = New-Object System.Windows.Media.TransformGroup
    [void]$group.Children.Add((New-Object System.Windows.Media.ScaleTransform(1, 1)))
    $button.RenderTransform = $group
    $button.Add_MouseEnter({ param($sender, $e) Start-HoverScale $sender 1.06 })
    $button.Add_MouseLeave({ param($sender, $e) Start-HoverScale $sender 1.0 })
}
foreach ($hoverButton in @($addShortcutButton, $settingsButton, $saveButton, $deleteShortcutButton)) { Attach-HoverScale $hoverButton }

function Get-InstalledApps {
    $items = [System.Collections.ArrayList]::new()
    $seenPaths = @{}
    $seenNames = @{}
    try { $shell = New-Object -ComObject WScript.Shell } catch { return @() }
    $roots = @(
        (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
        (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs')
    )
    $skipName = '卸载|uninstall|readme|release notes|website|manual|documentation|帮助|安装|setup|repair|reset|update|工具|settings|设置|command prompt|powershell|控制面板|control panel|task manager|任务管理器'
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        Get-ChildItem -LiteralPath $root -Recurse -Filter '*.lnk' -File -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $shortcut = $shell.CreateShortcut($_.FullName)
                $target = [string]$shortcut.TargetPath
            } catch { return }
            if ([string]::IsNullOrWhiteSpace($target) -or [IO.Path]::GetExtension($target).ToLowerInvariant() -ne '.exe') { return }
            if (-not (Test-Path -LiteralPath $target)) { return }
            $name = [IO.Path]::GetFileNameWithoutExtension($_.Name).Trim()
            if ([string]::IsNullOrWhiteSpace($name) -or $name -match $skipName) { return }
            if ($target -match '\\Windows\\|\\System32\\|\\SysWOW64\\') { return }
            if ($seenPaths.ContainsKey($target) -or $seenNames.ContainsKey($name)) { return }
            $seenPaths[$target] = $true
            $seenNames[$name] = $true
            [void]$items.Add([pscustomobject]@{ Name=$name; Description='已安装应用'; Path=$target })
        }
    }
    $items | Sort-Object Name
}

function Find-TranslucentTBPath {
    # The release archive no longer bundles TranslucentTB.  Keep the switch
    # available when the user has installed it separately, while still
    # supporting an older unpacked folder that contains the portable build.
    $candidates = @(
        (Join-Path $appRoot 'TranslucentTB-portable-x64\TranslucentTB.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\TranslucentTB.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\TranslucentTB\TranslucentTB.exe'),
        (Join-Path $env:ProgramFiles 'TranslucentTB\TranslucentTB.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'TranslucentTB\TranslucentTB.exe')
    )
    try {
        $command = Get-Command 'TranslucentTB.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command -and $command.Source) { $candidates += [string]$command.Source }
    } catch { }
    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    return $null
}

function Find-WallpaperEnginePath {
    # Wallpaper Engine ships through Steam and creates no Start-menu shortcut,
    # so the installed-app scan above can never see it.  Locate it from its
    # auto-start registry entry, then the Steam library folders.
    $candidates = [System.Collections.ArrayList]::new()
    try {
        $run = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction Stop
        $command = [string]$run.'WallpaperEngine'
        if ($command) {
            if ($command -match '"(.*?\.exe)"') { [void]$candidates.Add($Matches[1]) }
            elseif ($command -match '(?i)^(.*?\.exe)(\s|$)') { [void]$candidates.Add($Matches[1]) }
        }
    } catch { }
    $steamDirs = [System.Collections.Generic.List[string]]::new()
    try {
        $installed = [string](Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction Stop).SteamPath
        if ($installed) { $steamDirs.Add($installed.TrimEnd('\')) }
    } catch { }
    foreach ($fallback in @('C:\Program Files (x86)\Steam', 'C:\Program Files\Steam', 'D:\Steam', 'E:\Steam', 'F:\Steam')) {
        if (Test-Path -LiteralPath $fallback) { $steamDirs.Add($fallback) }
    }
    $libraryDirs = [System.Collections.Generic.List[string]]::new()
    foreach ($steam in $steamDirs) {
        if ($libraryDirs -notcontains $steam) { $libraryDirs.Add($steam) }
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (-not (Test-Path -LiteralPath $vdf)) { $vdf = Join-Path $steam 'config\libraryfolders.vdf' }
        if (-not (Test-Path -LiteralPath $vdf)) { continue }
        try {
            Get-Content -LiteralPath $vdf -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_ -match '"path"\s+"(.*?)"') {
                    $path = ($Matches[1] -replace '\\\\', '\').TrimEnd('\')
                    if ($path -and $libraryDirs -notcontains $path) { $libraryDirs.Add($path) }
                }
            }
        } catch { }
    }
    foreach ($library in $libraryDirs) {
        $installDir = Join-Path $library 'steamapps\common\wallpaper_engine'
        if (-not (Test-Path -LiteralPath $installDir)) { $installDir = Join-Path $library 'common\wallpaper_engine' }
        [void]$candidates.Add((Join-Path $installDir 'wallpaper64.exe'))
        [void]$candidates.Add((Join-Path $installDir 'wallpaper32.exe'))
    }
    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    return $null
}

function Find-ClashVergePath {
    # Start-menu discovery is convenient, but it can miss a portable or
    # manually moved Clash Verge installation.  Keep the known installation
    # location as a direct fallback so the saved switch remains usable.
    $candidates = @(
        'D:\Clash\clash-verge.exe',
        (Join-Path $env:ProgramFiles 'Clash Verge\clash-verge.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Clash Verge\clash-verge.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Clash Verge\clash-verge.exe')
    )
    foreach ($root in @(
        (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
        (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs')
    )) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        try {
            $shell = New-Object -ComObject WScript.Shell
            Get-ChildItem -LiteralPath $root -Recurse -Filter '*Clash*.lnk' -File -ErrorAction SilentlyContinue | ForEach-Object {
                $shortcut = $shell.CreateShortcut($_.FullName)
                if ($shortcut.TargetPath) { $candidates += [string]$shortcut.TargetPath }
            }
        } catch { }
    }
    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    return $null
}

$fixedApps = @(
    [pscustomobject]@{ Name='Nexus'; Description='Winstep Nexus Dock'; Path='D:\nexus\Winstep\Nexus.exe' }
)
$translucentPath = Find-TranslucentTBPath
if ($translucentPath) {
    $fixedApps += [pscustomobject]@{ Name='TranslucentTB'; Description='透明任务栏（需单独安装）'; Path=$translucentPath }
}
$clashPath = Find-ClashVergePath
if ($clashPath) {
    $fixedApps += [pscustomobject]@{ Name='Clash Verge'; Description='Clash Verge Rev'; Path=$clashPath }
}
$wallpaperPath = Find-WallpaperEnginePath
if ($wallpaperPath) {
    $fixedApps += [pscustomobject]@{ Name='Wallpaper Engine'; Description='Steam 动态壁纸'; Path=$wallpaperPath }
}
$discoveredApps = @(Get-InstalledApps | Where-Object { $_.Name -notin @('Nexus','TranslucentTB','Wallpaper Engine','wallpaper64','wallpaper32') })
$apps = @($fixedApps + ($discoveredApps | Where-Object { $_.Name -ne 'Clash Verge' }))

function Get-ConfigValue($object, [string]$name, $fallback) {
    if ($null -ne $object) {
        $property = $object.PSObject.Properties[$name]
        if ($null -ne $property) { return $property.Value }
    }
    return $fallback
}

function Get-KeyCode([string]$value) {
    if ([string]::IsNullOrWhiteSpace($value)) { return 0 }
    $ch = $value.Trim().ToUpperInvariant()[0]
    if (($ch -ge 'A' -and $ch -le 'Z') -or ($ch -ge '0' -and $ch -le '9')) { return [int][char]$ch }
    return 0
}

function Get-ModCode([string]$tag) {
    switch ($tag) {
        'CtrlAlt' { return 3 }
        'CtrlAltShift' { return 7 }
        'CtrlShift' { return 6 }
        'AltShift' { return 5 }
        'WinAlt' { return 9 }
    }
    return 7
}

function Get-ModTag($profile) {
    $tag = [string](Get-ConfigValue $profile 'ModifierTag' 'CtrlAltShift')
    if ($tag -notin @('CtrlAlt','CtrlAltShift','CtrlShift','AltShift','WinAlt')) { return 'CtrlAltShift' }
    return $tag
}

function New-Profile([string]$name = '新快捷键', [string]$tag = 'CtrlAltShift', [string]$key = 'P') {
    $appState = [ordered]@{}
    foreach ($app in $apps) { $appState[$app.Name] = $false }
    [pscustomobject]@{
        Id = [guid]::NewGuid().ToString('N')
        Name = $name
        ModifierTag = $tag
        Key = $key
        DesktopIcons = $false
        Taskbar = $false
        AutoHideTaskbar = $false
        Pending = $false
        Apps = $appState
    }
}

function ConvertTo-Profile($source) {
    $profile = New-Profile
    $profile.Id = [string](Get-ConfigValue $source 'Id' $profile.Id)
    $profile.Name = [string](Get-ConfigValue $source 'Name' '未命名快捷键')
    if ([string]::IsNullOrWhiteSpace($profile.Name)) { $profile.Name = '未命名快捷键' }
    $profile.ModifierTag = Get-ModTag $source
    $profile.Key = ([string](Get-ConfigValue $source 'Key' 'P')).Trim().ToUpperInvariant()
    if ($profile.Key.Length -gt 1) { $profile.Key = $profile.Key.Substring(0,1) }
    $profile.DesktopIcons = [bool](Get-ConfigValue $source 'DesktopIcons' $false)
    $profile.Taskbar = [bool](Get-ConfigValue $source 'Taskbar' $false)
    $profile.AutoHideTaskbar = [bool](Get-ConfigValue $source 'AutoHideTaskbar' $false)
    $profile.Pending = [bool](Get-ConfigValue $source 'Pending' $false)
    $savedApps = Get-ConfigValue $source 'Apps' $null
    foreach ($app in $apps) { $profile.Apps[$app.Name] = [bool](Get-ConfigValue $savedApps $app.Name $false) }
    return $profile
}

function Read-ConfigObject {
    foreach ($path in @($configPath, $legacyConfigPath)) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        try {
            $raw = [IO.File]::ReadAllText($path, [Text.UTF8Encoding]::new($false))
            if (-not [string]::IsNullOrWhiteSpace($raw)) { return ($raw | ConvertFrom-Json) }
        } catch { }
    }
    return $null
}

$configObject = Read-ConfigObject
$profiles = [System.Collections.ArrayList]::new()
if ($configObject -and $configObject.Shortcuts) {
    foreach ($source in @($configObject.Shortcuts)) { [void]$profiles.Add((ConvertTo-Profile $source)) }
} elseif ($configObject) {
    [void]$profiles.Add((ConvertTo-Profile $configObject))
} else {
    [void]$profiles.Add((New-Profile '美化模式' 'CtrlAltShift' 'N'))
}
if ($profiles.Count -eq 0) { [void]$profiles.Add((New-Profile '美化模式' 'CtrlAltShift' 'N')) }

$settingsSource = Get-ConfigValue $configObject 'Settings' $null
$settings = [ordered]@{
    StartWithWindows = [bool](Get-ConfigValue $settingsSource 'StartWithWindows' $false)
    StartMinimized = [bool](Get-ConfigValue $settingsSource 'StartMinimized' $false)
    ShowSaveNotification = [bool](Get-ConfigValue $settingsSource 'ShowSaveNotification' $true)
    LastSelectedId = [string](Get-ConfigValue $settingsSource 'LastSelectedId' '')
}

function Save-AllProfiles {
    $shortcutData = @($profiles | ForEach-Object {
        $appState = [ordered]@{}
        foreach ($app in $apps) { $appState[$app.Name] = [bool]$_.Apps[$app.Name] }
        [ordered]@{
            Id = $_.Id
            Name = $_.Name
            ModifierTag = $_.ModifierTag
            Key = $_.Key
            DesktopIcons = [bool]$_.DesktopIcons
            Taskbar = [bool]$_.Taskbar
            AutoHideTaskbar = [bool]$_.AutoHideTaskbar
            Pending = [bool]$_.Pending
            Apps = $appState
        }
    })
    $config = [ordered]@{ Version = 2; Shortcuts = $shortcutData; Settings = $settings }
    $json = $config | ConvertTo-Json -Depth 8
    [IO.Directory]::CreateDirectory($dataRoot) | Out-Null
    $tempPath = Join-Path $dataRoot ([IO.Path]::GetRandomFileName())
    try {
        [IO.File]::WriteAllText($tempPath, $json, [Text.UTF8Encoding]::new($true))
        Move-Item -LiteralPath $tempPath -Destination $configPath -Force
    } catch {
        if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue }
        throw
    }
}

function Get-ProfileHotkey($profile) {
    $item = $modifierBox.Items | Where-Object { $_.Tag -eq $profile.ModifierTag } | Select-Object -First 1
    $label = if ($item) { $item.Content.ToString() } else { 'Ctrl + Alt + Shift' }
    $key = if ([string]::IsNullOrWhiteSpace($profile.Key)) { '?' } else { $profile.Key.ToUpperInvariant() }
    return "$label + $key"
}

function Update-SelectedHotkeyDisplay($profile) {
    # A freshly added profile still carries the placeholder combination until
    # the user saves; show a neutral hint instead of a misleading shortcut.
    if ($profile.Pending) {
        $selectedHotkey.Text = '暂未设置快捷键组合'
        $selectedHotkey.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#9A8794')
    } else {
        $selectedHotkey.Text = Get-ProfileHotkey $profile
        $selectedHotkey.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#35A0B8')
    }
}

$checks = @{}
foreach ($app in $apps) {
    $panel = New-Object System.Windows.Controls.Border
    $panel.Background = [Windows.Media.Brushes]::White
    $panel.BorderBrush = [Windows.Media.BrushConverter]::new().ConvertFromString('#E7F3F6')
    $panel.BorderThickness = [Windows.Thickness]::new(1)
    $panel.CornerRadius = [Windows.CornerRadius]::new(6)
    $panel.Padding = [Windows.Thickness]::new(14)
    $panel.Margin = [Windows.Thickness]::new(0,0,0,10)
    $row = New-Object System.Windows.Controls.DockPanel
    $check = New-Object System.Windows.Controls.CheckBox
    $check.VerticalAlignment = 'Center'
    $check.Width = 24
    [System.Windows.Automation.AutomationProperties]::SetName($check, $app.Name)
    [System.Windows.Automation.AutomationProperties]::SetAutomationId($check, ('AppToggle_' + ($app.Name -replace '[^A-Za-z0-9_]', '_')))
    $name = New-Object System.Windows.Controls.TextBlock
    $name.Text = $app.Name; $name.FontSize = 15; $name.FontWeight = 'SemiBold'; $name.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#3E2A33')
    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = $app.Description; $desc.FontSize = 12; $desc.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#8B7A85'); $desc.Margin = [Windows.Thickness]::new(0,3,0,0)
    $textStack = New-Object System.Windows.Controls.StackPanel
    [void]$textStack.Children.Add($name); [void]$textStack.Children.Add($desc)
    [void]$row.Children.Add($check); [void]$row.Children.Add($textStack)
    $panel.Child = $row
    [void]$softwareList.Children.Add($panel)
    $checks[$app.Name] = $check
}

$selectedIndex = 0
$suppressSelection = $false
$listRows = [System.Collections.ArrayList]::new()
$registeredIds = @{}
$registeredHotkeySpecs = @{}
$hotkeyIdBase = 1200
$hwndSource = $null
$activeProfiles = @{}
$script:allowClose = $false
$script:savedWindowBounds = $null
$script:trayIcon = $null

function Set-Validation([string]$message, [string]$kind = 'normal') {
    $validationText.Text = $message
    $color = switch ($kind) { 'ok' { '#2F855A' }; 'warn' { '#B7791F' }; 'error' { '#D14D70' }; default { '#8B7A85' } }
    $validationText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString($color)
}

function Show-TrayStatus([string]$message, [string]$kind = 'info') {
    if (-not $script:trayIcon -or -not $script:trayIcon.Visible) { return }
    $script:trayIcon.BalloonTipTitle = 'OneL'
    $script:trayIcon.BalloonTipText = $message
    $script:trayIcon.BalloonTipIcon = if ($kind -eq 'error') { [System.Windows.Forms.ToolTipIcon]::Error } elseif ($kind -eq 'warn') { [System.Windows.Forms.ToolTipIcon]::Warning } else { [System.Windows.Forms.ToolTipIcon]::Info }
    $script:trayIcon.ShowBalloonTip(5000)
}

function Format-RegistrationErrors($errors) {
    return (@($errors | ForEach-Object { if ($_.Display) { $_.Display } else { [string]$_ } }) -join '、')
}

$script:bannerWindow = $null
function Show-ModeBanner([string]$text, [string]$kind) {
    # Soft pill banner sliding in at the top-center of the work area to
    # announce a mode switch: pink-cyan gradient for "on", white-pink for
    # "off".  Fades in, holds two seconds, fades out; never steals focus.
    try {
        if ($script:bannerWindow) { try { $script:bannerWindow.Close() } catch { } }
        $w = New-Object System.Windows.Window
        $w.WindowStyle = [System.Windows.WindowStyle]::None
        $w.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $w.AllowsTransparency = $true
        $w.Background = [System.Windows.Media.Brushes]::Transparent
        $w.Topmost = $true
        $w.ShowInTaskbar = $false
        $w.ShowActivated = $false
        $w.IsHitTestVisible = $false
        $w.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $border = New-Object System.Windows.Controls.Border
        $border.CornerRadius = [System.Windows.CornerRadius]::new(21)
        $border.Padding = [System.Windows.Thickness]::new(22, 10, 22, 10)
        $grad = New-Object System.Windows.Media.LinearGradientBrush
        $grad.StartPoint = [System.Windows.Point]::new(0, 0)
        $grad.EndPoint = [System.Windows.Point]::new(1, 0)
        if ($kind -eq 'on') {
            [void]$grad.GradientStops.Add([System.Windows.Media.GradientStop]::new([System.Windows.Media.Color]::FromRgb(238, 111, 168), 0))
            [void]$grad.GradientStops.Add([System.Windows.Media.GradientStop]::new([System.Windows.Media.Color]::FromRgb(53, 160, 184), 1))
            $fg = [System.Windows.Media.Brushes]::White
            $shadowColor = [System.Windows.Media.Color]::FromRgb(238, 111, 168)
        } else {
            [void]$grad.GradientStops.Add([System.Windows.Media.GradientStop]::new([System.Windows.Media.Color]::FromRgb(255, 255, 255), 0))
            [void]$grad.GradientStops.Add([System.Windows.Media.GradientStop]::new([System.Windows.Media.Color]::FromRgb(251, 227, 238), 1))
            $fg = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(62, 42, 51))
            $shadowColor = [System.Windows.Media.Color]::FromRgb(190, 160, 180)
        }
        $border.Background = $grad
        $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
        $shadow.BlurRadius = 24; $shadow.ShadowDepth = 0; $shadow.Opacity = 0.35; $shadow.Color = $shadowColor
        $border.Effect = $shadow
        $stack = New-Object System.Windows.Controls.StackPanel
        $stack.Orientation = [System.Windows.Controls.Orientation]::Horizontal
        $glyph = New-Object System.Windows.Controls.TextBlock
        $glyph.Text = if ($kind -eq 'on') { '⚡' } else { '✓' }
        $glyph.FontSize = 17; $glyph.Foreground = $fg; $glyph.VerticalAlignment = 'Center'; $glyph.Margin = [System.Windows.Thickness]::new(0, 0, 10, 0)
        $label = New-Object System.Windows.Controls.TextBlock
        $label.Text = $text; $label.FontSize = 16; $label.FontWeight = [System.Windows.FontWeights]::SemiBold; $label.Foreground = $fg; $label.VerticalAlignment = 'Center'
        [void]$stack.Children.Add($glyph); [void]$stack.Children.Add($label)
        $border.Child = $stack
        $w.Content = $border
        $w.Add_ContentRendered({
            param($sender, $e)
            try {
                $wa = [System.Windows.SystemParameters]::WorkArea
                $sender.Left = $wa.X + ($wa.Width - $sender.ActualWidth) / 2
                $sender.Top = $wa.Y + 26
            } catch { }
        })
        $w.Add_Closed({ param($sender, $e) if ($script:bannerWindow -eq $sender) { $script:bannerWindow = $null } })
        $tt = New-Object System.Windows.Media.TranslateTransform(0, -14)
        $border.RenderTransform = $tt
        $w.Opacity = 0
        $script:bannerWindow = $w
        $w.Show()
        $ease = New-Object System.Windows.Media.Animation.CubicEase
        $ease.EasingMode = 'EaseOut'
        $fade = New-Object System.Windows.Media.Animation.DoubleAnimation
        $fade.To = 1
        $fade.Duration = New-Object System.Windows.Duration([TimeSpan]::FromMilliseconds(240))
        $fade.EasingFunction = $ease
        $w.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fade)
        $slide = New-Object System.Windows.Media.Animation.DoubleAnimation
        $slide.To = 0
        $slide.Duration = New-Object System.Windows.Duration([TimeSpan]::FromMilliseconds(320))
        $slide.EasingFunction = $ease
        $tt.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $slide)
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromMilliseconds(2000)
        $timer.Add_Tick({
            param($s, $e)
            $s.Stop()
            $win = $script:bannerWindow
            if (-not $win) { return }
            try {
                $out = New-Object System.Windows.Media.Animation.DoubleAnimation
                $out.To = 0
                $out.Duration = New-Object System.Windows.Duration([TimeSpan]::FromMilliseconds(420))
                $win.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $out)
            } catch { }
            $closer = New-Object System.Windows.Threading.DispatcherTimer
            $closer.Interval = [TimeSpan]::FromMilliseconds(480)
            $closer.Add_Tick({ param($c, $e2) $c.Stop(); try { if ($script:bannerWindow) { $script:bannerWindow.Close() } } catch { } })
            $closer.Start()
        })
        $timer.Start()
    } catch { }
}

function Show-SaveFeedback([string]$message, [string]$kind = 'ok', [bool]$forceNotification = $false) {
    Set-Validation $message $kind
    if ($forceNotification -or $settings.ShowSaveNotification) {
        $icon = if ($kind -eq 'error') { 'Error' } elseif ($kind -eq 'warn') { 'Warning' } else { 'Information' }
        [System.Windows.MessageBox]::Show($message, 'OneL', 'OK', $icon) | Out-Null
    }
}

function Show-MainWindow {
    $window.ShowInTaskbar = $true
    $window.WindowState = 'Normal'
    if ($script:savedWindowBounds) {
        $window.Left = [double]$script:savedWindowBounds.Left
        $window.Top = [double]$script:savedWindowBounds.Top
        $script:savedWindowBounds = $null
    }
    $window.Activate()
    if ($script:trayIcon) { $script:trayIcon.Visible = $true }
}

function Initialize-TrayIcon {
    $tray = New-Object System.Windows.Forms.NotifyIcon
    $tray.Text = 'OneL'
    $iconPath = Join-Path $appRoot 'OneL.ico'
    try {
        if (Test-Path -LiteralPath $iconPath) { $tray.Icon = New-Object System.Drawing.Icon($iconPath) }
        else { $tray.Icon = [System.Drawing.SystemIcons]::Application }
    } catch { $tray.Icon = [System.Drawing.SystemIcons]::Application }

    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    $showItem = $menu.Items.Add('打开 OneL')
    $exitItem = $menu.Items.Add('退出程序')
    $showItem.Add_Click({ Show-MainWindow })
    $exitItem.Add_Click({
        $script:allowClose = $true
        if ($script:trayIcon) { $script:trayIcon.Visible = $false }
        $window.Close()
    })
    $tray.ContextMenuStrip = $menu
    $tray.Add_DoubleClick({ Show-MainWindow })
    # Keep a discoverable entry in the notification area while the hotkey
    # listener is alive, including when the main window is open.
    $tray.Visible = $true
    $script:trayIcon = $tray
}

function Refresh-ShortcutList {
    $keepIndex = $selectedIndex
    $script:suppressSelection = $true
    try {
        $shortcutList.Items.Clear()
        $listRows.Clear()
        for ($i = 0; $i -lt $profiles.Count; $i++) {
            $profile = $profiles[$i]
            $item = New-Object System.Windows.Controls.ListBoxItem
            $item.Padding = [Windows.Thickness]::new(12,10,10,10)
            $item.Margin = [Windows.Thickness]::new(0,0,0,6)
            $item.BorderThickness = [Windows.Thickness]::new(1)
            $item.BorderBrush = [Windows.Media.BrushConverter]::new().ConvertFromString('#F4E1EA')
            $item.Background = [Windows.Media.Brushes]::White
            $item.Tag = $i
            $stack = New-Object System.Windows.Controls.StackPanel
            $nameText = New-Object System.Windows.Controls.TextBlock
            $nameText.Text = $profile.Name; $nameText.FontSize = 15; $nameText.FontWeight = 'SemiBold'; $nameText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#3E2A33')
            $hotkeyText = New-Object System.Windows.Controls.TextBlock
            if ($profile.Pending) {
                $hotkeyText.Text = '暂未设置'
                $hotkeyText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#9A8794')
            } else {
                $hotkeyText.Text = Get-ProfileHotkey $profile
                $hotkeyText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#4E9FB5')
            }
            $hotkeyText.FontSize = 12; $hotkeyText.Margin = [Windows.Thickness]::new(0,4,0,0)
            [void]$stack.Children.Add($nameText); [void]$stack.Children.Add($hotkeyText)
            $item.Content = $stack
            [void]$shortcutList.Items.Add($item)
            [void]$listRows.Add([pscustomobject]@{ Item=$item; NameText=$nameText; HotkeyText=$hotkeyText })
        }
    } finally { $script:suppressSelection = $false }
    $shortcutCountText.Text = "$($profiles.Count) 组配置"
    if ($profiles.Count -gt 0) {
        $targetIndex = [Math]::Min($keepIndex, $profiles.Count - 1)
        $script:selectedIndex = $targetIndex
        $shortcutList.SelectedIndex = $targetIndex
        Set-UiFromProfile $profiles[$targetIndex]
    }
}

function Set-UiFromProfile($profile) {
    if ($null -eq $profile) { return }
    $shortcutNameBox.Text = $profile.Name
    $savedItem = $modifierBox.Items | Where-Object { $_.Tag -eq $profile.ModifierTag } | Select-Object -First 1
    if ($savedItem) { $modifierBox.SelectedItem = $savedItem } else { $modifierBox.SelectedIndex = 1 }
    $keyBox.Text = $profile.Key
    $desktopIconsToggle.IsChecked = [bool]$profile.DesktopIcons
    $taskbarToggle.IsChecked = [bool]$profile.Taskbar
    $autoHideTaskbarToggle.IsChecked = [bool]$profile.AutoHideTaskbar
    foreach ($app in $apps) { $checks[$app.Name].IsChecked = [bool]$profile.Apps[$app.Name] }
    $selectedTitle.Text = $profile.Name
    Update-SelectedHotkeyDisplay $profile
    Set-Validation ''
}

function Capture-UiToProfile($profile) {
    $key = $keyBox.Text.Trim().ToUpperInvariant()
    if ((Get-KeyCode $key) -eq 0) { throw '主键必须是一个字母或数字。' }
    $tag = if ($modifierBox.SelectedItem) { $modifierBox.SelectedItem.Tag.ToString() } else { 'CtrlAltShift' }
    $profile.Name = if ([string]::IsNullOrWhiteSpace($shortcutNameBox.Text)) { '未命名快捷键' } else { $shortcutNameBox.Text.Trim() }
    $profile.ModifierTag = $tag
    $profile.Key = $key.Substring(0,1)
    $profile.DesktopIcons = [bool]$desktopIconsToggle.IsChecked
    $profile.Taskbar = [bool]$taskbarToggle.IsChecked
    $profile.AutoHideTaskbar = [bool]$autoHideTaskbarToggle.IsChecked
    foreach ($app in $apps) { $profile.Apps[$app.Name] = [bool]$checks[$app.Name].IsChecked }
}

function Unregister-AllHotkeys {
    if ($script:hwndSource) {
        foreach ($id in @($script:registeredIds.Keys)) {
            [void][HotkeyApi]::UnregisterHotKey($script:hwndSource.Handle, [int]$id)
        }
    }
    $script:registeredIds.Clear()
    $script:registeredHotkeySpecs.Clear()
}

function Register-AllHotkeys {
    # Keep the registration tables in script scope.  Event handlers run in a
    # child scope, and an unqualified assignment there can otherwise leave the
    # hook looking at a stale table after a save.
    $oldSpecs = @($script:registeredHotkeySpecs.Values | ForEach-Object { $_ })
    $oldSpecsByProfile = @{}
    foreach ($oldSpec in $oldSpecs) { $oldSpecsByProfile[[string]$oldSpec.ProfileId] = $oldSpec }
    Unregister-AllHotkeys
    $errors = @()
    if (-not $script:hwndSource) { return $errors }
    $newIds = @{}
    $newSpecs = @{}
    $seenCombos = @{}
    $failedProfileIds = @{}
    for ($i = 0; $i -lt $profiles.Count; $i++) {
        $profile = $profiles[$i]
        $vk = Get-KeyCode $profile.Key
        $mods = Get-ModCode $profile.ModifierTag
        $id = $hotkeyIdBase + $i
        $combo = "$mods/$vk"
        if ($vk -eq 0) {
            $errors += [pscustomobject]@{ Display="$($profile.Name)：$(Get-ProfileHotkey $profile) — 主键无效"; Code=87 }
            $failedProfileIds[[string]$profile.Id] = $true
            continue
        }
        if ($seenCombos.ContainsKey($combo)) {
            $errors += [pscustomobject]@{ Display="$($profile.Name)：$(Get-ProfileHotkey $profile) — 与其他配置重复"; Code=1409 }
            $failedProfileIds[[string]$profile.Id] = $true
            continue
        }
        $seenCombos[$combo] = $true
        $registered = [HotkeyApi]::RegisterHotKey($script:hwndSource.Handle, $id, [uint32]$mods, [uint32]$vk)
        $errorCode = if ($registered) { 0 } else { [Runtime.InteropServices.Marshal]::GetLastWin32Error() }
        if (-not $registered) {
            $reason = switch ($errorCode) {
                1409 { '已被其他程序占用' }
                87 { '组合键无效' }
                default { "注册失败（错误码 $errorCode）" }
            }
            $errors += [pscustomobject]@{ Display="$($profile.Name)：$(Get-ProfileHotkey $profile) — $reason"; Code=$errorCode }
            $failedProfileIds[[string]$profile.Id] = $true
        } else {
            $newIds[$id] = $profile.Id
            $newSpecs[$id] = [pscustomobject]@{ Id=$id; ProfileId=$profile.Id; Modifiers=$mods; Key=$vk }
        }
    }
    if ($errors.Count -gt 0) {
        # Keep every successfully registered new shortcut.  Only restore the
        # previous registration for profiles whose new combination failed.
        # This prevents one occupied key from disabling all other profiles.
        $script:registeredIds.Clear(); $script:registeredHotkeySpecs.Clear()
        foreach ($id in $newIds.Keys) {
            $script:registeredIds[$id] = $newIds[$id]
            $script:registeredHotkeySpecs[$id] = $newSpecs[$id]
        }
        foreach ($profileId in @($failedProfileIds.Keys)) {
            if (-not $oldSpecsByProfile.ContainsKey([string]$profileId)) { continue }
            $spec = $oldSpecsByProfile[[string]$profileId]
            $restored = [HotkeyApi]::RegisterHotKey($script:hwndSource.Handle, [int]$spec.Id, [uint32]$spec.Modifiers, [uint32]$spec.Key)
            if ($restored) {
                $script:registeredIds[[int]$spec.Id] = $spec.ProfileId
                $script:registeredHotkeySpecs[[int]$spec.Id] = $spec
            }
        }
        return $errors
    }
    foreach ($id in $newIds.Keys) {
        $script:registeredIds[$id] = $newIds[$id]
        $script:registeredHotkeySpecs[$id] = $newSpecs[$id]
    }
    return $errors
}

function Set-DesktopIconsVisible([bool]$visible) {
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $currentlyVisible = $true
    try { $currentlyVisible = -not [bool](Get-ItemPropertyValue -Path $key -Name HideIcons -ErrorAction Stop) } catch { }
    if ($currentlyVisible -ne $visible) {
        try {
            # Windows PowerShell 5.1 does not support using an if statement
            # directly as a command argument (it tries to execute `if`).
            # Resolve the value first, then pass the integer to the cmdlet.
            if (-not (Test-Path -LiteralPath $key)) { New-Item -Path $key -Force -ErrorAction Stop | Out-Null }
            $hideIconsValue = 1
            if ($visible) { $hideIconsValue = 0 }
            New-ItemProperty -Path $key -Name HideIcons -PropertyType DWord -Value $hideIconsValue -Force -ErrorAction Stop | Out-Null
            [DesktopIconApi]::Toggle()
            $script:desktopIconsError = $null
        } catch {
            # A locked-down account may not be allowed to update Explorer's
            # preference key.  Do not abort launching the selected apps.
            $script:desktopIconsError = $_.Exception.Message
        }
    }
}

function Set-TaskbarVisible([bool]$visible) {
    $taskbar = [TaskbarApi]::FindWindow('Shell_TrayWnd', $null)
    if ($taskbar -ne [IntPtr]::Zero) {
        $showCommand = 0
        if ($visible) { $showCommand = 5 }
        [void][TaskbarApi]::ShowWindow($taskbar, $showCommand)
    }
}

function Set-TaskbarAutoHide([bool]$enabled) {
    # ABM_SETSTATE flips the same system state as Settings > Taskbar >
    # "automatically hide the taskbar": Explorer stows the bar and slides it
    # back in when the pointer touches the screen edge.  Only write when the
    # current state differs so toggling profiles never blinks the taskbar.
    try {
        if ([TaskbarAutoHideApi]::GetAutoHide() -ne $enabled) { [void][TaskbarAutoHideApi]::SetAutoHide($enabled) }
    } catch { }
}

function Start-ProfileApps($profile) {
    $selectedProcessNames = [System.Collections.ArrayList]::new()
    $startedProcessNames = [System.Collections.ArrayList]::new()
    $failures = [System.Collections.ArrayList]::new()
    foreach ($app in $apps) {
        if (-not [bool]$profile.Apps[$app.Name]) { continue }
        if ([string]::IsNullOrWhiteSpace($app.Path) -or -not (Test-Path -LiteralPath $app.Path)) {
            [void]$failures.Add("$($app.Name)：找不到程序文件")
            continue
        }
        $processName = [IO.Path]::GetFileNameWithoutExtension($app.Path)
        if ($selectedProcessNames -notcontains $processName) { [void]$selectedProcessNames.Add($processName) }
        $existing = @(Get-Process -Name $processName -ErrorAction SilentlyContinue)
        if ($existing.Count -gt 0) { continue }
        try {
            $started = Start-Process -FilePath $app.Path -WorkingDirectory (Split-Path -Parent $app.Path) -PassThru -ErrorAction Stop
            # A GUI process can take a moment to create its main window.  Give
            # it a short grace period, but catch executables that exit at once
            # so switching profiles never silently tears down the old mode.
            Start-Sleep -Milliseconds 800
            $running = @(Get-Process -Name $processName -ErrorAction SilentlyContinue)
            if ($running.Count -gt 0 -or -not $started.HasExited) {
                if ($startedProcessNames -notcontains $processName) { [void]$startedProcessNames.Add($processName) }
            } else {
                if ($app.Name -eq 'Clash Verge') {
                    [void]$failures.Add("Clash Verge：程序启动后立即退出（退出码 $($started.ExitCode)；请检查 64 位 WebView2 运行时和 Clash 本身）")
                } else {
                    [void]$failures.Add("$($app.Name)：程序启动后立即退出（退出码 $($started.ExitCode)）")
                }
            }
        } catch {
            [void]$failures.Add("$($app.Name)：$($_.Exception.Message)")
        }
    }
    [pscustomobject]@{
        SelectedProcessNames = @($selectedProcessNames)
        StartedProcessNames = @($startedProcessNames)
        Failures = @($failures)
    }
}

function Update-DesktopPresentation {
    $hideIcons = $false
    $hideTaskbar = $false
    $autoHideTaskbar = $false
    foreach ($state in @($script:activeProfiles.Values)) {
        if ([bool]$state.Profile.DesktopIcons) { $hideIcons = $true }
        if ([bool]$state.Profile.Taskbar) { $hideTaskbar = $true }
        if ([bool]$state.Profile.AutoHideTaskbar) { $autoHideTaskbar = $true }
    }
    $script:desktopIconsError = $null
    Set-DesktopIconsVisible (-not $hideIcons)
    Set-TaskbarVisible (-not $hideTaskbar)
    # Full hide wins over auto hide: a ShowWindow-hidden bar cannot slide in
    # on hover, so the system auto-hide flag is only meaningful while the bar
    # itself is visible.
    Set-TaskbarAutoHide ((-not $hideTaskbar) -and $autoHideTaskbar)
}

function Stop-ProfileApps([string]$profileId, $state) {
    # Do not close a process that is still selected by another active profile.
    $sharedNames = @{}
    foreach ($entry in $script:activeProfiles.GetEnumerator()) {
        if ([string]$entry.Key -eq $profileId) { continue }
        foreach ($name in @($entry.Value.ProcessNames)) { $sharedNames[$name] = $true }
    }
    foreach ($name in @($state.ProcessNames)) {
        if ($sharedNames.ContainsKey($name)) { continue }
        # Some desktop utilities (including Clash Verge when elevated) do not
        # accept a graceful stop from the unelevated launcher.  Force only the
        # processes explicitly owned by this profile.
        Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

function Exit-BeautyMode {
    # Remove each profile before stopping it so a process shared by multiple
    # profiles is stopped when the final owner is processed.
    foreach ($entry in @($script:activeProfiles.GetEnumerator())) {
        $profileId = [string]$entry.Key
        $state = $entry.Value
        [void]$script:activeProfiles.Remove($profileId)
        Stop-ProfileApps $profileId $state
    }
    $script:activeProfiles.Clear()
    $script:desktopIconsError = $null
    Set-DesktopIconsVisible $true
    Set-TaskbarVisible $true
    Set-TaskbarAutoHide $false
}

function Invoke-Profile($profile) {
    try {
        $profileId = [string]$profile.Id
        if ($script:activeProfiles.ContainsKey($profileId)) {
            $state = $script:activeProfiles[$profileId]
            Stop-ProfileApps $profileId $state
            [void]$script:activeProfiles.Remove($profileId)
            Update-DesktopPresentation
            Set-Validation "已关闭 [$($profile.Name)]" 'ok'
            Show-ModeBanner "$($profile.Name) 已关闭" 'off'
            return
        }

        # Profiles are independent: starting P must not close N (or any other
        # profile). Only a second press of the same hotkey closes its apps.
        $launchResult = Start-ProfileApps $profile
        if ($launchResult.Failures.Count -gt 0) {
            foreach ($name in @($launchResult.StartedProcessNames)) {
                Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            }
            $failureMessage = "未启用 [$($profile.Name)]：" + ($launchResult.Failures -join '；')
            Set-Validation $failureMessage 'error'
            Show-TrayStatus $failureMessage 'error'
            return
        }
        $script:activeProfiles[$profileId] = [pscustomobject]@{
            Profile = $profile
            ProcessNames = @($launchResult.SelectedProcessNames)
        }
        Update-DesktopPresentation
        if ($script:desktopIconsError) {
            Set-Validation ("已启用 [$($profile.Name)]（桌面图标设置未生效，但软件已启动）") 'warn'
        } else {
            Set-Validation "已启用 [$($profile.Name)]" 'ok'
        }
        Show-ModeBanner "$($profile.Name) 已开启" 'on'
    } catch { Set-Validation ('执行失败：' + $_.Exception.Message) 'error' }
}

function Save-CurrentProfile {
    if ($selectedIndex -lt 0 -or $selectedIndex -ge $profiles.Count) { throw '请先选择一个快捷键。' }
    $profile = $profiles[$selectedIndex]
    Capture-UiToProfile $profile
    $profile.Pending = $false
    $settings.LastSelectedId = $profile.Id
    Save-AllProfiles
    $errors = @(Register-AllHotkeys)
    Refresh-ShortcutList
    $selectedTitle.Text = $profile.Name
    Update-SelectedHotkeyDisplay $profile
    if ($errors.Count -gt 0) {
        Show-SaveFeedback ('配置已保存，但快捷键没有全部启用：' + (Format-RegistrationErrors $errors) + '。旧快捷键已保留。') 'warn' $true
    } else {
        # Make a successful save unmistakable even when the optional notification
        # setting was previously turned off: the user needs to know the new
        # shortcut has actually been registered and is ready to use.
        Show-SaveFeedback ('✓ 已保存并启用：' + (Get-ProfileHotkey $profile)) 'ok' $true
    }
}

function Set-StartWithWindows([bool]$enabled) {
    $runPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $valueName = 'OneClickBeautify'
    if ($enabled) {
        $exe = Join-Path $appRoot 'OneL.exe'
        if (-not (Test-Path -LiteralPath $exe)) { $exe = Join-Path $appRoot '一键桌面美化.exe' }
        if (Test-Path -LiteralPath $exe) { New-Item -Path $runPath -Force | Out-Null; Set-ItemProperty -Path $runPath -Name $valueName -Value ('"' + $exe + '"') }
    } else { Remove-ItemProperty -Path $runPath -Name $valueName -ErrorAction SilentlyContinue }
}

function Show-Settings {
    $settingsXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="设置" Width="520" Height="430" WindowStartupLocation="CenterOwner" ResizeMode="NoResize" Background="#FDF2F7" FontFamily="Segoe UI">
  <Window.Resources>
    <Style TargetType="Button">
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Padding" Value="16,8"/>
      <Setter Property="Margin" Value="0,0,8,0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="SnapsToDevicePixels" Value="True"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Border Name="bg" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="17"/>
              <Border Name="pressMask" Background="#28000000" CornerRadius="17" Opacity="0"/>
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="pressMask" Property="Opacity" Value="1"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="#C0FFFFFF"/>
      <Setter Property="BorderBrush" Value="#EFC7D9"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="SnapsToDevicePixels" Value="True"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="18" Padding="18,0">
              <ScrollViewer x:Name="PART_ContentHost" Focusable="False" HorizontalScrollBarVisibility="Hidden" VerticalScrollBarVisibility="Hidden" VerticalAlignment="Center"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>
  <Border Margin="18" Background="White" BorderBrush="#F3D9E5" BorderThickness="1" CornerRadius="8" Padding="24">
    <DockPanel>
      <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,22,0,0">
        <Button Name="CancelSettingsButton" Content="取消" Background="#C0FFFFFF" BorderBrush="#EFC7D9"/>
        <Button Name="SaveSettingsButton" Content="保存设置" Background="#C0EE6FA8" Foreground="White" BorderThickness="0" Margin="0"/>
      </StackPanel>
      <StackPanel>
        <TextBlock Text="设置" FontSize="23" FontWeight="SemiBold" Foreground="#3E2A33"/>
        <TextBlock Text="让快捷键中心更贴合你的工作习惯" Foreground="#8B7A85" FontSize="13" Margin="0,5,0,22"/>
        <CheckBox Name="StartWithWindowsToggle" Content="随 Windows 启动" FontSize="14" Margin="0,0,0,16"/>
        <TextBlock Text="登录系统后自动打开快捷键中心，快捷键才能随时待命。" Foreground="#9A8794" FontSize="12" TextWrapping="Wrap" Margin="24,-10,0,18"/>
        <CheckBox Name="StartMinimizedToggle" Content="启动时最小化窗口" FontSize="14" Margin="0,0,0,16"/>
        <TextBlock Text="减少桌面占用，需要编辑时可从任务栏恢复。" Foreground="#9A8794" FontSize="12" TextWrapping="Wrap" Margin="24,-10,0,18"/>
        <CheckBox Name="ShowSaveNotificationToggle" Content="保存后显示状态提示" FontSize="14" Margin="0,0,0,22"/>
        <TextBlock Text="配置文件位置" Foreground="#6E5A66" FontSize="12"/>
        <TextBox Name="ConfigPathText" IsReadOnly="True" Background="#C0FBF4F7" BorderBrush="#E7F3F6" Margin="0,6,0,0" Padding="18,8"/>
      </StackPanel>
    </DockPanel>
  </Border>
</Window>
'@
    $settingsReader = New-Object System.Xml.XmlNodeReader ([xml]$settingsXaml)
    $settingsWindow = [Windows.Markup.XamlReader]::Load($settingsReader)
    $startToggle = $settingsWindow.FindName('StartWithWindowsToggle')
    $minimizedToggle = $settingsWindow.FindName('StartMinimizedToggle')
    $notificationToggle = $settingsWindow.FindName('ShowSaveNotificationToggle')
    $configPathText = $settingsWindow.FindName('ConfigPathText')
    $saveSettingsButton = $settingsWindow.FindName('SaveSettingsButton')
    $cancelSettingsButton = $settingsWindow.FindName('CancelSettingsButton')
    foreach ($hoverButton in @($saveSettingsButton, $cancelSettingsButton)) { Attach-HoverScale $hoverButton }
    $startToggle.IsChecked = $settings.StartWithWindows
    $minimizedToggle.IsChecked = $settings.StartMinimized
    $notificationToggle.IsChecked = $settings.ShowSaveNotification
    $configPathText.Text = $configPath
    $settingsWindow.Owner = $window
    $saveSettingsButton.Add_Click({
        try {
            $settings.StartWithWindows = [bool]$startToggle.IsChecked
            $settings.StartMinimized = [bool]$minimizedToggle.IsChecked
            $settings.ShowSaveNotification = [bool]$notificationToggle.IsChecked
            Set-StartWithWindows $settings.StartWithWindows
            Save-AllProfiles
            $settingsWindow.DialogResult = $true
            $settingsWindow.Close()
            Set-Validation '设置已保存' 'ok'
        } catch { [System.Windows.MessageBox]::Show(('设置保存失败：' + $_.Exception.Message), '设置', 'OK', 'Error') | Out-Null }
    })
    $cancelSettingsButton.Add_Click({ $settingsWindow.Close() })
    [void]$settingsWindow.ShowDialog()
}

$shortcutList.Add_SelectionChanged({
    if ($script:suppressSelection) { return }
    if ($shortcutList.SelectedIndex -lt 0 -or $shortcutList.SelectedIndex -ge $profiles.Count) { return }
    $script:selectedIndex = $shortcutList.SelectedIndex
    Set-UiFromProfile $profiles[$selectedIndex]
})
$shortcutNameBox.Add_TextChanged({
    if ($selectedIndex -ge 0 -and $selectedIndex -lt $listRows.Count) {
        $displayName = if ([string]::IsNullOrWhiteSpace($shortcutNameBox.Text)) { '未命名快捷键' } else { $shortcutNameBox.Text.Trim() }
        $selectedTitle.Text = $displayName
        $listRows[$selectedIndex].NameText.Text = $displayName
    }
})
$modifierBox.Add_SelectionChanged({
    if ($selectedIndex -ge 0 -and $selectedIndex -lt $profiles.Count) {
        if ($profiles[$selectedIndex].Pending) { return }
        $tag = if ($modifierBox.SelectedItem) { $modifierBox.SelectedItem.Tag.ToString() } else { 'CtrlAltShift' }
        $preview = $profiles[$selectedIndex].PSObject.Copy(); $preview.ModifierTag = $tag; $preview.Key = $keyBox.Text.Trim().ToUpperInvariant()
        $selectedHotkey.Text = Get-ProfileHotkey $preview
        if ($selectedIndex -lt $listRows.Count) { $listRows[$selectedIndex].HotkeyText.Text = Get-ProfileHotkey $preview }
    }
})
$keyBox.AddHandler([System.Windows.UIElement]::PreviewKeyDownEvent, [System.Windows.Input.KeyEventHandler]{ param($sender,$e); if ($e.Key -notin @('Left','Right','Up','Down','Tab','Enter')) { $keyBox.Text = $e.Key.ToString().Replace('D',''); $e.Handled = $true } })
$keyBox.Add_TextChanged({
    if ($selectedIndex -ge 0 -and $selectedIndex -lt $profiles.Count) {
        if ($profiles[$selectedIndex].Pending) { return }
        $preview = $profiles[$selectedIndex].PSObject.Copy(); $preview.ModifierTag = if ($modifierBox.SelectedItem) { $modifierBox.SelectedItem.Tag.ToString() } else { 'CtrlAltShift' }; $preview.Key = $keyBox.Text.Trim().ToUpperInvariant()
        $selectedHotkey.Text = Get-ProfileHotkey $preview
        if ($selectedIndex -lt $listRows.Count) { $listRows[$selectedIndex].HotkeyText.Text = Get-ProfileHotkey $preview }
    }
})
$taskbarToggle.Add_Checked({ if ($autoHideTaskbarToggle.IsChecked) { $autoHideTaskbarToggle.IsChecked = $false } })
$autoHideTaskbarToggle.Add_Checked({ if ($taskbarToggle.IsChecked) { $taskbarToggle.IsChecked = $false } })
$saveButton.Add_Click({ try { Save-CurrentProfile } catch { Set-Validation ('保存失败：' + $_.Exception.Message) 'error' } })
$addShortcutButton.Add_Click({
    try {
        if ($selectedIndex -ge 0 -and $selectedIndex -lt $profiles.Count) { Capture-UiToProfile $profiles[$selectedIndex] }
        $newProfile = New-Profile "快捷键 $($profiles.Count + 1)" 'CtrlAlt' 'P'
        $newProfile.Pending = $true
        [void]$profiles.Add($newProfile)
        $selectedIndex = $profiles.Count - 1
        $settings.LastSelectedId = $newProfile.Id
        Save-AllProfiles
        $errors = @(Register-AllHotkeys)
        Refresh-ShortcutList
        $shortcutList.SelectedIndex = $selectedIndex
        if ($errors.Count -gt 0) { Set-Validation '已新增。默认组合键可能与其他软件冲突，请修改后保存。' 'warn' } else { Set-Validation '已新增快捷键，请设置启动内容后保存。' 'ok' }
    } catch { Set-Validation ('新增失败：' + $_.Exception.Message) 'error' }
})
$deleteShortcutButton.Add_Click({
    if ($profiles.Count -le 1) { Set-Validation '至少保留一组快捷键。' 'warn'; return }
    $deleteName = $profiles[$selectedIndex].Name
    $result = [System.Windows.MessageBox]::Show(('确定删除 ' + $deleteName + ' 吗？'), '删除快捷键', 'YesNo', 'Warning')
    if ($result -ne 'Yes') { return }
    try {
        [void]$profiles.RemoveAt($selectedIndex)
        $selectedIndex = [Math]::Max(0, $selectedIndex - 1)
        Save-AllProfiles
        $errors = @(Register-AllHotkeys)
        Refresh-ShortcutList
        Set-Validation '快捷键已删除' 'ok'
    } catch { Set-Validation ('删除失败：' + $_.Exception.Message) 'error' }
})
$settingsButton.Add_Click({ try { Show-Settings } catch { Set-Validation ('打开设置失败：' + $_.Exception.Message) 'error' } })

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class HotkeyApi {
  [DllImport("user32.dll", SetLastError=true)] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint modifiers, uint key);
  [DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
}
'@
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class TaskbarApi {
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string title);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd, int command);
}
'@
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class DesktopIconApi {
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string title);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
  public static IntPtr View() {
    IntPtr p=FindWindow("Progman", null); IntPtr v=FindWindowEx(p, IntPtr.Zero, "SHELLDLL_DefView", null); if(v!=IntPtr.Zero)return v;
    IntPtr w=IntPtr.Zero; while((w=FindWindowEx(IntPtr.Zero,w,"WorkerW",null))!=IntPtr.Zero){v=FindWindowEx(w,IntPtr.Zero,"SHELLDLL_DefView",null);if(v!=IntPtr.Zero)return v;} return IntPtr.Zero;
  }
  public static void Toggle(){IntPtr v=View(); if(v!=IntPtr.Zero) SendMessage(v,0x111,(IntPtr)0x7402,IntPtr.Zero);}
}
'@

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class TaskbarAutoHideApi {
  [StructLayout(LayoutKind.Sequential)] private struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] private struct APPBARDATA {
    public int cbSize; public IntPtr hWnd; public int uCallbackMessage; public int uEdge; public RECT rc; public int lParam;
  }
  [DllImport("shell32.dll")] private static extern uint SHAppBarMessage(int dwMessage, ref APPBARDATA pData);
  private const int ABM_GETSTATE = 4, ABM_SETSTATE = 10, ABS_AUTOHIDE = 1, ABS_ALWAYSONTOP = 2;
  public static int GetState() {
    APPBARDATA d = new APPBARDATA();
    d.cbSize = Marshal.SizeOf(typeof(APPBARDATA));
    return (int)SHAppBarMessage(ABM_GETSTATE, ref d);
  }
  public static bool GetAutoHide() { return (GetState() & ABS_AUTOHIDE) == ABS_AUTOHIDE; }
  public static bool SetAutoHide(bool enabled) {
    APPBARDATA d = new APPBARDATA();
    d.cbSize = Marshal.SizeOf(typeof(APPBARDATA));
    d.lParam = enabled ? ABS_AUTOHIDE : ABS_ALWAYSONTOP;
    return SHAppBarMessage(ABM_SETSTATE, ref d) != 0;
  }
}
'@
$window.Add_SourceInitialized({
    $helper = New-Object Windows.Interop.WindowInteropHelper $window
    $script:hwndSource = [Windows.Interop.HwndSource]::FromHwnd($helper.Handle)
    $hwndSource.AddHook({ param($hwnd,$msg,$wParam,$lParam,[ref]$handled)
        if ($msg -eq 0x0312) {
            $profileId = $script:registeredIds[$wParam.ToInt32()]
            if ($profileId) {
                $profile = $script:profiles | Where-Object { $_.Id -eq $profileId } | Select-Object -First 1
                if ($profile) { Invoke-Profile $profile }
                $handled.Value = $true
            }
        }
        return [IntPtr]::Zero
    })
    $errors = @(Register-AllHotkeys)
    if ($errors.Count -gt 0) { Set-Validation ('部分快捷键未启用：' + (Format-RegistrationErrors $errors)) 'warn' }
})
$window.Add_Closing([System.ComponentModel.CancelEventHandler]{
    param($sender, $eventArgs)
    if (-not [bool]$script:allowClose) {
        # Closing the window from the taskbar or its X button keeps the
        # hotkey listener alive and moves the app to the notification area.
        $eventArgs.Cancel = $true
        if ($script:trayIcon) { $script:trayIcon.Visible = $true }
        # Keep the modal ShowDialog alive: hiding a window during Closing can
        # end ShowDialog.  A minimized window without a taskbar button, however,
        # is drawn by the shell as a small floating strip in the bottom-left
        # corner of the screen.  Park the window off-screen instead (still in
        # Normal state) and remember its position for the tray "打开" restore.
        if ($sender.WindowState -ne 'Normal') { $sender.WindowState = 'Normal' }
        if ($sender.Left -gt -30000) {
            $script:savedWindowBounds = [pscustomobject]@{ Left = $sender.Left; Top = $sender.Top }
        }
        $sender.ShowInTaskbar = $false
        $sender.Left = -32000
        $sender.Top = -32000
    }
})
$window.Add_Closed({
    if ($script:activeProfiles.Count -gt 0) { try { Exit-BeautyMode } catch { } }
    Unregister-AllHotkeys
    if ($script:trayIcon) {
        $script:trayIcon.Visible = $false
        $script:trayIcon.Dispose()
        $script:trayIcon = $null
    }
})

Refresh-ShortcutList
$initialIndex = 0
if ($settings.LastSelectedId) {
    for ($i=0; $i -lt $profiles.Count; $i++) { if ($profiles[$i].Id -eq $settings.LastSelectedId) { $initialIndex = $i; break } }
}
$selectedIndex = $initialIndex
$shortcutList.SelectedIndex = $initialIndex
$window.Add_ContentRendered({ if ($settings.StartMinimized) { $window.WindowState = 'Minimized' } })
Initialize-TrayIcon
$window.ShowDialog() | Out-Null

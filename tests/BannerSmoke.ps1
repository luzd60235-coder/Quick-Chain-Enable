$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $projectRoot 'AppLauncher.ps1'
$source = [IO.File]::ReadAllText($sourcePath)
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ('Script parser error: ' + ($errors -join '; ')) }

$mainXaml = [regex]::Match($source, '(?s)\$xaml = @''\r?\n(.*?)\r?\n''@')
if (-not $mainXaml.Success) { throw 'Main XAML not found.' }
$reader = New-Object Xml.XmlNodeReader ([xml]$mainXaml.Groups[1].Value)
$main = [Windows.Markup.XamlReader]::Load($reader)
$topButtons = @($main.FindName('AddShortcutButton'), $main.FindName('SkinButton'), $main.FindName('SettingsButton'))
if ($topButtons -contains $null) { throw 'Top button missing.' }
if ($source.IndexOf('Name="AddShortcutButton"') -gt $source.IndexOf('Name="SkinButton"') -or
    $source.IndexOf('Name="SkinButton"') -gt $source.IndexOf('Name="SettingsButton"')) { throw 'Top button order is wrong.' }
$main.Close()

$functionNames = @('ConvertTo-BannerColor', 'Get-BannerPalette', 'New-CatSoundFile', 'Play-CatVoice',
    'New-RagdollCatVisual', 'Start-CatBannerAnimation', 'Show-ModeBanner', 'Show-SkinPicker',
    'Attach-HoverScale', 'Start-HoverScale', 'Save-AllProfiles', 'Set-Validation')
$functions = $ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)
foreach ($name in $functionNames) {
    $definition = $functions | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    if (-not $definition) { throw "Function missing: $name" }
    . ([scriptblock]::Create($definition.Extent.Text))
}

$script:bannerWindow = $null
$script:catSoundPlayer = $null
$settings = @{ BannerSkin = 'PinkCyan' }
$bannerSkinIds = @('PinkCyan', 'Ocean', 'Sunset', 'Forest', 'Violet', 'RagdollCat')
$appRoot = Join-Path $projectRoot ('build\smoke-' + [guid]::NewGuid().ToString('N'))
$dataRoot = Join-Path $appRoot 'data'
[IO.Directory]::CreateDirectory($dataRoot) | Out-Null
$diagnostic = Join-Path $appRoot 'launcher.log'
if (Test-Path -LiteralPath $diagnostic) { throw 'Historical smoke log exists.' }

foreach ($skin in $bannerSkinIds) {
    foreach ($kind in @('on', 'off')) {
        Show-ModeBanner "Test $skin $kind" $kind $skin
        if (-not $script:bannerWindow -or -not $script:bannerWindow.IsVisible) { throw "Banner did not appear: $skin $kind" }
        $script:bannerWindow.Close()
        if (Test-Path -LiteralPath $diagnostic) { throw "Banner error: $skin $kind $([IO.File]::ReadAllText($diagnostic))" }
    }
}

foreach ($voice in @('happy', 'low')) {
    $sound = Join-Path $dataRoot "OneL-cat-$voice.wav"
    if (-not (Test-Path -LiteralPath $sound) -or (Get-Item -LiteralPath $sound).Length -lt 1000) { throw "Sound missing: $voice" }
}
Write-Output 'PASS: top button order, five color themes, animated cat banners, and cat sounds.'

# Render the vector cat to a PNG so its face and silhouette can be inspected.
$cat = New-RagdollCatVisual
$cat.Measure([Windows.Size]::new(78,54))
$cat.Arrange([Windows.Rect]::new(0,0,78,54))
$cat.UpdateLayout()
$bitmap = New-Object Windows.Media.Imaging.RenderTargetBitmap(312,216,384,384,[Windows.Media.PixelFormats]::Pbgra32)
$bitmap.Render($cat)
$encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
$image = [IO.File]::Create((Join-Path $appRoot 'ragdoll-preview.png'))
try { $encoder.Save($image) } finally { $image.Dispose() }

# Exercise the real modal picker and real config writer without touching the
# user's profiles. Dispatcher callbacks click every skin, preview off, and save.
$reader = New-Object Xml.XmlNodeReader ([xml]$mainXaml.Groups[1].Value)
$window = [Windows.Markup.XamlReader]::Load($reader)
$window.ShowActivated = $false
$window.Left = -32000; $window.Top = -32000; $window.WindowStartupLocation = 'Manual'
$window.Show()
$profiles = [Collections.ArrayList]::new()
$apps = @()
$configPath = Join-Path $dataRoot 'shortcuts.json'
$validationText = $window.FindName('ValidationText')
$script:pickerStep = 0
$script:pickerFailure = $null
$pickerTimer = New-Object Windows.Threading.DispatcherTimer
$pickerTimer.Interval = [TimeSpan]::FromMilliseconds(140)
$pickerTimer.Add_Tick({
    param($sender,$eventArgs)
    try {
        $picker = @([Windows.Application]::Current.Windows | Where-Object { $_.Title -eq ([char]0x6A2A + [string][char]0x5E45 + [char]0x76AE + [char]0x80A4 + ' ' + [char]0x00B7 + ' OneL') }) | Select-Object -First 1
        if (-not $picker) { $picker = @($window.OwnedWindows | Where-Object { $_.FindName('SkinCards') }) | Select-Object -First 1 }
        if (-not $picker) { throw 'Modal skin picker missing.' }
        if ($script:pickerStep -lt 6) {
            $card = $picker.FindName('SkinCards').Children[$script:pickerStep]
            $card.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
            if (-not $script:bannerWindow) { throw 'Skin card preview missing.' }
            $picker.FindName('PreviewSkinOffButton').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
            $script:pickerStep++
        } else {
            $sender.Stop()
            $picker.FindName('SaveSkinButton').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        }
    } catch {
        $script:pickerFailure = $_.Exception.Message
        $sender.Stop()
        foreach ($owned in @($window.OwnedWindows)) { $owned.Close() }
    }
})
$pickerTimer.Start()
Show-SkinPicker
$pickerTimer.Stop()
if ($script:pickerFailure) { throw $script:pickerFailure }
if ($settings.BannerSkin -ne 'RagdollCat') { throw 'Skin selection did not update.' }
$saved = [IO.File]::ReadAllText($configPath) | ConvertFrom-Json
if ($saved.Settings.BannerSkin -ne 'RagdollCat') { throw 'Skin selection was not persisted.' }
if (Test-Path -LiteralPath $diagnostic) { throw ('Picker preview error: ' + [IO.File]::ReadAllText($diagnostic)) }
if ($script:bannerWindow) { $script:bannerWindow.Close() }
$window.Close()
Write-Output 'PASS: real skin picker, all card click events, both previews, and persisted selection.'
Write-Output ('Preview image: ' + (Join-Path $appRoot 'ragdoll-preview.png'))

# Friendly window for the optimizer. Every action runs "optimizer.bat <step>" in the
# background and shows its output, so the batch file stays the single implementation.
# Keep this file ASCII-only: Windows PowerShell 5.1 reads BOM-less scripts as ANSI.

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$base     = $PSScriptRoot
$batFile  = Join-Path $base 'optimizer.bat'
$appsFile = Join-Path $base 'apps.txt'
$logFile  = Join-Path $base 'optimizer.log'

# === Needs Administrator rights: relaunch elevated (and hidden) if we don't have them ===
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    } catch {
        [System.Windows.MessageBox]::Show('The optimizer needs Administrator permission to change system settings.', 'Windows Optimizer', 'OK', 'Warning') | Out-Null
    }
    exit
}

# Hide the console window when started with "Run with PowerShell"
Add-Type -Namespace Native -Name Console -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@
[Native.Console]::ShowWindow([Native.Console]::GetConsoleWindow(), 0) | Out-Null

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Windows Optimizer" Width="560" SizeToContent="Height" ResizeMode="CanMinimize"
        WindowStartupLocation="CenterScreen" Background="#F3F4F6"
        FontFamily="Segoe UI" FontSize="13" Foreground="#111827">
  <Window.Resources>
    <Style x:Key="Card" TargetType="Border">
      <Setter Property="Background" Value="White"/>
      <Setter Property="BorderBrush" Value="#E5E7EB"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="8"/>
      <Setter Property="Padding" Value="14,10"/>
      <Setter Property="Margin" Value="0,0,0,8"/>
    </Style>
    <Style x:Key="Title" TargetType="TextBlock">
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="FontSize" Value="14"/>
    </Style>
    <Style x:Key="Hint" TargetType="TextBlock">
      <Setter Property="Foreground" Value="#6B7280"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
      <Setter Property="Margin" Value="0,2,0,0"/>
    </Style>
    <Style x:Key="Option" TargetType="CheckBox">
      <Setter Property="VerticalContentAlignment" Value="Top"/>
      <Setter Property="Cursor" Value="Hand"/>
    </Style>
    <Style x:Key="PrimaryButton" TargetType="Button">
      <Setter Property="Background" Value="#2563EB"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontSize" Value="16"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Padding" Value="0,12"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bg" Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bg" Property="Background" Value="#1D4ED8"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="Bg" Property="Background" Value="#93C5FD"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="SecondaryButton" TargetType="Button">
      <Setter Property="Background" Value="White"/>
      <Setter Property="Foreground" Value="#374151"/>
      <Setter Property="Padding" Value="0,9"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bg" Background="{TemplateBinding Background}" BorderBrush="#D1D5DB" BorderThickness="1"
                    CornerRadius="8" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bg" Property="Background" Value="#F9FAFB"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Foreground" Value="#9CA3AF"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <ScrollViewer VerticalScrollBarVisibility="Auto">
  <StackPanel Margin="20,18,20,16">
    <TextBlock Text="Windows Optimizer" FontSize="24" FontWeight="SemiBold"/>
    <TextBlock Text="Make your PC feel faster. Everything here can be undone." Style="{StaticResource Hint}" Margin="0,2,0,14"/>

    <Border Style="{StaticResource Card}">
      <StackPanel>
        <Grid>
          <TextBlock Text="Memory in use" Style="{StaticResource Title}"/>
          <TextBlock x:Name="RamText" HorizontalAlignment="Right" Foreground="#6B7280" VerticalAlignment="Center"/>
        </Grid>
        <ProgressBar x:Name="RamBar" Height="10" Margin="0,8,0,2" Maximum="100"
                     Foreground="#2563EB" Background="#E5E7EB" BorderThickness="0"/>
      </StackPanel>
    </Border>

    <TextBlock Text="Choose what to do" Style="{StaticResource Title}" Margin="2,8,0,8"/>

    <Border Style="{StaticResource Card}">
      <CheckBox x:Name="ChkClean" Style="{StaticResource Option}" IsChecked="True">
        <StackPanel Margin="6,-2,0,0">
          <TextBlock Text="Clean up junk and close background apps" Style="{StaticResource Title}"/>
          <TextBlock Text="Deletes temporary files and closes apps like OneDrive and Teams that run in the background." Style="{StaticResource Hint}"/>
        </StackPanel>
      </CheckBox>
    </Border>
    <Border Style="{StaticResource Card}">
      <CheckBox x:Name="ChkStartup" Style="{StaticResource Option}" IsChecked="True">
        <StackPanel Margin="6,-2,0,0">
          <TextBlock Text="Make Windows start faster" Style="{StaticResource Title}"/>
          <TextBlock Text="Stops those background apps from opening every time you turn on your PC." Style="{StaticResource Hint}"/>
        </StackPanel>
      </CheckBox>
    </Border>
    <Border Style="{StaticResource Card}">
      <CheckBox x:Name="ChkPower" Style="{StaticResource Option}" IsChecked="True">
        <StackPanel Margin="6,-2,0,0">
          <TextBlock Text="Turn on maximum performance" Style="{StaticResource Title}"/>
          <TextBlock Text="Switches Windows to its fastest power mode. On a laptop, the battery may drain faster." Style="{StaticResource Hint}"/>
        </StackPanel>
      </CheckBox>
    </Border>
    <Border Style="{StaticResource Card}">
      <CheckBox x:Name="ChkUpdates" Style="{StaticResource Option}">
        <StackPanel Margin="6,-2,0,0">
          <TextBlock Text="Pause Windows updates for 5 weeks" Style="{StaticResource Title}"/>
          <TextBlock Text="No surprise updates or restarts while you play. Updates come back on by themselves." Style="{StaticResource Hint}"/>
        </StackPanel>
      </CheckBox>
    </Border>
    <Border Style="{StaticResource Card}">
      <CheckBox x:Name="ChkRam" Style="{StaticResource Option}">
        <StackPanel Margin="6,-2,0,0">
          <TextBlock Text="Free up memory now" Style="{StaticResource Title}"/>
          <TextBlock Text="Best just before starting a game. Windows slowly fills this memory again on its own." Style="{StaticResource Hint}"/>
        </StackPanel>
      </CheckBox>
    </Border>

    <Button x:Name="RunBtn" Content="Optimize my PC" Style="{StaticResource PrimaryButton}" Margin="0,6,0,8"/>
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition/>
        <ColumnDefinition Width="8"/>
        <ColumnDefinition/>
      </Grid.ColumnDefinitions>
      <Button x:Name="UndoBtn" Grid.Column="0" Content="Undo all changes" Style="{StaticResource SecondaryButton}"/>
      <Button x:Name="AppsBtn" Grid.Column="2" Content="Choose which apps to close" Style="{StaticResource SecondaryButton}"/>
    </Grid>

    <Border Style="{StaticResource Card}" Margin="0,12,0,6">
      <StackPanel>
        <TextBlock x:Name="StatusText" Text="Ready. Tick what you want, then press Optimize my PC." Style="{StaticResource Title}" TextWrapping="Wrap"/>
        <ProgressBar x:Name="Busy" Height="4" Margin="0,8,0,0" IsIndeterminate="True" Visibility="Collapsed"
                     Foreground="#2563EB" Background="#E5E7EB" BorderThickness="0"/>
        <TextBox x:Name="Output" Height="120" Margin="0,8,0,0" IsReadOnly="True" TextWrapping="Wrap"
                 VerticalScrollBarVisibility="Auto" BorderThickness="0" Background="Transparent" Foreground="#4B5563"/>
      </StackPanel>
    </Border>

    <TextBlock HorizontalAlignment="Right" Foreground="#6B7280">
      <Hyperlink x:Name="LogLink">See the full log</Hyperlink>
    </TextBlock>
  </StackPanel>
  </ScrollViewer>
</Window>
'@

$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
# Small laptop screens: never grow taller than the screen, scroll instead
$window.MaxHeight = [System.Windows.SystemParameters]::WorkArea.Height
$iconFile = Join-Path $base 'optimizer.ico'
if (Test-Path $iconFile) {
    $window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create([Uri]$iconFile)
}
$ui = @{}
foreach ($name in 'RamText','RamBar','ChkClean','ChkStartup','ChkPower','ChkUpdates','ChkRam',
                  'RunBtn','UndoBtn','AppsBtn','StatusText','Busy','Output','LogLink') {
    $ui[$name] = $window.FindName($name)
}

# Checkbox -> optimizer.bat step, in the order they run
$steps = @(
    @{ Box = 'ChkClean';   Arg = 'quick';   Label = 'Cleaning up junk and closing background apps' }
    @{ Box = 'ChkStartup'; Arg = 'startup'; Label = 'Stopping background apps from starting with Windows' }
    @{ Box = 'ChkPower';   Arg = 'power';   Label = 'Turning on maximum performance' }
    @{ Box = 'ChkUpdates'; Arg = 'pause';   Label = 'Pausing Windows updates' }
    @{ Box = 'ChkRam';     Arg = 'ram';     Label = 'Freeing up memory' }
)

function Get-UsedRam {
    $os = Get-CimInstance Win32_OperatingSystem
    [pscustomobject]@{
        UsedGB  = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB
        TotalGB = $os.TotalVisibleMemorySize / 1MB
    }
}

function Update-Ram {
    $ram = Get-UsedRam
    $ui.RamBar.Value = 100 * $ram.UsedGB / $ram.TotalGB
    $ui.RamText.Text = '{0:N1} GB of {1:N1} GB' -f $ram.UsedGB, $ram.TotalGB
}

function Add-Output([string]$text) {
    $ui.Output.AppendText($text + "`r`n")
    $ui.Output.ScrollToEnd()
}

function Set-Busy([bool]$busy) {
    foreach ($name in 'RunBtn','UndoBtn','AppsBtn','ChkClean','ChkStartup','ChkPower','ChkUpdates','ChkRam') {
        $ui[$name].IsEnabled = -not $busy
    }
    $ui.Busy.Visibility = if ($busy) { 'Visible' } else { 'Collapsed' }
}

# === Running steps: one optimizer.bat process at a time, output read without blocking the window ===
$script:queue    = New-Object System.Collections.Queue
$script:proc     = $null
$script:readTask = $null
$script:doneText = ''
$script:ramStart = $null

function Start-Run($stepList, [string]$doneText) {
    $script:queue.Clear()
    foreach ($s in $stepList) { $script:queue.Enqueue($s) }
    $script:doneText = $doneText
    $script:ramStart = (Get-UsedRam).UsedGB
    $ui.Output.Clear()
    Set-Busy $true
    Start-NextStep
    $pollTimer.Start()
}

function Start-NextStep {
    if ($script:queue.Count -eq 0) { Complete-Run; return }
    $step = $script:queue.Dequeue()
    $ui.StatusText.Text = $step.Label + '...'
    Add-Output ($step.Label)

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $env:ComSpec
    $psi.Arguments = "/c `"`"$batFile`" $($step.Arg)`""
    $psi.WorkingDirectory = $base
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $script:proc = [System.Diagnostics.Process]::Start($psi)
    $script:readTask = $script:proc.StandardOutput.ReadLineAsync()
}

function Complete-Run {
    $pollTimer.Stop()
    $script:proc = $null
    Set-Busy $false
    Update-Ram
    $freed = $script:ramStart - (Get-UsedRam).UsedGB
    $text = $script:doneText
    if ($freed -ge 0.1) { $text += ' {0:N1} GB of memory freed.' -f $freed }
    $ui.StatusText.Text = $text
}

$pollTimer = New-Object System.Windows.Threading.DispatcherTimer
$pollTimer.Interval = [TimeSpan]::FromMilliseconds(150)
$pollTimer.Add_Tick({
    if (-not $script:proc) { return }
    while ($script:readTask.IsCompleted) {
        $line = $script:readTask.Result
        if ($null -eq $line) {
            # End of this step's output
            $script:proc.WaitForExit()
            $script:proc.Dispose()
            Start-NextStep
            return
        }
        $line = $line.Trim()
        if ($line.StartsWith('[*] ')) { Add-Output ('    ' + [char]0x2022 + ' ' + $line.Substring(4)) }
        elseif ($line) { Add-Output ('    ' + $line) }
        $script:readTask = $script:proc.StandardOutput.ReadLineAsync()
    }
})

# === Buttons ===
$ui.RunBtn.Add_Click({
    $chosen = @($steps | Where-Object { $ui[$_.Box].IsChecked })
    if ($chosen.Count -eq 0) {
        $ui.StatusText.Text = 'Tick at least one option first.'
        return
    }
    Start-Run $chosen 'All done! Your PC is optimized.'
})

$ui.UndoBtn.Add_Click({
    $answer = [System.Windows.MessageBox]::Show(
        "This puts back your original power plan, lets your apps start with Windows again, and turns Windows updates back on.`r`n`r`nContinue?",
        'Undo all changes', 'YesNo', 'Question')
    if ($answer -ne 'Yes') { return }
    Start-Run @(@{ Arg = 'revert'; Label = 'Undoing all changes' }) 'Everything is back to how it was.'
})

$ui.AppsBtn.Add_Click({
    Start-Process notepad.exe -ArgumentList "`"$appsFile`""
    $ui.StatusText.Text = 'Edit the list in Notepad, save it, and it will be used the next time you optimize.'
})

$ui.LogLink.Add_Click({
    if (Test-Path $logFile) { Start-Process notepad.exe -ArgumentList "`"$logFile`"" }
    else { $ui.StatusText.Text = 'Nothing has been logged yet.' }
})

# === Live memory meter ===
$ramTimer = New-Object System.Windows.Threading.DispatcherTimer
$ramTimer.Interval = [TimeSpan]::FromSeconds(3)
$ramTimer.Add_Tick({ Update-Ram })
$ramTimer.Start()
Update-Ram

$window.ShowDialog() | Out-Null

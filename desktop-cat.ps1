param([switch]$ValidateOnly,[switch]$SelfTest)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$root=$PSScriptRoot
$atlas=New-Object Windows.Media.Imaging.BitmapImage
$atlas.BeginInit()
$atlas.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$atlas.UriSource=[Uri](Join-Path $root 'cat-atlas.png')
$atlas.EndInit()
$atlas.Freeze()
if($atlas.PixelWidth -ne 1536 -or $atlas.PixelHeight -ne 2288){throw 'Invalid cat atlas dimensions'}
$frames=@{}
$counts=@(6,8,8,4,5,8,6,6,6,8,8)
for($r=0;$r -lt 11;$r++){for($c=0;$c -lt $counts[$r];$c++){
 $rect=New-Object Windows.Int32Rect ($c*192),($r*208),192,208
 $frame=New-Object Windows.Media.Imaging.CroppedBitmap $atlas,$rect
 $frame.Freeze();$frames["$r,$c"]=$frame
}}
# Every animation uses complete, unmodified atlas cells in their original order.
$player=New-Object System.Media.SoundPlayer (Join-Path $root 'meow.wav')
$player.Load()
if($ValidateOnly){Write-Output "Validated $($frames.Count) frames and meow.wav";exit}
[xml]$xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="Jade cat" Width="192" Height="208" WindowStyle="None" AllowsTransparency="True" Background="Transparent" Topmost="True" ShowActivated="False" ShowInTaskbar="False" ResizeMode="NoResize">
 <Grid Background="Transparent"><Image Name="Cat" Stretch="Fill"/><Canvas Name="Effects" IsHitTestVisible="False"/></Grid>
</Window>
'@
$window=[Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$cat=$window.FindName('Cat');$effects=$window.FindName('Effects')
[Windows.Media.RenderOptions]::SetBitmapScalingMode($cat,[Windows.Media.BitmapScalingMode]::HighQuality)
$window.Left=[Math]::Max(0,[Windows.SystemParameters]::WorkArea.Right-330)
$window.Top=[Math]::Max(0,[Windows.SystemParameters]::WorkArea.Bottom-350)
$cat.Source=$frames['0,0']
$script:row=0;$script:column=0;$script:nextFrame=[DateTime]::Now
$script:muted=$false;$script:press=$null;$script:moved=$false;$script:lastPet=[DateTime]::MinValue
$durations=@(@(80,70,100,70,80,100),@(120,120,120,120,120,120,120,220),@(120,120,120,120,120,120,120,220),@(180,220,220,280),@(140,140,140,140,280),@(180,180,180,180,180,180,180,300),@(200,200,200,200,200,300),@(180,180,180,180,180,300),@(200,200,200,200,200,300))
$durations[7]=@(400,450,550,550,450,400)
$durations[5]=@(220,260,300,450,450,300,260,300)
$durations[8]=@(280,300,350,350,300,320)
$idleActions=@(
 @{Label='眨眼 / Blink';Row=0;Weight=50},
 @{Label='抬爪 / Wave';Row=3;Weight=14},
 @{Label='歪头 / Curious';Row=6;Weight=11},
 @{Label='观察 / Look around';Row=8;Weight=9},
 @{Label='思考 / Think';Row=7;Weight=8},
 @{Label='低头 / Shy';Row=5;Weight=4},
 @{Label='跳跃 / Jump';Row=4;Weight=4}
)
$script:actionActive=$false
$script:nextIdle=[DateTime]::Now.AddSeconds((Get-Random -Minimum 7 -Maximum 11))
function Play-Action([int]$Row,[int]$Milliseconds,[int]$Loops=1){
 $script:row=$Row;$script:column=0;$script:actionActive=$Milliseconds -gt 0
 $script:loopsRemaining=$Loops
 $script:nextFrame=[DateTime]::Now.AddMilliseconds($durations[$Row][0])
 $script:nextIdle=[DateTime]::Now.AddSeconds((Get-Random -Minimum 7 -Maximum 11))
 $cat.Source=$frames["$Row,0"]
}
function Select-IdleRow([int]$Roll=(Get-Random -Minimum 0 -Maximum 100)){
 foreach($action in $idleActions){if($Roll -lt $action.Weight){return $action.Row};$Roll-=$action.Weight}
 throw 'Invalid idle action roll'
}
function Play-CatAnimation([int]$Row){
 $script:lastLoops=if($Row -eq 4){Get-Random -Minimum 2 -Maximum 4}else{1}
 Play-Action $Row (($durations[$Row] | Measure-Object -Sum).Sum*$script:lastLoops) $script:lastLoops
}
function Set-CatSize([double]$Width){
 $width=[Math]::Max(96,[Math]::Min(384,$Width))
 $height=$width*208/192
 $window.Left+=($window.Width-$width)/2;$window.Top+=$window.Height-$height
 $window.Width=$width;$window.Height=$height
 $effects.Children.Clear()
}
function Move-Cat([double]$Dx,[double]$Dy){
 $script:moved=$true
 $runRow=if($Dx -lt -0.5){2}elseif($Dx -gt 0.5){1}elseif($script:row -in @(1,2)){$script:row}else{1}
 if($script:row -ne $runRow){Play-Action $runRow 300}
 $window.Left+=$Dx;$window.Top+=$Dy
}
function End-Drag {
 $wasDragging=$script:moved
 $script:press=$null;$script:moved=$false
 if($wasDragging){Play-Action 0 0}
}
function Pet-Cat {
 if(([DateTime]::Now-$script:lastPet).TotalMilliseconds -lt 900){return}
 $script:lastPet=[DateTime]::Now
 Play-Action 3 1000
 if(!$script:muted){$player.Play()}
 $effects.Children.Clear()
 for($i=0;$i -lt 3;$i++){
  $heart=New-Object Windows.Controls.TextBlock
  $scale=$window.Width/288
  $heart.Text=[char]0x2665;$heart.FontSize=22*$scale;$heart.Foreground=[Windows.Media.Brushes]::HotPink
  [Windows.Controls.Canvas]::SetLeft($heart,((105+$i*25)*$scale));[Windows.Controls.Canvas]::SetTop($heart,((28-$i*5)*$scale))
  [void]$effects.Children.Add($heart)
  $fade=New-Object Windows.Media.Animation.DoubleAnimation 1,0,([Windows.Duration][TimeSpan]::FromSeconds(1.2))
  $heart.BeginAnimation([Windows.UIElement]::OpacityProperty,$fade)
 }
}
$menu=New-Object Windows.Controls.ContextMenu
foreach($label in @('摸头 / Pet / Meow','Sound on / off','Close')){
 $item=New-Object Windows.Controls.MenuItem;$item.Header=$label
 $item.Add_Click({switch($this.Header){'摸头 / Pet / Meow'{Pet-Cat};'Sound on / off'{$script:muted=!$script:muted};'Close'{$window.Close()}}})
 [void]$menu.Items.Add($item)
}
$actionMenu=New-Object Windows.Controls.MenuItem;$actionMenu.Header='动作 / Actions'
foreach($action in $idleActions){
 $item=New-Object Windows.Controls.MenuItem;$item.Header=$action.Label;$item.Tag=$action.Row
 $item.Add_Click({Play-CatAnimation ([int]$this.Tag);$_.Handled=$true})
 [void]$actionMenu.Items.Add($item)
}
$menu.Items.Insert(1,$actionMenu)
$window.ContextMenu=$menu
$window.ToolTip='Click head: meow | Drag: run | Mouse wheel: resize | Right click: menu | Esc: close'
$window.Add_MouseWheel({if(!$script:press){Set-CatSize ($window.Width+[Math]::Sign($_.Delta)*24);$_.Handled=$true}})
$window.Add_KeyDown({if($_.Key -eq 'Escape'){$window.Close()}elseif($_.Key -eq 'Space'){Pet-Cat}})
$window.Add_MouseLeftButtonDown({$script:press=$_.GetPosition($window);$script:moved=$false;[void]$window.CaptureMouse()})
$window.Add_MouseMove({
 $point=$_.GetPosition($window)
 if($script:press -and $_.LeftButton -eq 'Pressed'){
  $dx=$point.X-$script:press.X;$dy=$point.Y-$script:press.Y
  if($script:moved -or [Math]::Abs($dx)+[Math]::Abs($dy) -gt 6){
   Move-Cat $dx $dy
  }
 }elseif(!$script:actionActive){
  $dx=$point.X*288/$window.Width-144;$dy=$point.Y*312/$window.Height-115
  if([Math]::Sqrt($dx*$dx+$dy*$dy) -gt 30){
   $degree=([Math]::Atan2($dx,-$dy)*180/[Math]::PI+360)%360
   $index=[int][Math]::Round($degree/22.5)%16
   $script:row=9+[int][Math]::Floor($index/8);$script:column=$index%8
   $cat.Source=$frames["$script:row,$script:column"]
  }elseif($script:row -ne 0){Play-Action 0 0}
 }
})
$window.Add_MouseLeftButtonUp({
 if($script:press -and !$script:moved -and $script:press.Y -lt $window.Height*162/312){Pet-Cat}
 End-Drag
 $window.ReleaseMouseCapture()
})
$window.Add_LostMouseCapture({End-Drag})
$window.Add_MouseLeave({if(!$script:press -and !$script:actionActive){Play-Action 0 0}})
$timer=New-Object Windows.Threading.DispatcherTimer
$timer.Interval=[TimeSpan]::FromMilliseconds(35)
function Update-Cat([DateTime]$Now,[bool]$PointerOver=$window.IsMouseOver){
 # Advance at most one frame per tick. Never skip poses to catch up with wall time.
 if($script:actionActive -and $Now -ge $script:nextFrame){
  if($script:column -eq $counts[$script:row]-1){
   if($script:moved){$script:column=0}
   elseif($script:loopsRemaining -gt 1){$script:loopsRemaining--;$script:column=0}
   else{Play-Action 0 0}
  }else{$script:column++}
  if($script:actionActive){
   $cat.Source=$frames["$script:row,$script:column"]
   $script:nextFrame=$Now.AddMilliseconds($durations[$script:row][$script:column])
  }
 }
 if(!$script:actionActive -and !$script:press -and !$menu.IsOpen -and !$PointerOver -and $Now -ge $script:nextIdle){
  Play-CatAnimation (Select-IdleRow)
 }
}
$timer.Add_Tick({Update-Cat ([DateTime]::Now)})
$script:closed=$false
$window.Add_Closed({
 $timer.Stop()
 if($script:testTimer){$script:testTimer.Stop()}
 $script:press=$null;$window.ReleaseMouseCapture()
 $effects.Children.Clear();$player.Stop();$player.Dispose()
 $script:closed=$true
})
$timer.Start()
if($SelfTest){
 $testOutput=Join-Path $root '.test-output'
 [void][IO.Directory]::CreateDirectory($testOutput)
 $window.Add_Loaded({
  $script:muted=$true
  if($window.ShowInTaskbar){throw 'Pet must be hidden from taskbar'}
  if(!$window.Topmost -or $window.ShowActivated){throw 'Pet must stay topmost without stealing startup focus'}
  if($counts[7] -ne 6 -or ($durations[7] | Measure-Object -Sum).Sum -lt 2800){throw 'Thinking must use six original poses at a slower pace'}
  foreach($r in 0..10){foreach($c in 0..($counts[$r]-1)){
   $frame=$frames["$r,$c"]
   if($frame -isnot [Windows.Media.Imaging.CroppedBitmap] -or $frame.SourceRect.X -ne $c*192 -or $frame.SourceRect.Y -ne $r*208){throw 'Animation no longer matches atlas cell'}
  }}
  $distribution=@{}
  foreach($roll in 0..99){$r=Select-IdleRow $roll;$distribution[[string]$r]++}
  foreach($action in $idleActions){if($distribution[[string]$action.Row] -ne $action.Weight){throw 'Idle weights failed'}}
  foreach($item in $actionMenu.Items){
   $item.RaiseEvent((New-Object Windows.RoutedEventArgs ([Windows.Controls.MenuItem]::ClickEvent)))
   if($script:row -ne [int]$item.Tag -or !$script:actionActive){throw 'Action menu dispatch failed'}
   $expectedRow=[int]$item.Tag;$expectedLoops=$script:lastLoops
   foreach($loop in 1..$expectedLoops){foreach($c in 0..($counts[$expectedRow]-1)){
    if($script:row -ne $expectedRow -or $script:column -ne $c -or ![Object]::ReferenceEquals($cat.Source,$frames["$expectedRow,$c"])){throw 'Animation skipped or reordered a frame'}
    Update-Cat ($script:nextFrame.AddMilliseconds(1)) $true
   }}
   if($script:actionActive -or $script:row -ne 0){throw 'Action failed to return to still idle'}
   $gap=($script:nextIdle-[DateTime]::Now).TotalSeconds
   if($gap -lt 6.5 -or $gap -gt 10.5){throw 'Idle gap outside 7-10 seconds'}
  }
  $observedLoops=@{}
  foreach($trial in 1..40){
   Play-CatAnimation 4
   if($script:lastLoops -notin @(2,3) -or $script:loopsRemaining -ne $script:lastLoops){throw 'Jump must repeat two or three times'}
   $observedLoops[[string]$script:lastLoops]=$true
  }
  if($observedLoops.Count -ne 2){throw 'Jump repetition is not varying'}
  # A delayed timer must still show the next pose, not skip ahead or cut the action short.
  Play-CatAnimation 7
  Update-Cat ($script:nextFrame.AddSeconds(5)) $true
  if(!$script:actionActive -or $script:column -ne 1){throw 'Delayed timer skipped a thinking pose'}
  Play-Action 0 0;$script:nextIdle=[DateTime]::MinValue
  Update-Cat ([DateTime]::Now) $true
  if($script:actionActive){throw 'Idle scheduler interrupted pointer interaction'}
  Update-Cat ([DateTime]::Now) $false
  if(!$script:actionActive){throw 'Due idle action did not start'}
  Play-Action 0 0
  # The scheduler must not interrupt a held mouse press or an active action.
  $script:press=New-Object Windows.Point 10,10;$script:nextIdle=[DateTime]::MinValue
  Update-Cat ([DateTime]::Now)
  if($script:actionActive){throw 'Idle scheduler interrupted mouse press'}
  $script:press=$null
  Play-CatAnimation 8;$script:nextIdle=[DateTime]::MinValue;Update-Cat ([DateTime]::Now)
  if($script:row -ne 8){throw 'Idle scheduler interrupted active animation'}
  Play-Action 0 0
  @{ok=$true;weights=$distribution;menuActions=$actionMenu.Items.Count;thinkingFrames=$counts[7];thinkingDurationMs=($durations[7] | Measure-Object -Sum).Sum;jumpLoops=@(2,3);idleGapSeconds=@(7,10)} | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $testOutput 'idle-actions-test.json')
  Set-CatSize 288
  if($window.Width -ne 288 -or $window.Height -ne 312){throw 'Resize aspect ratio failed'}
  Set-CatSize 999
  if($window.Width -ne 384){throw 'Resize upper limit failed'}
  Set-CatSize 1
  if($window.Width -ne 96){throw 'Resize lower limit failed'}
  Set-CatSize 192
  Move-Cat 12 0
  if($script:row -ne 1){throw 'Right drag animation failed'}
  $script:column=3;Move-Cat 12 0
  if($script:column -ne 3){throw 'Drag incorrectly restarts animation'}
  Move-Cat -24 0
  if($script:row -ne 2){throw 'Left drag animation failed'}
  End-Drag
  if($script:row -ne 0 -or $script:moved){throw 'Drag release failed'}
  Pet-Cat
  if($effects.Children.Count -ne 3 -or $script:row -ne 3){throw 'Head-pet interaction failed'}
  $script:testTimer=New-Object Windows.Threading.DispatcherTimer
  $script:testTimer.Interval=[TimeSpan]::FromMilliseconds(650)
  $script:testTimer.Add_Tick({
   $script:testTimer.Stop()
   if($script:row -ne 3 -or $script:column -lt 2){$window.Close();throw 'Animation did not advance during head-pet action'}
   @{ok=$true;row=$script:row;nextFrame=$script:column;hearts=$effects.Children.Count} | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $testOutput 'native-runtime-test.json')
   $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap ([int]$window.Width),([int]$window.Height),96,96,([Windows.Media.PixelFormats]::Pbgra32)
   $bitmap.Render($window)
   $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
   $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
   $stream=[IO.File]::Create((Join-Path $testOutput 'desktop-interaction-qa.png'))
   try{$encoder.Save($stream)}finally{$stream.Dispose()}
   Write-Output 'PASS: resize bounds and aspect ratio, left/right drag, continuous frames, drag release, head-pet animation and hearts.'
   # Exercise the actual Close menu click handler, not a separate shutdown path.
   $closeItem=$menu.Items | Where-Object {$_.Header -eq 'Close'}
   $closeItem.RaiseEvent((New-Object Windows.RoutedEventArgs ([Windows.Controls.MenuItem]::ClickEvent)))
  })
  $script:testTimer.Start()
 })
}
[void]$window.ShowDialog()
if($SelfTest){
 if(!$script:closed -or $timer.IsEnabled -or $script:testTimer.IsEnabled){throw 'Close did not release timers'}
 @{ok=$true;closeMenu=$true;timersStopped=$true;hiddenFromTaskbar=(!$window.ShowInTaskbar);idleGapSeconds=@(7,10)} | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $testOutput 'shutdown-test.json')
}

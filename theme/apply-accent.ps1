# Saturn accent: gold palette for Windows (Settings > Personalization > Colors), dark mode, transparency on.
# HKCU only, no admin. Previous values are saved to theme\accent-backup.reg first.
$acc = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
reg.exe export 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent' "$PSScriptRoot\accent-backup.reg" /y | Out-Null

# 8 shades light -> dark (RGBA): FFE9B8 F5D08A E8BC6C D9A85A B8863F 8F6526 5E4012 + teal 3D6B5F
$palette = [byte[]](0xFF,0xE9,0xB8,0x00, 0xF5,0xD0,0x8A,0x00, 0xE8,0xBC,0x6C,0x00, 0xD9,0xA8,0x5A,0x00,
                    0xB8,0x86,0x3F,0x00, 0x8F,0x65,0x26,0x00, 0x5E,0x40,0x12,0x00, 0x3D,0x6B,0x5F,0x00)
New-Item $acc -Force | Out-Null
Set-ItemProperty $acc AccentPalette $palette -Type Binary
Set-ItemProperty $acc StartColorMenu  ([int]0xFF26658F) -Type DWord   # ABGR
Set-ItemProperty $acc AccentColorMenu ([int]0xFF3F86B8) -Type DWord

$dwm = 'HKCU:\Software\Microsoft\Windows\DWM'
Set-ItemProperty $dwm AccentColor           ([int]0xFF3F86B8) -Type DWord
Set-ItemProperty $dwm ColorizationColor     ([int]0xC4B8863F) -Type DWord
Set-ItemProperty $dwm ColorizationAfterglow ([int]0xC4B8863F) -Type DWord
Set-ItemProperty $dwm ColorPrevalence 0 -Type DWord

$per = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
Set-ItemProperty $per AppsUseLightTheme 0 -Type DWord
Set-ItemProperty $per SystemUsesLightTheme 0 -Type DWord
Set-ItemProperty $per EnableTransparency 1 -Type DWord
Set-ItemProperty $per ColorPrevalence 0 -Type DWord
"accent applied (sign out / restart Explorer to see it everywhere)"

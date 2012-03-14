; Mintty quake console: Visor-like functionality for Windows
; Version: 1.1
; Author: Jon Rogers (lonepie@gmail.com)
; URL: https://github.com/lonepie/putty-quake-console
; Credits:
;	Originally forked from: https://github.com/marcharding/putty-quake-console
;	putty: http://code.google.com/p/putty/
;	Visor: http://visor.binaryage.com/

; TODO: 
;  - GUI: 
;		- choose between PuTTY or KiTTY
;		- putty exe location
;		- putty session source
;			- registry (default or specfiy path)
;			- directory (specify path)
; - Functionality:
; 		- choose session
;			- launchy putty, get pid, apply quake-console features
;		- apply to current putty window

;*******************************************************************************
;				Settings					
;*******************************************************************************
#NoEnv
#SingleInstance force
SendMode Input
DetectHiddenWindows, on
SetWinDelay, -1

; get path to cygwin from registry
;RegRead, cygwinRootDir, HKEY_LOCAL_MACHINE, SOFTWARE\Cygwin\setup, rootdir
;cygwinBinDir := cygwinRootDir . "\bin"

;*******************************************************************************
;				Preferences & Variables
;*******************************************************************************
VERSION := 1.0
iniFile := "putty-quake-console.ini"
IniRead, puttyPath, %iniFile%, General, putty_path, % cygwinBinDir . "\putty.exe"
IniRead, puttyType, %iniFile%, General, putty_type, "PuTTY"
IniRead, sessionMode, %iniFile%, General, session_mode, "registry"
IniRead, sessionPath, %iniFile%, General, session_path, "HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions"
;IniRead, puttyArgs, %iniFile%, General, putty_args, -
IniRead, consoleHotkey, %iniFile%, General, hotkey, ^``
;IniRead, startWithWindows, %iniFile%, Display, start_with_windows, 0
IniRead, startHidden, %iniFile%, Display, start_hidden, 1
IniRead, initialHeight, %iniFile%, Display, initial_height, 380
IniRead, pinned, %iniFile%, Display, pinned_by_default, 1
IniRead, animationStep, %iniFile%, Display, animation_step, 20
IniRead, animationTimeout, %iniFile%, Display, animation_timeout, 10
IfNotExist %iniFile%
{
	SaveSettings()
}

; path to putty (same folder as script), start with default shell
; puttyPath := cygwinBinDir . "\putty.exe -"
; puttyPath := cygwinBinDir . "\putty.exe /bin/zsh -li"
;puttyPath_args := puttyPath . " " . puttyArgs

; initial height of console window
heightConsoleWindow := initialHeight

;*******************************************************************************
;				Hotkeys						
;*******************************************************************************
Hotkey, %consoleHotkey%, ConsoleHotkey

;*******************************************************************************
;				Menu					
;*******************************************************************************
if !InStr(A_ScriptName, ".exe")
	Menu, Tray, Icon, terminal.ico
Menu, Tray, NoStandard
; Menu, Tray, MainWindow
Menu, Tray, Tip, putty-quake-console %VERSION%
Menu, Tray, Add, Enabled, ToggleScriptState
Menu, Tray, Check, Enabled
Menu, Tray, Add, Pinned, TogglePinned
if (pinned)
	Menu, Tray, Check, Pinned
Menu, Tray, Add
Menu, Tray, Add, Options, ShowOptionsGui
Menu, Tray, Add, About, AboutDlg
Menu, Tray, Add, Reload, ReloadSub
Menu, Tray, Add, Exit, ExitSub

init()
return
;*******************************************************************************
;				Functions / Labels						
;*******************************************************************************
init()
{
	global
	initCount++
	; get last active window
	WinGet, hw_current, ID, A
	if !WinExist("ahk_class" . puttyType) {
		;Run %puttyPath_args%, %cygwinBinDir%, Hide, hw_putty
		Run %puttyPath%
		WinWait ahk_class %puttyType%
	}
	else {
		WinGet, hw_putty, PID, ahk_class %puttyType%
	}
	
	WinGetPos, OrigXpos, OrigYpos, OrigWinWidth, OrigWinHeight, ahk_pid %hw_putty%
	toggleScript("init")
}

toggle()
{
	global

	IfWinActive ahk_pid %hw_putty%
	{
		Slide("ahk_pid" . hw_putty, "Out")
		; reset focus to last active window
		WinActivate, ahk_id %hw_current%
	}
	else
	{
		; get last active window
		WinGet, hw_current, ID, A

		WinActivate ahk_pid %hw_putty%
		Slide("ahk_pid" . hw_putty, "In")
	}
}

Slide(Window, Dir)
{
	global animationStep, animationTimeout, pinned
	WinGetPos, Xpos, Ypos, WinWidth, WinHeight, %Window%
	If (Dir = "In") And (Ypos < 0)
		WinShow %Window%
	If (Xpos != 0)
		WinMove, %Window%,,0
	Loop
	{
	  If (Dir = "In") And (Ypos >= 0) Or (Dir = "Out") And (Ypos <= (-WinHeight))
		 Break
	  
	  ; dRate := WinHeight // 4
	  dRate := animationStep
	  ; dY := % (Dir = "In") ? A_Index*dRate - WinHeight : (-A_Index)*dRate
	  dY := % (Dir = "In") ? Ypos + dRate : Ypos - dRate
	  WinMove, %Window%,,, dY
	  WinGetPos, Xpos, Ypos, WinWidth, WinHeight, %Window%
	  Sleep, %animationTimeout%
	}
	If (Dir = "In") And (Ypos >= 0) {
		WinMove, %Window%,,, 0 
		if (!pinned)
			SetTimer, HideWhenInactive, 250
	}
	If (Dir = "Out") And (Ypos <= (-WinHeight)) {
		WinHide %Window%
		if (!pinned)
			SetTimer, HideWhenInactive, Off
	}
}

toggleScript(state) {
	; enable/disable script effects, hotkeys, etc
	global
	; WinGetPos, Xpos, Ypos, WinWidth, WinHeight, ahk_pid %hw_putty%
	if(state = "on" or state = "init") {
		If !WinExist("ahk_pid" . hw_putty) {
			init()
			return
		}
		WinHide ahk_pid %hw_putty%
		;WinSet,Transparent,210,ahk_pid %hw_putty%
		WinSet, Style, +0x1000000, ahk_pid %hw_putty%
		WinSet, Style, -0xC00000, ahk_pid %hw_putty%
		WinSet, Style, -0x200000, ahk_pid %hw_putty%
		WinSet, Style, -0x40000, ahk_pid %hw_putty%
		; WinGetPos, Xpos, Ypos, WinWidth, WinHeight, ahk_pid %hw_putty%
		if (OrigYpos >= 0 or OrigWinWidth < A_ScreenWidth)
				WinMove, ahk_pid %hw_putty%, , 0, -%heightConsoleWindow%, A_ScreenWidth, %heightConsoleWindow% ; resize/move
		
		scriptEnabled := True
		Menu, Tray, Check, Enabled
		
		if (state = "init" and initCount = 1 and startHidden) {
			return
		}
		
		WinShow ahk_pid %hw_putty%
		WinActivate ahk_pid %hw_putty%
		Slide("ahk_pid" . hw_putty, "In")
	}
	else if (state = "off") {
		WinSet, Style, +0xC00000, ahk_pid %hw_putty%
		WinSet, Style, +0x200000, ahk_pid %hw_putty%
		WinSet, Style, +0x40000, ahk_pid %hw_putty%
		WinSet, Style, -0x1000000, ahk_pid %hw_putty%
		if (OrigYpos >= 0)
			WinMove, ahk_pid %hw_putty%, , %OrigXpos%, %OrigYpos%, %OrigWinWidth%, %OrigWinHeight% ; restore size / position
		else
			WinMove, ahk_pid %hw_putty%, , %OrigXpos%, 100, %OrigWinWidth%, %OrigWinHeight%
		WinShow, ahk_pid %hw_putty% ; show window
		scriptEnabled := False
		Menu, Tray, Uncheck, Enabled
	}
}

HideWhenInactive:
	IfWinNotActive ahk_pid %hw_putty%
	{
		Slide("ahk_pid" . hw_putty, "Out")
		SetTimer, HideWhenInactive, Off
	}
return

ToggleScriptState:
	if(scriptEnabled)
		toggleScript("off")
	else
		toggleScript("on")
return

TogglePinned:
	pinned := !pinned
	Menu, Tray, ToggleCheck, Pinned
	SetTimer, HideWhenInactive, Off
return

ConsoleHotkey:
	If (scriptEnabled) {
		IfWinExist ahk_pid %hw_putty%
		{
			toggle()
		}
		else
		{
			init()
		}
	}
return

ExitSub:
	if A_ExitReason not in Logoff,Shutdown
	{
		MsgBox, 4, putty-quake-console, Are you sure you want to exit?
		IfMsgBox, No
			return
		toggleScript("off")
	}
ExitApp

ReloadSub:
Reload
return

AboutDlg:
	MsgBox, 64, About, putty-quake-console AutoHotkey script`nVersion: %VERSION%`nAuthor: Jonathon Rogers <lonepie@gmail.com>`nURL: https://github.com/lonepie/putty-quake-console
return

ShowOptionsGui:
	OptionsGui()
return

;*******************************************************************************
;				Extra Hotkeys						
;*******************************************************************************
#IfWinActive ahk_class putty
; why this method doesn't work, I don't know...
; Hotkey, IfWinActive, ahk_pid %hw_putty%
; Hotkey, ^!NumpadAdd, IncreaseHeight
; Hotkey, ^!NumpadSub, DecreaseHeight
; IncreaseHeight:
^!NumpadAdd::
	if(WinActive("ahk_pid" . hw_putty)) {
		if(heightConsoleWindow < A_ScreenHeight) {
			heightConsoleWindow += animationStep
			WinMove, ahk_pid %hw_putty%,,,,, heightConsoleWindow
		}
	}
return
; DecreaseHeight:
^!NumpadSub::
	if(WinActive("ahk_pid" . hw_putty)) {
		if(heightConsoleWindow > 100) {
			heightConsoleWindow -= animationStep
			WinMove, ahk_pid %hw_putty%,,,,, heightConsoleWindow
		}
	}
return
#IfWinActive

;*******************************************************************************
;				Options					
;*******************************************************************************
SaveSettings() {
	global
	IniWrite, %puttyPath%, %iniFile%, General, putty_path
	IniWrite, %puttyArgs%, %iniFile%, General, putty_args	
	IniWrite, %consoleHotkey%, %iniFile%, General, hotkey
	IniWrite, %startWithWindows%, %iniFile%, Display, start_with_windows
	IniWrite, %startHidden%, %iniFile%, Display, start_hidden
	IniWrite, %initialHeight%, %iniFile%, Display, initial_height
	IniWrite, %pinned%, %iniFile%, Display, pinned_by_default
	IniWrite, %animationStep%, %inifile%, Display, animation_step
	IniWrite, %animationTimeout%, %iniFile%, Display, animation_timeout
	;CheckWindowsStartup(startWithWindows)
}

CheckWindowsStartup(enable) {
	SplitPath, A_ScriptName, , , , OutNameNoExt
	LinkFile=%A_Startup%\%OutNameNoExt%.lnk

	if !FileExist(LinkFile) {
		if (enable) {
			FileCreateShortcut, %A_ScriptFullPath%, %LinkFile%
		}
	}
	else {
		if(!enable) {
			FileDelete, %LinkFile%
		}
	}
}

OptionsGui() {
	global
	If not WinExist("ahk_id" GuiID) {
		Gui, Add, GroupBox, x12 y10 w450 h110 , General
		Gui, Add, GroupBox, x12 y130 w450 h180 , Display
		Gui, Add, Button, x242 y360 w100 h30 Default, Save
		Gui, Add, Button, x362 y360 w100 h30 , Cancel
		Gui, Add, Text, x22 y30 w70 h20 , Mintty Path:
		Gui, Add, Edit, x92 y30 w250 h20 VputtyPath, %puttyPath%
		Gui, Add, Button, x352 y30 w100 h20, Browse
		Gui, Add, Text, x22 y60 w100 h20 , Mintty Arguments:
		Gui, Add, Edit, x122 y60 w330 h20 VputtyArgs, %puttyArgs%
		Gui, Add, Text, x22 y90 w100 h20 , Hotkey Trigger:
		Gui, Add, Hotkey, x122 y90 w100 h20 VconsoleHotkey, %consoleHotkey%
		Gui, Add, CheckBox, x22 y150 w100 h30 VstartHidden Checked%startHidden%, Start Hidden
		Gui, Add, CheckBox, x22 y180 w100 h30 Vpinned Checked%pinned%, Pinned
		;Gui, Add, CheckBox, x22 y210 w120 h30 VstartWithWindows Checked%startWithWindows%, Start With Windows
		Gui, Add, Text, x22 y250 w100 h20 , Initial Height (px):
		Gui, Add, Edit, x22 y270 w100 h20 VinitialHeight, %initialHeight%
		Gui, Add, Text, x232 y170 w220 h20 , Animation Delta (px):
		Gui, Add, Text, x232 y220 w220 h20 , Animation Time (ms):
		Gui, Add, Slider, x232 y190 w220 h30 VanimationStep Range5-50, %animationStep%
		Gui, Add, Slider, x232 y240 w220 h30 VanimationTimeout Range5-50, %animationTimeout%
		Gui, Add, Text, x232 y280 w220 h20 +Center, Animation Speed = Delta / Time
	}
	; Generated using SmartGUI Creator 4.0
	Gui, Show, h410 w482, TerminalHUD Options
	Gui, +LastFound
	GuiID := WinExist()
	
	Loop {
		;sleep to reduce CPU load
        Sleep, 100 

        ;exit endless loop, when settings GUI closes 
        If not WinExist("ahk_id" GuiID) 
            Break 
	}

	ButtonSave:
		Gui, Submit
		SaveSettings()
		Reload
	return
	
	ButtonBrowse:
		FileSelectFile, SelectedPath, 3, %A_MyDocuments%, Path to putty.exe, Executables (*.exe)
		if SelectedPath != 
			GuiControl,, MinttyPath, %SelectedPath%
	return
	
	GuiClose:
	GuiEscape:
	ButtonCancel:
		Gui, Cancel
	return
}

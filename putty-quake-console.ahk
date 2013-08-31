; PuTTY quake console: Visor-like functionality for Windows
; Version: 1.0
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
SetWorkingDir %A_ScriptDir%

; get path to cygwin from registry
;RegRead, cygwinRootDir, HKEY_LOCAL_MACHINE, SOFTWARE\Cygwin\setup, rootdir
;cygwinBinDir := cygwinRootDir . "\bin"

;*******************************************************************************
;				Preferences & Variables
;*******************************************************************************
VERSION := 1.0

; Registry Paths
puttyRegPath = "HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions"
kittyRegPath = "HKEY_CURRENT_USER\Software\9bis.com\KiTTY\Sessions"

; Default paths
defaultSessionStorePath = ""
dirSessionsPath = "Sessions"


iniFile := "putty-quake-console.ini"
IniRead, clientPath, %iniFile%, General, client_path, "putty.exe"
IniRead, clientType, %iniFile%, General, client_type, "PuTTY"
IniRead, sessionStore, %iniFile%, General, session_store, "registry"
if(sessionStore = "registry") {
    defaultSessionStorePath := clientType = "putty" ? puttyRegPath : kittyRegPath
}
IniRead, sessionStorePath, %iniFile%, General, session_store_path, %defaultSessionStorePath%
IniRead, clientArgs, %iniFile%, General, client_args, ""
IniRead, defaultSession, %iniFile%, General, default_session, ""
IniRead, consoleHotkey, %iniFile%, General, hotkey, ^``
IniRead, startWithWindows, %iniFile%, Display, start_with_windows, 0
IniRead, startHidden, %iniFile%, Display, start_hidden, 1
IniRead, initialHeight, %iniFile%, Display, initial_height, 380
IniRead, initialWidth, %iniFile%, Display, initial_width, 100 ; percent
IniRead, initialTrans, %iniFile%, Display, initial_trans, 235 ; 0-255 stepping
IniRead, autohide, %iniFile%, Display, autohide_by_default, 0
IniRead, animationModeFade, %iniFile%, Display, animation_mode_fade, 0
IniRead, animationModeSlide, %iniFile%, Display, animation_mode_slide, 1
IniRead, animationStep, %iniFile%, Display, animation_step, 20
IniRead, animationTimeout, %iniFile%, Display, animation_timeout, 10
IfNotExist %iniFile%
{
	SaveSettings()
}

if(clientType = "putty") {
    clientType = "PuTTY" ; case sensitive for ahk_class
}
else if(clientType = "kitty") {
    clientType = "KiTTY"
}
else {
    ; client type is invalid - throw error
}

if(!clientPath) {
    StringLower, clientPath, clientType
    clientPath .= ".exe"
}


clientPath_args := clientPath
if(defaultSession) {
    if(InStr(defaultSession, "-load") or InStr(defaultSession, "-ssh") or InStr(defaultSession, "-telnet"))
        clientPath_args .= " " . defaultSession
    else
        clientPath_args .= " -load " . defaultSession
}
if(clientArgs)
    clientPath_args .= " " . clientArgs

; initial height and width of console window
heightConsoleWindow := initialHeight
widthConsoleWindow := initialWidth

isVisible := False

;*******************************************************************************
;				Hotkeys
;*******************************************************************************
Hotkey, %consoleHotkey%, ConsoleHotkey

;*******************************************************************************
;				Menu
;*******************************************************************************
if !InStr(A_ScriptName, ".exe")
    Menu, Tray, Icon, %A_ScriptDir%\terminal.ico
Menu, Tray, NoStandard
; Menu, Tray, MainWindow
Menu, Tray, Tip, putty-quake-console %VERSION%
Menu, Tray, Click, 1
Menu, Tray, Add, Show/Hide, ToggleVisible
Menu, Tray, Default, Show/Hide
Menu, Tray, Add, Enabled, ToggleScriptState
Menu, Tray, Check, Enabled
Menu, Tray, Add, Auto-Hide, ToggleAutoHide
if (autohide)
    Menu, Tray, Check, Auto-Hide
Menu, Tray, Add
;Menu, Tray, Add, Options, ShowOptionsGui
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
	if !WinExist("ahk_class" . clientType) {
		;Run %clientPath_args%, %cygwinBinDir%, Hide, hw_client
		Run %clientPath_args%
		WinWait ahk_class %clientType%
	}
	else {
		WinGet, hw_client, PID, ahk_class %clientType%
	}

	WinGetPos, OrigXpos, OrigYpos, OrigWinWidth, OrigWinHeight, ahk_pid %hw_client%
	toggleScript("init")
}

toggle()
{
	global

	IfWinActive ahk_pid %hw_client%
	{
		Slide("ahk_pid" . hw_client, "Out")
		; reset focus to last active window
		WinActivate, ahk_id %hw_current%
	}
	else
	{
		; get last active window
		WinGet, hw_current, ID, A

		WinActivate ahk_pid %hw_client%
		Slide("ahk_pid" . hw_client, "In")
	}
}

Slide(Window, Dir)
{
    global initialWidth, animationModeFade, animationModeSlide, animationStep, animationTimeout, autohide, isVisible, currentTrans, initialTrans
    WinGetPos, Xpos, Ypos, WinWidth, WinHeight, %Window%

    WinGet, testTrans, Transparent, %Window%
    if (testTrans = "" or (animationModeFade and currentTrans = 0))
    {
        ; Solution for Windows 8 to find window without borders, only 1st call will flash borders
        WinSet, Style, +0x040000, %Window% ; show window border
        WinSet, Transparent, %currentTrans%, %Window%
        WinSet, Style, -0x040000, %Window% ; hide window border
        ; this problem seems to happen if putty's transparency is set to "Off"
        ; putty will lose transparency when the window loses focus, so it's best to just use
        ; putty's built in transparency setting
    }

    VirtScreenPos(ScreenLeft, ScreenTop, ScreenWidth, ScreenHeight)

    if (animationModeFade)
    {
        WinMove, %Window%,, WinLeft, ScreenTop
    }

    ; Multi monitor support.  Always move to current window
    If (Dir = "In")
    {
      WinShow %Window%
      WinLeft := ScreenLeft + (1 - initialWidth/100) * ScreenWidth / 2
      WinMove, %Window%,, WinLeft
    }
    Loop
    {
      inConditional := (animationModeSlide) ? (Ypos >= ScreenTop) : (currentTrans == initialTrans)
      outConditional := (animationModeSlide) ? (Ypos <= (-WinHeight)) : (currentTrans == 0)

      If (Dir = "In") And inConditional Or (Dir = "Out") And outConditional
         Break

      if (animationModeFade = 1)
      {
          dRate := animationStep/300*255
          dT := % (Dir = "In") ? currentTrans + dRate : currentTrans - dRate
          dT := (dT < 0) ? 0 : ((dT > initialTrans) ? initialTrans : dT)

          WinSet, Transparent, %dT%, %Window%
          currentTrans := dT
      }
      else
      {
          dRate := animationStep
          dY := % (Dir = "In") ? Ypos + dRate : Ypos - dRate
          WinMove, %Window%,,, dY
      }
      WinGetPos, Xpos, Ypos, WinWidth, WinHeight, %Window%
      Sleep, %animationTimeout%
    }

    If (Dir = "In")  {
        WinMove, %Window%,,, ScreenTop
        if (autohide)
            SetTimer, HideWhenInactive, 250
        isVisible := True
    }
    If (Dir = "Out")  {
        WinHide %Window%
        if (autohide)
            SetTimer, HideWhenInactive, Off
        isVisible := False
    }
}

toggleScript(state) {
    ; enable/disable script effects, hotkeys, etc
    global
    ; WinGetPos, Xpos, Ypos, WinWidth, WinHeight, ahk_pid %hw_client%
    if(state = "on" or state = "init") {
        If !WinExist("ahk_pid" . hw_client) {
            init()
            return
        }

        ; use putty's transparency setting, if it's set
        WinGet, puttyTrans, Transparent, ahk_pid %hw_client%
        if (puttyTrans <> "")
            initialTrans:=puttyTrans
        WinSet, Transparent, %initialTrans%, ahk_pid %hw_client%
        currentTrans:=initialTrans

        WinHide ahk_pid %hw_client%
        WinSet, Style, -0xC40000, ahk_pid %hw_client% ; hide window borders and caption/title

        VirtScreenPos(ScreenLeft, ScreenTop, ScreenWidth, ScreenHeight)

        width := ScreenWidth * widthConsoleWindow / 100
        left := ScreenLeft + ((ScreenWidth - width) /  2)
        WinMove, ahk_pid %hw_client%, , %left%, -%heightConsoleWindow%, %width%, %heightConsoleWindow% ; resize/move

        scriptEnabled := True
        Menu, Tray, Check, Enabled

        if (state = "init" and initCount = 1 and startHidden) {
            return
        }

        WinShow ahk_pid %hw_client%
        WinActivate ahk_pid %hw_client%
        Slide("ahk_pid" . hw_client, "In")
    }
    else if (state = "off") {
            WinSet, Style, +0xC40000, ahk_pid %hw_client% ; show window borders and caption/title
        if (OrigYpos >= 0)
            WinMove, ahk_pid %hw_client%, , %OrigXpos%, %OrigYpos%, %OrigWinWidth%, %OrigWinHeight% ; restore size / position
        else
            WinMove, ahk_pid %hw_client%, , %OrigXpos%, 100, %OrigWinWidth%, %OrigWinHeight%
        WinShow, ahk_pid %hw_client% ; show window
        scriptEnabled := False
        Menu, Tray, Uncheck, Enabled
    }
}

HideWhenInactive:
    IfWinNotActive ahk_pid %hw_client%
    {
        Slide("ahk_pid" . hw_client, "Out")
        SetTimer, HideWhenInactive, Off
    }
return

ToggleVisible:
    if(isVisible)
    {
        Slide("ahk_pid" . hw_client, "Out")
    }
    else
    {
        WinActivate ahk_pid %hw_client%
        Slide("ahk_pid" . hw_client, "In")
    }
return

ToggleScriptState:
    if(scriptEnabled)
        toggleScript("off")
    else
        toggleScript("on")
return

ToggleAutoHide:
    autohide := !autohide
    Menu, Tray, ToggleCheck, Auto-Hide
    SetTimer, HideWhenInactive, Off
return

ConsoleHotkey:
	If (scriptEnabled) {
		IfWinExist ahk_pid %hw_client%
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
; IncreaseHeight:
^!NumpadAdd::
^+=::
    if(WinActive("ahk_pid" . hw_client)) {

    VirtScreenPos(ScreenLeft, ScreenTop, ScreenWidth, ScreenHeight)
        if(heightConsoleWindow < ScreenHeight) {
            heightConsoleWindow += animationStep
            WinMove, ahk_pid %hw_client%,,,,, heightConsoleWindow
        }
    }
return
; DecreaseHeight:
^!NumpadSub::
^+-::
    if(WinActive("ahk_pid" . hw_client)) {
        if(heightConsoleWindow > 100) {
            heightConsoleWindow -= animationStep
            WinMove, ahk_pid %hw_client%,,,,, heightConsoleWindow
        }
    }
return
#IfWinActive

;*******************************************************************************
;				Options
;*******************************************************************************
SaveSettings() {
    global
    IniWrite, %clientPath%, %iniFile%, General, putty_path
    IniWrite, %clientArgs%, %iniFile%, General, putty_args
    IniWrite, %consoleHotkey%, %iniFile%, General, hotkey
    IniWrite, %startWithWindows%, %iniFile%, Display, start_with_windows
    IniWrite, %startHidden%, %iniFile%, Display, start_hidden
    IniWrite, %initialHeight%, %iniFile%, Display, initial_height
    IniWrite, %initialWidth%, %iniFile%, Display, initial_width
    IniWrite, %initialTrans%, %iniFile%, Display, initial_trans
    IniWrite, %autohide%, %iniFile%, Display, autohide_by_default
    IniWrite, %animationModeSlide%, %iniFile%, Display, animation_mode_slide
    IniWrite, %animationModeFade%, %iniFile%, Display, animation_mode_fade
    IniWrite, %animationStep%, %inifile%, Display, animation_step
    IniWrite, %animationTimeout%, %iniFile%, Display, animation_timeout
    CheckWindowsStartup(startWithWindows)
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
            Gui, Add, GroupBox, x12 y130 w450 h250 , Display
        Gui, Add, Button, x242 y390 w100 h30 Default, Save
        Gui, Add, Button, x362 y390 w100 h30 , Cancel
        Gui, Add, Text, x22 y30 w70 h20 , PuTTY Path:
        Gui, Add, Edit, x92 y30 w250 h20 VclientPath, %clientPath%
        Gui, Add, Button, x352 y30 w100 h20, Browse
        Gui, Add, Text, x22 y60 w100 h20 , PuTTY Arguments:
        Gui, Add, Edit, x122 y60 w330 h20 VclientArgs, %clientArgs%
        Gui, Add, Text, x22 y90 w100 h20 , Hotkey Trigger:
        Gui, Add, Hotkey, x122 y90 w100 h20 VconsoleHotkey, %consoleHotkey%
        Gui, Add, CheckBox, x22 y150 w100 h30 VstartHidden Checked%startHidden%, Start Hidden
        Gui, Add, CheckBox, x22 y180 w150 h30 Vautohide Checked%autohide%, Auto-Hide when focus is lost
        Gui, Add, CheckBox, x22 y210 w120 h30 VstartWithWindows Checked%startWithWindows%, Start With Windows
        Gui, Add, Text, x22 y250 w100 h20 , Initial Height (px):
        Gui, Add, Edit, x22 y270 w100 h20 VinitialHeight, %initialHeight%
        Gui, Add, Text, x22 y300 w115 h20 , Initial Width (percent):
        Gui, Add, Edit, x22 y320 w100 h20 VinitialWidth, %initialWidth%

        Gui, Add, GroupBox, x232 y150 w220 h45 , Animation Type:
        Gui, Add, Radio, x252 y168 w70 h20 VanimationModeSlide group Checked%animationModeSlide%, Slide
        Gui, Add, Radio, x332 y168 w70 h20 VanimationModeFade Checked%animationModeFade%, Fade

        Gui, Add, Text, x232 y210 w220 h20 , Animation Delta (px):
        Gui, Add, Text, x232 y260 w220 h20 , Animation Time (ms):
        Gui, Add, Slider, x232 y230 w220 h30 VanimationStep Range1-100 TickInterval20 , %animationStep%
        Gui, Add, Slider, x232 y280 w220 h30 VanimationTimeout Range1-50 TickInterval10, %animationTimeout%
        Gui, Add, Text, x232 y310 w220 h20 , Window Transparency (`%):
        Gui, Add, Slider, x232 y330 w220 h30 VinitialTrans Range100-255 , %initialTrans%
        ; Gui, Add, Text, x232 y320 w220 h20 +Center, Animation Speed = Delta / Time
    }
    ; Generated using SmartGUI Creator 4.0
    Gui, Show, h440 w482, TerminalHUD Options
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
        FileSelectFile, SelectedPath, 3, %A_MyDocuments%, Path to putty.exe/kitty.exe, Executables (*.exe)
        if SelectedPath !=
            GuiControl,, clientPath, %SelectedPath%
    return

    GuiClose:
    GuiEscape:
    ButtonCancel:
        Gui, Cancel
    return
}

;*******************************************************************************
;               Utility
;*******************************************************************************
GetSessions() {

}

; Gets the edge that the taskbar is docked to.  Returns:
;   "top"
;   "right"
;   "bottom"
;   "left"

VirtScreenPos(ByRef mLeft, ByRef mTop, ByRef mWidth, ByRef mHeight)
{
  Coordmode, Mouse, Screen
    MouseGetPos,x,y
    SysGet, m, MonitorCount
    ; Iterate through all monitors.
    Loop, %m%
    {   ; Check if the window is on this monitor.
      SysGet, Mon, Monitor, %A_Index%
      SysGet, MonArea, MonitorWorkArea, %A_Index%
        if (x >= MonLeft && x <= MonRight && y >= MonTop && y <= MonBottom)
        {
        mLeft:=MonAreaLeft
        mTop:=MonAreaTop
        mWidth:=(MonAreaRight - MonAreaLeft)
        mHeight:=(MonAreaBottom - MonAreaTop)
        }
    }
}

/*
ResizeAndCenter(w, h)
{
  ScreenX := GetScreenLeft()
  ScreenY := GetScreenTop()
  ScreenWidth := GetScreenWidth()
  ScreenHeight := GetScreenHeight()

  WinMove A,,ScreenX + (ScreenWidth/2)-(w/2),ScreenY + (ScreenHeight/2)-(h/2),w,h
}
*/

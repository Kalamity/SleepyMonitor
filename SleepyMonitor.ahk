#SingleInstance force
#Persistent
SetWorkingDir %A_ScriptDir%

version := "1.07"


Process, Priority,, Low
global isMonitorOn := True ; on
global newGUID := ""
idleCheckTime := 2000

FileCreateDir, %A_Temp%\SleepyMonitor 
FileInstall, Resources\Sleep.ico, %A_Temp%\SleepyMonitor\Sleep.ico, 1
FileInstall, Resources\Disabled.ico, %A_Temp%\SleepyMonitor\Disabled.ico, 1
Menu, Tray, Icon, %A_Temp%\SleepyMonitor\Sleep.ico, 1, 1

varSetCapacity(newGUID,16,0)
if a_OSVersion in WIN_8,WIN_8.1,WIN_10
    dllCall("Rpcrt4\UuidFromString", "Str", GUID_CONSOLE_DISPLAY_STATE := "6fe69556-704a-47a0-8f24-c28d936fda47", "Ptr", &newGUID)
else dllCall("Rpcrt4\UuidFromString", "Str", GUID_MONITOR_POWER_ON := "02731015-4510-4526-99e6-e5a17ebd1aea", "Ptr", &newGUID)
rhandle := dllCall("RegisterPowerSettingNotification", "Ptr", A_scriptHwnd, "Str", strGet(&newGUID), "UInt", 0, "Ptr")
onMessage(0x218, "WM_POWERBROADCAST")

gosub, ReadSettings
SetTimer, IdleCheck, %idleCheckTime%

Menu, tray, NoStandard
Menu, tray, add  ; Creates a separator line.
Menu, tray, add, &Settings, SettingsGUI ; label cant have spaces
Menu, tray, Default, &Settings 
Menu, tray, add
Menu, tray, add, &Monitor Standby, MonitorStandby 
Menu, tray, add  
Menu, tray, add, &Screen Saver, LaunchScreenSaver 

aMenuName := { 	"DisableFor015": "15 Mins", "DisableFor030": "30 Mins", "DisableFor060":  "60 Mins"
			, 	"DisableFor090": "90 Mins", "DisableForHours002": "2 Hrs", "DisableForHours004": "4 Hrs", "DisableForHours006": "6 Hrs" }

for label, menuName in aMenuName
	Menu, DisableSubMenu, Add, %menuName%, %label%
Menu, DisableSubMenu, Add
Menu, DisableSubMenu, Add, Until Restart, DisableUntilAppRestart

Menu, tray, add  
Menu, tray, Add, DisableFor, :DisableSubMenu
Menu, tray, Rename, DisableFor, Disable For
Menu, tray, add  
Menu, tray, add , Exit, ExitRoutine 

OnExit, ExitRoutine

Menu, Tray, Tip, SleepyMonitor

enableScreenSaver_TT := "Enables the screen saver.`nIt starts after the specified delay."
saverMins_TT := SaverMinsEditDummy_TT := "The screen saver will start once the user has been idle for this period of time."
UseSystemScreenSaver_TT := "Uses the screen saver specified in control panel / Windows settings."
EnableCycleScreenSavers_TT := "When enabled (and multiple screen savers are chosen) the running screen saver will be randomly cycled."
CycleMins_TT := CycleMinsEditDummy_TT := "After a screen saver has been running for this many minutes it will be randomly cycled to another screen saver."
ScreenSaverFile_TT := "Screen savers from:`n" A_Tab A_WinDir "\`n" A_Tab A_WinDir "\System32\`n" A_Tab A_ScriptDir "\Screensavers\"
preWarning_TT := "A system alert sound is made before starting the screen saver or placing the monitor into standby.`nNote: No sound is made if the screen saver is already running."
preWarningSeconds_TT := PreWarningSecondsEditDummy_TT := "The alert will sound this many seconds before the screen saver starts or before the monitor is placed into standby."
enableMonitorStandby_TT := "Allows the monitor to be put into low-power/standby mode."
monOffMins_TT := MonOffMinsEditDummy_TT := "The monitor will be placed into low-power state after the user has been idle for this period of time."
return

ExitRoutine:
dllCall("UnregisterPowerSettingNotification", "Ptr", rhandle)
ExitApp
return 

debug:
s := "isMonitorOn: " isMonitorOn "`n"
	. "Idle s: " A_TimeIdle / 1000 "`n"
	. "preWarning && A_TimeIdle >= saverWarningMS: " (preWarning && A_TimeIdle >= saverWarningMS ) "`n"
  	. "isScreenSaverRunning(useSystemScreenSaver, aLastLaunchedSaver): " isScreenSaverRunning()
  ToolTip, % s
 return 


IdleCheck:
if !isMonitorOn
	return 

if (A_TimeIdle < prevIdle)
	hasWarned := false 
prevIdle := A_TimeIdle

if (enableScreenSaver)
{
	if (preWarning && A_TimeIdle >= saverWarningMS && !hasWarned && !isScreenSaverRunning())
	{
		hasWarned := true
		SoundPlay, *-1
		return 
	}	
	else if (A_TimeIdle >= saverMS) && (!isScreenSaverRunning() || (enableCycleScreenSavers && A_TickCount - screenSaverLaucnedAt >= cycleMS))
	{
		loop
		{ 	
			nextScreenSaver := randomArrayItem(aEnabledScreenSaverPaths)
		} until (aLastLaunchedSaver != nextScreenSaver) || aEnabledScreenSaverPaths.MaxIndex() <= 1 ; <= 1 as could be 0...in which case start sys screensaver
		screenSaverLaucnedAt := A_TickCount
		startSleepyScreenSaver(useSystemScreenSaver, aLastLaunchedSaver := nextScreenSaver)
	}
}

if (enableMonitorStandby)
{
	if (preWarning && A_TimeIdle >= monOffWarningMS && !hasWarned && !isScreenSaverRunning())
	{
		hasWarned := true
		SoundPlay, *-1
		return 
	}	
	else if (A_TimeIdle >= monOffMS)
	{
		monitorStandby()
		return 
	}	
}

return

debug()
{
	global 
	g_debug .= isScreenSaverRunning()
			. "`n" aLastLaunchedSaver
			. "`n" g_debugPos
			. "`n==============`n"
}

LaunchScreenSaver:
MonitorStandby:
sleep 2000
if (A_ThisLabel = "LaunchScreenSaver")
	startSleepyScreenSaver(useSystemScreenSaver, randomArrayItem(aEnabledScreenSaverPaths)) 
else monitorStandby()
return 

DisableUntilAppRestart:

; isDisabledUntilRestart is true when a checkmark is on this menu item 

if isDisabledUntilRestart := !isDisabledUntilRestart
{
	Menu, DisableSubMenu, Check, Until Restart
	settimer, reenableMonitoring, off
	SetTimer, UpdateTimeRemaing, Off
	settimer, IdleCheck, off
	Menu, Tray, Icon, %A_Temp%\SleepyMonitor\Disabled.ico, 1, 1
	Menu, Tray, Tip, Disabled until app restart....
	if disabledMenuLabelClicked
	{
		Menu, DisableSubMenu, Uncheck, % aMenuName[disabledMenuLabelClicked]
		disabledMenuLabelClicked := ""
	}
}
else gosub ReenableMonitoring
return 

DisableFor001:
DisableFor015:
DisableFor030:
DisableFor060:
DisableFor090:
DisableForHours002:
DisableForHours004:
DisableForHours006:

; disabledMenuLabelClicked is true (will hold the label name) 
; whenever a checkmark is applied to these menu items

; If clicked item was previously clicked (and it hasn't expired)
; re-enable monitoring and remove checkmark
if (A_ThisLabel = disabledMenuLabelClicked)
{
	setTimer, reenableMonitoring, -1
	return
}
else if disabledMenuLabelClicked
	Menu, DisableSubMenu, Uncheck,%  aMenuName[disabledMenuLabelClicked]

Menu, DisableSubMenu, ToggleCheck, % aMenuName[A_ThisLabel]
isDisabledUntilRestart := false
Menu, DisableSubMenu, Uncheck, Until Restart
disabledMenuLabelClicked := A_ThisLabel

settimer, IdleCheck, off
settimer, ReenableMonitoring, % - 1 * 60 * 1000 * (disableForMins := SubStr(A_ThisLabel, StrLen(A_ThisLabel) - 2) * (InStr(A_ThisLabel, "Hours") ? 60 : 1))
SetTimer, UpdateTimeRemaing, 60000 ; update every minute
Menu, Tray, Icon, %A_Temp%\SleepyMonitor\Disabled.ico, 1, 1
gosub UpdateTimeRemaing
return

ReenableMonitoring:
if aMenuName.HasKey(disabledMenuLabelClicked)
	Menu, DisableSubMenu, Uncheck, % aMenuName[disabledMenuLabelClicked]
Menu, DisableSubMenu, Uncheck, Until Restart
disabledMenuLabelClicked := ""
SetTimer, IdleCheck, %idleCheckTime%
SetTimer, UpdateTimeRemaing, Off
Menu, Tray, Tip, SleepyMonitor
Menu, Tray, Icon, %A_Temp%\SleepyMonitor\Sleep.ico, 1, 1
return 

UpdateTimeRemaing:
Menu, Tray, Tip, % "Disabled for another " disableForMins " minutes...."
disableForMins -= 1
return 

SettingsGUI:
Gui +LastFoundExist ; prevent error due to reloading gui 
IfWinExist 
{
	WinActivate
	Return 									
}

Gui, Add, GroupBox, y+20 w300 h440 section, Screen Saver 
Gui, Add, Checkbox, xs+15 yp+25 vEnableScreenSaver Checked%enableScreenSaver% gGUIControlHandler, Enable
			
Gui, Add, Text, xs+170 ys+25, Delay Mins:
Gui, Add, Edit, % "Number Right x+15 yp-2 w45 vSaverMinsEditDummy Disabled" !enableScreenSaver 
Gui, Add, UpDown,  Range1-1000 vSaverMins, %saverMins%	

Gui, Add, Checkbox, xs+15 yp+35 vUseSystemScreenSaver Checked%useSystemScreenSaver% gGUIControlHandler, System screen saver

Gui, Add, Checkbox, % "xs+15 yp+35 vEnableCycleScreenSavers Checked" EnableCycleScreenSavers " gGUIControlHandler Disabled" useSystemScreenSaver, Cycle screen Savers

Gui, Add, Text, xs+170 yp, Cycle Mins:
Gui, Add, Edit, % "Number Right x+15 yp-2 w45 vCycleMinsEditDummy Disabled" (useSystemScreenSaver || !EnableCycleScreenSavers)
Gui, Add, UpDown,  Range1-1000 vCycleMins, %CycleMins%	


Gui, Add, ListView, xs+15 yp+35 w270 Checked -LV0x10 -Multi -Hdr  R15 ReadOnly Disabled%useSystemScreenSaver% vLVDummy, FileName|FullFilePath ; still need column title with -Hdr, otherwise LV is empty

for i, screenSaver in findInstalledScreenSavers(enabledScreenSaversFullPaths)
	LV_Add( screenSaver.enabled ? "Check" : "", screenSaver.fileName, screenSaver.filePathFull)

LV_ModifyCol(2, 0) ; set column width to 0
LV_ModifyCol(1, "Auto") 

Gui, add, button, xs+15 y+15 w90 h25 gTestScreenSaver, Test
Gui, add, button, x+25  w90 h25 gConfigureScreenSaver Disabled%UseSystemScreenSaver% vConfigButtonDummy, Config

Gui, Add, GroupBox, xs  y+35 w300 h60 section, Screen Standby
Gui, Add, Checkbox, xs+15 yp+25 vEnableMonitorStandby Checked%enableMonitorStandby% gGUIControlHandler, Enable
Gui, Add, Text, xs+170 ys+25, Delay Mins:
Gui, Add, Edit, % "Number Right x+15 yp-2 w45 vMonOffMinsEditDummy Disabled" !enableMonitorStandby
Gui, Add, UpDown,  Range1-1000 vMonOffMins, %monOffMins%	


Gui, Add, GroupBox, xs  y+35 w300 h60 section, Warning
Gui, Add, Checkbox, % "xs+15 yp+25 vPreWarning Checked" preWarning " gGUIControlHandler Disabled" (!enableScreenSaver && !enableMonitorStandby), Enable warning
Gui, Add, Text, xs+170 yp, Delay Secs:
Gui, Add, Edit, % "Number Right x+15 yp-2 w45 vPreWarningSecondsEditDummy Disabled" (!preWarning || (!enableScreenSaver && !enableMonitorStandby))
Gui, Add, UpDown,  Range1-1000 vPreWarningSeconds, %preWarningSeconds%


Gui, Add, GroupBox, xs  y+35 w300 h55 section, Misc
Gui, Add, Checkbox, xs+15 yp+25 vRunOnStartUp Checked%RunOnStartUp%, Run on startup
Gui, add, button, xs ys+85 w54 h25 gSaveSettings, Save
Gui, add, button, x+40 yp w54 h25 gGUIClose, Cancel
Gui, Add, text, x+100 yp+12, Ver: %version%
OnMessage(0x200, "OptionsGUITooltips")
Gui, Show, w320 h755
return


GUIControlHandler:
GuiControlGet, screenSaverChecked,, enableScreenSaver 
GuiControlGet, monitorStandbyChecked,, enableMonitorStandby 
GuiControlGet, preWarningChecked,, preWarning 
GuiControlGet, useSystemScreenSaverChecked,, useSystemScreenSaver 
GuiControlGet, EnableCycleScreenSaversChecked,, enableCycleScreenSavers 


GuiControl, % "Disable" !screenSaverChecked, SaverMinsEditDummy
GuiControl, % "Disable" useSystemScreenSaverChecked, ScreenSaverFile
GuiControl, % "Disable" !(screenSaverChecked || monitorStandbyChecked), PreWarning
GuiControl, % "Disable" !(preWarningChecked && (screenSaverChecked || monitorStandbyChecked)), PreWarningSecondsEditDummy
GuiControl, % "Disable" useSystemScreenSaverChecked, ConfigButtonDummy
GuiControl, % "Disable" useSystemScreenSaverChecked, LVDummy

GuiControl, % "Disable" useSystemScreenSaverChecked, EnableCycleScreenSavers
GuiControl, % "Disable" (useSystemScreenSaverChecked || !EnableCycleScreenSaversChecked), CycleMinsEditDummy

GuiControlGet, monitorStandbyChecked,, enableMonitorStandby 
GuiControl, % "Disable" !monitorStandbyChecked, MonOffMinsEditDummy
return 


TestScreenSaver:
sleep 800
ConfigureScreenSaver:
LV_GetText(selectedScreenSaverPath, LV_GetNext(0), 2) ; only 1 row can be selected at a time. No rows can be selected too.
GuiControlGet, useSystemScreenSaverChecked,, useSystemScreenSaver 
startSleepyScreenSaver(useSystemScreenSaverChecked, selectedScreenSaverPath, A_ThisLabel = "ConfigureScreenSaver")
return 


GUIClose:
GUI, Destroy
return 

ReadSettings:
RegRead, enableMonitorStandby, HKEY_CURRENT_USER, Software\SleepyMonitor, EnableMonitorStandby
enableMonitorStandby := (ErrorLevel ? False : enableMonitorStandby)
RegRead, monOffMins, HKEY_CURRENT_USER, Software\SleepyMonitor, MonOffMins
monOffMins := (ErrorLevel ? 25 : monOffMins)
RegRead, enableScreenSaver, HKEY_CURRENT_USER, Software\SleepyMonitor, EnableScreenSaver
enableScreenSaver := (ErrorLevel ? False : enableScreenSaver)
RegRead, saverMins, HKEY_CURRENT_USER, Software\SleepyMonitor, SaverMins
saverMins := (ErrorLevel ? 15 : saverMins)
RegRead, EnableCycleScreenSavers, HKEY_CURRENT_USER, Software\SleepyMonitor, EnableCycleScreenSavers
EnableCycleScreenSavers := (ErrorLevel ? False : EnableCycleScreenSavers)
RegRead, CycleMins, HKEY_CURRENT_USER, Software\SleepyMonitor, CycleMins
CycleMins := (ErrorLevel ? 20 : CycleMins)
RegRead, useSystemScreenSaver, HKEY_CURRENT_USER, Software\SleepyMonitor, UseSystemScreenSaver
useSystemScreenSaver := (ErrorLevel ? true : useSystemScreenSaver)
RegRead, enabledScreenSaversFullPaths, HKEY_CURRENT_USER, Software\SleepyMonitor, enabledScreenSaversFullPaths
enabledScreenSaversFullPaths := (ErrorLevel ? "" : enabledScreenSaversFullPaths)
aEnabledScreenSaverPaths := strsplit(enabledScreenSaversFullPaths, "|")

RegRead, preWarning, HKEY_CURRENT_USER, Software\SleepyMonitor, PreWarning
preWarning := (ErrorLevel ? False : preWarning)
RegRead, preWarningSeconds, HKEY_CURRENT_USER, Software\SleepyMonitor, PreWarningSeconds
preWarningSeconds := (ErrorLevel ? 10 : preWarningSeconds)
RegRead, RunOnStartUp, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Run, SleepyMonitor
if (RunOnStartUp := !ErrorLevel) && RunOnStartUp != A_ScriptFullPath ; user Moved the script
	RegWrite, REG_SZ, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Run, SleepyMonitor, %A_ScriptFullPath%
calculateVars:
saverMS := saverMins * 60 * 1000
saverWarningMS := saverMS - preWarningSeconds * 1000
monOffMS := monOffMins * 60 * 1000
monOffWarningMS := monOffMS - preWarningSeconds * 1000
cycleMS := CycleMins * 60 * 1000

;preWarningSeconds := 5
;saverMS := 10 *1000
;cycleMS := 3 *1000
;monOffMS := 30 * 1000
;monOffWarningMS := monOffMS - preWarningSeconds * 1000
;saverWarningMS := saverMS - preWarningSeconds * 1000
return 

SaveSettings:
row := 0
enabledScreenSaversFullPaths := ""
while row := LV_GetNext(row, "Checked")
{
	LV_GetText(fullFilePath, row, 2)
	enabledScreenSaversFullPaths .= fullFilePath "|"
}
enabledScreenSaversFullPaths := RTrim(enabledScreenSaversFullPaths, "|")
aEnabledScreenSaverPaths := strsplit(enabledScreenSaversFullPaths, "|")
GUI, Submit
GUI, Destroy

ScreenSaverFile := aScreenSavers[ScreenSaverFile]
for k, varName in StrSplit("EnableMonitorStandby|MonOffMins|UseSystemScreenSaver|enabledScreenSaversFullPaths|EnableScreenSaver|SaverMins|EnableCycleScreenSavers|CycleMins|PreWarning|PreWarningSeconds", "|")
	RegWrite, REG_SZ, HKEY_CURRENT_USER, Software\SleepyMonitor, %varName%, % %varName%

if RunOnStartUp
	RegWrite, REG_SZ, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Run, SleepyMonitor, %A_ScriptFullPath%
else RegDelete, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Run, SleepyMonitor
Gosub, calculateVars
return 



; cos of 32 / 64 bit emulation of system32 folder (redirection to wow folder)

findInstalledScreenSavers(enabledScreenSaversFullPaths := "")
{
	aInstalledScreenSavers := []
	
	loop, %A_WinDir%\*.scr 
		aInstalledScreenSavers.insert({ fileName: A_LoopFileName, filePathFull: A_LoopFileLongPath, enabled: InStr(enabledScreenSaversFullPaths, A_LoopFileLongPath)})

	if (isWow64 := isWow64Process())
		prevWowValue := disableWow64FsRedirection()

	loop, %A_WinDir%\System32\*.scr 
		aInstalledScreenSavers.insert({ fileName: A_LoopFileName, filePathFull: A_LoopFileLongPath, enabled: InStr(enabledScreenSaversFullPaths, A_LoopFileLongPath)})

	if isWow64
		revertWow64FsRedirection(prevWowValue)

	loop, %A_ScriptDir%\Screensavers\*.scr 
		aInstalledScreenSavers.insert({ fileName: A_LoopFileName, filePathFull: A_LoopFileLongPath, enabled: InStr(enabledScreenSaversFullPaths, A_LoopFileLongPath)})

	return aInstalledScreenSavers
}


isWow64Process()
{
	DllCall("IsWow64Process", "Ptr", DllCall("GetCurrentProcess", "Ptr"), "Int*", Wow64Process)
	return Wow64Process
}

disableWow64FsRedirection(byref result := "")
{
	DllCall("Wow64DisableWow64FsRedirection", "Ptr*", prevWowValue)
	return prevWowValue
}

revertWow64FsRedirection(prevWowValue)
{
	return DllCall("Wow64RevertWow64FsRedirection", "Ptr*", prevWowValue)
}


; /c - Show the screensaver configuration dialog box
;/ s - Show the screensaver full-screen 

startSleepyScreenSaver(useSystemScreenSaver, screenSaverFilePath, config := false)
{
	if !useSystemScreenSaver
	{
		if InStr(screenSaverFilePath, A_WinDir "\System32\") && isWow64Process()
			prevWowValue := disableWow64FsRedirection()
		if FileExist(screenSaverFilePath)
			run, % screenSaverFilePath (config ? " /c" : " /s")
		else fileNotFound := true 
		if prevWowValue
			revertWow64FsRedirection(prevWowValue)
		if !fileNotFound || config
			return 
	}
	; useSystemScreenSaver or fileNotFound (backup)
	startSystemScreenSaver()
	return 
}

FileExistWOW64(file)
{
		if InStr(file, A_WinDir "\System32\") && isWow64Process()
			prevWowValue := disableWow64FsRedirection()
		return FileExist(file), prevWowValue ? revertWow64FsRedirection(prevWowValue) : ""
			
}

isScreenSaverRunning()
{
	; always check  isUsingSystemSystemScreenSaver() - in case OS started its own screenSaver
	return isSystemScreenSaverRunning() || InStr(proccessList(), ".scr|")
}

; If monitor is in standby/off returns false
; Only works if startSystemScreenSaver() is used to start screen saver
; not if the .scr file is launched via this script
isSystemScreenSaverRunning()
{
	return result, DllCall("SystemParametersInfo", "UInt", SPI_GETSCREENSAVERRUNNING := 0x0072, "UInt", 0, "UInt*", result, "UInt", 0)
}

startSystemScreenSaver()
{
	PostMessage, % WM_SYSCOMMAND := 0x0112, % SC_SCREENSAVE := 0xF140,,, % "ahk_id "  (HWND_BROADCAST := 0xFFFF)
}




/*
	SC_MONITORPOWER		0xF170

	Sets the state of the display. This command supports devices that have power-saving features, such as a battery-powered personal computer. 
	The lParam parameter can have the following values:
	-1 (the display is powering on)
	1 (the display is going to low power)
	2 (the display is being shut off)

	https://docs.microsoft.com/en-us/windows/desktop/menurc/wm-syscommand
*/
monitorStandby()
{
	SendMessage, % WM_SYSCOMMAND := 0x0112, SC_MONITORPOWER := 0xF170, 2,, Program Manager
}

; Masonjar13
WM_POWERBROADCAST(wParam, lParam)
{
    static PBT_POWERSETTINGCHANGE := 0x8013, PBT_APMRESUMESUSPEND := 0x7

    if (wParam = PBT_POWERSETTINGCHANGE && subStr(strGet(lParam), 1, strLen(strGet(lParam)) - 1) = strGet(&newGUID))
            isMonitorOn := numGet(lParam+0,20,"UInt") ? true : false 
    ; PBT_APMRESUMESUSPEND
    ; Computer has woken up as a response to user input. 
    ; Or the system has originally woken up automatically, but the user has just made an input
    if (wParam = PBT_APMRESUMESUSPEND)
    {
		; When the user wakes the computer up the screen saver will start (or monitor standby) if it was previously running as 
		; A_TimeIdle is still above the threashold - the user pressing a key to wake the computer doesn't reset this value
		; therefore move the mouse slightly to prevent this.
    	MouseMove, 1,0,, R
		MouseMove, -1,0,, R
    }

    return true 
}

randomArrayItem(array)
{
	random, i, % array.MinIndex(), % array.MaxIndex()
	return array[i]
}

OptionsGUITooltips()
{
	static CurrControl, PrevControl, _TT  ; _TT is kept blank for use by the ToolTip command below.

    CurrControl := A_GuiControl
    If (CurrControl != PrevControl && !InStr(CurrControl, " "))
    {
        ToolTip  ; Turn off any previous tooltip.
        SetTimer, DisplayToolTip, -400
        PrevControl := CurrControl
    }
    return

    DisplayToolTip:
    ;SetTimer, DisplayToolTip, Off
	Try	ToolTip % %CurrControl%_TT  ; try guards against illegal character error (when a controls text is passed as it doesn't have an associated variable)
	; Average reading words/minute = 250-300. 180 when proof reading on a monitor (so use this)
	; Average English word length is ~ 5 (could just use regex to find word count)
   	try displayTime := strlen(%CurrControl%_TT) / 5 / 180 * 60000
    SetTimer, RemoveToolTip, % -1 * (displayTime > 9000 ? displayTime : 9000)
    return

    RemoveToolTip:
    ToolTip
    return
}

proccessList(byref count := "")
{
	; Example #4: Retrieves a list of running processes via DllCall then shows them in a MsgBox.

	d := "|"  ; string separator
	s := 4096  ; size of buffers and arrays (4 KB)

	Process, Exist  ; sets ErrorLevel to the PID of this running script
	; Get the handle of this script with PROCESS_QUERY_INFORMATION (0x0400)
	h := DllCall("OpenProcess", "UInt", 0x0400, "Int", false, "UInt", ErrorLevel, "Ptr")
	; Open an adjustable access token with this process (TOKEN_ADJUST_PRIVILEGES = 32)
	DllCall("Advapi32.dll\OpenProcessToken", "Ptr", h, "UInt", 32, "PtrP", t)
	VarSetCapacity(ti, 16, 0)  ; structure of privileges
	NumPut(1, ti, 0, "UInt")  ; one entry in the privileges array...
	; Retrieves the locally unique identifier of the debug privilege:
	DllCall("Advapi32.dll\LookupPrivilegeValue", "Ptr", 0, "Str", "SeDebugPrivilege", "Int64P", luid)
	NumPut(luid, ti, 4, "Int64")
	NumPut(2, ti, 12, "UInt")  ; enable this privilege: SE_PRIVILEGE_ENABLED = 2
	; Update the privileges of this process with the new access token:
	r := DllCall("Advapi32.dll\AdjustTokenPrivileges", "Ptr", t, "Int", false, "Ptr", &ti, "UInt", 0, "Ptr", 0, "Ptr", 0)
	DllCall("CloseHandle", "Ptr", t)  ; close this access token handle to save memory
	DllCall("CloseHandle", "Ptr", h)  ; close this process handle to save memory

	hModule := DllCall("LoadLibrary", "Str", "Psapi.dll")  ; increase performance by preloading the library
	s := VarSetCapacity(a, s)  ; an array that receives the list of process identifiers:
	c := 0  ; counter for process idendifiers
	DllCall("Psapi.dll\EnumProcesses", "Ptr", &a, "UInt", s, "UIntP", r)
	Loop, % r // 4  ; parse array for identifiers as DWORDs (32 bits):
	{
	   id := NumGet(a, A_Index * 4, "UInt")
	   ; Open process with: PROCESS_VM_READ (0x0010) | PROCESS_QUERY_INFORMATION (0x0400)
	   h := DllCall("OpenProcess", "UInt", 0x0010 | 0x0400, "Int", false, "UInt", id, "Ptr")
	   if !h
	      continue
	   VarSetCapacity(n, s, 0)  ; a buffer that receives the base name of the module:
	   e := DllCall("Psapi.dll\GetModuleBaseName", "Ptr", h, "Ptr", 0, "Str", n, "UInt", A_IsUnicode ? s//2 : s)
	   if !e    ; fall-back method for 64-bit processes when in 32-bit mode:
	      if e := DllCall("Psapi.dll\GetProcessImageFileName", "Ptr", h, "Str", n, "UInt", A_IsUnicode ? s//2 : s)
	         SplitPath n, n
	   DllCall("CloseHandle", "Ptr", h)  ; close process handle to save memory
	   if (n && e)  ; if image is not null add to list:
	      l .= n . d, c++
	}
	DllCall("FreeLibrary", "Ptr", hModule)  ; unload the library to free memory
	;Sort, l, C  ; uncomment this line to sort the list alphabetically
	count := c
	return l
}
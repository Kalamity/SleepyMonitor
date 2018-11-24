#SingleInstance force
#Persistent
SetWorkingDir %A_ScriptDir%
version := "1.01"

global isMonitorOn := True ; on
global newGUID:= ""

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
SetTimer, IdleCheck, 4000

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
preWarning_TT := "A system alert sound is made before starting the screen saver or placing the monitor into standby.`nNote: No sound is made if the screen saver is already running."
preWarningSeconds_TT := PreWarningSecondsEditDummy_TT := "The alert will sound this many seconds before the screen saver starts or before the monitor is placed into standby."
enableMonitorStandby_TT := "Allows the monitor to be put into low-power/standby mode."
monOffMins_TT := MonOffMinsEditDummy_TT := "The monitor will be placed into low-power state after the user has been idle for this period of time."
return

ExitRoutine:
dllCall("UnregisterPowerSettingNotification", "Ptr", rhandle)
ExitApp
return 

IdleCheck:

if !isMonitorOn
	return 

if (enableScreenSaver)
{
	if (preWarning && A_TimeIdle >= saverWarningMS && !isScreenSaverRunning())
	{
		if waitForInput(preWarningSeconds + .250)
			return
	}

	if (A_TimeIdle >= saverMS && !isScreenSaverRunning())
	{
		startScreenSaver()
		sleep 5000 ; ensure screen saver has started before next idleCheck run - prevents second warning
	}
}


if (enableMonitorStandby)
{
	if (preWarning && A_TimeIdle >= monOffWarningMS && !isScreenSaverRunning())
	{
		if waitForInput(preWarningSeconds + .250)
			return
	}
	if (A_TimeIdle >= monOffMS)
	{
		monitorStandby()
		sleep 5000
	}
}
return 

waitForInput(timeOut)
{
	startIdle := A_TimeIdle
	soundplay *-1
	loop 
	{
		if (A_TimeIdle < startIdle)
			return true
		sleep 200
	} until (A_TimeIdle - startIdle >= timeOut * 1000)	
	return false
}


LaunchScreenSaver:
MonitorStandby:
sleep 2000
(A_ThisLabel = "LaunchScreenSaver") ? startScreenSaver() : monitorStandby()
return 

; returns true if still idle
warnCheckIsIdle(preWarningSeconds, idleThreashold)
{
	soundplay *-1
	sleep % preWarningSeconds * 1000 + 250
	return (A_TimeIdle / 60 / 1000 >= idleThreashold)
}


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
; when ever a checkmark is applied to these menu items

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
SetTimer, IdleCheck, 5000
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

Gui, Add, GroupBox,  y+20 w300 h60 section, Screen Saver 
Gui, Add, Checkbox, xs+15 yp+25 vEnableScreenSaver Checked%enableScreenSaver% gGUIControlHandler, Enable

			
Gui, Add, Text, xs+170 ys+25, Delay Mins:
Gui, Add, Edit, % "Number Right x+15 yp-2 w45 vSaverMinsEditDummy Disabled" !enableScreenSaver 
Gui, Add, UpDown,  Range1-1000 vSaverMins, %saverMins%	



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
Gui, Show, w320 h385
return

GUIControlHandler:
GuiControlGet, screenSaverChecked,, enableScreenSaver 
GuiControlGet, monitorStandbyChecked,, enableMonitorStandby 
GuiControlGet, preWarningChecked,, preWarning 
GuiControl, % "Disable" !screenSaverChecked, SaverMinsEditDummy
GuiControl, % "Disable" !(screenSaverChecked || monitorStandbyChecked), PreWarning
GuiControl, % "Disable" !(preWarningChecked && (screenSaverChecked || monitorStandbyChecked)), PreWarningSecondsEditDummy

GuiControlGet, monitorStandbyChecked,, enableMonitorStandby 
GuiControl, % "Disable" !monitorStandbyChecked, MonOffMinsEditDummy
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
return 

SaveSettings:
GUI, Submit
GUI, Destroy

for k, varName in StrSplit("EnableMonitorStandby|MonOffMins|EnableScreenSaver|SaverMins|PreWarning|PreWarningSeconds", "|")
	RegWrite, REG_SZ, HKEY_CURRENT_USER, Software\SleepyMonitor, %varName%, % %varName%

if RunOnStartUp
	RegWrite, REG_SZ, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Run, SleepyMonitor, %A_ScriptFullPath%
else RegDelete, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Run, SleepyMonitor
Gosub, calculateVars
return 





/*
	BOOL SystemParametersInfoA(
	  UINT  uiAction,
	  UINT  uiParam,
	  PVOID pvParam,
	  UINT  fWinIni
	);
*/
startScreenSaver()
{
	PostMessage, % WM_SYSCOMMAND := 0x0112, % SC_SCREENSAVE := 0xF140,,, % "ahk_id "  (HWND_BROADCAST := 0xFFFF)
}

; If monitor is in standby/off returns false
isScreenSaverRunning()
{
	return result, DllCall("SystemParametersInfo", "UInt", SPI_GETSCREENSAVERRUNNING := 0x0072, "UInt", 0, "UInt*", result, "UInt", 0)
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

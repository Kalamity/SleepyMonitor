; Currently when the computer resumes from sleep the script will
; quickly run the screen saver or place the monitor into standby
; as the user has still been idle.
; Perhaps should monitor resume power messages and reset idle time.
; Not sure if better to leave it the way it is now though.

#SingleInstance force
#Persistent
SetWorkingDir %A_ScriptDir%
version := "1.00"

global isMonitorOn := True ; on
global newGUID:= ""

FileCreateDir, %A_Temp%\SleepyMonitor 
FileInstall, Resources\Sleep.ico, %A_Temp%\SleepyMonitor\Sleep.ico, 1
Menu, Tray, Icon, %A_Temp%\SleepyMonitor\Sleep.ico, 1, 1

GUID_MONITOR_POWER_ON:="02731015-4510-4526-99e6-e5a17ebd1aea"
GUID_CONSOLE_DISPLAY_STATE:="6fe69556-704a-47a0-8f24-c28d936fda47"

varSetCapacity(newGUID,16,0)
if a_OSVersion in WIN_8,WIN_8.1,WIN_10
    dllCall("Rpcrt4\UuidFromString", "Str", GUID_CONSOLE_DISPLAY_STATE, "UInt", &newGUID)
else
    dllCall("Rpcrt4\UuidFromString", "Str", GUID_MONITOR_POWER_ON, "UInt", &newGUID)
rhandle := dllCall("RegisterPowerSettingNotification", "UInt", a_scriptHwnd, "Str", strGet(&newGUID), "Int", 0, "Ptr")
onMessage(0x218, "WM_POWERBROADCAST")


gosub, ReadSettings

SetTimer, IdleCheck, 5000

Menu, tray, NoStandard
Menu, tray, add  ; Creates a separator line.
Menu, tray, add, Settings, SettingsGUI ; label cant have spaces
Menu, tray, Default, Settings 
Menu, tray, add
Menu, tray, add, Monitor Standby, MonitorStandby 
Menu, tray, add  
Menu, tray, add, Screen Saver, LaunchScreenSaver 

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
preWarning_TT := "A system alert sound is made before starting the screen saver.`nThe delay setting is adjustable."
preWarningSeconds_TT := PreWarningSecondsEditDummy_TT := "The alert will sound this many seconds before the screen saver starts."
enableMonitorStandby_TT := "Allows the monitor to be put into low-power/standby mode."
monOffMins_TT := MonOffMinsEditDummy_TT := "The monitor will be placed into low-power state after the user has been idle for this period of time."

return

ExitRoutine:
dllCall("UnregisterPowerSettingNotification", "Ptr", rhandle)
ExitApp
return 

IdleCheck:
if (A_TimeIdle / 60 / 1000 >= saverMins && isMonitorOn && !isScreenSaverRunning())
{
	if (preWarning)
	{
		sleep % preWarningSeconds * 1000
		if (A_TimeIdle / 60 / 1000 <= saverMins) 
			return
	}
	startScreenSaver()
}

if (A_TimeIdle / 60 / 1000 >= monOffMins && isMonitorOn)
	monitorStandby()

return

LaunchScreenSaver:
MonitorStandby:
sleep 2000
(A_ThisLabel = "LaunchScreenSaver") ? startScreenSaver() : monitorStandby()
return 


DisableUntilAppRestart:

; isDisabledUntilRestart is true when a checkmark is on this menu item 


if isDisabledUntilRestart := !isDisabledUntilRestart
{
	Menu, DisableSubMenu, Check, Until Restart
	settimer, reenableMonitoring, off
	SetTimer, UpdateTimeRemaing, Off
	settimer, IdleCheck, off
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

; If clicks item with was previously clicked (and it hasn't expired)
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

Gui, Add, GroupBox,  y+20 w300 h120 section, Screen Saver 
Gui, Add, Checkbox, xs+15 yp+25 vEnableScreenSaver Checked%enableScreenSaver% gGUIControlHandler, Enable

			
Gui, Add, Text, xs+170 ys+25, Delay Mins:
Gui, Add, Edit, % "Number Right x+15 yp-2 w45 vSaverMinsEditDummy Disabled" !enableScreenSaver 
Gui, Add, UpDown,  Range0-1000 vsaverMins, %saverMins%	

Gui, Add, Checkbox, % "xs+15 y+30 vPreWarning Checked" preWarning " gGUIControlHandler Disabled" !enableScreenSaver, Enable warning
Gui, Add, Text, xs+170 yp, Delay Secs:
Gui, Add, Edit, % "Number Right x+15 yp-2 w45 vPreWarningSecondsEditDummy Disabled" (!preWarning || !enableScreenSaver)
Gui, Add, UpDown,  Range0-1000 vPreWarningSeconds, %preWarningSeconds%

Gui, Add, GroupBox, xs  y+35 w300 h60 section, Screen Standby
Gui, Add, Checkbox, xs+15 yp+25 vEnableMonitorStandby Checked%enableMonitorStandby% gGUIControlHandler, Enable
Gui, Add, Text, xs+170 ys+25, Delay Mins:
Gui, Add, Edit, % "Number Right x+15 yp-2 w45 vMonOffMinsEditDummy Disabled" !enableMonitorStandby
Gui, Add, UpDown,  Range0-1000 vMonOffMins, %monOffMins%	

Gui, Add, GroupBox, xs  y+35 w300 h55 section, Misc
Gui, Add, Checkbox, xs+15 yp+25 vRunOnStartUp Checked%RunOnStartUp%, Run on startup
Gui, add, button, xs ys+85 w54 h25 gSaveSettings, Save
Gui, add, button, x+40 yp w54 h25 gGUIClose, Cancel
OnMessage(0x200, "OptionsGUITooltips")
Gui, Show, w320 h350

return

GUIControlHandler:
GuiControlGet, screenSaverChecked,, enableScreenSaver 
GuiControlGet, preWarningChecked,, preWarning 
GuiControl, % "Disable" !screenSaverChecked, SaverMinsEditDummy
GuiControl, % "Disable" !screenSaverChecked, PreWarning
GuiControl, % "Disable" !(preWarningChecked && screenSaverChecked), PreWarningSecondsEditDummy

GuiControlGet, monitorStandbyChecked,, enableMonitorStandby 
GuiControl, % "Disable" !monitorStandbyChecked, MonOffMinsEditDummy
return 


GUIClose:
GUI, Destroy
return 

ReadSettings:
RegRead, enableMonitorStandby, HKEY_CURRENT_USER, Software\SleepyMonitor, enableMonitorStandby
enableMonitorStandby := (ErrorLevel ? False : enableMonitorStandby)
RegRead, monOffMins, HKEY_CURRENT_USER, Software\SleepyMonitor, monOffMins
monOffMins := (ErrorLevel ? 25 : monOffMins)
RegRead, enableScreenSaver, HKEY_CURRENT_USER, Software\SleepyMonitor, enableScreenSaver
enableScreenSaver := (ErrorLevel ? False : enableScreenSaver)
RegRead, saverMins, HKEY_CURRENT_USER, Software\SleepyMonitor, saverMins
saverMins := (ErrorLevel ? 15 : saverMins)
RegRead, preWarning, HKEY_CURRENT_USER, Software\SleepyMonitor, preWarning
preWarning := (ErrorLevel ? False : preWarning)
RegRead, preWarningSeconds, HKEY_CURRENT_USER, Software\SleepyMonitor, preWarningSeconds
preWarningSeconds := (ErrorLevel ? 10 : preWarningSeconds)
RegRead, RunOnStartUp, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Run, SleepyMonitor
if ErrorLevel
	RunOnStartUp := false 
else 
{
	if (A_ScriptFullPath != RunOnStartUp) 	; user Moved the script
		RegWrite, REG_SZ, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Run, SleepyMonitor, %A_ScriptFullPath%
	RunOnStartUp := true
}
return 

SaveSettings:
GUI, Submit
GUI, Destroy
RegWrite, REG_SZ, HKEY_CURRENT_USER, Software\SleepyMonitor, EnableMonitorStandby, %enableMonitorStandby%
RegWrite, REG_SZ, HKEY_CURRENT_USER, Software\SleepyMonitor, MonOffMins, %monOffMins%
RegWrite, REG_SZ, HKEY_CURRENT_USER, Software\SleepyMonitor, EnableScreenSaver, %enableScreenSaver%
RegWrite, REG_SZ, HKEY_CURRENT_USER, Software\SleepyMonitor, SaverMins, %saverMins%
RegWrite, REG_SZ, HKEY_CURRENT_USER, Software\SleepyMonitor, PreWarning, %preWarning%
RegWrite, REG_SZ, HKEY_CURRENT_USER, Software\SleepyMonitor, preWarningSeconds, %preWarningSeconds%

if RunOnStartUp
	RegWrite, REG_SZ, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Run, SleepyMonitor, %A_ScriptFullPath%
else RegDelete, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Run, SleepyMonitor
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
WM_POWERBROADCAST(wParam,lParam)
{
    static PBT_POWERSETTINGCHANGE := 0x8013
    soundplay *64
    if (wParam = PBT_POWERSETTINGCHANGE && subStr(strGet(lParam), 1, strLen(strGet(lParam)) - 1) = strGet(&newGUID))
            isMonitorOn := numGet(lParam+0,20,"UInt") ? true : false 
    return
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

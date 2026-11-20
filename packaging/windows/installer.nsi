; NSIS installer for WorkChat. Build: makensis /DVERSION=1.1.0 packaging/windows/installer.nsi
!include "MUI2.nsh"

Name "WorkChat"
OutFile "..\..\dist\WorkChat-${VERSION}-windows-x64-setup.exe"
InstallDir "$LOCALAPPDATA\Programs\WorkChat"
RequestExecutionLevel user

!define MUI_ICON "..\..\assets\icon\workchat.ico"
!define MUI_UNICON "..\..\assets\icon\workchat.ico"

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Install"
  SetOutPath "$INSTDIR"
  File /r "..\..\app\build\windows\x64\runner\Release\*.*"
  File "..\..\assets\icon\workchat.ico"
  
  WriteUninstaller "$INSTDIR\uninstall.exe"
  CreateShortcut "$SMPROGRAMS\WorkChat.lnk" "$INSTDIR\workchat.exe" "" "$INSTDIR\workchat.ico"
  CreateShortcut "$DESKTOP\WorkChat.lnk" "$INSTDIR\workchat.exe" "" "$INSTDIR\workchat.ico"
  
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\WorkChat" "DisplayName" "WorkChat"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\WorkChat" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\WorkChat" "DisplayIcon" "$INSTDIR\workchat.ico"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\WorkChat" "UninstallString" "$INSTDIR\uninstall.exe"

  ; URL protocol handler workchat://
  WriteRegStr HKCU "Software\Classes\workchat" "" "URL:WorkChat Protocol"
  WriteRegStr HKCU "Software\Classes\workchat" "URL Protocol" ""
  WriteRegStr HKCU "Software\Classes\workchat\DefaultIcon" "" "$INSTDIR\workchat.ico"
  WriteRegStr HKCU "Software\Classes\workchat\shell\open\command" "" '"$INSTDIR\workchat.exe" "%1"'
SectionEnd

Section "Uninstall"
  RMDir /r "$INSTDIR"
  Delete "$SMPROGRAMS\WorkChat.lnk"
  Delete "$DESKTOP\WorkChat.lnk"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\WorkChat"
  DeleteRegKey HKCU "Software\Classes\workchat"
SectionEnd

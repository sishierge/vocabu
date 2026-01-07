; Vocabu Installer Script for Inno Setup
; 使用方法: 用 Inno Setup 打开此文件并编译

#define MyAppName "Vocabu"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Vocabu Team"
#define MyAppExeName "vocabu.exe"
#define MyAppDescription "智能英语学习助手"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppVerName={#MyAppName} {#MyAppVersion}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=installer_output
OutputBaseFilename=Vocabu_Setup_{#MyAppVersion}
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\{#MyAppExeName}
LicenseFile=
InfoBeforeFile=

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
; 添加所有扩展插件 (从 installer_output/extracted 目录)
Source: "installer_output\extracted\DanmuOverlay.exe"; DestDir: "{app}\plugins"; Flags: ignoreversion
Source: "installer_output\extracted\DanmuOverlay.dll"; DestDir: "{app}\plugins"; Flags: ignoreversion
Source: "installer_output\extracted\DanmuOverlay.deps.json"; DestDir: "{app}\plugins"; Flags: ignoreversion
Source: "installer_output\extracted\DanmuOverlay.runtimeconfig.json"; DestDir: "{app}\plugins"; Flags: ignoreversion
Source: "installer_output\extracted\CarouselOverlay.exe"; DestDir: "{app}\plugins"; Flags: ignoreversion
Source: "installer_output\extracted\CarouselOverlay.dll"; DestDir: "{app}\plugins"; Flags: ignoreversion
Source: "installer_output\extracted\CarouselOverlay.deps.json"; DestDir: "{app}\plugins"; Flags: ignoreversion
Source: "installer_output\extracted\CarouselOverlay.runtimeconfig.json"; DestDir: "{app}\plugins"; Flags: ignoreversion
Source: "installer_output\extracted\StickyOverlay.exe"; DestDir: "{app}\plugins"; Flags: ignoreversion
Source: "installer_output\extracted\StickyOverlay.dll"; DestDir: "{app}\plugins"; Flags: ignoreversion
Source: "installer_output\extracted\StickyOverlay.deps.json"; DestDir: "{app}\plugins"; Flags: ignoreversion
Source: "installer_output\extracted\StickyOverlay.runtimeconfig.json"; DestDir: "{app}\plugins"; Flags: ignoreversion
Source: "installer_output\extracted\Newtonsoft.Json.dll"; DestDir: "{app}\plugins"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// 卸载时询问是否删除用户数据
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    if MsgBox('是否删除用户数据和学习记录?', mbConfirmation, MB_YESNO) = IDYES then
    begin
      DelTree(ExpandConstant('{userappdata}\vocabu'), True, True, True);
    end;
  end;
end;

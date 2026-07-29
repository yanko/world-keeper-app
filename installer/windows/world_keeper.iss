; World Keeper — Windows installer (Inno Setup 6).
;
; Not invoked directly. `installer\windows\build.ps1` builds the app, stages the Visual
; C++ runtime beside it, reads the version out of pubspec.yaml and passes it in here.
;
;   powershell -File installer\windows\build.ps1
;
; Why Inno rather than MSIX: an MSIX will not install at all without a certificate the
; machine already trusts, so an unsigned one means talking the user through importing a
; self-signed cert into the Trusted People store before they can even try the app. An
; unsigned Inno installer just shows the SmartScreen prompt, which is the same thing the
; Tauri build has always shown.

#ifndef AppVersion
  #error AppVersion must be passed in: ISCC /DAppVersion=1.0.0 ...
#endif
#ifndef ProjectDir
  #error ProjectDir must be passed in: ISCC /DProjectDir=<absolute path to flutter\>
#endif

#define AppName "World Keeper"
#define AppPublisher "Civortech"
#define AppExeName "world_keeper.exe"

#define BuildDir ProjectDir + "\build\windows\x64\runner\Release"
#define OutDir ProjectDir + "\installer\out"

[Setup]
; Never change this. It is the identity Windows matches an upgrade against; a new GUID
; makes the next version install *alongside* this one instead of over it.
AppId={{8F3C1D6A-2B94-4E5F-9A17-6C0D5E8B4A21}

AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
VersionInfoVersion={#AppVersion}

; Per-user by default, so there is no UAC prompt on top of the SmartScreen one. An
; unsigned installer that also demands administrator is a lot to ask of someone trying
; the app for the first time. `dialog` still lets an admin pick machine-wide.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes

; Flutter's Windows embedder is x64-only.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Windows 10 1809 is the floor: below it the app is on its own for the Segoe UI Variable
; and DirectComposition paths the embedder uses.
MinVersion=10.0.17763

OutputDir={#OutDir}
OutputBaseFilename=WorldKeeper-{#AppVersion}-windows-x64-setup
SetupIconFile={#ProjectDir}\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}

WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
; Nothing here is worth a wizard page of its own — the only real choice is the desktop
; shortcut, and that fits on the ready page.
DisableWelcomePage=yes
LicenseFile=

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
; The app itself ships English and French, so the installer should not be the one part
; of it that refuses to speak French.
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; The whole build output, recursively: the exe, `flutter_windows.dll`, every plugin DLL,
; the `data\` directory holding the AOT snapshot and ICU data, and the Visual C++ runtime
; that build.ps1 staged in. Listing them individually would mean a broken installer every
; time a plugin is added.
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Deliberately empty.
;
; The app's config, generated SSH keys and audit database live in
; `%APPDATA%\com.civortech.worldkeeper`, which is *shared with the Tauri build of World
; Keeper* — that sharing is the whole reason the Flutter app reproduces Tauri's path
; resolution. Removing it here would silently destroy the other app's setup as a side
; effect of uninstalling this one. It also holds the audit log, which is the record of
; what was done to a live game server; a log an uninstaller can erase is not a log.

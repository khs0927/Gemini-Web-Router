Dim WshShell, fso, scriptDir, ensureScript, psExe
Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
psExe = WshShell.ExpandEnvironmentStrings("%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe")
ensureScript = fso.BuildPath(scriptDir, "ensure-router.ps1")

If fso.FileExists(psExe) And fso.FileExists(ensureScript) Then
    WshShell.CurrentDirectory = scriptDir
    WshShell.Run """" & psExe & """ -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ensureScript & """", 0, False
End If

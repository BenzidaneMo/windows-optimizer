' Auto-elevating VBS that opens the optimizer window (optimizer-gui.ps1) as Administrator,
' with no console window behind it

If Not WScript.Arguments.Named.Exists("elevated") Then
    ' Relaunch the script with admin privileges
    Set shell = CreateObject("Shell.Application")
    shell.ShellExecute "wscript.exe", Chr(34) & _
        WScript.ScriptFullName & Chr(34) & " /elevated", "", "runas", 1
    WScript.Quit
End If

' Now start the window from the same folder, with PowerShell's console hidden (window style 0)
Dim scriptPath
scriptPath = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)

Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & _
    Chr(34) & scriptPath & "\optimizer-gui.ps1" & Chr(34), 0
Set WshShell = Nothing

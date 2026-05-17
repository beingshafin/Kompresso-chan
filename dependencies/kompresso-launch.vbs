' kompresso-launch.vbs
' Silently launches Kompresso-chan context wrapper

Set objShell = CreateObject("WScript.Shell")

' Get the target path from command line arguments
targetPath = WScript.Arguments(0)

' Build the PowerShell command with proper escaping
psCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""C:\Program Files\Kompresso-chan\kompresso-context-wrapper.ps1"" """ & targetPath & """"

' Run with window style 0 (hidden) and async execution (False = do not wait)
objShell.Run psCommand, 0, False

' Clean up
Set objShell = Nothing

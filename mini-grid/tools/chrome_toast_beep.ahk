#NoTrayIcon
#Persistent
SetTitleMatchMode, 2
SoundFile := A_WinDir "\Media\Windows Notify.wav"
Loop {
    ; Wait up to 10 minutes for any Windows toast window
    WinWait, ahk_class Windows.UI.Core.CoreWindow,, 600000
    WinGetTitle, t, ahk_class Windows.UI.Core.CoreWindow
    ; Filter toasts coming from Google Chrome
    if InStr(t, "Google Chrome") {
        if FileExist(SoundFile)
            SoundPlay, %SoundFile%
        else
            SoundBeep, 900, 150
        Sleep, 500
    }
}

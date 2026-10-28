-- Compiled by install_godot_updater_app.sh. The Python updater is bundled in Resources.
on run
    set updaterPath to POSIX path of (path to resource "update_godot.py")
    set updater to "/usr/bin/python3 " & quoted form of updaterPath
    set checkText to ""
    try
        with timeout of 120 seconds
            set checkText to do shell script updater
        end timeout
        set checkText to my replaceText(checkText, "Run again with --install to install it.", "")
    on error errorMessage
        set checkText to "Could not check for updates: " & errorMessage & return & return & "You can still restore a saved version."
    end try

    try
        set choice to button returned of (display dialog checkText & return & return & "This updates the Mono editor only. The project remains pinned to 4.7.1; web and iOS export tools are separate." buttons {"Close", "Roll Back", "Update"} default button "Close" with title "Godot Updater")
        if choice is "Update" then
            set progress total steps to 1
            set progress completed steps to 0
            set progress description to "Updating Godot"
            set progress additional description to "Downloading and verifying the editor. This may take a few minutes."
            try
                with timeout of 1800 seconds
                    set resultText to do shell script updater & " --install 2>&1"
                end timeout
                set progress completed steps to 1
                display dialog resultText buttons {"OK"} default button "OK" with title "Godot Updater"
            on error errorMessage number errorNumber
                set progress total steps to 0
                display dialog "Update failed:" & return & errorMessage buttons {"OK"} default button "OK" with icon stop with title "Godot Updater"
            end try
        else if choice is "Roll Back" then
            my restoreBackup(updater)
        end if
    on error errorMessage number errorNumber
        if errorNumber is not -128 then display dialog errorMessage buttons {"OK"} default button "OK" with icon stop with title "Godot Updater"
    end try
end run

on restoreBackup(updater)
    set backupJSON to do shell script updater & " --list-backups"
    set converter to "import json,sys; d=json.loads(sys.argv[1]); print('\\n'.join(x['version'] + ' | ' + x['path'] for x in d))"
    set backupText to do shell script "/usr/bin/python3 -c " & quoted form of converter & " " & quoted form of backupJSON
    if backupText is "" then
        display dialog "No saved Godot versions were found. A backup is created when you update with this app." buttons {"OK"} default button "OK" with title "Godot Updater"
        return
    end if
    set selected to choose from list paragraphs of backupText with title "Roll back Godot" with prompt "Choose a saved version to restore. The current app will also be saved as a backup." OK button name "Continue" cancel button name "Cancel"
    if selected is false then return
    set oldDelimiters to AppleScript's text item delimiters
    set AppleScript's text item delimiters to " | "
    set backupPath to text item 2 of (item 1 of selected)
    set AppleScript's text item delimiters to oldDelimiters
    set answer to button returned of (display dialog "Restore this saved editor?" & return & return & item 1 of selected & return & return & "Quit Godot first. The current editor will be kept as a backup." buttons {"Cancel", "Restore"} default button "Cancel" with title "Godot Updater")
    if answer is "Restore" then
        with timeout of 300 seconds
            set resultText to do shell script updater & " --rollback " & quoted form of backupPath & " 2>&1"
        end timeout
        display dialog resultText buttons {"OK"} default button "OK" with title "Godot Updater"
    end if
end restoreBackup

on replaceText(sourceText, searchText, replacementText)
    set oldDelimiters to AppleScript's text item delimiters
    set AppleScript's text item delimiters to searchText
    set pieces to text items of sourceText
    set AppleScript's text item delimiters to replacementText
    set resultText to pieces as text
    set AppleScript's text item delimiters to oldDelimiters
    return resultText
end replaceText

--
--  AppDelegate.applescript
--  DisplayPlaylist
--
--  Created by Christian Seyb on 30.01.14.
--  Copyright (c) 2014 Christian Seyb. All rights reserved.
--

script AppDelegate
	property parent : class "NSObject"
    
    --
    -- Define variables for Popup's and the descriptions for it
    --
    property systemNameLocalisation: missing value
    property systemNamePopup: missing value
    property advertisingLocalisation: missing value
    property advertisingPopup: missing value
    property currentPlayerLocalisation: missing value
    property currentPlayerDisplayedPopup: missing value
    --
    -- The Value of the following variables can be changed in the ~/.DisplayPlaylist file
    -- systemNameLocalisationDefault, advertisingLocalisationDefault and currentPlayerLocalisationDefault are just localization variables.
    --
    -- systemName, hostName, hostUser and hostPasswd are used to mount the odroid/raspi system to the Mac
    --
    -- advertising and musicPlayer have an effect on the behaviour of the program.
    --
    property systemNameLocalisationDefault: "Anzeigemodus"
    property advertisingLocalisationDefault: "Werbung"
    property currentPlayerLocalisationDefault: "Music Player"
    --
    property systemName : "Odroid" -- "RaspberryPi", "RaspberryPi2", "Odroid" or "LocalMac"
    property hostName : "odroid"
    property hostUser : "odroid"
    property hostPasswd : "XXyyZZ00"
    --
    property advertising : "Advertising" -- "Off", "Advertising", "Video" or "Clock"
    property musicPlayer : "Decibel" -- "Decibel" or "iTunes"
    --
    -- Global variables needed by various subroutines
    --
    property processID : 0
    property displayPlaylistLog : ""
    property signalDisplayPlaylist : ""
    property killDisplayPlaylist : ""
    
    on readPlaylistDecibel()
        tell application "Decibel"
            launch
            set cTitle to {}
            set cArtist to {}
            set cGenre to {}
            set cRunning to {}
            set lastRunning to {}
            set readSuccess to false
            set playingStatus to false
            try
                if (not exists nowPlaying) then -- Player does not contain usefull information yet
                   return {cRunning, cTitle, cArtist, cGenre, lastRunning, playingStatus, readSuccess}
                end if
                set lastRunning to id of nowPlaying & artist of nowPlaying & title of nowPlaying & genre of nowPlaying
                repeat with i from 1 to the count of tracks
                    if (title of track i is missing value) then
                        set end of cTitle to "Unbekannter Titel"
                    else
                        set end of cTitle to title of track i
                    end if
                    if (artist of track i is missing value) then
                        set end of cArtist to "Unbekanntes Orchester"
                    else
                        set end of cArtist to artist of track i
                    end if
                    if (genre of track i is missing value) then
                        set end of cGenre to "Cortina"
                    else
                        set end of cGenre to genre of track i
                    end if
                    set currentIdTag to id of track i & artist of track i & title of track i & genre of track i
                    if (playing and (currentIdTag = lastRunning)) then
                        set end of cRunning to "Playing"
                        set playingStatus to true
                    else if (currentIdTag = lastRunning) then
                        set end of cRunning to "Stopped"
                    else
                        set end of cRunning to "False"
                    end if
                    set i to i + 1
                end repeat
                    set readSuccess to true
                    return {cRunning, cTitle, cArtist, cGenre, lastRunning, playingStatus, readSuccess}
            on error
                return {cRunning, cTitle, cArtist, cGenre, lastRunning, playingStatus, readSuccess}
            end try
        end tell
    end readPlaylistDecibel
    
    on readPlaylistiTunes()
        tell application "iTunes"
            launch
            set cTitle to {}
            set cArtist to {}
            set cGenre to {}
            set cRunning to {}
            set lastRunning to {}
            set playingStatus to false
            set readSuccess to false
            if (not (exists (name of current playlist))) then -- Player does not contain usefull information yet
                return {cRunning, cTitle, cArtist, cGenre, lastRunning, playingStatus, readSuccess}
            end if
            try
                set lastRunning to (id of current track as string) & artist of current track & name of current track & genre of current track
                repeat with i from 1 to the count of tracks in current playlist
                    if (name of track i of current playlist is missing value) then
                        set end of cTitle to "Unbekannter Titel"
                    else
                        set end of cTitle to name of track i of current playlist
                    end if
                    if (artist of track i of current playlist is missing value) then
                        set end of cArtist to "Unbekanntes Orchester"
                    else
                        set end of cArtist to artist of track i of current playlist
                    end if
                    if (genre of track i of current playlist is missing value) then
                        set end of cGenre to "Cortina"
                    else
                        set end of cGenre to genre of track i of current playlist
                    end if
                    set currentIdTag to (id of track i of current playlist as string) & artist of track i of current playlist & name of track i of current playlist & genre of track i of current playlist
                    if ((player state is playing) and (currentIdTag = lastRunning)) then
                        set end of cRunning to "Playing"
                        set playingStatus to true
                    else if (currentIdTag = lastRunning) then
                        set end of cRunning to "Stopped"
                    else
                        set end of cRunning to "False"
                    end if
                    set i to i + 1
                end repeat
                set readSuccess to true
                return {cRunning, cTitle, cArtist, cGenre, lastRunning, playingStatus, readSuccess}
            on error
                return {cRunning, cTitle, cArtist, cGenre, lastRunning, playingStatus, readSuccess}
            end try
        end tell
    end readPlaylistiTunes
    
    on writePlaylist(playlistProperties, typeOfLog)
        set cPlaying to item 1 of playlistProperties
        set cTitle to item 2 of playlistProperties
        set cArtist to item 3 of playlistProperties
        set cGenre to item 4 of playlistProperties
        set cropAt to 27 -- Limit string, if cTitle or cArtist is more than cropAt
        --
        -- Wait for "Perl.lock" to go away. Set by "DisplayPlaylist.pl" on Raspi or LocalMac to signal, that it is
        -- currently processing "DisplayPlaylist.log". Gets deleted by "DisplayPlaylist.pl" after processing is completed.
        --
        -- Touch the "Apple.lock" file to signal DisplayPlaylist.pl on Raspi or LocalMac, that DisplayPlaylist.app is
        -- currently creating a new DisplayPlaylist.log file.
        --
        do shell script signalDisplayPlaylist & " " & "Perl.lock" & " " & "wait" & " " & systemName
        do shell script signalDisplayPlaylist & " " & "Apple.lock" & " " & "touch" & " " & systemName -- Touch Apple.lock file
        if (typeOfLog = "Logfile") then
            tell application "System Events"
                try -- Open displayPlaylistLog File and write the current Playlist to it
                    set logFile to (open for access file (displayPlaylistLog) with write permission)
                    set eof of logFile to 0
                on error
                    close access logFile
                end try
                repeat with i from 1 to count of cPlaying
                    set theArtist to item i of cArtist
                    set theTitle to item i of cTitle
                    if ((count of theArtist + count of theTitle) is greater than 2 * cropAt) then
                        if ((count of theTitle) is greater than cropAt) then
                            set theTitle to text 1 thru cropAt of theTitle
                        end if
                    end if
                    if ((count of theArtist + count theTitle) is greater than 2 * cropAt) then
                        if ((count of theArtist) is greater than cropAt) then
                            set theArtist to text 1 thru cropAt of theArtist
                        end if
                    end if
                    set ThisTrack to item i of cPlaying & " - " & theArtist & " - " & theTitle & " - " & item i of cGenre & linefeed
                    try
                        write ThisTrack to logFile
                    on error
                        close access logFile
                    end try
                    set i to i + 1
                end repeat
                close access logFile
            end tell
        end if
        --
        -- Write "HtmFile" or "Logfile" to "ProcessLogFile" and delete the "Apple.lock" file. DisplayPlaylist.pl on Raspi
        -- or LocalMac waits for the deletion of "Apple.lock", then waits for "ProcessLogFile" to appear and either converts
        -- "DisplayPlaylist.log" to "DisplayPlaylist.htm" or copies "HtmFile.htm" to "DisplayPlaylist.htm" and signals the
        -- browser to reload the current page.
        --
        do shell script signalDisplayPlaylist & " " & "ProcessLogFile" & " " & typeOfLog & " " & systemName
        do shell script signalDisplayPlaylist & " " & "Apple.lock" & " " & "unlink" & " " & systemName
    end writePlaylist
    
    on mountHomeDir()
        --
        -- Wait until RaspberryPi or Odroid "Home Directory" is mounted, Needs to
        -- be excecuted on startup, but also after Mac wakes up from sleep mode.
        --
        -- Will NOT return unless "Home Directory" can be mounted successfully.
        --
        if (systemName is not equal to "LocalMac") then
            set mounted to false
            repeat while (mounted is equal to false)
                set mounted_Disks to list disks
                if mounted_Disks does not contain "Home Directory" then
                    mount volume "afp://" & hostName as user name hostUser with password hostPasswd
                    set mounted_Disks to list disks
                    if mounted_Disks does not contain "Home Directory" then
                        --
                        -- Mounting of Home Directory failed - wait for some seconds for the next try
                        --
                        delay 5
                    else
                        set mounted to true
                        exit repeat
                    end if
                else
                    set mounted to true
                    exit repeat
                end if
            end repeat
        end if
    end mountHomeDir
    
    on setupEnvironment()
        --
        -- These are the configurable Items either preset or read from the
        -- preferences file ~/.DisplayPlaylist
        --
        set homeFolder to path to home folder as string
        set posixhomeFolder to POSIX path of homeFolder
        set myPrefsFile to homeFolder & ".DisplayPlaylist"
        try
            alias myPrefsFile
            set existsMyPrefsFile to true
        on error
            set existsMyPrefsFile to false
        end try
        if (existsMyPrefsFile) then
            set prefsContents to (do shell script "cat " & quoted form of (POSIX path of myPrefsFile))
            set myPrefsLines to paragraphs of prefsContents
            repeat with i from 1 to count of myPrefsLines
                set prefsValue to ""
                if ((character 1 of item i of myPrefsLines) is not equal to "#") then -- Skip lines starting with #
                    if ((item 2 of words of item i of myPrefsLines) is equal to "=") then -- the second word needs to be "="
                        repeat with j from 2 to count of words of item i of myPrefsLines
                            if (j ≤ 2) then
                                set prefsItem to item 1 of words of item i of myPrefsLines
                            else
                                set prefsValue to prefsValue & item j of words of item i of myPrefsLines & " "
                            end if
                        end repeat
                    end if
                    set prefsValue to text 1 thru ((count of prefsValue) - 1) of prefsValue -- Chop the last space character
                    if (prefsItem = "systemName") then
                        set systemName to prefsValue
                    else if (prefsItem = "hostName") then
                            set hostName to prefsValue
                    else if (prefsItem = "hostPasswd") then
                        set hostPasswd to prefsValue
                    else if (prefsItem = "hostUser") then
                        set hostUser to prefsValue
                    else if (prefsItem = "systemNameLocalisationDefault") then
                        set systemNameLocalisationDefault to prefsValue
                    else if (prefsItem = "advertisingLocalisationDefault") then
                        set advertisingLocalisationDefault to prefsValue
                    else if (prefsItem = "currentPlayerLocalisationDefault") then
                        set currentPlayerLocalisationDefault to prefsValue
                    else if (prefsItem = "advertising") then
                        set advertising to prefsValue
                    else if (prefsItem = "musicPlayer") then
                        set musicPlayer to prefsValue
                    end if
                end if
            end repeat
        end if
        --
        -- Set PerlInterpreter, displayPlaylistLog and SignalDisplayPlaylist.pl to the right location
        --
        set perlInterpreter to do shell script "which perl"
        if (systemName is not equal to "LocalMac") then
            --
            -- Mount the raspi/Odroid Home Directory
            --
            mountHomeDir()
            set displayPlaylistLog to "Home Directory:Downloads:DisplayPlaylist:DisplayPlaylist.log"
            set signalDisplayPlaylist to perlInterpreter & " " & "\"/Volumes/Home Directory/Downloads/DisplayPlaylist/SignalDisplayPlaylist.pl\""
        else
            --
            -- systemName is "LocalMac"
            --
            set displayPlaylistHomeDir to "CloudStation:Programme:DisplayPlaylist"
            set posixdisplayPlaylistHomeDir to POSIX path of displayPlaylistHomeDir
            -- Trim first "/" character
            set posixdisplayPlaylistHomeDir to text 2 thru end of posixdisplayPlaylistHomeDir
            set displayPlaylistLog to homeFolder & displayPlaylistHomeDir & ":DisplayPlaylist.log"
            set signalDisplayPlaylist to perlInterpreter & " " & "\"" & posixhomeFolder & posixdisplayPlaylistHomeDir & "/SignalDisplayPlaylist.pl\""
            --
            -- "do shell script killDisplayPlaylist" kills all running "DisplayPlaylist.pl LocalMac" scripts
            --
            set killDisplayPlaylist to perlInterpreter & " \"" & posixhomeFolder & posixdisplayPlaylistHomeDir & "/KillDisplayPlaylist.pl\""
            --
            -- Start "DisplayPlaylist.pl" on the "LocalMac"
            --
            set displayPlaylistPl to perlInterpreter & " \"" & posixhomeFolder & posixdisplayPlaylistHomeDir & "/DisplayPlaylist.pl\" " & systemName & " &> /dev/null & echo $!"
            set processID to do shell script displayPlaylistPl -- Start DisplayPlaylist.pl in background on "LocalMac"
        end if
    end setupEnvironment

    on DisplayPlaylistMain()
        repeat
            --
            -- Process the current Decibel Playlist and write it to the displayPlaylistLog File in the following Formats:
            --
            -- Status - Orquestra - Song Title - Genre
            -- False - Miguel Calo - Cuatro Compaces - Tango
            -- Playing - Miguel Calo - Cuatro Compaces - Tango
            -- Stopped - Miguel Calo - Cuatro Compaces - Tango
            --
            if (musicPlayer equal to "Decibel") then
                set playlistProperties to readPlaylistDecibel() -- Get current Playlist from Decibel Player
            else
                set playlistProperties to readPlaylistiTunes() -- Get current Playlist from iTunes Player
            end if
            set readSucceeded to item 7 of playlistProperties
            --
            -- Set currentTitlePlaying and lastTitlePlaying to the current song
            --
            set currentTitlePlaying to item 5 of playlistProperties
            set lastTitlePlaying to currentTitlePlaying
            --
            -- Set playerIsPlaying and playerWasPlaying to the current player status
            --
            set playerIsPlaying to item 6 of playlistProperties
            set playerWasPlaying to playerIsPlaying
            --
            -- Set adSignaledYet and logSignaledYet to false to force a display status update
            --
            set adSignaledYet to false
            set logSignaledYet to false
            set lastAdvertising to advertising
            --
            -- Repeat until the next title is played
            --
            repeat while (lastTitlePlaying is equal to currentTitlePlaying)
                if (playerIsPlaying and (not logSignaledYet)) then
                    --
                    -- Check for and if not mounted, mount raspi/odroid Home Directory
                    --
                    mountHomeDir()
                    --
                    -- Signal "Logfile" to DisplayPlaylist.pl once, if player is playing
                    --
                    writePlaylist(playlistProperties, "Logfile")
                    set logSignaledYet to true
                end if
                if ((not playerIsPlaying) and (not adSignaledYet)) then
                    --
                    -- Check for and if not mounted, mount raspi/odroid Home Directory
                    --
                    mountHomeDir()
                    --
                    -- Signal Werbung Popup (HtmlFile) to DisplayPlaylist.pl once if not "Off", if player has stopped
                    --
                    if (advertising is not equal to "Off") then
                        writePlaylist(playlistProperties, advertising)
                    end if
                    set lastAdvertising to advertising
                    set adSignaledYet to true
                end if
                --
                -- Reread the playlist from player and set currentTitlePlaying and playerIsPlaying
                --
                if (musicPlayer equal to "Decibel") then
                    set currentPlaylistProperties to readPlaylistDecibel()
                else
                    set currentPlaylistProperties to readPlaylistiTunes()
                end if
                set readSucceeded to item 7 of currentPlaylistProperties
                --
                -- Get currently played title for later comparison in repeat loop, to see if it has changed.
                --
                set currentTitlePlaying to item 5 of currentPlaylistProperties
                --
                -- Get current player status - is player playing or stopped
                --
                set playerIsPlaying to item 6 of currentPlaylistProperties
                if (readSucceeded) then
                    --
                    -- Check if playlist has changed - Next Song played, Songs moved, added or deleted from Playlist
                    --
                    set currentPlaylistTitles to ""
                    set lastPlaylistTitles to ""
                    repeat with i from 1 to count of item 2 of currentPlaylistProperties
                        set currentPlaylistTitles to currentPlaylistTitles & item i of item 1 of currentPlaylistProperties & item i of item 2 of currentPlaylistProperties & item i of item 3 of currentPlaylistProperties & item i of item 4 of currentPlaylistProperties & "\n"
                    end repeat
                    repeat with i from 1 to count of item 2 of playlistProperties
                        set lastPlaylistTitles to lastPlaylistTitles & item i of item 1 of playlistProperties & item i of item 2 of playlistProperties & item i of item 3 of playlistProperties & item i of item 4 of playlistProperties & "\n"
                    end repeat
                    if (lastPlaylistTitles is not equal to currentPlaylistTitles) then
                        copy currentPlaylistProperties to playlistProperties
                        set adSignaledYet to false
                        set logSignaledYet to false
                    end if
                    --
                    -- Check if player status has changed (playing or stopped)
                    --
                    if ((playerIsPlaying and not playerWasPlaying) or (not playerIsPlaying and playerWasPlaying)) then
                        set playerWasPlaying to playerIsPlaying
                        set adSignaledYet to false
                        set logSignaledYet to false
                    end if
                end if
                --
                -- Check if Advertising mode changed
                --
                if (lastAdvertising is not equal to advertising) then
                    set adSignaledYet to false
                    set lastAdvertising to advertising
                    set logSignaledYet to false
                end if
                delay 1
                --
                -- Check for changes in the user interface
                --
                fetchEvents()
            end repeat
        end repeat
    end DisplayPlaylistMain
    
    on fetchEvents() -- handle user events to keep the queue from filling up (Shane Stanley)
        repeat -- forever
            tell current application's NSApp to set theEvent to nextEventMatchingMask_untilDate_inMode_dequeue_(current application's NSUIntegerMax, missing value, current application's NSEventTrackingRunLoopMode, true)
            if theEvent is missing value then -- none left
                exit repeat
            else
                tell current application's NSApp to sendEvent_(theEvent) -- pass it on
            end if
        end repeat
        return
    end fetchEvents
    
    on ButtonHandlerUsePlayer_(sender)
        --
        -- Just set musicPlayer to the value of the Popup
        --
        set musicPlayer to (currentPlayerDisplayedPopup's titleOfSelectedItem()) as string
        --
        -- Start DisplayPlaylistMain() - will run until application is quit
        --
        performSelector_withObject_afterDelay_("DisplayPlaylistMain", missing value, 1.0)
        --
    end ButtonHandlerUsePlayer_
    
    on ButtonHandlerAnzeigeModus_(sender)
        --
        -- Call setupEnvironment() and set systemName to the value of the Popup
        --
        setupEnvironment()
        set systemName to (systemNamePopup's titleOfSelectedItem()) as string
        --
        -- Start DisplayPlaylistMain() - will run until application is quit
        --
        performSelector_withObject_afterDelay_("DisplayPlaylistMain", missing value, 1.0)
        --
    end ButtonHandlerAnzeigeModus_
    
    on ButtonHandlerWerbung_(sender)
        --
        -- Just set advertising to the value of the Popup
        --
        set advertising to (advertisingPopup's titleOfSelectedItem()) as string
        --
        -- Start DisplayPlaylistMain() - will run until application is quit
        --
        performSelector_withObject_afterDelay_("DisplayPlaylistMain", missing value, 1.0)
        --
    end ButtonHandlerWerbung_
    
	on applicationWillFinishLaunching_(aNotification)
		-- Insert code here to initialize your application before any files are opened
        setupEnvironment()
        --
        -- Set the localized texts of systemNameLocalisation, advertisingLocalisation and currentPlayerLocalisation
        -- and set the Popup's to predefined values or from the ones of .Displayplaylist
        --
        systemNameLocalisation's setStringValue_(systemNameLocalisationDefault)
        advertisingLocalisation's setStringValue_(advertisingLocalisationDefault)
        currentPlayerLocalisation's setStringValue_(currentPlayerLocalisationDefault)
        systemNamePopup's setTitle_(systemName)
        advertisingPopup's setTitle_(advertising)
        currentPlayerDisplayedPopup's setTitle_(musicPlayer)
        --
        -- Start DisplayPlaylistMain() - will run until application is quit
        --
        performSelector_withObject_afterDelay_("DisplayPlaylistMain", missing value, 1.0)
        --
	end applicationWillFinishLaunching_
	
	on applicationShouldTerminate_(sender)
		-- Insert code here to do any housekeeping before your application quits
        if systemName is equal to "LocalMac" then
            do shell script killDisplayPlaylist
        end if
        --
        -- Quit DisplayPlaylist
        --
        tell current application's NSApp to terminate_(me)
		-- return current application's NSTerminateNow
	end applicationShouldTerminate_
	
end script
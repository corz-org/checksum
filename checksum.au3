#AutoIt3Wrapper_Res_Fileversion=2.0.3.0
global const $VERSION = "2.0.3.0"

;
; checksum
; from corz.org
; (c) 2006 ->
;
; https://corz.org/windows/software/checksum/
;

#cs

Debug Levels:

	0: No debug output.
	1: Errors. Also used for temporary debug statements (default before assigning integer).
	2: + Basic status messages.
	3: + Most useful debugging starts here.
	4: + Increased init debug output
	5: + Language-related debugging starts here. Also initial switches and command-line debugging.
	6: + Hashing and algorithm data here. Init debug output includes PATH and directory information.
	7: + Init outputs preferences and system variables. More in-depth debugging of functions.
	8: + CheckHashformat() debugging here.
	9: + Debug logging facility, HTML/text log creation, etc..
	10: + Draws borders around GUI controls. This *only* happens at level 10.

	Special level (a-la Spinal Tap)..

		11: All previous (except 10) + outputs /all/ current language translation phrases.

  Not every function has debug statements. ;o)

#ce


#include <Misc.au3>
#include <Math.au3>
#include <Constants.au3>
#include <ComboConstants.au3>
#include <StructureConstants.au3>
#include <APIFilesConstants.au3>
#include <WinAPIInternals.au3>
#include <WinAPIFiles.au3>
#include <WinAPIGdi.au3>
#include <GUIToolTip.au3>
#include <WinAPISysWin.au3>
#include <WinAPIIcons.au3>
#include <WinAPIShellEx.au3>

#include "Includes\checksumShared.au3"
#include "Includes\LanguageInstaller.au3"

AutoItSetOption("TrayOnEventMode", 1)
AutoItSetOption("GUICoordMode", 0)
AutoItSetOption("TrayMenuMode", 11)
AutoItSetOption("GUIOnEventMode", 1)

$app_name = "checksum"
global const $MAX_PATHS = 16777215
global const $INI_FILE = $app_name & ".ini"

global const $MY_URL = "https://corz.org/windows/software/checksum/"
global const $DOWNLOAD_URL = "https://corz.org/windows/software/checksum/#section-download"
global const $VERSION_CHECK_URL = "https://corz.org/inc/versions.php?app=checksum"
global const $BETA_URL = "https://corz.org/inc/versions.php?app=checksum-beta"
global const $UPDATE_LOG = "https://corz.org/public/machine/Windows/Software/checksum/Source/itstory.txt?view"

global $beta_channel, $do_exit_command, $exe_path
global $ini_installed = false
global $script_dir = @ScriptDir
global $queue_file = @TempDir & "\checksum_queue"
global $config_folder_path = @AppDataDir & "\corz\" & $app_name
global $shutdown_when_done = $OFF
global $dropped_files[1]
global $task_mode = false
global $search_and_verify = $OFF
global $found_verify_path = false
global $current_file, $existing_hashes_lookup
global $com_error_details_array[2]
global $error_obj = ObjEvent("AutoIt.Error", "HandleComError")
global $force_verify = false
global $do_options = false
global $input_timeout, $dialog_input
global $tooltip_handle, $checkbox_progress_tip
global $tray_click_bounce = false
global $my_msg, $full_text



; Before language translations are loaded proper, we have a simple _B() macro
; which translates the bootstrapping messages into most main languages,
; at least one for each "region". I do what I can..


; Portable mode setup..
if $cmdline[0] = 1 and StringStripWS($cmdline[1], $STR_STRIP_ENDS) = "portable" then
	$my_msg = _B("Portable Mode Enabled!")
	if FileInstall("Resources\checksum.ini", $script_dir & "\" & $INI_FILE) then
		IniWrite($script_dir & "\" & $INI_FILE, $app_name, "log_folder", "@checksumdir\logs")
		MsgBox($MB_TOPMOST, $my_msg, $my_msg, 30)
	else
		$my_msg =  _B("Portable Mode NOT Enabled!")
		$full_text = _B("Check your folder permissions")
		MsgBox($MB_TOPMOST+$MB_ICONERROR, $my_msg, $my_msg & @LF & @LF & $full_text, 30)
	endif
	exit 0
endif


; Check for portable mode..
if FileExists($script_dir & "\" & $INI_FILE) then
	$ini_path = $script_dir & "\" & $INI_FILE
	FileChangeDir($script_dir)
else
	if not FileExists($config_folder_path) then DirCreate($config_folder_path)
	$ini_path = $config_folder_path & "\" & $INI_FILE
	$ini_installed = FileInstall("Resources\checksum.ini", $ini_path)
endif


; Ctrl + SHIFT key overrides..
if _IsPressed("10") then $do_options = true
if _IsPressed("11") then $force_verify = true


if @Compiled then
	$exe_path = @ScriptFullPath
else
	$exe_path = ".\" & $app_name & ".exe"
endif

; Missing ini file..
if not FileExists($ini_path) then
	$my_msg = _B("checksum.ini is missing")
	MsgBox($MB_TOPMOST + $MB_ICONERROR, $my_msg & "!", _
		$my_msg & _B("checksum is unable to write a new checksum.ini") & @LF & @LF & _
		_B("Please ensure your data folder is writable!") & @LF & _
		_B("checksum cannot continue"), 30)
	debug("checksum.ini is missing: ----->	EXIT 11" , @ScriptLineNumber, 1)
	exit 11
endif

; $ini_path is now set.

if @Compiled then
	$beta_channel = IniReadCheckBox($ini_path, $app_name, "beta_channel", $OFF)
endif

$debug_level = Int(IniRead($ini_path, $app_name, "debug_level", 0))
if $debug_level then
	local $dump_file = IniRead($ini_path, $app_name, "dump_file", "checksum.debug")
	$debug_log = $dump_file
	MakeAFile($debug_log, true) ; Wipe file for every run.
	InitDebug()
endif


global $write_command_line = IniReadCheckBox($ini_path, $app_name, "write_command_line", $OFF)
local $command_line_file = IniRead($ini_path, $app_name, "command_line_file", "@userdir\last_command-line.log")
debug("write_command_line: =>" & Human($write_command_line) & "<=" , @ScriptLineNumber, 5)
local $command_line_out_append = IniReadCheckBox($ini_path, $app_name, "command_line_out_append", $ON)

if $write_command_line = $ON and $CmdLine[0] > 0 then
	$command_line_file = DeTokenize($command_line_file, $command_line_file, "path")
	if $command_line_out_append = $OFF then DeleteFilesRecursive($command_line_file)
	debug("Writing out Command-Line to =>" & $command_line_file & "<=", @ScriptLineNumber, 5)
	FileWrite($command_line_file, _NowCalc() & ": " & $CmdLineRaw & $LF)
endif


global $allow_multiple = IniReadCheckBox($ini_path, $app_name, "allow_multiple", $OFF)
global $apply_options_to_queue = IniReadCheckBox($ini_path, $app_name, "apply_options_to_queue", $ON)
debug("allow_multiple: =>" & Human($allow_multiple) & "<=" , @ScriptLineNumber, 5)


; Read [checksum] prefs section into an array..
global $ini_array = IniReadSection($ini_path, $app_name)




;
; Language translations..									B:\Test\INVALID.hash		cro B:\		vro B:\

func __________________LOAD_LANGUAGES()
endfunc

; Install language files..
local $languages_directory = GetParent($ini_path) & "\languages"
local $flags_directory = $languages_directory & "\flags"
local $language_codes = MapKeys($language_code_mappings)
debugPrintArray($language_codes, "$language_codes:", @ScriptLineNumber, 7, default, default, default, default, true)

local $existing_count = 0
for $code in $language_codes
    if FileExists($languages_directory & "\" & $code & ".ini") then
        $existing_count += 1
    endif
    if FileExists($flags_directory & "\" & $code & ".gif") then
        $existing_count += 1
    endif
next

; Incomplete installation is fine; the user may have deleted some files.
if $existing_count == 0 then
    InstallLanguageFiles($languages_directory, $flags_directory)
endif

; Native associative arrays in AutoIt!
global $translation_dictionary[]

; Check ini for existing language setting..
global $active_language = GetINIArrayValue($ini_array, "language", "")
debug("active_language: =>" & $active_language & "<=" , @ScriptLineNumber, 7)

; No language selected, or we are testing..
if $active_language = "" or StringInStr($active_language, "test") then
	local $ask_for_language = GetUserLanguageSelection($languages_directory)
	debug("ask_for_language: =>" & $ask_for_language & "<=" , @ScriptLineNumber, 7)
	if $ask_for_language = "" then $ask_for_language = "en"
	if not StringInStr($active_language, "test") then
		IniWrite($ini_path, $app_name, "language", $ask_for_language)
	endif
	$active_language = $ask_for_language
endif

debug("#include Includes\languages.au3", @ScriptLineNumber, 3)
#include "Includes\languages.au3"
$active_language = LoadLanguage($active_language, $languages_directory)

; Now we can use _T() (translate)..
debug("active_language: =>" & $active_language & "<=" , @ScriptLineNumber, 3)
debug("TRANSLATION: 'Passed' =>" & _T("Passed") & "<=" , @ScriptLineNumber, 7)


; RTL Languges..
global $is_rtl = $OFF
global $reading_direction = 0
global $text_alignment = $SS_LEFT
if IsRTLLanguage($active_language) then
	$is_rtl = $ON
	$text_alignment = $SS_RIGHT
	$reading_direction = $WS_EX_RTLREADING
endif


; Add this to all tray messages..
global const $TRAY_CLICK_MSG = _T("right-click to bring up the tray menu")

; Check for updated version ini..				cro B:\
global $is_upgrade = $OFF
if not $ini_installed then $is_upgrade = UpdateChecksumINIFile()
debug("is_upgrade: =>" & $is_upgrade & "<=" , @ScriptLineNumber, 1)

; One-time welcome dialog..
global $welcomed = IniReadCheckBox($ini_path, $app_name, "welcomed", $OFF)
if $is_upgrade == $ON then $welcomed = $OFF

; WELCOME!
if $welcomed <> $ON then
	AdlibRegister("EndSplash", 1500)
	ShowSplash()
endif


SetTrayTip(_T("checksum is gathering user preferences.."))

global $help_tips = INIArrayReadCheckBoxValue($ini_array, "help_tips", $ON)
global $timestamp_string = @YEAR & "-" & @MON & "-" & @MDAY & " @ " & @HOUR & "." & @MIN & ":" & @SEC
global $html_data = ""
global $do_recurse = false
global $log_everywhere_flag = 1
global $hash_file_active = true
global $log_parent = ""
global $hash_match_status_flag = ""
global $process_existing_hashes = false
global $fallback_mode_active = false
global $hashfile_extension = ".sha2"
global $uppercase_hashes = 0
global $hash_length = 32
global $hash_written = false
global $hashfile_created = false
global $current_file_handle = ""
global $hashfile_path = ""
global $do_sync = false
global $has_failures = false
global $is_playlist_mode = false
global $in_progress = false
global $playlist_type = "m3u"
global $playlist_entry_counter = 0
global $is_playlist_enabled = false
global $operation_mode = "create"
global $tooltip_ready = false
global $verify_single_file_mode = false
global $dialog_timeout = GetINIArrayValue($ini_array, "dialog_timeout", 60)
global $gc_interval_setting = GetINIArrayValue($ini_array, "garbage_collector", "hourly")
global $elapsed_time_seconds = false
global $GUI_Options = ""
global $GUI_about = ""
global $GUI_nothing_to_do = ""
global $root_writeable = false
global $unwritable_path = ""
global $log_file_handle = ""
global $file_queue_array[1][2] = [[""]]

global $status_result_codes[7] = ["quit", "cancel", "noexist", "rd_quit", "nada", "bad", "invalid"]
;      $status_result_codes        [0]      [1]        [2]        [3]      [4]     [5]      [6]

global $hash_status_codes[10] = [_T("Passed"), _T("BAD"), _T("MISSING"), _T("DELETED"), _T("CORRUPT"), _T("CHANGED"), _T("UPDATED"), _T("SKIPPED"), _T("INVALID"), _T("ERROR")]
;      $hash_status_codes           [0]            [1]          [2]            [3]            [4]            [5]           [6]             [7]            [8]          [9]

global $log_entry_counter = 0
global $log_entries_array[$log_entry_counter + 1][4] = [["", "", "", ""]]
global $queue_entry_has_failures = false
global $total_processing_time_seconds = 0
global $tray_items[14] = [""]
global $bad_file_paths_list = ""
global $exit_code_value = 0
global $path_already_exists_flag = false
global $fallback_dirs_created = false
global $nfo_file_written = false
global $unwritable_paths_list = ""
global $files_hashed_count = 0
global $hashes_deleted_count = 0
global $hashes_updated_count = 0
global $legacy_ext_rename_count = 0
global $extension_switched_count = 0
global $sync_choice = "no_all"
global $stored_progress_str = $app_name
global $playlist_string
global $menu_toggle_audio

global $do_preamble = INIArrayReadCheckBoxValue($ini_array, "do_preamble", $ON)
global $show_edit_ini = INIArrayReadCheckBoxValue($ini_array, "show_edit_ini", $ON)

global $tooltip_progress, $group_algorithm, $group_behaviour, $do_audio_alerts
global $line_feed = GetINIArrayValue($ini_array, "line_feed", "CRLF")
; $LF set to @CRLF in cel.au3
if $line_feed = "LF" then $LF = @LF
if $line_feed = "CR" then $LF = @CR

global $unified_extension = INIArrayReadCheckBoxValue($ini_array, "unified_extension", $ON)
global $unihash_extension = GetINIArrayValue($ini_array, "unihash_ext", "hash")
if StringLeft($unihash_extension, 1) = "." then $unihash_extension = StringTrimLeft($unihash_extension, 1)
if $unified_extension = $ON then $hashfile_extension = "." & $unihash_extension

local $UNIX_hash_adds = ""
global $unix_hashfiles = GetINIArrayValue($ini_array, "unix_hashfiles", "md5sums,md5sum.txt")
if $unix_hashfiles <> "" then $UNIX_hash_adds = "," & $unix_hashfiles

global $hash_extensions[7] = [6, $unihash_extension]
global $hashfiles = "*." & $unihash_extension
for $i = 1 to $hash_algorithms[0]
	$hashfiles &= ",*." & $hash_algorithms[$i]
	$hash_extensions[$i + 1] = $hash_algorithms[$i]
next
$hash_extensions[6] = "sfv"
$hashfiles &= ",*.sfv"
$hashfiles &= $UNIX_hash_adds

debug("hashfiles =>" & $hashfiles & "<=", @ScriptLineNumber, 6)
debugPrintArray($hash_algorithms, "$hash_algorithms", @ScriptLineNumber, 6)
debugPrintArray($hash_extensions, "$hash_extensions", @ScriptLineNumber, 6)

global $show_unc_paths = INIArrayReadCheckBoxValue($ini_array, "show_unc_paths", $OFF)
global $always_store_unc = INIArrayReadCheckBoxValue($ini_array, "always_store_unc", $ON)
global $relaxed_write_test = INIArrayReadCheckBoxValue($ini_array, "relaxed_write_test", $OFF)
global $ignore_symlinks = INIArrayReadCheckBoxValue($ini_array, "ignore_symlinks", $OFF)

global $quiet_operation = INIArrayReadCheckBoxValue($ini_array, "quiet_operation", $OFF)
debug("quiet_operation =>" & Human($quiet_operation) & "<=", @ScriptLineNumber, 5)

global $path = ""
global $switches = ""
global $exit_command

; Changelog updates..
global $itstory_checking = GetINIArrayValue($ini_array, "itstory_checking", "")


; Custom verify path..
global $custom_verify_path = false

;
; Handle command-line..

local $cmd_line = $cmdline
debugPrintArray($cmd_line, "$cmd_line:", @ScriptLineNumber, 5)

if $cmd_line[0] then

	; Switches and path supplied, well done!
	if $cmd_line[0] = 2 then
		$switches = $cmd_line[1]
		$path = StringStripWS($cmd_line[$cmd_line[0]], $STR_STRIP_ENDS)
		; Remove from switches and store now..
		$custom_verify_path = ExtractSwitchGroup("p", "")
		; If ONLY a custom_verify_path was supplied in the switches, we reset the command-line array
		; so hash file detection still works after p(custom verify path) group removed.
		if @extended == 1 and $switches = "" then ; @extended set to 1 if this was a p(custom-path) switch group.
			$cmd_line[0] = 1
			$cmd_line[1] = $cmd_line[2]
		endif
		debugPrintArray($cmd_line, "$cmd_line:", @ScriptLineNumber, 5)
	endif

	; No switches, only a path, let's figure out what the user wants here..
	if $cmd_line[0] = 1 then
		$path = StringStripWS($cmd_line[1], $STR_STRIP_ENDS)
		local $scanned_files = Dig(GetLongParentDir($path), $unix_hashfiles, true)
		if IsDir($path) then
			$switches = "cr"
		elseif FindInStringArray($hash_extensions, GetExtension($path)) then
			$switches = "v"
		elseif FindInStringArray($scanned_files, $path) then
			$switches = "v"
		else
			$switches = "c"
		endif
	endif

	debug("$switches            =>" & $switches & "<=" , @ScriptLineNumber, 5)
	debug("$cmd_line --> path:  =>" & $path & "<=" , @ScriptLineNumber, 5)
	debug("$custom_verify_path: =>" & $custom_verify_path & "<=" , @ScriptLineNumber, 5)
else
	DoStartupCommand()
endif


func __________________SINGLETON()
endfunc

;
; Already running..

; DIY Singleton..
; One mutex per drive.
local $drive_to_register = $path
if $custom_verify_path then $drive_to_register = $custom_verify_path
local $drive_letter = StringReplace(StringLeft(StripLongPathPrefix($drive_to_register), 2), ":", "")
local $mutex_name = "Local\checksumMutexDrive_" & $drive_letter
local $call = DllCall("kernel32.dll", "handle", "CreateMutexW", "ptr", 0, "bool", 1, "wstr", $mutex_name)
local $mutex_handle = $call[0]
local $last_error = DllCall("kernel32.dll", "dword", "GetLastError")[0]
local $already_hashing_this_drive = ($last_error = 183)

SetError(0)
local $add_to_queue = false
local $do_singleton_exit = false

; A standard Singleton..
if _Singleton("checksums_abitrary_sysmsg", 1) = 0 then
	debug("***             SECONDARY INSTANCE              ***", @ScriptLineNumber, 5)

	; Add to queue and exit..
	if StringLeft($allow_multiple, 1) = "q" then
		$add_to_queue = true
	endif

	if not $add_to_queue then	; 	TODO enable option in dialog to enable queueing and queue immediately.
		if $already_hashing_this_drive then
			if $allow_multiple = $OFF then
				$my_msg = _T("checksum is already running on this disk!")
				$full_text = _T("This copy will now exit.")
				MsgBox($MB_TOPMOST, $my_msg, $my_msg & @LF & @LF & _
						$full_text & @LF & @LF & _
						_T("checksum.ini: {{allow_multiple=true}} / {{allow_multiple=queue}}"), 30)
				$do_singleton_exit = true
			endif
		endif
	endif

	if $add_to_queue then
		if $do_options and $apply_options_to_queue = $OFF then $CmdLineRaw = "o" & $CmdLineRaw
		IniWrite($queue_file, "queue", "cmdline@" & @HOUR & "." & @SEC & "." & @MSEC, $CmdLineRaw)
		$do_singleton_exit = true
	endif

	if $do_singleton_exit then
		DllCall("kernel32.dll", "bool", "CloseHandle", "handle", $mutex_handle)
		exit 5
	endif

endif


; Nothing to do!
if not $task_mode and $path = "" then
	MakeTray(false)
	NothingToDo()
	CheckVersionAndExit(7)
endif


; Unless told otherwise, we recurse directories.
DetermineRecurseFromPath($path)
debug("path =>" & $path & "<=", @ScriptLineNumber, 3)

debug("initial switches: " & "->" & $switches & "<-", @ScriptLineNumber, 5)
debug("do_recurse: " & "->" & $do_recurse & "<-", @ScriptLineNumber, 5)
$path = ConvertToCorrectCLIPath($path)
debug("Final UNICODE path =>" & $path & "<=", @ScriptLineNumber, 5)

if $force_verify then
	$switches = StringReplace($switches, "c", "", 1)
	$switches = "v" & $switches
endif
debug("Final Initial switches: " & "->" & $switches & "<-", @ScriptLineNumber, 5)

global $algorithm = GetINIArrayValue($ini_array, "algorithm", $hash_algorithms[DefaultAlgoID()])
$algorithm_id = _ArraySearch($hash_algorithms, $algorithm, 1)
if $algorithm_id = -1 then
	$algorithm_id = DefaultAlgoID()
	$algorithm = $hash_algorithms[$algorithm_id]
	IniWrite($ini_path, $app_name, "algorithm", $algorithm)
endif
; Algorithm switch-letter map, parallel to $hash_algorithms (helpers live near SwitchesToVars()).
global $algo_switch_letters[5] = [4, "5", "s", "2", "4"]
; Hex lengths per algorithm ID. NOTE: all top-level globals must live here in the
; startup region; anything declared later never executes before the job runs.
global $algo_hex_lens[5] = [4, $MD5_HEX_LEN, $SHA1_HEX_LEN, $SHA2_HEX_LEN, $CRC32_HEX_LEN]
debug("algorithm: =>" & $algorithm & "<=" , @ScriptLineNumber, 5)
debug("algorithm_id: =>" & $algorithm_id & "<=" , @ScriptLineNumber, 5)

global $uppercase = INIArrayReadCheckBoxValue($ini_array, "uppercase", $OFF)
global $utf8_hashes = INIArrayReadCheckBoxValue($ini_array, "utf8_hashes", $ON)

; AutoIt handles this differently now. UTF-8 NO BOM is the default. Good!
global $utf8_file_mode_flag = 0
if $utf8_hashes = $OFF then $utf8_file_mode_flag = $FO_ANSI
global $add_utf8_bom = INIArrayReadCheckBoxValue($ini_array, "add_utf8_bom", $OFF)
if $utf8_hashes = $ON and $add_utf8_bom = $ON then $utf8_file_mode_flag = $FO_UTF8
debug("utf8_file_mode_flag: =>" & $utf8_file_mode_flag & "<=" , @ScriptLineNumber, 5)

global $error_display_limit = Number(GetINIArrayValue($ini_array, "error_display_limit", 24))
if $error_display_limit < 10 then $error_display_limit = 24
if $error_display_limit > 1000 then $error_display_limit = 24
global $log_format = GetINIArrayValue($ini_array, "log_format", "text")
global $log_folder = GetINIArrayValue($ini_array, "log_folder", "@userdir\logs")
if $log_folder = "" then $log_folder = "@userdir\logs"
global $log_name = GetINIArrayValue($ini_array, "log_name", "[@year-@mon-@mday] checksums for @item")
global $log_folder_path_alias = $log_folder
global $log_path_type = ""
global $log_file_path = ""
global $log_to_file = INIArrayReadCheckBoxValue($ini_array, "log_to_file", $OFF)
global $log_everything = INIArrayReadCheckBoxValue($ini_array, "log_everything", $OFF)
global $append_logs = INIArrayReadCheckBoxValue($ini_array, "append_logs", $OFF)
$playlist_type = GetINIArrayValue($ini_array, "playlist_type", "m3u")
global $status_fail = GetINIArrayValue($ini_array, "status_fail", "ERRORS")
global $status_success = GetINIArrayValue($ini_array, "status_success", "100% AOK")
global $open_log_folder = INIArrayReadCheckBoxValue($ini_array, "open_log_folder", $ON)
global $compress_logs = INIArrayReadCheckBoxValue($ini_array, "compress_logs", $ON)
global $hashfile_paths = INIArrayReadCheckBoxValue($ini_array, "hashfile_paths", $OFF)
global $path_in_titles = INIArrayReadCheckBoxValue($ini_array, "path_in_titles", $OFF)
global $truncate_at = GetINIArrayValue($ini_array, "truncate_at", "")
global $display_times = INIArrayReadCheckBoxValue($ini_array, "display_times", $OFF)
global $total_times = INIArrayReadCheckBoxValue($ini_array, "total_times", $OFF)
if $display_times = $OFF then $total_times = $OFF
global $fallback_styles = INIArrayReadCheckBoxValue($ini_array, "fallback_styles", $ON)
global $master_styles = INIArrayReadCheckBoxValue($ini_array, "master_styles", $ON)
global $embed_styles = INIArrayReadCheckBoxValue($ini_array, "embed_styles", $OFF)

GetLogPath()

; Mail stuff
global $mail_on_failure = INIArrayReadCheckBoxValue($ini_array, "mail_on_failure", $OFF)
global $current_mail_preset, $mail_preset_list_array, $mail_preset_combo_id, $resend_mail, $resend_mail_max_retry
global $my_mail_hack, $smtp_server, $from_name, $from_address, $to_address, $subject, $retry_delay_seconds
global $mail_priority, $mail_user, $mail_pass, $cc_add, $bcc_add, $mail_ssl
global $ssl_ntlm_auth_flag, $mail_port, $attached_files
debug("#include Includes\WinMail.au3", @ScriptLineNumber, 3)
#include "Includes\WinMail.au3"

global $ignore_types = StringStripWS(GetINIArrayValue($ini_array, "ignore_types", "md5,sha1,sha2,hash,sfv,crc"), $STR_STRIP_ENDS)
if StringLeft($ignore_types, 1) = "," then
	$ignore_types = StringTrimLeft($ignore_types, 1)
	IniWrite($ini_path, $app_name, "ignore_types", $ignore_types)
endif
if StringInStr($ignore_types, ",,") then
	$ignore_types = StringReplace($ignore_types, ",,", ",")
	IniWrite($ini_path, $app_name, "ignore_types", $ignore_types)
endif
if $ignore_types <> "" then $ignore_types = StringSplit($ignore_types, ",")
global $exclude_masks
global $ignore_files = StringStripWS(GetINIArrayValue($ini_array, "ignore_files", "desktop.ini,folder.jpg,.desktop,thumbs.db"), $STR_STRIP_ENDS)
$ignore_files = StringSplit($ignore_files, ",")
debugPrintArray($ignore_files, "Ignored Files:", @ScriptLineNumber, 5)
global $ignore_folders = GetINIArrayValue($ini_array, "ignore_folders", "")

global $always_sync = INIArrayReadCheckBoxValue($ini_array, "always_sync", $OFF)
global $file_extensions = INIArrayReadCheckBoxValue($ini_array, "file_extensions", $OFF)
global $hide_checksums = INIArrayReadCheckBoxValue($ini_array, "hide_checksums", $OFF)

global $beep_alerts = INIArrayReadCheckBoxValue($ini_array, "beep_alerts", $ON)
global $beep_freq = GetINIArrayValue($ini_array, "beep_freq", 1000)
if $beep_freq < 37 or $beep_freq > 19999 or $beep_freq = "" then
	$beep_freq = 1000
	IniWrite($ini_path, $app_name, "beep_freq", $beep_freq)
endif

global $beep_success = GetINIArrayValue($ini_array, "beep_success", "")
global $beep_fail = GetINIArrayValue($ini_array, "beep_fail", "")
if not FileExists($beep_success) then $beep_success = ""
if not FileExists($beep_fail) then $beep_fail = ""

global $one_hash = INIArrayReadCheckBoxValue($ini_array, "one_hash", $OFF)
global $absolute_paths = INIArrayReadCheckBoxValue($ini_array, "absolute_paths", $OFF)
global $nix_paths = INIArrayReadCheckBoxValue($ini_array, "nix_paths", $OFF)
global $individual_hashes = INIArrayReadCheckBoxValue($ini_array, "individual_hashes", $OFF)
global $fallback_level = GetINIArrayValue($ini_array, "fallback_level", 1)
global $fallback_folder = GetINIArrayValue($ini_array, "fallback_folder", "@desktop\checksums")
if $fallback_folder = "" then $fallback_folder = "@desktop\checksums"
global $resync_readonly = INIArrayReadCheckBoxValue($ini_array, "resync_readonly", $ON)
global $allow_caching = INIArrayReadCheckBoxValue($ini_array, "allow_caching", $OFF)
global $long_operation = GetINIArrayValue($ini_array, "long_operation", 0)
global $readable_times = INIArrayReadCheckBoxValue($ini_array, "readable_times", $ON)
global $hashfile_name = GetINIArrayValue($ini_array, "hashfile_name", "")
global $report_missing = INIArrayReadCheckBoxValue($ini_array, "report_missing", $ON)
global $report_changed = INIArrayReadCheckBoxValue($ini_array, "report_changed", $ON)
global $report_corrupt = INIArrayReadCheckBoxValue($ini_array, "report_corrupt", $ON)
global $do_timestamp = INIArrayReadCheckBoxValue($ini_array, "do_timestamp", $OFF)
$do_exit_command = INIArrayReadCheckBoxValue($ini_array, "do_exit_command", $OFF)
global $default_mask = GetINIArrayValue($ini_array, "default_mask", "*.*")
if not $default_mask then $default_mask = "*.*"
global $file_mask = $default_mask
global $nameless_name = GetINIArrayValue($ini_array, "nameless_name", "")
global $check_dates = INIArrayReadCheckBoxValue($ini_array, "check_dates", $ON)

global $progress_tip = INIArrayReadCheckBoxValue($ini_array, "progress_tip", $ON)
global $tooltip_x = GetINIArrayValue($ini_array, "x", 0)
global $tooltip_y = GetINIArrayValue($ini_array, "y", 0)
global $tip_font = GetINIArrayValue($ini_array, "tip_font", "Lucida Console")
global $tip_font_size = GetINIArrayValue($ini_array, "tip_font_size", 7)
global $tip_snap = GetINIArrayValue($ini_array, "tip_snap", 16)
global $tip_color = GetINIArrayValue($ini_array, "tip_color", "ffffff")
global $warn_color = GetINIArrayValue($ini_array, "warn_color", "ff0000")
global $tip_text_color = GetINIArrayValue($ini_array, "tip_text_color", "000000")
global $tip_stretch = GetINIArrayValue($ini_array, "tip_stretch", 100)
if $tip_stretch < 1 then $tip_stretch = 1
if $tip_stretch > 300 then $tip_stretch = 300
$tip_stretch = +(($tip_stretch / 100) * 3.33)

global $pause = GetINIArrayValue($ini_array, "pause", 1000)
global $opt_x = GetINIArrayValue($ini_array, "opt_x", -1)
global $opt_y = GetINIArrayValue($ini_array, "opt_y", -1)
global $gui_initial_position_x = $opt_x
global $gui_initial_position_y = $opt_y
global $tip_anchor_right = INIArrayReadCheckBoxValue($ini_array, "tip_anchor_right", $OFF)

global $skip_hashes = INIArrayReadCheckBoxValue($ini_array, "skip_hashes", $OFF)
if $skip_hashes = $ON then
	global $skipped_hashes = GetINIArrayValue($ini_array, "skipped_hashes", 0)
	$skipped_hashes = StringSplit($skipped_hashes, ",")
endif

global $delete_missing_hashes = INIArrayReadCheckBoxValue($ini_array, "delete_missing_hashes", $OFF)
global $update_changed_hashes = INIArrayReadCheckBoxValue($ini_array, "update_changed_hashes", $OFF)
global $check_only_new_files = INIArrayReadCheckBoxValue($ini_array, "check_only_new_files", $OFF)

global $cpu_priority = Int(GetINIArrayValue($ini_array, "cpu_priority", 2))
if $cpu_priority < 0 or $cpu_priority > 5 then $cpu_priority = 2
ProcessSetPriority(@AutoItPID, $cpu_priority)

global $process_start_timer
$shutdown_when_done = INIArrayReadCheckBoxValue($ini_array, "shutdown_when_done", $OFF)

global $memory_tuning = GetINIArrayValue($ini_array, "memory_tuning", 10)
if $memory_tuning < 1 or $memory_tuning > 1000 then $memory_tuning = 100
$memory_tuning *= 10000
debug("memory_tuning =>" & $memory_tuning & "<=", @ScriptLineNumber, 5)



global $inifile_masks_array = IniReadSection($ini_path, "file masks")
$file_mask = ExtractSwitchGroup("m", $file_mask)
debug("file_mask =>" & $file_mask & "<=", @ScriptLineNumber, 5)
global $original_mask = $file_mask

; If file_mask lacks an extension dot, resolve alias from ini array
if not StringInStr($file_mask, ".") then
    if IsArray($inifile_masks_array) then
        for $mask_idx = 1 to $inifile_masks_array[0][0]
            if $inifile_masks_array[$mask_idx][0] = $file_mask then
                $file_mask = $inifile_masks_array[$mask_idx][1]
            endif
        next
    endif
endif

debug("file_mask FINAL =>" & $file_mask & "<=", @ScriptLineNumber, 5)
global $playlist_extensions = ""
global $gui_playlist_extensions = ""

if IsArray($inifile_masks_array) then
    debugPrintArray($inifile_masks_array, "$mask_array (check for music group)", @ScriptLineNumber, 5)

    local $media_found = false
    local $matched_idx = 0

    ; Primary search: Find playlist extension group matching the original mask name
    for $mask_idx = 1 to $inifile_masks_array[0][0]
        if $inifile_masks_array[$mask_idx][0] = $original_mask then
            if ContainsMediaFileExtension($inifile_masks_array[$mask_idx][1]) then
                $media_found = true
                $matched_idx = $mask_idx
                exitloop
            endif
        endif
    next

    ; Fallback search: Find the first available playlist extension group in the ini array
    if not $media_found then
        for $mask_idx = 1 to $inifile_masks_array[0][0]
            if ContainsMediaFileExtension($inifile_masks_array[$mask_idx][1]) then
                $media_found = true
                $matched_idx = $mask_idx
                exitloop
            endif
        next
    endif

    if $media_found then
        $playlist_extensions = $inifile_masks_array[$matched_idx][1]
        $gui_playlist_extensions = $playlist_extensions
        $playlist_extensions = StringSplit($playlist_extensions, ",")
    endif
endif


$exclude_masks = ExtractSwitchGroup("x", $exclude_masks)
debug("exclude_masks =>" & $exclude_masks & "<=", @ScriptLineNumber, 5)
debug("switches =>" & $switches & "<=", @ScriptLineNumber, 5)

if $exclude_masks then
	$exclude_masks = $ignore_folders & "," & $exclude_masks
else
	$exclude_masks = $ignore_folders
endif

$exclude_masks = StringReplace($exclude_masks, ",,", ",")
if StringRight($exclude_masks, 1) = "," then $exclude_masks = StringTrimRight($exclude_masks, 1)
if StringLeft($exclude_masks, 1) = "," then $exclude_masks = StringTrimLeft($exclude_masks, 1)
debug("ignored folders (masks) =>" & $exclude_masks & "<=", @ScriptLineNumber, 5)
global $out_dir = ""
$out_dir = ExtractSwitchGroup("d", $out_dir, true)
debug("INIT out_dir: " & $out_dir, @ScriptLineNumber, 5)
debug("switches =>" & $switches & "<=", @ScriptLineNumber, 5)

SetCustomHashFileName()
OutputPrefs()

; Legacy hash upgrade..
global $upgrade_final_msg = ""
global $upgrade_log = ""
global $upgrade_all_hashes, $upgrade_log_all
debug("#include \Includes\HashUpgrade.au3", @ScriptLineNumber, 3)
#include "Includes\HashUpgrade.au3"

debug("switches before Gatherswitches(): " & $switches, @ScriptLineNumber, 5)
Gatherswitches()

if $out_dir <> "" then
	debug("out_dir: " & $out_dir, @ScriptLineNumber, 5)
	if StringInStr($out_dir, "@") and not StringInStr($out_dir, ".\") and not StringInStr($out_dir, "..\") then $out_dir = DeTokenize($out_dir, @WorkingDir, "path")
	$out_dir = ConvertToCorrectCLIPath($out_dir, @WorkingDir)
	if StringRight($out_dir, 1) = "\" then $out_dir = StringTrimRight($out_dir, 1)
	if not _LFN_FileExists($out_dir) then
		$my_msg = _T("Does Not Exist!")
		$full_text = _T("Should checksum create the Output Directory?")
		if MsgBox($MB_YESNO + $MB_ICONWARNING + $MB_TOPMOST, _T("Output Directory does Not Exist!"), _
			FormatPathForDisplay($out_dir) & @LF & @LF & $my_msg & @LF & @LF & $full_text) = 6 then _LFN_DirCreate($out_dir)
	endif
	debug("FINAL out_dir: " & $out_dir, @ScriptLineNumber, 5)
endif

MakeTray(false)

; Task Scheduler functions..
debug("#include Includes\WinTask.au3", @ScriptLineNumber, 3)
#include "Includes\WinTask.au3"

if $task_mode then
	CreateTaskMaster()
	exit 110
endif


func __________________CHOOSE_OPTIONS()
endfunc


; Options Dialogs..		cro B:\							vro B:\
debug("do_options =>" & Human($do_options) & "<=", @ScriptLineNumber, 5)

if ($operation_mode = "create" or $operation_mode = "verify") and not StringInStr($switches, "q") and IniReadCheckBox($ini_path, "dialogs", "shift options notice", $OFF) = $OFF then
	$my_msg = _T("ONE TIME NOTICE!")
	$full_text = _T("To bring up the options dialog in future,\n\nhold down the SHIFT key when you launch checksum.")
	MsgBox($MB_TOPMOST, $my_msg, $my_msg & @LF & @LF & _L($full_text), $dialog_timeout)
	$switches &= "o"
	IniWriteCheckBox($ini_path, "dialogs", "shift options notice", $ON)
endif

if ($operation_mode = "create" or $operation_mode = "verify") and (StringInStr($switches, "o") or $do_options) then

	debug("switches before options: " & $switches, @ScriptLineNumber, 5)
	if $operation_mode = "create" then
		DoCreateOptions()
	else
		DoVerifyOptions()
	endif
	if $user_quit then CheckVersionAndExit(-9)
	debug("switches AFTER options =>" & $switches & "<=", @ScriptLineNumber, 5)

	DetermineRecurseFromPath($path)
	GetLogPath()

endif


switchLogformat()
debug("final b4 SwitchesToVars(): " & $switches, @ScriptLineNumber, 5)
SwitchesToVars()
MakeTray(true)

debug("mode =>" & $operation_mode & "<=", @ScriptLineNumber, 3)
if $progress_tip = $ON then checksumProgress()
DoProgressTips(_T("checksum is starting up") & ".. ")

debug("FINAL switches: " & $switches, @ScriptLineNumber, 3)
debug("file_mask: " & $file_mask, @ScriptLineNumber, 5)
debug("custom hashfile_name: " & $hashfile_name, @ScriptLineNumber, 5)

global $result
$process_start_timer = TimerInit()




#Region  ************************  MODE SELECTION       ************************

	;
	; Main mode selection..

	select

		case $operation_mode = "upgrade"
			SetTrayTip(_T("checksum is upgrading hashes"))
			$result = HashUpgrade($path)

		case $search_and_verify = $ON
			$path_already_exists_flag = true
			$result = SearchUpAndVerify($path, $hashfile_extension)
			debug("result =>" & $result & "<=", @ScriptLineNumber, 5)
			if $result == 0 and $algorithm <> $hashfile_extension then
				debug("Searching matching LEGACY hash files.. [previous result]=>" & $result & "<=", @ScriptLineNumber, 5)
				SearchUpAndVerify($path, "." & $algorithm)
			endif

		case $operation_mode = "verify" and $verify_single_file_mode
			$result = VerifyHashes($path)

		case $operation_mode = "verify" and $do_recurse
			$result = VerifyHashes($path, true)

		case $operation_mode = "verify"
			$path_already_exists_flag = true
			$result = VerifyHashFile($path)

		case $operation_mode = "create" and $verify_single_file_mode
			$result = CreateHashes($path)

		case $operation_mode = "create" and $do_recurse
			$result = CreateHashes($path, true)

		case $operation_mode = "create"
			$result = CreateSingleHash($path)
			if $hash_file_active then CloseHashFile($current_file_handle)

		case else
			NothingToDo()
			CheckVersionAndExit($exit_code_value)
	endselect



#EndRegion	******************    END MODE SELECTION    ************************



if not $elapsed_time_seconds then $elapsed_time_seconds = Round(TimerDiff($process_start_timer) / 1000, 2)
debug("end time: " & $elapsed_time_seconds, @ScriptLineNumber, 5)

DoFinalReportDialog()


if $fallback_mode_active then
	if $quiet_operation = $ON then
		debug("read-only conditions, fall-back applied: ----->	EXIT -1" , @ScriptLineNumber, 1)
		exit -1
	else
		if not WinExists($fallback_folder) then
			$my_msg = _T("read-only media warning")
			$full_text = _T("At least one of the checked files was stored on read-only media\n\nYour hashes are in your fallback folder.\n\nWould you like to open that folder right now?")
			local $ln = MsgBox($MB_YESNO + $MB_ICONINFORMATION + $MB_TOPMOST, $app_name & " ~ " & $my_msg, _
			StringUpper($my_msg) & @LF & @LF & _L($full_text), $dialog_timeout)
			if $ln = $IDYES then Run("Explorer.exe " & $fallback_folder)
			$exit_code_value = -1
		endif
	endif
endif


;
;	FIN!			"B:\Test\NO-PERMISSION\PS3 Baby_360p [2021-03-31].mkv"

CheckVersionAndExit($exit_code_value)




; Dig()
;
; Recursively scans a directory tree collecting files matching a glob mask with
; exclusion patterns and size limits into arrays.
func Dig($dir, $mask = "*.*", $no_recurse = false, $out_file = false, $return_dirs = false, $matched_dirs_only = false, $my_exclude_masks = false, $chunk_size = 1000000)

	if $mask = default then $mask = "*.*"
	if $no_recurse = default then $no_recurse = false
	if $out_file = default then $out_file = false
	if $return_dirs = default then $return_dirs = false
	if $matched_dirs_only = default then $matched_dirs_only = false
	if $my_exclude_masks = default then $my_exclude_masks = false
	if $chunk_size = default then $chunk_size = 1000000
	if $chunk_size > ($MAX_PATHS - 2) then $chunk_size = $MAX_PATHS - 2
	if StringRight($dir, 1) = "\" then $dir = StringTrimRight($dir, 1)
	if StringLeft($dir, 3) <> "\\?" then $dir = ConvertToLongPathFormat($dir)
	if not _LFN_FileExists($dir) then return -1

	local $dir_idx = 0
	local $item
	local $handle
	local $dir_count = 1
	local $dir_match_count = 1
	local $file_match_count = 1
	local $step = $chunk_size
	local $dirs[$step + 2] = [1, $dir]
	local $matched_dirs[$step + 2]
	local $files[$step + 2]
	local $is_dir

	$mask = GlobToRegexPattern($mask)
	if $my_exclude_masks then
		$my_exclude_masks = StringReplace($my_exclude_masks, ",", ";")
		$my_exclude_masks = GlobToRegexPattern($my_exclude_masks)
	endif

	while $dir_count > $dir_idx

		if $user_quit then return $status_result_codes[0]
		$dir_idx += 1
		$handle = OpenFileSearchHandle($dirs[$dir_idx] & "\*")

		if $user_quit then return $status_result_codes[0]

		while 1

			$item = FileFindNextFile($handle)
			$is_dir = @extended

			if @error then
				FileClose($item)
				exitloop
			endif

			local $name = $item
			$item = $dirs[$dir_idx] & "\" & $item

			; Ignore NTFS Junctions?
			if $ignore_symlinks = $ON and BitAND(_WinAPI_GetFileAttributes($item), $FILE_ATTRIBUTE_REPARSE_POINT) then continueloop

			if $is_dir and not $no_recurse then
				if $my_exclude_masks and StringRegExp($name, $my_exclude_masks) then continueloop
				$dir_count += 1
				$dirs[0] = $dir_count
				if Mod($dir_count, $step) = 0 then
					if ($dir_count + $step + 1) <= $MAX_PATHS then
						redim $dirs[$dir_count + $step + 1]
					else
						redim $dirs[$MAX_PATHS]
					endif
				endif
				$dirs[$dir_count] = $item
			endif
		wend

		FileClose($handle)

		$is_dir = false
		$handle = OpenFileSearchHandle($dirs[$dir_idx] & "\*")

		if $handle = -1 then continueloop
		if @error then
			FileClose($handle)
			exitloop
		endif

		while 1
			$item = FileFindNextFile($handle)
			$is_dir = @extended
			if @error then
				FileClose($item)
				exitloop
			endif

			if not StringRegExp($item, $mask) then continueloop

			$item = $dirs[$dir_idx] & "\" & $item

			; Ignore NTFS Symlink?
			if $ignore_symlinks = $ON and BitAND(_WinAPI_GetFileAttributes($item), $FILE_ATTRIBUTE_REPARSE_POINT) then continueloop

			if Mod($file_match_count, $step) = 0 then
				if ($file_match_count + $step + 1) <= $MAX_PATHS then
					redim $files[$file_match_count + $step + 1]
				else
					redim $files[$MAX_PATHS]
				endif
			endif

			if Mod($dir_match_count, $step) = 0 then
				if ($dir_match_count + $step + 1) <= $MAX_PATHS then
					redim $matched_dirs[$dir_match_count + $step + 1]
				else
					redim $matched_dirs[$MAX_PATHS]
				endif
			endif

			if not $is_dir then
				$files[0] = $file_match_count
				$files[$file_match_count] = $item
				$file_match_count += 1
				if $file_match_count > $MAX_PATHS then return -999
			else
				$matched_dirs[0] = $dir_match_count
				$matched_dirs[$dir_match_count] = $item
				$dir_match_count += 1
				if $dir_match_count > $MAX_PATHS then return -999
			endif
		wend

		FileClose($handle)

	wend

	local $my_result = false
	if $return_dirs then
		if $matched_dirs_only then
			redim $matched_dirs[$dir_match_count]
			if $matched_dirs[0] > 0 then $my_result = $matched_dirs
		else
			redim $dirs[$dir_count + 1]
			if $dirs[0] > 0 then $my_result = $dirs
		endif
	else
		redim $files[$file_match_count]
		if $files[0] > 0 then $my_result = $files
		if not IsArray($my_result) then return $status_result_codes[2] ; BUG! what is 0?? QUIT! so, needs to be something else.
	endif

	if $out_file then
		local $out_handle = OpenFileHandle($out_file, $FO_OVERWRITE)
		if IsArray($my_result) then
			local $i
			for $i = 1 to $my_result[0]
				_LFN_FileWrite($out_handle, $my_result[$i] & $LF)
			next
		endif
		FileClose($out_handle)
	endif

	return $my_result
endfunc




;
; Gatherswitches()

; Gather up and proccess all the switches from the command-line..
;
func Gatherswitches()

	debug($LF, @ScriptLineNumber, 5)
	debug("Gatherswitches() initial switches =>" & $switches & "<=", @ScriptLineNumber, 5)
	debug("path =>" & $path & "<=", @ScriptLineNumber, 5)

	SetTrayTip( _T("checksum is gathering user preferences.."))

	; Upgrade legacy hash files..
	if StringInStr($switches, "upgrade") then

		$operation_mode = "upgrade"
		$switches = StringReplace($switches, "upgrade", "")

		local $check_upgrade_all = IniReadCheckBox($ini_path, "dialogs", "upgrade_all_hashes", -1)
		debug("$check_upgrade_all =>" & Human($check_upgrade_all) & "<=", @ScriptLineNumber, 5)

		if $check_upgrade_all == -1 then
			; Upgrade ALL Yes/No..
			$my_msg = _T("Upgrade ALL hashes to {{SHA256}}?")
			$full_text = _T("checksum can upgrade legacy hash files with {{.md5}}, {{.sha1}}, {{.crc}} and {{.sfv}} extensions, verifying and re-computing their hashes with {{SHA256}} whilst retaining their existing structure.\n\nProcessed files are then given a {{.sha2}} extension.\n\nNote: This setting will be remembered and you won't be asked again.\n\nUpgrade ALL hash files?")
			local $ask_upgrade_all = MsgBox($MB_YESNOCANCEL + $MB_ICONWARNING + $MB_TOPMOST, $my_msg, _L($full_text))
			switch $ask_upgrade_all
				case $IDYES
					$upgrade_all_hashes = $ON
				case $IDNO
					$upgrade_all_hashes = $OFF
				case else
					exit 80
			endswitch
			IniWriteCheckBox($ini_path, "dialogs", "upgrade_all_hashes", $upgrade_all_hashes)
		else
			$upgrade_all_hashes = $check_upgrade_all
		endif
		debug("$upgrade_all_hashes =>" & Human($upgrade_all_hashes) & "<=", @ScriptLineNumber, 5)

		local $check_upgrade_log_all = IniReadCheckBox($ini_path, "dialogs", "upgrade_log_all", -1)
		debug("$check_upgrade_log_all =>" & Human($check_upgrade_log_all) & "<=", @ScriptLineNumber, 5)
		if $check_upgrade_log_all == -1 then
			$my_msg = _T("Log ALL hash upgrade operations?")
			$full_text = _T("If there any issues during the upgrade, checksum will log details to the working direcory. \n\nIf you prefer, you can log ALL details.")
			local $ask_upgrade_log_all = MsgBox($MB_YESNOCANCEL + $MB_ICONWARNING + $MB_TOPMOST, $my_msg, _L($full_text) & @LF & @LF & $my_msg)
			switch $ask_upgrade_log_all
				case $IDYES
					$upgrade_log_all = $ON
				case $IDNO
					$upgrade_log_all = $OFF
				case else
					exit 88
			endswitch
			IniWriteCheckBox($ini_path, "dialogs", "upgrade_log_all", $upgrade_log_all)
		else
			$upgrade_log_all = $check_upgrade_log_all
		endif
		debug("$upgrade_log_all =>" & Human($upgrade_log_all) & "<=", @ScriptLineNumber, 5)

	endif


	if StringInStr($switches, "v") then $operation_mode = "verify"
	if $pause = 0 and not StringInStr($switches, "-n") then $switches &= "n"

	ProcessSwitch($progress_tip, $ON, "t")
	ProcessSwitch($beep_alerts, $ON, "b")
	ProcessSwitch($quiet_operation, $ON, "q")
	ProcessSwitch($do_exit_command, $ON, "0")

	if not _LFN_FileExists($path) then
		if not StringInStr($switches, "q") then
			$my_msg = _T("Path does not exist!")
			$full_text = _T("If I attempt to hash in a non-existant path, bad things will surely happen.")
			MsgBox($MB_TOPMOST + $MB_ICONERROR, $my_msg, $my_msg & @LF & @LF & $full_text, $dialog_timeout)
		endif
		debug("non-existent path: ----->	EXIT 6" , @ScriptLineNumber, 1)
		exit 6
	endif

	if $operation_mode = "create" then
		for $i = 1 to $hash_algorithms[0]
			if StringInStr($switches, "-" & $algo_switch_letters[$i]) then $switches = StringReplace($switches, "-" & $algo_switch_letters[$i], "")
		next
		; An explicitly-supplied algorithm letter wins; only append the
		; ini-default letter when the user did not specify one.
		local $has_algo_switch = false
		for $i = 1 to $hash_algorithms[0]
			if StringInStr($switches, $algo_switch_letters[$i]) then $has_algo_switch = true
		next
		if not $has_algo_switch then
			local $default_algo_id = _ArraySearch($hash_algorithms, $algorithm, 1)
			if $default_algo_id < 1 then $default_algo_id = DefaultAlgoID()
			$switches &= $algo_switch_letters[$default_algo_id]
		endif
		ProcessSwitch($uppercase, $ON, "u")
		ProcessSwitch($always_sync, $ON, "y")
		ProcessSwitch($file_extensions, $ON, "e")
		ProcessSwitch($individual_hashes, $ON, "i")
		ProcessSwitch($absolute_paths, $ON, "k")
		ProcessSwitch($one_hash, $ON, "1")
		ProcessSwitch($hide_checksums, $ON, "h")
		if StringInStr($switches, "1") then
			if StringInStr($switches, "i") then $switches = StringReplace($switches, "i", "")
			if StringInStr($switches, "e") then $switches = StringReplace($switches, "e", "")
		else
			if StringInStr($switches, "k") then $switches = StringReplace($switches, "k", "")
		endif

	endif

	if $operation_mode = "verify" then
		ProcessSwitch($log_to_file, $ON, "f")
		ProcessSwitch($log_everything, $ON, "l")
		if StringInStr($switches, "l") and not StringInStr($switches, "f") then $switches &= "f"
		ProcessSwitch($open_log_folder, $ON, "g")
		ProcessSwitch($delete_missing_hashes, $ON, "x")
		ProcessSwitch($update_changed_hashes, $ON, "w")
		ProcessSwitch($search_and_verify, $ON, "i")
		if $mail_on_failure = $ON and not StringInStr($switches, "e") then
			$switches &= "e"
			if not StringInStr($switches, "q") then $switches &= "q"
		endif
		if StringInStr($switches, "-e") then $switches = StringReplace($switches, "-e", "")
	endif

	ProcessSwitch($shutdown_when_done, $ON, "z")
	debug("Gatherswitches() FINAL switches =>" & $switches & "<=", @ScriptLineNumber, 5)
endfunc

; Helper function to save repetative code..
func ProcessSwitch(byref $my_var, $expected_value, $my_switch)
	if $my_var = $expected_value and not StringInStr($switches, $my_switch) then $switches &= $my_switch
	if StringInStr($switches, "-" & $my_switch) then $switches = StringReplace($switches, "-" & $my_switch, "")
endfunc



;
; SwitchesToVars()

; Parses all single-character CLI flags into global runtime variables: e.g.
; algorithm selection (s=sha1/2=sha2), mode flags (q/r/n/t/b/0/a), logging
; options (f/l/w/x/m/i/g/z) for both create and verify modes, etc..
;
func SwitchesToVars()

	debug($LF, @ScriptLineNumber, 5)
	debug("SwitchesToVars() ---> switches: =>" & $switches & "<=" , @ScriptLineNumber, 5)

	if $operation_mode = "verify" then
		$mail_on_failure = $OFF
		if StringInStr($switches, "e") then
			$mail_on_failure = $ON
			if not StringInStr($switches, "q") then $switches &= "q"
		endif
	endif

	$quiet_operation = $OFF
	if StringInStr($switches, "q") then
		$quiet_operation = $ON
		local $lt = StringInStr($switches, "q")
		local $lu = StringMid($switches, $lt + 1, 1)
		if $lu = "+" then $sync_choice = "yes_all"
		if not StringInStr($switches, "f") then $switches &= "f"
	endif

	if StringInStr($switches, "r") then
		if $do_recurse then
			$verify_single_file_mode = true
		else
			if $quiet_operation = $OFF then
				$my_msg = _T("Path Error!")
				$full_text = _T("Not a directory!\n\nYou cannot use the {{'r'}} (recurse) switch on a regular file!")
				MsgBox($MB_TOPMOST + $MB_ICONERROR, $my_msg, _L($full_text), $dialog_timeout)
				debug("recurse on regular file!: ----->	EXIT 9" , @ScriptLineNumber, 1)
				exit 9
			endif
		endif
	endif

	if StringInStr($switches, "n") and not StringInStr($switches, "-n") then $pause = 0

	SwitchOn($progress_tip, "t")
	SwitchOn($beep_alerts, "b")
	SwitchOn($do_exit_command, "0")
	SwitchOn($shutdown_when_done, "z")

	if $operation_mode = "create" then

		$algorithm_id = AlgoIDFromSwitches()
		$algorithm = $hash_algorithms[$algorithm_id]

		if $unified_extension = $ON then
			$hashfile_extension = "." & $unihash_extension
		else
			$hashfile_extension = "." & $algorithm
		endif

		if StringInStr($switches, "y") and $do_recurse then
			$process_existing_hashes = true
			$sync_choice = "sync"
		endif

		SwitchOn($uppercase_hashes, "u")
		SwitchOn($file_extensions, "e")
		SwitchOn($individual_hashes, "i")
		SwitchOn($one_hash, "1")
		SwitchOn($absolute_paths, "k")
		SwitchOn($hide_checksums, "h")

		if $do_recurse then
			if StringInStr($switches, "3") or StringInStr($switches, "p") then $is_playlist_mode = true
			if StringInStr($switches, "p") then $playlist_type = "pls"
			InitializePlaylistMode()
		endif

	endif


	if $operation_mode = "verify" then

		local $verify_algo_id = AlgoIDFromVerifySwitch()

		if $verify_algo_id then
			$algorithm = $hash_algorithms[$verify_algo_id]
			$hash_extensions = MakeDummyArray($algorithm)
			if $verify_algo_id = 4 then
				redim $hash_extensions[3]
				$hash_extensions[0] = 2
				$hash_extensions[2] = "sfv"
			endif
			SetHashFileExtensionPattern()
		endif

		SwitchOn($log_to_file, "f")
		$log_everything = $OFF
		if StringInStr($switches, "l") then
			$log_everywhere_flag = 2
			$log_to_file = $ON
		endif

		SwitchOn($open_log_folder, "g")
		SwitchOn($delete_missing_hashes, "x")
		SwitchOn($check_only_new_files, "m")
		SwitchOn($update_changed_hashes, "w")
		SwitchOn($search_and_verify, "i")

	endif

endfunc

; SwitchesToVars() helper function.
func SwitchOn(byref $my_var, $my_switch)
	$my_var = $OFF
	if StringInStr($switches, $my_switch) then $my_var = $ON
endfunc



;
; SetCustomHashFileName()

; Got a 'j' in the command-line switches..
;
func SetCustomHashFileName()
	debug($LF, @ScriptLineNumber, 5)
	debug("GetCustomName BEGIN (switches): " & $switches, @ScriptLineNumber, 5)
	$hashfile_name = StringStripWS(ExtractSwitchGroup("j", $hashfile_name), $STR_STRIP_ENDS)
	debug("SetCustomHashFileName() --> hashfile_name: " & $hashfile_name, @ScriptLineNumber, 5)
	debug("GetCustomName() FINISH (switches): " & $switches, @ScriptLineNumber, 5)
endfunc



;
; FormatPathForDisplay

; Returns original path if UNC display enabled, otherwise strips long-path
; prefix for human-readable output
;
func FormatPathForDisplay($my_path)
	if $show_unc_paths = $ON then
		return $my_path
	else
		return StripLongPathPrefix($my_path)
	endif
endfunc






func _____________CREATE_AND_VERIFY_HASHES()
endfunc



;
; CreateHashes()

; Main entry point for create mode: processes command-line paths, creates root
; hashes, folder hashes and per-file hashes recursively through directory tree.
;
func CreateHashes($my_path, $recurse_flag=false)

	debug("CreateHashes(my_path =>" & $my_path & "<= 	...		recurse_flag=>" & $recurse_flag  & "<==)", @ScriptLineNumber, 5)

	if StringRight($my_path, 1) <> "\" then $my_path &= "\"
	if $out_dir then
		$root_writeable = TestWriteable($out_dir)
	else
		$root_writeable = TestWriteable($my_path)
	endif
	debug($LF, @ScriptLineNumber, 5)
	debug("CreateHashes() absolute_paths =>" & Human($absolute_paths) & "<=", @ScriptLineNumber, 6)

	local $my_create_msg

	if $root_writeable = false then
		switch $fallback_level
			case 1
				if $one_hash = $OFF then $one_hash = $ON
			case 2
				if $one_hash = $OFF then $one_hash = $ON
				if $absolute_paths = $OFF then $absolute_paths = $ON
			case else
		endswitch
		debug("USING FALL-BACK LEVEL =>" & $fallback_level & "<=", @ScriptLineNumber, 6)
	endif
	debug("absolute_paths =>" & Human($absolute_paths) & "<=", @ScriptLineNumber, 6)

	$my_create_msg = _T("checksum is building a list of files for")
	$my_create_msg = $my_create_msg & " " & FormatPathForDisplay($my_path) & " .. "
	DoProgressTips($my_create_msg)

	if $one_hash = $ON then

		local $my_hashfile_created, $my_hashfile_path
		local $my_hashes = Dig($my_path, $file_mask, false, "", false, false, $exclude_masks, $memory_tuning)

		SetTrayTip(_T("checksum is creating hashes.."))

		if not IsArray($my_hashes) then return 0
		if StringRight($my_path, 1) = "\" then $my_path = StringTrimRight($my_path, 1)

		if $out_dir then
			$my_hashfile_created = CreateNewHashFile($out_dir & "\" & BaseName($my_path), true, true, $my_hashes[0], $my_path)
		else
			$my_hashfile_created = CreateNewHashFile($my_path & "\" & BaseName($my_path), true, true, $my_hashes[0])
		endif

		if $my_hashfile_created then
			if $out_dir then
				$my_hashfile_path = $out_dir & "\" & BaseName($my_path) & $hashfile_extension
			else
				$my_hashfile_path = $my_path & "\" & BaseName($my_path) & $hashfile_extension
			endif

			$do_sync = false
			local $existing_hash_list = 0
			local $original_hash_list = 0

			if $process_existing_hashes then
				debug("GetHashesFromFile()  $hashfile_path =>" & $hashfile_path & "<=", @ScriptLineNumber, 6)
				$existing_hash_list = GetHashesFromFile($hashfile_path)
				debugPrintArray($existing_hash_list, "$existing_hash_list:", @ScriptLineNumber, 9)
				if $hashfile_path <> $my_hashfile_path then
					debug("GetHashesFromFile()  $my_hashfile_path =>" & $my_hashfile_path & "<=", @ScriptLineNumber, 6)
					$original_hash_list = GetHashesFromFile($my_hashfile_path)
				endif
			endif

			if (IsArray($existing_hash_list) and $existing_hash_list[0]) or ($resync_readonly = $OFF and IsArray($original_hash_list) and $original_hash_list[0]) then
				$do_sync = true
				$my_create_msg = _T("checksum is extracting all possible file matches in the root hash file..")
				DoProgressTips($my_create_msg)
				if IsArray($existing_hash_list) then $existing_hash_list = MakeSearchList($existing_hash_list, $my_path, $algorithm_id)
				if $user_quit then return $status_result_codes[0] ; "quit"
				if IsArray($original_hash_list) then $original_hash_list = MakeSearchList($original_hash_list, $my_path, $algorithm_id)
			endif

			$my_create_msg = _T("checksum is checking files against existing root hashes..")
			DoProgressTips($my_create_msg)
			for $t = 1 to $my_hashes[0]
				if $user_quit then return $status_result_codes[0]
				if FindInStringArray($ignore_types, GetExtension($my_hashes[$t])) then continueloop
				if FindInStringArray($ignore_files, BaseName($my_hashes[$t])) then continueloop
				if $do_sync then
					local $match_index
					$match_index = _ArrayBinarySearch($existing_hash_list, $my_hashes[$t], 1)
					if $match_index <> -1 then continueloop
					if $resync_readonly = $OFF then
						$match_index = _ArrayBinarySearch($original_hash_list, $my_hashes[$t], 1)
						if $match_index <> -1 then continueloop
					endif
				endif
				AddtoRootHashes($my_hashes[$t], $t, $my_hashes[0])
				if $do_sync then SlowProgressUpdate("checksum is checking files against existing root hashes.. ")
			next

			CloseHashFile($current_file_handle)
			FinalizePlaylistFile($hashfile_path)

			$my_msg = _T("checksum completed root hash file:")
			$my_create_msg = $my_msg & " " & FormatPathForDisplay($my_hashfile_path)
			DoProgressTips($my_create_msg)

		endif

		if not $hash_written and not $hashfile_created then
			$fallback_mode_active = false
			if $nfo_file_written then
				DeleteFilesRecursive($fallback_folder & "\checksums.nfo.txt")
				if $fallback_dirs_created then
					_LFN_DirRemove($fallback_folder)
				endif
			endif
		endif
		if $user_quit then return $status_result_codes[0]

	else

		$my_hashes = Dig($path, $file_mask, $recurse_flag, "", true, false, $exclude_masks, $memory_tuning)
		SetTrayTip(_T("checksum is creating hashes.."))
		if $my_hashes = $status_result_codes[0] then return $status_result_codes[0]

		if $individual_hashes = $ON then
			if IsArray($my_hashes) then
				for $t = 1 to $my_hashes[0]
					CreateFolderSingleHashes($my_hashes[$t], $t, $my_hashes[0])
					if $user_quit then return $status_result_codes[0]
				next
			endif
		else
			if IsArray($my_hashes) then
				for $t = 1 to $my_hashes[0]
					CreateFolderHash($my_hashes[$t], $t, $my_hashes[0])
					if $user_quit then return $status_result_codes[0]
				next
			endif
		endif
	endif

endfunc


;
; AddtoRootHashes()

; Appends a file hash to a root hash file.
;
func AddtoRootHashes($file, $item="", $total="")

	debug($LF, @ScriptLineNumber, 6)
	debug("AddtoRootHashes $file      --->" & $file & "<=", @ScriptLineNumber, 6)
	debug("AddtoRootHashes $item      --->" & $item & "<=", @ScriptLineNumber, 6)
	debug("AddtoRootHashes $total     --->" & $total & "<=", @ScriptLineNumber, 6)
	debug("AddtoRootHashes $path      --->" & $path & "<=", @ScriptLineNumber, 6)

	if $hash_file_active then

		local $file_time = ""
		if $check_dates = $ON then
			$file_time = _LFN_FileGetTime($file)
		endif
		if $progress_tip = $ON then
			local $progress_prefix = ""
			if $item then $progress_prefix = "[" & $item & " " & _T("of") & " " & $total & "] "
			$my_msg = _T("checksum is creating")
			local $my_create_msg = $my_msg & " " & $algorithm_strings[$algorithm_id] & " " & _T("hash") & ": " & $progress_prefix & ".. " & BaseName($file)
			DoProgressTips($my_create_msg)
		endif

		local $rel_path

		if $absolute_paths = $ON then
			$rel_path = $file
		else
			if StringRight($path, 1) <> "\" then $path &= "\"
			local $nix_prefix = ""
			if $nix_paths = $ON then $nix_prefix = "./"
			$rel_path = StringReplace($file, $path, $nix_prefix, 1)
			if $nix_paths = $ON then $rel_path = StringReplace($rel_path, "\", "/")
		endif

		local $hash_val = HashFile($file, $algorithm_id, $uppercase_hashes)
		AddHashString($hash_val, $rel_path, $file_time, true)
		if $user_quit then return $status_result_codes[0] ; "quit"
	endif

endfunc



;
; ExtractSwitchGroup()

; Finds a single-letter switch key, e.g. "*(value)" in the switches, extracts
; the value between delimiters and removes it from the switches.
;
func ExtractSwitchGroup($switch_key, $default, $last_delim=false)

	debug($LF, @ScriptLineNumber, 6)
	debug("ExtractSwitchGroup() --> switch_key: " & $switch_key & "     default: "  & $default & "    last_delim: " & $last_delim , @ScriptLineNumber, 6)

	if not StringInStr($switches, $switch_key & "(") then return $default
	local $val, $my_switches = $switches
	local $start = StringInStr($my_switches, $switch_key & "(") + 2
	$val = StringMid($my_switches, $start)

	if $last_delim then
		$val = StringMid($val, 1, StringInStr($val, ")", 2, -1) - 1)
	else
		$val = StringMid($val, 1, StringInStr($val, ")") - 1)
	endif
	debug("switches: =>" & $switches & "<=" , @ScriptLineNumber, 6)

	$switches = StringReplace($my_switches, $switch_key & "(" & $val & ")", "")
	debug("switches: =>" & $switches & "<=" , @ScriptLineNumber, 6)
	debug("Returning $val: =>" & $val & "<=" , @ScriptLineNumber, 6)

	return SetError(0, ($switch_key == "p"), $val)

endfunc




;
; CreateFolderHash()

; Recursively hashes all files in a directory tree, writing folder hashes.
;
func CreateFolderHash($folder_path, $item="", $total="")

	debug($LF, @ScriptLineNumber, 6)
	debug("CreateFolderHash() $folder_path  --->" & $folder_path & "<=", @ScriptLineNumber, 6)
	debug("CreateFolderHash() $item         --->" & $item & "<=", @ScriptLineNumber, 6)
	debug("CreateFolderHash() $total        --->" & $total & "<=", @ScriptLineNumber, 6)

	if TestDirectoryAccessible($folder_path) then return -1
	local $file_list = Dig($folder_path, $file_mask, true, "", false, false, $exclude_masks, $memory_tuning)
	if not IsArray($file_list) then return -1
	local $my_create_msg
	local $has_valid_files = false

	for $i = 1 to $file_list[0]
		if not FindInStringArray($ignore_types, GetExtension($file_list[$i])) and not FindInStringArray($ignore_files, BaseName($file_list[$i])) then
			$has_valid_files = true
			exitloop
		endif
	next

	if not $has_valid_files then return -1

	local $my_hashfile_created
	if $out_dir then
		$my_hashfile_created = CreateNewHashFile($out_dir & "\" & BaseName($folder_path), true, default, $file_list[0], $folder_path)
	else
		$my_hashfile_created = CreateNewHashFile($folder_path & "\" & BaseName($folder_path), true, default, $file_list[0])
	endif
	debug("CreateFolderHash => $created: =>" & Human($my_hashfile_created) & "<=", @ScriptLineNumber, 6)

	if not $my_hashfile_created then return 0
	debug("hashfile_loc =>" & $hashfile_path & "<=", @ScriptLineNumber, 6)

	$do_sync = false
	local $original_hashes = 0
	local $existing_hashes = 0
	local $hash_file_name = BaseName($hashfile_path)
	local $local_hash_file = $folder_path & "\" & $hash_file_name
	debug("my_hash_file =>" & $local_hash_file & "<=", @ScriptLineNumber, 6)

	if $process_existing_hashes then
		debug("CreateFolderHash(existing_hashes) GetHashesFromFile =>" & $hashfile_path & "<=", @ScriptLineNumber, 6)
		$existing_hashes = GetHashesFromFile($hashfile_path)
		if $hashfile_path <> $local_hash_file and _LFN_FileExists($local_hash_file) then
			debug("CreateFolderHash(original_hashes) GetHashesFromFile =>" & $local_hash_file & "<=", @ScriptLineNumber, 6)
			$original_hashes = GetHashesFromFile($local_hash_file)
		endif
	endif

	if (IsArray($existing_hashes) and $existing_hashes[0]) or (IsArray($original_hashes) and $original_hashes[0]) then
		$do_sync = true
		debug("do_sync =>" & Human($do_sync) & "<=", @ScriptLineNumber, 6)
		debug("Checking for matches =>", @ScriptLineNumber, 6)
		$my_create_msg = _T("checksum is searching for all possible path matches in folder hash file") & " " & FormatPathForDisplay($local_hash_file)
		DoProgressTips($my_create_msg)
		debugPrintArray($existing_hashes, "$existing_hashes", @ScriptLineNumber, 6)
		if IsArray($existing_hashes) then $existing_hashes = MakeSearchList($existing_hashes, $folder_path, $algorithm_id)
		debugPrintArray($existing_hashes, "$existing_hashes >?> SearchList", @ScriptLineNumber, 6)
		if $user_quit then return $status_result_codes[0] ; "quit"
		if IsArray($original_hashes) then $original_hashes = MakeSearchList($original_hashes, $folder_path, $algorithm_id)
		debugPrintArray($original_hashes, "$original_hashes >?> SearchList", @ScriptLineNumber, 6)
	endif

	for $i = 1 to $file_list[0]

		if $user_quit then return $status_result_codes[0] ; "quit"
		local $my_current_file = $file_list[$i]
		if FindInStringArray($ignore_types, GetExtension($my_current_file)) then continueloop
		local $my_current_file_name = BaseName($my_current_file)
		if FindInStringArray($ignore_files, $my_current_file_name) then continueloop

		if $do_sync then
			local $search_idx
			$search_idx = _ArrayBinarySearch($existing_hashes, $file_list[$i], 1)
			if $search_idx <> -1 then continueloop
			if $resync_readonly = $OFF then
				$search_idx = _ArrayBinarySearch($original_hashes, $file_list[$i], 1)
				if $search_idx <> -1 then continueloop
			endif
		endif

		if $hash_file_active then
			local $file_time = ""
			if $check_dates = $ON then
				$file_time = _LFN_FileGetTime($my_current_file)
			endif
			$my_msg = _T("checksum is creating hashes")
			$my_create_msg = $my_msg & " : [" & _T("folder") & ": " & $item & " " & _T("of") & " " & $total & "][" & _T("file") & ": " & $i & " " & _T("of") & " " & _
									$file_list[0] & "] " & FormatPathForDisplay($local_hash_file) & " : " & $my_current_file_name
			DoProgressTips($my_create_msg)
			local $hash_val = HashFile($my_current_file, $algorithm_id, $uppercase_hashes)
			AddHashString($hash_val, $my_current_file_name, $file_time)
		endif

		if $user_quit then return $status_result_codes[0] ; "quit"
		if $do_sync then
			$my_msg = _T("checksum is searching for possible path matches in folder hash file")
			$my_create_msg = $my_msg & ": " & $local_hash_file
			DoProgressTips($my_create_msg)
		endif

	next

	CloseHashFile($current_file_handle)
	FinalizePlaylistFile($hashfile_path)

endfunc


;
; CreateFolderSingleHashes()

; Creates individual hash files of all files in a directory matching our masks.
;
func CreateFolderSingleHashes($folder_path, $item="", $total="")

	debug($LF, @ScriptLineNumber, 6)
	debug("CreateFolderSingleHashes() $folder_path --->" & $folder_path & "<=", @ScriptLineNumber, 6)
	debug("CreateFolderSingleHashes() $item        --->" & $item & "<=", @ScriptLineNumber, 6)
	debug("CreateFolderSingleHashes() $total       --->" & $total & "<=", @ScriptLineNumber, 6)

	local $file_list = Dig($folder_path, $file_mask, true, "", false, false, $memory_tuning)
	if not IsArray($file_list) then return -1

	local $folder_prefix = ""
	if $item <> "" and $total <> "" then $folder_prefix = "[" & _T("folder") & " " & $item & " " & _T("of") & " " & $total & "]"

	for $i = 1 to $file_list[0]
		if $progress_tip = $OFF then
			CreateSingleHash($file_list[$i])
		else
			CreateSingleHash($file_list[$i], $i, $file_list[0], $folder_prefix, BaseName($folder_path))
		endif
		if $hash_file_active then CloseHashFile($current_file_handle)
		if $user_quit then return $status_result_codes[0] ; "quit"
	next

endfunc



;
; CreateSingleHash()

; Computes and records a single hash for one specific file.
;
func CreateSingleHash($file, $item="", $total="", $prefix="", $dir_name="")

	debug($LF, @ScriptLineNumber, 6)
	debug("CreateSingleHash() file   	  --->" & $file & "<=", @ScriptLineNumber, 6)
	debug("CreateSingleHash() item        --->" & $item & "<=", @ScriptLineNumber, 6)
	debug("CreateSingleHash() total       --->" & $total & "<=", @ScriptLineNumber, 6)
	debug("CreateSingleHash() prefix      --->" & $prefix & "<=", @ScriptLineNumber, 6)
	debug("CreateSingleHash() dir_name    --->" & $dir_name & "<=", @ScriptLineNumber, 6)

	if $out_dir then
		$root_writeable = TestWriteable($out_dir)
	else
		$root_writeable = TestWriteable(GetLongParentDir($file))
	endif

	local $file_name = BaseName($file)

	if not FindInStringArray($ignore_types, GetExtension($file)) and not FindInStringArray($ignore_files, $file_name) then

		local $target_name = $file_name
		local $parent_path = GetLongParentDir($file)
		if RemoveExtension($file_name) = "" then $target_name = $nameless_name & $target_name

		local $my_hashfile_created
		if $out_dir then
			$my_hashfile_created = CreateNewHashFile($out_dir & "\" & $target_name, default, default, 1, $file)
		else
			$my_hashfile_created = CreateNewHashFile($parent_path & "\" & $target_name, default, default, 1)
		endif
		debug("created =>" & Human($my_hashfile_created) & "<=", @ScriptLineNumber, 6)
		if $my_hashfile_created == $status_result_codes[0] then return $status_result_codes[0] ; "quit"
		if not $my_hashfile_created then return 0

		if $hash_file_active then
			local $file_time = ""
			if $check_dates = $ON then
				$file_time = _LFN_FileGetTime($file)
			endif

			if $progress_tip = $ON then
				local $progress_msg = ""
				if $prefix then $progress_msg &= $prefix
				if $item then $progress_msg &= "[" & _T("file") &" " & $item & " " & _T("of") & " " & $total & "] : "
				if $dir_name then $progress_msg &= $dir_name & "\"
				$my_msg = _T("checksum is creating a")
				local $my_create_msg = $my_msg & " " & $algorithm_strings[$algorithm_id] & " hash : " & $progress_msg & $file_name
				DoProgressTips($my_create_msg)
			endif
			local $hash_val = HashFile($file, $algorithm_id, $uppercase_hashes)
			debug("CreateSingleHash()  ==> add value:" & $hash_val & "    basename:" & $file_name & "    info:" & $file_time & "<=", @ScriptLineNumber, 6)
			debug("CreateSingleHash()  ==> existing_hashes_lookup =>" & $existing_hashes_lookup & "<=", @ScriptLineNumber, 6)
			if $legacy_ext_rename_count then
				if StringInStr($existing_hashes_lookup, $file_name) then return
			endif
			AddHashString($hash_val, $file_name, $file_time)
		endif
	endif
endfunc


;
; CreateNewHashFile()

; Opens and initializes a new hash file for writing, writes preamble header, if
; configured in ini settings. Performs MANY checks before writing!

func CreateNewHashFile($hash_file, $is_folder=false, $is_single_file=false, $expected_lines=1, $original_item=default)

	debug($LF, @ScriptLineNumber, 5)
	debug("CreateNewHashFile($hash_file)       --->" & $hash_file & "<=", @ScriptLineNumber, 5)
	debug("CreateNewHashFile($is_folder)       --->" & $is_folder & "<=", @ScriptLineNumber, 5)
	debug("CreateNewHashFile($is_single_file)  --->" & $is_single_file & "<=", @ScriptLineNumber, 5)
	debug("CreateNewHashFile($expected_lines)  --->" & $expected_lines & "<=", @ScriptLineNumber, 5)

	if $original_item = default then $original_item = $hash_file
	debug("CreateNewHashFile($original_item)   --->" & $original_item & "<=", @ScriptLineNumber, 5)

	if $is_folder = default then $is_folder = false
	if $is_single_file = default then $is_single_file = false
	local $my_create_msg

	; Attempt to determine if there is enough free space for this hash file..
	local $est_bytes = 260
	if $do_timestamp = $ON then $est_bytes = 568

	$est_bytes = $est_bytes + AlgoHexLen($algorithm_id)

	$est_bytes = ($est_bytes * $expected_lines) + 141
	local $unc_share = GetUncServerAndShare($hash_file)
	if (DriveSpaceFree($unc_share) * 1048576) < $est_bytes then
		$my_msg = _T("Out of Space!")
		$full_text = _T("will probably run out of space before completion!\n\nPlease make some space on the drive before hashing, or select\nan alternative output directory (one with plenty space).")
		local $str_exit = _T("checksum will now exit.")
		MsgBox($MB_TOPMOST + $MB_ICONERROR, $my_msg, $my_msg & @LF & @LF & $unc_share & _L($full_text) & @LF & @LF & _L($str_exit), $dialog_timeout)
		$user_quit = true
		return
	endif

	$current_file_handle = 0
	$hash_written = false
	$hashfile_created = false
	local $is_writable = false
	local $has_legacy_hash = false
	local $ext_suffix = ""
	local $attribs
	$hash_file_active = true

	if $is_folder then
		local $base_path = $hash_file
		if $is_playlist_mode then
			$is_playlist_enabled = $is_playlist_mode
			if _LFN_FileExists($hash_file & "." & $playlist_type) then $is_playlist_enabled = false
		endif
		if $unified_extension = $ON then
			if _LFN_FileExists($hash_file & "." & $algorithm) then
				if MoveFilesRecursive($hash_file & "." & $algorithm, $hash_file & $hashfile_extension) then $legacy_ext_rename_count += 1
			endif
		endif
	else
		$base_path = RemoveExtension($hash_file)
		local $ext = GetExtension($hash_file)

		if $unified_extension = $ON then
			if $file_extensions = $ON then
				if _LFN_FileExists($base_path & "." & $ext & "." & $algorithm) then
					if MoveFilesRecursive($base_path & "." & $ext & "." & $algorithm, $base_path & $ext & $hashfile_extension) then $legacy_ext_rename_count += 1
				endif
			else
				if _LFN_FileExists($base_path & "." & $algorithm) then
					if MoveFilesRecursive($base_path & "." & $algorithm, $base_path & $hashfile_extension) then $legacy_ext_rename_count += 1
				endif
			endif
		endif

		if $file_extensions = $ON then $ext_suffix = "." & $ext
		if $file_extensions = $ON then
			if _LFN_FileExists($base_path & $hashfile_extension) then
				if MoveFilesRecursive($base_path & $hashfile_extension, $base_path & $ext_suffix & $hashfile_extension) then $extension_switched_count += 1
			endif
		else
			if _LFN_FileExists($base_path & "." & $ext & $hashfile_extension) then
				if MoveFilesRecursive($base_path & "." & $ext & $hashfile_extension, $base_path & $hashfile_extension) then $extension_switched_count += 1
			endif
		endif
	endif

	if $is_folder and $hashfile_name then
		if $out_dir then
			$hashfile_path = $out_dir & "\" & DeTokenize($hashfile_name, $original_item, "file") & $hashfile_extension
		else
			$hashfile_path = GetLongParentDir($hash_file) & "\" & DeTokenize($hashfile_name, $hash_file, "file") & $hashfile_extension
		endif
	else
		if $out_dir then
			$hashfile_path = $out_dir & "\" & BaseName($base_path) & $ext_suffix & $hashfile_extension
		else
			$hashfile_path = $base_path & $ext_suffix & $hashfile_extension
		endif
	endif

	if $unified_extension = $ON then
		local $legacy_hash_file = RemoveExtension($hashfile_path) & "." & $algorithm
		if _LFN_FileExists($legacy_hash_file) then $has_legacy_hash = true
	endif
	debug("has_legacy_hash =>" & Human($has_legacy_hash) & "<=", @ScriptLineNumber, 5)

	if $root_writeable <> false and $is_folder then
		$is_writable = TestWriteable(GetLongParentDir($hashfile_path))
	else
		$is_writable = $root_writeable
	endif

	if $is_writable = false then
		debug("WRITEABLE hashfile location ->" & $hashfile_path & "<-", @ScriptLineNumber, 5)
		local $inner_path = StripLongPathPrefix($hashfile_path)
		debug("inner_path =>" & $inner_path & "<=", @ScriptLineNumber, 5)
		select
			case StringMid($inner_path, 2, 1) = ":"
				$inner_path = StringReplace($inner_path, ":", "")
			case StringLeft($inner_path, 2) = "\\"
				$inner_path = StringReplace($inner_path, "\\", "")
		endselect
		if StringLeft($inner_path, 1) <> "\" then $inner_path = "\" & $inner_path
		$fallback_folder = DeTokenize($fallback_folder, $path, "path")
		debug("fallback_folder =>" & $fallback_folder & "<=", @ScriptLineNumber, 5)
		$hashfile_path = $fallback_folder & $inner_path
	endif
	debug("hashfile location ->" & $hashfile_path & "<-", @ScriptLineNumber, 5)

	if _LFN_FileExists($hashfile_path) then

		if not $is_folder then
			if $file_extensions = $ON then return 0
			if $file_extensions = $OFF then
				DoProgressTips(_T("checksum is scanning for matching files") & "..")
				local $is_already_present = AlreadyInHashFile($hashfile_path, $hash_file)
				debug("exist_already =>" & Human($is_already_present) & "<=", @ScriptLineNumber, 5)
				if $user_quit then return $status_result_codes[0] ; "quit"
				if $is_already_present then
					return false
				else
					$process_existing_hashes = true
					$hash_match_status_flag = $OFF
				endif
			endif
		endif

		if $hash_match_status_flag = "" and not $process_existing_hashes then
			$my_msg = _T("A checksum file has already been found..")
			$full_text = _T("Do you wish to overwrite this file? (not recommended)\n\nAlternatively, choose 'Synchronize' to add new new file hashes to\nexisting checksum files.\n\nNote: if you are creating multi-hash file, choose 'Synchronize'.")
			local $dialog_text = $my_msg & "    " & @LF & @LF & FormatPathForDisplay($hashfile_path) & @LF & @LF & _L($full_text)
			local $user_choice = ShowSyncDialog(_T("checksum file exists!"), $dialog_text, true, true, true, $is_single_file)
			debug("user_choice: =>" & $user_choice & "<=" , @ScriptLineNumber, 5)

			switch $user_choice
				case "yes"
					$hash_file_active = true
				case "yes_all"
					$hash_file_active = true
					$hash_match_status_flag = $ON
				case "no"
					$hash_file_active = false
				case "no_all"
					$hash_file_active = false
					$hash_match_status_flag = $OFF
				case "sync"
					$hash_file_active = true
					$hash_match_status_flag = $OFF
					$process_existing_hashes = true
				case else
					exit $status_result_codes[0] ; "quit"
			endswitch
		else
			if $hash_match_status_flag = $ON or $process_existing_hashes then
				$hash_file_active = true
			else
				$hash_file_active = false
			endif
		endif

		debug("is_writable: =>" & $is_writable & "<=" , @ScriptLineNumber, 5)
		debug("hash_file_active: =>" & $hash_file_active & "<=" , @ScriptLineNumber, 5)
		debug("process_existing_hashes: =>" & $process_existing_hashes & "<=" , @ScriptLineNumber, 5)

		if $process_existing_hashes then
			debug("Processing Existing Hashes..", @ScriptLineNumber, 5)

			$attribs = _LFN_FileGetAttrib($hashfile_path)
			_LFN_FileSetAttrib($hashfile_path, "-SH")
			$current_file_handle = OpenFileHandle($hashfile_path, $FO_APPEND + $utf8_file_mode_flag)
			if $current_file_handle <> -1 and Asc(StringRight(_LFN_FileRead($current_file_handle), 1)) > 31 then
				_LFN_FileWriteLine($current_file_handle, $LF)
			endif

			if $do_timestamp = $ON then
				_LFN_FileWriteLine($current_file_handle, $LF & "# checksum begins @ " & @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & "-" & @MIN & "-" & @SEC & $LF & $LF)
			endif

			_LFN_FileSetAttrib($hashfile_path, $attribs)
			if not $is_folder then
				$process_existing_hashes = false
				$hash_match_status_flag = ""
			endif

			if $has_legacy_hash then
				debug("CreateNewHashFile(tmp_hshs) GetHashesFromFile =>" & $hashfile_path & "<=", @ScriptLineNumber, 5)
				local $current_hashes = GetHashesFromFile($hashfile_path)
				debug("CreateNewHashFile(l_hashes) GetHashesFromFile =>" & $legacy_hash_file & "<=", @ScriptLineNumber, 5)
				local $legacy_hashes = GetHashesFromFile($legacy_hash_file)
				$existing_hashes_lookup = ""
				if IsArray($current_hashes) then $existing_hashes_lookup = 1
				if IsArray($legacy_hashes) and IsArray($current_hashes) then
					$current_hashes = MakeSearchList($current_hashes, GetLongParentDir($hashfile_path), $algorithm_id)
					if $user_quit then return $status_result_codes[0] ; "quit"
					$my_create_msg = _T("checksum is examining existing legacy hashes for..") & " " & FormatPathForDisplay($hashfile_path)
					DoProgressTips($my_create_msg)
					local $search_idx
					for $t = 1 to $legacy_hashes[0]
						local $entry_parts = StringSplit($legacy_hashes[$t], "|")
						if $current_hashes[0] then
							$search_idx = _ArrayBinarySearch($current_hashes, MakePathFullAndUNC($entry_parts[1], GetLongParentDir($hashfile_path)), 1)
							if $search_idx <> -1 then continueloop
						endif
						local $meta_line
						if $entry_parts[4] <> "" then
							$meta_line = $entry_parts[4] & $LF
						endif
						debug("COPYING legacy hash =>" & $entry_parts[1] & "<=", @ScriptLineNumber, 5)
						AddHashString($entry_parts[2], $entry_parts[1], $meta_line, false, true)
						$existing_hashes_lookup &= $entry_parts[2] & "|"
					next
				endif

				if $existing_hashes_lookup then
					_LFN_FileClose($current_file_handle)
					if DeleteFilesRecursive($legacy_hash_file) then $legacy_ext_rename_count += 1
					$current_file_handle = OpenFileHandle($hashfile_path, $FO_APPEND + $utf8_file_mode_flag)
				endif
			endif

			if $current_file_handle <> -1 then return 1

		endif

	endif

	debug("hash_file_active1: =>" & $hash_file_active & "<=" , @ScriptLineNumber, 5)
	if not $hash_file_active then return 0
	debug("hash_file_active2: =>" & $hash_file_active & "<=" , @ScriptLineNumber, 5)

	if not $is_writable then
		$fallback_mode_active = true
		if not $fallback_dirs_created then $fallback_dirs_created = _LFN_DirCreate($fallback_folder)
		if not _LFN_FileExists($fallback_folder & "\checksums.nfo.txt") then
			$nfo_file_written = _LFN_FileWriteLine($fallback_folder & "\checksums.nfo.txt", $LF & _
			"       ##                   ##                            " & $LF & _
			"       ##                   ##                            " & $LF & _
			"  #### #####   ####   ##### ##  ### #####  ##  ## ####### " & $LF & _
			" ##    ##  ## ## ##  ##     #####   ###    ##  ## ## ## ##" & $LF & _
			" ##    ##  ## ###    ##     ## ###     ### ##  ## ## ## ##" & $LF & _
			"  #### ##  ##  #####  ##### ##  ### ###### ###### ## ## ##" & $LF & $LF & _
			" checksum couldn't create hash files on the chosen location" & $LF & _
			" (perhaps it is read-only) and so stored them here instead." & $LF & $LF & _
			" When the files are copied back to writeable media (or the " & $LF & _
			" location becomes readable), you can drop the checksums " & $LF & _
			" next to them, to verify your data. " & $LF & $LF & _
			" Files and folders will merge together with a single drag-and- " & $LF & _
			" drop. Meanwhile, store them somewhere safe!" & $LF & $LF & _
			" Note: if you do this sort of thing a lot, you might want to " & $LF & _
			" look at checksum's absolute_paths preference, then you could " & $LF & _
			" verify the read-only files from any location - just a thought.")
		endif
	endif

	$attribs = _LFN_FileGetAttrib($hashfile_path)
	_LFN_FileSetAttrib($hashfile_path, "-SH")
	$current_file_handle = OpenFileHandle($hashfile_path, $FO_OVERWRITE + $FO_CREATEPATH + $utf8_file_mode_flag)
	debug("current_file_handle: =>" & $current_file_handle & "<=" , @ScriptLineNumber, 5)

	if $current_file_handle = -1 then
		if not $unwritable_paths_list then
			$my_msg = _T("Cannot create hash file!")
			$full_text = _T("I'm having problems creating a checksum file!")
			local $str_fb = _T("Even in your fall-back location!")
			MsgBox($MB_TOPMOST, $my_msg, $my_msg & @LF & @LF & $full_text & '"' & FormatPathForDisplay($hashfile_path) & '"' & @LF & @LF & $str_fb)
		endif
		$unwritable_paths_list &= " " & $hashfile_path & "    " & @LF
		return 0
	endif

	if $do_preamble = $ON then
		local $preamble = GenerateHashFilePreamble()
		if $do_preamble = $ON then _LFN_FileWriteLine($current_file_handle, $preamble)
	endif

	if _LFN_FileExists($hashfile_path) then
		$hashfile_created = true
		_LFN_FileSetAttrib($hashfile_path, $attribs)
	endif

	return $hashfile_path
endfunc




;
; AlreadyInHashFile

; Checks whether a given path plus hash combination already exists in the file.
;
func AlreadyInHashFile($my_hashfile, $file)

	debug($LF, @ScriptLineNumber, 6)
	debug("AlreadyInHashFile($my_hashfile) =>" & $my_hashfile & "<=", @ScriptLineNumber, 6)
	debug("AlreadyInHashFile($file)        =>" & $file & "<=", @ScriptLineNumber, 6)

	local $hashes = GetHashesFromFile($my_hashfile)
	if $hashes == $status_result_codes[0] then return $status_result_codes[0] ; "quit"

	debugPrintArray($hashes, "$hashes", @ScriptLineNumber, 6)
	if IsArray($hashes) and $hashes[0] then
		$my_msg = _T("checksum is finding existing hashes for..")
		DoProgressTips($my_msg & " " & BaseName($file))
		$hashes = MakeSearchList($hashes, GetLongParentDir($file), $algorithm_id)
		if $user_quit then return $status_result_codes[0] ; "quit"
		local $index = _ArrayBinarySearch($hashes, $file, 1)
		if $index <> -1 then return true
	endif

	return false

endfunc



;
; MakeSearchList()

; Recursively scans directories collecting files matching glob patterns into an
; array with size and exclusion filters applied.
;
func MakeSearchList(byref $array, $root_path, $match_algo=false)

	debug($LF, @ScriptLineNumber, 6)
	debugPrintArray($array, $LF & $LF & "MakeSearchList($array)", @ScriptLineNumber, 6)
	debug("MakeSearchList(root_path)  =>" & $root_path & "<=", @ScriptLineNumber, 6)
	debug("MakeSearchList(match_algo) =>" & $match_algo & "<=", @ScriptLineNumber, 6)

	if not IsArray($array) then return false
	local $paths[$array[0] + 1]
	local $count = 1

	for $i = 1 to $array[0]
		if $user_quit then return $status_result_codes[0] ; "quit"
		local $parts = StringSplit($array[$i], "|")
		if $match_algo and $parts[3] <> $algorithm_id then continueloop
		$paths[$count] = MakePathFullAndUNC($parts[1], $root_path)
		$paths[0] = $count
		$count += 1
	next

	redim $paths[$count]
	_ArraySort($paths, 0, 1)

	return $paths

endfunc



;
; VerifyHashes()

; Main entry point for verify mode.
;
func VerifyHashes($my_path, $dont_recurse=false)

	debug($LF, @ScriptLineNumber, 6)
	debug("VerifyHashes($my_path)      =>" & $my_path & "<=", @ScriptLineNumber, 6)
	debug("VerifyHashes($dont_recurse) =>" & Human($dont_recurse) & "<=", @ScriptLineNumber, 6)

	$my_msg = _T("checksum is building a list of checksum files in")
	DoProgressTips($my_msg & " " & FormatPathForDisplay($my_path), true)
	local $hash_files = Dig($my_path, $hashfiles, $dont_recurse, "", false, false, $memory_tuning)
	debugPrintArray($hash_files, "VerifyHashes() -->$hash_files:", @ScriptLineNumber, 8)

	if IsArray($hash_files) then
		for $i = 1 to $hash_files[0]
			$result = VerifyHashFile($hash_files[$i], $i, $hash_files[0])
			debug("VerifyHashes(" & $hash_files[$i] & ") --> result =>" & $result & "<=", @ScriptLineNumber, 6)
			if $result == $status_result_codes[1] or $result == $status_result_codes[0] then return $result
		next
		if $hash_files[0] = 1 then $path_already_exists_flag = true
		return $result
	endif

	if $hash_files = $status_result_codes[0] then return $status_result_codes[3] ; "rd_quit"
	return $status_result_codes[4] ; "nada"

endfunc




;
; VerifyHashFile()

; Verifies all entries in a specific hash file, compares computed versus
; expected hashes showing per-file pass and fail status.
;
func VerifyHashFile($hashfile_path, $item_num="", $total_items="", $search_file=false, $start_at=1)

	debug($LF, @ScriptLineNumber, 6)
	debug("VerifyHashFile() --> hashfile_path      =>" & $hashfile_path & "<=", @ScriptLineNumber, 6)
	debug("VerifyHashFile() --> item_num           =>" & $item_num & "<=", @ScriptLineNumber, 6)
	debug("VerifyHashFile() --> total_items        =>" & $total_items & "<=", @ScriptLineNumber, 6)
	debug("VerifyHashFile() --> search_file        =>" & $search_file & "<=", @ScriptLineNumber, 6)
	debug("VerifyHashFile() --> start_at           =>" & $start_at & "<=", @ScriptLineNumber, 6)
	debug("VerifyHashFile() --> algorithm          =>" & $algorithm & "<=", @ScriptLineNumber, 6)
	debug("VerifyHashFile() --> hashfile_extension =>" & $hashfile_extension & "<=", @ScriptLineNumber, 6)
	debugPrintArray($hash_extensions, "VerifyHashFile() --> $hash_extensions", @ScriptLineNumber, 6)

	local $computed_hash
	local $hashes[8]

	$my_msg = _T("checksum is verifying hash file..")
	DoProgressTips($my_msg & " " & FormatPathForDisplay($hashfile_path), true)
	if $delete_missing_hashes = $ON then $start_at = 1

	debug("VerifyHashFile() GetHashesFromFile() ---> hashfile_path->" & $hashfile_path & "<--  search_file-->" & $search_file & "<--  start_at-->" & $start_at & "<-", @ScriptLineNumber, 6)
	$hashes = GetHashesFromFile($hashfile_path, $search_file, $start_at)
	debugPrintArray($hashes, "VerifyHashFile() --> GetHashesFromFile() ---> $hashes", @ScriptLineNumber, 6)

	if $hashes == $status_result_codes[0] then return $status_result_codes[0] ; "quit"
	if not IsArray($hashes) then
		DoLogOutput($hashfile_path, 1, $hash_status_codes[1], $hashfile_path, 1, true) ; BAD
		$has_failures = true
		return $status_result_codes[5] ; CHANGED
	endif

	local $parent_dir = GetLongParentDir($hashfile_path)
	debug("VerifyHashFile() --> parent_dir =>" & $parent_dir & "<=", @ScriptLineNumber, 6)
	if $out_dir then $parent_dir = $out_dir
	debug("VerifyHashFile() --> out_dir =>" & $out_dir & "<=", @ScriptLineNumber, 6)
	debug("VerifyHashFile() --> parent_dir =>" & $parent_dir & "<=", @ScriptLineNumber, 6)

	local $hashfile_name = BaseName($hashfile_path)
	local $is_last = false
	local $total_time = 0
	local $file_time_diff = 0
	local $needs_rewrite = false
	local $updated_hashes = false
	local $status_level = 2
	local $found_search_match = false
	$queue_entry_has_failures = false
	local $file_time_comment

	for $i = 1 to $hashes[0]

		if $i = $hashes[0] then $is_last = true
		local $display_name
		local $line_parts = StringSplit($hashes[$i], "|")
		debugPrintArray($line_parts, "VerifyHashFile() --> $line_parts", @ScriptLineNumber, 6)

		local $filename_entry = $line_parts[1]
		local $hash_entry = $line_parts[2]
		local $algo_id_entry = $line_parts[3]
		local $metadata_entry = $line_parts[4]
		$status_level = 2

		if StringInStr($filename_entry, "/", 2) then
			if StringLeft($filename_entry, 2) = "./" then $filename_entry = StringTrimLeft($filename_entry, 2)
			$filename_entry = StringReplace($filename_entry, "/", "\")
		endif
		debug("VerifyHashFile() --> VERIFY FILE =>" & $filename_entry & "<=", @ScriptLineNumber, 6)

		if $progress_tip = $ON then
			local $progress_prefix = ""
			local $algo_label = $algorithm_strings[DefaultAlgoID()]
			if $algo_id_entry >= 1 and $algo_id_entry <= $algorithm_strings[0] then $algo_label = $algorithm_strings[$algo_id_entry]
			if $item_num then $progress_prefix = "[checksum file: " & $item_num & " of " & $total_items & "] " & $hashfile_name & " :"
		endif

		; Check for custom path supplied in p(group)..
		local $entry_parent_dir = $parent_dir
		debug("VerifyHashFile() --> entry_parent_dir =>" & $entry_parent_dir & "<=", @ScriptLineNumber, 6)
		debug("VerifyHashFile() --> custom_verify_path =>" & $custom_verify_path & "<=", @ScriptLineNumber, 6)
		if $custom_verify_path then $entry_parent_dir = $custom_verify_path
		debug("VerifyHashFile() --> entry_parent_dir =>" & $entry_parent_dir & "<=", @ScriptLineNumber, 6)

		if StringLeft($filename_entry, 3) = "..\" then
			do
				local $slash_pos = StringInStr($entry_parent_dir, "\", 0, -1)
				if $slash_pos > 0 then $entry_parent_dir = StringLeft($entry_parent_dir, $slash_pos - 1)
				$filename_entry = StringTrimLeft($filename_entry, 3)
			until StringLeft($filename_entry, 3) <> "..\"
		endif

		; Set the full path for hashing this file..
		local $full_path

		; FULL absolute paths used in checksum creation (contain drive root)..
		if StringMid($filename_entry, 2, 2) = ":\" or StringMid($filename_entry, 1, 2) = "\\" then
			$full_path = PrependLongPathPrefix($filename_entry)
		else
			$full_path = $entry_parent_dir & "\" & $filename_entry
		endif
		debug("VerifyHashFile() --> full_path =>" & $full_path & "<=", @ScriptLineNumber, 6)

		local $status_text = "UNKNOWN"
		local $stored_basename, $stored_time_str, $actual_basename, $time_string, $metadata_parts

		if $search_file then
			if $search_file <> $filename_entry then continueloop
			if $search_file = $filename_entry then
				$found_search_match = true
				if $delete_missing_hashes = $ON then
					$status_text = $hash_status_codes[3] ; deleted
					$needs_rewrite = true
				endif
				debug("VerifyHashFile() --> got_search_match =>" & $search_file & "<=", @ScriptLineNumber, 6)
			endif
		endif

		$display_name = BaseName($filename_entry)
		if $check_dates = $ON then
			local $file_time_raw = _LFN_FileGetTime($full_path)
			$file_time_comment = StringStripWS(CreateMetaData($file_time_raw, $display_name), $STR_STRIPTRAILING)
			if $file_time_comment then $metadata_parts = StringSplit($file_time_comment, "#")
			if IsArray($metadata_parts) and $metadata_parts[0] = 4 then
				$actual_basename = BaseName($metadata_parts[3])
				$time_string = $metadata_parts[4]
				local $stored_parts = StringSplit($metadata_entry, "#")
				if IsArray($stored_parts) and $stored_parts[0] = 4 then
					$stored_basename = BaseName($stored_parts[3])
					$stored_time_str = $stored_parts[4]
				endif
			endif
		endif

		debug("VerifyHashFile() --> time_string =>" & $time_string & "<=", @ScriptLineNumber, 6)
		debug("VerifyHashFile() --> stored_time_str =>" & $stored_time_str & "<=", @ScriptLineNumber, 6)

		if $check_only_new_files = $ON and $stored_time_str <> "" and $time_string <> "" and ($time_string = $stored_time_str) then
			debug("VerifyHashFile() --> check_only_new_files =>UNCHANGED FILE!!!! SKIPPING..." & "<=", @ScriptLineNumber, 6)
			$status_text = $hash_status_codes[7] ; UPDATED

		elseif not StringIsXDigit($hash_entry) then
			debug("VerifyHashFile() --> =>INVALID HASH FILE!!!!" & "<=", @ScriptLineNumber, 6)
			$status_text = $hash_status_codes[8] ; SKIPPED
		else
			debug("VerifyHashFile() --> verifying =>" & $display_name & "<=", @ScriptLineNumber, 6)

			local $timer = 0
			if $display_times = 1 then $timer = TimerInit()

			if $progress_tip = $ON then
				$my_msg = _T("checksum is verifying")
				DoProgressTips($my_msg & " " & $algo_label & ": " & $progress_prefix & " [" & _T("file") & ": " & $i & " " & _T("of") & " " & $hashes[0] & "] : " & $display_name)
			endif

			$computed_hash = HashFile($full_path, $algo_id_entry, $uppercase_hashes)

			if $computed_hash == $status_result_codes[0] then
				$user_quit = true
				return $status_result_codes[1] ; "cancel"
			endif

			if $display_times = 1 then $file_time_diff = TimerDiff($timer) / 1000
			$total_time += $file_time_diff
			debug("VerifyHashFile() --> actual_basename =>" & $actual_basename & "<=", @ScriptLineNumber, 6)
			debug("VerifyHashFile() --> stored_basename =>" & $stored_basename & "<=", @ScriptLineNumber, 6)
		endif

		if $status_text = $hash_status_codes[7] then ; SKIPPED
			SetArrayElementByIndex($hashes, $i, 5, $status_text)
			$status_level = 2
		elseif $computed_hash = $hash_entry then
			debug("VerifyHashFile() --> SUCCESS! => HASH PASSED!" & "<=", @ScriptLineNumber, 6)
			$status_text = $hash_status_codes[0] ; Passed
			SetArrayElementByIndex($hashes, $i, 5, $status_text)
			$status_level = 2
		else

			debug("VerifyHashFile() --> ERROR!!! => HASH ERROR" & "<=", @ScriptLineNumber, 6)
			local $skip_alert = false

			if not _LFN_FileExists($full_path) then
				$status_text = $hash_status_codes[2] ; MISSING
				if $delete_missing_hashes = $ON then
					$status_text = $hash_status_codes[3] ; DELETED
					$needs_rewrite = true
				endif
			else
				if $check_dates = $ON and $actual_basename and $actual_basename = $stored_basename then
					if $stored_time_str = $time_string then
						$status_text = $hash_status_codes[4] ; CORRUPT
					else
						if $update_changed_hashes = $ON then
							$status_text = $hash_status_codes[6] ; UPDATED
							SetArrayElementByIndex($hashes, $i, 6, $computed_hash)
							SetArrayElementByIndex($hashes, $i, 7, $file_time_comment)
							$updated_hashes = true
							$needs_rewrite = true
						else
							$status_text = $hash_status_codes[5] ; CHANGED
						endif
					endif
				else
					$status_text = $hash_status_codes[5]
				endif
			endif

			SetArrayElementByIndex($hashes, $i, 5, $status_text)
			select
				case $status_text = $hash_status_codes[3] or $status_text = $hash_status_codes[6] ; deleted
					$skip_alert = true
				case $status_text = $hash_status_codes[2] and $report_missing = $OFF
					continueloop
				case $status_text = $hash_status_codes[5] and $report_changed = $OFF
					continueloop
				case $status_text = $hash_status_codes[4] and $report_corrupt = $OFF
					continueloop
			endselect

			if not $skip_alert then
				SetTipWarnColor()
				$status_level = 1
				$has_failures = true
				if $beep_alerts <> $OFF then
					if $beep_fail then
						SoundPlay($beep_fail)
					else
						Beep($beep_freq, 25)
					endif
				endif
				SetTipDefaultColor()
			endif

		endif

		local $drive_status
		local $msg_result = 0

		if $status_text = $hash_status_codes[2] or $status_text = $hash_status_codes[3] then ; missing or deleted
			local $drive_type = DriveGetType(StringLeft(StripLongPathPrefix($full_path), 2))
			if $drive_type <> "Fixed" then
				if $drive_type = "Network" then
					if _LFN_FileExists(GetUncServerAndShare($full_path)) then
						$drive_status = "READY"
					else
						$drive_status = "not READY"
					endif
				else
					$drive_status = DriveStatus(StringLeft(StripLongPathPrefix($full_path), 2))
				endif
				if $drive_status <> "READY" then
					if $quiet_operation = $OFF then
						$my_msg = _T("Drive Not Available")
						$full_text = _T("Attempting to continue could produce errors.\n\nDo you wish to continue verifying files on this drive?")
						$msg_result = MsgBox($MB_YESNO + $MB_ICONWARNING + $MB_TOPMOST, $my_msg, $my_msg & _L($full_text))
					else
						$msg_result = 7
					endif
				endif
			endif
		endif

		if $msg_result = 7 then
			$user_quit = true
			local $log_message = ""
			if $i = 1 then
				$log_message = _T("Fatal Error: Files were unavailable for checking.")
			else
				$log_message = _T("Fatal Error: Files became unavailable for checking.")
			endif
			if $i <> $hashes[0] and not $search_file then
				DoLogOutput($log_message & " ", $status_level, $hash_status_codes[9], $hashfile_path, $i, true, $total_time) ; ERROR
			endif
			return $status_result_codes[0] ; "quit"
		else
			if $status_text <> $hash_status_codes[7] then $files_hashed_count += 1	; SKIPPED
			debug("JOB COUNT =>" & $files_hashed_count & "<=", @ScriptLineNumber, 6)
			local $entry_idx = $i
			if $found_search_match then
				$entry_idx = 1
				$is_last = true
			endif
			debug("hashfile_path =>" & $hashfile_path & "<=", @ScriptLineNumber, 6)
			DoLogOutput($full_path, $status_level, $status_text, $hashfile_path, $entry_idx, $is_last, $total_time, $algo_id_entry)
		endif

		if $found_search_match and $delete_missing_hashes = $OFF then exitloop
		if $user_quit then return $status_result_codes[0] ; "quit"
	next

	debugPrintArray($hashes, "VerifyHashFile() ---> $hashes", @ScriptLineNumber, 6)

	if $needs_rewrite then
		RewriteHashFile($hashfile_path, $hashes, $updated_hashes)
	endif

	if $found_search_match then return $status_text
	if $search_file then return false

endfunc



;
; GetHashesFromFile()

; Reads and parses an existing hash file into an array structure.
;
func GetHashesFromFile($hash_file, $search_path=false, $start_line=1)

	debug($LF, @ScriptLineNumber, 6)
	debug("GetHashesFromFile() hash_file:	===>" & $hash_file & "", @ScriptLineNumber, 6)
	debug("GetHashesFromFile() search_path:	===>" & $search_path & "", @ScriptLineNumber, 6)
	debug("GetHashesFromFile() start_line:	===>" & $start_line & "", @ScriptLineNumber, 6)

	if not _LFN_FileExists($hash_file) then return $status_result_codes[2] ; "noexist"

	local $line_count = 0
	local $display_path = FormatPathForDisplay($hash_file)
	$my_msg = _T("checksum is examining hash file..")
	DoProgressTips($my_msg & " " & $display_path, true)
	local $read_handle = OpenFileHandle($hash_file, $FO_READ)
	_LFN_FileClose($read_handle)

	if $start_line = 1 then
		$my_msg = _T("checksum is counting the number of lines in")
		DoProgressTips($my_msg & " " & $display_path, true)
		$line_count = CountFileLines($hash_file)
		if $line_count == $status_result_codes[0] then return $status_result_codes[0] ; "quit"
		debug("line_count Calculated =>" & $line_count & "<=", @ScriptLineNumber, 6)
	else
		$line_count = $start_line + 2
		debug("line_count SET TO =>" & $line_count & "<=", @ScriptLineNumber, 6)
	endif

	local $array_size = $line_count
	if ($array_size > $MAX_PATHS) and ($array_size <= ($MAX_PATHS * 2)) then $array_size = $MAX_PATHS - 1
	if $line_count > (2 * $MAX_PATHS) then
		$my_msg = _T("hash file too big!")
		$full_text = _T("The hash file is too big to deal with!\nPlease split the file into two or more pieces and try again!")
		MsgBox($MB_ICONERROR + $MB_TOPMOST, $my_msg, $my_msg & _L($full_text), $dialog_timeout)
		$bad_file_paths_list &= $display_path & "|"
		return $status_result_codes[5] ; "bad"
	endif

	if $line_count = 0 then
		$bad_file_paths_list &= $display_path & "|"
		return $status_result_codes[5]
	endif

	$my_msg = _T("checksum is extracting hashes from")
	DoProgressTips($my_msg & ".. " & $display_path, true)

	local $file_handle = OpenFileHandle($hash_file)
	if $start_line <> 1 then
		_LFN_FileReadLine($file_handle, $start_line - 2)
	endif

	local $hashes[$array_size + 1]
	local $count = 1
	local $file_info = ""
	local $timer = TimerInit()
	local $timer_step = 1
	local $qty_text = _T("lots")
	local $skip_line = false
	debug("Extracting hashes from file =>" & $display_path & "<=", @ScriptLineNumber, 6)

	local $debug_timer = TimerInit()
	while true

		if $user_quit then return $status_result_codes[0] ; "quit"
		if $search_path and $array_size < $count then
			debug("searchpath and $array_size < count =>" & $count & "<=", @ScriptLineNumber, 6)
			exitloop
		endif

		if $timer_step < 8 then
			if (TimerDiff($timer) / 1000) > (5 * $timer_step) then
				$my_msg = _T("checksum is extracting")
				$full_text = _T("of hashes from")
				DoProgressTips($my_msg & " " & $qty_text & " " & $full_text & ".. " & $display_path, true)
				if $timer_step > 1 then
					$qty_text = _T("a HUGE amount")
				else
					$qty_text &= " " & _T("and LOTS")
				endif
				$timer_step += 2
			endif
		endif

		local $line = _LFN_FileReadLine($file_handle)
		if $skip_line then
			$skip_line = false
			continueloop
		endif

		if @error = -1 then exitloop
		debug("GetHashesFromFile() -->set $line =>" & $line & "<=", @ScriptLineNumber, 6)

		if StringLeft($line, 1) = ";" or $line = "" then continueloop

		if StringLeft($line, 1) = "#" then
			if $skip_hashes = $ON then
				local $parts = StringSplit($line, "#")
				debugPrintArray($parts, "GetHashesFromFile() ---> $parts", @ScriptLineNumber, 6)
				if $parts[0] = 4 and FindInStringArray($skipped_hashes, $parts[2]) then
					debug("SKIPPING!!!!!!!!!!! =>" & $line & "<=", @ScriptLineNumber, 6)
					$skip_line = true
					continueloop
				endif
			endif
			$file_info = $line
			debug("file_info =>" & $file_info & "<=", @ScriptLineNumber, 6)
			continueloop
		endif

		local $parsed_line = CheckHashformat($line, $hash_file)
		debugPrintArray($parsed_line, "GetHashesFromFile()->CheckHashformat() returned $parsed_line", @ScriptLineNumber, 6)
; GOOD
; [0] : MeC.png
; [1] : d9deb688f8daaa74dd8a5f9ccacd5b7fd2c2120b
; [2] : 2

		; checking one specific algorithm only..
		if $operation_mode = "verify" then
			local $has_algo_filter = StringInStr($switches, "a")
			if $has_algo_filter then
				local $filter_algo_id = AlgoIDFromVerifySwitch()
				if $filter_algo_id and $parsed_line[2] <> $filter_algo_id then continueloop
			endif
		endif

		debug("hash_length: =>" & $hash_length & "<=" , @ScriptLineNumber, 6)
		debug("$parsed_line[1]: =>" & $parsed_line[1] & "<=" , @ScriptLineNumber, 6)

		if (StringLen($parsed_line[1]) <> $hash_length) or not StringIsXDigit($parsed_line[1]) then
			debug("INVALID HASH LINE" , @ScriptLineNumber, 6)
			_LFN_FileClose($file_handle)
			$bad_file_paths_list &= $display_path & "|"
			return $status_result_codes[5] ; "bad"
		endif

		if $user_quit then return $status_result_codes[0]
		debug("Creating $hashes_array.." & $count, @ScriptLineNumber, 6)

		$hashes[0] = $count
		$hashes[$count] = $parsed_line[0]
		$hashes[$count] &= "|" & $parsed_line[1]
		$hashes[$count] &= "|" & $parsed_line[2]
		$hashes[$count] &= "|" & $file_info
		$hashes[$count] &= "|" & ""
		$hashes[$count] &= "|" & ""
		$hashes[$count] &= "|" & ""
		$count += 1
		; debugPrintArray($hashes, "$hashes:", @ScriptLineNumber, 8)
; GOOD
; [0] : 1
; [1] : MeC.png|d9deb688f8daaa74dd8a5f9ccacd5b7fd2c2120b|2||||

		if $search_path and $search_path = $parsed_line[0] then
			redim $hashes[$count]
			exitloop
		endif

		if $count >= $MAX_PATHS then
			$my_msg = _T("hash file too big!")
			$full_text = _T("To verify all the hashes, please split the file into two or more files.\n\nDo you wish me to verify the first")

			if MsgBox($MB_YESNO + $MB_ICONWARNING + $MB_TOPMOST, $my_msg, _
				$my_msg & @LF & _L($full_text) & " " & $count-1 & " hashes? ", $dialog_timeout) = $IDYES then
				exitloop
			else
				_LFN_FileClose($file_handle)
				return $status_result_codes[5] ; "bad"
			endif
		endif

	wend
	debug("GetHashesFromFile took =>" & Round(TimerDiff($debug_timer) / 1000, 2) & " seconds", @ScriptLineNumber, 6)
	_LFN_FileClose($file_handle)
	redim $hashes[$hashes[0] + 1]
	debugPrintArray($hashes, "GetHashesFromFile() --->> created: $hashes", @ScriptLineNumber, 6)

	return $hashes

endfunc



;
; RewriteHashFile()

; Reads a hash file line-by-line parsing comments and entries, regenerates all
; entries with fresh timestamps and metadata from actual current hashes on disk,
; writes atomically to temp file, then rename..
;
func RewriteHashFile($hash_file, byref $hashes, $update_hashes=false)

	debug($LF, @ScriptLineNumber, 6)
	debugPrintArray($hashes, "RewriteHashFile() ---> RewriteHashFile($hash_array)", @ScriptLineNumber, 6)

	CopyFilesRecursive($hash_file, @TempDir & "\checksum-deleted-backup.hash", 9)
	DoProgressTips("checksum is updating" & " " & FormatPathForDisplay($hash_file))

	local $attribs = _LFN_FileGetAttrib($hash_file)
	_LFN_FileSetAttrib($hash_file, "-SH")
	local $file = OpenFileHandle($hash_file, $FO_OVERWRITE + $utf8_file_mode_flag)

	if $do_preamble = $ON then
		local $preamble = GenerateHashFilePreamble()
		if $do_preamble = $ON then _LFN_FileWriteLine($file, $preamble)
	endif

	local $written_count = 0

	for $i = 1 to $hashes[0]

		local $parts = StringSplit($hashes[$i], "|")

		if $parts[5] <> $hash_status_codes[3] then ; DELETED
			if $update_hashes and $parts[5] = $hash_status_codes[6] then ; UPDATED
				$parts[4] = $parts[7]
				$parts[2] = $parts[6]
				$hashes_updated_count += 1
			endif
			if $parts[4] <> "#" then _LFN_FileWriteLine($file, $parts[4])
			_LFN_FileWriteLine($file, $parts[2] & " " & "*" & $parts[1])
			$written_count += 1
		else
			$hashes_deleted_count += 1
			$files_hashed_count -= 1
		endif
	next

	_LFN_FileClose($file)
	_LFN_FileSetAttrib($hash_file, $attribs)
	if $written_count = 0 then DeleteFilesRecursive($hash_file)

endfunc




;
; CheckHashformat()

; Checks if a line from a file follows an expected format before validation.
; Returns simple array with ($file_name, $my_hash, $my_algo_id, $my_hash_format)
; Sets global $hash_length
;
func CheckHashformat($line, $file_path)

	$line = StringStripWS($line, $STR_STRIP_ENDS)
	debug($LF, @ScriptLineNumber, 8)
	debug("CheckHashformat() --> $line        =>" & $line & "<=", @ScriptLineNumber, 8)
	debug("CheckHashformat() --> $file_path   =>" & $file_path & "<=", @ScriptLineNumber, 8)

	local $my_algo_id = 0
	local $my_hash = ""
	local $file_name = ""
	local $my_hash_length = 0
	local $my_hash_format = 0
	local $algo_lengths[4] = [$SHA2_HEX_LEN, $SHA1_HEX_LEN, $MD5_HEX_LEN, $CRC32_HEX_LEN]
	local $algo_ids[4] = [3, 2, 1, 4]

	; Check standard hex-prefix formats, starting with SHA256 (CRC32 last, so longer hashes always win)
	for $algo_index = 0 to 3
		local $test_len = $algo_lengths[$algo_index]
		if StringLen($line) >= $test_len then
			local $test_hash = StringLeft($line, $test_len)
			if StringIsXDigit($test_hash) then
				local $next_char = StringMid($line, $test_len + 1, 1)
				if $next_char = "" or $next_char = " " or $next_char = @TAB then
					$my_algo_id = $algo_ids[$algo_index]
					$my_hash_length = $test_len
					$my_hash = $test_hash
					exitloop
				endif
			endif
		endif
	next

	; Standard format hash entry (left-anchored hash).
	if $my_algo_id > 0 then

		$file_name = StringTrimLeft($line, $my_hash_length)
		while StringLeft($file_name, 1) = " " or StringLeft($file_name, 1) = @TAB or StringLeft($file_name, 1) = "*"
			$file_name = StringTrimLeft($file_name, 1)
		wend

		if $file_name = "" then
			$my_hash_format = 4 ; bare / piped hash -- nothing trailing the hash on this line.
			local $ext_pos = StringInStr(BaseName($file_path), ".", $STR_NOCASESENSEBASIC, -1)
			if $ext_pos > 1 then
				$file_name = StringMid(BaseName($file_path), 1, $ext_pos - 1)
			else
				$file_name = BaseName($file_path)
			endif
		endif

	else
		; BSD/Windows parenthesized formats: "SHA1 (file) = hash" or "(SHA1) file = hash"
		local $match = StringRegExp($line, "(?i)^(MD5|SHA1|SHA256|CRC32)\s*\((.+)\)\s*(?:=\s*)?([a-f0-9]{32}|[a-f0-9]{40}|[a-f0-9]{64}|[a-f0-9]{8})$", 1)
		if not IsArray($match) then
			$match = StringRegExp($line, "(?i)^\((MD5|SHA1|SHA256|CRC32)\)\s*(.+?)\s*(?:=\s*)?([a-f0-9]{32}|[a-f0-9]{40}|[a-f0-9]{64}|[a-f0-9]{8})$", 1)
		endif

		if IsArray($match) then
			$file_name = $match[1]
			$my_hash = $match[2]
			$my_hash_format = 3
			local $label_algo_id = _ArraySearch($algorithm_strings, StringUpper($match[0]), 1)
			if $label_algo_id > 0 then
				$my_algo_id = $label_algo_id
				$my_hash_length = AlgoHexLen($label_algo_id)
			endif
		endif

		; Classic SFV hash-last: "filename hash". Filenames may hold spaces, so split on the last blank.
		; The tail length decides the algorithm: 8 = CRC32, 32 = MD5, 40 = SHA1, 64 = SHA256.
		if $my_algo_id = 0 and StringLeft($line, 1) <> ";" and StringLeft($line, 1) <> "#" then
			local $space_pos = StringInStr($line, " ", 0, -1)
			local $tab_pos = StringInStr($line, @TAB, 0, -1)
			local $split_pos = $space_pos
			if $tab_pos > $split_pos then $split_pos = $tab_pos
			if $split_pos > 1 then
				local $tail = StringStripWS(StringMid($line, $split_pos + 1), $STR_STRIP_ENDS)
				local $tail_id = 0
				if StringIsXDigit($tail) then
					switch StringLen($tail)
						case $CRC32_HEX_LEN
							$tail_id = 4
						case $MD5_HEX_LEN
							$tail_id = 1
						case $SHA1_HEX_LEN
							$tail_id = 2
						case $SHA2_HEX_LEN
							$tail_id = 3
					endswitch
				endif
				if $tail_id > 0 then
					local $head = StringStripWS(StringLeft($line, $split_pos - 1), $STR_STRIP_ENDS)
					if StringLen($head) > 2 and StringLeft($head, 1) = '"' and StringRight($head, 1) = '"' then $head = StringMid($head, 2, StringLen($head) - 2)
					if $head <> "" then
						$file_name = $head
						$my_hash = $tail
						$my_algo_id = $tail_id
						$my_hash_length = StringLen($tail)
						$my_hash_format = 5
					endif
				endif
			endif
		endif
	endif

	local $err = 0
	if $my_algo_id > 0 then
		if StringRegExp(BaseName($file_name), '[*?"<>|]') then
			$my_algo_id = 0
			$my_hash = ""
			$file_name = $hash_status_codes[1] ; BAD
			$err = 1
		endif
		if $my_hash_length <> 0 then $hash_length = $my_hash_length
	else
		$file_name = $hash_status_codes[1]
		$err = 1
	endif

	local $my_result[4] = [$file_name, $my_hash, $my_algo_id, $my_hash_format]
	debugPrintArray($my_result, "CheckHashformat() --> $my_result[4]=>:", @ScriptLineNumber, 8)
	return SetError($err, 0, $my_result)

endfunc




;
; CloseHashFile()

; Closes open hash file handle stream object; if show-all-hashes mode active
; writes accumulated all entries to final .m3u or .pls playlist file with proper
; header structure and entry numbering.
;
func CloseHashFile($my_file)

	debug($LF, @ScriptLineNumber, 6)
	debug("CLOSING HASH FILE::	CloseHashFile()", @ScriptLineNumber, 6)
	debug("files_hashed_count      =>" & $files_hashed_count & "<=", @ScriptLineNumber, 6)
	debug("hashfile_path           =>" & $hashfile_path & "<=", @ScriptLineNumber, 6)
	debug("hashfile_created_flag   =>" & $hashfile_created & "<=", @ScriptLineNumber, 6)
	debug("hash_written            =>" & $hash_written & "<=", @ScriptLineNumber, 6)

	_LFN_FileClose($my_file)

	if $hashfile_created and not $hash_written then
		DeleteFilesRecursive($hashfile_path)
		$files_hashed_count -= 1
		$hashfile_created = false
	endif

	debug("files_hashed_count 2 =>" & $files_hashed_count & "<=", @ScriptLineNumber, 6)
	debug("hide_checksums =>" & $hide_checksums & "<=", @ScriptLineNumber, 6)

	if $files_hashed_count > 0 then
		if $hide_checksums = $ON then
			_LFN_FileSetAttrib($hashfile_path, "+H")
		endif
	endif

endfunc



;
; CreateMetaData()

; Formats an array date/time [count,Y,M,D,H,Mi] into
; "#algo#filename#Y.M.D@H:M\n" metadata string..
;
func CreateMetaData(byref $date_time, $file_name)
	if IsArray($date_time) then
		$date_time = "#" & $algorithm & "#" & $file_name & "#" & $date_time[0] & "." & $date_time[1] & "." & _
						$date_time[2] & "@" & $date_time[3] & "." & $date_time[4] & ":" & $date_time[5] & $LF
		return $date_time
	endif
	return ""
endfunc



;
; SetHashFileExtensionPattern()

; e.g. ".md5" or unified, and build a compound
; file-matching pattern string for hash files.
;
func SetHashFileExtensionPattern()
	local $hash_ext_list = ""
	if $unified_extension = $ON then
		$hashfile_extension = "." & $unihash_extension
		$hash_ext_list = ",*." & $algorithm
	else
		$hashfile_extension = "." & $algorithm
	endif
	$hashfiles = "*" & $hashfile_extension & $hash_ext_list & "," & $unix_hashfiles
	local $filter_id = AlgoIDFromVerifySwitch()
	if $filter_id = 0 or $filter_id = 4 then $hashfiles &= ",*.sfv"
endfunc



;
; GenerateHashFilePreamble()

; Builds comment header plus custom preamble lines.
;
func GenerateHashFilePreamble()

	local $arch_bit = "32"
	if @AutoItX64 = 1 then $arch_bit = "64"
	local $preamble = "# " & _T("made with") & " checksum.. " & $arch_bit & "-bit " & _T("edition") & "." & $LF & "# " & _T("from") & " corz.org.. " & $MY_URL & $LF & "#" & $LF
	local $custom_preamble = GetINIArrayValue($ini_array, "preamble", "")

	switch $custom_preamble
		case "none"
			$do_preamble = $OFF
		case ""
		case else
			$preamble = ""
			local $preamble_lines = StringSplit($custom_preamble, "\n", 1)
			for $i = 1 to $preamble_lines[0]
				if StringLeft($preamble_lines[$i], 1) <> ";" and StringLeft($preamble_lines[$i], 1) <> "#" then
					$preamble_lines[$i] = "#" & $preamble_lines[$i]
				endif
				$preamble &= $preamble_lines[$i] & $LF
			next
	endswitch
	return $preamble
endfunc




; TODO - do SOMETHING with error messages!


;
; HashFile()

; Hash a file..
; The three asterisk at the start of the error messages must remain, as we use 
; it to recognise error messages.
;
func HashFile($file, $my_algo_id=3, $uppercase_hashes=0)

	local $target = PrependLongPathPrefix($file)
	debug($LF, @ScriptLineNumber, 7)
	debug("HashFile() file      --->" & $file & "<="  , @ScriptLineNumber, 7)
	debug("HashFile() Algo ID      --->" & $my_algo_id & "<="  , @ScriptLineNumber, 7)
	debug("HashFile() target      --->" & $target & "<="  , @ScriptLineNumber, 7)

	local $hash_digest
	if $my_algo_id = 4 then
		$hash_digest = crc32HashFile($target, $uppercase_hashes, $allow_caching)
	else
		$hash_digest = bcryptHashFile($target, $algorithm_strings[$my_algo_id], $uppercase_hashes, $allow_caching)
	endif

	if not @error then
		return SetError(-1, 0, $hash_digest)
	else
		local $error = @error
		local $extended = @extended
		local $error_msg = ""
		switch $error
			case 1
				$error_msg = "*** FAILED TO LOAD BCRYPT.DLL ***"
			case 2, 3, 4, 8, 9
				$error_msg = StringFormat("*** CRYPTO API ERROR (0x%08X) ***", $extended)
			case 5
				switch $extended
					case 2, 3
						$error_msg = "*** FILE NOT FOUND ***"
					case 5, 32
						$error_msg = "*** READ PERMISSION DENIED ***"
					case else
						$error_msg = StringFormat("*** FILE ACCESS ERROR (%d) ***", $extended)
				endswitch
			case 6
				$error_msg = "*** OPERATION ABORTED ***"
			case 7
				$error_msg = StringFormat("*** FILE READ ERROR (%d) ***", $extended)
			case else
				$error_msg = "*** UNKNOWN ERROR ***"
		endswitch
		return SetError($error, $extended, $error_msg)
	endif

endfunc




;
; AddHashString()

; Adds a single computed hash to a hash file.
;
func AddHashString($my_hash, $my_file_name, $my_date_info="", $root_hash=false, $unified=false)

	debug($LF, @ScriptLineNumber, 6)
	debug("AddHashString() my_hash       --->" & $my_hash & "<=", @ScriptLineNumber, 6)
	debug("AddHashString() my_file_name  --->" & $my_file_name & "<=", @ScriptLineNumber, 6)
	debug("AddHashString() my_date_info  --->" & $my_date_info & "<=", @ScriptLineNumber, 6)
	debug("AddHashString() root_hash     --->" & $root_hash & "<=", @ScriptLineNumber, 6)
	debug("AddHashString() unified       --->" & $unified & "<=", @ScriptLineNumber, 6)

	if $my_hash == $status_result_codes[0] or StringInStr($my_hash, "ABORTED") then
		$user_quit = true
		return
	endif

	; Hashing error - TODO: log these somewhere..
	if StringLeft($my_hash, 3) == "***" then return

	if $my_hash = "" or $my_file_name = "" then return
	if $root_hash and $absolute_paths = $ON and $always_store_unc = $OFF then
		$my_file_name = StripLongPathPrefixIfShort($my_file_name)
	endif

	if $check_dates = $ON and IsArray($my_date_info) then
		$my_date_info = CreateMetaData($my_date_info, $my_file_name)
	endif

	debug("AddHashString() ADDING:      --->" & $my_date_info & $my_hash & " *" & $my_file_name & $LF & "<=", @ScriptLineNumber, 6)
	local $write_result = _LFN_FileWriteLine($current_file_handle, $my_date_info & $my_hash & " *" & $my_file_name & $LF)
	debug("AddHashString() write_result:      --->" & $write_result & "<=" , @ScriptLineNumber, 6)

	if $write_result then
		if not $unified then $files_hashed_count += 1
		debug("JOB COUNT =>" & $files_hashed_count & "<=", @ScriptLineNumber, 6)
		$hash_written = true
	endif
	debug("AddHashString() hash_written:      --->" & $hash_written & "<=" , @ScriptLineNumber, 6)


	if $is_playlist_enabled then
		if FindInStringArray($playlist_extensions, "*." & GetExtension($my_file_name)) then
			$in_progress = true
			switch $playlist_type
				case "m3u", "m3u8"
					$playlist_string &= $my_file_name & $LF
				case "pls"
					$playlist_entry_counter += 1
					$playlist_string &= "File" & $playlist_entry_counter & "=" & $my_file_name & $LF
			endswitch
		endif
	endif

endfunc



;
; InitializePlaylistMode()

; Resets playlist state: appends "[playlist]" ini header for pls format, resets
; entry counter, disables timestamp display flag.
;
func InitializePlaylistMode()
	if $playlist_type = "pls" then
		$playlist_string &= "[playlist]" & $LF
		$playlist_entry_counter = 0
	endif
	$in_progress = false
endfunc



;
; FinalizePlaylistFile()

; If show-all-hashes and timestamps enabled, writes accumulated $playlist_string
; to a .m3u/.pls file then resets flags.
;
func FinalizePlaylistFile($playlist_file)

	if $is_playlist_mode then

		if $in_progress then

			local $pu = 2
			switch $playlist_type
				case "m3u8", "pls"
					$pu = $FO_UTF8 + $FO_OVERWRITE
				case "m3u"
					$pu = $FO_ANSI
			endswitch
			local $pv = OpenFileHandle(RemoveExtension($playlist_file) & "." & $playlist_type, $pu)

			if $pv then
				if $playlist_type = "pls" then
					$playlist_string &= "NumberOfEntries=" & $playlist_entry_counter & $LF
					$playlist_string &= "Version=2" & $LF
				endif
				if $nix_paths = $OFF then $playlist_string = StringReplace($playlist_string, "/", "\")
				_LFN_FileWrite($pv, "# checksum generated playlist file" & $LF & "# " & $MY_URL & $LF & $playlist_string)
				_LFN_FileClose($pv)
				$playlist_string = ""
			endif

		endif
		InitializePlaylistMode()

	endif
endfunc




;
; TestWriteable()

; Tests whether a directory or file parent path is writable and create-able by
; attempting to generate + delete a temporary test file in the location; returns
; true for writable, false otherwise; used before hash output file creation.
;
func TestWriteable($test_path)

	debug($LF, @ScriptLineNumber, 6)
	debug("TestWriteable() --->  test_path =>" & $test_path & "<=", @ScriptLineNumber, 6)
	debug("root_writeable                  =>" & $root_writeable & "<=", @ScriptLineNumber, 6)

	if StringRight($test_path, 1) <> "\" then $test_path &= "\"
	if $root_writeable = $test_path then return $test_path
	if $test_path = $unwritable_path then return false
	debug("TestWriteable() ---> TESTING for =>" & $test_path & "<=", @ScriptLineNumber, 6)

	if $relaxed_write_test = $ON then
		if not StringInStr(_LFN_FileGetAttrib($test_path), "R", 2) then return $test_path
		return false
	endif

	local $test_file
	local $test_chars = StringSplit("[,],(,),&,^,+,=,@,#,%,-", ",")

	for $i = 1 to $test_chars[0]
		$test_file = $test_path & $test_chars[$i]
		if _LFN_FileExists($test_file) then continueloop
		debug("TestWriteable() --->  WRITING TEST FILE: =>" & $test_file & "<=", @ScriptLineNumber, 6)
		if _LFN_FileWriteLine($test_file, "1") then
			DeleteFilesRecursive($test_file)
			debug("TestWriteable() --->  100% OKAY!   IT IS WRITEABLE!! =>" & $test_file & "<=", @ScriptLineNumber, 6)
			return $test_path
		else
			debug("TestWriteable() ---> ERROR! It is NOT WRITEABLE: =>" & $test_file & "<=", @ScriptLineNumber, 6)
			$unwritable_path = $test_path
			return false
		endif
	next

	$unwritable_path = $test_path
	return false

endfunc





;
; SearchUpAndVerify()

; Recursively walks up parent directories of a given file checking each level
; against its stored hash entries, searching for a matching hash entry.
;
func SearchUpAndVerify($file_path, $ext)

	debug($LF, @ScriptLineNumber, 6)
	debug("SearchUpAndVerify( file_path: " & $file_path & ")=>>>>>>>", @ScriptLineNumber, 6)
	debug("SearchUpAndVerify( extension: " & $ext & ")=>>>>>>>", @ScriptLineNumber, 6)

	$file_path = PrependLongPathPrefix($file_path)
	local $dir_path = GetLongParentDir($file_path)
	local $search_level = 1
	local $hash_path
	local $last_dir = false
	local $base_name = BaseName($file_path)

	debug("search_file =>" & $file_path & "<=", @ScriptLineNumber, 6)
	debug("search_file_dir =>" & $dir_path & "<=", @ScriptLineNumber, 6)

	$my_msg = _T("checksum is searching for hash entry matching")
	DoProgressTips($my_msg & ": " & $base_name)

	while true

		local $line_match = false
		$result = false
		debug("search_level =>" & $search_level & "<=", @ScriptLineNumber, 6)

		if $search_level = 1 then

			if $file_extensions = $ON then
				$hash_path = $file_path & $ext
			else
				$hash_path = RemoveExtension($file_path) & $ext
			endif
			if FileExists($hash_path) then
				debug("GOT TEST HASHFILE (INDIVIDUAL FILE HASH) =>" & $hash_path & "<=", @ScriptLineNumber, 6)
				$line_match = SearchFileForPattern($hash_path, $base_name)
				if $line_match == $status_result_codes[0] then return $status_result_codes[0] ; "quit"
				if $line_match then
					$result = VerifyHashFile($hash_path, "", "", $base_name, $line_match)
				endif
				debug("RESULT =>" & $result & "<=", @ScriptLineNumber, 6)
			endif

		endif

		if not $result then

			$hash_path = $dir_path & "\" & BaseName($dir_path) & $ext
			debug("search_file_dir =>" & $dir_path & "<=", @ScriptLineNumber, 6)
			debug("test for hashfile =>" & $hash_path & "<=", @ScriptLineNumber, 6)

			if FileExists($hash_path) then

				debug("GOT TEST HASHFILE (FOLDER HASH) =>" & $hash_path & "<=", @ScriptLineNumber, 6)
				debug("search_file =>" & $file_path & "<=", @ScriptLineNumber, 6)
				local $rel_file = StringReplace($file_path, $dir_path & "\", "")
				debug("rel_file =>" & $rel_file & "<=", @ScriptLineNumber, 6)

				local $send_target = false
				$my_msg = _T("checksum is searching")
				DoProgressTips($my_msg & " " & FormatPathForDisplay($hash_path) & " for " & $base_name)
				local $timer = TimerInit()
				local $found_lines = SearchFileForPattern($hash_path, $rel_file, true, true)
				debug("SearchFileForPattern TOOK =>" & Round(TimerDiff($timer) / 1000, 2) & " " & _T("seconds"), @ScriptLineNumber, 6)
				debugPrintArray($found_lines, "SearchUpAndVerify() ---> found_lines", @ScriptLineNumber, 6)
				if $found_lines == $status_result_codes[0] then return $status_result_codes[0] ; "quit"

				if IsArray($found_lines) and $found_lines[0][0] then
					for $i = 0 to UBound($found_lines) - 1
						select
							case StringInStr($found_lines[$i][1], $file_path)
								$send_target = $file_path
							case StringInStr($found_lines[$i][1], StripLongPathPrefix($file_path))
								$send_target = StripLongPathPrefix($file_path)
							case StringLeft($found_lines[$i][1], 1) <> "#" and StringLeft($found_lines[$i][1], 1) <> ";"
								if $found_lines[$i][1] then
									local $hash_format = CheckHashformat($found_lines[$i][1], $hash_path)
									if IsArray($hash_format) and $hash_format[0] = $rel_file then $send_target = $rel_file
								endif
						endselect
						if $send_target then
							$line_match = $found_lines[$i][0]
							exitloop
						endif
					next
				endif

				if not $line_match then
					debug("Searching for UNIX rel_file  =>" & StringReplace($rel_file, "\", "/") & "<=", @ScriptLineNumber, 6)
					$line_match = SearchFileForPattern($hash_path, StringReplace($rel_file, "\", "/"))
					if $line_match == $status_result_codes[0] then return $status_result_codes[0] ; "quit"
					if $line_match then $send_target = $rel_file
				endif

				debug("SearchFileForPattern TOTAL TOOK =>" & Round(TimerDiff($timer) / 1000, 2) & " " & _T("seconds"), @ScriptLineNumber, 6)
				debug("line_match =>" & $line_match & "<=", @ScriptLineNumber, 6)
				debug("SEARCH_TO_SEND =>" & $send_target & "<=", @ScriptLineNumber, 6)

				SetTrayTip(_T("checksum is testing") & ".. " & BaseName($hash_path))
				if $send_target then
					$result = VerifyHashFile($hash_path, "", "", $send_target, $line_match)
					debug("VerifyHashFile() result =>" & $result & "<=", @ScriptLineNumber, 6)
				endif
			endif
		endif

		if $result then
			if $result == $status_result_codes[1] then return $result
			if $user_quit then return $status_result_codes[0] ; "quit"
			$found_verify_path = $hash_path
			return $result
		endif

		debug("NO RELEVANT HASH FILE HERE!!! =>" & $result & "<=", @ScriptLineNumber, 6)

		$last_dir = $dir_path
		$dir_path = GetLongParentDir($dir_path)
		if $dir_path = $last_dir then exitloop
		$search_level += 1
	wend

endfunc





; Unless told otherwise, we'll treat directories as recursible, files as not.
; So if it is a directory, set $do_recurse to true..
func DetermineRecurseFromPath($path)
	$do_recurse = false
	if IsDir($path) then $do_recurse = true
endfunc







func _________________________________LOGGING()
endfunc



;
; DoFinalReportDialog()

; Displays final summary report dialog after hash operation complete.
;
func DoFinalReportDialog()

	debug($LF, @ScriptLineNumber, 6)
	debug("DoFinalReportDialog(mode)      --->" & $operation_mode & "<=", @ScriptLineNumber, 6)

	local $my_report_msg
	local $freq = $beep_freq
	if $has_failures then
		$beep_success = $beep_fail
	else
		$freq *= 2
	endif

	if $beep_alerts = $ON and not $user_quit then
		if $beep_success then
			SoundPlay($beep_success)
		else
			Beep($freq, 33)
			Sleep(25)
			Beep($freq, 33)
		endif
	endif

	local $report_msg = ""
	local $status
	; local $plural_s
	local $mail_result = 0
	local $elapsed = $elapsed_time_seconds & "s"
	if $readable_times = $ON then $elapsed = FormatHumanTime($elapsed_time_seconds)
	local $action_desc
	local $op_path = FormatPathForDisplay($path)

	if $operation_mode = "upgrade" then

		if $quiet_operation = $OFF then
			if $elapsed_time_seconds > $long_operation or $long_operation = 0 or $has_failures then
				local $my_icon = $MB_ICONINFORMATION
				if $has_failures or $result = 0 then $my_icon = $MB_ICONWARNING
				debug("DoFinalReportDialog() -----> result: =>" & $result & "<=" , @ScriptLineNumber, 6)
				local $my_pl = _T("hash")
				if $result > 1 then $my_pl = _T("hashes")
				if $result > 0 then $upgrade_final_msg &= $LF & $result & " " & $my_pl & " " & _T("upgraded")
				MsgBox($my_icon + $MB_TOPMOST, $app_name & " " & _T("finished in") & " " & $elapsed, SwitchLineFeedsForDialogs($upgrade_final_msg), $dialog_timeout)
			endif
		endif

		if $upgrade_log <> "" then
			local $upgrade_log_handle = OpenFileHandle("checksum-hash-upgrade.log", $FO_APPEND)
			_LFN_FileWrite($upgrade_log_handle,  "checksum hash upgrade:" & $LF & $upgrade_log & $LF & $LF)
			FileClose($upgrade_log_handle)
		endif

	elseif $operation_mode = "create" then

		; 1. File hashing summary
		if $files_hashed_count < 1 then
			$exit_code_value = -5
			$report_msg &= @LF & @LF & _T("No files were hashed!")
		elseif $files_hashed_count == 1 then
			$report_msg &= @LF & @LF & _T("1 file hashed.")
		else
			$report_msg &= @LF & @LF & _T("[count] files hashed.", "[count]", $files_hashed_count)
		endif

		; 2. Extension switched summary
		if $extension_switched_count == 1 then
			$report_msg &= @LF & @LF & _T("1 extension switched!")
		elseif $extension_switched_count > 1 then
			$report_msg &= @LF & @LF & _T("[count] extensions switched!", "[count]", $extension_switched_count)
		endif

		; 3. Legacy extension rename summary
		if $legacy_ext_rename_count == 1 then
			$report_msg &= @LF & @LF & _T("1 unified extension applied!")
		elseif $legacy_ext_rename_count > 1 then
			$report_msg &= @LF & @LF & _T("[count] unified extensions applied!", "[count]", $legacy_ext_rename_count)
		endif

		; 4. Unwritable paths list
		if $unwritable_paths_list then
			local $trimmed_paths = StringTrimRight($unwritable_paths_list, 1)
			$report_msg &= @LF & @LF & _T("Couldn't write these checksum files..") & @LF & @LF & $trimmed_paths & "."
		endif

		; 5. Operation description & progress
		$action_desc = _T("hashing: [path]", "[path]", $op_path)
		$my_report_msg = _T("checksum completed [action] in [time]", "[action]", $action_desc, "[time]", $elapsed)

		debug("checksum completed =>" & $action_desc & " in " & $elapsed & "<=", @ScriptLineNumber, 6)
		DoProgressTips($my_report_msg)

		; 6. Final dialog title logic
		if $quiet_operation = $OFF then
			local $msg_title = ""
			if $user_quit then
				$msg_title = _T("Quit after [time]", "[time]", $elapsed)
			elseif $files_hashed_count < 1 then
				$msg_title = _T("Completed in [time]", "[time]", $elapsed)
			else
				$msg_title = _T("Hashing completed in [time]", "[time]", $elapsed)
			endif

			if $elapsed_time_seconds > $long_operation or $long_operation = 0 then
				local $dialog_title = _T("checksum is finished")
				MsgBox($MB_ICONINFORMATION + $MB_TOPMOST, $dialog_title, $msg_title & "  " & $report_msg, $dialog_timeout)
			endif
		endif

	else ; Verify

		$action_desc = _T("verifying") & ": " & $op_path
		if $result == $status_result_codes[3] then ; "rd_quit"
			if $quiet_operation = $OFF then
				MsgBox($MB_ICONERROR + $MB_TOPMOST, _T("Premature exit!"), _T("You quit before I could find all the hashes!"), $dialog_timeout)
			endif
			debug("quit before hashes found: ----->	EXIT 8" , @ScriptLineNumber, 1)
			exit 8
		endif

		if $result == "nada" then
			if $quiet_operation = $OFF then
				$my_msg = _T("Nothing to check!")
				$full_text = _T("Try creating some checksum files first, using the 'c' switch..")
				MsgBox($MB_ICONERROR + $MB_TOPMOST, _T("Error!"), $my_msg & @LF & _
					$full_text & @LF & @LF & @ScriptName & "  c  " & $op_path & "	", $dialog_timeout)
			endif
			debug("no checksums found: ----->	EXIT 2" , @ScriptLineNumber, 1)
			exit 2
		endif

		debug("FINAL REPORT result =>" & $result & "<=", @ScriptLineNumber, 6)
		debug("job_count =>" & $files_hashed_count & "<=", @ScriptLineNumber, 6)

		local $success_msg = ""
		select
			case $result == "noexist" and $path_already_exists_flag
				$report_msg = _T("THE FILE DOES not EXIST!")
				$success_msg = ""

			case $result == $status_result_codes[1] ; "cancel"
				$report_msg = _T("Operation Cancelled.")
				$success_msg = ""
				$exit_code_value = -30

			case $result == $status_result_codes[0] ; "quit"
				if $files_hashed_count < 1 then
					$report_msg = _T("NOTHING WAS DONE!")
					$success_msg = ""
					$exit_code_value = -14
				else
					$report_msg = _T("Operation Cancelled.")
					$success_msg = ""
					$exit_code_value = -9
				endif

			case $files_hashed_count < 1
				if $search_and_verify = $ON then
					$report_msg = _T("No matching hash could be found!")
					$status_success = _T("No Match!")
				else
					$report_msg = _T("THERE WAS NOTHING TO DO!")
				endif
				$success_msg = ""
				$exit_code_value = -5

			case else
				$success_msg = _T("Success!\nNo errors. All data is 100% intact.")
		endselect


		if $files_hashed_count == 1 then
			; TODO: report algos checked (gather during GetHashesFromFile()).
			$report_msg &= @LF & @LF & _T("1 hash verified.")
		elseif $files_hashed_count > 1 then
			$report_msg &= @LF & @LF & _T("[count] hashes verified.", "[count]", $files_hashed_count)
		endif

		local $location_msg = ""
		local $del_msg = "", $upd_msg = ""

		if $hashes_deleted_count == 1 then
			$del_msg = @LF & _T("(1 hash was deleted)")
		elseif $hashes_deleted_count > 1 then
			$del_msg = @LF & _T("([count] hashes were deleted)", "[count]", $hashes_deleted_count)
		endif

		if $hashes_updated_count == 1 then
			$upd_msg = @LF & _T("(1 hash was updated)")
		elseif $hashes_updated_count > 1 then
			$upd_msg = @LF & _T("([count] hashes were updated)", "[count]", $hashes_updated_count)
		endif

		if $del_msg or $upd_msg then
			$report_msg &= @LF & $del_msg & $upd_msg
			$location_msg &= @LF & $del_msg & $upd_msg
		endif

		debug("del_msg =>" & $del_msg & "<=", @ScriptLineNumber, 6)
		debug("upd_msg =>" & $upd_msg & "<=", @ScriptLineNumber, 6)
		debug("badfile =>" & $bad_file_paths_list & "<=", @ScriptLineNumber, 6)

		if $bad_file_paths_list <> "" then
			if $quiet_operation = $OFF and not $user_quit then
				local $err_prefix = _T("The file..")
				local $err_suffix = _T(".. is not a valid checksum file!")
				$bad_file_paths_list = StringTrimRight($bad_file_paths_list, 1)
				local $bad_files = StringSplit($bad_file_paths_list, "|")
				if $bad_files[0] > 1 then
					$err_prefix = _T("These files..")
					$err_suffix = _T(".. are not checksum files!")
					$bad_file_paths_list = ""
					for $i = 1 to $bad_files[0]
						if $bad_files[$i] then $bad_file_paths_list &= $bad_files[$i] & @CRLF
					next
					$bad_file_paths_list = StringTrimRight($bad_file_paths_list, 1)
				endif
				$my_msg = _T("You can copy and paste from here if required. Click OK to continue..")
				ShowBadFilesBox( _T("hash file read error!"), $err_prefix & @CRLF & @CRLF & $bad_file_paths_list & @CRLF & @CRLF & $err_suffix, 600, 400, $my_msg, $dialog_timeout)
				if $path_already_exists_flag then
					debug("invalid hash file: ----->	EXIT 3" , @ScriptLineNumber, 1)
					exit 3
				endif
			else
				$exit_code_value = 3
			endif
		endif

		debug("result =>" & $result & "<=", @ScriptLineNumber, 6)
		debug("failures =>" & $has_failures & "<=", @ScriptLineNumber, 6)

		if $found_verify_path then
			debug("found_verify_path =>" & $found_verify_path & "<=", @ScriptLineNumber, 6)

			$location_msg = @LF & @LF & _T('Located hash for') & "'" & BaseName($path) & "'" & _T("in") & ": " & @LF & FormatPathForDisplay($found_verify_path)
			$report_msg &= $location_msg
		endif

		if $has_failures or $result == $status_result_codes[1] then
			$status = $status_fail
			SetTipWarnColor()
			$my_report_msg = _T("checksum completed") & "  " & $action_desc & " " & _T("in") & " " & $elapsed & ".. [" & $status_fail & "]"
			DoProgressTips($my_report_msg)
			$exit_code_value = -2
		else
			$status = $status_success
			$my_report_msg = "[" & $status_success & "] " & _T("checksum completed") & " " & $action_desc & " " & _T("in") & " " & $elapsed
			DoProgressTips($my_report_msg)
			debug("checksum completed =>" & $action_desc & " in " & $elapsed & ".. [" & $status_success & "]" & "<=", @ScriptLineNumber, 6)
			debug("my_report_msg =>" & $my_report_msg & "<=", @ScriptLineNumber, 6)
			if $quiet_operation = $OFF then
				if $elapsed_time_seconds > $long_operation or $long_operation = 0 then
					MsgBox($MB_ICONINFORMATION + $MB_TOPMOST, $app_name & " " & _T("finished in") & " " & $elapsed, _L($success_msg) & $report_msg, $dialog_timeout)
				endif
			endif
		endif

		if $operation_mode = "verify" then DoLogOutput("out", "", $status, "", "", false, default, default, $location_msg)

		if $has_failures and $mail_on_failure = $ON then
			SetTipWarnColor()

			$my_report_msg = _T("checksum is sending a notification mail") & ".. [" & $status_fail & "]"
			DoProgressTips($my_report_msg)

			$mail_result = SendMailOnFail()
			debug("MAIL-ON-FAIL SENT =>" & $mail_result & "<=", @ScriptLineNumber, 6)
			local $retry_count = 0
			if $mail_result <> "sent" and $resend_mail = $ON then
				while $retry_count < $resend_mail_max_retry and $mail_result <> "sent"


					$my_report_msg = _T("checksum sending mail failed - sleeping") & " " & $retry_delay_seconds & "s " & _T("for retry..")
					DoProgressTips($my_report_msg)

					Sleep($retry_delay_seconds * 1000)
					if $user_quit then exitloop
					$mail_result = SendMailOnFail()
					$retry_count += 1
				wend
			endif
		endif

		SetTrayTip(_t("checksum is finished") & "..")
		if $compress_logs = $ON then
			local $norm_log_path = GetLongParentDir($log_file_path)
			if not StringInStr(_LFN_FileGetAttrib($norm_log_path), "C", $STR_NOCASESENSEBASIC) then
				$log_folder_path_alias = DeTokenize($log_folder_path_alias, $path, "path")
				if StringRight($log_folder_path_alias, 1) = "\" then $log_folder_path_alias = StringTrimRight($log_folder_path_alias, 1)
				if $log_folder_path_alias = $norm_log_path and ($norm_log_path <> $script_dir) then
					Run(@ComSpec & " /c " & 'compact.exe /C "' & $norm_log_path & '"', "", @SW_HIDE)
				endif
				Run(@ComSpec & " /c " & 'compact.exe /C "' & $norm_log_path & "\*.log", "", @SW_HIDE)
				Run(@ComSpec & " /c " & 'compact.exe /C "' & $norm_log_path & "\*.html", "", @SW_HIDE)
			endif
		endif
	endif


	if $pause and $progress_tip = $ON and not $user_quit then Sleep($pause)
	debug("log_path =>" & $log_file_path & "<=", @ScriptLineNumber, 6)

	if $open_log_folder = $ON then
		if $log_to_file = $ON and $log_file_handle then
			if not WinExists(StripLongPathPrefix(GetLongParentDir($log_file_path))) then
				Run("Explorer.exe " & GetLongParentDir($log_file_path))
			else
				WinActivate(GetLongParentDir($log_file_path))
			endif
		endif
	endif

	return $mail_result
endfunc



#cs
$log_entries_array:
		[0]	[0] = my.show.s03e01..hash		[1] = *M:\path\to\shows\my.show.s03e01..mkv|CORRUPT|MD5		[2] = 		[3] = True
		[1]	[0] = my.show.s03e02..hash		[1] = 		[2] = 		[3] = false
		[2]	[0] = my.show.s03e03..hash		[1] = 		[2] = 		[3] = false
		[3]	[0] = my.show.s03e04..hash		[1] = 		[2] = 		[3] = false
		[4]	[0] = my.show.s03e05..hash		[1] = 		[2] = 		[3] = false
		[5]	[0] = my.show.s03e06..hash		[1] = 		[2] = 		[3] = false
		[6]	[0] = my.show.s03e07..hash		[1] = 		[2] = 		[3] = false
		[7]	[0] = my.show.s03e08..hash		[1] = *M:\path\to\shows\my.show.s03e08..mkv|CORRUPT|MD5		[2] = 		[3] = True
		[8]	[0] = my.show.s03e09..hash		[1] = 		[2] = 		[3] = false
		[9]	[0] = my.show.s03e10..hash		[1] = 		[2] = 		[3] = false
#ce

;
; DoLogOutput()

; Formats debug output string with optional source context prefix then writes to
; console or dump file (when compiled); handles multi-line arrays recursively.
; And yes, this is some convoluted shit! But it gets the job done.
;
func DoLogOutput($log_entry, $log_level=1, $status="", $checksum_file="", $idx="", $is_last_entry=false, $processing_time="", $my_algo_id=3, $my_report_msg="")

	if $processing_time = default then $processing_time = ""
	if $is_last_entry = default then $is_last_entry = false
	if $my_algo_id = default then $my_algo_id = DefaultAlgoID()

	debug($LF, @ScriptLineNumber, 9)
	debug("DoLogOutput() ---> ", @ScriptLineNumber, 9)
	debug("DoLogOutput() ---> log_entry        =>" & $log_entry & "<=", @ScriptLineNumber, 9)
	debug("DoLogOutput() ---> log_level        =>" & $log_level & "<=", @ScriptLineNumber, 9)
	debug("DoLogOutput() ---> status           =>" & $status & "<=", @ScriptLineNumber, 9)
	debug("DoLogOutput() ---> checksum_file    =>" & $checksum_file & "<=", @ScriptLineNumber, 9)
	debug("DoLogOutput() ---> idx              =>" & $idx & "<=", @ScriptLineNumber, 9)
	debug("DoLogOutput() ---> is_last_entry    =>" & $is_last_entry & "<=", @ScriptLineNumber, 9)
	debug("DoLogOutput() ---> processing_time  =>" & $processing_time & "<=", @ScriptLineNumber, 9)
	debug("DoLogOutput() ---> my_algo_id       =>" & $my_algo_id & "<=", @ScriptLineNumber, 9)
	debug("DoLogOutput() ---> my_report_msg    =>" & $my_report_msg & "<=", @ScriptLineNumber, 9)

	local $my_algo_str = $algorithm_strings[$my_algo_id]
	debug("DoLogOutput() ---> my_algo_str =>" & $my_algo_str & "<=", @ScriptLineNumber, 9)

	; BAD MISSING CORRUPT CHANGED ERROR
	if $status = $hash_status_codes[1] or $status = $hash_status_codes[2] or $status = $hash_status_codes[4] or _
										$status = $hash_status_codes[5] or $status = $hash_status_codes[9]  then
		$queue_entry_has_failures = true
		local $queue_size = UBound($file_queue_array)
		ReDim $file_queue_array[$queue_size + 1][2]
		if $status = $hash_status_codes[1] then $status &= " " & _T("FILE")
		$file_queue_array[$queue_size][0] = $status
		$file_queue_array[$queue_size][1] = $log_entry
	endif

	debugPrintArray($log_entries_array, "DoLogOutput() ---> $log_entries_array", @ScriptLineNumber, 9)
	debug("DoLogOutput() ---> checksum_file: =>" & $checksum_file & "<=" , @ScriptLineNumber, 9)


	; Single log entry, add to the log array..
	if $log_entry <> "out" then

		; New hash file..
		if $idx = 1 then
			$log_entry_counter += 1
			ReDim $log_entries_array[$log_entry_counter][4]
			local $checksum_file_name = BaseName($checksum_file)
			if $hashfile_paths = $OFF then
				$checksum_file = $checksum_file_name
			else
				$checksum_file = FormatPathForDisplay($checksum_file)
				if StringLen($checksum_file) > $truncate_at then
					$checksum_file = StringLeft($checksum_file, $truncate_at - StringLen($checksum_file_name) - 3) & " &hellip; " & $checksum_file_name
				endif
			endif
			$log_entries_array[$log_entry_counter - 1][0] = $checksum_file
		endif

		; Last entry for this hash file..
		if $is_last_entry then
			if $log_entry_counter > 0 then
				$log_entries_array[$log_entry_counter - 1][3] = $queue_entry_has_failures
				if $display_times = $ON then
					if $readable_times = $ON then
						$log_entries_array[$log_entry_counter - 1][2] = FormatHumanTime(Round($processing_time, 3))
					else
						$log_entries_array[$log_entry_counter - 1][2] = Round($processing_time, 3) & "s"
					endif
					$total_processing_time_seconds += $processing_time
				endif
			endif
			if $log_entry = "" then return
		endif
		debug("DoLogOutput() ---> log_entry_counter =>" & $log_entry_counter & "<=", @ScriptLineNumber, 9)

		if $log_level > 1 and $log_everywhere_flag < 2 then
			return
		else
			if $log_entry_counter > 0 then
				$log_entries_array[$log_entry_counter - 1][1] &= "*" & FormatPathForDisplay($log_entry) & "|" & $status & "|" & $my_algo_str
			endif
		endif

		debugPrintArray($log_entries_array, "DoLogOutput() ---> $log_entries_array", @ScriptLineNumber, 9)
		return

	endif


	;
	; Final entry, finish the log..

	debug("DoLogOutput() ---> log_name =>" & $log_name & "<=", @ScriptLineNumber, 9)
	debug("DoLogOutput() ---> path =>" & $path & "<=", @ScriptLineNumber, 9)
	debug("DoLogOutput() ---> log_folder =>" & $log_folder & "<=", @ScriptLineNumber, 9)
	debug("DoLogOutput() ---> log_parent =>" & $log_parent & "<=", @ScriptLineNumber, 9)

	$log_name = DeTokenize($log_name, $path, "file")
	if $log_folder and StringRight($log_folder, 1) <> "\" then $log_folder &= "\"
	$log_file_path = $log_folder & $log_name
	debug("DoLogOutput() ---> log_file_path =>" & $log_file_path & "<=", @ScriptLineNumber, 9)

	if $log_path_type = "relative" and not StringInStr($log_folder, @ScriptDir) then
		$log_file_path = $log_parent & $log_folder & $log_name
	endif
	debug("DoLogOutput() ---> log_file_path =>" & $log_file_path & "<=", @ScriptLineNumber, 9)
	debug("DoLogOutput() ---> log_format =>" & $log_format & "<=", @ScriptLineNumber, 9)
	debugPrintArray($log_entries_array, "DoLogOutput() ---> $log_entries_array", @ScriptLineNumber, 9)

	$html_data = ""
	local $entries_split, $entry_fields
	local $file_ext = ($log_format = "html" ? "html" : "log")
	$log_file_path &= "." & $log_format

	if $log_format = "html" then

		debug("DoLogOutput() ---> log_file_path =>" & $log_file_path & "<=", @ScriptLineNumber, 9)

		for $idx = 0 to UBound($log_entries_array) - 1
			if $log_entries_array[$idx][1] <> "" then
				local $class_attr = ""
				if $log_entries_array[$idx][3] = 1 then $class_attr = 'class="has_fails" '
				$html_data &= '<div class="label"><h4 ' & $class_attr & 'title="click this label to toggle the hashes in this checksum file">' _
																												& @LF & $log_entries_array[$idx][0]
				if $display_times = $ON then
					$html_data &= ' &nbsp;&nbsp;<span class="log_times">[checked in ' & $log_entries_array[$idx][2] & "]</span>"
				endif
				$html_data &= "</h4>" & @LF & "</div>" & @LF & '<div class="blocks">' & @LF
				$entries_split = StringSplit($log_entries_array[$idx][1], "*")
				debug("DoLogOutput() ---> SPLITTING: =>" & $log_entries_array[$idx][1] & "<=" , @ScriptLineNumber, 9)
				debugPrintArray($entries_split, "$entries_split 1:", @ScriptLineNumber, 8)

				if IsArray($entries_split) and $entries_split[0] >= 2 then
					for $item_idx = 2 to $entries_split[0]
							$entry_fields = StringSplit($entries_split[$item_idx], "|")
							debugPrintArray($entry_fields, "$entry_fields:", @ScriptLineNumber, 8)
							if IsArray($entry_fields) and $entry_fields[0] >= 3 then
								local $hash_algo_tag = "(" & $entry_fields[3] & ")"
								local $entry_folder_url = "file:///" & StringReplace(StringLeft($entry_fields[1], StringInStr($entry_fields[1], "\", 0, -1)), "\", "/")
								if $entry_fields[2] = $hash_status_codes[1] & " " & _T("FILE") then $hash_algo_tag = ""
								$html_data &= '<div class="result"><span class="checksum-' & $entry_fields[2] & '"><a href="' & $entry_folder_url & '">' & $entry_fields[1] & _
								"</a></span>" & '<span class="status ' & $entry_fields[2] & '">&nbsp;&nbsp;' & $hash_algo_tag & " " & $entry_fields[2] & "</span><br /></div>" & @LF
						endif
					next
				else
					$html_data &= '<div class="result">INVALID ENTRY</div>'
				endif
				$html_data &= @LF & '<div class="clear">&nbsp;</div>' & @LF & "</div>"
			endif
		next
	else
		; Plain text .log..
		for $idx = 0 to UBound($log_entries_array) - 1
			if $log_entries_array[$idx][1] <> "" then
				$html_data &= @LF & $log_entries_array[$idx][0]
				if $display_times = $ON then
					$html_data &= "  [checked in " & $log_entries_array[$idx][2] & "]"
				endif
				$html_data &= @LF
				$entries_split = StringSplit($log_entries_array[$idx][1], "*")
				debugPrintArray($entries_split, "$entries_split 2:", @ScriptLineNumber, 9)

				if IsArray($entries_split) and $entries_split[0] >= 2 then
					for $item_idx = 2 to $entries_split[0]
						$entry_fields = StringSplit($entries_split[$item_idx], "|")
						if IsArray($entry_fields) and $entry_fields[0] >= 2 then
							$entry_fields[2] = StringReplace($entry_fields[2], $hash_status_codes[0], "Passed:") ; Passed
							$html_data &= $entry_fields[2] & ": " & $entry_fields[1] & @LF
						endif
					next
				else
					$html_data &= 'INVALID ENTRY'
				endif
			endif
		next
	endif

	if $html_data <> "" then

		local $msgbox_flags = $MB_ICONINFORMATION
		local $error_heading = ""
		local $error_prompt = ""
		local $total_time_str = ""

		if $total_times = $ON then
			if $readable_times = $ON then
				$total_processing_time_seconds = FormatHumanTime(Round($total_processing_time_seconds, 3))
			else
				$total_processing_time_seconds &= "s"
			endif
			switch $log_format
				case "text"
					$total_time_str = " [total time: " & $total_processing_time_seconds & "]"
				case "html"
					$total_time_str = ' &nbsp;&nbsp;<span class="log_times">[total time: ' & $total_processing_time_seconds & "]</span>"
			endswitch
		endif

		local $error_list_text
		if $has_failures then
			debug("DoLogOutput() ---> ERROR: GOT FAILURES!!!", @ScriptLineNumber, 9)
			debugPrintArray($file_queue_array, "DoLogOutput() ---> $file_queue_array", @ScriptLineNumber, 9)
			$msgbox_flags = $MB_ICONERROR
			$error_list_text = ""
			$error_heading = _T("There were errors..")
			$error_prompt = _T("A log will be created, here") & " .." & @LF & @LF & FormatPathForDisplay($log_file_path) & "  "

			if UBound($file_queue_array) > $error_display_limit then
				if $log_to_file = $OFF then $log_to_file = $ON
				$error_heading = _T("There were too many errors to display.")
			else
				$error_list_text = @LF & @LF
				local $start_err_idx = UBound($file_queue_array) - $error_display_limit
				if UBound($file_queue_array) = 2 then $error_heading = _T("There was an error..")
				if $start_err_idx < 0 then $start_err_idx = 0
				for $idx = $start_err_idx to UBound($file_queue_array) - 1
					if $file_queue_array[$idx][1] then $error_list_text &= "  " & $file_queue_array[$idx][0] & "  " & _
															Chr(187) & "  " & BaseName($file_queue_array[$idx][1]) & " " & @LF
				next
			endif

			if $log_to_file = $OFF then
				$msgbox_flags = $MB_YESNO + $MB_ICONERROR
				$error_prompt = _T("Do you wish to save a log of these errors?")
				if UBound($file_queue_array) = 2 then $error_prompt = _T("Do you wish to log this error?")
			endif

			if $my_report_msg then $my_report_msg = StringStripWS($my_report_msg, $STR_STRIP_ENDS) & @LF & @LF

			if $quiet_operation = $OFF then
				$my_msg = _T("completed")
				local $msgbox_response = MsgBox($msgbox_flags, $app_name & " " & $my_msg & " [" & _T("in") & " " & $elapsed_time_seconds & "s]", $error_heading & _
																							$error_list_text & @LF & $my_report_msg & $error_prompt, $dialog_timeout)
				if $msgbox_response = $IDYES or $msgbox_response = $IDTIMEOUT then $log_to_file = $ON
			endif
		endif

		if $log_to_file = $ON then
			debug("DoLogOutput() ---> log_name =>" & $log_name & "<=", @ScriptLineNumber, 9)
			SetTrayTip(_T("checksum is writing out the log file") & ".. ")
			local $is_desktop_fallback = false
			local $title_prefix = ""
			if $path_in_titles = $ON then $title_prefix = BaseName($path) & " @ "

			$log_file_handle = OpenFileHandle($log_file_path, $FO_APPEND + $FO_CREATEPATH + $utf8_file_mode_flag)
			_LFN_FileClose($log_file_handle)

			if $log_file_handle = -1 then
				$log_file_path = @DesktopDir & "\" & $log_name & "." & $file_ext
				$is_desktop_fallback = true
			endif

			debug("DoLogOutput() ---> log_path =>" & $log_file_path & "<=", @ScriptLineNumber, 9)

			switch $log_format
				case "text"
					if $append_logs = $ON then
						$log_file_handle = OpenFileHandle($log_file_path, $FO_APPEND + $FO_CREATEPATH + $utf8_file_mode_flag)
					else
						$log_file_handle = OpenFileHandle($log_file_path, $FO_OVERWRITE + $FO_CREATEPATH + $utf8_file_mode_flag)
					endif
					_LFN_FileWriteLine($log_file_handle, @LF & $app_name & " report " & "[" & $title_prefix & $timestamp_string & "]" & $total_time_str & _
													" .. " & @LF & "--------------------------------------------------------------------------------" & @LF)
					_LFN_FileWriteLine($log_file_handle, $html_data & @LF & @LF)
					_LFN_FileClose($log_file_handle)

				case "html"
					local $is_new_html_log = true
					if $append_logs = $ON and _LFN_FileExists($log_file_path) and (_LFN_FileGetSize($log_file_path) > 10) then
						$is_new_html_log = false
						local $read_file = OpenFileHandle($log_file_path, $FO_READ + $utf8_file_mode_flag)
						$log_string = _LFN_FileRead($read_file)
						_LFN_FileClose($read_file)
						FooterSeparator()
					endif

					if $is_new_html_log then HTMLLog()

					local $day_fails_class = ""
					if $has_failures then $day_fails_class = 'class="day_fails" '

					$log_string &= '<div class="label"><h3 ' & $day_fails_class & 'title="click this label to toggle the checksum files for this date and time">' & _
										$title_prefix & $timestamp_string & $total_time_str & "</h3>" & @LF & "</div>" & @LF & @LF & '<div class="blocks">' & @LF & @LF
					$log_string &= $html_data & @LF & "</div>" & @LF
					DoLogFooter()

					$log_file_handle = OpenFileHandle($log_file_path, $FO_OVERWRITE + $FO_CREATEPATH + $utf8_file_mode_flag)
					_LFN_FileWriteLine($log_file_handle, $log_string & @LF & @LF)
					_LFN_FileClose($log_file_handle)
			endswitch

			local $log_loc_known = IniReadCheckBox($ini_path, "dialogs", "log location known", $OFF)
			local $desktop_fallback_known = IniReadCheckBox($ini_path, "dialogs", "desktop fall-back known", $OFF)
			local $location_msg = _T("to") & " " & GetLongParentDir($log_file_path) & "    "
			local $reminder_msg = _T("From now on, you are expected to remember that logs go there.\n(unless you specify otherwise)")

			if $is_desktop_fallback then
				$location_msg = _T("on your desktop.\n(the log folder was not accessible)")
				$reminder_msg = _T("Sometimes it's not possible to save logs to where you specified.")
				IniWrite($ini_path, "dialogs", "desktop fall-back known", "yes")
			endif

			if $log_loc_known = $OFF or ($is_desktop_fallback and $desktop_fallback_known = $OFF) then
				if $quiet_operation = $OFF then
					MsgBox($MB_ICONINFORMATION + $MB_TOPMOST, $app_name & " " & _T("report"), _T("The log has been saved") & " " & $location_msg & @LF & @LF & $reminder_msg, $dialog_timeout)
				endif
				IniWrite($ini_path, "dialogs", "log location known", "yes")
			endif
		endif
	endif

endfunc




;
; GetLogPath()

; Returns the configured log folder path.
;
func GetLogPath()

	if $do_recurse then
		$log_parent = $path
	else
		$log_parent = GetLongParentDir($path)
	endif

	if StringRight($log_parent, 1) <> "\" then $log_parent &= "\"
	$log_folder = DeTokenize($log_folder, $path, "path")
	debug($LF, @ScriptLineNumber, 9)
	debug("GetLogPath() ---> log_folder =>" & $log_folder & "<=", @ScriptLineNumber, 9)
	debug("GetLogPath() ---> script_dir =>" & $script_dir & "<=", @ScriptLineNumber, 9)

	if StringInStr($log_folder, $script_dir) then
		if StringInStr($log_folder, "/") then $log_folder = StringReplace($log_folder, "/", "\")
		if StringLen($log_folder) > StringLen($script_dir) and not StringInStr($log_folder, "\") then
			$log_folder = StringReplace($log_folder, $script_dir, $script_dir & "\")
		endif
	endif
	debug("GetLogPath() ---> log_folder =>" & $log_folder & "<=", @ScriptLineNumber, 9)

	if StringInStr($log_folder, ":\") or StringInStr($log_folder, "\\") then
		$log_path_type = "absolute"
	else
		$log_path_type = "relative"
	endif
	debug("GetLogPath() ---> log_path_type =>" & $log_path_type & "<=", @ScriptLineNumber, 9)

endfunc



;
; switchLogformat()

; Toggles the global log output format variable between plain-text mode
; producing plain text .log files or cute .html pages.
;
func switchLogformat()
	switch $log_format
		case "text", "plain", "plain text", "plaintext", "plain-text", "txt", "t"
			$log_format = "text"
		case "html", "xhtml", "htm", "hyper", "hypertext", "x", "h"
			$log_format = "html"
	endswitch
endfunc



;
; HTMLLog()

; Setup styles and such for HTML logging.
;
func HTMLLog()

	local $template_path
	local $target_dir = @ScriptDir	; 2do - check for TMP conditions.. ?

	local $target_css = $target_dir & "\checksum.css"
	local $overwrite_css = 0
	if (FileGetSize($target_css) = 2943 and FileGetTime($target_css, 0, 1) = "20120313172633") or _
	   (FileGetSize($target_css) = 2848 and FileGetTime($target_css, 0, 1) = "20071127143552") or _
	   (FileGetSize($target_css) = 2995 and FileGetTime($target_css, 0, 1) = "20140708125324") or _
	   (FileGetSize($target_css) = 3042 and FileGetTime($target_css, 0, 1) = "20260808222613") or _
	   (FileGetSize($target_css) = 3150 and FileGetTime($target_css, 0, 1) = "20260723235504") then
		$overwrite_css = 1
	endif
	FileInstall("Resources\checksum.css", $target_css, $overwrite_css)

	local $is_temp_template = false
	if _LFN_FileExists($target_dir & "\template.html") then
		$template_path = $target_dir & "\template.html"
	else
		$template_path = @TempDir & "\template.html"
		if not _LFN_FileExists($template_path) then
			FileInstall("Resources\template.html", $template_path)
			$is_temp_template = true
		endif
	endif

	$log_string = StringStripWS(_LFN_FileRead($template_path, _LFN_FileGetSize($template_path)), $STR_STRIP_ENDS)
	$log_string &= $LF & '<style type="text/css" media="screen">' & $LF

	switch $fallback_styles
		case $ON
			$log_string &= '@import "https://corz.org/windows/software/checksum/files/checksum.css";' & $LF
		case $OFF
		case else
			$log_string &= '@import "' & $fallback_styles & '";' & $LF
	endswitch

	switch $master_styles
		case "", $ON
			$log_string &= '@import "file:///' & StringReplace($target_dir, "\", "/") & '/checksum.css";' & $LF
		case "-", $OFF
		case else
			$log_string &= '@import "' & $master_styles & '";' & $LF
	endswitch

	if $embed_styles = $ON then
		$log_string &= _LFN_FileRead($target_css)
	else
		$log_string &= '@import "checksum.css";' & $LF & ".status { float: right; }" & $LF
	endif

	$log_string &= "</style>" & $LF & "<title>checksum logs from " & $timestamp_string & "</title>" & $LF & "</head>" & $LF & "<body>" & $LF & _
	'<div class="logs">' & $LF & $LF & '<h1 id="log-head" title="click here to TOTALLY expand or collapse the entire log (it toggles)">checksum logs <small>from ' & _
	$timestamp_string & "</small></h1>" & $LF & $LF

	if $is_temp_template then DeleteFilesRecursive($template_path)
endfunc



;
; FooterSeparator()

; Strips the footer from the active HTML log file.
;
func FooterSeparator()
	local $qz = StringInStr($log_string, "<!-- footer -->", 2, -1)
	$log_string = StringLeft($log_string, $qz - 1)
endfunc


;
; DoLogFooter()

; Appends summary footer section at end of completed log file:
; When appending to an existing log, this is wiped and re-placed.
;
func DoLogFooter()
	$log_string &= "<!-- footer -->" & $LF & '<div class="link-corz" ><a href="https://corz.org/windows/software/checksum/" ' & _
		'title="checksum.. drop-dead simple file hashing for windows. from corz.org"' & 'id="link-checksum-corz">' & _T("generated by checksum") & _
		'</a><!-- checksum v' & $VERSION & '--></div>' & $LF & "</div>" & $LF & "</body>" & $LF & "</html>" & $LF
endfunc



;
; HTMLEntitize()

; Fixes ampersand characters in text strings for safe HTML output.
;
func HTMLEntitize($input_text)
	$input_text = StringReplace($input_text, "&", "&amp;")
	$input_text = StringReplace($input_text, "&amp;nbsp;", "&nbsp;")
	$input_text = StringReplace($input_text, "&amp;hellip;", "&hellip;")
	return $input_text
endfunc




func _________________________________OPTIONS()
endfunc


;
; DoCreateOptions()																	cro b:\					vro b:\

; The Create options Dialog.
;
func DoCreateOptions()

	debug($LF, @ScriptLineNumber, 7)
	$switches = StringReplace($switches, "o", "", 1)
	debug("DoCreateOptions() initial switches =>" & $switches & "<=", @ScriptLineNumber, 7)

	if $apply_options_to_queue = $ON and FileExists($queue_file) then
		if not StringInStr($switches, "q") then $switches = "q" & $switches
	endif

	local $text_scale = ChecksumDialogTextScale()
	local $old_gui_mode = AutoItSetOption("GUIOnEventMode", 0)
	local $old_coord_mode = AutoItSetOption("GUICoordMode", 1)
	local $opt_width = Int(GetINIArrayValue($ini_array, "create_options_width", 0))
	if $opt_width < 355 or $opt_width > @DesktopWidth then $opt_width = 0
	$GUI_Options = GUICreate($app_name & " " & _T("one-shot create options") & "..", 370, 212, $opt_x, $opt_y, _
		BitOr($WS_MINIMIZEBOX, $WS_CAPTION, $WS_POPUP, $WS_SYSMENU, $WS_SIZEBOX), $WS_EX_ACCEPTFILES)
	GUISetFont(9 * $text_scale, default, default, "Segoe UI", $GUI_Options)

	local $captions = [_T("path") & ":", _T("mask") & ":", _T("behaviour") & "..", _T("recurse"), _T("synchronize"), _
		_T("individual checksums"), _T("one-file 'root' hashes"), _T("record absolute paths"), _T("progress tip"), _T("beeps"), _
		_T("quiet mode (no dialogs)"), _T("shutdown when done"), _T("output") & "..", _T("UPPERCASE"), _T("hide checksums"), _
		_T("add file extensions"), _T("{{winamp}} playlists"), _T("{{shoutcast}} playlists"), _T("output directory") & "..", _
		_T("algorithm") & "..", _T("switches") & "..", _T("do it now!")]
	local $measure = GUICtrlCreateLabel("", 0, 0, 1, 1)
	local $line_height = FitLabelHeight($measure, "Ag", 100)
	local $gap = Ceiling($line_height / 2)
	local $row_height = $line_height + Ceiling($gap / 3)
	local $caption_widths[UBound($captions)]
	for $i = 0 to UBound($captions) - 1
		$caption_widths[$i] = FitLabelWidth($measure, $captions[$i], @DesktopWidth)
	next
	local $checkbox_padding = $line_height + $gap
	local $behaviour_width = _Max($caption_widths[2], _Max($caption_widths[3] + $caption_widths[4], $caption_widths[8] + $caption_widths[9]) + 2 * $checkbox_padding + $gap)
	for $i = 5 to 11
		$behaviour_width = _Max($behaviour_width, $caption_widths[$i] + $checkbox_padding)
	next
	$behaviour_width += 2 * $gap
	local $output_width = $caption_widths[12]
	for $i = 13 to 18
		$output_width = _Max($output_width, $caption_widths[$i] + $checkbox_padding)
	next
	$output_width += 2 * $gap
	local $commands_width = _Max(_Max($caption_widths[19], $caption_widths[20]), $caption_widths[21]) + 3 * $gap
	for $i = 1 to $algorithm_strings[0]
		$commands_width = _Max($commands_width, FitLabelWidth($measure, $algorithm_strings[$i], @DesktopWidth, $line_height + 2 * $gap))
	next
	GUICtrlDelete($measure)

	local $field_left = _Max($caption_widths[0], $caption_widths[1]) + 2 * $gap
	local $groups_top = 2 * $row_height + 3 * $gap
	local $first_row = $groups_top + $row_height
	local $groups_height = 8 * $row_height + $gap
	local $standard_gui_width = _Max($field_left + 12 * $line_height, $behaviour_width + $output_width + $commands_width + 4 * $gap)
	local $base_gui_width = _Max($standard_gui_width, $opt_width)
	local $base_gui_height = $groups_top + $groups_height + $gap
	local $output_left = $behaviour_width + 2 * $gap
	local $commands_left = $base_gui_width - $commands_width - $gap
	local $outer = WinGetPos($GUI_Options)
	local $client = WinGetClientSize($GUI_Options)
	local $frame_width = $outer[2] - $client[0], $frame_height = $outer[3] - $client[1]
	WinMove($GUI_Options, "", _Max(0, _Min($outer[0], @DesktopWidth - $base_gui_width - $frame_width)), _
		_Max(0, _Min($outer[1], @DesktopHeight - $base_gui_height - $frame_height)), $base_gui_width + $frame_width, $base_gui_height + $frame_height)
	GUISetIcon($exe_path, 0, $GUI_Options)
	GUIRegisterMsg($WM_DROPFILES, "HandleDragDropFiles")

	InitPaddedTips()

	GUICtrlCreateLabel($captions[0], $gap, $gap, $field_left - $gap, $row_height)
	SetPaddedTip(-1, _T("hover over the folder path input box for more details."))
	GUICtrlSetResizing(-1, $GUI_DOCKSIZE + $GUI_DOCKLEFT + $GUI_DOCKTOP)

	local $input_basename = ""
	if not IsDir($path) then
		$input_basename = BaseName($path)
		$path = GetLongParentDir($path)
	endif

	local $input_path = GUICtrlCreateInput(FormatPathForDisplay($path), $field_left, $gap, $base_gui_width - $field_left - $gap, $row_height)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKHEIGHT)
	GUICtrlSetState(-1, $GUI_DROPACCEPTED)

	GUICtrlCreateLabel($captions[1], $gap, $row_height + 2 * $gap, $field_left - $gap, $row_height)
	SetPaddedTip(-1, _T("hover over the masks drop-down button for more details."))
	GUICtrlSetResizing(-1, $GUI_DOCKSIZE + $GUI_DOCKLEFT + $GUI_DOCKTOP)

	local $combo__mask = GUICtrlCreateCombo($file_mask, $field_left, $row_height + 2 * $gap, $base_gui_width - $field_left - $gap) ; RTL pointless here
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKHEIGHT)

	local $mask_list = ""
	$inifile_masks_array = IniReadSection($ini_path, "file masks")

	if IsArray($inifile_masks_array) then
		for $mask_idx = 1 to $inifile_masks_array[0][0]
			$mask_list &= $inifile_masks_array[$mask_idx][1] & "|"
		next
	endif

	$mask_list = StringTrimRight($mask_list, 1)
	if $input_basename then
		$mask_list = $mask_list & "|" & $input_basename
		GUICtrlSetData($combo__mask, $mask_list, $input_basename)
	else
		GUICtrlSetData($combo__mask, $mask_list, $default_mask)
	endif

	$group_behaviour = GUICtrlCreateGroup($captions[2], $gap, $groups_top, $behaviour_width, $groups_height)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKSIZE)
	local $checkbox_recurse = CreateCheckbox($captions[3], 2 * $gap, $first_row, $caption_widths[3] + $checkbox_padding, $row_height)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKSIZE)
	if StringInStr($switches, "r") then GUICtrlSetState(-1, $ON)
	if not IsDir(GUICtrlRead($input_path)) then GUICtrlSetState(-1, $OFF)
	local $checkbox_sync = CreateCheckbox($captions[4], 3 * $gap + $caption_widths[3] + $checkbox_padding, $first_row, $caption_widths[4] + $checkbox_padding, $row_height)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKSIZE)
	if StringInStr($switches, "y") then GUICtrlSetState(-1, $ON)
	local $checkbox_individual = CreateCheckbox($captions[5], 2 * $gap, $first_row + 1 * $row_height, $caption_widths[5] + $checkbox_padding, $row_height)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKSIZE)
	if StringInStr($switches, "i") then GUICtrlSetState(-1, $ON)
	local $checkbox_root = CreateCheckbox($captions[6], 2 * $gap, $first_row + 2 * $row_height, $caption_widths[6] + $checkbox_padding, $row_height)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKSIZE)

	if StringInStr($switches, "1") then
		GUICtrlSetState(-1, $ON)
		GUICtrlSetState($checkbox_recurse, $ON)
	endif

	local $checkbox_abs_paths = CreateCheckbox($captions[7], 2 * $gap, $first_row + 3 * $row_height, $caption_widths[7] + $checkbox_padding, $row_height)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKSIZE)
	if StringInStr($switches, "k") then GUICtrlSetState(-1, $ON)
	$checkbox_progress_tip = CreateCheckbox($captions[8], 2 * $gap, $first_row + 4 * $row_height, $caption_widths[8] + $checkbox_padding, $row_height)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKSIZE)
	if StringInStr($switches, "t") then GUICtrlSetState(-1, $ON)
	local $checkbox_audio_alerts = CreateCheckbox($captions[9], 3 * $gap + $caption_widths[8] + $checkbox_padding, $first_row + 4 * $row_height, $caption_widths[9] + $checkbox_padding, $row_height)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKSIZE)
	if StringInStr($switches, "b") then GUICtrlSetState(-1, $ON)
	local $checkbox_quiet = CreateCheckbox($captions[10], 2 * $gap, $first_row + 5 * $row_height, $caption_widths[10] + $checkbox_padding, $row_height)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKSIZE)
	if StringInStr($switches, "q") then GUICtrlSetState(-1, $ON)
	local $checkbox_shutdown = CreateCheckbox($captions[11], 2 * $gap, $first_row + 6 * $row_height, $caption_widths[11] + $checkbox_padding, $row_height)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKSIZE)
	if StringInStr($switches, "z") then GUICtrlSetState(-1, $ON)

	global $g_id_grp_output = GUICtrlCreateGroup($captions[12], $output_left, $groups_top, $output_width, $groups_height)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKSIZE)
	local $checkbox_uppercase = CreateCheckbox($captions[13], $output_left + $gap, $first_row, $caption_widths[13] + $checkbox_padding, $row_height)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKSIZE)
	if StringInStr($switches, "u") then GUICtrlSetState(-1, $ON)
	local $checkbox_hide = CreateCheckbox($captions[14], $output_left + $gap, $first_row + 1 * $row_height, $caption_widths[14] + $checkbox_padding, $row_height)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKSIZE)
	if StringInStr($switches, "h") then GUICtrlSetState(-1, $ON)
	local $checkbox_add_ext = CreateCheckbox($captions[15], $output_left + $gap, $first_row + 2 * $row_height, $caption_widths[15] + $checkbox_padding, $row_height)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKSIZE)
	if StringInStr($switches, "e") then GUICtrlSetState(-1, $ON)
	local $checkbox_winamp = CreateCheckbox($captions[16], $output_left + $gap, $first_row + 3 * $row_height, $caption_widths[16] + $checkbox_padding, $row_height)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKSIZE)
	if StringInStr($switches, "3") or StringInStr($switches, "p") then GUICtrlSetState(-1, $ON)
	local $checkbox_shoutcast = CreateCheckbox($captions[17], $output_left + $gap, $first_row + 4 * $row_height, $caption_widths[17] + $checkbox_padding, $row_height)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKSIZE)
	if StringInStr($switches, "p") then GUICtrlSetState(-1, $ON)
	local $checkbox_out_dir = CreateCheckbox($captions[18], $output_left + $gap, $first_row + 5 * $row_height, $caption_widths[18] + $checkbox_padding, $row_height)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKSIZE)
	if $out_dir then GUICtrlSetState(-1, $ON)
	local $input_out_dir = GUICtrlCreateInput($out_dir, $output_left + $gap, $first_row + 6 * $row_height, $output_width - 2 * $gap, $row_height)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKSIZE)
	GUICtrlSetData(-1, $out_dir)
	if GUICtrlRead($checkbox_out_dir) = $OFF then GUICtrlSetState(-1, $GUI_HIDE)


	local $command_dock = $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKSIZE
	$group_algorithm = GUICtrlCreateGroup($captions[19], $commands_left, $groups_top, $commands_width, 2 * $row_height + $gap)
	GUICtrlSetResizing(-1, $command_dock)
	local $combo_algo = GUICtrlCreateCombo("", $commands_left + $gap, $first_row, $commands_width - 2 * $gap, default, $CBS_DROPDOWNLIST)
	GUICtrlSetResizing(-1, $command_dock)
	GUICtrlSetData(-1, AlgoComboList(), $algorithm_strings[AlgoIDFromSwitches()])

	local $switches_top = $groups_top + 4 * $row_height
	local $group_switches = GUICtrlCreateGroup($captions[20], $commands_left, $switches_top, $commands_width, 2 * $row_height + $gap)
	GUICtrlSetResizing(-1, $command_dock)
	local $input_switches = GUICtrlCreateInput($switches, $commands_left + $gap, $switches_top + $row_height, $commands_width - 2 * $gap, $row_height)
	GUICtrlSetResizing(-1, $command_dock)

	local $button_run = GUICtrlCreateButton("&" & $captions[21], $commands_left, $base_gui_height - $row_height - $gap, $commands_width, $row_height, $BS_DEFPUSHBUTTON, $reading_direction)
	GUICtrlSetResizing(-1, $command_dock)
	AutoItSetOption("GUICoordMode", $old_coord_mode)

	if $help_tips = $ON then

		$my_msg = _T("checksum will create hashes for all matched files in this path")
		SetPaddedTip($input_path,  _L($my_msg))
		$my_msg = _T("checksum will only create hashes for files matching this 'mask'. the default is *.*. Separate multiple file masks with commas, e.g.. *.avi,*.mpg,*.mp3. Alternatively, choose one of the predefined mask sets from the drop-down (you can add these yourself by editing checksum.ini)")
		SetPaddedTip($combo__mask,  _L($my_msg))
		$my_msg = _T("Dig into sub-directories, and their sub-directories, and theirs, and so on...")
		SetPaddedTip($checkbox_recurse,  _L($my_msg))
		$my_msg = _T("Rather than one hash file for a each folder (the most useful default), checksum can create individual hash files for each files it encounters.")
		SetPaddedTip($checkbox_individual,  _L($my_msg))
		$my_msg = _T("Rather than one hash file for a each folder (the default), checksum can create one single checksum file in the root folder.")
		SetPaddedTip($checkbox_root,  _L($my_msg))
		$my_msg = _T("Record the FULL, ABSOLUTE path of files inside the root hash file. This is useful for read-only disks that will ALWAYS be in the same location, e.g. D:\")
		SetPaddedTip($checkbox_abs_paths,  _L($my_msg))
		$my_msg = _T("Show the funky dynamic progress 'ToolTip' (you can click-and-drag that around)")
		SetPaddedTip($checkbox_progress_tip,  _L($my_msg))
		$my_msg = _T("do audio alerts - checksum will beep on errors and task completion")
		SetPaddedTip($checkbox_audio_alerts,  _L($my_msg))
		$my_msg = _T("In Quiet Mode, checksum posts no dialogs at all. Handy for scripting or periods of deep concentration.")
		SetPaddedTip($checkbox_quiet,  _L($my_msg))
		$my_msg = _T("checksum can shutdown your computer at the end of the job. You will have 60 seconds to abort this. This is especially useful for long jobs on systems that don't run 24/7.")
		SetPaddedTip($checkbox_shutdown,  _L($my_msg))
		$my_msg = _T("Create UPPERCASE hashes")
		SetPaddedTip($checkbox_uppercase,  _L($my_msg))
		$my_msg = _T("Hide the checksum files (basically, attrib +h)")
		SetPaddedTip($checkbox_hide,  _L($my_msg))
		$my_msg = _T("Create winamp format album playlists (.m3u files) for any music files found in each folder (only for folder hashes). note: you can still use the '*.*' file mask; non-music files won't go in the playlist.")
		SetPaddedTip($checkbox_winamp,  _L($my_msg))
		$my_msg = _T("Create shoutcast/icecast (.pls) playlist files for any music files found in each folder (only for folder hashes). note: you can still use the '*.*' file mask; non-music files won't go in the playlist.")
		SetPaddedTip($checkbox_shoutcast,  _L($my_msg))
		$my_msg = _T("You can have your .hash files output to a custom directory. Note: this isn't recommended, unless you have a good reason to do this, and even then, 'root' hashing is preferred.")
		SetPaddedTip($checkbox_out_dir,  _L($my_msg))
		$my_msg = _T("Paste/type the full path of your custom output directory. Leave blank to use the default (RECOMMENDED!)")
		SetPaddedTip($input_out_dir,  _L($my_msg))
		$my_msg = _T("Add file extensions to individual hashes (rather than 'file.md5', you get 'file.ext.md5')")
		SetPaddedTip($checkbox_add_ext,  _L($my_msg))
		$my_msg = _T("Rather than create a new checksum file, checksum can add any new files it finds to the the existing checksum file, a Good Idea; existing checksums will be untouched.")
		SetPaddedTip($checkbox_sync,  _L($my_msg))
		$my_msg = DoCreateAlgoTips(AlgoIDFromDisplay(GUICtrlRead($combo_algo)))
		SetPaddedTip($combo_algo,  _L($my_msg))
		$my_msg = _T("Your current switches. This input updates dynamically when you un/check things. You can also add and remove regular switches here - corresponding checkboxes will update the next time you 'do' something (e.g. click the 'switches' label or some other control)..")
		SetPaddedTip($input_switches,  _L($my_msg))
		SetPaddedTip($group_switches,  _L($my_msg))
		$my_msg = _T("Click here to run the current job.")
		SetPaddedTip($button_run,  _L($my_msg))
	endif

	debugGUICtrlBorders($GUI_Options)
	GUISetState()
	WinActivate($GUI_Options)
	WinSetOnTop($GUI_Options, "", 1)

	local $options_min_size = WinGetPos($GUI_Options)
	local $options_min_width = $standard_gui_width
	local $options_min_height = $base_gui_height
	local $options_frame_width = 0
	local $options_saved_width = $base_gui_width
	if IsArray($options_min_size) then
		$options_frame_width = $options_min_size[2] - $base_gui_width
		$options_min_width = $standard_gui_width + $options_frame_width
		$options_min_height = $options_min_size[3]
	endif

	local $gui_msg
	while not $user_quit

		$switches = StringReplace($switches, "-", "")
		$gui_msg = GUIGetMsg()

		switch $gui_msg

			case $GUI_EVENT_RESIZED
				EnforceOptionsMinSize($options_min_width, $options_min_height)
				MaybeSaveOptionsWidth("create_options_width", $options_min_width, $options_frame_width, $options_saved_width)

			case $GUI_EVENT_CLOSE
				AutoItSetOption("GUIOnEventMode", $old_gui_mode)
				GUISetState(@SW_HIDE, $GUI_Options)
				GUIDelete($GUI_Options)
				Sleep(25)
				CheckVersionAndExit(-9)

			case $GUI_EVENT_DROPPED
				if @GUI_DragId = -1 then
					if UBound($dropped_files) > 1 then
						local $drag_exts = ""
						GUICtrlSetData($input_path, GetLongParentDir($dropped_files[0]))
						for $file_idx = 0 to UBound($dropped_files) - 1
							local $file_ext = GetExtension($dropped_files[$file_idx])
							if $file_ext <> "" and not StringInStr($drag_exts, $file_ext) and not FindInStringArray($ignore_types, $file_ext) then
								$drag_exts &= "*." & $file_ext & ","
							endif
						next
						$drag_exts = StringTrimRight($drag_exts, 1)
						GUICtrlSetData($combo__mask, $drag_exts)
						local $combo_idx = ControlCommand($GUI_Options, "", $combo__mask, "FindString", $drag_exts)
						ControlCommand($GUI_Options, "", $combo__mask, "SetCurrentselection", $combo_idx)
					else
						if IsDir(@GUI_DragFile) then
							GUICtrlSetData($input_path, @GUI_DragFile)
							ControlCommand($GUI_Options, "", $combo__mask, "selectString", "*.*")
						else
							GUICtrlSetData($input_path, GetLongParentDir(@GUI_DragFile))
							local $drag_basename = BaseName(@GUI_DragFile)
							GUICtrlSetData($combo__mask, $drag_basename)
							ControlCommand($GUI_Options, "", $combo__mask, "selectString", $drag_basename)
						endif
					endif
				endif

			case $input_switches
				$switches = GUICtrlRead($input_switches)
				if not StringInStr($switches, "c") then $switches = "c" & $switches
				if StringInStr($switches, "r") then
					GUICtrlSetState($checkbox_recurse, $ON)
				else
					GUICtrlSetState($checkbox_recurse, $OFF)
				endif
				if StringInStr($switches, "y") then
					GUICtrlSetState($checkbox_sync, $ON)
					$switches = StringReplace($switches, "i", "")
					GUICtrlSetState($checkbox_individual, $OFF)
					$switches = StringReplace($switches, "e", "")
					GUICtrlSetState($checkbox_add_ext, $OFF)
				else
					GUICtrlSetState($checkbox_sync, $OFF)
				endif
				if StringInStr($switches, "i") then
					GUICtrlSetState($checkbox_individual, $ON)
					$switches = StringReplace($switches, "y", "")
					GUICtrlSetState($checkbox_sync, $OFF)
					$switches = StringReplace($switches, "1", "")
					GUICtrlSetState($checkbox_root, $OFF)
					$switches = StringReplace($switches, "k", "")
					GUICtrlSetState($checkbox_abs_paths, $OFF)
				else
					GUICtrlSetState($checkbox_individual, $OFF)
				endif
				if StringInStr($switches, "1") then
					GUICtrlSetState($checkbox_root, $ON)
					if not StringInStr($switches, "r") then $switches &= "r"
					GUICtrlSetState($checkbox_recurse, $ON)
				else
					GUICtrlSetState($checkbox_root, $OFF)
				endif
				if StringInStr($switches, "k") then
					GUICtrlSetState($checkbox_abs_paths, $ON)
					if not StringInStr($switches, "1") then $switches &= "1"
					GUICtrlSetState($checkbox_root, $ON)
					if not StringInStr($switches, "r") then $switches &= "r"
					GUICtrlSetState($checkbox_recurse, $ON)
					$switches = StringReplace($switches, "i", "")
					GUICtrlSetState($checkbox_individual, $OFF)
					$switches = StringReplace($switches, "e", "")
					GUICtrlSetState($checkbox_add_ext, $OFF)
				else
					GUICtrlSetState($checkbox_abs_paths, $OFF)
				endif
				if StringInStr($switches, "t") then
					GUICtrlSetState($checkbox_progress_tip, $ON)
				else
					GUICtrlSetState($checkbox_progress_tip, $OFF)
				endif
				if StringInStr($switches, "b") then
					GUICtrlSetState($checkbox_audio_alerts, $ON)
				else
					GUICtrlSetState($checkbox_audio_alerts, $OFF)
				endif
				if StringInStr($switches, "q") then
					GUICtrlSetState($checkbox_quiet, $ON)
				else
					GUICtrlSetState($checkbox_quiet, $OFF)
				endif
				if StringInStr($switches, "z") then
					GUICtrlSetState($checkbox_shutdown, $ON)
				else
					GUICtrlSetState($checkbox_shutdown, $OFF)
				endif
				if StringInStr($switches, "u") then
					GUICtrlSetState($checkbox_uppercase, $ON)
				else
					GUICtrlSetState($checkbox_uppercase, $OFF)
				endif
				if StringInStr($switches, "h") then
					GUICtrlSetState($checkbox_hide, $ON)
				else
					GUICtrlSetState($checkbox_hide, $OFF)
				endif
				if StringInStr($switches, "e") then
					GUICtrlSetState($checkbox_add_ext, $ON)
					GUICtrlSetState($checkbox_individual, $ON)
					$switches = StringReplace($switches, "y", "")
					GUICtrlSetState($checkbox_sync, $OFF)
					$switches = StringReplace($switches, "1", "")
					GUICtrlSetState($checkbox_root, $OFF)
					$switches = StringReplace($switches, "k", "")
					GUICtrlSetState($checkbox_abs_paths, $OFF)
				else
					GUICtrlSetState($checkbox_add_ext, $OFF)
				endif
				if StringInStr($switches, "3") then
					GUICtrlSetState($checkbox_winamp, $ON)
					$switches = StringReplace($switches, "p", "")
					GUICtrlSetState($checkbox_shoutcast, $OFF)
					$switches = StringReplace($switches, "i", "")
					GUICtrlSetState($checkbox_individual, $OFF)
					$switches = StringReplace($switches, "e", "")
					GUICtrlSetState($checkbox_add_ext, $OFF)
				else
					GUICtrlSetState($checkbox_winamp, $OFF)
				endif
				if StringInStr($switches, "p") then
					GUICtrlSetState($checkbox_shoutcast, $ON)
					$switches = StringReplace($switches, "3", "")
					GUICtrlSetState($checkbox_winamp, $OFF)
					$switches = StringReplace($switches, "i", "")
					GUICtrlSetState($checkbox_individual, $OFF)
					$switches = StringReplace($switches, "e", "")
					GUICtrlSetState($checkbox_add_ext, $OFF)
				else
					GUICtrlSetState($checkbox_shoutcast, $OFF)
				endif
				local $sync_algo_id = AlgoIDFromSwitches()
				if not HasAlgoSwitch() then $sync_algo_id = 1 ; legacy default: no letter means MD5
				ControlCommand($GUI_Options, "", $combo_algo, "SelectString", $algorithm_strings[$sync_algo_id])
				StripAlgoSwitches()
				$switches &= AlgoLetterForID($sync_algo_id)
				SetPaddedTip($combo_algo, _L(DoCreateAlgoTips($sync_algo_id)))
				GUICtrlSetData($input_switches, $switches)

			case $checkbox_out_dir
				if GUICtrlRead($checkbox_out_dir) = $OFF then
					GUICtrlSetState($input_out_dir, $GUI_HIDE)
				else
					GUICtrlSetState($input_out_dir, $GUI_SHOW)
				endif

			case $checkbox_recurse, $input_path
				if GUICtrlRead($input_path) <> "" and not IsDir(GUICtrlRead($input_path)) then
					GUICtrlSetState($checkbox_recurse, $OFF)
					$switches = StringReplace($switches, "r", "")
					ControlFocus($GUI_Options, "", $input_path)
					Send("{END}{SHIFTDOWN}{HOME}{SHIFTUP}")
					Sleep(100)
					Send("{END}")
					Sleep(100)
					Send("{SHIFTDOWN}{HOME}{SHIFTUP}")
				endif
				if GUICtrlRead($checkbox_recurse) = $ON then
					$switches &= "r"
				else
					$switches = StringReplace($switches, "r", "")
					GUICtrlSetState($checkbox_root, $OFF)
					$switches = StringReplace($switches, "1", "")
					GUICtrlSetState($checkbox_abs_paths, $OFF)
					$switches = StringReplace($switches, "k", "")
				endif
				GUICtrlSetData($input_switches, $switches)

			case $checkbox_sync
				if GUICtrlRead($checkbox_sync) = $ON then
					$switches &= "y"
					GUICtrlSetState($checkbox_individual, $OFF)
					$switches = StringReplace($switches, "i", "")
					GUICtrlSetState($checkbox_add_ext, $OFF)
					$switches = StringReplace($switches, "e", "")
				else
					$switches = StringReplace($switches, "y", "")
				endif
				GUICtrlSetData($input_switches, $switches)

			case $checkbox_individual
				if GUICtrlRead($checkbox_individual) = $ON then
					$switches &= "i"
					GUICtrlSetState($checkbox_sync, $OFF)
					$switches = StringReplace($switches, "y", "")
					GUICtrlSetState($checkbox_winamp, $OFF)
					$switches = StringReplace($switches, "3", "")
					GUICtrlSetState($checkbox_shoutcast, $OFF)
					$switches = StringReplace($switches, "p", "")
					GUICtrlSetState($checkbox_root, $OFF)
					$switches = StringReplace($switches, "1", "")
					GUICtrlSetState($checkbox_abs_paths, $OFF)
					$switches = StringReplace($switches, "k", "")
				else
					$switches = StringReplace($switches, "i", "")
					GUICtrlSetState($checkbox_add_ext, $OFF)
					$switches = StringReplace($switches, "e", "")
				endif
				GUICtrlSetData($input_switches, $switches)

			case $checkbox_root
				if GUICtrlRead($checkbox_root) = $ON then
					$switches &= "1"
					GUICtrlSetState($checkbox_recurse, $ON)
					if not StringInStr($switches, "r") then $switches &= "r"
					GUICtrlSetState($checkbox_individual, $OFF)
					$switches = StringReplace($switches, "i", "")
					GUICtrlSetState($checkbox_add_ext, $OFF)
					$switches = StringReplace($switches, "e", "")
				else
					$switches = StringReplace($switches, "1", "")
					GUICtrlSetState($checkbox_abs_paths, $OFF)
					$switches = StringReplace($switches, "k", "")
				endif
				GUICtrlSetData($input_switches, $switches)

			case $checkbox_abs_paths
				if GUICtrlRead($checkbox_abs_paths) = $ON then
					$switches &= "k"
					GUICtrlSetState($checkbox_recurse, $ON)
					if not StringInStr($switches, "r") then $switches &= "r"
					GUICtrlSetState($checkbox_individual, $OFF)
					$switches = StringReplace($switches, "i", "")
					GUICtrlSetState($checkbox_add_ext, $OFF)
					$switches = StringReplace($switches, "e", "")
					if GUICtrlRead($checkbox_root) = $OFF then
						GUICtrlSetState($checkbox_root, $ON)
						if not StringInStr($switches, "1") then $switches &= "1"
					endif
				else
					$switches = StringReplace($switches, "k", "")
				endif
				GUICtrlSetData($input_switches, $switches)

			case $checkbox_progress_tip
				if GUICtrlRead($checkbox_progress_tip) = $ON then
					$switches &= "t"
				else
					$switches = StringReplace($switches, "t", "")
				endif
				GUICtrlSetData($input_switches, $switches)

			case $checkbox_audio_alerts
				if GUICtrlRead($checkbox_audio_alerts) = $ON then
					$switches &= "b"
				else
					$switches = StringReplace($switches, "b", "")
				endif
				GUICtrlSetData($input_switches, $switches)

			case $checkbox_quiet
				if GUICtrlRead($checkbox_quiet) = $ON then
					$switches &= "q"
				else
					$switches = StringReplace($switches, "q", "")
				endif
				GUICtrlSetData($input_switches, $switches)

			case $checkbox_shutdown
				if GUICtrlRead($checkbox_shutdown) = $ON then
					$switches &= "z"
				else
					$switches = StringReplace($switches, "z", "")
				endif
				GUICtrlSetData($input_switches, $switches)

			case $checkbox_uppercase
				if GUICtrlRead($checkbox_uppercase) = $ON then
					$switches &= "u"
				else
					$switches = StringReplace($switches, "u", "")
				endif
				GUICtrlSetData($input_switches, $switches)

			case $checkbox_hide
				if GUICtrlRead($checkbox_hide) = $ON then
					$switches &= "h"
				else
					$switches = StringReplace($switches, "h", "")
				endif
				GUICtrlSetData($input_switches, $switches)

			case $checkbox_add_ext
				if GUICtrlRead($checkbox_add_ext) = $ON then
					$switches &= "e"
					if GUICtrlRead($checkbox_individual) = $OFF then ControlClick($GUI_Options, "", $checkbox_individual)
				else
					$switches = StringReplace($switches, "e", "")
				endif
				GUICtrlSetData($input_switches, $switches)

			case $checkbox_winamp
				if GUICtrlRead($checkbox_winamp) = $ON then
					$switches &= "3"
					GUICtrlSetState($checkbox_shoutcast, $OFF)
					if StringInStr($switches, "p") then $switches = StringReplace($switches, "p", "")
					GUICtrlSetState($checkbox_individual, $OFF)
					$switches = StringReplace($switches, "i", "")
					GUICtrlSetState($checkbox_add_ext, $OFF)
					$switches = StringReplace($switches, "e", "")
					if GUICtrlRead($combo__mask) = "*.*" then ControlCommand($GUI_Options, "", $combo__mask, "selectString", $gui_playlist_extensions)
				else
					$switches = StringReplace($switches, "3", "")
					if GUICtrlRead($combo__mask) = $gui_playlist_extensions then ControlCommand($GUI_Options, "", $combo__mask, "selectString", "*.*")
				endif
				GUICtrlSetData($input_switches, $switches)

			case $checkbox_shoutcast
				if GUICtrlRead($checkbox_shoutcast) = $ON then
					$switches &= "p"
					GUICtrlSetState($checkbox_winamp, $OFF)
					if StringInStr($switches, "3") then $switches = StringReplace($switches, "3", "")
					GUICtrlSetState($checkbox_individual, $OFF)
					$switches = StringReplace($switches, "i", "")
					GUICtrlSetState($checkbox_add_ext, $OFF)
					$switches = StringReplace($switches, "e", "")
					if GUICtrlRead($combo__mask) = "*.*" then ControlCommand($GUI_Options, "", $combo__mask, "selectString", $gui_playlist_extensions)
				else
					$switches = StringReplace($switches, "p", "")
					if GUICtrlRead($combo__mask) = $gui_playlist_extensions then ControlCommand($GUI_Options, "", $combo__mask, "selectString", "*.*")
				endif
				GUICtrlSetData($input_switches, $switches)


			case $combo_algo
				local $combo_algo_id = AlgoIDFromDisplay(GUICtrlRead($combo_algo))
				StripAlgoSwitches()
				$switches &= AlgoLetterForID($combo_algo_id)
				SetPaddedTip($combo_algo, _L(DoCreateAlgoTips($combo_algo_id)))
				GUICtrlSetData($input_switches, $switches)

			case $button_run
				StripAlgoSwitches()
				$switches &= AlgoLetterForID(AlgoIDFromDisplay(GUICtrlRead($combo_algo)))
				GUICtrlSetData($input_switches, $switches)
				if GUICtrlRead($checkbox_out_dir) = $ON then
					local $resolved_out_dir = ConvertToLongPathFormat(GUICtrlRead($input_out_dir))
					if StringRight($resolved_out_dir, 1) = "\" then StringTrimRight($resolved_out_dir, 1)
					if not _LFN_FileExists($resolved_out_dir) then
						$my_msg = _T("Output Directory does Not Exist!")
						$full_text = _T("Does Not Exist!") & @LF & @LF & _T("Should checksum create the Output Directory?")
						if MsgBox($MB_YESNO + $MB_ICONWARNING + $MB_TOPMOST, $my_msg, _
							FormatPathForDisplay($out_dir) & @LF & @LF & _L($full_text)) = $IDYES then _LFN_DirCreate($out_dir)
					endif
					if _LFN_FileExists($resolved_out_dir) and IsDir($resolved_out_dir) then
						$out_dir = $resolved_out_dir
					endif
				endif

				$path = ConvertToLongPathFormat(GUICtrlRead($input_path))
				if not _LFN_FileExists($path) or not IsDir($path) then
					$my_msg = _T("Please input a valid folder path here!")
					if GUICtrlRead($input_path) = "" or GUICtrlRead($input_path) = $my_msg then
						GUICtrlSetData($input_path, $my_msg)
						ControlFocus($GUI_Options, "", $input_path)
						Send("{SHIFTDOWN}{HOME}{SHIFTUP}")
					else
					$my_msg = _T("The specified folder does not exist!")
						MsgBox($MB_ICONQUESTION + $MB_TOPMOST, _T("Error!"), $my_msg, $dialog_timeout)
						ControlFocus($GUI_Options, "", $input_path)
						Send("{SHIFTDOWN}{HOME}{SHIFTUP}")
					endif
					continueloop
				endif

				if GUICtrlRead($combo__mask) <> "" then $file_mask = GUICtrlRead($combo__mask)
				if _LFN_FileExists($path & "\" & $file_mask) and not StringInStr($file_mask, "*") then
					$path = $path & "\" & $file_mask
					$switches = StringReplace($switches, "r", "")
				endif

				if not StringInStr($switches, "c") then $switches &= "c"
				if FileExists($queue_file) and $apply_options_to_queue = $ON then
					local $queue_section = IniReadSection($queue_file, "queue")
					if IsArray($queue_section) then
						for $queue_idx = 1 to $queue_section[0][0]
							local $queue_item = $queue_section[$queue_idx][1]
							local $quote_pos = StringInStr($queue_item, '"')
							$queue_item = $switches & ' "' & StringTrimLeft($queue_item, $quote_pos)
							IniWrite($queue_file, "queue", $queue_section[$queue_idx][0], $queue_item)
						next
					endif
				endif

				SaveWinPosition()
				AutoItSetOption("GUIOnEventMode", $old_gui_mode)
				GUIDelete($GUI_Options)
				return 1

		endswitch
	wend

	AutoItSetOption("GUIOnEventMode", $old_gui_mode)
	GUIDelete($GUI_Options)

endfunc



;
; DoVerifyOptions()													cro b:\						vro B:\Test

; The main Verify Options dialog.
;
func DoVerifyOptions()

	debug($LF, @ScriptLineNumber, 7)
	$switches = StringReplace($switches, "o", "")
	debug("DoVerifyOptions() ---> $initial switches =>" & $switches & "<=", @ScriptLineNumber, 7)

	local $old_gui_mode = AutoItSetOption("GUIOnEventMode", 0)
	local $old_coord_mode = AutoItSetOption("GUICoordMode", 1)
	local $text_scale = ChecksumDialogTextScale()
	local $opt_width = Int(GetINIArrayValue($ini_array, "verify_options_width", 0))
	if $opt_width < 355 or $opt_width > @DesktopWidth then $opt_width = 0

	$GUI_Options = GUICreate($app_name & " " & _T("one-shot verify options") & "..", 375, 180, _
		$opt_x, $opt_y, BitOr($WS_MINIMIZEBOX, $WS_CAPTION, $WS_POPUP, $WS_SYSMENU, $WS_SIZEBOX), $WS_EX_ACCEPTFILES)
	GUISetFont(9 * $text_scale, default, default, "Segoe UI", $GUI_Options)

	local $captions = [_T("path") & ":", _T("logging") & "..", _T("log failures"), _T("log everything"), _T("append logs"), _
		_T("goto log folder"), _T("log to a file in") & "..", _T("behaviour") & "..", _T("recurse"), _T("audio alerts"), _
		_T("progress tip"), _T("delete missing hashes"), _T("update changed hashes"), _T("email on hash fail"), _T("shutdown when done"), _
		_T("algorithm") & "..", _T("all algorithms"), _T("search + verify"), _T("do it now!")]
	local $measure = GUICtrlCreateLabel("", 0, 0, 1, 1)
	local $line_height = FitLabelHeight($measure, "Ag", 100)
	local $gap = Ceiling($line_height / 2)
	local $row_height = $line_height + Ceiling($gap / 3)
	local $toggle_padding = $line_height + $gap
	local $caption_widths[UBound($captions)]
	for $i = 0 to UBound($captions) - 1
		$caption_widths[$i] = FitLabelWidth($measure, $captions[$i], @DesktopWidth)
	next

	local $logging_width = $caption_widths[1]
	for $i = 2 to 6
		$logging_width = _Max($logging_width, $caption_widths[$i] + $toggle_padding)
	next
	$logging_width += 2 * $gap
	local $behaviour_width = $caption_widths[7]
	for $i = 8 to 14
		$behaviour_width = _Max($behaviour_width, $caption_widths[$i] + $toggle_padding)
	next
	$behaviour_width += 2 * $gap
	local $algorithm_width = $caption_widths[16] + $toggle_padding
	for $i = 1 to $algorithm_strings[0]
		$algorithm_width = _Max($algorithm_width, FitLabelWidth($measure, $algorithm_strings[$i], @DesktopWidth, $toggle_padding))
	next
	local $commands_width = _Max(_Max($caption_widths[15], $algorithm_width), _Max($caption_widths[17] + $toggle_padding, $caption_widths[18])) + 2 * $gap
	GUICtrlDelete($measure)

	local $field_left = $caption_widths[0] + 2 * $gap
	local $groups_top = $row_height + 3 * $gap
	local $first_row = $groups_top + $row_height
	local $groups_height = 8 * $row_height + $gap
	local $standard_gui_width = _Max($field_left + 12 * $line_height, $logging_width + $behaviour_width + $commands_width + 4 * $gap)
	local $base_gui_width = _Max($standard_gui_width, $opt_width)
	local $base_gui_height = $groups_top + $groups_height + $gap
	local $behaviour_left = $logging_width + 2 * $gap
	local $commands_left = $base_gui_width - $commands_width - $gap
	local $left_dock = $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKSIZE
	local $right_dock = $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKSIZE
	local $outer = WinGetPos($GUI_Options)
	local $client = WinGetClientSize($GUI_Options)
	local $frame_width = $outer[2] - $client[0], $frame_height = $outer[3] - $client[1]
	WinMove($GUI_Options, "", _Max(0, _Min($outer[0], @DesktopWidth - $base_gui_width - $frame_width)), _
		_Max(0, _Min($outer[1], @DesktopHeight - $base_gui_height - $frame_height)), $base_gui_width + $frame_width, $base_gui_height + $frame_height)
	GUISetIcon($exe_path, 0, $GUI_Options)

	InitPaddedTips()

	local $label_path = GUICtrlCreateLabel($captions[0], $gap, $gap, $field_left - $gap, $row_height)
	GUICtrlSetResizing(-1, $left_dock)
	local $input_path = GUICtrlCreateInput(FormatPathForDisplay($path), $field_left, $gap, $base_gui_width - $field_left - $gap, $row_height)
	GUICtrlSetState(-1, $GUI_DROPACCEPTED)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKHEIGHT)

	GUICtrlCreateGroup($captions[7], $behaviour_left, $groups_top, $behaviour_width, $groups_height, BitOr($WS_GROUP, $BS_GROUPBOX))
	GUICtrlSetResizing(-1, $left_dock)
	local $checkbox_recurse = CreateCheckbox($captions[8], $behaviour_left + $gap, $first_row, $caption_widths[8] + $toggle_padding, $row_height)
	GUICtrlSetResizing(-1, $left_dock)
	if StringInStr($switches, "r") then GUICtrlSetState(-1, $ON)
	if not IsDir(GUICtrlRead($input_path)) then GUICtrlSetState(-1, $OFF)
	local $checkbox_audio_alerts = CreateCheckbox($captions[9], $behaviour_left + $gap, $first_row + 1 * $row_height, $caption_widths[9] + $toggle_padding, $row_height)
	GUICtrlSetResizing(-1, $left_dock)
	if StringInStr($switches, "b") then GUICtrlSetState(-1, $ON)
	GUICtrlSetState(-1, $beep_alerts)
	$checkbox_progress_tip = CreateCheckbox($captions[10], $behaviour_left + $gap, $first_row + 2 * $row_height, $caption_widths[10] + $toggle_padding, $row_height)
	GUICtrlSetResizing(-1, $left_dock)
	if StringInStr($switches, "t") then GUICtrlSetState(-1, $ON)
	local $checkbox_delete_missing = CreateCheckbox($captions[11], $behaviour_left + $gap, $first_row + 3 * $row_height, $caption_widths[11] + $toggle_padding, $row_height)
	GUICtrlSetResizing(-1, $left_dock)
	if StringInStr($switches, "x") then GUICtrlSetState(-1, $ON)
	local $checkbox_update_changed = CreateCheckbox($captions[12], $behaviour_left + $gap, $first_row + 4 * $row_height, $caption_widths[12] + $toggle_padding, $row_height)
	GUICtrlSetResizing(-1, $left_dock)
	if StringInStr($switches, "w") then GUICtrlSetState(-1, $ON)

	local $checkbox_email_fail = CreateCheckbox($captions[13], $behaviour_left + $gap, $first_row + 5 * $row_height, $caption_widths[13] + $toggle_padding, $row_height)
	GUICtrlSetResizing(-1, $left_dock)
	if StringInStr($switches, "e") then GUICtrlSetState(-1, $ON)

	local $checkbox_shutdown = CreateCheckbox($captions[14], $behaviour_left + $gap, $first_row + 6 * $row_height, $caption_widths[14] + $toggle_padding, $row_height)
	GUICtrlSetResizing(-1, $left_dock)
	if StringInStr($switches, "z") then GUICtrlSetState(-1, $ON)

	GUICtrlCreateGroup($captions[15], $commands_left, $groups_top, $commands_width, 2 * $row_height + $gap, BitOr($WS_GROUP, $BS_GROUPBOX))
	GUICtrlSetResizing(-1, $right_dock)
	local $combo_alg_filter = GUICtrlCreateCombo("", $commands_left + $gap, $first_row, $commands_width - 2 * $gap, default, $CBS_DROPDOWNLIST)
	GUICtrlSetResizing(-1, $right_dock)
	local $verify_default = $captions[16]
	for $i = 1 to $algo_switch_letters[0]
		if StringInStr($switches, "a" & $algo_switch_letters[$i]) then $verify_default = $algorithm_strings[$i]
	next
	GUICtrlSetData(-1, $captions[16] & "|" & AlgoComboList(), $verify_default)

	GUICtrlCreateGroup($captions[1], $gap, $groups_top, $logging_width, $groups_height)
	GUICtrlSetResizing(-1, $left_dock)
	local $radio_log_failures = CreateRadioButton($captions[2], 2 * $gap, $first_row, $caption_widths[2] + $toggle_padding, $row_height)
	GUICtrlSetResizing(-1, $left_dock)
	GUICtrlSetState(-1, $ON)
	local $radio_log_everything = CreateRadioButton($captions[3], 2 * $gap, $first_row + $row_height, $caption_widths[3] + $toggle_padding, $row_height)
	GUICtrlSetResizing(-1, $left_dock)

	if StringInStr($switches, "l") then
		GUICtrlSetState(-1, $ON)
		GUICtrlSetState($radio_log_failures, $OFF)
		$log_to_file = $ON
		if not StringInStr($switches, "l") then $switches &= "l"
		if not StringInStr($switches, "f") then $switches &= "f"
	endif

	local $checkbox_append_logs = CreateCheckbox($captions[4], 2 * $gap, $first_row + 2 * $row_height, $caption_widths[4] + $toggle_padding, $row_height)
	GUICtrlSetResizing(-1, $left_dock)
	GUICtrlSetState(-1, $append_logs)
	local $checkbox_open_log_folder = CreateCheckbox($captions[5], 2 * $gap, $first_row + 3 * $row_height, $caption_widths[5] + $toggle_padding, $row_height)
	GUICtrlSetResizing(-1, $left_dock)
	if StringInStr($switches, "g") then GUICtrlSetState(-1, $ON)
	local $checkbox_log_to_file = CreateCheckbox($captions[6], 2 * $gap, $first_row + 4 * $row_height, $caption_widths[6] + $toggle_padding, $row_height)
	GUICtrlSetResizing(-1, $left_dock)
	if StringInStr($switches, "f") then GUICtrlSetState(-1, $ON)
	local $log_field_width = $logging_width - 2 * $gap
	local $input_log_folder = GUICtrlCreateInput($log_folder, 2 * $gap, $first_row + 6 * $row_height, $log_field_width, $row_height)
	GUICtrlSetResizing(-1, $left_dock)
	GUICtrlSetData(-1, $log_folder)
	if GUICtrlRead($checkbox_log_to_file) = $OFF then GUICtrlSetState(-1, $GUI_HIDE)

	local $search_top = $groups_top + 4 * $row_height
	GUICtrlCreateGroup("", $commands_left, $search_top, $commands_width, $row_height + 2 * $gap)
	GUICtrlSetResizing(-1, $right_dock)
	local $checkbox_search_verify = CreateCheckbox($captions[17], $commands_left + $gap, $search_top + $gap, $caption_widths[17] + $toggle_padding, $row_height)
	GUICtrlSetResizing(-1, $right_dock)
	if StringInStr($switches, "i") then GUICtrlSetState(-1, $ON)

	local $button_run = GUICtrlCreateButton("&" & $captions[18], $commands_left, $base_gui_height - $row_height - $gap, $commands_width, $row_height, $BS_DEFPUSHBUTTON, $reading_direction)
	GUICtrlSetResizing(-1, $right_dock)
	AutoItSetOption("GUICoordMode", $old_coord_mode)

	if $help_tips = $ON then

		$my_msg = _T("Hover over the path input box for more details.")
		SetPaddedTip($label_path,  _L($my_msg))
		$my_msg = _T("checksum will verify all the checksum files it encounters along this path")
		SetPaddedTip($input_path,  _L($my_msg))
		$my_msg = _T("The default is to record only failures.")
		SetPaddedTip($radio_log_failures,  _L($my_msg))
		$my_msg = _T("Record all failures and successes.")
		SetPaddedTip($radio_log_everything,  _L($my_msg))
		$my_msg = _T("The default is to append new logs to old logs. With dynamic @tokens, this creates many possibilities. But you can also disable this and create a brand new log for every verification job, if required.")
		SetPaddedTip($checkbox_append_logs,  _L($my_msg))
		$my_msg = _T("If a log is created, open that folder on your desktop. Note: if the folder is already opened, nothing happens.")
		SetPaddedTip($checkbox_open_log_folder,  _L($my_msg))
		$my_msg = _T("Log the results to a file (choose the logging folder below). Note: if there are errors, you always get the option to log to a file.")
		SetPaddedTip($checkbox_log_to_file,  _L($my_msg))
		$my_msg = _T("The name of the folder to log to. if you leave this blank, the log will be saved in the top folder checked. If that folder is not accessible for some reason, the log will be saved to your desktop.")
		SetPaddedTip($input_log_folder,  _L($my_msg))
		$my_msg = _T("Dig into sub-directories, and their sub-directories, and theirs, and so on...")
		SetPaddedTip($checkbox_recurse,  _L($my_msg))
		$my_msg = _T("do audio alerts - checksum will beep on any failures, and on completion.")
		SetPaddedTip($checkbox_audio_alerts,  _L($my_msg))
		$my_msg = _T("Show the funky dynamic progress 'toolTip' (you can click-and-drag that around).")
		SetPaddedTip($checkbox_progress_tip,  _L($my_msg))
		$my_msg = _T("checksum will delete hashes for MISSING files, rather than report them. Note: a backup is made to your system temp directory, named '{{checksum-deleted-backup.hash}}'.")
		SetPaddedTip($checkbox_delete_missing,  _L($my_msg))
		$my_msg = _T("checksum can update (aka. refresh) hashes and timestamps for CHANGED files. Note: ensure you are certain that the files have been changed mindfully before enabling this! Your log can help!")
		SetPaddedTip($checkbox_update_changed,  _L($my_msg))
		$my_msg = _T("checksum can shutdown your computer at the end of the job. You will have 60 seconds to abort this. This is especially useful for long jobs on systems that don't run 24/7.")
		SetPaddedTip($checkbox_shutdown,  _L($my_msg))
		$my_msg = _T("checksum can email you about hash errors. Note: enabling this also enables 'quiet' mode (no dialogs). ALSO Note: You can get to your mail prefs from the System Tray Menu.")
		SetPaddedTip($checkbox_email_fail,  _L($my_msg))
		local $verify_tip_idx = 0
		if GUICtrlRead($combo_alg_filter) <> _T("all algorithms") then $verify_tip_idx = AlgoIDFromDisplay(GUICtrlRead($combo_alg_filter))
		$my_msg = DoVerifyAlgoTips($verify_tip_idx)
		SetPaddedTip($combo_alg_filter,  _L($my_msg))
		$my_msg = _T("Run a search + verify operation for a single file. (checksum will scan all possible hash files for a matching hash and verify ONLY that file's hash)")
		SetPaddedTip($checkbox_search_verify,  _L($my_msg))
		$my_msg = _T("Verify Now!")
		SetPaddedTip($button_run,  _L($my_msg))
	endif

	debugGUICtrlBorders($GUI_Options)
	GUISetState()
	WinActivate($GUI_Options)
	WinSetOnTop($GUI_Options, "", 1)

	local $options_min_size = WinGetPos($GUI_Options)
	local $options_min_width = $standard_gui_width
	local $options_min_height = $base_gui_height
	local $options_frame_width = 0
	local $options_saved_width = $base_gui_width
	if IsArray($options_min_size) then
		$options_frame_width = $options_min_size[2] - $base_gui_width
		$options_min_width = $standard_gui_width + $options_frame_width
		$options_min_height = $options_min_size[3]
	endif

	local $gui_msg, $last_hover_ctrl
	while not $user_quit

		if ControlCommand($GUI_Options, "checksum", $input_log_folder, "IsVisible") then
			local $cursor_info = GUIGetCursorInfo($GUI_Options)
			if $last_hover_ctrl <> $cursor_info[4] then
				if IsArray($cursor_info) and $cursor_info[4] = $input_log_folder then
					ControlMove($GUI_Options, "checksum", $input_log_folder, default, default, $logging_width + $behaviour_width - $gap)
					GUICtrlSetState($checkbox_shutdown, $GUI_HIDE)
				else
					ControlMove($GUI_Options, "checksum", $input_log_folder, default, default, $log_field_width)
					GUICtrlSetState($checkbox_shutdown, $GUI_SHOW)
				endif
			endif
			$last_hover_ctrl = $cursor_info[4]
		endif

		$gui_msg = GUIGetMsg()
		switch $gui_msg

			case $GUI_EVENT_RESIZED
				EnforceOptionsMinSize($options_min_width, $options_min_height)
				MaybeSaveOptionsWidth("verify_options_width", $options_min_width, $options_frame_width, $options_saved_width)

			case $GUI_EVENT_CLOSE
				AutoItSetOption("GUIOnEventMode", $old_gui_mode)
				GUISetState(@SW_HIDE, $GUI_Options)
				GUIDelete($GUI_Options)
				Sleep(25)
				CheckVersionAndExit(-9)

			case $GUI_EVENT_DROPPED
				if @GUI_DragId = -1 then
					GUICtrlSetData($input_path, @GUI_DragFile)
				endif

			case $checkbox_recurse, $input_path
				if GUICtrlRead($checkbox_recurse) = $ON then
					if not IsDir(GUICtrlRead($input_path)) then
						GUICtrlSetState($checkbox_recurse, $OFF)
						ControlFocus($GUI_Options, "", $input_path)
						Send("{SHIFTDOWN}{HOME}{SHIFTUP}")
					endif
				endif

			case $radio_log_everything
				if GUICtrlRead($radio_log_everything) = $OFF then
					GUICtrlSetState($checkbox_log_to_file, $OFF)
					GUICtrlSetState($input_log_folder, $GUI_HIDE)
					continuecase
				else
					GUICtrlSetState($checkbox_log_to_file, $ON)
					GUICtrlSetState($input_log_folder, $GUI_SHOW)
					continuecase
				endif

			case $checkbox_append_logs

			case $checkbox_open_log_folder

			case $checkbox_log_to_file
				if GUICtrlRead($checkbox_log_to_file) = $OFF then
					GUICtrlSetState($input_log_folder, $GUI_HIDE)
				else
					GUICtrlSetState($input_log_folder, $GUI_SHOW)
				endif

			case $checkbox_audio_alerts

			case $checkbox_progress_tip

			case $combo_alg_filter
				local $combo_tip_idx = 0
				if GUICtrlRead($combo_alg_filter) <> _T("all algorithms") then $combo_tip_idx = AlgoIDFromDisplay(GUICtrlRead($combo_alg_filter))
				SetPaddedTip($combo_alg_filter, _L(DoVerifyAlgoTips($combo_tip_idx)))

			case $button_run
				$path = ConvertToLongPathFormat(GUICtrlRead($input_path))

				if not _LFN_FileExists($path) then
					$my_msg = _T("Please input a valid path here!")
					if GUICtrlRead($input_path) = "" or GUICtrlRead($input_path) = $my_msg then
						GUICtrlSetData($input_path, $my_msg)
						ControlFocus($GUI_Options, "", $input_path)
						Send("{SHIFTDOWN}{HOME}{SHIFTUP}")
					else
						MsgBox($MB_ICONQUESTION + $MB_TOPMOST, _T("Error!"), _T("The specified path does not exist!"), $dialog_timeout)
						ControlFocus($GUI_Options, "", $input_path)
						Send("{SHIFTDOWN}{HOME}{SHIFTUP}")
					endif
					continueloop
				endif

				DetermineRecurseFromPath($path)
				local $switch_chars = StringSplit("rbitxwzgflas254m", "")	; TODO check we have all applicable new switches here
				for $switch_idx = 1 to $switch_chars[0]
					$switches = StringReplace($switches, $switch_chars[$switch_idx], "")
				next

				if GUICtrlRead($checkbox_recurse) = $ON and $do_recurse then $switches &= "r"
				if GUICtrlRead($checkbox_audio_alerts) = $ON then $switches &= "b"
				if GUICtrlRead($checkbox_progress_tip) = $ON then $switches &= "t"
				if GUICtrlRead($checkbox_delete_missing) = $ON then $switches &= "x"
				if GUICtrlRead($checkbox_update_changed) = $ON then $switches &= "w"
				if GUICtrlRead($checkbox_shutdown) = $ON then $switches &= "z"

				if GUICtrlRead($checkbox_email_fail) = $ON then
					$switches &= "e"
					if not StringInStr($switches, "q") then $switches &= "q"
				endif

				if GUICtrlRead($checkbox_open_log_folder) = $ON then $switches &= "g"
				$append_logs = $OFF
				if GUICtrlRead($checkbox_append_logs) = $ON then $append_logs = $ON

				if GUICtrlRead($radio_log_everything) = $ON then
					$switches &= "lf"
				else
					if GUICtrlRead($checkbox_log_to_file) = $ON then $switches &= "f"
				endif
				$log_folder = GUICtrlRead($input_log_folder)

				local $verify_algo_idx = 0
				if GUICtrlRead($combo_alg_filter) <> _T("all algorithms") then $verify_algo_idx = AlgoIDFromDisplay(GUICtrlRead($combo_alg_filter))
				if $verify_algo_idx > 0 then $switches &= "a" & AlgoLetterForID($verify_algo_idx)

				debug("hash_ext =>" & $hashfile_extension & "<=", @ScriptLineNumber, 7)
				debug("GetExtension($path) =>" & GetExtension($path) & "<=", @ScriptLineNumber, 7)

				if GUICtrlRead($checkbox_search_verify) = $ON and not $do_recurse and "." & GetExtension($path) <> $hashfile_extension then $switches &= "i"
				if not StringInStr($switches, "v") then $switches &= "v"
				SaveWinPosition()

				AutoItSetOption("GUIOnEventMode", $old_gui_mode)
				GUIDelete($GUI_Options)
				return 1

		endswitch

	wend

	AutoItSetOption("GUIOnEventMode", $old_gui_mode)
	GUIDelete($GUI_Options)

endfunc

;						cro b:\

; Snaps an options dialog back to its creation size if the user resizes it too small.
; Minima come from a WinGetPos() snapshot taken just after GUISetState(), never hardcoded.
func EnforceOptionsMinSize($min_width, $min_height)
	local $win_pos = WinGetPos($GUI_Options)
	if not IsArray($win_pos) then return
	local $new_width = $win_pos[2]
	local $new_height = $win_pos[3]
	if $new_width < $min_width then $new_width = $min_width
	if $new_height < $min_height then $new_height = $min_height
	if $new_width <> $win_pos[2] or $new_height <> $win_pos[3] then WinMove($GUI_Options, "", default, default, $new_width, $new_height)
endfunc


; If the user increases the options dialog size larger than the standard size, 
; the value is saved to the ini. On resizing to <= standard, the value is wiped.
; This is a client width (what GUICreate expects); the live measurement is outer 
; width, hence the frame offset measured at creation time.
func MaybeSaveOptionsWidth($width_key, $min_outer_width, $frame_width, byref $last_saved_width)
	local $win_pos = WinGetPos($GUI_Options)
	if not IsArray($win_pos) then return
	local $standard_client_width = $min_outer_width - $frame_width
	if $win_pos[2] <= $min_outer_width then
		if $last_saved_width <> $standard_client_width then
			$last_saved_width = $standard_client_width
			IniWrite($ini_path, $app_name, $width_key, "")
		endif
		return
	endif
	local $client_width = $win_pos[2] - $frame_width
	if $client_width > @DesktopWidth then $client_width = Int(@DesktopWidth)
	if $client_width = $last_saved_width then return
	$last_saved_width = $client_width
	IniWrite($ini_path, $app_name, $width_key, $client_width)
endfunc


; Simple wrapper for our GUI checkboxes, saves on repeating GUICtrlSetResizing() commands
func CreateCheckbox($text, $left, $top, $width=-1, $height=-1)
    local $control_id = GUICtrlCreateCheckbox($text, $left, $top, $width, $height, default, $reading_direction)
    if not $control_id then return 0
    ; Locks width while allowing x/y to move proportionally with window resize
    GUICtrlSetResizing($control_id, $GUI_DOCKWIDTH)
    return $control_id
endfunc

; Wrapper for creating radio buttons. Not used much now.
func CreateRadioButton($text, $left, $top, $width=-1, $height=-1, $anchor_right=false)
    local $control_id = GUICtrlCreateRadio($text, $left, $top, $width, $height, default, $reading_direction)
    if not $control_id then return 0
	local $my_flags = $GUI_DOCKWIDTH
	if $anchor_right then $my_flags = $GUI_DOCKWIDTH+$GUI_DOCKRIGHT
    GUICtrlSetResizing($control_id, $my_flags)
    return $control_id
endfunc


; Returns the create-mode algorithm ID matching $switches (default SHA2).
func AlgoIDFromSwitches()
	for $i = 1 to $algo_switch_letters[0]
		if StringInStr($switches, $algo_switch_letters[$i]) then return $i
	next
	return DefaultAlgoID()
endfunc

; Returns the create-mode switch letter for an algorithm ID (default SHA2).
func AlgoLetterForID($algo_id)
	if $algo_id >= 1 and $algo_id <= $algo_switch_letters[0] then return $algo_switch_letters[$algo_id]
	return $algo_switch_letters[DefaultAlgoID()]
endfunc

; Removes all algorithm switch letters from $switches.
func StripAlgoSwitches()
	for $i = 1 to $algo_switch_letters[0]
		$switches = StringReplace($switches, $algo_switch_letters[$i], "")
	next
endfunc

; Pipe-delimited $algorithm_strings list for dropdowns (future algorithms appear automatically).
func AlgoComboList()
	local $list = ""
	for $i = 1 to $algorithm_strings[0]
		$list &= $algorithm_strings[$i] & "|"
	next
	return StringTrimRight($list, 1)
endfunc

; Maps a dropdown display string back to its algorithm ID (default SHA2).
func AlgoIDFromDisplay($display)
	local $id = _ArraySearch($algorithm_strings, $display, 1)
	if $id > 0 then return $id
	return DefaultAlgoID()
endfunc

; Per-algorithm create-dialog tooltip text (existing strings).
func DoCreateAlgoTips($algo_id)
	switch $algo_id
		case 1
			return _T("MD5 was once the gold standard verification algorithm, now it's slow and insecure.")
		case 2
			return _T("At the expense of a little speed, the SHA1 algorithm provides better security.")
		case 4
			return _T("CRC32 is old-school and very fast, but offers no security - fine for quick checks.")
		case else
			return _T("With hardware-enhanced hashing speed, the SHA2 algorithm provides the ultimate in speed and security.")
	endswitch
endfunc

; Per-algorithm verify-dialog tooltip text, 0 = all algorithms (existing strings).
func DoVerifyAlgoTips($verify_idx)
	switch $verify_idx
		case 1
			return _T("Verify only MD5 hashes inside *.hash files (when unified hash extension is enabled) as well as all *.md5 files in the path, ignoring *.sha1 and *.sha2 files.")
		case 2
			return _T("Verify only SHA1 hashes inside *.hash files (when unified hash extension is enabled) as well as all *.sha1 files in the path, ignoring *.md5 and *.sha2 files.")
		case 3
			return _T("Verify only SHA2 hashes inside *.hash files (when unified hash extension is enabled) as well as all *.sha2 files in the path, ignoring *.md5 and *.sha1 files.")
		case 4
			return _T("Verify only CRC32 hashes inside *.hash files (when unified hash extension is enabled) as well as all *.crc files in the path, ignoring *.md5, *.sha1 and *.sha2 files.")
		case else
			return _T("The default is to verify all algorithms inside *.hash files (regardless of unified_extension setting) as well as ALL *.crc, *.md5 and *.sha1 and *.sha2 files encountered in the (folder) path. In other words, verify everything.")
	endswitch
endfunc

; The preferred algorithm ID (SHA2). Single home for the default policy;
; function defaults and the shared global must stay literal, see below.
func DefaultAlgoID()
	return 3
endfunc

; True if $switches already carries any create-mode algorithm letter.
func HasAlgoSwitch()
	for $i = 1 to $algo_switch_letters[0]
		if StringInStr($switches, $algo_switch_letters[$i]) then return true
	next
	return false
endfunc

; Returns the verify-filter algorithm ID from an "a?" switch (0 = all algorithms).
; A bare "a" with no known letter keeps the legacy SHA2 default.
func AlgoIDFromVerifySwitch()
	for $i = 1 to $algo_switch_letters[0]
		if StringInStr($switches, "a" & $algo_switch_letters[$i]) then return $i
	next
	if StringInStr($switches, "a") then return DefaultAlgoID()
	return 0
endfunc

; Upgrade policy: MD5, SHA1 and CRC32 hashes are upgraded (to SHA256).
func IsUpgradeableAlgoID($algo_id)
	return $algo_id = 1 or $algo_id = 2 or $algo_id = 4
endfunc

; Hex digest length for an algorithm ID (default algorithm on bad ID).
func AlgoHexLen($algo_id)
	if $algo_id >= 1 and $algo_id <= $algo_hex_lens[0] then return $algo_hex_lens[$algo_id]
	return $algo_hex_lens[DefaultAlgoID()]
endfunc










func ______________________PROGRESS_AND_TIP()
endfunc


;
; checksumProgress()

; checksum's *main* GUI, a simple strip of a windoid.
;
; Updates the status tooltip with info about current operation.
;
; TODO: progress percentage (color?) and time (est? elapsed?).
; TODO: put stetch in context menu.
;
func checksumProgress()

	global $tooltip_label_width = 66
	global $tooltip_label_height = $tip_font_size * 1.8
	global $GUI_ToolTip = GUICreate($app_name, $tooltip_label_width, $tooltip_label_height, $tooltip_x, $tooltip_y, $WS_POPUP, Bitor($WS_EX_TOOLWINDOW, $WS_EX_TOPMOST))
	GUISetBkColor("0x" & $tip_color, $GUI_ToolTip)
	GUISetFont($tip_font_size, 500, default, $tip_font, $GUI_ToolTip)
	GUISetOnEvent($GUI_EVENT_PRIMARYUP, "ClickSnapTip", $GUI_ToolTip)

	global $tooltip_display_label = GUICtrlCreateLabel("", 1, 3, $tooltip_label_width, $tooltip_label_height, $SS_LEFTNOWORDWRAP, BitOr($GUI_WS_EX_PARENTDRAG, $reading_direction))
	; global $tooltip_display_label = GUICtrlCreateLabel("", 1, 3, $tooltip_label_width, $tooltip_label_height, $SS_LEFTNOWORDWRAP, BitOr($GUI_WS_EX_PARENTDRAG, $reading_direction))
					; Bitor($text_alignment, $SS_LEFTNOWORDWRAP), BitOr($GUI_WS_EX_PARENTDRAG, $reading_direction))
	GUICtrlSetBkColor(-1, "0x" & $tip_color)
	GUICtrlSetColor(-1, "0x" & $tip_text_color)

	local $context_menu_id = GUICtrlCreateContextMenu($tooltip_display_label)

	GUICtrlCreateMenuItem(_T("About") & " " & $app_name, $context_menu_id)
	GUICtrlSetOnEvent(-1, "ShowAboutBoxDefault")
	GUICtrlCreateMenuItem("", $context_menu_id)
	GUICtrlCreateMenuItem(_T("Disable Progress toolTip"), $context_menu_id)
	GUICtrlSetOnEvent(-1, "ToggleToolTip")
	GUICtrlCreateMenuItem("", $context_menu_id)

	$menu_toggle_audio = GUICtrlCreateMenuItem(_T("Disable Audio Alerts"), $context_menu_id)
	GUICtrlSetOnEvent(-1, "ToggleAudio")
	GUICtrlCreateMenuItem("", $context_menu_id)

	if $show_edit_ini = $ON then
		GUICtrlCreateMenuItem(_T("Edit Prefs (checksum.ini)"), $context_menu_id)
		GUICtrlSetOnEvent(-1, "EditIniFileWithEditor")
		GUICtrlCreateMenuItem("", $context_menu_id)
	endif

	if StringLower(StringLeft($allow_multiple, 1)) = "q" then
		GUICtrlCreateMenuItem(_T("Abort Queue"), $context_menu_id)
		GUICtrlSetOnEvent(-1, "AbortQueueAndQuit")
		GUICtrlCreateMenuItem("", $context_menu_id)
	endif

	GUICtrlCreateMenuItem(_T("Exit"), $context_menu_id)
	GUICtrlSetOnEvent(-1, "ItsQuittingTime")
	GUISetState(@SW_SHOW, $GUI_ToolTip)

	$tooltip_ready = true
	DoToggleToolTip(false)
	DoToggleToolTip(false)
	DoToggleAudio(false)
	DoToggleAudio(false)
	SnapTip(true)

endfunc



;
; DoProgressTips()

; Updates the tray mouseover information and floating progress tip windoid..
;
func DoProgressTips($my_prog_msg, $force_tray_msg=false)

	; Don't need this now..
	AdlibUnRegister("ProgressTipUpdater")

	; Store in case we are re-enabled during current item..
	$stored_progress_str = $my_prog_msg

	; Creating hashes..
	if $operation_mode <> "verify" or $force_tray_msg then
		SetTrayTip($my_prog_msg)
	else
		if $has_failures then
			local $start_index = UBound($file_queue_array) - 5
			if $start_index < 0 then $start_index = 0
			local $recent_failures = ""
			for $i = $start_index to UBound($file_queue_array) - 1
				if StringLen($recent_failures) > 64 then exitloop
				if $file_queue_array[$i][0] then $recent_failures &= @LF & " " & StringLeft(BaseName($file_queue_array[$i][1]), 60) & "... "
			next
			SetTrayTip( _T("verifying: right-click to bring up the menu") & " " & @LF & " " & _T("recent failures") & ": " & $recent_failures)
		else
			SetTrayTip(_T("verifying") & ": " & @LF & _T("no failures, so far"))
		endif

	endif

	; No comment..
	if $progress_tip <> $ON then return

	local $tip_width = Int(StringLen($my_prog_msg) * (($tip_font_size / 4) * $tip_stretch))
	if $tip_anchor_right = $ON then
		local $cur_pos = WinGetPos($GUI_ToolTip)
		if IsArray($cur_pos) then
			WinMove($GUI_ToolTip, "", $cur_pos[0] + $cur_pos[2] - $tip_width, default, $tip_width)
		else
			WinMove($GUI_ToolTip, "", default, default, $tip_width)
		endif
	else
		WinMove($GUI_ToolTip, "", default, default, $tip_width)
	endif
	ControlSetText($GUI_ToolTip, "", $tooltip_display_label, " " & $my_prog_msg & " ")

endfunc



func ClickSnapTip()
	SnapTip(false)
endfunc



;
; SnapTip()

; Adjusts tooltip screen position coordinates so it stays within visible monitor
; bounds preventing off-screen display. Throw it anywhere off the edge of your
; desktop and it will snap back into position and stay anchored there, otherwise
; it anchors to its x/y position.
;
func SnapTip($init=false)

	debug("SnapTip($init =" & $init & ") 					--->", @ScriptLineNumber, 5)

	if $init and $tip_anchor_right = $ON then
		WinMove($GUI_ToolTip, "", @DesktopWidth, default)
	endif

	if WinExists($GUI_ToolTip) then
		local $win_pos = WinGetPos($GUI_ToolTip)
		if not IsArray($win_pos) then return 0
	else
		return 0
	endif

	local $x = $win_pos[0]
	local $y = $win_pos[1]
	local $w = $win_pos[2]
	local $h = $win_pos[3]

	$tip_anchor_right = $OFF

	if $x < $tip_snap then
		$x = 0
		$tip_anchor_right = $OFF
	endif

	if $x > @DesktopWidth - $w - $tip_snap then
		$x = @DesktopWidth - $w
		$tip_anchor_right = $ON
	endif

	if $y < $tip_snap then $y = 0
	if $y > @DesktopHeight - $h - $tip_snap then $y = @DesktopHeight - $h

	WinMove($GUI_ToolTip, "", $x, $y)

	if $tooltip_x <> $x then IniWrite($ini_path, $app_name, "x", $x)
	if $tooltip_y <> $y then IniWrite($ini_path, $app_name, "y", $y)
	IniWriteCheckBox($ini_path, $app_name, "tip_anchor_right", $tip_anchor_right)

endfunc



; SetTipWarnColor()
; Changes tooltip color for warning messages during verification.
func SetTipWarnColor()
	if $progress_tip <> $ON then return
	GUISetBkColor("0x" & $warn_color, $GUI_ToolTip)
	GUICtrlSetBkColor($tooltip_display_label, "0x" & $warn_color)
	GUICtrlSetColor($tooltip_display_label, "0x" & $tip_color)
endfunc

; SetTipDefaultColor()
; Resets tooltip back to default.
func SetTipDefaultColor()
	if $progress_tip <> $ON then return
	GUISetBkColor("0x" & $tip_color, $GUI_ToolTip)
	GUICtrlSetBkColor($tooltip_display_label, "0x" & $tip_color)
	GUICtrlSetColor($tooltip_display_label, "0x" & $tip_text_color)
endfunc


; SlowProgressUpdate()
; Auto-update progress on slow operations.
func SlowProgressUpdate($my_file)
	$current_file = $my_file
	AdlibRegister("ProgressTipUpdater", 1000)
endfunc

; ProgressTipUpdater()
; Turn off slow-ops-auto-update and set progress to current file.
func ProgressTipUpdater()
	AdlibUnRegister("ProgressTipUpdater")
	DoProgressTips($current_file)
endfunc


; ToggleToolTip()
; User toggled tooltip. A wrapper function.
func ToggleToolTip()
	DoToggleToolTip()
endfunc

; DoToggleToolTip()
; Toggle tooltip from the tray and (if it's a user action) save setting to ini..
func DoToggleToolTip($save_pref=true)

	debug("DoToggleToolTip() save_pref: =>" & $save_pref & "<=" , @ScriptLineNumber, 5)

	if $save_pref then
		if $tray_click_bounce then return
		$tray_click_bounce = true
		AdlibRegister("EndDeBounce", 500)
	endif

	if $progress_tip = $OFF then
		if not $tooltip_ready then checksumProgress()
		$progress_tip = $ON
		if WinExists($GUI_ToolTip) then GUISetState(@SW_SHOW, $GUI_ToolTip)
		if WinExists($GUI_Options) then GUICtrlSetState($checkbox_progress_tip, $ON)
		TrayItemSetText($tray_items[3], _T("Disable Progress toolTip"))
		DoProgressTips($stored_progress_str)
	else
		$progress_tip = $OFF
		if WinExists($GUI_ToolTip) then GUISetState(@SW_HIDE, $GUI_ToolTip)
		if WinExists($GUI_Options) then GUICtrlSetState($checkbox_progress_tip, $OFF)
		TrayItemSetText($tray_items[3], _T("Enable Progress toolTip"))
	endif

	if $save_pref then IniWriteCheckBox($ini_path, $app_name, "progress_tip", $progress_tip)
	debug("DoToggleToolTip() progress_tip: =>" & Human($progress_tip) & "<=" , @ScriptLineNumber, 5)

endfunc

; EndDeBounce()
; For left-clicks in tray.
func EndDeBounce()
	AdlibUnRegister("EndDeBounce")
	$tray_click_bounce = false
endfunc


; Set the actual tray tip, using RTL ordering if required.
func SetTrayTip($tip_text="")
	local $direction_mark = ChrW(0x200E)
	if $is_rtl == $ON then $direction_mark = ChrW(0x200F)
	local $my_tiptext = $direction_mark & $tip_text & @LF
	if $tip_text = "" then $my_tiptext = $direction_mark
	return TraySetToolTip($my_tiptext & $TRAY_CLICK_MSG)
endfunc




;
; Pop-Up / mouseover help tips for GUI.

; Custom replacement for GUICtrlSetTip(), with padding.
func SetPaddedTip($control_id, $text)
	local $control_handle = GUICtrlGetHandle($control_id)
	local $parent_window = _WinAPI_GetParent($control_handle)
	_GUIToolTip_AddTool($tooltip_handle, $parent_window, $text, $control_handle)
endfunc

; Setup padding for the GUI ToolTips..
func InitPaddedTips($left_margin=6, $top_margin=4, $right_margin=6, $bottom_margin=4)

	$tooltip_handle = _GUIToolTip_Create(0)
	_WinAPI_SetWindowPos($tooltip_handle, -1, 0, 0, 0, 0, 0x0013)

	if $is_rtl == $ON then
		local $extended_style = _WinAPI_GetWindowLong($tooltip_handle, -20)
		local $rtl_flags = 0x00403000
		_WinAPI_SetWindowLong($tooltip_handle, -20, BitOR($extended_style, $rtl_flags))
	endif

	DllCall("uxtheme.dll", "long", "SetWindowTheme", "hwnd", $tooltip_handle, "wstr", "", "wstr", "")
	_GUIToolTip_SetMaxTipWidth($tooltip_handle, 400)
	_GUIToolTip_SetTipBkColor($tooltip_handle, 0xFFFFFF)
	_GUIToolTip_SetTipTextColor($tooltip_handle, 0x000000)
	_GUIToolTip_SetMargin($tooltip_handle, $left_margin, $top_margin, $right_margin, $bottom_margin)
endfunc





; ToggleAudio()
; User toggled audio notifications. A wrapper.
func ToggleAudio()
	DoToggleAudio()
endfunc

; DoToggleAudio()
; Toggle audio notifications and save setting to ini.
func DoToggleAudio($save_pref=true)

	if $beep_alerts = $OFF then
		$beep_alerts = $ON
		$my_msg = _T("Disable Audio Alerts")
		if WinExists($GUI_ToolTip) then GUICtrlSetData($menu_toggle_audio, $my_msg)
		TrayItemSetText($tray_items[5], $my_msg)
	else
		$beep_alerts = $OFF
		$my_msg = _T("Enable Audio Alerts")
		if WinExists($GUI_ToolTip) then GUICtrlSetData($menu_toggle_audio, $my_msg)
		TrayItemSetText($tray_items[5], $my_msg)
	endif

	if $save_pref then IniWriteCheckBox($ini_path, $app_name, "beep_alerts", $beep_alerts)
	debug("DoToggleAudio() beep_alerts: =>" & Human($beep_alerts) & "<=" , @ScriptLineNumber, 5)
endfunc



;
; MakeTray()

; Create / refresh system tray menu:
;
func MakeTray($running_tray=true)

	for $t = 1 to UBound($tray_items) - 1
		TrayItemDelete($tray_items[$t])
	next

	$tray_items[1] = TrayCreateItem(_T("About") & " " & $app_name & "..")
	TrayItemSetOnEvent(-1, "ShowAboutBox")
	$tray_items[2] = TrayCreateItem("")
	TraySetOnEvent($TRAY_EVENT_PRIMARYDOWN, "ToggleToolTip")
	TraySetOnEvent($TRAY_EVENT_PRIMARYUP, "ToggleToolTip")

	if $running_tray then
		$tray_items[3] = TrayCreateItem(_T("Toggle Progress toolTip"))
		TrayItemSetOnEvent(-1, "ToggleToolTip")
		$tray_items[4] = TrayCreateItem("")
		$tray_items[5] = TrayCreateItem(_T("Toggle Audio Alerts"))
		TrayItemSetOnEvent(-1, "ToggleAudio")
		$tray_items[6] = TrayCreateItem("")
	endif

	if $show_edit_ini = $ON then
		$tray_items[7] = TrayCreateItem(_T("Edit Prefs (checksum.ini)") & "..")
		TrayItemSetOnEvent(-1, "EditIniFileWithEditor")
		$tray_items[8] = TrayCreateItem("")
	endif

	if $path and $operation_mode = "verify" and not $running_tray then
		$tray_items[9] = TrayCreateItem(_T("Edit Mail Prefs") & "..")
		TrayItemSetOnEvent(-1, "EditMailPreferences")
		$tray_items[10] = TrayCreateItem("")
	endif

	if StringLower(StringLeft($allow_multiple, 1)) = "q" then
		$tray_items[11] = TrayCreateItem(_T("Abort Queue"))
		TrayItemSetOnEvent(-1, "AbortQueueAndQuit")
		$tray_items[12] = TrayCreateItem("")
	endif

	$tray_items[13] = TrayCreateItem(_T("Exit"))
	TrayItemSetOnEvent(-1, "ItsQuittingTime")
	TraySetClick(8)
	TraySetState()
	TraySetIcon($exe_path, 0)
	SetTrayTip()

endfunc




;
; NothingToDo()								BTest\NO-PERMISSION\PS3 Baby_360p [2021-03-31].mkv				cro b:\

; Shows a message box when no files were selected or found by the directory
; search routine, prompts user to add more files and try again.
;
func NothingToDo()

	if $user_quit then return

	VisitUrl("https://corz.org/windows/software/checksum/checksum-launch.php")

	$my_msg = _T("checksum was given nothing to do!")
	SetTrayTip($my_msg)

	AutoItSetOption("GUIOnEventMode", 0)
	AutoItSetOption("GUICoordMode", 1)

	local $margin = 15
	local $text_scale = ChecksumDialogTextScale()
	local $gui_height = Ceiling(160 * $text_scale)
	local $gui_width = Ceiling(500 * $text_scale)

	$GUI_nothing_to_do = GUICreate($my_msg, $gui_width, $gui_height, -1, -1, $WS_CAPTION, $WS_EX_TOPMOST)
	GUISetIcon($exe_path, 0, $GUI_nothing_to_do)
	GUISetFont(9 * $text_scale, default, default, "Segoe UI", $GUI_nothing_to_do)
	$full_text = _T("No explorer context menu, no drag-and-drop, no command-line, nothing.\n\nIf you are not using the explorer context menu actions (or drag and drop) you need to provide\ncommand-line switches.")
	; Preserve paragraph breaks and let the label wrap the translated lines.
	local $info_text = $my_msg & @LF & @LF & StringRegExpReplace(_L($full_text), "(?<!\n)\n(?!\n)", " ")
	local $label_top = $margin - 5
	local $label_width = $gui_width - 2 * $margin
	local $label = GUICtrlCreateLabel($info_text, $margin, $label_top, $label_width, 1, $text_alignment, BitOr($GUI_WS_EX_PARENTDRAG, $reading_direction))
	local $label_height = FitLabelHeight($label, $info_text, $label_width)
	GUICtrlSetPos($label, $margin, $label_top, $label_width, $label_height)
	local $required_height = $label_top + $label_height + $margin + Ceiling(28 * $text_scale)
	if $required_height > $gui_height then
		local $outer = WinGetPos($GUI_nothing_to_do)
		WinMove($GUI_nothing_to_do, "", $outer[0], $outer[1], $outer[2], $outer[3] + $required_height - $gui_height)
		$gui_height = $required_height
	endif
	local $btn_help = GUICtrlCreateButton(_T("Get More Help!"), 10, $gui_height - Ceiling(28 * $text_scale), Ceiling(110 * $text_scale), Ceiling(22 * $text_scale))
	GUICtrlSetTip(-1, _T("Visit checksum tricks and tips page"))
	local $btn_simple = GUICtrlCreateButton(_T("Launch simple checksum"), Ceiling(125 * $text_scale), $gui_height - Ceiling(28 * $text_scale), Ceiling(150 * $text_scale), Ceiling(22 * $text_scale))
	GUICtrlSetTip(-1, _T("Launch simple checksum"))
	local $btn_cancel = GUICtrlCreateButton(_T("Cancel"), $gui_width - Ceiling(100 * $text_scale), $gui_height - Ceiling(28 * $text_scale), Ceiling(95 * $text_scale), Ceiling(22 * $text_scale))
	GUICtrlSetTip(-1, _T("Close this information window."))

	debugGUICtrlBorders($GUI_nothing_to_do)
	GUISetState()
	WinActivate($GUI_nothing_to_do)

	while 1

		if $user_quit then exitloop

		switch GUIGetMsg()
			case $GUI_EVENT_CLOSE, $btn_cancel
				exitloop
			case $btn_simple
				if _LFN_FileExists("simple checksum.exe") then
					Run("simple checksum.exe")
				else
					GUIDelete($GUI_nothing_to_do)
					MsgBox($MB_ICONERROR + $MB_TOPMOST, _T("Error!"), _T("{{simple checksum}} not found!") & @LF & _T("please reinstall checksum!"), $dialog_timeout)
					debug("simple checksum not found: ----->	EXIT 4" , @ScriptLineNumber, 1)
					exit 4
				endif
				exitloop
			case $btn_help
				VisitUrl("https://corz.org/windows/software/checksum/checksum-tricks.php")
				exitloop
		endswitch

		Sleep(5)

	wend

	GUIDelete($GUI_nothing_to_do)
endfunc


; Deletes the queue ini file then sets operation quit flag via ItsQuittingTime; tray menu "Abort Queue" action
func AbortQueueAndQuit()
	FileDelete($queue_file)
	ItsQuittingTime()
endfunc



func ____________________________MISC_DIALOGS()
endfunc


func EndSplash()
	AdlibUnRegister("EndSplash")
	$welcomed = $ON
	IniWriteCheckBox($ini_path, $app_name, "welcomed", $welcomed)
endfunc

;
; ShowSplash()					cro b:\

; A simple welcome splash.
; Also used for version upgrade notifcations.
;
func ShowSplash()

	local $opt_event = AutoItSetOption("GUIOnEventMode", 0)
	local $opt_coord = AutoItSetOption("GUICoordMode", 0)

	local $my_title = " " & _T("Welcome to checksum!") & " "
	if $is_upgrade == $ON then $my_title = " " & _T("checksum UPGRADED!") & " "

	local $text_scale = ChecksumDialogTextScale()
	local $gui = GUICreate($my_title, Ceiling(190 * $text_scale), Ceiling(44 * $text_scale), -1, -1, default, BitOr($WS_EX_TOOLWINDOW, $WS_EX_TOPMOST))
	GUISetFont(9 * $text_scale, default, default, "Segoe UI", $gui)
	local $splash_icon = GUICtrlCreateIcon($exe_path, 0, 8, 6, 32, 32)
	; Request the 32px image from the EXE's first icon group (zero-based index).
	local $splash_icon_handle = _WinAPI_ShellExtractIcon($exe_path, 0, 32, 32)
	if $splash_icon_handle then
		GUICtrlSendMsg($splash_icon, $STM_SETIMAGE, $IMAGE_ICON, $splash_icon_handle)
	endif
	GUICtrlCreateLabel($app_name & " v" & $VERSION & @LF & _T("from") & " corz.org", 46, 2, default, default, $text_alignment, $reading_direction)
	debugGUICtrlBorders($gui)
	GUISetState()

	while $welcomed <> $ON
		Sleep(25)
		local $msg = GUIGetMsg()
		switch $msg
			case $GUI_EVENT_CLOSE
				exitloop
			case $GUI_EVENT_PRIMARYDOWN
				VisitUrl($MY_URL)
				$welcomed = $ON
		endswitch
	wend

	GUIDelete($gui)
	if $splash_icon_handle then _WinAPI_DestroyIcon($splash_icon_handle)
	AutoItSetOption("GUIOnEventMode", $opt_event)
	AutoItSetOption("GUICoordMode", $opt_coord)

endfunc



; ShowAboutBoxDefault()
; Standalone wrapper (e.g. for GUICtrlSetOnEvent(func))
func ShowAboutBoxDefault()
	DoAboutBox()
endfunc

; ShowAboutBox()
; Unwrapped here..
func ShowAboutBox()
	DoAboutBox($GUI_Options)
endfunc


; DoAboutBox()
;
; The actual "About" box function..
;
func DoAboutBox($parent_gui=NULL)

	local $pos_x = -1
	local $pos_y = -1
	local $top_offset = 0
	local $text_scale = ChecksumDialogTextScale()
	local $dialog_height = Ceiling(105 * $text_scale)
	local $dialog_width = Ceiling(265 * $text_scale)
	local $text_left = 80
	local $had_nothing_to_do = false

	if WinVisible($parent_gui) then
		local $parent_pos = WinGetPos($parent_gui)
		if IsArray($parent_pos) then
			$pos_x = $parent_pos[0] + ($parent_pos[2] / 2) - ($dialog_width / 2)
			$pos_y = $parent_pos[1] + ($parent_pos[3] / 2) - ($dialog_height)
		endif
		HideWindow($parent_gui)
	endif

	if WinVisible($GUI_nothing_to_do) then
		GUIDelete($GUI_nothing_to_do)
		$had_nothing_to_do = true
	endif

	local $prev_on_event_mode = AutoItSetOption("GUIOnEventMode", 0)
	local $prev_coord_mode = AutoItSetOption("GUICoordMode", 1)

	$GUI_about = GUICreate(" " & _T("About") & " " & $app_name & "..", $dialog_width, $dialog_height + $top_offset, $pos_x, $pos_y, default, BitOR($WS_EX_TOOLWINDOW, $WS_EX_TOPMOST))
	GUISetFont(9 * $text_scale, default, default, "Segoe UI", $GUI_about)
	$my_msg = _T("from")

	local $label_app_info = GUICtrlCreateLabel($app_name & " v" & $VERSION & @LF & $my_msg & " corz.org", $text_left, 8, default, default, $text_alignment, $reading_direction)
	
	local $about_icon = GUICtrlCreateIcon($exe_path, 0, 6, 9, 64, 64)
	; Request the 64px image from the EXE's first icon group (zero-based index).
	local $about_icon_handle = _WinAPI_ShellExtractIcon($exe_path, 0, 64, 64)
	if $about_icon_handle then
		GUICtrlSendMsg($about_icon, $STM_SETIMAGE, $IMAGE_ICON, $about_icon_handle)
	endif
	
	$my_msg = _T("Do you want to visit the checksum\nweb page at this time?")
	local $label_question = GUICtrlCreateLabel(_L($my_msg), $text_left, $top_offset + Ceiling(40 * $text_scale), default, default, $text_alignment, $reading_direction)
	$my_msg = _T("No, not now")
	local $btn_no = GUICtrlCreateButton(_L($my_msg), 10, $top_offset + Ceiling(80 * $text_scale), Ceiling(95 * $text_scale), Ceiling(22 * $text_scale))

	$my_msg = _T("The other button is the one you want to click!")
	SetPaddedTip(-1, $my_msg)

	$my_msg = _T("Yes, let's do it!")
	local $btn_yes = GUICtrlCreateButton($my_msg, $dialog_width - Ceiling(104 * $text_scale), $top_offset + Ceiling(80 * $text_scale), Ceiling(95 * $text_scale), Ceiling(22 * $text_scale))

	$my_msg = _T("The link will open in your system default browser")
	SetPaddedTip(-1, $my_msg)
	local $arch_text = "x86"
	if @AutoItX64 = 1 then $arch_text = "x64"
	local $label_arch = GUICtrlCreateLabel($arch_text, $dialog_width - Ceiling(19 * $text_scale), 1, Ceiling(18 * $text_scale), Ceiling(12 * $text_scale), $text_alignment, $reading_direction)

	GUICtrlSetFont(-1, 8 * $text_scale, 200, 0, "Lucida Console")
	debugGUICtrlBorders($GUI_about)
	GUISetState()

	local $loop_counter = 1
	local $action
	local $gui_msg

	while 1
		$loop_counter += 1
		if Mod($loop_counter, 50) = 0 then
			GUICtrlSetColor($label_arch, $COLOR_DARKCHARCOAL)
		endif
		if Mod($loop_counter, 100) = 0 then
			GUICtrlSetColor($label_arch, $COLOR_BLACK)
		endif
		$gui_msg = GUIGetMsg()
		Sleep(10)
		switch $gui_msg
			case $GUI_EVENT_CLOSE, $btn_no
				exitloop
			case $btn_yes, $label_app_info, $label_question
				$action = "url"
				exitloop
			case $label_arch
				$action = "info"
				exitloop
		endswitch
	wend

	GUIDelete($GUI_about)
	if $about_icon_handle then _WinAPI_DestroyIcon($about_icon_handle)
	AutoItSetOption("GUICoordMode", $prev_coord_mode)
	AutoItSetOption("GUIOnEventMode", $prev_on_event_mode)
	FileDelete(@TempDir & "\about.gif")

	switch $action
		case "url"
			VisitUrl($MY_URL)
		case "info"
			SysInfoBox($app_name)
	endswitch

	if WinVisible($parent_gui) then ShowWindow($parent_gui)
	if $had_nothing_to_do then
		CheckVersionAndExit(4)
	endif

endfunc



;
; ShowBadFilesBox()			;			B:\Test\INVALID.hash

; Creates a custom input box GUI with large text field, OK button, timeout.
; Used for presenting an editable list of BAD files.
;
func ShowBadFilesBox($title, $text, $width=800, $height=800, $prompt="Click OK to continue", $timeout_sec=$dialog_timeout)

	debug("ShowBadFilesBox() text: =>" & $text & "<=" , @ScriptLineNumber, 5)

	$input_timeout = Number($timeout_sec)
	local $opt_event = AutoItSetOption("GUIOnEventMode", 0)
	local $opt_coord = AutoItSetOption("GUICoordMode", 1)

	$prompt = _T($prompt) & ".."

	local $text_scale = ChecksumDialogTextScale()
	local $GUI_InputDialog = GUICreate($title, $width, $height, -1, -1, BitOr($WS_DLGFRAME, $WS_SIZEBOX))

	GUISetFont(9 * $text_scale, default, default, "Segoe UI", $GUI_InputDialog)
	local $prompt_label = GUICtrlCreateLabel($prompt, 0, 0, default, default, $text_alignment, $reading_direction)
	local $prompt_rect = ControlGetPos($GUI_InputDialog, "", $prompt_label)
	local $ok_caption = _T("OK")
	local $ok_measure = GUICtrlCreateLabel($ok_caption, 0, 0)
	local $ok_rect = ControlGetPos($GUI_InputDialog, "", $ok_measure)
	GUICtrlDelete($ok_measure)

	local $margin = Ceiling($ok_rect[3] / 2)
	local $button_width = _Max(3 * $ok_rect[3], $ok_rect[2] + 2 * $margin)
	local $button_height = $ok_rect[3] + $margin
	local $footer_height = _Max($button_height, $prompt_rect[3])
	local $min_width = $prompt_rect[2] + $button_width + 3 * $margin
	local $min_height = $footer_height + $ok_rect[3] + 3 * $margin
	local $outer = WinGetPos($GUI_InputDialog)
	local $client = WinGetClientSize($GUI_InputDialog)
	local $frame_width = $outer[2] - $client[0]
	local $frame_height = $outer[3] - $client[1]
	$width = _Max($width, $min_width)
	$height = _Max($height, $min_height)
	if $width <> $client[0] or $height <> $client[1] then _
		WinMove($GUI_InputDialog, "", $outer[0] - Int(($width - $client[0]) / 2), $outer[1] - Int(($height - $client[1]) / 2), $width + $frame_width, $height + $frame_height)
	RegisterMinMax($GUI_InputDialog, $min_width + $frame_width, $min_height + $frame_height)

	local $footer_top = $height - $margin - $footer_height
	$dialog_input = GUICtrlCreateInput($text, $margin, $margin, $width - 2 * $margin, $footer_top - 2 * $margin, BitOr(4, 64))
	GUICtrlSetResizing(-1, $GUI_DOCKTOP + $GUI_DOCKBOTTOM + $GUI_DOCKLEFT + $GUI_DOCKRIGHT)
	GUICtrlSetPos($prompt_label, $margin, $footer_top + Int(($footer_height - $prompt_rect[3]) / 2), $prompt_rect[2], $prompt_rect[3])
	GUICtrlSetResizing($prompt_label, $GUI_DOCKBOTTOM + $GUI_DOCKLEFT + $GUI_DOCKSIZE)
	local $ok_btn = GUICtrlCreateButton($ok_caption, $width - $margin - $button_width, $footer_top + Int(($footer_height - $button_height) / 2), $button_width, $button_height, $BS_CENTER, $reading_direction)
	GUICtrlSetResizing($ok_btn, $GUI_DOCKBOTTOM + $GUI_DOCKRIGHT + $GUI_DOCKSIZE)

	debugGUICtrlBorders($GUI_InputDialog)
	GUISetState(@SW_SHOW)

	ControlSend($GUI_InputDialog, "", $dialog_input, "{END}")
	ControlFocus($GUI_InputDialog, "", $ok_btn)
	GUIRegisterMsg($WM_COMMAND, "EditFocusResetTimer")

	local $timer = TimerInit()
	local $msg

	while 1
		$msg = GUIGetMsg()
		if $msg = $dialog_input then $input_timeout = 0
		if $msg = $ok_btn or $msg = $GUI_EVENT_CLOSE then exitloop
		Sleep(50)
		if $input_timeout > 0 and TimerDiff($timer) / 1000 > $input_timeout then exitloop
	wend

	UnregisterMinMax($GUI_InputDialog)
	GUIDelete($GUI_InputDialog)
	AutoItSetOption("GUIOnEventMode", $opt_event)
	AutoItSetOption("GUICoordMode", $opt_coord)

endfunc



; Reset close-timer when input control gains focus. User is editing.
func EditFocusResetTimer($hwnd, $msg, $w_param, $l_param)
	#forceref $hwnd, $msg
	local $notify_code = BitShift($w_param, 16)
	switch $l_param
		case GUICtrlGetHandle($dialog_input)
			switch $notify_code
				case $EN_SETFOCUS
					debug("EditFocusResetTimer() INPUT GOT FOCUS!" , @ScriptLineNumber, 5)
					$input_timeout = 0
			endswitch
	endswitch
	return $GUI_RUNDEFMSG
endfunc


; Reads Windows' accessibility text size for checksum's custom dialogs.
; Returns the configured percentage as a multiplier, or 1 if unavailable.
func ChecksumDialogTextScale()
	local $text_scale = RegRead("HKCU\Software\Microsoft\Accessibility", "TextScaleFactor")
	if @error or $text_scale < 100 then return 1
	return $text_scale / 100
endfunc


;
; ShowSyncDialog()

; Creates modal Yes/No/Yes-to-All/No-to-All/Synchronize/Abort dialog GUI
; returns choice string ("yes", "no", "yes_all", "no_all", "sync") or empty on abort/close
func ShowSyncDialog($title, $message, $allow_yes_all=false, $allow_no_all=false, $allow_sync=false, $hide_all_options=false)

	if $quiet_operation = $ON then return $sync_choice

	local $opt_gui_on_event = AutoItSetOption("GUIOnEventMode", 0)
	local $opt_coord = AutoItSetOption("GUICoordMode", 1)
	local $GUI_Sync = GUICreate($title, 460, 200)
	local $text_scale = ChecksumDialogTextScale()
	GUISetFont(9 * $text_scale, default, default, "Segoe UI", $GUI_Sync)
	local $captions = [_T("Yes"), _T("Yes to All"), _T("No"), _T("No to All"), _StringProper(_T("synchronize")), _T("Abort")]
	local $sample = GUICtrlCreateLabel($captions[0], 0, 0)
	local $sample_rect = ControlGetPos($GUI_Sync, "", $sample)
	GUICtrlDelete($sample)
	local $line_height = $sample_rect[3]
	local $margin = $line_height, $button_gap = Ceiling($line_height / 2)
	local $button_height = $line_height + $button_gap
	local $label = GUICtrlCreateLabel($message, $margin, $margin, default, default, $text_alignment, $reading_direction)
	local $label_rect = ControlGetPos($GUI_Sync, "", $label)
	local $button_y = $label_rect[1] + $label_rect[3] + $margin
	local $visible = [true, $allow_yes_all and not $hide_all_options, true, $allow_no_all and not $hide_all_options, $allow_sync, true]
	local $buttons[6]
	local $button_x = $margin

	for $i = 0 to UBound($captions) - 1
		if not $visible[$i] then continueloop
		local $caption = GUICtrlCreateLabel($captions[$i], 0, 0)
		local $caption_rect = ControlGetPos($GUI_Sync, "", $caption)
		GUICtrlDelete($caption)
		local $button_width = _Max(3 * $line_height, $caption_rect[2] + 2 * $button_gap)
		if $i = UBound($captions) - 1 then $button_x = _Max($button_x, ($label_rect[2] + 2 * $margin) - $margin - $button_width)
		local $style = default
		if $i = 2 then $style = $BS_DEFPUSHBUTTON
		$buttons[$i] = GUICtrlCreateButton($captions[$i], $button_x, $button_y, $button_width, $button_height, $style)
		$button_x += $button_width + $button_gap
	next

	local $client = WinGetClientSize($GUI_Sync)
	local $window = WinGetPos($GUI_Sync)
	local $gui_width = $button_x - $button_gap + $margin + $window[2] - $client[0]
	local $gui_height = $button_y + $button_height + $margin + $window[3] - $client[1]
	global $dialog_pos_x = (@DesktopWidth - $gui_width) / 2
	global $dialog_pos_y = (@DesktopHeight / 2) - $gui_height
	WinMove($GUI_Sync, "", $dialog_pos_x, $dialog_pos_y, $gui_width, $gui_height)
	AutoItSetOption("GUICoordMode", $opt_coord)
	debugGUICtrlBorders($GUI_Sync)
	GUISetState(@SW_SHOW)

	local $user_choice = ""
	local $msg

	do
		$msg = GUIGetMsg()
		select
			case $msg = $buttons[5] or $msg = $GUI_EVENT_CLOSE
				exitloop
			case $msg = $buttons[0]
				$user_choice = "yes"
			case $visible[1] and $msg = $buttons[1]
				$user_choice = "yes_all"
			case $msg = $buttons[2]
				$user_choice = "no"
			case $visible[3] and $msg = $buttons[3]
				$user_choice = "no_all"
			case $allow_sync and $msg = $buttons[4]
				$user_choice = "sync"
		endselect
		sleep(10)
	until $user_choice <> ""

	GUIDelete($GUI_Sync)
	AutoItSetOption("GUIOnEventMode", $opt_gui_on_event)

	$process_start_timer = TimerInit()
	return $user_choice

endfunc





func ____________________________INI_FUNCTIONS()
endfunc

;
; UpdateChecksumINIFile()

; During version upgrades, Updates checksum.ini by parsing the default
; checksum.ini (template), preserving all comments and layout, merging existing
; user settings and preserving existing dynamic/custom keys and sections.
;
func UpdateChecksumINIFile()

	SetTrayTip(_T("checksum is updating its ini file.."))
	local $current_version = IniRead($ini_path, $app_name, "version", "0.0.0.0")
	switch _VersionCompare($VERSION, $current_version)
		case 0, -1
			return -1
	endswitch

	debug($LF, @ScriptLineNumber, 6)
	debug("	***	NEW VERSION!!!	***", @ScriptLineNumber, 6)

	local $temp_ini_path = @TempDir & "\" & $INI_FILE & ".new"
	FileInstall("Resources\checksum.ini", $temp_ini_path, 1)

	local $template_lines = FileReadToArray($temp_ini_path)
	if @error then return -1

	local $user_sections = IniReadSectionNames($ini_path)
	local $handled_keys = "|"
	local $out_lines[0]
	local $current_section = ""
	local $line = ""
	local $match = 0
	local $key = ""
	local $user_val = ""
	local $default_marker = "___NON_EXISTENT_KEY___"
	local $last_key_idx = 0

	local $upgrading = $OFF
	if $current_version <> "0.0.0.0" then $upgrading = $ON

	for $index = 0 to UBound($template_lines) - 1
		$line = $template_lines[$index]

		; Detect section header [SectionName]
		$match = StringRegExp($line, "^\s*\[([^\]]+)\]", 1)
		if not @error then
			; Flush unhandled keys right after the last key of the ending section
			_InsertUnhandledSectionKeys($ini_path, $current_section, $handled_keys, $out_lines, $last_key_idx)
			$current_section = $match[0]
			_ArrayAddLine($out_lines, $line)
			$last_key_idx = UBound($out_lines)
			continueloop
		endif

		; Handle non-key lines (comments, blank lines)
		if StringRegExp($line, "^\s*(?:;|#|\r?\n|$)") then
			_ArrayAddLine($out_lines, $line)
			continueloop
		endif

		; Match key=value pattern while preserving optional inline comment
		$match = StringRegExp($line, "^\s*([^=;]+?)\s*=\s*(.*?)\s*(;.*)?$", 1)
		if not @error then
			$key = StringStripWS($match[0], $STR_STRIP_ENDS)
			$user_val = IniRead($ini_path, $current_section, $key, $default_marker)

			if $user_val <> $default_marker then
				local $inline_comment = ""
				if UBound($match) > 2 and $match[2] <> "" then $inline_comment = " " & $match[2]
				$line = $key & "=" & $user_val & $inline_comment
			endif

			$handled_keys &= $current_section & "\" & $key & "|"
			_ArrayAddLine($out_lines, $line)
			$last_key_idx = UBound($out_lines)
			continueloop
		endif

		_ArrayAddLine($out_lines, $line)
	next

	; Flush unhandled dynamic keys for the final section
	_InsertUnhandledSectionKeys($ini_path, $current_section, $handled_keys, $out_lines, $last_key_idx)

	; Append entirely new custom sections from user ini missing from default template
	if IsArray($user_sections) then
		for $sec_idx = 1 to $user_sections[0]
			local $sec_name = $user_sections[$sec_idx]
			local $user_keys = IniReadSection($ini_path, $sec_name)
			if IsArray($user_keys) then
				local $has_unhandled = false
				for $key_idx = 1 to $user_keys[0][0]
					if not StringInStr($handled_keys, "|" & $sec_name & "\" & $user_keys[$key_idx][0] & "|", 0) then
						$has_unhandled = true
						exitloop
					endif
				next
				if $has_unhandled then
					_TrimTrailingBlankLines($out_lines)
					_ArrayAddLine($out_lines, "")
					_ArrayAddLine($out_lines, "[" & $sec_name & "]")
					$last_key_idx = UBound($out_lines)
					_InsertUnhandledSectionKeys($ini_path, $sec_name, $handled_keys, $out_lines, $last_key_idx)
				endif
			endif
		next
	endif

	; Write merged output back to file
	local $file_handle = FileOpen($temp_ini_path, 2)
	if $file_handle <> -1 then
		for $out_idx = 0 to UBound($out_lines) - 1
			FileWriteLine($file_handle, $out_lines[$out_idx])
		next
		FileClose($file_handle)
	endif

	FileMove($ini_path, GetLongParentDir($ini_path) & "\[" & @YEAR & "-" & @MON & "-" & @MDAY & "@" & @HOUR & "." & @MIN & "] " & $INI_FILE)
	FileMove($temp_ini_path, $ini_path, 1)
	IniWrite($ini_path, $app_name, "version", $VERSION)

	; legacy removals..
	IniDelete($ini_path, $app_name, "stuff")
	IniDelete($ini_path, $app_name, "keep_dll")
	IniDelete($ini_path, $app_name, "dummy")
	IniDelete($ini_path, $app_name, "convert_level")
	IniDelete($ini_path, $app_name, "max")
	IniDelete($ini_path, $app_name, "tar_md5_special")

	return $upgrading
endfunc

func _ArrayAddLine(byref $array, $line)
	local $size = UBound($array)
	redim $array[$size + 1]
	$array[$size] = $line
endfunc

func _ArrayInsertLine(byref $array, $index, $line)
	local $size = UBound($array)
	redim $array[$size + 1]
	for $idx = $size to $index + 1 step -1
		$array[$idx] = $array[$idx - 1]
	next
	$array[$index] = $line
endfunc

func _InsertUnhandledSectionKeys($my_path, $section, byref $handled_keys, byref $out_lines, byref $insert_idx)
	local $keys = IniReadSection($my_path, $section)
	if not IsArray($keys) then return
	for $idx = 1 to $keys[0][0]
		local $k = $keys[$idx][0]
		local $v = $keys[$idx][1]
		if not StringInStr($handled_keys, "|" & $section & "\" & $k & "|", 0) then
			_ArrayInsertLine($out_lines, $insert_idx, $k & "=" & $v)
			$insert_idx += 1
			$handled_keys &= $section & "\" & $k & "|"
		endif
	next
endfunc

func _TrimTrailingBlankLines(byref $out_lines)
	while UBound($out_lines) > 0 and StringStripWS($out_lines[UBound($out_lines) - 1], $STR_STRIP_ENDS) == ""
		redim $out_lines[UBound($out_lines) - 1]
	wend
endfunc



; reads checkbox value from ini array cache returning on/off flag with default fallback
func INIArrayReadCheckBoxValue(byref $cache, $section, $key)
	return GetINIArrayValue($cache, $section, $key, true)
endfunc


; Searches a 2D array's first column for a matching key, returns associated value or default
func GetINIArrayValue(byref $cache, $key, $default, $is_checkbox=false)
	if not IsArray($cache) then return false
	for $i = 1 to $cache[0][0]
		if $cache[$i][0] == $key then
			if $cache[$i][1] <> "" then
				if $is_checkbox then return returnCheckBoxValue($cache[$i][1])
				return $cache[$i][1]
			endif
			return $default
		endif
	next
	return $default
endfunc



; EditIniFileWithEditor()
; Reads [checksum]editor from ini (default "notepad.exe"), runs it with $ini_path as argument; shows error dialog if launch fails
func EditIniFileWithEditor()
	local $my_editor = IniRead($ini_path, "checksum", "editor", "notepad.exe")
	if not Run($my_editor & " " & $ini_path) then
		MsgBox($MB_YESNO, _T("Error!"), _T("I couldn't run") & ":" & @LF & @LF & '"' & $my_editor & '"' & @LF & @LF & _T("Ironically, you need to check your {{ini}} settings!"), 30)
	endif
endfunc




; ContainsMediaFileExtension()
; Returns true if a group contain .mp3, .fla, .ogg, or .aac extensions.. Music!
func ContainsMediaFileExtension($my_ext)
	if StringInStr($my_ext, ".mp3", 2) or StringInStr($my_ext, ".flac", 2) or StringInStr($my_ext, ".ogg", 2) or StringInStr($my_ext, ".aac", 2) then
		return true
	endif
	return false
endfunc





;
; DeTokenize()

; Replaces @tokens.
;
func DeTokenize($string, $original_item, $string_type)

	debug("DeTokenize() string ->" & $string & "<-", @ScriptLineNumber, 8)
	debug("DeTokenize() original_item ->" & $original_item & "<-", @ScriptLineNumber, 8)
	debug("DeTokenize() string_type->" & $string_type & "<-", @ScriptLineNumber, 8)

	local $item_name = BaseName($original_item)
	if $string_type = "custom" then
		$string = StringReplace($string, "@fullpathnounc", StripLongPathPrefix($item_name))
		$string = StringReplace($string, "@fullpath", $item_name)
	endif
	debug("my_item ->" & $item_name & "<-", @ScriptLineNumber, 8)

	if $string_type = "path" then
		$string = StringReplace($string, "/", "\")
		$string = StringReplace($string, "\\", "\")
	endif

	if $string_type = "file" then
		$string = StringReplace($string, "\", "~")
		$string = StringReplace($string, "@desktop", "")
		$string = StringReplace($string, "@userdir", "")
		$string = StringReplace($string, "@checksumdir", "")
	endif

	local $dir_token_handled = false

	select
		case StringInStr($string, "@sec")
			$string = StringReplace($string, "@sec", @SEC)
			continuecase
		case StringInStr($string, "@min")
			$string = StringReplace($string, "@min", @MIN)
			continuecase
		case StringInStr($string, "@hour")
			$string = StringReplace($string, "@hour", @HOUR)
			continuecase
		case StringInStr($string, "@mday")
			$string = StringReplace($string, "@mday", @MDAY)
			continuecase
		case StringInStr($string, "@mon")
			$string = StringReplace($string, "@mon", @MON)
			continuecase
		case StringInStr($string, "@year")
			$string = StringReplace($string, "@year", @YEAR)
			continuecase
		case StringInStr($string, "@wday")
			$string = StringReplace($string, "@wday", @WDAY)
			continuecase
		case StringInStr($string, "@yday")
			$string = StringReplace($string, "@yday", @YDAY)
			continuecase
		case StringInStr($string, "@item")
			if $item_name <> "" then $string = StringReplace($string, "@item", $item_name)
			continuecase
		case StringInStr($string, "@parent")
			$string = ResolveParentDepthTokens($string, $original_item, $string_type)
			continuecase
		case StringInStr($string, "@status")
			if $has_failures then
				$string = StringReplace($string, "@status", $status_fail)
			else
				$string = StringReplace($string, "@status", $status_success)
			endif
			continuecase
		case StringInStr($string, "@desktop")
			$dir_token_handled = true
			$string = StringReplace($string, "@desktop", @DesktopDir)
			$string = StringReplace($string, "@checksumdir\", "")
			$string = StringReplace($string, "@checksumdir", "")
			$string = StringReplace($string, "@userdir\", "")
			$string = StringReplace($string, "@userdir", "")
		case StringInStr($string, "@userdir")
			if not $dir_token_handled then
				$dir_token_handled = true
				$string = StringReplace($string, "@userdir", $config_folder_path)
				$string = StringReplace($string, "@checksumdir\", "")
				$string = StringReplace($string, "@checksumdir", "")
			endif
		case StringInStr($string, "@checksumdir")
			if not $dir_token_handled then
				if StringRight($script_dir, 1) = "\" then $script_dir = StringTrimRight($script_dir, 1)
				$string = StringReplace($string, "@checksumdir", $script_dir)
				$dir_token_handled = true
			endif
		case StringInStr($string, "@exit")
			$string = StringReplace($string, "@exit", $exit_code_value)
	endselect

	debug("DeTokenizeD string ->" & $string & "<-", @ScriptLineNumber, 8)
	return $string

endfunc



; Iteratively resolves @parent+1, @parent*separator tokens in a template string by walking up directory hierarchy.
func ResolveParentDepthTokens($toknzd_string, $item_path, $token_type)

	debug("doParentDepth() $toknzd_string =>" & $toknzd_string & "<=", @ScriptLineNumber, 8)
	debug("doParentDepth() $my_item =>" & $item_path & "<=", @ScriptLineNumber, 8)
	debug("doParentDepth() $token_type =>" & $token_type & "<=", @ScriptLineNumber, 8)

	local $token_pos, $operator_char, $depth_char, $depth_count, $depth_counter, $resolved_parent
	local $current_path = GetLongParentDir($item_path)
	local $base_path = $current_path

	while StringInStr($toknzd_string, "@parent")

		$token_pos = StringInStr($toknzd_string, "@parent")
		$operator_char = StringMid($toknzd_string, $token_pos + 7, 1)
		$depth_char = StringMid($toknzd_string, $token_pos + 8, 1)
		$depth_count = Number($depth_char)
		$depth_counter = $depth_count

		if $depth_char and $operator_char = "*" then
			$resolved_parent = StringReplace(FormatPathForDisplay($item_path), ":\", "\")
			$resolved_parent = StringReplace($resolved_parent, "\", $depth_char) & $depth_char
			$toknzd_string = StringReplace($toknzd_string, "@parent" & "*" & $depth_char, $resolved_parent)

		elseif $depth_count and $operator_char = "+" then
			$current_path = $base_path

			while $depth_count
				if BaseName($current_path) = "" then
					$resolved_parent = GetDriveOrServerName($current_path)
					exitloop
				else
					$resolved_parent = BaseName(GetLongParentDir($current_path))
					$depth_count -= 1
				endif
				$current_path = GetLongParentDir($current_path)
			wend

			$toknzd_string = StringReplace($toknzd_string, "@parent" & "+" & $depth_counter, $resolved_parent, 1)
		else
			$resolved_parent = BaseName($base_path)
			$toknzd_string = StringReplace($toknzd_string, "@parent", $resolved_parent, 1)
		endif
		debug("toknzd_string =>" & $toknzd_string & "<=", @ScriptLineNumber, 8)
	wend

	debug("FINAL toknzd_string =>" & $toknzd_string & "<=", @ScriptLineNumber, 8)
	return $toknzd_string
endfunc






func ______________________________________ETC()
endfunc


; Sets $is_operation_quit_flag to true to halt ongoing operations
func ItsQuittingTime()
	$user_quit = true
endfunc


; SaveWinPosition()
; Save create/verify options window position, if it has changed.
func SaveWinPosition()
	local $winpos_data = WinGetPos($GUI_Options)
	if IsArray($winpos_data) then
		if $gui_initial_position_x <> $winpos_data[0] then IniWrite($ini_path, $app_name, "opt_x", $winpos_data[0])
		if $gui_initial_position_y <> $winpos_data[1] then IniWrite($ini_path, $app_name, "opt_y", $winpos_data[1])

	endif
endfunc


; HideWindow()
; Disable GUI window and set tray icon to busy/dimmed state while dialog is open.
func HideWindow($my_GUI)
	GUISetState(@SW_DISABLE, $my_GUI)
	TraySetState(2)
endfunc


; ShowWindow()
; Restore GUI: basically undo HideWindow().
func ShowWindow($my_GUI)
	TraySetState(1)
	TraySetIcon($exe_path, 0)
	GUISetState(@SW_ENABLE, $my_GUI)
	WinActivate($my_GUI)
	GUIswitch($my_GUI)
endfunc



;
; HandleDragDropFiles()

; Some internal shit.
; Processes WM_DROPFILES notification via DragQueryFileW API.
;
func HandleDragDropFiles($hwnd, $msg, $wparam, $lparam)

	#forceref $hwnd, $msg, $lparam

	local $buffer_len, $path_struct
	local $file_count = DllCall("shell32.dll", "int", "DragQueryFileW", "hwnd", $wparam, "int", -1, "ptr", 0, "int", 255)
	redim $dropped_files[$file_count[0]]

	for $index = 0 to $file_count[0] - 1
		$buffer_len = DllCall("shell32.dll", "int", "DragQueryFileW", "hwnd", $wparam, "int", $index, "ptr", 0, "int", 0)
		$buffer_len = $buffer_len[0] + 1
		$path_struct = DllStructCreate("wchar[" & $buffer_len & "]")
		DllCall("shell32.dll", "int", "DragQueryFileW", "hwnd", $wparam, "int", $index, "ptr", DllStructGetPtr($path_struct), "int", $buffer_len)
		$dropped_files[$index] = DllStructGetData($path_struct, 1)
		$path_struct = 0
	next

endfunc



;
; DoStartupCommand()

; No command-line, check for pre-configured startup command and run it..
;
func DoStartupCommand()

	local $startup_command = StringStripWS(GetINIArrayValue($ini_array, "startup_command", ""), $STR_STRIP_ENDS)
	debug($LF, @ScriptLineNumber, 5)
	debug("No Command-Line. Checking for startup_command =>" & $startup_command & "<=", @ScriptLineNumber, 5)

	if $startup_command <> "" then
		local $exec_result, $exec_error

		select
			case StringInStr($startup_command, BaseName(@ScriptFullPath) & "|") or StringInStr($startup_command, BaseName(@ScriptFullPath) & '"|')
				debug("@ScriptFullPath =>" & @ScriptFullPath & "<=", @ScriptLineNumber, 5)
				MsgBox($MB_TOPMOST, _T("Startup Command Launch Error!"), _
					_T("To launch checksum as a startup command, edit your checksum.ini:\n\n{{startup_command=checksum|<command here>}}"), 30)
				debug("startup command launch error: ----->	EXIT 101" , @ScriptLineNumber, 1)
				exit 101

			case StringLeft($startup_command, 4) = "dos|"
				$startup_command = StringStripWS(StringMid($startup_command, 5), $STR_STRIP_ENDS)
				if $startup_command <> "" then
					debug("RUNNING startup_command =>" & $startup_command & "<=", @ScriptLineNumber, 5)
					$exec_result = Run(@ComSpec & " /c " & DeTokenize($startup_command, @WorkingDir, "custom"), @WorkingDir, @SW_HIDE)
					$exec_error = @error
					debug("DOS @error : ----->	EXIT 102" , @ScriptLineNumber, 1)
					exit 102
				endif

			case StringLeft($startup_command, 8) = "shellex|"
				local $shellex_params, $shellex_verb, $shellex_dir
				$startup_command = DeTokenize($startup_command, @WorkingDir, "custom")
				local $command_parts = StringSplit($startup_command, "|")
				$startup_command = $command_parts[2]
				if $startup_command <> "" then
					if $command_parts[0] > 2 then
						$shellex_params = $command_parts[3]
					endif
					if $command_parts[0] > 3 then
						$shellex_verb = $command_parts[4]
					endif
					if $command_parts[0] > 4 and $command_parts[5] <> "" then
						$shellex_dir = $command_parts[5]
					else
						$shellex_dir = @WorkingDir
					endif
					debug("SHELLEX startup_command =>" & $startup_command & "<=", @ScriptLineNumber, 5)
					debug("SHELLEX startup_params =>" & $shellex_params & "<=", @ScriptLineNumber, 5)
					debug("SHELLEX startup_verb =>" & $shellex_verb & "<=", @ScriptLineNumber, 5)
					debug("SHELLEX startup_dir =>" & $shellex_dir & "<=", @ScriptLineNumber, 5)
					debug("RUNNING startup_command =>" & $startup_command & "<=", @ScriptLineNumber, 5)
					$exec_result = ShellExecute($startup_command, $shellex_params, $shellex_dir, $shellex_verb)
					$exec_error = @error
					debug("SHELLEX @error =>" & @error & "<=", @ScriptLineNumber, 5)
					if $exec_result then
						debug("SHELLEX OK: ----->	EXIT 103" , @ScriptLineNumber, 1)
						exit 103
					else
						debug("SHELLEX ERROR: ----->	EXIT 102" , @ScriptLineNumber, 1)
						exit 203
					endif
				endif

			case StringLeft($startup_command, 9) = "checksum|"
				$startup_command = StringStripWS(StringMid($startup_command, 10), $STR_STRIP_ENDS)
				if $startup_command <> "" then
					debug("RUNNING startup_command =>" & $startup_command & "<=", @ScriptLineNumber, 5)
					$exec_result = Run('"' & @AutoItExe & '"' & " " & DeTokenize($startup_command, @WorkingDir, "custom"), @WorkingDir)
					$exec_error = @error
					debug("internal @error =>" & @error & "<=", @ScriptLineNumber, 5)
					if $exec_result then
						debug("Startup Command Run OK: ----->	EXIT 100" , @ScriptLineNumber, 1)
						exit 100
					endif
				endif

			case StringLeft($startup_command, 4) = "pref"
				EditIniFileWithEditor()
				exit 0

			case StringLeft($startup_command, 5) = "sched"
				$task_mode = true

			case StringLeft($startup_command, 7) = "sysinfo" or StringLeft($startup_command, 4) = "info"
				SysInfoBox($app_name)
				CheckVersionAndExit(0)

			case else
				if $startup_command <> "" and StringLeft($startup_command, 8) <> StringLeft(BaseName(@AutoItExe), 8) _
				  and StringRight($startup_command, StringLen(BaseName(@AutoItExe))) <> StringRight(BaseName(@AutoItExe), StringLen(BaseName(@AutoItExe))) then
					debug("RUNNING startup_command =>" & $startup_command & "<=", @ScriptLineNumber, 5)
					$exec_result = Run(DeTokenize($startup_command, @WorkingDir, "custom"))
					$exec_error = @error
					debug("external @error =>" & @error & "<=", @ScriptLineNumber, 5)
					if $exec_result then
						exit 201
					else
						MsgBox($MB_TOPMOST, _T("Startup Command Launch Error!"), _
							_T("Error launching startup command. Code: [code]\nPlease check the startup_command preference in your {{checksum.ini}}", "[code]", $exec_error), 30)
						debug("ERROR running startup command: ----->	EXIT 202" , @ScriptLineNumber, 1)
						exit 202
					endif
				endif
		endselect

		if not $task_mode then
			MsgBox($MB_TOPMOST, _T("Invalid Startup Command!"), ("Please check the startup_command preference in your {{checksum.ini}}") & @LF & @LF, 30)
			debug("Invalid Startup Command: ----->	EXIT 200" , @ScriptLineNumber, 1)
			exit 200
		endif

	endif

endfunc




;
; ProcessQueueAndShutdown()

; Reads queue ini and launches next queued task; optionally runs custom exit
; command from ini; shows 60s countdown before Shutdown() if flag set.
;
func ProcessQueueAndShutdown($my_exit_code)

	if FileExists($queue_file) then

		Sleep(250)
		local $rz = IniReadSection($queue_file, "queue")

		if IsArray($rz) then
			local $u0 = $rz[1][1]
			if IniDelete($queue_file, "queue", $rz[1][0]) then
				if @Compiled = 1 then
					Run('"' & @AutoItExe & '"' & " " & $u0)
				else
					Run(FileGetShortName(@AutoItExe) & " " & '"' & @ScriptFullPath & '"' & " " & $u0)
				endif
			endif
		else
			FileDelete($queue_file)
		endif

	endif

	if $do_exit_command = $ON then
		$exit_command = StringStripWS(GetINIArrayValue($ini_array, "exit_command", ""), $STR_STRIP_ENDS)
		if $exit_command <> "" then
			$exit_command = DeTokenize($exit_command, $path, "custom")
			Run($exit_command)
		endif
	endif

	if $shutdown_when_done = $ON then
		$my_msg = _T("checksum will now shutdown your computer") & ".."
		$full_text = _T("To abort the shutdown process, click Cancel within the next 60 seconds.\n\nClick OK to shutdown immediately.")
		local $u1 = MsgBox($MB_OKCANCEL, $my_msg, $my_msg & @LF & @LF & _L($full_text) , 60)
		if $u1 = $IDOK or $u1 = $IDTIMEOUT then
			Shutdown(Bitor($SD_SHUTDOWN, $SD_POWERDOWN))
		endif
	endif

	exit $my_exit_code

endfunc



; Check for changes to checksum's itsory..
func CheckUpdateLog()

	; I will often hit save MANY times in an hour, so this prevents repeat annoyance if you are doing a lot of hashing.
	local $nfo_check_time = IniRead($ini_path, "checksum", "nfo_check_time", "2000/01/01 00:00:00")
	local $hours_elapsed = _DateDiff("h", $nfo_check_time, _NowCalc())
	if $hours_elapsed < 1 then return false

	local $current_logsize = GetRemoteFileSize($UPDATE_LOG)
	if $current_logsize <= 0 then return false

	if $itstory_checking > 1 and $current_logsize <> $itstory_checking and $quiet_operation = $OFF then
		$my_msg = _T("There have been new changes with checksum.\n\nWould you like to read about them?")
		if MsgBox($MB_YESNO + $MB_ICONQUESTION + $MB_TOPMOST, "ITSTORY " & _T("UPDATE!"), _L($my_msg)) = $IDYES then VisitURL($UPDATE_LOG)
	endif
	IniWrite($ini_path, $app_name, "itstory_checking", $current_logsize)
	IniWrite($ini_path, "checksum", "nfo_check_time", _NowCalc())
endfunc


; The server returns the byte count as plain text for this user agent.
func GetRemoteFileSize($url)

	local $request = ObjCreate("WinHttp.WinHttpRequest.5.1")
	if not IsObj($request) then return 0

	local $query_token = "?"
	if StringInStr($url, "?") then $query_token = "&"

	$request.Open("GET", $url & $query_token & Int(TimerInit()), false)
	if @error then return 0
	$request.SetRequestHeader("User-Agent", "app.corz.org")
	if @error then return 0
	$request.Send()
	if @error then return 0

	local $status = $request.Status
	if @error or $status <> 200 then return 0

	local $response = $request.ResponseText
	if @error then return 0
	$response = StringStripWS($response, $STR_STRIP_ENDS)
	if not StringRegExp($response, "^[0-9]+$") then return 0

	return Number($response)

endfunc



; Switches version-check URL to beta channel if enabled, then onto cleanup/exit
func CheckVersionAndExit($my_exit_code)
	debug("CheckVersionAndExit(" & $my_exit_code & ")...", @ScriptLineNumber, 5)

	local $check_url = $VERSION_CHECK_URL
	if $beta_channel = $ON then $check_url = $beta_url
	CheckVersion($app_name, $check_url, $DOWNLOAD_URL, $ini_path, $app_name, $VERSION)
	ProcessQueueAndShutdown($my_exit_code)
endfunc



; Prompts for one line of text at the Windows accessibility text size.
; Takes the title, prompt, initial input, base width and optional parent.
; Fits the wrapped prompt and controls using their rendered font.
; Returns the field text on OK or "" on cancellation.
func ChecksumTextInput($title, $prompt, $initial_text, $base_width, $parent_gui=default)
	local $event_mode = AutoItSetOption("GUIOnEventMode", 0)
	local $coord_mode = AutoItSetOption("GUICoordMode", 1)
	local $text_scale = ChecksumDialogTextScale()
	local $dialog = GUICreate($title, Ceiling($base_width * $text_scale), 150, -1, -1, default, default, $parent_gui)
	GUISetFont(9 * $text_scale, default, default, "Segoe UI", $dialog)
	local $label = GUICtrlCreateLabel($prompt, 0, 0, 1, 1, $text_alignment, $reading_direction)
	local $input = GUICtrlCreateInput($initial_text, 0, 0, 1, 1)
	local $ok = GUICtrlCreateButton(_T("OK"), 0, 0, 1, 1, $BS_DEFPUSHBUTTON)
	local $cancel = GUICtrlCreateButton(_T("Cancel"), 0, 0, 1, 1)
	LayoutFancyInputBox($dialog, $label, $ok, $cancel, $input)
	GUICtrlSetState($input, $GUI_FOCUS)
	_GUICtrlEdit_SetSel($input, 0, -1)
	GUISetState(@SW_SHOW, $dialog)

	local $entry = ""
	while true
		switch GUIGetMsg()
			case $GUI_EVENT_CLOSE, $cancel
				exitloop
			case $ok
				$entry = GUICtrlRead($input)
				exitloop
		endswitch
	wend

	GUIDelete($dialog)
	AutoItSetOption("GUICoordMode", $coord_mode)
	AutoItSetOption("GUIOnEventMode", $event_mode)
	return $entry
endfunc


; Get version text from URL, with progress reporting, using InetRead()
func CheckVersion($app_name, $check_url, $my_download_url, $my_ini_file, $ini_section, $current_version, $parent_gui=Default, $pause_parent=false)

	#ignorefunc HideWindow, ShowWindow

	; Start with Itstory checking..
	if $itstory_checking == "" and $quiet_operation = $OFF then
		$my_msg = _T("Follow checksum {{itstory}} changes?")
		$full_text = _T("Would you like to be alerted when there are changes to checksum's development itstory?\n\nNOTE: This only happens when checksum runs; there is no 'sentinal' process")
		local $res = MsgBox($MB_YESNO + $MB_ICONWARNING + $MB_DEFBUTTON2 + $MB_TASKMODAL, $my_msg, _L($full_text))
		switch $res
			case $IDYES
				$itstory_checking = 1
			case $IDNO
				$itstory_checking = -1
		endswitch
		IniWrite($ini_path, $app_name, "itstory_checking", $itstory_checking)
	endif
	if $itstory_checking >= 0 and $quiet_operation = $OFF then CheckUpdateLog()

	local $check_interval = IniRead($my_ini_file, $ini_section, "version_checking", "")
	if $check_interval == 0 then return false
	if $check_interval = -1 or $check_interval = "" then
		if $pause_parent then HideWindow($pause_parent)
		$my_msg = _T("Automatic Version Checking?")
		$full_text = _T("can check online for a new version of itself.\nEnter the number of days between checks (0 to disable version checking).")
		local $days_input = StringStripWS(ChecksumTextInput($my_msg, $app_name & " " & StringReplace($full_text, "\n", " "), "", 400, $parent_gui), $STR_STRIP_ENDS)
		if $pause_parent then ShowWindow($pause_parent)
		if $days_input = "" then return false
		IniWrite($my_ini_file, $ini_section, "version_checking", Number($days_input))
		if $days_input = 0 then return false
	endif
	if $check_interval > 365 then $check_interval = 365
	if $check_interval > 0 then
		local $last_checked_date = IniRead($my_ini_file, $ini_section, "version_checked", "2000/01/01 00:00:00")
		local $days_elapsed = _DateDiff("D", $last_checked_date, _NowCalc())
		if $days_elapsed < $check_interval then return false
	endif

	local $title_text = ""
	if $check_interval = 1 then
		$title_text = _T("Version Check (every [interval] day)", "[interval]", $check_interval)
	else
		$title_text = _T("Version Check (every [interval] days)", "[interval]", $check_interval)
	endif
	local $coord_mode = AutoItSetOption("GUICoordMode", 1)
	local $text_scale = ChecksumDialogTextScale()
	local $margin = Ceiling(10 * $text_scale)
	local $progress_width = Ceiling(300 * $text_scale)
	local $progress_gui = GUICreate($title_text, $progress_width, 100, -1, -1, $WS_CAPTION, BitOr($WS_EX_TOOLWINDOW, $WS_EX_TOPMOST))
	GUISetFont(9 * $text_scale, default, default, "Segoe UI", $progress_gui)
	local $status = _T("Checking for new version..")
	local $status_label = GUICtrlCreateLabel($status, $margin, $margin, $progress_width - 2 * $margin, 1, $text_alignment, $reading_direction)
	local $status_height = FitLabelHeight($status_label, $status, $progress_width - 2 * $margin)
	GUICtrlSetPos($status_label, $margin, $margin, $progress_width - 2 * $margin, $status_height)
	local $progress = GUICtrlCreateProgress($margin, $status_height + 2 * $margin, $progress_width - 2 * $margin, $margin)
	local $outer = WinGetPos($progress_gui)
	local $client = WinGetClientSize($progress_gui)
	WinMove($progress_gui, "", $outer[0], $outer[1], $outer[2], $outer[3] - $client[1] + $status_height + 4 * $margin)
	AutoItSetOption("GUICoordMode", $coord_mode)
	GUICtrlSetData($progress, 25)
	GUISetState(@SW_SHOW, $progress_gui)

	$check_url &= "&frequency=" & $check_interval & "&current=" & $current_version
	local $version_response = InetRead($check_url, ($INET_FORCERELOAD + $INET_FORCEBYPASS))
	if @error <> 0 then
		GUIDelete($progress_gui)
		$my_msg = _T("Version Check FAILED!")
		$full_text = _T("Could not determine version online.\nCheck your firewall.")
		MsgBox($MB_ICONERROR, $my_msg, _L($full_text))
		return false
	endif

	$version_response = BinaryToString($version_response)
	GUICtrlSetData($progress, 50)
	IniWrite($my_ini_file, $ini_section, "version_checked", _NowCalc())
	GUICtrlSetData($progress, 75)

	local $compare_result = _VersionCompare($current_version, $version_response)
	switch $compare_result
		case 0, 1
			GUICtrlSetData($progress, 100)
			GUIDelete($progress_gui)
			return false
		case -1
			GUICtrlSetData($progress, 100)
			$my_msg = _T("New Version Available")
			$full_text = _T("A newer version of checksum is available.\nWould you like to visit the download page?")
			local $msg_box_choice = MsgBox($MB_YESNO + $MB_ICONWARNING + $MB_TOPMOST, $my_msg, _L($full_text))
			GUIDelete($progress_gui)
			switch $msg_box_choice
				case $IDYES
					ShellExecute($my_download_url)
			endswitch
			return $version_response
	endswitch

endfunc


; Extracts COM error hex code and description into $error_handler_array globals,
; appends network hint if "connect" in description, sets @error=1
func HandleComError()
	local $err_num = Hex($error_obj.number, 8)
	$com_error_details_array[0] = $err_num
	$com_error_details_array[1] = StringStripWS($error_obj.description, $STR_STRIP_ENDS)
	if StringInStr($com_error_details_array[1], "connect") then $com_error_details_array[1] &= @LF & @LF & "Check your network and firewall settings."
	debug("### COM Error	!  Number: " & $err_num & "	ScriptLine:	" & $error_obj.scriptline & "   Description: " & $com_error_details_array[1], @ScriptLineNumber, 1)
	SetError(1)
	return
endfunc




func InitDebug()
	if $debug_level < 2 then return
	local $uf = "x86"
	if @AutoItX64 = 1 then $uf = "x64"
	debug("", @ScriptLineNumber)
	debug("", @ScriptLineNumber)
	debug("Beginning debug output for checksum v" & $VERSION & " (" & $uf & ")", @ScriptLineNumber)
	debug("", @ScriptLineNumber)
	debug("Date [Y-M-D]: " & @YEAR & "-" & @MON & "-" & @MDAY, @ScriptLineNumber)
	debug("Time [H:M:S]: " & @HOUR & ":" & @MIN & ":" & @SEC, @ScriptLineNumber)
	if $debug_level < 4 then return
	debug("", @ScriptLineNumber)
	debug("RAW Command-Line: " & $CmdLineRaw, @ScriptLineNumber)
	debug("", @ScriptLineNumber)
	local $zl = ""
	if @OSLang then $zl = "[lang: " & @OSLang & "]"
	local $uz = StringReplace(@OSVersion, "_", " ") & " (" & @OSArch & ") " & @OSServicePack & "[" & @OSType & "][build: " & @OSBuild & "]" & $zl & "[cpu:" & StringLower(@CPUArch) & "]"
	debug("Working DIR=>" & @WorkingDir, @ScriptLineNumber)
	if $debug_level < 6 then return
	debug("Computer Name =>" & @ComputerName, @ScriptLineNumber)
	debug("Free Memory =>" & GetFreeMem(), @ScriptLineNumber)
	debug("Operating System =>" & $uz, @ScriptLineNumber)
	debug("SYSTEM PATH=>" & EnvGet("PATH"), @ScriptLineNumber)
	debug("Startup Directory: " & @StartupDir, @ScriptLineNumber)
	debug("Windows Directory: " & @WindowsDir, @ScriptLineNumber)
	debug("System Folder: " & @SystemDir, @ScriptLineNumber)
	debug("Desktop Directory: " & @DesktopDir, @ScriptLineNumber)
	debug("'My documents' Directory: " & @MydocumentsDir, @ScriptLineNumber)
	debug("Program Files Directory: " & @ProgramFilesDir, @ScriptLineNumber)
	debug("Start Menu Directory: " & @StartMenuDir, @ScriptLineNumber)
	debug("Temporary File Directory: " & @TempDir, @ScriptLineNumber)
	debug("Desktop: " & @DesktopWidth & "x" & @DesktopHeight & " " & @DesktopDepth & "bits @ " & @DesktopRefresh & "KHz", @ScriptLineNumber)
	debug("", @ScriptLineNumber)
	debug("", @ScriptLineNumber)
endfunc

func OutputPrefs()
	if $debug_level < 7 then return
	debug("", @ScriptLineNumber)
	debug("BEGIN CHECKSUM PREFS OUTPUT ==>", @ScriptLineNumber)
	debug("", @ScriptLineNumber)
	debug("pause =>" & $pause & "<=", @ScriptLineNumber)
	debug("long_operation =>" & Human($long_operation) & "<=", @ScriptLineNumber)
	debug("readable_times =>" & Human($readable_times) & "<=", @ScriptLineNumber)
	debug("dialog_timeout =>" & $dialog_timeout & "<=", @ScriptLineNumber)
	debug("algorithm =>" & $algorithm & "<=", @ScriptLineNumber)
	debug("uppercase =>" & Human($uppercase) & "<=", @ScriptLineNumber)
	debug("out_dir =>" & $out_dir & "<=", @ScriptLineNumber)
	debug("default_mask =>" & $default_mask & "<=", @ScriptLineNumber)
	debug("unified_extension =>" & Human($unified_extension) & "<=", @ScriptLineNumber)
	debug("always_sync =>" & Human($always_sync) & "<=", @ScriptLineNumber)
	debug("allow_caching =>" & Human($allow_caching) & "<=", @ScriptLineNumber)
	debug("do_timestamp =>" & Human($do_timestamp) & "<=", @ScriptLineNumber)
	debug("file_extensions =>" & Human($file_extensions) & "<=", @ScriptLineNumber)
	debug("individual_hashes =>" & Human($individual_hashes) & "<=", @ScriptLineNumber)
	debug("line_feed =>" & $line_feed & "<=", @ScriptLineNumber)
	debug("ignore_types =>" & $ignore_types & "<=", @ScriptLineNumber)
	debug("ignore_files =>" & $ignore_files & "<=", @ScriptLineNumber)
	debug("ignore_folders =>" & $ignore_folders & "<=", @ScriptLineNumber)
	debug("unix_hashfiles =>" & $unix_hashfiles & "<=", @ScriptLineNumber)
	debug("absolute_paths =>" & Human($absolute_paths) & "<=", @ScriptLineNumber)
	debug("one_hash =>" & Human($one_hash) & "<=", @ScriptLineNumber)
	debug("nix_paths =>" & Human($nix_paths) & "<=", @ScriptLineNumber)
	debug("hide_checksums =>" & Human($hide_checksums) & "<=", @ScriptLineNumber)
	debug("utf8_hashes =>" & Human($utf8_hashes) & "<=", @ScriptLineNumber)
	debug("show_unc_paths =>" & Human($show_unc_paths) & "<=", @ScriptLineNumber)
	debug("always_store_unc =>" & Human($always_store_unc) & "<=", @ScriptLineNumber)
	debug("progress_tip =>" & Human($progress_tip) & "<=", @ScriptLineNumber)
	debug("tip_font =>" & $tip_font & "<=", @ScriptLineNumber)
	debug("tip_font_size =>" & $tip_font_size & "<=", @ScriptLineNumber)
	debug("tip_snap =>" & Human($tip_snap) & "<=", @ScriptLineNumber)
	debug("tip_color =>" & $tip_color & "<=", @ScriptLineNumber)
	debug("tip_text_color =>" & $tip_text_color & "<=", @ScriptLineNumber)
	debug("warn_color =>" & $warn_color & "<=", @ScriptLineNumber)
	debug("tip_stretch =>" & $tip_stretch & "<=", @ScriptLineNumber)
	debug("beep_alerts =>" & Human($beep_alerts) & "<=", @ScriptLineNumber)
	debug("beep_freq =>" & $beep_freq & "<=", @ScriptLineNumber)
	debug("beep_success =>" & $beep_success & "<=", @ScriptLineNumber)
	debug("beep_fail =>" & $beep_fail & "<=", @ScriptLineNumber)
	debug("quiet_operation =>" & Human($quiet_operation) & "<=", @ScriptLineNumber)
	debug("log_to_file =>" & Human($log_to_file) & "<=", @ScriptLineNumber)
	debug("log_everything =>" & Human($log_everything) & "<=", @ScriptLineNumber)
	debug("append_logs =>" & Human($append_logs) & "<=", @ScriptLineNumber)
	debug("log_folder =>" & $log_folder & "<=", @ScriptLineNumber)
	debug("log_name =>" & $log_name & "<=", @ScriptLineNumber)
	debug("status_fail =>" & $status_fail & "<=", @ScriptLineNumber)
	debug("status_success =>" & $status_success & "<=", @ScriptLineNumber)
	debug("log_format =>" & $log_format & "<=", @ScriptLineNumber)
	debug("path_in_titles =>" & Human($path_in_titles) & "<=", @ScriptLineNumber)
	debug("hashfile_paths =>" & $hashfile_paths & "<=", @ScriptLineNumber)
	debug("truncate_at =>" & $truncate_at & "<=", @ScriptLineNumber)
	debug("display_times =>" & $display_times & "<=", @ScriptLineNumber)
	debug("total_times =>" & $total_times & "<=", @ScriptLineNumber)
	debug("open_log_folder =>" & Human($open_log_folder) & "<=", @ScriptLineNumber)
	debug("compress_logs =>" & Human($compress_logs) & "<=", @ScriptLineNumber)
	debug("fallback_styles =>" & $fallback_styles & "<=", @ScriptLineNumber)
	debug("master_styles =>" & $master_styles & "<=", @ScriptLineNumber)
	debug("embed_styles =>" & Human($embed_styles) & "<=", @ScriptLineNumber)
	debug("check_dates =>" & Human($check_dates) & "<=", @ScriptLineNumber)
	debug("report_missing =>" & Human($report_missing) & "<=", @ScriptLineNumber)
	debug("report_changed =>" & Human($report_changed) & "<=", @ScriptLineNumber)
	debug("report_corrupt =>" & Human($report_corrupt) & "<=", @ScriptLineNumber)
	debug("delete_missing_hashes =>" & Human($delete_missing_hashes) & "<=", @ScriptLineNumber)
	debug("update_changed_hashes =>" & Human($update_changed_hashes) & "<=", @ScriptLineNumber)
	debug("fallback_level =>" & $fallback_level & "<=", @ScriptLineNumber)
	debug("fallback_folder =>" & $fallback_folder & "<=", @ScriptLineNumber)
	debug("resync_readonly =>" & Human($resync_readonly) & "<=", @ScriptLineNumber)
	debug("playlist_type =>" & $playlist_type & "<=", @ScriptLineNumber)
	debug("allow_multiple =>" & $allow_multiple & "<=", @ScriptLineNumber)
	debug("apply_options_to_queue =>" & Human($apply_options_to_queue) & "<=", @ScriptLineNumber)
	; debug("cpu_priority =>" & $cpu_priority & "<=", @ScriptLineNumber)
	debug("cpu_priority =>" & StringSplit("Idle/Low|Below Normal|Normal|Above Normal|High|Realtime", "|", 2)[$cpu_priority] & "<=", @ScriptLineNumber)
	debug("help_tips =>" & Human($help_tips) & "<=", @ScriptLineNumber)
	debug("shutdown_when_done =>" & Human($shutdown_when_done) & "<=", @ScriptLineNumber)
	debug("exit_command =>" & $exit_command & "<=", @ScriptLineNumber)
	debug("do_exit_command =>" & Human($do_exit_command) & "<=", @ScriptLineNumber)
	debug("opt_x =>" & $opt_x & "<=", @ScriptLineNumber)
	debug("opt_y =>" & $opt_y & "<=", @ScriptLineNumber)
	debug("do_preamble =>" & Human($do_preamble) & "<=", @ScriptLineNumber)
	debug("show_edit_ini =>" & Human($show_edit_ini) & "<=", @ScriptLineNumber)
	debug("hashfile_name =>" & $hashfile_name & "<=", @ScriptLineNumber)
	debug("nameless_name =>" & $nameless_name & "<=", @ScriptLineNumber)
	debug("relaxed_write_test =>" & Human($relaxed_write_test) & "<=", @ScriptLineNumber)
	debug("beta_channel =>" & Human($beta_channel) & "<=", @ScriptLineNumber)
	debug("debug_level =>" & $debug_level & "<=", @ScriptLineNumber)
	debug("", @ScriptLineNumber)
	debug("", @ScriptLineNumber)
endfunc








#Region ----- START ---------------- COMPILE / WRAPPER DIRECTIVES --------------



; AutoIt Wrapper / Compiler directives..

; for resources included with File___Install()
#pragma compile(Compression, 9)

;::dev::..
; If you want your binary NOW, set this to N
#AutoIt3Wrapper_Run_Au3Stripper=Y

; See the notes above debug() (in cel.au3) for what /rsln does.
; #Au3Stripper_Parameters=/StripOnly /rsln

; Like calling the wrapper with /debug, which we do anyway. This is handy, though ..
#AutoIt3Wrapper_Run_Debug_Mode=Y
#AutoIt3Wrapper_LogFile=%scriptdir%\wrapper.log
#AutoIt3Wrapper_UseX64=Y
#AutoIt3Wrapper_UseUpx=N
#AutoIt3Wrapper_Run_AU3Check=Y
#AutoIt3Wrapper_AU3Check_Parameters=-d -w 1 -w 2 -w 3 -w- 4 -w 5 -w 6 -w 7 -v 1
#AutoIt3Wrapper_AU3Check_Stop_OnWarning=Y
#AutoIt3Wrapper_Run_Stop_OnError=Y
; Main program icon..
; Note: *** MAY NEED FORWARD SLASHES IN RELATIVE PATHS - YMMV ***
#AutoIt3Wrapper_Icon=Resources\checksum.ico
#AutoIt3Wrapper_Res_Icon_Add=Resources\document.ico


; Free-form Res Fields..
#AutoIt3Wrapper_Res_Field=Author|corz.org
#AutoIt3Wrapper_Res_Field=Contact|checksum@corz.org
#AutoIt3Wrapper_Res_Field=Long Description|checksum resurrection build
#AutoIt3Wrapper_Res_Field=Publisher|corz.org
#AutoIt3Wrapper_Res_Field=Web Page|https://corz.org/windows/software/checksum/
#AutoIt3Wrapper_Res_Field=Compiled|%date% %time%

; These now have their own fields..
#AutoIt3Wrapper_Res_ProductName=checksum
#AutoIt3Wrapper_Res_CompanyName=corz.org
#AutoIt3Wrapper_Res_LegalCopyright=corz.org

; Application's resource info..
#AutoIt3Wrapper_Res_Comment=checksum

; This is the one that shows up in Process Explorer..
#AutoIt3Wrapper_Res_Description=file hashing for Windows
#AutoIt3Wrapper_Res_LegalCopyright=corz.org
#AutoIt3Wrapper_Res_ProductVersion=2

; #AutoIt3Wrapper_Res_Field=Build|DEBUG
;#AutoIt3Wrapper_Res_Field=Build|Release
;#AutoIt3Wrapper_Res_Field=Build|Beta Release
; #AutoIt3Wrapper_Res_Field=Build|Special Release
#AutoIt3Wrapper_Res_Field=Build|Resurrection

; I must get a shot of my son's Surface and see if this does anything!
#AutoIt3Wrapper_Res_HiDpi=Y


; Run pre- & post-compile tasks elevated (as admin)..
;
#AutoIt3Wrapper_Run_Before_Admin=Y
#AutoIt3Wrapper_Run_After_Admin=Y


; Tasks to perform BEFORE compilation..
;

; You might want to comment this out (kills any running instance of checksum)..
#AutoIt3Wrapper_Run_Before=taskkill /F /T /IM checksum.exe
; But if you do, copying your new binary over (below) probably won't work.



; Tasks to perform AFTER compilation..
;

; Backup this version of the script (dropped into a backup.zip, below). So I don't have to remember to..
#AutoIt3Wrapper_Run_After=copy "%in%" 									".\%scriptfile% - %fileversion%.au3"


; Handy to keep a backup of the stripped version, too..
#AutoIt3Wrapper_Run_After=move /Y .\%scriptfile%_stripped.au3 			".\%scriptfile% - %fileversion%_stripped.au3"


;::dev::..
; Copy latest binaries to app folders (overwrites existing binary)..
; Your copy of checksum may be somewhere else..
#AutoIt3Wrapper_Run_After=copy /Y "%outx64%" 												"C:\Program Files\corz\checksum\checksum.exe"
; For distro..
#AutoIt3Wrapper_Run_After=copy /Y "%outx64%" 												"..\checksum\Files\checksum\checksum.exe"
#AutoIt3Wrapper_Run_After=copy /Y "..\..\simple_checksum\simple checksum.exe" 				"..\checksum\Files\checksum\simple checksum.exe"
#AutoIt3Wrapper_Run_After=copy /Y "..\..\Setup\Source\Setup.exe" 				"..\checksum\Setup.exe"


#AutoIt3Wrapper_Run_After=C:\UNIX\Python312\python.exe "C:\Users\Dad\Documents\Scripts\Python\stamp-setup-version.py" "%scriptdir%\..\checksum\Files\setup.ini" "%fileversion%" 2>&1
#AutoIt3Wrapper_Run_After=7z.exe a -mx7 -tzip "..\checksum.zip" "..\checksum\"
#AutoIt3Wrapper_Run_After=del /a "..\checksum.hash"
#AutoIt3Wrapper_Run_After=checksum.exe cq-t-h "..\checksum.zip"



; Backup this version of the source files to BackUp.zip..
#AutoIt3Wrapper_Run_After=7z.exe a -mx7 -tzip "..\BackUp\BackUp.zip" ".\%scriptfile% - %fileversion%.au3"
#AutoIt3Wrapper_Run_After=7z.exe a -mx7 -tzip "..\BackUp\BackUp.zip" ".\%scriptfile% - %fileversion%_stripped.au3"



; Note: The 7z and checksum program directories are in my %PATH% (System Properties >> Advanced >> Environment Variables).
; Which is why I don't need to supply the full paths in these commands.


; Finally, remove the (now-zipped) source & output files..
#AutoIt3Wrapper_Run_After=del /f /q ".\%scriptfile% - %fileversion%.au3"
#AutoIt3Wrapper_Run_After=del /f /q ".\%scriptfile% - %fileversion%_stripped.au3"
#AutoIt3Wrapper_Run_After=del /f /q "%outx64%"



; Find end-of-line comments: (?:"[^"]*"|'[^']*')(*SKIP)(*FAIL)|^\h*;.*$(*SKIP)(*FAIL)|\h*;.*$
; Find debug lines:	(?-i)^\h*debug\w*\(.*


; Enable both directives for a GitHub source publish.
;#AutoIt3Wrapper_Run_After_Admin=N
;#AutoIt3Wrapper_Run_After="C:\UNIX\Python312\python.exe" "C:\Users\Dad\Documents\Scripts\publish-autoit-source.py" "%scriptdir%" checksum "%fileversion%"
#endRegion -----  END  --------------- COMPILE / WRAPPER DIRECTIVES ------------

#cs
		Create switches: 1, 2, 3, 5, b, c, d, e, f, g, h, i, j, k, m, p, q, r, s, t, u, y
		Verify switches: a, b, d, f, g, i, l, m, n, o, p, q, r, t, v, w, y

BUGS:

	Checking queue on bad file fail?

TODO:

  APP:
	
	work as CLI-only app, output the hashes in the shell and quit.
	
	If in a queue, post report opens on last item only, BUT queue can be mixed hash/verify, erm.. Just set quiet until done? Hmm.

  PREFS:

	Tip padding Left-Top-Right-Bottom

  SETUP:

	context menus NOT for all files, but only .hash, .md5, .sha1.
	Add .sha2 to checksum's reg entries, for single-click hashing.


TEST::
		OK:		B:\Test\1.hash				B:\Test\Tests\MeC.sha1sum.sha1 			B:\Test\Tests\MeC.md5sum.md5
		hash string too short					B:\Test\INVALID2.hash
		invalid hash string									B:\Test\INVALID.hash
		MISSING FILE													B:\Test\MISSING.hash
		Invalid piped hash string of "a" characters and "**" for a name!				B:\Test\BUG.hash
		Empty file:																B:\Test\Tests\empty-error.md5
		A PNG file:					B:\Test\Tests\badfile.md5
		some bad entries:  										B:\Test\bad.hash
		BAD (file name) characters:					B:\Test\BadFileNameCharacters\BadFileNameCharacters.hash
		Absolute Paths:												>> Absolute Paths >>						B:\Test\AbsolutePaths.hash
		Absolute Paths 2 missing:									>> Absolute Paths 2 MISSING >>								B:\Test\Tests\AbsolutePaths.hash
		custom location:						p(B:\Test\Sugar) "C:\TEMP\Sugar.hash"							-->	hashes in: "B:\Test\Sugar"
		LONG custom location:					p("B:\Test\My Sugar") "C:\TEMP\Sugar.hash"						-->	hashes in: "B:\Test\My Sugar"
		Should be "NOTHING TO DO!"				vamp(B:\Test\Sugar) "C:\TEMP\Sugar.hash"						-->	hashes in: "B:\Test\Sugar" (specifying MD5-only verify)

		Keep checksum busy on this drive and try again on this drive:			"B:\Archive\Books\Books.hash"				v "B:\Archive\Books\Tom Clancy"

		MD5 file with "up" (..\) paths inside:				"C:\TEMP\I Am Your Beast [FitGirl Repack]\MD5\fitgirl-bins.md5"

		NO HASHES CREATED:		crt2him(movies) "M:\[Video]\[TV]\[Classic]\Knight Rider"

		one BAD hash file, some changed files			vr "B:\Test\TestUpgrade"
		one BAD hash file, some changed files			vro "B:\Test\TestUpgrade"			cro "B:\Test\TestUpgrade"			vr "B:\Test\TestUpgrade"

		vr B:\Archive
		cr "B:\Test\TestUpgrade\Mix"
		upgrade B:\[Software]\[AI]\Krea2\LoRA					c4 "B:\Test\1.GB"					v  "B:\Test\1.GB"

																cro B:\					vro B:\Test  			vr "B:\Test\ICON\Windows7\icons\{e1dd0f20-c08a-4979-906d-b3bf03f966b6}"
#ce

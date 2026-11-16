#include-once
#include <WinAPIFiles.au3>

; HashUpgrade.au3	v0.4.7
; A part of checksum, by corz.org
;
; Upgrade obsolete (MD5/SHA1/CRC32) hashes with freshly-computed SHA256 hashes.
; CRC32 entries are verified and upgraded like any other legacy hash.
;
; Activated by command-line switch "upgrade". Explorer context menu additions
; are available to make this easy.
;
;	Verifies each existing hash BEFORE replacement.
;	Only verified hashes are replaced with a fresh SHA256 hash.
;	Failed verifications are skipped and reported as errors.
;	Handles all the usual formats, md5sum, BSD, sfv, piped hash files, etc..
;


global $UPGRADE_ERROR_MSG[9] = [8, _
	"FILE DOES NOT EXIST!", _
	"NOT A FILE!", _
	"CAN'T GET OPEN FILE HANDLE!", _
	"CAN'T GET WRITE FILE HANDLE!", _
	"INVALID HASH FILE!", _
	"VERIFICATION FAILURES!", _
	"MOVE FAILED!", _
	"ALREADY FULLY UPGRADED!"]


; CountHashEntries()
;
; Count the number of actual hash entries inside a given file.
; Returns the number of hashes found.
; The number of SHA256 hashes is returned in @extended
;
func CountHashEntries($file_path)

	local $read_handle = _LFN_FileOpen($file_path, 0)
	if $read_handle = -1 then return -1

	local $hash_count = 0
	local $sha2_hashes = 0
	local $line = ""
	local $line_len = 0

	while true

		$line = _LFN_FileReadLine($read_handle)
		if @error then exitloop

		$line = StringStripWS($line, $STR_STRIP_ENDS)
		$line_len = StringLen($line)
		if $line = "" then continueloop
		if $line_len < $CRC32_HEX_LEN then continueloop

		if StringLeft($line, 1) = "#" then continueloop
		if StringLeft($line, 1) = ";" then continueloop ; SFV comments

		; Match standalone CRC32 (8), MD5 (32), SHA1 (40), SHA256/BLAKE2s (64), or SHA512/BLAKE2b (128) hex strings
		local $hash_match = StringRegExp($line, "(?i)\b([a-f0-9]{8}|[a-f0-9]{32}|[a-f0-9]{40}|[a-f0-9]{64}|[a-f0-9]{128})\b", 1)
		if IsArray($hash_match) then
			$hash_count += 1
			if StringLen($hash_match[0]) = 64 then $sha2_hashes += 1
		endif

	wend

	_LFN_FileClose($read_handle)
	return SetError(0, $sha2_hashes, $hash_count)

endfunc



; DetectLineFormat()
;
; Determines which hash-file format a line belongs to by inspecting structure.
; Returns: 1 = checksum_native (preceded by #comment), 2 = UNIX md5sum,
; 3 = parenthesized BSD/Windows, 4 = piped hash (filename inferred from hash file name),
; 0 = unrecognized / invalid line
;
func DetectLineFormat($line, $prev_line = "")

	local $clean_line = StringStripWS($line, $STR_STRIP_ENDS)
	if $clean_line = "" or StringLeft($clean_line, 1) = "#" then return 0

	; Checksum native is identified by the presence of a preceding comment line.
	if StringLeft($prev_line, 1) = "#" then return 1

	; Tagged/parenthesized formats: "MD5 (file) = ...", "(MD5) file = ..."
	if StringRegExp($clean_line, "(?i)^(?:MD5|SHA1|SHA256|CRC32)\s*\(") or StringRegExp($clean_line, "(?i)^\((?:MD5|SHA1|SHA256|CRC32)\)") then return 3

	; UNIX piped hash (standalone MD5, SHA1, SHA256 or CRC32 hex string)
	local $line_len = StringLen($clean_line)
	if ($line_len = $MD5_HEX_LEN or $line_len = $SHA1_HEX_LEN or $line_len = $SHA2_HEX_LEN or $line_len = $CRC32_HEX_LEN) and StringIsXDigit($clean_line) then
		return 4
	endif

	; UNIX-style (hash followed by space/tab/asterisk and filename)
	if StringRegExp($clean_line, "(?i)^([a-f0-9]{8}|[a-f0-9]{32}|[a-f0-9]{40}|[a-f0-9]{64})[\s\*]") then return 2

	; Classic SFV hash-last ("filename hash") -- upgrades normalize it, so report UNIX-style.
	if StringRegExp($clean_line, "(?i)^.+[\s\*]([a-f0-9]{8}|[a-f0-9]{32}|[a-f0-9]{40}|[a-f0-9]{64})$") then return 2

	return 0
endfunc




; ReconstructHashLine()
;
; Reconstructs a line in its original format with the fresh SHA256 hash.
;
; 	$format_num   : from DetectLineFormat()
; 	$new_hash     : fresh sha256 hex string
; 	$file_name    : resolved file path (relative or absolute as original)
; 	$prev_comment_line : the #comment line for checksum native, "" otherwise
; 	$original_line  : the original hash line (for separator preservation), optional
;
func ReconstructHashLine($format_num, $new_hash, $file_name, $prev_comment_line = "", $original_line = "")

	switch $format_num
		case 1 ; Checksum native -- two lines: comment + hash.
			local $timestamp = @YEAR & "." & @MON & "." & @MDAY & "@" & @HOUR & "." & StringFormat("%02d", @MIN) & ":" & StringFormat("%02d", @SEC)

			; Parse old comment to extract algo name for replacement.
			local $comment_parts = StringSplit($prev_comment_line, "#")
			local $new_comment = "#"
			if IsArray($comment_parts) and $comment_parts[0] >= 4 then
				; Format: #algo#filename#date@time
				$new_comment &= "sha256#" & $comment_parts[3] & "#" & $timestamp
			else
				$new_comment &= "sha256#" & $file_name & "#" & $timestamp
			endif

			return $new_comment & $LF & $new_hash & " *" & $file_name

		case 2 ; UNIX md5sum / sha1sum style -- single line.
			if StringInStr($original_line, "*") then
				; Binary mode: hash *filename
				return $new_hash & " *" & $file_name
			else
				; Text mode: hash  filename (two spaces)
				return $new_hash & "  " & $file_name
			endif

		case 3 ; Parenthesized format -- single line.
			return "(SHA256) " & $file_name & @TAB & $new_hash

		case 4 ; piped hash.
			return $new_hash

		case 5 ; Classic SFV hash-last -- normalize to UNIX hash-first, same as case 2.
			if StringInStr($original_line, "*") then
				return $new_hash & " *" & $file_name
			else
				return $new_hash & "  " & $file_name
			endif

	endswitch

	; Fallback to UNIX-style with *
	return $new_hash & " *" & $file_name
endfunc



; ResolveHashTargetPath()
;
; Resolves the actual file path from a relative filename stored inside a .hash file.
; Mirrors how checksum resolves paths during verification: hash_file_dir + relative_name,
; with UP (..) handling and long-path prefix support.
;
func ResolveHashTargetPath($hash_file_path, $relative_filename)

	; If the filename is already absolute or has \\?\ prefix, return as-is.
	if StringLeft($relative_filename, 4) = "\\?\" then return $relative_filename
	if StringRegExp($relative_filename, "^[A-Za-z]:") then return PrependLongPathPrefix($relative_filename)

	; Get the directory containing the .hash file.
	local $hash_dir = ""
	local $last_backslash = StringInStr($hash_file_path, "\", 0, -1)
	if $last_backslash > 0 then
		$hash_dir = StringLeft($hash_file_path, $last_backslash - 1)
	endif

	; Handle UP directory references (..).
	local $target_path = $hash_dir & "\" & $relative_filename

	; Resolve relative path components (. and ..) to canonical full path before long-path prefixing
	if StringInStr($target_path, "..") or StringInStr($target_path, ".\") then
		local $buf = DllStructCreate("wchar[32768]")
		local $call = DllCall("kernel32.dll", "ulong", "GetFullPathNameW", _
				"wstr", $target_path, _
				"ulong", 32768, _
				"ptr", DllStructGetPtr($buf), _
				"ptr", 0)
		if not @error and $call[0] > 0 then
			$target_path = DllStructGetData($buf, 1)
		endif
	endif

	return PrependLongPathPrefix($target_path)
endfunc




; VerifyExistingHash()
;
; Verifies an existing hash against the file's actual content using the original algorithm.
; Returns true if hashes match, false otherwise.
;
func VerifyExistingHash($target_path, $stored_hash, $algo_id)

	local $clean_path = StringReplace($target_path, Chr(160), "")
	$clean_path = StringRegExpReplace($clean_path, "[\r\n\t]+", "")
	$clean_path = StringStripWS($clean_path, $STR_STRIP_ENDS)

	$clean_path = __LFN_Target_UnSetUnicodePrefix($clean_path)
	debug("VerifyExistingHash() clean_path =>" & $clean_path  & "<=", @ScriptLineNumber, 2)

	local $clean_hash = StringReplace($stored_hash, Chr(160), "")
	$clean_hash = StringStripWS($clean_hash, $STR_STRIPALL)
	debug("VerifyExistingHash() clean_hash =>" & $clean_hash  & "<=", @ScriptLineNumber, 2)

	local $computed = HashFile($clean_path, $algo_id, 0)
	debug("VerifyExistingHash() computed =>" & $computed  & "<=", @ScriptLineNumber, 2)

	if @error or $computed = "" then
		debug("VerifyExistingHash ERROR: HashFile failed (@error=" & @error & ") for: " & $clean_path, @ScriptLineNumber, 2)
		return false
	endif

	local $clean_computed = StringStripWS($computed, $STR_STRIPALL)
	local $is_match = (StringLower($clean_computed) == StringLower($clean_hash))

	if not $is_match then
		debug("VerifyExistingHash MISMATCH: computed=[" & $clean_computed & "] stored=[" & $clean_hash & "] target: " & $clean_path, @ScriptLineNumber, 2)
	endif

	return $is_match
endfunc




;
; UpgradeHashesInFile()

; The main upgrade function. Reads a file line-by-line, verifies each hash;
; replaces verified non-SHA256 entries with a freshly-computed SHA256 hash,
; preserves original line format; checksum native, UNIX md5sum, Windows / BSD
; parenthesized, UNIX piped hashes, etc..
;
; Returns:
;			SUCCESS:	number of hashes upgraded
;			ERROR:		-1
;
func UpgradeHashesInFile($hash_file, $single_file = false)

	if not _LFN_FileExists($hash_file) then return SetError(1, 0, -1)
	debug("UpgradeHashesInFile() file =>" & $hash_file & "<=", @ScriptLineNumber, 2)

	local $attribs = _LFN_FileGetAttrib($hash_file)
	if StringInStr($attribs, "D") then return SetError(2, 0, -1)

	local $total_entries = CountHashEntries($hash_file)
	local $sha256_hashes = @extended

	; INVALID hash file
	if $total_entries = 0 then return SetError(5, 0, -1)

	local $display_path = FormatPathForDisplay($hash_file)
	DoProgressTips(_T("checksum is upgrading hashes in") & ".. " & $display_path)

	local $temp_hash_file = $hash_file & ".tmp.sha2"

	local $skip_lines = 0
	local $is_resuming = false
	local $already_upgraded = $sha256_hashes
	local $processed_entries = 0
	local $total_upgraded_count

	local $orig_attribs = _LFN_FileGetAttrib($hash_file)
	_LFN_FileSetAttrib($hash_file, "-SH")

	local $upgraded_count = 0
	local $skipped_count = 0
	local $missing_files = 0
	local $verify_failures = 0

	; Temp file already exists, we are resuming..
	if _LFN_FileExists($temp_hash_file) then

		local $resume_handle = OpenFileHandle($temp_hash_file, 0 + $utf8_file_mode_flag)

		if not @error and $resume_handle <> -1 then

			local $temp_line, $temp_detected
			$already_upgraded = 0

			while true
				$temp_line = _LFN_FileReadLine($resume_handle)
				if @error = -1 then exitloop
				$skip_lines += 1
				$temp_detected = CheckHashformat($temp_line, $hash_file)	;	returns: [file_name, hash, algo_id]
				if not @error and IsArray($temp_detected) then
					$processed_entries += 1
					if $temp_detected[2] = 3 then
						$already_upgraded += 1
					endif
				endif
			wend

			_LFN_FileClose($resume_handle)
			if $skip_lines > 0 then $is_resuming = true

			debug("UPGRADE:" & $LF & @TAB & "is_resuming: " & $is_resuming & $LF & @TAB & "skip_lines: " & $skip_lines & $LF & @TAB & "already_upgraded: " & $already_upgraded, @ScriptLineNumber, 2)

		else
			debug("******************** RESUME CHECK FAILED to open temp file handle", @ScriptLineNumber, 2)
		endif

	endif

	debug("already_upgraded: =>" & $already_upgraded & "<=" , @ScriptLineNumber, 2);debug
	debug("total_entries: =>" & $total_entries & "<=" , @ScriptLineNumber, 2);debug


	if $already_upgraded >= $total_entries then
		_LFN_FileSetAttrib($hash_file, $orig_attribs)
		return SetError(8, 0, -1) ; "ALREADY FULLY UPGRADED!"
	else
		; Some entries are legacy hashes..
		debug("******************** Upgrading LEGACY Hashes.. ", @ScriptLineNumber, 2)
		local $read_handle = OpenFileHandle($hash_file, 0 + $utf8_file_mode_flag)

		if @error or $read_handle = -1 then
			debug("******************** ERROR: Failed to open read handle for " & $hash_file & " (@error=" & @error & ")", @ScriptLineNumber, 2)
			_LFN_FileSetAttrib($hash_file, $orig_attribs)
			return SetError(3, 0, -1)
		endif

		if $is_resuming then
			local $skipped = 0
			while $skipped < $skip_lines
				_LFN_FileReadLine($read_handle)
				if @error = -1 then exitloop
				$skipped += 1
			wend
		endif

		local $write_mode = $is_resuming ? 1 : 2
		local $write_handle = OpenFileHandle($temp_hash_file, $write_mode + $utf8_file_mode_flag)
		if @error or $write_handle = -1 then
			debug("ERROR: Failed to open write handle for " & $temp_hash_file & " mode=" & $write_mode & " (@error=" & @error & ")", @ScriptLineNumber, 2)
			_LFN_FileClose($read_handle)
			_LFN_FileSetAttrib($hash_file, $orig_attribs)
			return SetError(4, 0, -1)
		endif

		local $prev_line = ""
		local $processed_lines = 0

		local $line, $parts_check, $format_type
		local $hash_info, $file_name, $stored_hash_value, $algo_id
		local $target_path, $new_hash_value, $reconstructed

		; Iterate file line-by-line..
		while true

			$line = _LFN_FileReadLine($read_handle)
			if @error = -1 then exitloop

			$processed_lines += 1

			if StringStripWS($line, $STR_STRIP_ENDS) = "" then
				if $prev_line <> "" then
					_LFN_FileWriteLine($write_handle, $prev_line)
					$prev_line = ""
				endif
				_LFN_FileWriteLine($write_handle, $line)
				continueloop
			endif

			; Comment lines
			if StringLeft($line, 1) = "#" then
				$parts_check = StringSplit($line, "#")
				if IsArray($parts_check) and $parts_check[0] >= 4 then ; TODO: check it contains some algo string
					; Checksum native comment marker: buffer into $prev_line without writing immediately
					if $prev_line <> "" then
						_LFN_FileWriteLine($write_handle, $prev_line)
					endif
					$prev_line = $line
					continueloop
				else
					; Standalone comment line (not metadata)
					if $prev_line <> "" then
						_LFN_FileWriteLine($write_handle, $prev_line)
						$prev_line = ""
					endif
					_LFN_FileWriteLine($write_handle, $line)
					continueloop
				endif
			endif
			
			; Non-comment line
			$hash_info = CheckHashformat($line, $hash_file)
			local $check_err = @error

			if $hash_info[2] > 0 then
				if StringLeft($prev_line, 1) = "#" then
					$format_type = 1
				else
					$format_type = $hash_info[3]
					if $format_type = 0 then $format_type = 2
				endif
			endif

			if $check_err then
				; Unrecognized line format
				if $prev_line <> "" then
					_LFN_FileWriteLine($write_handle, $prev_line)
					$prev_line = ""
				endif
				_LFN_FileWriteLine($write_handle, $line)
				continueloop
			endif
			
			$processed_entries += 1

			$file_name = $hash_info[0]
			$stored_hash_value = $hash_info[1]
			$algo_id = $hash_info[2]

			; Already current, or not upgradeable - leave alone (see IsUpgradeableAlgoID())..
			if not IsUpgradeableAlgoID($algo_id) then
				if $prev_line <> "" then
					_LFN_FileWriteLine($write_handle, $prev_line)
					$prev_line = ""
				endif
				_LFN_FileWriteLine($write_handle, $line)
				$skipped_count += 1
			else
				$target_path = ResolveHashTargetPath($hash_file, $file_name)

				if not _LFN_FileExists($target_path) then
					if $prev_line <> "" then
						_LFN_FileWriteLine($write_handle, $prev_line)
						$prev_line = ""
					endif
					_LFN_FileWriteLine($write_handle, $line)
					$missing_files += 1
					debug("******************** MISSING TARGET FILE: " & $target_path, @ScriptLineNumber, 2)
				else

					if not VerifyExistingHash($target_path, $stored_hash_value, $algo_id) then

						if $prev_line <> "" then
							_LFN_FileWriteLine($write_handle, $prev_line)
							$prev_line = ""
						endif
						_LFN_FileWriteLine($write_handle, $line)
						$verify_failures += 1
						$has_failures = true ; why do we need this?
						debug("******************** VERIFY FAILED for " & $file_name & " (Target: " & $target_path & ")", @ScriptLineNumber, 2)

					else

						$new_hash_value = bcryptHashFile($target_path, "SHA256", 0)

						if @error or $new_hash_value = "" then
							if $prev_line <> "" then
								_LFN_FileWriteLine($write_handle, $prev_line)
								$prev_line = ""
							endif
							_LFN_FileWriteLine($write_handle, $line)
							$missing_files += 1
						else
							if $format_type = 1 then
								$reconstructed = ReconstructHashLine(1, $new_hash_value, $file_name, $prev_line)
								_LFN_FileWriteLine($write_handle, $reconstructed)
							else
								if $prev_line <> "" then
									_LFN_FileWriteLine($write_handle, $prev_line)
								endif
								$reconstructed = ReconstructHashLine($format_type, $new_hash_value, $file_name, "", $line)
								_LFN_FileWriteLine($write_handle, $reconstructed)
							endif
							
							$prev_line = ""
							$upgraded_count += 1
							debug("UPGRADED: " & $file_name, @ScriptLineNumber, 2)
						endif

					endif

				endif

			endif

			if $user_quit then exitloop

		wend

		if $prev_line <> "" then
			_LFN_FileWriteLine($write_handle, $prev_line)
			$prev_line = ""
		endif

		_LFN_FileClose($read_handle)
		_LFN_FileClose($write_handle)

		debug("-------------->File UPGRADE Processed! processed_lines: " & $processed_lines & @TAB & "upgraded_count: " & $upgraded_count, @ScriptLineNumber, 2)

	endif


	$total_upgraded_count = $already_upgraded + $upgraded_count
	debug("File Processed! upgraded_count=" & $upgraded_count, @ScriptLineNumber, 2)
	debug("File Processed! total_upgraded_count=" & $total_upgraded_count, @ScriptLineNumber, 2)

	local $final_target_file = $hash_file
	local $dot_pos = StringInStr($hash_file, ".", 0, -1)
	if $total_upgraded_count > 0 and $dot_pos > 0 then
		local $ext = StringLower(StringMid($hash_file, $dot_pos + 1))
		if $ext = "md5" or $ext = "sha1" or $ext = "sfv" or $ext = "crc" then
			$final_target_file = RemoveExtension($hash_file) & ".sha2"
		endif
	endif

	; "atomic" changes is just switching in the temp file..
	local $move_fail = false

	if $processed_entries == $total_entries and $processed_entries > 0 then ; ALL DONE!

		; Extra redundancy in case shit happens during move..
		local $backup_file = $hash_file & ".bak"
		if not _LFN_FileExists($backup_file) then
			_LFN_FileCopy($hash_file, $backup_file, 1)
			debug("BACKUP CREATED: " & $backup_file, @ScriptLineNumber, 2)
		endif

		if _LFN_FileMove($temp_hash_file, $final_target_file, 1) then
			debug("FILE MOVED OKAY =" & $temp_hash_file & " >> moved to >>" & $final_target_file, @ScriptLineNumber, 2)
			_LFN_FileSetAttrib($final_target_file, $orig_attribs)
			if $final_target_file <> $hash_file then ; .md5, .sha1, etc.. extension has changed.
				_LFN_FileDelete($hash_file)
			endif
		else
			debug("********************  ERROR: MOVE FAILED from " & $temp_hash_file & " >> to >>" & $final_target_file, @ScriptLineNumber, 2)
			if $single_file and $quiet_operation = $OFF then
				MsgBox($MB_TOPMOST + $MB_ICONERROR, _
						_T("checksum hash upgrade error"), _
						_T("Unable to switch in the upgraded hash file.") & @LF & @LF & _
						_T("The computed hashes have been saved to") & ": " & FormatPathForDisplay($temp_hash_file), 30)
			endif
			$upgrade_log &= $hash_file & $LF & @TAB & _T("Failed to switch") & " " & FormatPathForDisplay($temp_hash_file) & " >> to >> " & FormatPathForDisplay($final_target_file) & $LF & _
							_T("Computed {{SHA256}} hashes saved to") & ": " & FormatPathForDisplay($temp_hash_file) & $LF
			$move_fail = true
		endif
		if _LFN_FileExists($backup_file) then _LFN_FileDelete($backup_file)

	endif

	; Restore original attributes on the target file, whatever happens.
	_LFN_FileSetAttrib($hash_file, $orig_attribs)

	; Create log entry for this hash file..
	local $report_str
	local $my_error_log = ""

	$report_str = $LF & FormatPathForDisplay($hash_file) & $LF & $LF & _
					"	" & _T("Upgraded") & ":	" & $upgraded_count & $LF & _
					"	" & _T("Skipped (n/a)") & ":	" & $skipped_count & $LF & _
					"	" & _T("Missing files") & ":	" & $missing_files & $LF & _
					"	" & _T("Verify failures") & ":	" & $verify_failures & $LF & $LF
	debug("report_str =" & $report_str, @ScriptLineNumber, 2)

	if $verify_failures > 0 then
		$my_error_log &= FormatPathForDisplay($hash_file) & $LF & @TAB & _T("Some hashes FAILED verification. (hashes skipped, left unchanged)") & $LF
		$upgrade_log &= $my_error_log
	endif

	if $move_fail then
		$my_msg = _T("Failed to switch [temp_hash] to [target_hash]", "[temp_hash]", FormatPathForDisplay($temp_hash_file), "[target_hash]", FormatPathForDisplay($final_target_file)) 
		; $my_error_log &= FormatPathForDisplay($hash_file) & $LF & @TAB & _T("Failed to switch") & " " & FormatPathForDisplay($temp_hash_file) & " >> to >> " & FormatPathForDisplay($final_target_file) & $LF
		$my_error_log &= _L($my_msg) & $LF
		$upgrade_log &= $my_error_log
	endif

	debug("my_error_log =" & $my_error_log, @ScriptLineNumber, 2)
	if $upgrade_log_all = $ON then $upgrade_log &= $report_str

	if $verify_failures > 0 then return SetError(6, $verify_failures, $upgraded_count)
	if $move_fail then return SetError(7, 0, $upgraded_count)

	return SetError(0, 0, $upgraded_count)

endfunc




;
; HashUpgrade()

; Main wrapper/entry-point for the hash upgrade facility.
; Handles single hash file or recursive directory search.
;
func HashUpgrade($input_path)

	debug("HashUpgrade() => input_path =>" & $input_path & "<=", @ScriptLineNumber, 2)

	; Store file attributes
	local $attribs = _LFN_FileGetAttrib($input_path)

	;
	; Upgrading a SINGLE hash file..

	if not StringInStr($attribs, "D") then

		; upgrade_all_hashes pref set to false and attempting to upgrade legacy (not .hash) file..
		if $upgrade_all_hashes = $OFF and StringLower(StringRight($input_path, 5)) <> ".hash" then
			$upgrade_final_msg = _T("Not a native {{.hash}} file") & ": " & FormatPathForDisplay($input_path) & $LF & " " & _T("Check your {{upgrade_all_hashes}} ini setting")
			return SetError(-1, 0, 0)
		endif

		; It's a recognised hash file extension..
		local $result = UpgradeHashesInFile($input_path, true)
		local $hash_err = @error

		if $hash_err then
			$has_failures = true
			$upgrade_final_msg = FormatPathForDisplay($input_path) & $LF & $LF & $UPGRADE_ERROR_MSG[$hash_err]
		else
			local $was_interrupted_str = ""
			if $user_quit then $was_interrupted_str = " " & _T("(So far, I was interrupted!)")
			$upgrade_final_msg = _T("Finished upgrading") & ": " & $LF & $LF & FormatPathForDisplay($input_path) & $LF & $LF & _T("100% OK!") & $was_interrupted_str
		endif

		debug("hash_err: =>" & $hash_err & "<=" , @ScriptLineNumber, 2);debug
		debug("result: =>" & $result & "<=" , @ScriptLineNumber, 2);debug
		return SetError($hash_err, 0, $result)

	endif

	;
	; Directory processing..

	local $patterns
	if $upgrade_all_hashes = $OFF then
		local $patterns_hash_only[1] = ["*.hash"]
		$patterns = $patterns_hash_only
	else
		local $patterns_all[6] = ["*.hash", "*.md5", "*.sha1", "*.sfv", "*.crc", "*.md5sums"]
		$patterns = $patterns_all
	endif

	local $invalid_hashfiles = 0
	local $already_fully_upgraded = 0
	local $total_upgraded = 0
	local $total_failed = 0

	local $dirs[100]
	$dirs[0] = 1
	$dirs[1] = $input_path

	local $dir_idx = 1
	local $current_dir, $found_items, $item_attribs, $found_files, $res, $base_name


	while $dir_idx <= $dirs[0]

		$current_dir = $dirs[$dir_idx]
		$dir_idx += 1

		; Strip trailing backslash to prevent double-slash path corruption under \\?\
		while StringRight($current_dir, 1) = "\"
			$current_dir = StringTrimRight($current_dir, 1)
		wend

		; Check for each hash extension..
		for $p = 0 to UBound($patterns) - 1

			$found_files = ExpandFileSearchPattern($current_dir & "\" & $patterns[$p])
			debugPrintArray($found_files, "found_files", @ScriptLineNumber)

			if IsArray($found_files) and $found_files[0] > 0 then

				for $i = 1 to $found_files[0]
				
					if $user_quit then exitloop
					$item_attribs = _LFN_FileGetAttrib($found_files[$i])
					if StringInStr($item_attribs, "D") then continueloop

					$res = UpgradeHashesInFile($found_files[$i], false)
					local $my_err = @error
					local $fail_count = @extended
					debug("HashUpgrade()->UpgradeHashesInFile() res: =>" & $res & "<=" , @ScriptLineNumber, 2);debug

					if $res > 0 then $total_upgraded += $res

					if $my_err then
						if $my_err = 5 then $invalid_hashfiles += 1
						if $my_err = 6 then $total_failed += $fail_count
						if $my_err = 8 then $already_fully_upgraded += 1
						continueloop
					endif
				next
			endif

		next

		$found_items = ExpandFileSearchPattern($current_dir & "\*")

		if IsArray($found_items) and $found_items[0] > 0 then
			if $user_quit then exitloop
			for $j = 1 to $found_items[0]
				$base_name = BaseName($found_items[$j])
				if $base_name = "." or $base_name = ".." then continueloop

				$item_attribs = _LFN_FileGetAttrib($found_items[$j])
				if StringInStr($item_attribs, "D") then
					$dirs[0] += 1
					if $dirs[0] >= UBound($dirs) then redim $dirs[$dirs[0] * 2]
					$dirs[$dirs[0]] = $found_items[$j]
				endif
			next
		endif

	    if $user_quit then exitloop

	wend

	$elapsed_time_seconds = Round(TimerDiff($process_start_timer) / 1000, 2)

	; Construct a message for the final dialog..
	$upgrade_final_msg =	_T("Hash Upgrade Summary") & ":" & $LF & $LF & _
							FormatPathForDisplay($input_path) & $LF & $LF & _
							_T("Directories Scanned") & ":" & @TAB & $dirs[0] & $LF & _
							_T("Already Upgraded") & ":" & @TAB & $already_fully_upgraded & $LF & _
							_T("Entries Upgraded") & ":" & @TAB & @TAB & $total_upgraded & $LF & _
							_T("Failed Entries") & ":" & @TAB & @TAB & $total_failed & $LF & _
							_T("Invalid Hash Files") & ":" & @TAB & @TAB & $invalid_hashfiles & $LF

	return SetError(0, 0, $total_upgraded)

endfunc


; That's all folks!

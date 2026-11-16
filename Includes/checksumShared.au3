#include-once

; checksumShared.au3	v0.3.2
; Shared functions for checksum and simple checksum, from corz.org

#include "corzShared.au3"
#include "LFN.au3"
#include "WinCrypto.au3"

global const $MD5_HEX_LEN	= 32
global const $SHA1_HEX_LEN	= 40
global const $SHA2_HEX_LEN	= 64
global const $CRC32_HEX_LEN	= 8

; Our supported algorithms, for whenever the string is required/checked.
; Also used for simple file extensions.
global $hash_algorithms[5] = [4, "md5", "sha1", "sha2", "crc"]

; Algorithm ID. 1 = MD5, 2 = SHA1, 3 = SHA2 (the default), 4 = CRC32.
; ID corresponds to its position in $hash_algorithms array.
global $algorithm_id = 3 

; For bcrypt.dll (CRC32 uses RtlComputeCrc32 instead, see HashFile()).
; Also used for Win/BSD hash file detection.
global const $algorithm_strings[5] = [4, "MD5", "SHA1", "SHA256", "CRC32"] 


; Hash a string with bcrypt.dll..
func HashString($text, $algorithmID = 3, $upper = 0)

	debug("HashString =>" & $text & "<=	Algo ID:" & $algorithmID, @ScriptLineNumber, 6)
	if $algorithmID = 4 then return SetError(10, 0, "*** CRC32 STRINGS NOT SUPPORTED ***")
	local $hash_digest = bcryptHashString($text, $algorithm_strings[$algorithmID], $upper)

	if not @error then
		return SetError(-1, 0, $hash_digest)
	else
		local $err = @error
		local $ext = @extended
		local $error_msg = ""
		switch $err
			case 1
				$error_msg = "*** FAILED TO LOAD BCRYPT.DLL ***"
			case 2, 3, 4, 8, 9
				$error_msg = StringFormat("*** CRYPTO API ERROR (0x%08X) ***", $ext)
			case else
				$error_msg = "*** UNKNOWN ERROR ***"
		endswitch
		return SetError($err, $ext, $error_msg)

	endif

endfunc


; Deletes files matching wildcards recursively
func DeleteFilesRecursive($path)
	if not StringInStr($path, "*") and not StringInStr(StripLongPathPrefix($path), "?") and StringLen($path) < 260 then return FileDelete($path)
	local $dll = __LFN_DllOpen()
	if @error then return SetError(1, 6, 0)
	if not GetPathType($path) then return SetError(1, 7, 0)
	if @extended = 3 then $path &= "\*"
	local $files = ExpandFileSearchPattern($path)
	if $files[0] = 0 then return SetError(1, 8, 0)
	local $i
	local $result
	local $error = false
	for $i = 1 to $files[0]
		if StringRight($files[$i], 1) = "\" then continueloop
		$result = DllCall($dll, "bool", "DeleteFileW", "wstr", $files[$i])
		if $result[0] = 0 or FileExists($files[$i]) then $error = true
	next
	if $error then return SetError(1, 9, 0)
	return 1
endfunc


; Strips \\?\ prefix only if string length < 260; otherwise returns as-is
func StripLongPathPrefixIfShort($my_path)
	if StringLen($my_path) < 260 then $my_path = StripLongPathPrefix($my_path)
	return $my_path
endfunc


; Reads file into a string array
func FileToArray($some_file)
	if IsString($some_file) then $some_file = PrependLongPathPrefix($some_file)
	local $x = FileReadToArray($some_file)
	return SetError(@error, @extended, $x)
endfunc


; Reads/writes/updates key-value pairs in INI files with section-aware logic and auto-creation of missing sections
func IniReadWriteKeyValue($file_path, $section, $key, $value)
	local $val = String($value)
	$val = StringStripWS($val, $STR_STRIP_ENDS)
	if StringLeft($val, 1) = '"' and StringRight($val, 1) = '"' then $val = StringTrimLeft(StringTrimRight($val, 1), 1)
	if not _LFN_FileExists($file_path) then
		_LFN_FileWriteLine($file_path, "[" & $section & "]")
		if @error then return SetError(1, 0, 0)
		_LFN_FileWriteLine($file_path, $key & "=" & $val)
		if @error then return SetError(1, 0, 0)
		return 1
	endif
	local $lines = FileToArray($file_path)
	if @error then return SetError(1, 0, 0)
	local $mode = -1
	local $section_found = false
	local $insert_line = -1
	local $eq_pos = 0
	for $i = 0 to UBound($lines) - 1
		if StringLeft($lines[$i], 1) = "[" then
			if StringLeft($lines[$i], StringLen($section) + 2) = "[" & $section & "]" then
				$section_found = true
			else
				if $section_found then
					$insert_line = $i
					$mode = 1
					exitloop
				endif
			endif
		else
			if $section_found then
				$eq_pos = StringInStr($lines[$i], "=")
				if StringLeft($lines[$i], $eq_pos - 1) = $key then
					$lines[$i] = $key & "=" & $val
					$mode = 0
					exitloop
				else
					if $i = UBound($lines) - 1 then $mode = 3
				endif
			endif
		endif
	next
	if not $section_found then $mode = 2
	local $error = false
	local $file
	switch $mode
		case 0
			$file = OpenFileHandle($file_path, 2)
			for $i = 0 to UBound($lines) - 1
				_LFN_FileWriteLine($file, $lines[$i])
				if @error then
					$error = true
					exitloop
				endif
			next
			_LFN_FileClose($file)
		case 1
			$file = OpenFileHandle($file_path, 2)
			for $i = 0 to UBound($lines) - 1
				if $i = $insert_line then
					_LFN_FileWriteLine($file, $key & "=" & $val)
					if @error then
						$error = true
						exitloop
					endif
				endif
				_LFN_FileWriteLine($file, $lines[$i])
				if @error then
					$error = true
					exitloop
				endif
			next
			_LFN_FileClose($file)
		case 2
			_LFN_FileWriteLine($file_path, "[" & $section & "]")
			if @error then $error = true
			_LFN_FileWriteLine($file_path, $key & "=" & $val)
			if @error then $error = true
		case 3
			_LFN_FileWriteLine($file_path, $key & "=" & $val)
			if @error then $error = true
		case else
			$error = true
	endswitch
	if $error then return SetError(1, 0, 0)
	return 1
endfunc


; Normalizes paths: strips trailing backslash, removes long-path prefixes, 
; extracts root/parent directory portion for relative resolution.
func GetLongParentDir($my_path)
	local $needs_converting = (StringLeft($my_path, 4) = "\\?\" or StringLeft($my_path, 8) = "\\?\UNC\" or StringLen($my_path) > 258)
	if StringRight($my_path, 1) = "\" then $my_path = StringTrimRight($my_path, 1)
	$my_path = StripLongPathPrefix($my_path)
	local $is_standard_root = (not StringInStr($my_path, "\", 2, 1, 3))
	local $is_unc_root = (StringInStr($my_path, "\UNC\") and not StringInStr($my_path, "\", 2, 1, 9))
	if not $is_standard_root and not $is_unc_root then
		$my_path = StringLeft($my_path, StringInStr($my_path, "\", 2, -1) - 1)
	endif
	if $needs_converting then return ConvertToLongPathFormat($my_path)
	return $my_path
endfunc


; Always use plain @LF for Windows dialog boxes..
func SwitchLineFeedsForDialogs($some_string)
	if $LF = @CRLF then
		return StringReplace($some_string, @CRLF, @LF)
	else
		return $some_string
	endif
endfunc


; Converts boolean $ON/$OFF values to string for writing to ini
func IniWriteCheckBox($file, $section, $key, $state, $true_val = "true", $false_val = "false")
	if $state = $ON or $state == true then $state = $true_val
	if $state = $OFF or $state == false then $state = $false_val
	IniReadWriteKeyValue($file, $section, $key, $state)
endfunc


; Sets a pipe-delimited string at array index $index, column $col to value $value; re-joins with "|" via ArrayJoin
func SetArrayElementByIndex(byref $array, $index, $col, $value)
	local $item = $array[$index]
	local $parts = StringSplit($item, "|")
	$parts[$col] = $value
	$array[$index] = ArrayJoin($parts, "|")
endfunc


; A few extra long-filename-capable file system functions for checksum..

; Resolves relative CLI paths ("..\", ".\", bare names) against working directory base, then prepends \\?\ long-path prefix via ConvertToLongPathFormat
func ConvertToCorrectCLIPath($cli_path, $working_dir = @WorkingDir)
	debug("ConvertToCorrectCLIPath() sent_path =>" & $cli_path & "<=", @ScriptLineNumber, 7)
	debug("ConvertToCorrectCLIPath() current_dir =>" & $working_dir & "<=", @ScriptLineNumber, 7)
	if (StringLeft($cli_path, 4) <> "\\?\") then
		if StringLeft($cli_path, 2) <> "\\" and StringMid($cli_path, 2, 1) <> ":" then
			switch true
				case $cli_path = "..\"
					$cli_path = ConvertToLongPathFormat(GetLongParentDir($working_dir))
				case StringInStr($cli_path, "..\")
					while StringInStr($cli_path, "..\")
						$working_dir = GetLongParentDir($working_dir)
						$cli_path = StringReplace($cli_path, "..\", "", 1)
					wend
					$cli_path = ConvertToLongPathFormat($working_dir) & "\" & $cli_path
				case $cli_path = ".\"
					$cli_path = ConvertToLongPathFormat($working_dir)
				case else
					$cli_path = ConvertToLongPathFormat($working_dir & "\" & $cli_path)
			endswitch
		else
			$cli_path = ConvertToLongPathFormat($cli_path)
		endif
	endif
	debug("ConvertToCorrectCLIPath() sent_path =>" & $cli_path & "<=", @ScriptLineNumber, 7)
	debug("ConvertToCorrectCLIPath() working_dir =>" & $working_dir & "<=", @ScriptLineNumber, 7)
	return $cli_path
endfunc


; Normalizes an input CLI path against a given root path: ensures a long-path/UNC prefix,
; strips duplicate root prefixes or leading "./" relative markers, and converts forward
; slashes to backslashes to return a fully-qualified, standardized path.
func MakePathFullAndUNC($path, $rootpath)
	debug("MakePathFullAndUNC() path =>" & $path & "<=", @ScriptLineNumber, 7)
	debug("MakePathFullAndUNC() rootpath =>" & $rootpath & "<=", @ScriptLineNumber, 7)
	if StringRight($rootpath, 1) <> "\" then $rootpath &= "\"
	$path = PrependLongPathPrefix($path)
	local $rel_path = StringReplace($path, $rootpath, "")
	if StringLeft($rel_path, 2) = "./" then $rel_path = StringTrimLeft($rel_path, 2)
	$rel_path = $rootpath & StringReplace($rel_path, "/", "\")
	return $rel_path
endfunc


; Extracts UNC server\share from a path, or returns drive letter for local paths (e.g. "C:" or "\\server\share")
func GetUncServerAndShare($my_path)
	$my_path = StripLongPathPrefix($my_path)
	if StringMid($my_path, 2, 1) = ":" then return StringLeft($my_path, 2)
	$my_path = ($my_path)
	$my_path = StringTrimLeft($my_path, 2)
	$my_path = StringSplit($my_path, "\")
	return "\\" & $my_path[1] & "\" & $my_path[2]
endfunc


; Copies files matching patterns with wildcard support, recursion, attribute preservation, and CreateDirectoryW fallback
func CopyFilesRecursive($src, $dest, $flags = 0)
	if StringRight($src, 1) = "\" then $src &= "*"
	local $idir = false
	CRT($dest)
	if @extended then $idir = true
	if not GetPathType($src) then return SetError(1, 0, 0)
	if @extended = 3 then $src &= "\*"
	if $flags < 32 and not $idir and StringLen($dest) < 260 and not StringInStr($src, "*") _
		and not StringInStr(StripLongPathPrefix($src), "?") and StringLen($src) < 260 then return FileCopy($src, $dest, $flags)
	local $dest_dir = ""
	local $file_name = ""
	local $fixed_name = false
	local $files = ExpandFileSearchPattern($src)
	if @extended = 1 then
		if GetPathType($dest) and @extended = 3 then
			$dest_dir = $dest
		else
			if Bitand($flags, 8) and $idir then
				$dest_dir = $dest
			else
				$dest_dir = GetParentDirectoryWithPrefix($dest)
				$file_name = GetFileNameFromPath($dest)
				$fixed_name = true
			endif
		endif
	else
		$dest_dir = $dest
	endif
	if Bitand($flags, 8) then _LFN_DirCreate($dest_dir)
	if not (GetPathType($dest_dir) and @extended = 3) then return SetError(1, 0, 0)
	local $dll = __LFN_DllOpen()
	if @error then return SetError(1, 0, 0)
	local $error = false
	local $i
	local $dest_file
	for $i = 1 to $files[0]
		if StringRight($files[$i], 1) = "\" then continueloop
		if not $fixed_name then $file_name = GetFileNameFromPath($files[$i])
		$dest_file = $dest_dir & "\" & $file_name
		if CompareFileMetadata($files[$i], $dest_file) then continueloop
		if not IsFileEmpty($files[$i]) then
			$error = true
			continueloop
		endif
		; if Bitand($flags, 64) and StringInStr(GetFileAttributeFlagsString($files[$i]), "E") then
		if Bitand($flags, 64) and StringInStr(_LFN_FileGetAttrib($files[$i]), "X") then
			if not CopyFileByHandle($files[$i], $dest_file) then $error = true
		else
			DllCall($dll, "bool", "CopyFileW", "wstr", $files[$i], "wstr", PrependLongPathPrefix($dest_file), "bool", 0)
			if not CompareFileMetadata($files[$i], $dest_file) then
				if not (Bitand($flags, 32) and CopyFileByHandle($files[$i], $dest_file)) then $error = true
			endif
		endif
	next
	if $error then return SetError(1, 0, 0)
	return 1
endfunc


; Moves files matching wildcards recursively using MoveFileExW API with overwrite flag
func MoveFilesRecursive($src, $dest, $flags = 0)
	if StringRight($src, 1) = "\" then $src &= "*"
	local $idir = false
	CRT($dest)
	; $dest = TrimTrailingBackslashes($dest)
	if @extended then $idir = true
	if not GetPathType($src) then return SetError(1, 0, 0)
	if @extended = 3 then $src &= "\*"
	if $flags < 32 and not $idir and StringLen($dest) < 260 and not StringInStr($src, "*") and _
				not StringInStr(StripLongPathPrefix($src), "?") and StringLen($src) < 260 then return FileMove($src, $dest, $flags)
	local $dest_dir = ""
	local $file_name = ""
	local $fixed_name = false
	local $files = ExpandFileSearchPattern($src)
	if @extended = 1 then
		if GetPathType($dest) then
			$dest_dir = $dest
		else
			$dest_dir = GetParentDirectoryWithPrefix($dest)
			$file_name = GetFileNameFromPath($dest)
			$fixed_name = true
		endif
	else
		$dest_dir = $dest
	endif
	if Bitand($flags, 8) then _LFN_DirCreate($dest_dir)
	if not (GetPathType($dest_dir) and @extended = 3) then return SetError(1, 0, 0)
	local $overwrite = false
	if Bitand($flags, 1) then $overwrite = 1
	local $dll = __LFN_DllOpen()
	if @error then return SetError(1, 0, 0)
	local $error = false
	local $i
	local $dest_file
	local $my_result
	for $i = 1 to $files[0]
		if StringRight($files[$i], 1) = "\" then continueloop
		if not $fixed_name then $file_name = GetFileNameFromPath($files[$i])
		$dest_file = $dest_dir & "\" & $file_name
		if not IsFileEmpty($files[$i]) then
			$error = true
			continueloop
		endif
		$my_result = DllCall($dll, "bool", "MoveFileExW", "wstr", $files[$i], "wstr", PrependLongPathPrefix($dest_file), "dword", 2 + $overwrite)
		if $my_result[0] = 0 or not GetPathType($dest_file) then $error = true
	next
	if $error then return SetError(1, 0, 0)
	return 1
endfunc


; Get drive letter (e.g. "C") or UNC server name from a path
func GetDriveOrServerName($my_path)
	$my_path = StripLongPathPrefix($my_path)
	local $1f = DllCall("shlwapi.dll", "bool", "PathStriptoRootW", "wstr", $my_path)
	if @error or not $1f[0] then return SetError(@error, @extended, "")
	$my_path = $1f[1]
	select
		case StringMid($my_path, 2, 1) == ":"
			return StringLeft($my_path, 1)
		case StringLeft($my_path, 2) == "\\"
			return StringMid($my_path, StringInStr($my_path, "\", 2, 3) + 1)
		case else
			return ""
	endselect
endfunc


; Tests if directory exists and can be opened for search; returns 0=ok, 1=access denied, 2=not found
func TestDirectoryAccessible($my_dir)
	if not _LFN_FileExists($my_dir) then return 2
	local $my_result = 0
	local $search_handle = OpenFileSearchHandle($my_dir & "\*.*")
	if $search_handle = -1 then
		if @error = 1 then
			$my_result = 1
		else
			$my_result = 2
		endif
	endif
	_LFN_FileClose($search_handle)
	return $my_result
endfunc


; Formats seconds into human-readable elapsed time string (e.g. days/hours/minutes)
; Most languages recognise international format seconds.
func FormatHumanTime($my_time = 0)
	if $my_time < 0 then return -1
	select
		case $my_time < 61
			return $my_time & "s" 
		case $my_time < 3601
			return Stringformat("%.01dm %.01ds", Mod(($my_time / 60), 60), Mod($my_time, 60))
		case $my_time < 86401
			return Stringformat("%.01dh %.01dm %.01ds", Mod($my_time / 3600, 24), Int(Mod(($my_time / 60), 60)), Mod($my_time, 60))
		case else
			return Stringformat("%.01dd %.01dh %.01dm %.01ds", Mod($my_time / 86400, 7), Mod($my_time / 3600, 24), Int(Mod(($my_time / 60), 60)), Mod($my_time, 60))
	endselect
endfunc


; Unused functions..

; Creates a temporary file in specified directory with given prefix via GetTempFileNameW, returns full temp path
func CreateTempFileName($my_tmp_dir, $my_contents = "")
	local $1f = DllCall("kernel32.dll", "uint", "GetTempFileNameW", "wstr", $my_tmp_dir, "wstr", $my_contents, "uint", 0, "wstr", "")
	if @error or not $1f[0] then return SetError(@error + 10, @extended, "")
	return $1f[4]
endfunc


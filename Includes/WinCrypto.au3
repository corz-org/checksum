#include-once
#include <Misc.au3>
#include "corzShared.au3"

#cs

	WinCrypto.au3		v0.3.3
	
	Hashing with Windows bcrypt.dll in a fast way, from corz.org.
	A part of checksum and simple checksum.

#ce


#cs

  TEST: File

	An mpty 10GB file, as created by (PowerShell) [System.IO.File]::Create(PATH)
	
	Test Hardware: Ryzen 5600X, 64GB RAM (test file held in RAM).
		
		Algorithm						WinCrypto.au3			checksum hash.dll		Windows cryptutil

		MD4: 		"MD4"				12.43s					-						15.16s				0044f01fdba328c957c0ed00489e770e
		MD5: 		"MD5"				18.57s					15.28s					21.35s				2dd26c4d4799ebd29fa31e48d49e8e53
		SHA-1: 		"SHA1"				14.74s					12.75s					17.59s				a0b6e2ca4e28360a929943e8eb966f703a69dc44
		SHA-256: 	"SHA256"			6.71s					-						9.23s				732377e7f4a2abdc13ddfa1eb4c9c497fd2a2b294674d056cf51581b47dd586d
		SHA-384: 	"SHA384"			18.1s					-						20.19s				440e039ed1fe662a936af419efa9210b1c3d43ae749da5b91f4e77d865b7910ab7949150ae4c52b545e02c41a9a19daf
		SHA-512: 	"SHA512"			18.2s					-						19.93s				0a9ed4396868700784918a83a595845d70e582eb0e625c48ace24f4ee94e705247e210339c5f5a55e597f00d2c3217b0c0797e1bfc617161e00de96eaee2d068
		Blake2s: 	-					-						17.81s										10421fca74fb8037cd060b2e77086e8d909b319747698d3a25cfb8a9c84752b1
	
	Each test performed three times, mean (simple average) time recorded above.
	It is noteworthy that the 2nd fastest algorithm on modern hardware, is MD4.
#ce

; local $timer = TimerInit()
; local $hash_algo = "SHA256"
; ; local $hash = bcryptHashFile("B:\Test\10.GB", $hash_algo, 0)
; local $hash = bcryptHashFile("I:\TEST\1.GB", $hash_algo, 0)
; ConsoleWrite($hash_algo & ": " & $hash & @CRLF)
; ConsoleWrite("Execution Time: " & TimerDiff($timer) / 1000 & " seconds" & @CRLF)


#cs

  TEST: String (SHA256):

		"" (empty string)								e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
		"abc"											ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
		"hello world"									b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9
		"The quick brown fox jumps over the lazy dog"	d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592
#ce

; local $hash_algo = "SHA256"
; ; local $test_string = ""
; ; local $test_string = "abc"
; ; local $test_string = "hello world"
; local $test_string = "The quick brown fox jumps over the lazy dog"
; local $timer = TimerInit()
; local $hash = bcryptHashString($test_string, $hash_algo, $OFF)
; ConsoleWrite($hash_algo & ": " & $hash & @CRLF)
; ConsoleWrite("Execution Time: " & TimerDiff($timer) / 1000 & " seconds" & @CRLF)


; ; CRC32
; local $timer = TimerInit()
; local $hash = crc32HashFile("I:\TEST\1.GB")
; ; local $hash = crc32HashFile("C:\TEMP\I Am Your Beast [FitGirl Repack]\fg-04.bin")
; ConsoleWrite("CRC32: " & $hash & @CRLF)
; ConsoleWrite("Execution Time: " & TimerDiff($timer) / 1000 & " seconds" & @CRLF)


;
; crc32HashFile
;
; Hash a file using native Windows ntdll.dll (RtlComputeCrc32).
;
func crc32HashFile($file_path, $uppercase=$OFF, $allow_caching=$OFF)

	local $flags = 0x20000080 ; FILE_ATTRIBUTE_NORMAL | FILE_FLAG_NO_BUFFERING
	if $allow_caching = $ON then $flags = 0x00000080 ; FILE_ATTRIBUTE_NORMAL

	local $last_err
	local $file_call = DllCall("kernel32.dll", _
			"ptr", "CreateFileW", _
			"wstr", $file_path, _
			"dword", 0x80000000, _	; GENERIC_READ
			"dword", 1, _			; FILE_SHARE_READ
			"ptr", 0, _
			"dword", 3, _			; OPEN_EXISTING
			"dword", $flags, _		; Caching toggle
			"ptr", 0)

	if @error or $file_call[0] = 0 or $file_call[0] = Ptr(-1) then
		local $dll_err = @error
		$last_err = DllCall("kernel32.dll", "dword", "GetLastError")
		local $file_err = $dll_err ? $dll_err : $last_err[0]
		if $dll_err <> 0 then
			$file_err = $dll_err
		else
			$file_err = $last_err[0]
		endif
		return SetError(5, $file_err, "") ; @error 5: File open failed
	endif

	local $file_handle = $file_call[0]
	local $user32 = DllOpen("user32.dll")
	local $chunk_size = 1048576 ; 1 MB, a sector multiple for NO_BUFFERING
	local $buffer_struct = 0
	local $buffer_ptr = 0
	local $use_virtual = false
	if $flags = 0x20000080 then
		; NO_BUFFERING needs a sector-aligned buffer; VirtualAlloc returns page-aligned memory.
		local $alloc = DllCall("kernel32.dll", "ptr", "VirtualAlloc", "ptr", 0, "ulong_ptr", $chunk_size, "dword", 0x3000, "dword", 0x04)
		if not @error and $alloc[0] <> 0 then
			$buffer_ptr = $alloc[0]
			$use_virtual = true
		endif
	endif
	if not $use_virtual then
		$buffer_struct = DllStructCreate("byte[" & $chunk_size & "]")
		$buffer_ptr = DllStructGetPtr($buffer_struct)
	endif
	local $bytes_read_struct = DllStructCreate("dword")
	local $loop_err = 0
	local $loop_ext = 0

	local $crc = 0 ; Initial seed

	while 1

		if $user32 <> -1 and _IsPressed("13", $user32) then ; Pause/Break key
			if MsgBox($MB_YESNO + $MB_ICONWARNING + $MB_TOPMOST, " Abort?", "Abort the hashing operation?") = $IDYES then
				$loop_err = $IDYES ; User aborted
				$loop_ext = 0
				$user_quit = true
				exitloop
			endif
		endif

		local $read = DllCall("kernel32.dll", "bool", "ReadFile", _
				"ptr", $file_handle, _
				"ptr", $buffer_ptr, _
				"dword", $chunk_size, _
				"ptr", DllStructGetPtr($bytes_read_struct), _
				"ptr", 0)

		if @error or not $read[0] then
			local $read_err = @error
			$last_err = DllCall("kernel32.dll", "dword", "GetLastError")
			$loop_err = 7 ; ReadFile failure
			if $read_err <> 0 then
				$loop_ext = $read_err
			else
				$loop_ext = $last_err[0]
			endif
			exitloop
		endif

		local $bytes_read = DllStructGetData($bytes_read_struct, 1)
		if $bytes_read = 0 then exitloop

		local $crc_call = DllCall("ntdll.dll", "ulong", "RtlComputeCrc32", _
				"ulong", $crc, _
				"ptr", $buffer_ptr, _
				"ulong", $bytes_read)

		if @error then
			$loop_err = 8 ; RtlComputeCrc32 failure
			$loop_ext = @error
			exitloop
		endif

		$crc = $crc_call[0]

	wend

	if $user32 <> -1 then DllClose($user32)
	DllCall("kernel32.dll", "bool", "CloseHandle", "ptr", $file_handle)
	if $use_virtual then DllCall("kernel32.dll", "bool", "VirtualFree", "ptr", $buffer_ptr, "ulong_ptr", 0, "dword", 0x8000)

	if $loop_err <> 0 then return SetError($loop_err, $loop_ext, "")

	local $result = Hex($crc, 8)

	if $uppercase == $ON then return $result
	return StringLower($result)

endfunc




;
; bcryptHashFile

; Hash a file using Windows' bcrypt.dll.
; This function seems long but handling *everything* makes for better operation.
;
func bcryptHashFile($file_path, $algorithm="SHA256", $uppercase=$OFF, $allow_caching=$OFF)

	local $bcrypt = DllOpen("bcrypt.dll")
	if $bcrypt = -1 then
		return SetError(1, 0, "") ; @error 1: Failed to open bcrypt.dll
	endif

	local $call = DllCall($bcrypt, _
			"long", "BCryptOpenAlgorithmProvider", _
			"ptr*", 0, _
			"wstr", $algorithm, _
			"ptr", 0, _
			"ulong", 0)
			
	if @error then
		local $dll_err = @error
		DllClose($bcrypt)
		return SetError(2, $dll_err, "") ; @error 2: DllCall failure on BCryptOpenAlgorithmProvider
	endif

	if $call[0] <> 0 then
		local $status = $call[0]
		DllClose($bcrypt)
		return SetError(2, $status, "") ; @error 2: CNG failure on BCryptOpenAlgorithmProvider (@extended = NTSTATUS)
	endif

	local $alg = $call[1]
	local $prop_hash_len = DllStructCreate("wchar[17]")
	DllStructSetData($prop_hash_len, 1, "HashDigestLength")

	local $prop_obj_len = DllStructCreate("wchar[13]")
	DllStructSetData($prop_obj_len, 1, "ObjectLength")

	local $hash_len_struct = DllStructCreate("ulong")
	local $obj_len_struct = DllStructCreate("ulong")
	local $output_bytes_struct = DllStructCreate("ulong")
	local $err_code

	$call = DllCall($bcrypt, _
			"long", "BCryptGetProperty", _
			"ptr", $alg, _
			"ptr", DllStructGetPtr($prop_hash_len), _
			"ptr", DllStructGetPtr($hash_len_struct), _
			"ulong", 4, _
			"ptr", DllStructGetPtr($output_bytes_struct), _
			"ulong", 0)
			
	if @error or $call[0] <> 0 then
		$err_code = @error ? @error : $call[0]
		DllCall($bcrypt, "long", "BCryptCloseAlgorithmProvider", "ptr", $alg, "ulong", 0)
		DllClose($bcrypt)
		return SetError(3, $err_code, "") ; @error 3: Failed to query hash length property
	endif

	$call = DllCall($bcrypt, _
			"long", "BCryptGetProperty", _
			"ptr", $alg, _
			"ptr", DllStructGetPtr($prop_obj_len), _
			"ptr", DllStructGetPtr($obj_len_struct), _
			"ulong", 4, _
			"ptr", DllStructGetPtr($output_bytes_struct), _
			"ulong", 0)
			
	if @error or $call[0] <> 0 then
		$err_code = @error ? @error : $call[0]
		DllCall($bcrypt, _
				"long", "BCryptCloseAlgorithmProvider", _
				"ptr", $alg, _
				"ulong", 0)
		DllClose($bcrypt)
		return SetError(3, $err_code, "") ; @error 3: Failed to query object length property
	endif

	local $hash_len = DllStructGetData($hash_len_struct, 1)
	local $obj_len = DllStructGetData($obj_len_struct, 1)

	local $hash_obj_struct = DllStructCreate("byte[" & $obj_len & "]")
	$call = DllCall($bcrypt, _
				"long", "BCryptCreateHash", _
				"ptr", $alg, _
				"ptr*", 0, _
				"ptr", DllStructGetPtr($hash_obj_struct), _
				"ulong", $obj_len, _
				"ptr", 0, _
				"ulong", 0, _
				"ulong", 0)
				
	if @error or $call[0] <> 0 then
		$err_code = @error ? @error : $call[0]
		DllCall($bcrypt, _
				"long", "BCryptCloseAlgorithmProvider", _
				"ptr", $alg, _
				"ulong", 0)
		DllClose($bcrypt)
		return SetError(4, $err_code, "") ; @error 4: Failed to create hash object
	endif

	local $last_err
	local $hash = $call[2]
	local $file_attr = 0x20000080	; FILE_ATTRIBUTE_NORMAL | FILE_FLAG_NO_BUFFERING <- this will ALWAYS read the file afresh from the device.
	if $allow_caching = $ON then $file_attr = 0x00000080 ; FILE_ATTRIBUTE_NORMAL <-- this will use Windows caching, for testing raw hashing speeds.
	local $file_call = DllCall("kernel32.dll", _
			"ptr", "CreateFileW", _
			"wstr", $file_path, _
			"dword", 0x80000000, _	; GENERIC_READ
			"dword", 1, _			; FILE_SHARE_READ
			"ptr", 0, _
			"dword", 3, _			; OPEN_EXISTING
			"dword", $file_attr, _
			"ptr", 0)

	if @error or $file_call[0] = 0 or $file_call[0] = Ptr(-1) then
		$last_err = DllCall("kernel32.dll", "dword", "GetLastError")
		local $file_err = @error ? @error : $last_err[0]
		DllCall($bcrypt, "long", "BCryptDestroyHash", "ptr", $hash)
		DllCall($bcrypt, "long", "BCryptCloseAlgorithmProvider", "ptr", $alg, "ulong", 0)
		DllClose($bcrypt)
		return SetError(5, $file_err, "") ; @error 5: File open failed (@extended = Win32 error e.g. 2 = File Not Found, 5 = Access Denied)
	endif

	local $file_handle = $file_call[0]
	local $user32 = DllOpen("user32.dll")
	local $chunk_size = 1048576 ; 1 MB, a sector multiple for NO_BUFFERING
	local $buffer_struct = 0
	local $buffer_ptr = 0
	local $use_virtual = false
	if $file_attr = 0x20000080 then
		; NO_BUFFERING needs a sector-aligned buffer; VirtualAlloc returns page-aligned memory.
		local $alloc = DllCall("kernel32.dll", "ptr", "VirtualAlloc", "ptr", 0, "ulong_ptr", $chunk_size, "dword", 0x3000, "dword", 0x04)
		if not @error and $alloc[0] <> 0 then
			$buffer_ptr = $alloc[0]
			$use_virtual = true
		endif
	endif
	if not $use_virtual then
		$buffer_struct = DllStructCreate("byte[" & $chunk_size & "]")
		$buffer_ptr = DllStructGetPtr($buffer_struct)
	endif
	local $bytes_read_struct = DllStructCreate("dword")
	local $loop_err = 0
	local $loop_ext = 0

	while 1

		if $user32 <> -1 and _IsPressed("13", $user32) then ; Pause/Break key
			if MsgBox($MB_YESNO + $MB_ICONWARNING + $MB_TOPMOST, " Abort?", "Abort the hashing operation?") = $IDYES then
				$loop_err = $IDYES ; User aborted
				$loop_ext = 0
				$user_quit = true
				exitloop
			endif
		endif

		local $read = DllCall("kernel32.dll", "bool", "ReadFile", _
				"ptr", $file_handle, _
				"ptr", $buffer_ptr, _
				"dword", $chunk_size, _
				"ptr", DllStructGetPtr($bytes_read_struct), _
				"ptr", 0)

		if @error or not $read[0] then
			$last_err = DllCall("kernel32.dll", "dword", "GetLastError")
			$loop_err = 7 ; ReadFile failure
			$loop_ext = @error ? @error : $last_err[0]
			exitloop
		endif

		local $bytes_read = DllStructGetData($bytes_read_struct, 1)
		if $bytes_read = 0 then exitloop

		$call = DllCall($bcrypt, "long", "BCryptHashData", _
				"ptr", $hash, _
				"ptr", $buffer_ptr, _
				"ulong", $bytes_read, _
				"ulong", 0)

		if @error or $call[0] <> 0 then
			$loop_err = 8 ; BCryptHashData failure
			$loop_ext = @error ? @error : $call[0]
			exitloop
		endif

	wend

	if $user32 <> -1 then DllClose($user32)
	DllCall("kernel32.dll", "bool", "CloseHandle", "ptr", $file_handle)
	if $use_virtual then DllCall("kernel32.dll", "bool", "VirtualFree", "ptr", $buffer_ptr, "ulong_ptr", 0, "dword", 0x8000)

	if $loop_err <> 0 then
		DllCall($bcrypt, "long", "BCryptDestroyHash", "ptr", $hash)
		DllCall($bcrypt, "long", "BCryptCloseAlgorithmProvider", "ptr", $alg, "ulong", 0)
		DllClose($bcrypt)
		return SetError($loop_err, $loop_ext, "")
	endif

	local $hash_buffer = DllStructCreate("byte[" & $hash_len & "]")
	$call = DllCall($bcrypt, _
			"long", "BCryptFinishHash", _
			"ptr", $hash, _
			"ptr", DllStructGetPtr($hash_buffer), _
			"ulong", $hash_len, _
			"ulong", 0)
			
	if @error or $call[0] <> 0 then
		local $finish_err = @error ? @error : $call[0]
		DllCall($bcrypt, "long", "BCryptDestroyHash", "ptr", $hash)
		DllCall($bcrypt, "long", "BCryptCloseAlgorithmProvider", "ptr", $alg, "ulong", 0)
		DllClose($bcrypt)
		return SetError(9, $finish_err, "") ; @error 9: BCryptFinishHash failure
	endif

	local $result = Hex(DllStructGetData($hash_buffer, 1))

	DllCall($bcrypt, "long", "BCryptDestroyHash", "ptr", $hash)
	DllCall($bcrypt, "long", "BCryptCloseAlgorithmProvider", "ptr", $alg, "ulong", 0)
	DllClose($bcrypt)

	if $uppercase == $ON then return $result
	return StringLower($result)

endfunc


;
; bcryptHashString

; Hash a string using Windows' bcrypt.dll.
;
func bcryptHashString($string, $algo="SHA256", $uppercase=$OFF)

	local $bcrypt = DllOpen("bcrypt.dll")
	if $bcrypt = -1 then return SetError(1, 0, "")

	local $call = DllCall($bcrypt, _
			"long", "BCryptOpenAlgorithmProvider", _
			"ptr*", 0, _
			"wstr", $algo, _
			"ptr", 0, _
			"ulong", 0)

	if @error then
		local $dll_err = @error
		DllClose($bcrypt)
		return SetError(2, $dll_err, "")
	endif
	if $call[0] <> 0 then
		local $status = $call[0]
		DllClose($bcrypt)
		return SetError(2, $status, "")
	endif

	local $provider = $call[1]
	local $obj_len_struct = DllStructCreate("ulong")
	local $cb_res_struct = DllStructCreate("ulong")
	local $err_code

	$call = DllCall($bcrypt, _
			"long", "BCryptGetProperty", _
			"ptr", $provider, _
			"wstr", "ObjectLength", _
			"ptr", DllStructGetPtr($obj_len_struct), _
			"ulong", 4, _
			"ptr", DllStructGetPtr($cb_res_struct), _
			"ulong", 0)

	if @error or $call[0] <> 0 then
		$err_code = @error ? @error : $call[0]
		DllCall($bcrypt, "long", "BCryptCloseAlgorithmProvider", "ptr", $provider, "ulong", 0)
		DllClose($bcrypt)
		return SetError(3, $err_code, "") ;
	endif

	local $obj_len = DllStructGetData($obj_len_struct, 1)
	local $hash_len_struct = DllStructCreate("ulong")

	$call = DllCall($bcrypt, _
			"long", "BCryptGetProperty", _
			"ptr", $provider, _
			"wstr", "HashDigestLength", _
			"ptr", DllStructGetPtr($hash_len_struct), _
			"ulong", 4, _
			"ptr", DllStructGetPtr($cb_res_struct), _
			"ulong", 0)

	if @error or $call[0] <> 0 then
		DllCall($bcrypt, "long", "BCryptCloseAlgorithmProvider", "ptr", $provider, "ulong", 0)
		DllClose($bcrypt)
		return SetError(3, 0, "")
	endif

	local $hash_len = DllStructGetData($hash_len_struct, 1)
	local $hash_obj_struct = DllStructCreate("byte[" & $obj_len & "]")
	
	$call = DllCall($bcrypt, _
			"long", "BCryptCreateHash", _
			"ptr", $provider, _
			"ptr*", 0, _
			"ptr", DllStructGetPtr($hash_obj_struct), _
			"ulong", $obj_len, _
			"ptr", 0, _
			"ulong", 0, _
			"ulong", 0)
			
	if @error or $call[0] <> 0 then
		DllCall($bcrypt, "long", "BCryptCloseAlgorithmProvider", "ptr", $provider, "ulong", 0)
		DllClose($bcrypt)
		return SetError(4, 0, "")
	endif

	local $hash_handle = $call[2]
	local $data_binary = StringToBinary($string, 4)
	local $data_len = BinaryLen($data_binary)
	local $data_struct = DllStructCreate("byte[" & ($data_len > 0 ? $data_len : 1) & "]")
	if $data_len > 0 then DllStructSetData($data_struct, 1, $data_binary)

	$call = DllCall($bcrypt, _
			"long", "BCryptHashData", _
			"ptr", $hash_handle, _
			"ptr", DllStructGetPtr($data_struct), _
			"ulong", $data_len, _
			"ulong", 0)
			
	if @error or $call[0] <> 0 then
		DllCall($bcrypt, "long", "BCryptDestroyHash", "ptr", $hash_handle)
		DllCall($bcrypt, "long", "BCryptCloseAlgorithmProvider", "ptr", $provider, "ulong", 0)
		DllClose($bcrypt)
		return SetError(5, 0, "")
	endif

	local $hash_buf_struct = DllStructCreate("byte[" & $hash_len & "]")
	
	$call = DllCall($bcrypt, _
			"long", "BCryptFinishHash", _
			"ptr", $hash_handle, _
			"ptr", DllStructGetPtr($hash_buf_struct), _
			"ulong", $hash_len, _
			"ulong", 0)
			
	DllCall($bcrypt, "long", "BCryptDestroyHash", "ptr", $hash_handle)
	DllCall($bcrypt, "long", "BCryptCloseAlgorithmProvider", "ptr", $provider, "ulong", 0)

	DllClose($bcrypt)
	if @error or $call[0] <> 0 then return SetError(6, 0, "")

	local $result = StringTrimLeft(String(DllStructGetData($hash_buf_struct, 1)), 2)
	
	if $uppercase == $ON then return $result
	return StringLower($result)

endfunc

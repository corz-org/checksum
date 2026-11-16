#include-once
#cs
	CipherSaber and Other Handy Cryptographic Functions		v0.2.2

	These could all be done in DLLs, but as using DLL calls for CipherSaber defeats
	one of the main purposes of CipherSaber (Sheesh!), I thought it might be fun to
	also include pure AutoIt versions of the Ancillary functions, _Base64Encode()
	and such, rather than use the regular (faster) DLL versions. Have fun, but don't
	try it on any HUGE files!

	; a wee demo..
	#include "corzCrypto.au3"

	; decrypt a file..
	$key = "MyKeyString"
	$encrypted = FileRead("C:\path\to\encrypted.file")
	FileWrite("C:\path\to\decrypted.file", CSbinDecrypt($encrypted, $key))

	; basic variable encrpyt/decrpyt test:
	$String = "Secret**FE*K**String"
	$key = "me@myplace.org"

	; Binary..
	ConsoleWrite("BINARY: " & "->" & @LF)
	$encrypted = CSbinEncrypt($String, $key)
	ConsoleWrite("encrypted: " & "->" & BinaryToString(StringStripWS($encrypted, 8)) & @LF)
	$decrypted = CSbinDecrypt($encrypted, $key)
	ConsoleWrite("decrypted: " & "->" & $decrypted & "<-" & @LF)

	; Base64..
	ConsoleWrite(@LF)
	ConsoleWrite("Base64: " & "->" & @LF)
	$encrypted = CSEncrypt($String, $key)
	ConsoleWrite("encrypted: " & "->" & $encrypted & @LF)
	$decrypted = CSDecrypt($encrypted, $key)
	ConsoleWrite(@LF)
	ConsoleWrite("decrypted: " & "->" & $decrypted & "<-" & @LF)
#ce


; CipherSaber stream-cipher
; Designed by Arnold Reinhold
;
; CipherSaber (1 and 2) encryption and decryption with base64 encoding
; For more info on CS algorithm go to http://ciphersaber.gurus.org/
; Based on Emilis Dambauskas' PHP script: http://www.phpclasses.org/browse/file/3689.html
; Which was based on Ian Gulliver's perl script: http://www.xs4all.nl/~cg/ciphersaber/ (DEAD)
;
; Pure AutoIt version @ corz.org 2012 - Open Source
;

; base64 encrypt.. $wordwrap adds a @CRLF every 76 chars; pass false for
; single-line values like ini secrets. Defaults to true, as before.
func CSEncrypt($str, $key, $csl=20, $wordwrap='')
	if IsString($wordwrap) and $wordwrap == "" then $wordwrap = true
	local $r_num = StringMid(MakeRandomXString(), 1, 10)
	return _Base64Encode($r_num & AICipherSaber($str, $key, $r_num, $csl), $wordwrap)
endfunc

;  base64 decrypt..
func CSDecrypt($str, $key, $csl=20)
	$str = BinaryToString(_Base64Decode($str))
	local $r_num = StringMid($str, 1, 10)
	$str = StringMid($str, 11)
	return AICipherSaber($str, $key, $r_num, $csl)
endfunc


; binary encrypt..
func CSbinEncrypt($str, $key, $csl=20)
	local $r_num = StringMid(MakeRandomXString(), 1, 10)
	return $r_num & AICipherSaber($str, $key, $r_num, $csl)
endfunc

; binary decrypt..
func CSbinDecrypt($str, $key, $csl=20)
	$str = BinaryToString($str)
	local $r_num = StringMid($str, 1, 10)
	$str = StringMid($str, 11)
	return AICipherSaber($str, $key, $r_num, $csl)
endfunc


; CipherSaber Algorithm..
func AICipherSaber($d, $p, $rnum, $csl=20)

	$p &= $rnum
	local $S[256]

	for $i = 0 to 255
		$S[$i] = $i
	next

	local $j = 0, $t = StringLen($p)
	local $kkk[256]

	for $i = 0 to 255
		$kkk[$i] = Asc(StringMid($p, $j+1, 1))
		$j = Mod(($j + 1), $t)
	next

	$j = 0
	for $kk = 0 to $csl-1 ; CS2 loops
		for $i = 0 to 255
			$j = BitAND(($j + $S[$i] + $kkk[$i]),  0xff)
			$t = $S[$i]
			$S[$i] = $S[$j]
			$S[$j] = $t
		next
	next
	$i = 0
	$j = 0
	local $ii = 0
	local $ret = ''
	local $dlen = StringLen($d)

	for $ii = 0 to $dlen-1
		local $c = StringMid($d, $ii+1, 1)
		$i = BitAND(($i + 1), 0xff)
		$j = BitAND(($j + $S[$i]), 0xff)
		$t = $S[$i]
		$S[$i] = $S[$j]
		$S[$j] = $t
		$t = BitAND(($S[$i] + $S[$j]), 0xff)
		$ret &= Chr(BitXOR($S[$t], Asc($c)))
	next
	return $ret
endfunc


func MakeRandomXString($length=32, $seed=@Min*@Sec*@MSec)
	SRandom($seed)
	local $a[$length]
	local $x = 0
	while $a[$length-1] = ""
		local $tmp = Chr(Random(48, 71, 1)) ; CAPITALS
		if StringIsXDigit($tmp) then
			$a[$x] = Asc($tmp)
			$x += 1
		endif
	wend
	$a = StringFromASCIIArray($a)
	; debug("MakeRandomXString() returning: =>" & $a & "<=", @ScriptLineNumber, 7);debug
	return $a
endfunc





; Ancillary functions..
;




; _Base64Encode() setup section..
;

#Region Build look-up tables
;The Base64 alphabet, in an array which can be used as a 6-bit lookup table
Global Const $gcac_Base64Alphabet[64] = [ _
		'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', _
		'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f', _
		'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', _
		'w', 'x', 'y', 'z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '+', '/']

;reverse look-up table to convert an ascii value to a 6-bit value
Global Const $gcai_Base64Reverse[256] = [ _
		 - 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, _
		 - 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 62, -1, -1, -1, 63, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -1, -1, -1, -1, -1, -1, _
		 - 1, 00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -1, -1, -1, -1, -1, _
		 - 1, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, -1, -1, -1, -1, -1, _
		 - 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, _
		 - 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, _
		 - 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, _
		 - 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]

;A 12-bit to 16-bit lookup table for encoding to base64
Global Const $gcas_Base64Table12 = _Base64Table12()

;a 14-bit to 12-bit reverse lookup (basically a truncated 16-bit to 12-bit table, uses 7+7 instead of 8+8)
Global Const $gcai_Base64Table14 = _Base64Table14()

;Build a 12-bit to 16-bit lookup table
Func _Base64Table12()
	local $a_Out[4096], $i_Count1, $i_Count2
	For $i_Count1 = 0 To 63
		For $i_Count2 = 0 To 63
			$a_Out[$i_Count1 * 64 + $i_Count2] = $gcac_Base64Alphabet[$i_Count1] & $gcac_Base64Alphabet[$i_Count2]
		Next
	Next
	Return $a_Out
EndFunc   ;==>_Base64Table12

;a 14-bit to 12-bit reverse lookup (basically a truncated "16-bit to 12-bit" table, uses 7+7 instead of 8+8)
;note: 12-bit values have been shifted to easier fit into the Big Edian style of the BinaryString() function
;The table has 2 columns.  The columns represent the 4-bit groups as 00C0AB and EF0D00 respectively
Func _Base64Table14()
	local $a_Out[16384][2], $i_Count1, $i_Count2, $i_Temp1, $i_Temp2
	For $i_Count1 = 0 To 63
		For $i_Count2 = 0 To 63
			$i_Temp1 = Asc($gcac_Base64Alphabet[$i_Count1]) * 128 + Asc($gcac_Base64Alphabet[$i_Count2])
			$i_Temp2 = $i_Count1 * 64 + $i_Count2
			$a_Out[$i_Temp1][0] = BitShift($i_Temp2, 4) + BitAND($i_Temp2, 15) * 4096
			$a_Out[$i_Temp1][1] = BitAND($i_Temp2, 255) * 65536 + BitAND($i_Temp2, 3840)
		Next
	Next
	Return $a_Out
EndFunc   ;==>_Base64Table14
#endregion


;===============================================================================
;
; Description:		Convert String to Base64
; Syntax:			_Base64Encode($s_Input, $b_WordWrap)
; Parameter(s):
;	$s_Input 			- String to convert to a Base64 String
;	$b_WordWrap 		- Add a @CRLF to the output every 76 Char. Default = True
;
; Requirement(s):	v3.2.4.0
;
; Return Value:		A Base64 encoded version of that string
;
; Authors:			Original functions  					- blindwig
;					Edit for UDF and Clean/Speedup Code		- Mikeytown2
;					Code Speedup/Standards					- blindwig
; Note(s):
;					To encode a binary file, adapt this codeblock to your program
;					$file = "binaryfile.dat"
;					_Base64Encode (BinaryToString(FileRead(FileOpen($file, 16), FileGetSize($file))))
;
;					Autoit will most likely crash if input is large (24+ MB)
;
;===============================================================================
Func _Base64Encode($s_Input, $b_WordWrap='')
	Local $i_Count, $i_Count2, $s_Out = '', $i_Temp

	if IsString($b_WordWrap) and $b_WordWrap == "" then $b_WordWrap = true

	;Break the input up into bytes
	Local $as_Input = StringSplit($s_Input, '')


	If $b_WordWrap Then ;use LineWrap only
		;Handle data in a 57-byte chunck (which will be coded to a 76-byte line)
		For $i_Count2 = 1 To $as_Input[0] - Mod($as_Input[0], 57) Step 57
			For $i_Count = $i_Count2 To $i_Count2 + 54 Step 3
				$i_Temp = Asc($as_Input[$i_Count + 1])
				$s_Out &= $gcas_Base64Table12[Asc($as_Input[$i_Count + 0]) * 16 + BitShift($i_Temp, 4) ] _
						 & $gcas_Base64Table12[BitAND($i_Temp, 15) * 256 + Asc($as_Input[$i_Count + 2]) ]
			Next
			$s_Out &= @CRLF
		Next
		;Handle any left-over bytes (a final chunk less than 57 bytes but at least 3)
		For $i_Count = $i_Count2 To $as_Input[0] - Mod($as_Input[0], 3) Step 3
			$i_Temp = Asc($as_Input[$i_Count + 1])
			$s_Out &= $gcas_Base64Table12[Asc($as_Input[$i_Count + 0]) * 16 + BitShift($i_Temp, 4) ] _
					 & $gcas_Base64Table12[BitAND($i_Temp, 15) * 256 + Asc($as_Input[$i_Count + 2]) ]
		Next
	Else ; no LineWrap
		For $i_Count = 1 To $as_Input[0] - Mod($as_Input[0], 3) Step 3
			$i_Temp = Asc($as_Input[$i_Count + 1])
			$s_Out &= $gcas_Base64Table12[Asc($as_Input[$i_Count + 0]) * 16 + BitShift($i_Temp, 4) ] _
					 & $gcas_Base64Table12[BitAND($i_Temp, 15) * 256 + Asc($as_Input[$i_Count + 2]) ]
		Next
	EndIf


	;Handle any left-over bytes (a final chunk less than 3 bytes)
	Switch Mod($as_Input[0], 3)
		Case 1
			$s_Out &= $gcac_Base64Alphabet[BitShift(Asc($as_Input[$as_Input[0]]), 2) ] _
					 & $gcac_Base64Alphabet[BitAND(Asc($as_Input[$as_Input[0]]), 3) * 16 ] & '=='
		Case 2
			$s_Out &= $gcac_Base64Alphabet[BitShift(Asc($as_Input[$as_Input[0] - 1]), 2) ] _
					 & $gcac_Base64Alphabet[BitAND(Asc($as_Input[$as_Input[0] - 1]), 3) * 16 + BitShift(Asc($as_Input[$as_Input[0]]), 4) ] _
					 & $gcac_Base64Alphabet[BitAND(Asc($as_Input[$as_Input[0]]), 15) * 4 ] & '='
	EndSwitch

	;Final line-wrap
	If $b_WordWrap And Mod($i_Count + 1, 19) = 0 Then $s_Out &= @CRLF

	;DONE!
	Return $s_Out
EndFunc

;===============================================================================
;
; Description:		Decodes a given base64 string
; Syntax:			_Base64Decode($as_CypherText)
; Parameter(s):
;	$as_CypherText		- Base64 String
;
; Requirement(s):	v3.2.4.0
;
; Return Value(s):	On Success - Returns decoded Base64 string
;
; Authors:			Original functions  					- blindwig
;					Edit for UDF and Clean/Speedup Code		- Mikeytown2
;					Code Speedup/Standards					- blindwig
; Note(s):
;					will always strip all @CRLF, @CR, @LF characters before processing and any non Base64 characters
;
;					Will most likely crash if input is large (32+ MB)
;
;===============================================================================
Func _Base64Decode($s_CypherText)
	; Local $i_Count = 0, $i_Count2, $s_Out = '', $i_CypMod, $i_Temp
	Local $i_Count = 0, $s_Out = '', $i_CypMod, $i_Temp

	;first filter EOL characters
	$s_CypherText = StringReplace(StringStripCR($s_CypherText), @LF, '')
	;check for non-base64 characters, filter if needed
	If StringRegExp($s_CypherText, '[^0-9a-zA-Z/+=]', 0) Then
		$s_CypherText = StringRegExpReplace($s_CypherText, '[^0-9a-zA-Z/+=]', '')
	EndIf

	;Break the input up into bytes
	local $as_CypherText = StringSplit($s_CypherText, '')

	;Pad the input to a multiple of four characters
	$i_CypMod = Mod($as_CypherText[0], 4)
	If $i_CypMod Then
		ReDim $as_CypherText[$as_CypherText[0] + 5 - $i_CypMod]
		For $i_Count = $as_CypherText[0] + 1 To UBound($as_CypherText) - 1
			$as_CypherText[$i_Count] = '='
		Next
		$as_CypherText[0] = UBound($as_CypherText) - 1
	EndIf

	For $i_Count = 1 To $as_CypherText[0] - 4 Step + 4
		$i_Temp = $gcai_Base64Table14[Asc($as_CypherText[$i_Count + 0]) * 128 + Asc($as_CypherText[$i_Count + 1]) ][0] _
				 + $gcai_Base64Table14[Asc($as_CypherText[$i_Count + 2]) * 128 + Asc($as_CypherText[$i_Count + 3]) ][1]
		$s_Out &= StringLeft(BinaryToString($i_Temp), 3)
	Next

	;last run - left over bytes (4 or less, if any)
	If $as_CypherText[0] Then ;make sure there is some input (not zero).
		If $as_CypherText[0] > $i_Count Then
			Local $ai_Bytes[4]

			$ai_Bytes[0] = $gcai_Base64Reverse[Asc($as_CypherText[$i_Count + 0]) ]
			$ai_Bytes[1] = $gcai_Base64Reverse[Asc($as_CypherText[$i_Count + 1]) ]
			$ai_Bytes[2] = $gcai_Base64Reverse[Asc($as_CypherText[$i_Count + 2]) ]
			$ai_Bytes[3] = $gcai_Base64Reverse[Asc($as_CypherText[$i_Count + 3]) ]

			Select
				Case $ai_Bytes[0] = -1;File ended on a perfect octet
				Case $ai_Bytes[1] = -1;This should never happen
					SetError(-1)
				Case $ai_Bytes[2] = -1;Only the first 2 bytes to be considered
					$s_Out &= Chr($ai_Bytes[0] * 4 + BitShift($ai_Bytes[1], 4))
				Case $ai_Bytes[3] = -1;Only the first 3 bytes to be considered
					$s_Out &= Chr($ai_Bytes[0] * 4 + BitShift($ai_Bytes[1], 4)) _
							 & Chr(BitAND($ai_Bytes[1] * 16 + BitShift($ai_Bytes[2], 2), 255))
				Case Else;All 4 bytes to be considered
					$s_Out &= Chr($ai_Bytes[0] * 4 + BitShift($ai_Bytes[1], 4)) _
							 & Chr(BitAND($ai_Bytes[1] * 16 + BitShift($ai_Bytes[2], 2), 255)) _
							 & Chr(BitAND($ai_Bytes[2] * 64 + $ai_Bytes[3], 255))
			EndSelect
		EndIf
	EndIf

	;DONE!
	Return $s_Out
EndFunc


;===============================================================================
;
; Function Name:    _StringEncrypt()
; Description:      RC4 Based string encryption
; Parameter(s):     $i_Encrypt - 1 to encrypt, 0 to decrypt
;                   $s_EncryptText - string to encrypt
;                   $s_EncryptPassword - string to use as an encryption password
;                   $i_EncryptLevel - integer to use as number of times to encrypt string
; Requirement(s):   None
; Return Value(s):  On Success - Returns the string encrypted (blank) times with (blank) password
;                   On Failure - Returns a blank string and sets @error = 1
; Author(s):        Wes Wolfe-Wolvereness <Weswolf at aol dot com>
;
;===============================================================================
;
Func _StringEncrypt($i_Encrypt, $s_EncryptText, $s_EncryptPassword, $i_EncryptLevel = 1)
	If $i_Encrypt <> 0 And $i_Encrypt <> 1 Then
		SetError(1)
		Return ''
	ElseIf $s_EncryptText = '' Or $s_EncryptPassword = '' Then
		SetError(1)
		Return ''
	Else
		If Number($i_EncryptLevel) <= 0 Or Int($i_EncryptLevel) <> $i_EncryptLevel Then $i_EncryptLevel = 1
		Local $v_EncryptModified
		Local $i_EncryptCountH
		Local $i_EncryptCountG
		Local $v_EncryptSwap
		Local $av_EncryptBox[256][2]
		Local $i_EncryptCountA
		Local $i_EncryptCountB
		Local $i_EncryptCountC
		Local $i_EncryptCountD
		Local $i_EncryptCountE
		Local $v_EncryptCipher
		Local $v_EncryptCipherBy
		If $i_Encrypt = 1 Then
			For $i_EncryptCountF = 0 To $i_EncryptLevel Step 1
				$i_EncryptCountG = ''
				$i_EncryptCountH = ''
				$v_EncryptModified = ''
				For $i_EncryptCountG = 1 To StringLen($s_EncryptText)
					If $i_EncryptCountH = StringLen($s_EncryptPassword) Then
						$i_EncryptCountH = 1
					Else
						$i_EncryptCountH += 1
					EndIf
					$v_EncryptModified = $v_EncryptModified & Chr(BitXOR(Asc(StringMid($s_EncryptText, $i_EncryptCountG, 1)), Asc(StringMid($s_EncryptPassword, $i_EncryptCountH, 1)), 255))
				Next
				$s_EncryptText = $v_EncryptModified
				$i_EncryptCountA = ''
				$i_EncryptCountB = 0
				$i_EncryptCountC = ''
				$i_EncryptCountD = ''
				$i_EncryptCountE = ''
				$v_EncryptCipherBy = ''
				$v_EncryptCipher = ''
				$v_EncryptSwap = ''
				$av_EncryptBox = ''
				Local $av_EncryptBox[256][2]
				For $i_EncryptCountA = 0 To 255
					$av_EncryptBox[$i_EncryptCountA][1] = Asc(StringMid($s_EncryptPassword, Mod($i_EncryptCountA, StringLen($s_EncryptPassword)) + 1, 1))
					$av_EncryptBox[$i_EncryptCountA][0] = $i_EncryptCountA
				Next
				For $i_EncryptCountA = 0 To 255
					$i_EncryptCountB = Mod(($i_EncryptCountB + $av_EncryptBox[$i_EncryptCountA][0] + $av_EncryptBox[$i_EncryptCountA][1]), 256)
					$v_EncryptSwap = $av_EncryptBox[$i_EncryptCountA][0]
					$av_EncryptBox[$i_EncryptCountA][0] = $av_EncryptBox[$i_EncryptCountB][0]
					$av_EncryptBox[$i_EncryptCountB][0] = $v_EncryptSwap
				Next
				For $i_EncryptCountA = 1 To StringLen($s_EncryptText)
					$i_EncryptCountC = Mod(($i_EncryptCountC + 1), 256)
					$i_EncryptCountD = Mod(($i_EncryptCountD + $av_EncryptBox[$i_EncryptCountC][0]), 256)
					$i_EncryptCountE = $av_EncryptBox[Mod(($av_EncryptBox[$i_EncryptCountC][0] + $av_EncryptBox[$i_EncryptCountD][0]), 256)][0]
					$v_EncryptCipherBy = BitXOR(Asc(StringMid($s_EncryptText, $i_EncryptCountA, 1)), $i_EncryptCountE)
					$v_EncryptCipher &= Hex($v_EncryptCipherBy, 2)
				Next
				$s_EncryptText = $v_EncryptCipher
			Next
		Else
			For $i_EncryptCountF = 0 To $i_EncryptLevel Step 1
				$i_EncryptCountB = 0
				$i_EncryptCountC = ''
				$i_EncryptCountD = ''
				$i_EncryptCountE = ''
				$v_EncryptCipherBy = ''
				$v_EncryptCipher = ''
				$v_EncryptSwap = ''
				$av_EncryptBox = ''
				Local $av_EncryptBox[256][2]
				For $i_EncryptCountA = 0 To 255
					$av_EncryptBox[$i_EncryptCountA][1] = Asc(StringMid($s_EncryptPassword, Mod($i_EncryptCountA, StringLen($s_EncryptPassword)) + 1, 1))
					$av_EncryptBox[$i_EncryptCountA][0] = $i_EncryptCountA
				Next
				For $i_EncryptCountA = 0 To 255
					$i_EncryptCountB = Mod(($i_EncryptCountB + $av_EncryptBox[$i_EncryptCountA][0] + $av_EncryptBox[$i_EncryptCountA][1]), 256)
					$v_EncryptSwap = $av_EncryptBox[$i_EncryptCountA][0]
					$av_EncryptBox[$i_EncryptCountA][0] = $av_EncryptBox[$i_EncryptCountB][0]
					$av_EncryptBox[$i_EncryptCountB][0] = $v_EncryptSwap
				Next
				For $i_EncryptCountA = 1 To StringLen($s_EncryptText) Step 2
					$i_EncryptCountC = Mod(($i_EncryptCountC + 1), 256)
					$i_EncryptCountD = Mod(($i_EncryptCountD + $av_EncryptBox[$i_EncryptCountC][0]), 256)
					$i_EncryptCountE = $av_EncryptBox[Mod(($av_EncryptBox[$i_EncryptCountC][0] + $av_EncryptBox[$i_EncryptCountD][0]), 256)][0]
					$v_EncryptCipherBy = BitXOR(Dec(StringMid($s_EncryptText, $i_EncryptCountA, 2)), $i_EncryptCountE)
					$v_EncryptCipher = $v_EncryptCipher & Chr($v_EncryptCipherBy)
				Next
				$s_EncryptText = $v_EncryptCipher
				$i_EncryptCountG = ''
				$i_EncryptCountH = ''
				$v_EncryptModified = ''
				For $i_EncryptCountG = 1 To StringLen($s_EncryptText)
					If $i_EncryptCountH = StringLen($s_EncryptPassword) Then
						$i_EncryptCountH = 1
					Else
						$i_EncryptCountH += 1
					EndIf
					$v_EncryptModified &= Chr(BitXOR(Asc(StringMid($s_EncryptText, $i_EncryptCountG, 1)), Asc(StringMid($s_EncryptPassword, $i_EncryptCountH, 1)), 255))
				Next
				$s_EncryptText = $v_EncryptModified
			Next
		EndIf
		Return $s_EncryptText
	EndIf
EndFunc   ;==>_StringEncrypt



; ROT47: Reliable, symmetrical, simple obfuscation for Base64 strings.
; Adapted from SmOke_N's _cipher_Rot()..
func ROT47($string)
	if not StringLen($string) then return SetError(1, 0, "")
	local $dc_str = StringToASCIIArray($string)
	if @error then return SetError(2, 0, "")
	for $rdat = 0 To UBound($dc_str) - 1
		switch $dc_str[$rdat]
			case 33 To 126
				if $dc_str[$rdat] + 47 < 127 then
					$dc_str[$rdat] += 47
				else
					$dc_str[$rdat] -= 47
				endif
		endswitch
	next
	return StringFromASCIIArray($dc_str)
endfunc

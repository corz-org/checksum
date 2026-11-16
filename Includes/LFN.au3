#include-once
#include "corzShared.au3"

; #INDEX# =======================================================================================================================
; Title .........: LFN
; AutoIt Version : 3.3.14.3
; UDF Version ...: 5.2
; Status ........: Production
; Language ......: English
; Description ...: Standard file management functions rewritten to overcome the MAX_PATH limitation of 256 characters by:
;                  - prepending the unicode prefix \\?\ or \\?\UNC\ where needed
;                  - calling kernel32 DLL with the unicode versions of the relevant functions
;                  - validating directory structure before calling the DLL
;                  - applying wildcards where not supported by the DLL
;                  - full compliance of parameters and return values with the equivalent native AutoIt functions:
;                  -- there may be additional use of @extended or @error when required
;                  -- there may be additional values that existing parameters can accept
;                  This UDF was created because:
;                  - not all of the above conditions are met by the WinAPIEx UDF
;                  - there was a need for convenient way to make existing scripts support long file names
;                  Native AutoIt functions that did not find their place in this UDF:
;                    FileChangeDir      - couldn't get it to work.
;                    FileCreateNTFSLink - not sure what it is and what it does.
;                    FileCreateShortcut - couldn't get it to work.
;                    FileGetShortcut    - couldn't get FileCreateShortcut to work, so didn't proceed here.
;                    FileInstall        - couldn't get it to work.
;                    FileOpenDialog     - couldn't get it to work with init dir in too long path; but it does set @WorkingDir!
;                    FileRecycle        - not applicable: too long paths can not be put to recycle bin anyway.
;                    FileRecycleEmpty   - not applicable: too long paths can not be put to recycle bin anyway.
;                    FileSaveDialog     - couldn't get it to work with init dir in too long path; but it does set @WorkingDir!
;                    FileSelectFolder   - seems to work as is.
;                  How To use this UDF:
;                  - for new scripts: as usual, include this UDF in your script and use its functions.
;                  - for existing scripts: use the conversion script (downloadable from the AutoIt forum). The conversion will
;                    replace the native functions calls with their LFN equivalents, and add an #include statement for this UDF
;                    just after your last #include statement (or at the top of your script if you have no #include statements).
;                    There is no need to change anything in the parameters or return values.
;                  Remark on the _LFN_Ini* functions:
;                  - comments (any text following a semicolon) are preserved. Comment following a Key=Value line are considered
;                    as part of the value string.
; Dll ...........: kernel32.dll
; Author(s) .....: orbs
; Resources .....: http://msdn.microsoft.com/en-us/library/windows/desktop/aa365247(v=vs.85).aspx
;                  http://www.geoffchappell.com/studies/windows/win32/kernel32/api/
; ===============================================================================================================================

; #CURRENT# =====================================================================================================================
;_LFN_DirCopy
;_LFN_DirCreate
;_LFN_DirGetSize
;_LFN_DirMove
;_LFN_DirRemove
;_LFN_FileClose
;_LFN_FileCopy
;_LFN_FileDelete
;_LFN_FileExists
;_LFN_FileFindFirstFile
;_LFN_FileFindNextFile
;_LFN_FileFlush
;_LFN_FileGetAttrib
;_LFN_FileGetEncoding
;_LFN_FileGetLongName
;_LFN_FileGetPos
;_LFN_FileGetShortName
;_LFN_FileGetSize
;_LFN_FileGetTime
;_LFN_FileGetVersion
;_LFN_FileMove
;_LFN_FileOpen
;_LFN_FileRead
;_LFN_FileReadLine
;_LFN_FileReadToArray
;_LFN_FileSetAttrib
;_LFN_FileSetEnd
;_LFN_FileSetPos
;_LFN_FileSetTime
;_LFN_FileWrite
;_LFN_FileWriteLine
;_LFN_IniDelete
;_LFN_IniRead
;_LFN_IniReadSection
;_LFN_IniReadSectionNames
;_LFN_IniRenameSection
;_LFN_IniWrite
;_LFN_IniWriteSection
; ===============================================================================================================================

; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_DirCopy
; Description ...: Copies a directory and all sub-directories and files.
; Syntax.........: _LFN_DirCopy($sSrcPath, $sDstPath[, $iFlag = 0])
; Parameters ....: $sSrcPath - Path of the source directory (with no trailing backslash). e.g. "C:\Path1"
;                  $sDstPath - Path of the destination directory (with no trailing backslash). e.g. "C:\Path_Copy"
;                  $iFlag    - [optional] This flag determines whether to overwrite files if they already exist:
;                    $FC_NOOVERWRITE (0) = (default) do not overwrite existing files
;                    $FC_OVERWRITE (1)   = overwrite existing files
;                    Constants are defined in FileConstants.au3
; Return values .: Success - Returns 1
;                  Failure - Returns 0 and sets @error to 1
; Author ........: orbs
; Modified ......:
; Remarks .......: If the destination directory structure doesn't exist, it will be created (if possible). This means that flag 8
;                  is assumed, and needs not be specified.
;                  Overwrite is determined per file, and complies with flag combination.
;                  NOTE: DirCopy('D:\dir','C:\') will fail, but _LFN_DirCopy('D:\dir','C:\') will succeed. Make of it whatever
;                  suits you.
; Related .......:
; Dependencies ..: _LFN_DirCreate, _LFN_FileCopy
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _LFN_DirCopy($sSrcPath, $sDstPath, $iFlag = 0)
    ; preparation
    $sSrcPath = __LFN_Target_RemoveTrailingBackslash($sSrcPath)
    $sDstPath = __LFN_Target_RemoveTrailingBackslash($sDstPath)
    If Not __LFN_Target_IsExistingFolder($sSrcPath) Then Return SetError(1, 0, 0)
    _LFN_DirCreate($sDstPath)
    ; main action
    Local $aFiles = __LFN_FilesListToArray($sSrcPath & '\*')
    Local $i
    Local $bOneFail = False
    For $i = 1 To $aFiles[0]
        If StringRight($aFiles[$i], 1) = '\' Then
            _LFN_DirCreate($sDstPath & '\' & __LFN_Target_LastElement_Get(StringTrimRight($aFiles[$i], 1)))
            If Not _LFN_DirCopy($aFiles[$i], $sDstPath & '\' & __LFN_Target_LastElement_Get(StringTrimRight($aFiles[$i], 1)), $iFlag) Then $bOneFail = True
        Else
            If Not _LFN_FileCopy($aFiles[$i], $sDstPath & '\', BitOR($iFlag, 8)) Then $bOneFail = True
        EndIf
    Next
    If $bOneFail Then Return SetError(1, 0, 0)
    Return 1
EndFunc   ;==>_LFN_DirCopy


; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_DirGetSize
; Description ...: Use exactly like the native AutoIt function DirGetSize
; Syntax.........: _LFN_DirGetSize($sPath[, $iFlag = 0])
; ===============================================================================================================================
Func _LFN_DirGetSize($sPath, $iFlag = 0)
    $sPath = __LFN_Target_SetUnicodePrefix($sPath)
    Local $result = DirGetSize($sPath, $iFlag)
    Return SetError(@error, @extended, $result)
EndFunc   ;==>_LFN_DirGetSize

; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_DirMove
; Description ...: Moves a directory and all sub-directories and files.
; Syntax.........: _LFN_DirMove($sSrcPath, $sDstPath[, $iFlag = 0])
; Parameters ....: $sSrcPath - Path of the source directory (with no trailing backslash). e.g. "C:\Path1"
;                  $sDstPath - Path of the destination directory (with no trailing backslash). e.g. "C:\Path_Copy"
;                  $iFlag    - [optional] This flag determines whether to overwrite files if they already exist:
;                    $FC_NOOVERWRITE (0) = (default) do not overwrite existing files
;                    $FC_OVERWRITE (1)   = overwrite existing files
;                    Constants are defined in FileConstants.au3
; Return values .: Success - Returns 1
;                  Failure - Returns 0 and sets @error to 1
; Author ........: orbs
; Modified ......:
; Remarks .......: - If the source and destination are on different volumes or UNC paths are used, then a copy+delete operation
;                    is performed rather than a move. If the 'copy' or 'delete' fails, then depending on the reason of failure,
;                    there may remain some files either in the source or destination, where not expected.
;                  - If the destination already exists and the overwrite flag IS specified, then the source directory will be
;                    moved inside the destination. If a subfolder of the destination folder already exists by the name of the
;                    source folder, then source files will overwrite destination files if exist.
;                  - If the destination already exists and the overwrite flag IS NOT specified, the operation fails.
;                  - Because AutoIt lacks a "_LFN_DirRename" function, use _LFN_DirMove to rename a folder!
; Related .......:
; Dependencies ..: _LFN_FileDelete, _LFN_DirCopy, _LFN_DirRemove
; Link ..........: http://msdn.microsoft.com/en-us/library/windows/desktop/aa365240(v=vs.85).aspx
; Example .......: No
; ===============================================================================================================================
Func _LFN_DirMove($sSrcPath, $sDstPath, $iFlag = 0)
    ; standard procedure
    Local $hDLL = __LFN_DllOpen()
    If @error Then Return SetError(1, 0, 0)
    ; preparation
    $sSrcPath = __LFN_Target_RemoveTrailingBackslash($sSrcPath)
    $sDstPath = __LFN_Target_RemoveTrailingBackslash($sDstPath)
    If Not __LFN_Target_IsExistingFolder($sSrcPath) Then Return SetError(1, 0, 0)
    If __LFN_FilesExist($sDstPath) Then
        Switch @extended
            Case 1 ; file
                If $iFlag Then ; overwrite => delete file
                    _LFN_FileDelete($sSrcPath)
                Else
                    Return SetError(1, 0, 0) ; fail
                EndIf
            Case 3 ; folder
                If $iFlag Then ; overwrite => move inside
                    $sDstPath = $sDstPath & '\' & __LFN_Target_LastElement_Get($sSrcPath)
                Else
                    Return SetError(1, 0, 0) ; fail
                EndIf
        EndSwitch
    EndIf
    ; main action
    Local $aRet = DllCall($hDLL, 'bool', 'MoveFileExW', 'wstr', __LFN_Target_SetUnicodePrefix($sSrcPath), 'wstr', __LFN_Target_SetUnicodePrefix($sDstPath), 'dword', 2 + $iFlag)
    If $aRet[0] = 0 Then
        If _LFN_DirCopy($sSrcPath, $sDstPath, $iFlag) Then
            _LFN_DirRemove($sSrcPath, 3)
        Else
            Return SetError(1, 0, 0)
        EndIf
    EndIf
    Return 1
EndFunc   ;==>_LFN_DirMove

; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_DirRemove
; Description ...: Deletes a directory.
; Syntax.........: _LFN_DirRemove($sPath[, $iFlag = 0])
; Parameters ....: $sPath        - Full path of the directory to remove.
;                  $iFlag        - [optional] This flag is a combination of the following values:
;                    1 = recurse subfolders
;                    2 = clear the Read-only and System attributes to force removal
; Return values .: Success - Returns 1
;                  Failure - Returns 0 and sets @error to 1
; Author ........: orbs
; Modified ......:
; Remarks .......:
; Related .......:
; Dependencies ..: _LFN_FileSetAttrib, _LFN_FileDelete
; Link ..........: http://msdn.microsoft.com/en-us/library/windows/desktop/aa365488(v=vs.85).aspx
; Example .......: No
; ===============================================================================================================================
Func _LFN_DirRemove($sPath, $iFlag = 0)
    ; standard procedure
    Local $hDLL = __LFN_DllOpen()
    If @error Then Return SetError(1, 0, 0)
    $sPath = __LFN_Target_SetUnicodePrefix($sPath)
    If Not __LFN_Target_IsExistingFolder($sPath) Then Return SetError(1, 0, 0)
    ; main action
    If BitAND($iFlag, 1) Then
        Local $aFiles = __LFN_FilesListToArray($sPath, BitAND($iFlag, 1))
        Local $i, $aRet
        For $i = $aFiles[0] To 1 Step -1
            If StringRight($aFiles[$i], 1) = '\' Then
                If BitAND($iFlag, 2) Then _LFN_FileSetAttrib($aFiles[$i], '-RS')
                $aRet = DllCall($hDLL, 'bool', 'RemoveDirectoryW', 'wstr', StringTrimRight($aFiles[$i], 1))
                If $aRet[0] = 0 Then Return SetError(1, @error, 0)
            Else
                If BitAND($iFlag, 2) Then _LFN_FileSetAttrib($aFiles[$i], '-RS')
                _LFN_FileDelete($aFiles[$i])
            EndIf
        Next
    EndIf
    $aRet = DllCall($hDLL, 'bool', 'RemoveDirectoryW', 'wstr', $sPath)
    If @error Then Return SetError(1, @error, 0)
    If FileExists($sPath) Then Return SetError(1, 0, 0)
    Return 1
EndFunc   ;==>_LFN_DirRemove


; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_FileCopy
; Description ...: Use exactly like the native AutoIt function FileCopy
; Syntax ........: _LFN_FileCopy($sSrc, $sDst[, $iFlag = 0])
; ===============================================================================================================================
Func _LFN_FileCopy($sSrc, $sDst, $iFlag = 0)
    $sSrc = __LFN_Target_SetUnicodePrefix($sSrc)
    $sDst = __LFN_Target_SetUnicodePrefix($sDst)
    Local $result = FileCopy($sSrc, $sDst, $iFlag)
    Return SetError(@error, @extended, $result)
EndFunc   ;==>_LFN_FileCopy

; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_FileDelete
; Description ...: Use exactly like the native AutoIt function FileDelete
; Syntax.........: _LFN_FileDelete($sMask)
; ===============================================================================================================================
Func _LFN_FileDelete($sMask)
    $sMask = __LFN_Target_SetUnicodePrefix($sMask)
    Local $result = FileDelete($sMask)
    Return SetError(@error, @extended, $result)
EndFunc   ;==>_LFN_FileDelete


; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_FileFindFirstFile
; Description ...: Use exactly like the native AutoIt function FileFindFirstFile
; Syntax.........: _LFN_FileFindFirstFile($sFile)
; ===============================================================================================================================
Func _LFN_FileFindFirstFile($sFile)
    $sFile = __LFN_Target_SetUnicodePrefix($sFile)
    Local $result = FileFindFirstFile($sFile)
    Return SetError(@error, @extended, $result)
EndFunc   ;==>_LFN_FileFindFirstFile

; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_FileFindNextFile
; Description ...: Use exactly like the native AutoIt function FileFindNextFile
; Syntax.........: _LFN_FileFindNextFile($hSearch)
; ===============================================================================================================================
Func _LFN_FileFindNextFile($hSearch)
    Local $result = FileFindNextFile($hSearch)
    Return SetError(@error, @extended, $result)
EndFunc   ;==>_LFN_FileFindNextFile

; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_FileFlush
; Description ...: Use exactly like the native AutoIt function FileFlush
; Syntax.........: _LFN_FileFlush($hFile)
; ===============================================================================================================================
Func _LFN_FileFlush($hFile)
    Local $result = FileFlush($hFile)
    Return SetError(@error, @extended, $result)
EndFunc   ;==>_LFN_FileFlush


; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_FileGetEncoding
; Description ...: Use exactly like the native AutoIt function FileGetEncoding
; Syntax.........: _LFN_FileGetEncoding($xFile[, $nMode = 1])
; ===============================================================================================================================
Func _LFN_FileGetEncoding($xFile, $nMode = 1)
    If IsString($xFile) Then $xFile = __LFN_Target_SetUnicodePrefix($xFile)
    Local $result = FileGetEncoding($xFile, $nMode)
    Return SetError(@error, @extended, $result)
EndFunc   ;==>_LFN_FileGetEncoding

; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_FileGetLongName
; Description ...: Returns the long path+name of the path+name passed.
; Syntax.........: _LFN_FileGetLongName($sFile[, $iFlag = 0])
; Parameters ....: $sFile - Full path and file name to convert
;                  $iFlag - [optional] if 1 file can have relative dir, e.g. "..\file.txt"
; Return values .: Success - Returns the long path+name of the path+name passed.
;                  Failure - Returns the parameter and sets @error to 1
; Author ........: orbs
; Modified ......:
; Remarks .......:
; Related .......:
; Dependencies ..:
; Link ..........: http://msdn.microsoft.com/en-us/library/windows/desktop/aa364980(v=vs.85).aspx
;                  http://msdn.microsoft.com/en-us/library/windows/desktop/aa364963(v=vs.85).aspx
; Example .......: No
; ===============================================================================================================================
Func _LFN_FileGetLongName($sFile, $iFlag = 0)
    Local $aRet
    Local $sFileFullPath
    If $iFlag Then
        $aRet = DllCall('kernel32.dll', 'dword', 'GetFullPathNameW', 'wstr', __LFN_Target_SetUnicodePrefix($sFile), 'dword', 4096, 'wstr', '', 'ptr', 0)
        If @error Or Not $aRet[0] Then $sFileFullPath = $sFile
        $sFileFullPath = $aRet[3]
    Else
        $sFileFullPath = $sFile
    EndIf
    $aRet = DllCall('kernel32.dll', 'dword', 'GetLongPathNameW', _
            'wstr', __LFN_Target_SetUnicodePrefix($sFileFullPath), _
            'wstr', '', _
            'dword', 65536)
    If $aRet[0] = 0 Then Return SetError(1, $sFile)
    Return __LFN_Target_UnSetUnicodePrefix($aRet[2])
EndFunc   ;==>_LFN_FileGetLongName

; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_FileGetPos
; Description ...: Use exactly like the native AutoIt function FileGetPos
; Syntax.........: _LFN_FileGetPos($hFile)
; ===============================================================================================================================
Func _LFN_FileGetPos($hFile)
    Local $result = FileGetPos($hFile)
    Return SetError(@error, @extended, $result)
EndFunc   ;==>_LFN_FileGetPos


; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_FileGetShortName
; Description ...: Use exactly like the native AutoIt function FileGetShortName
; Syntax.........: _LFN_FileGetShortName($sFile[, $iFlag = 0])
; ===============================================================================================================================
Func _LFN_FileGetShortName($sFile, $iFlag = 0)
    $sFile = __LFN_Target_SetUnicodePrefix($sFile)
    Local $result = FileGetShortName($sFile, $iFlag)
    Local $nError = @error
    Local $nExtended = @extended
    $result = __LFN_Target_UnSetUnicodePrefix($result) ; the result is a short name, therefore must not have the unicode prefix.
    Return SetError($nError, $nExtended, $result)
EndFunc   ;==>_LFN_FileGetShortName


; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_FileGetVersion
; Description ...: Use exactly like the native AutoIt function FileGetVersion
; Syntax.........: _LFN_FileGetVersion($sFile[, $sField = -1])
; ===============================================================================================================================
Func _LFN_FileGetVersion($sFile, $sField = -1)
    $sFile = __LFN_Target_SetUnicodePrefix($sFile)
    Local $sResult
    If $sField = -1 Then
        $sResult = FileGetVersion($sFile)
        Return SetError(@error, @extended, $sResult)
    Else
        $sResult = FileGetVersion($sFile, $sField)
        Return SetError(@error, @extended, $sResult)
    EndIf
EndFunc   ;==>_LFN_FileGetVersion

; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_FileMove
; Description ...: Use exactly like the native AutoIt function FileMove
; Syntax ........: _LFN_FileMove($sSrc, $sDst[, $iFlag = 0])
; ===============================================================================================================================
Func _LFN_FileMove($sSrc, $sDst, $iFlag = 0)
    $sSrc = __LFN_Target_SetUnicodePrefix($sSrc)
    $sDst = __LFN_Target_SetUnicodePrefix($sDst)
    Local $result = FileMove($sSrc, $sDst, $iFlag)
    Return SetError(@error, @extended, $result)
EndFunc   ;==>_LFN_FileMove

; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_FileOpen
; Description ...: Use exactly like the native AutoIt function FileOpen
; Syntax.........: _LFN_FileOpen($sFile[, $nMode = 0])
; ===============================================================================================================================
Func _LFN_FileOpen($sFile, $nMode = 0)
    $sFile = __LFN_Target_SetUnicodePrefix($sFile)
    Local $result = FileOpen($sFile, $nMode)
    Return SetError(@error, @extended, $result)
EndFunc   ;==>_LFN_FileOpen


; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_FileReadLine
; Description ...: Use exactly like the native AutoIt function FileReadLine
; Syntax.........: _LFN_FileReadLine($xFile[, $nLine = 1])
; ===============================================================================================================================
Func _LFN_FileReadLine($xFile, $nLine = 1)
    If IsString($xFile) Then $xFile = __LFN_Target_SetUnicodePrefix($xFile)
    Local $result
    If $nLine = 1 Then
        $result = FileReadLine($xFile)
    Else
        $result = FileReadLine($xFile, $nLine)
    EndIf
    Return SetError(@error, @extended, $result)
EndFunc   ;==>_LFN_FileReadLine

; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_FileReadToArray
; Description ...: Use exactly like the native AutoIt function FileReadToArray
; Syntax.........: _LFN_FileReadToArray($xFile)
; ===============================================================================================================================
Func _LFN_FileReadToArray($xFile)
    If IsString($xFile) Then $xFile = __LFN_Target_SetUnicodePrefix($xFile)
    Local $result = FileReadToArray($xFile)
    Return SetError(@error, @extended, $result)
EndFunc   ;==>_LFN_FileReadToArray


; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_FileSetPos
; Description ...: Use exactly like the native AutoIt function FileSetPos
; Syntax.........: _LFN_FileSetPos($hFile, $nOffset, $nOrigin)
; ===============================================================================================================================
Func _LFN_FileSetPos($hFile, $nOffset, $nOrigin)
    Local $result = FileSetPos($hFile, $nOffset, $nOrigin)
    Return SetError(@error, @extended, $result)
EndFunc   ;==>_LFN_FileSetPos

; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_FileSetEnd
; Description ...: Use exactly like the native AutoIt function FileSetEnd
; Syntax.........: _LFN_FileSetEnd($hFile)
; ===============================================================================================================================
Func _LFN_FileSetEnd($hFile)
    Local $result = FileSetEnd($hFile)
    Return SetError(@error, @extended, $result)
EndFunc   ;==>_LFN_FileSetEnd


; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_IniDelete
; Description ...: Deletes a value from a standard format .ini file.
; Syntax.........: _LFN_IniDelete($sFile, $sSection[, $sKey = ''])
; Parameters ....: $sFile    - The filename of the .ini file.
;                  $sSection - The section name in the .ini file.
;                  $sKey     - [optional] The key name in the .ini file to delete. If the key name is not given the entire
;                    section is deleted. The Default keyword may also be used which will cause the section to be deleted.
; Return values .: Success - Returns 1
;                  Failure - Returns 0 and sets @error to 1
; Author ........: orbs
; Modified ......:
; Remarks .......: A standard ini file looks like:
;                  [SectionName]
;                  Key=Value
; Related .......:
; Dependencies ..: _LFN_FileExists, _LFN_FileReadToArray, _LFN_FileOpen, _LFN_FileWriteLine, _LFN_FileClose, _LFN_FileGetEncoding
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _LFN_IniDelete($sFile, $sSection, $sKey = '')
    If Not _LFN_FileExists($sFile) Then Return SetError(1, 0, 0)
    Local $aFileLines = _LFN_FileReadToArray($sFile)
    If @error Then Return SetError(1, 0, 0)
    Local $iFirstLineToDelete = -1
    Local $iLastLineToDelete = -1
    Local $bSectionFound = False
    Local $iPos = 0
    For $i = 0 To UBound($aFileLines) - 1
        If StringLeft($aFileLines[$i], 1) = '[' Then
            If StringLeft($aFileLines[$i], StringLen($sSection) + 2) = '[' & $sSection & ']' Then
                $bSectionFound = True
                If $sKey = '' Then
                    $iFirstLineToDelete = $i
                    $iLastLineToDelete = UBound($aFileLines) - 1
                EndIf
            Else
                If $bSectionFound Then ; entering next section
                    If $sKey = '' Then $iLastLineToDelete = $i - 1
                    ExitLoop
                EndIf
            EndIf
        Else
            If $bSectionFound And $sKey <> '' Then
                $iPos = StringInStr($aFileLines[$i], '=')
                If $iPos = 0 Then ContinueLoop
                If StringLeft($aFileLines[$i], $iPos - 1) = $sKey Then
                    $iFirstLineToDelete = $i
                    $iLastLineToDelete = $i
                EndIf
            EndIf
        EndIf
    Next
    Local $hFile
    Local $bError
    If $iFirstLineToDelete > -1 And $iLastLineToDelete >= $iFirstLineToDelete Then
        $hFile = _LFN_FileOpen($sFile, 2 + _LFN_FileGetEncoding($sFile))
        For $i = 0 To UBound($aFileLines) - 1
            If $i >= $iFirstLineToDelete And $i <= $iLastLineToDelete Then ContinueLoop
            _LFN_FileWriteLine($hFile, $aFileLines[$i])
            If @error Then
                $bError = True
                ExitLoop
            EndIf
        Next
        _LFN_FileClose($hFile)
        If $bError Then Return SetError(1, 0, 0)
    Else
        Return SetError(1, 0, 0)
    EndIf
    Return 1
EndFunc   ;==>_LFN_IniDelete

; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_IniRead
; Description ...: Reads a value from a standard format .ini file.
; Syntax.........: _LFN_IniRead($sFile, $sSection, $sKey, $xDefaultValue)
; Parameters ....: $sFile         - The filename of the .ini file.
;                  $sSection      - The section name in the .ini file.
;                  $sKey          - The key name in the .ini file.
;                  $xDefaultValue - The default value to return if the requested key is not found.
; Return values .: Success - Returns the requested key value as a string.
;                  Failure - Returns the default string if the requested key is not found or any error occured.
; Author ........: orbs
; Modified ......:
; Remarks .......: All values returned are converted as a string.
;                  A standard ini file looks like:
;                  [SectionName]
;                  Key=Value
; Related .......:
; Dependencies ..: _LFN_FileExists, _LFN_FileReadToArray
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _LFN_IniRead($sFile, $sSection, $sKey, $xDefaultValue)
    If Not _LFN_FileExists($sFile) Then Return $xDefaultValue
    Local $aFileLines = _LFN_FileReadToArray($sFile)
    If @error Then Return $xDefaultValue
    Local $bSectionFound = False
    Local $iPos = 0
    For $i = 0 To UBound($aFileLines) - 1
        If StringLeft($aFileLines[$i], 1) = '[' Then
            If StringLeft($aFileLines[$i], StringLen($sSection) + 2) = '[' & $sSection & ']' Then
                $bSectionFound = True
            Else
                If $bSectionFound Then ; entering next section, key not found
                    Return $xDefaultValue
                    ExitLoop
                EndIf
            EndIf
        Else
            If $bSectionFound Then
                $iPos = StringInStr($aFileLines[$i], '=')
                If $iPos = 0 Then ContinueLoop
                If StringLeft($aFileLines[$i], $iPos - 1) = $sKey Then Return StringTrimLeft($aFileLines[$i], $iPos)
            EndIf
        EndIf
    Next
    Return $xDefaultValue
EndFunc   ;==>_LFN_IniRead

; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_IniReadSection
; Description ...: Reads all key/value pairs from a section in a standard format .ini file.
; Syntax.........: _LFN_IniReadSection($sFile, $sSection)
; Parameters ....: $sFile    - The filename of the .ini file.
;                  $sSection - The section name in the .ini file.
; Return values .: Success - Returns a 2-D array where element[n][0] is the key and element[n][1] is the value.
;                  Failure - Returns 0 and sets the @error flag to non-zero if unable to read the section (The INI file may not
;                    exist or the section may not exist or is empty).
; Author ........: orbs
; Modified ......:
; Remarks .......: A standard ini file looks like:
;                  [SectionName]
;                  Key=Value
;                  The number of elements returned will be in element[0][0]. If an @error occurs, no array is created.
;                  This function is not impacted by the 32kB limitation.
; Related .......:
; Dependencies ..: _LFN_FileExists, _LFN_FileReadToArray
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _LFN_IniReadSection($sFile, $sSection)
    If Not _LFN_FileExists($sFile) Then Return SetError(1, 0, 0)
    Local $aFileLines = _LFN_FileReadToArray($sFile)
    If @error Then Return SetError(1, 0, 0)
    Local $aResult[1][2]
    $aResult[0][0] = 0
    Local $bSectionFound = False
    Local $iPos = 0
    For $i = 0 To UBound($aFileLines) - 1
        If StringLeft($aFileLines[$i], 1) = '[' Then
            If StringLeft($aFileLines[$i], StringLen($sSection) + 2) = '[' & $sSection & ']' Then
                $bSectionFound = True
            Else
                If $bSectionFound Then ; entering next section
                    ExitLoop
                EndIf
            EndIf
        Else
            If $bSectionFound Then
                $iPos = StringInStr($aFileLines[$i], '=')
                If $iPos = 0 Then ContinueLoop
                __LFN_ReDim2D($aResult)
                $aResult[$aResult[0][0]][0] = StringLeft($aFileLines[$i], $iPos - 1)
                $aResult[$aResult[0][0]][1] = StringTrimLeft($aFileLines[$i], $iPos)
            EndIf
        EndIf
    Next
    ReDim $aResult[$aResult[0][0] + 1][2]
    Return $aResult
EndFunc   ;==>_LFN_IniReadSection

; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_IniReadSectionNames
; Description ...: Reads all sections in a standard format .ini file.
; Syntax.........: _LFN_IniReadSectionNames($sFile)
; Parameters ....: $sFile  - The filename of the .ini file.
; Return values .: Success - Returns a 1-D array of all section names in the .ini file.
;                  Failure - Returns 0 and sets the @error flag to non-zero.
; Author ........: orbs
; Modified ......:
; Remarks .......: A standard ini file looks like:
;                  [SectionName]
;                  Key=Value
;                  The number of elements returned will be in element[0]. If an @error occurs, no array is created.
; Related .......:
; Dependencies ..: _LFN_FileExists, _LFN_FileReadToArray
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _LFN_IniReadSectionNames($sFile)
    If Not _LFN_FileExists($sFile) Then Return SetError(1, 0, 0)
    Local $aFileLines = _LFN_FileReadToArray($sFile)
    If @error Then Return SetError(1, 0, 0)
    Local $aResult[1] = [0]
    For $i = 0 To UBound($aFileLines) - 1
        If StringLeft($aFileLines[$i], 1) = '[' Then __LFN_ReDim($aResult, StringTrimRight(StringTrimLeft($aFileLines[$i], 1), 1))
    Next
    If $aResult[0] = 0 Then Return SetError(1, 0, 0)
    ReDim $aResult[$aResult[0] + 1]
    Return $aResult
EndFunc   ;==>_LFN_IniReadSectionNames

; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_IniRenameSection
; Description ...: Renames a section in a standard format .ini file.
; Syntax.........: _LFN_IniRenameSection($sFile, $sSection, $sNewSection[, $bOverwrite = False])
; Parameters ....: $sFile       - The filename of the .ini file.
;                  $sSection    - The section to be renamed.
;                  $sNewSection - The new name for the section.
;                  $bOverwrite  - [optional] if a section already exists by the new name, set to True to overwrite it.
; Return values .: Success - Returns 1
;                  Failure - Returns 0 and sets @error to non-zero.
; Author ........: orbs
; Modified ......:
; Remarks .......: A standard ini file looks like:
;                  [SectionName]
;                  Key=Value
; Related .......:
; Dependencies ..: _LFN_FileExists, _LFN_FileReadToArray, _LFN_FileOpen, _LFN_FileWriteLine, _LFN_FileClose, _LFN_FileGetEncoding
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _LFN_IniRenameSection($sFile, $sSection, $sNewSection, $bOverwrite = False)
    If $sSection = $sNewSection Then Return 1
    If Not _LFN_FileExists($sFile) Then Return SetError(1, 0, 0)
    Local $aFileLines = _LFN_FileReadToArray($sFile)
    If @error Then Return SetError(1, 0, 0)
    Local $bSectionFound = False
    Local $bNewSectionFound = False
    Local $iFirstLineToDelete = -1
    Local $iLastLineToDelete = -1
    For $i = 0 To UBound($aFileLines) - 1
        If StringLeft($aFileLines[$i], 1) = '[' Then
            If StringLeft($aFileLines[$i], StringLen($sSection) + 2) = '[' & $sSection & ']' Then $bSectionFound = True
            If StringLeft($aFileLines[$i], StringLen($sNewSection) + 2) = '[' & $sNewSection & ']' Then
                $bNewSectionFound = True
                $iFirstLineToDelete = $i
                $iLastLineToDelete = UBound($aFileLines) - 1
            Else
                If $bNewSectionFound Then ; entering next section
                    $iLastLineToDelete = $i - 1
                    ExitLoop
                EndIf
            EndIf
        EndIf
    Next
    If Not $bSectionFound Then Return SetError(1, 0, 0)
    If $bNewSectionFound And Not $bOverwrite Then Return SetError(1, 0, 0)
    Local $hFile
    Local $bError
    $hFile = _LFN_FileOpen($sFile, 2 + _LFN_FileGetEncoding($sFile))
    For $i = 0 To UBound($aFileLines) - 1
        If $i >= $iFirstLineToDelete And $i <= $iLastLineToDelete Then ContinueLoop
        If StringLeft($aFileLines[$i], StringLen($sSection) + 2) = '[' & $sSection & ']' Then $aFileLines[$i] = StringReplace($aFileLines[$i], $sSection, $sNewSection)
        _LFN_FileWriteLine($hFile, $aFileLines[$i])
        If @error Then
            $bError = True
            ExitLoop
        EndIf
    Next
    _LFN_FileClose($hFile)
    If $bError Then Return SetError(1, 0, 0)
    Return 1
EndFunc   ;==>_LFN_IniRenameSection

; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_IniWrite
; Description ...: Writes a value to a standard format .ini file.
; Syntax.........: _LFN_IniWrite($sFile, $sSection, $sKey, $xValue)
; Parameters ....: $sFile    - The filename of the .ini file.
;                  $sSection - The section name in the .ini file.
;                  $sKey     - The key name in the .ini file.
;                  $xValue   - The value to write/change.
; Return values .: Success - Returns 1
;                  Failure - Returns 0 and sets @error ro 1
; Author ........: orbs
; Modified ......:
; Remarks .......: A standard ini file looks like:
;                  [SectionName]
;                  Key=Value
;                  - If the file does not already exist, it is created so long as the directory exists. Keys and/or sections are
;                    added to the end and are not sorted in any way.
;                  - If you would like to wrap quotes around an ini value, then you need to double up the quotation marks as the
;                    first set of quotation marks are stripped. For example: ""This is a test"" will produce "This is a test"
;                    when using IniRead() or such-like.
;                  - Leading and trailing whitespace is stripped. In order to preserve the whitespace, the string must be quoted.
;                    For example, " this is a test" will preserve the whitespace but per above, the quotation marks are stripped.
;                  - Multi-line values are not possible.
;                  - If you want to use an ini file with Unicode encoding, first create an .ini file by using the FileOpen()
;                    function with the mode parameter set to a Unicode parameter.
; Related .......:
; Dependencies ..: _LFN_FileExists, _LFN_FileWriteLine, _LFN_FileReadToArray, _LFN_FileOpen, _LFN_FileClose, _LFN_FileGetEncoding
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _LFN_IniWrite($sFile, $sSection, $sKey, $xValue)
    Local $sValue = String($xValue)
    $sValue = StringStripWS($sValue, 3)
    If StringLeft($sValue, 1) = '"' And StringRight($sValue, 1) = '"' Then $sValue = StringTrimLeft(StringTrimRight($sValue, 1), 1)
    If Not _LFN_FileExists($sFile) Then
        _LFN_FileWriteLine($sFile, '[' & $sSection & ']')
        If @error Then Return SetError(1, 0, 0)
        _LFN_FileWriteLine($sFile, $sKey & '=' & $sValue)
        If @error Then Return SetError(1, 0, 0)
        Return 1
    EndIf
    Local $aFileLines = _LFN_FileReadToArray($sFile)
    If @error Then Return SetError(1, 0, 0)
    Local $bToDo = -1 ; 0 = replace existing line, 1 = insert line in existing section, 2 = add new section, 3 = add new line at last section
    Local $bSectionFound = False
    Local $iLineToInsert = -1
    Local $iPos = 0
    For $i = 0 To UBound($aFileLines) - 1
        If StringLeft($aFileLines[$i], 1) = '[' Then
            If StringLeft($aFileLines[$i], StringLen($sSection) + 2) = '[' & $sSection & ']' Then
                $bSectionFound = True
            Else
                If $bSectionFound Then ; entering next section, key not found
                    $iLineToInsert = $i
                    $bToDo = 1
                    ExitLoop
                EndIf
            EndIf
        Else
            If $bSectionFound Then
                $iPos = StringInStr($aFileLines[$i], '=')
                If StringLeft($aFileLines[$i], $iPos - 1) = $sKey Then
                    $aFileLines[$i] = $sKey & '=' & $sValue
                    $bToDo = 0
                    ExitLoop
                Else
                    If $i = UBound($aFileLines) - 1 Then $bToDo = 3
                EndIf
            EndIf
        EndIf
    Next
    If Not $bSectionFound Then $bToDo = 2
    Local $bError = False
    Local $hFile
    Switch $bToDo
        Case 0
            $hFile = _LFN_FileOpen($sFile, 2 + _LFN_FileGetEncoding($sFile))
            For $i = 0 To UBound($aFileLines) - 1
                _LFN_FileWriteLine($hFile, $aFileLines[$i])
                If @error Then
                    $bError = True
                    ExitLoop
                EndIf
            Next
            _LFN_FileClose($hFile)
        Case 1
            While $aFileLines[$iLineToInsert - 1] = ''
                $iLineToInsert -= 1
            WEnd
            $hFile = _LFN_FileOpen($sFile, 2 + _LFN_FileGetEncoding($sFile))
            For $i = 0 To UBound($aFileLines) - 1
                If $i = $iLineToInsert Then
                    _LFN_FileWriteLine($hFile, $sKey & '=' & $sValue)
                    If @error Then
                        $bError = True
                        ExitLoop
                    EndIf
                EndIf
                _LFN_FileWriteLine($hFile, $aFileLines[$i])
                If @error Then
                    $bError = True
                    ExitLoop
                EndIf
            Next
            _LFN_FileClose($hFile)
        Case 2
            _LFN_FileWriteLine($sFile, '[' & $sSection & ']')
            If @error Then $bError = True
            _LFN_FileWriteLine($sFile, $sKey & '=' & $sValue)
            If @error Then $bError = True
        Case 3
            _LFN_FileWriteLine($sFile, $sKey & '=' & $sValue)
            If @error Then $bError = True
        Case Else
            $bError = True
    EndSwitch
    If $bError Then Return SetError(1, 0, 0)
    Return 1
EndFunc   ;==>_LFN_IniWrite

; #FUNCTION# ====================================================================================================================
; Name ..........: _LFN_IniWriteSection
; Description ...: Writes a section to a standard format .ini file.
; Syntax.........: _LFN_IniWriteSection($sFile, $sSection, $xData[, $iFirstEntry = 1])
; Parameters ....: $sFile       - The filename of the .ini file.
;                  $sSection    - The section name in the .ini file.
;                  $xData       - The data to write. The data can either be a string or an array. If the data is a string, then
;                                 each key=value pair must be delimited by @LF. If the data is an array, the array must be 2-D
;                                 and the second dimension must be 2 elements.
;                  $iFirstEntry - [optional] If an array is passed as data, this specifies the index to start writing from.
;                                 By default, this is 1 so that the return value of IniReadSection() can be used immediately.
;                                 For manually created arrays, this value may need to be different depending on how the array was
;                                 created. This parameter is ignored if a string is passed as data.
; Return values .: Success - Returns 1
;                  Failure - Returns 0 and sets @error ro 1
; Author ........: orbs
; Modified ......:
; Remarks .......: A standard ini file looks like:
;                  [SectionName]
;                  Key=Value
;                  - _LFN_IniWrite Remarks about doubling quotation marks or quoting whitespace are irrelevant here. Data is
;                    written to the .ini file as is.
;                  - If the file does not already exist, it is created so long as the directory exists. Keys and/or sections are
;                    added to the end and are not sorted in any way.
;                  - If the section being written already exists, its contents will be overwritten.
;                  - If you want to use an ini file with Unicode encoding, first create an .ini file by using the FileOpen()
;                    function with the mode parameter set to a Unicode parameter.
; Related .......:
; Dependencies ..: _LFN_FileExists, _LFN_FileReadToArray, _LFN_FileOpen, _LFN_FileWriteLine, _LFN_FileClose, _LFN_FileGetEncoding
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _LFN_IniWriteSection($sFile, $sSection, $xData, $iFirstEntry = 1)
    Local $sData
    If IsArray($xData) Then
        For $i = $iFirstEntry To UBound($xData) - 1
            $sData = $sData & $xData[$i][0] & '=' & $xData[$i][1] & @CRLF
        Next
    Else
        $sData = StringReplace($xData, @LF, @CRLF)
    EndIf
    If _LFN_FileExists($sFile) Then
        Local $aFileLines = _LFN_FileReadToArray($sFile)
        If @error Then Return SetError(1, 0, 0)
        Local $iFirstLineToDelete = -1
        Local $iLastLineToDelete = -1
        Local $bSectionFound = False
        For $i = 0 To UBound($aFileLines) - 1
            If StringLeft($aFileLines[$i], 1) = '[' Then
                If StringLeft($aFileLines[$i], StringLen($sSection) + 2) = '[' & $sSection & ']' Then
                    $bSectionFound = True
                    $iFirstLineToDelete = $i
                    $iLastLineToDelete = UBound($aFileLines) - 1
                Else
                    If $bSectionFound Then ; entering next section
                        $iLastLineToDelete = $i - 1
                        ExitLoop
                    EndIf
                EndIf
            EndIf
        Next
        Local $hFile
        Local $bError
        If $iFirstLineToDelete > -1 And $iLastLineToDelete >= $iFirstLineToDelete Then
            $hFile = _LFN_FileOpen($sFile, 2 + _LFN_FileGetEncoding($sFile))
            For $i = 0 To UBound($aFileLines) - 1
                If $i >= $iFirstLineToDelete And $i <= $iLastLineToDelete Then ContinueLoop
                _LFN_FileWriteLine($hFile, $aFileLines[$i])
                If @error Then
                    $bError = True
                    ExitLoop
                EndIf
            Next
            _LFN_FileClose($hFile)
            If $bError Then Return SetError(1, 0, 0)
        EndIf
    EndIf
    _LFN_FileWriteLine($sFile, '[' & $sSection & ']')
    If @error Then Return SetError(1, 0, 0)
    _LFN_FileWriteLine($sFile, $sData)
    If @error Then Return SetError(1, 0, 0)
    Return 1
EndFunc   ;==>_LFN_IniWriteSection


; #FUNCTION# ====================================================================================================================
; Name ..........: __LFN_FileReadable
; Description ...: Checks if a file can be read.
; Syntax.........: __LFN_FileReadable($sFile)
; Parameters ....: $sFile  - Full path of a single file to check.
; Return values .: Success - Returns True if the file can be read.
;                  Failure - Returns False if the file cannot be read.
; Author ........: orbs
; Modified ......:
; Remarks .......: The check is done by opening the file for reading in binary mode and reading the first byte.
;                  Example: this funtion will return False when checking a PST file currently in use by Microsoft Outlook.
;                  @error is not used.
; Related .......:
; Dependencies ..: _LFN_FileGetSize, _LFN_FileOpen, _LFN_FileRead, _LFN_FileClose
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func __LFN_FileReadable($sFile)
    If _LFN_FileGetSize($sFile) = 0 Then Return True
    Local $hFile = _LFN_FileOpen($sFile, 16)
    _LFN_FileRead($hFile, 1)
    Local $nError = @error
    _LFN_FileClose($hFile)
    Return ($nError = 0)
EndFunc   ;==>__LFN_FileReadable


; #FUNCTION# ====================================================================================================================
; Name ..........: __LFN_FilesSimilar
; Description ...: Checks if two files have the same size and small-enough "Modified" timestamp difference.
; Syntax.........: __LFN_FilesSimilar($sFile1, $sFile2)
; Parameters ....: $sFile1 - first file to check similarity of.
;                  $sFile2 - second file to check similarity of.
; Return values .: Success - Returns 1 if the files are similar, or 0 otherwise and sets @extended:
;                    1 - Difference of the "Modify" timestamp.
;                    2 - Difference of size.
;                  Failure - Returns 0 and sets @error:
;                    1 - At least one of the files was not found, or could not get timestamp of At least one of the files.
;                    2 - At least one of the files was not found, or could not get size of At least one of the files.
; Author ........: orbs
; Modified ......:
; Remarks .......:
; Related .......:
; Dependencies ..: _LFN_FileGetTime, _LFN_FileGetSize
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func __LFN_FilesSimilar($sFile1, $sFile2)
    Local $sTime1 = _LFN_FileGetTime($sFile1, 0, 1)
    If @error Then Return SetError(1, 0, 0)
    Local $sTime2 = _LFN_FileGetTime($sFile2, 0, 1)
    If @error Then Return SetError(1, 0, 0)
    If Abs(Number($sTime1) - Number($sTime2)) > 2 Then Return SetExtended(1, 0)
    Local $nSize1 = _LFN_FileGetSize($sFile1)
    If @error Then Return SetError(2, 0, 0)
    Local $nSize2 = _LFN_FileGetSize($sFile2)
    If @error Then Return SetError(2, 0, 0)
    If $nSize1 <> $nSize2 Then Return SetExtended(2, 0)
    Return 1
EndFunc   ;==>__LFN_FilesSimilar

; #FUNCTION# ====================================================================================================================
; Name ..........: __LFN_FileWritable
; Description ...: Checks if a file can be written to.
; Syntax.........: __LFN_FileWritable($sFile)
; Parameters ....: $sFile  - Full path of a single file to check.
; Return values .: Success - Returns True if the file can be written to.
;                  Failure - Returns False if the file cannot be written to.
; Author ........: KaFu
; Modified ......: orbs
; Remarks .......:
; Related .......:
; Dependencies ..:
; Link ..........: http://www.autoitscript.com/forum/topic/133076-looking-for-a-non-invasive-way-to-check-if-a-file-or-directory-is-writable-deletable-solved/
; Example .......: No
; ===============================================================================================================================
Func __LFN_FileWritable($sFile)
    Local $aRet = DllCall('kernel32.dll', 'handle', 'CreateFileW', _
            'wstr', __LFN_Target_SetUnicodePrefix($sFile), _
            'dword', 2, _
            'dword', 7, _
            'struct*', 0, _
            'dword', 3, _
            'dword', 0x02000000, _
            'handle', 0)
    If @error Or $aRet[0] = Ptr(-1) Or $aRet[0] = 0 Then Return False
    DllCall('kernel32.dll', 'bool', 'CloseHandle', 'handle', $aRet[0])
    Return True
EndFunc   ;==>__LFN_FileWritable


; #FUNCTION# ====================================================================================================================
; Name ..........: __LFN_ReDim2D
; Description ...: Applies ReDim on a 2-D array in an efficient way.
; Syntax.........: __LFN_ReDim2D(ByRef $aArray[, $xData=''[, $sDelimiter='|']])
; Parameters ....: $aArray      - The array to ReDim
;                  $xData       - [optional] Data to add to the array
;                  $sDelimiter  - [optional] Delimiter to be used to separate data elements to columns
; Return values .: Returns the array after ReDim
; Author ........: orbs
; Modified.......:
; Remarks .......: The returned array probably has empty rows at the end. the value at element [0][0] is the count of used rows,
;                  not the count of total rows. To work with the returned array, use element [0][0] to determine the last used
;                  cell instead of UBound.
;                  To truncate the array to used size: ReDim $aArray[$aArray[0][0]+1][UBound($aArray,2)]
; Related .......:
; Dependencies ..:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func __LFN_ReDim2D(ByRef $aArray, $xData = '', $sDelimiter = '|')
    Local $iNewRealSize = UBound($aArray)
    If $aArray[0][0] >= UBound($aArray) - 1 Then ; if used size = real size then must redim, otherwise do nothing
        $iNewRealSize = Ceiling((UBound($aArray) + 1) * 1.5)
        ReDim $aArray[$iNewRealSize][UBound($aArray, 2)]
    EndIf
    $aArray[0][0] += 1 ; anyway used size increased
    Local $aElements
    If $xData <> '' Then
        $aElements = StringSplit($xData, $sDelimiter)
        If $aElements[0] > UBound($aArray, 2) Then ReDim $aArray[$iNewRealSize][$aElements[0]] ; need to add columns
        For $i = 1 To $aElements[0]
            $aArray[$aArray[0][0]][$i - 1] = $aElements[$i]
        Next
    EndIf
EndFunc   ;==>__LFN_ReDim2D

; #FUNCTION# ====================================================================================================================
; Name ..........: __LFN_Target_IsExistingFile
; Description ...: Checks if the target is a single file that exists and is not a folder.
; Syntax.........: __LFN_Target_IsExistingFile($sTarget)
; Parameters ....: $sTarget - Full path to check.
; Return values .: True if the target is an existing file.
;                  False if the target is a mask, a folder, or does not exist.
; Author ........: orbs
; Modified ......:
; Remarks .......:
; Related .......:
; Dependencies ..:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func __LFN_Target_IsExistingFile($sTarget)
    If __LFN_FilesExist($sTarget) And @extended = 1 Then Return True
    Return False
EndFunc   ;==>__LFN_Target_IsExistingFile



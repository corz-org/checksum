#include-once

; Task Scheduler functions for checksum.		v0.2.2
; (c) corz.org 2005->


;
; CreateTaskMaster()

; Start creating a Task Scheduler task, choose the user to run the task under..
;
func CreateTaskMaster()

	TraySetState(2)
	local $user_name = InputBox(_T("Enter User Name"), _T("Run the Task under which user account?"), @UserName, "", 300, 130, default, default, 0)

	if not $user_name then
		TraySetState(1)
		return
	endif
	
	$my_msg = _T("Enter a name for this task")
	$full_text = _T("note: The name entered will OVERWRITE any existing tasks with the same name!\n\nAlso note, you can place the task in a subfolder using the format, 'folder\task-name'\n(by default, tasks are placed in a 'checksum' folder in your Task Scheduler)")

	local $task_name = InputBox($my_msg, $my_msg & ": " & _L($full_text), _T("My checksum task"), "", 450, 200, default, default, 0)

	if not $task_name then
		TraySetState(1)
		return
	endif

	$task_name = StringReplace($task_name, "/", "\")
	if not StringInStr($task_name, "\") then $task_name = "checksum\" & $task_name
	local $task_frequency = "weekly"

	local $schedule_info = CreateScheduledTask()

	if not $schedule_info[0] then
		TraySetState(1)
		MsgBox($MB_ICONERROR + $MB_TOPMOST, _T("Error!"), _T("Invalid date selection!\n\nchecksum will now exit!"), $dialog_timeout)
		return
	endif

	local $schedule_day = $schedule_info[0]
	local $schedule_time = $schedule_info[1]
	$path = GetINIArrayValue($ini_array, "scheduled_path", "")
	local $task_switches = ChooseTaskType()

	if not $task_switches then
		TraySetState(1)
		return
	endif

	$task_switches = StringReplace($task_switches, '"', '\"')
	if $out_dir then $switches = $switches & "d(" & $out_dir & ")"

	if $file_mask <> "*.*" then
		if IsArray($inifile_masks_array) then
			for $mask_index = 1 to $inifile_masks_array[0][0]
				if $inifile_masks_array[$mask_index][1] = $file_mask then
					$file_mask = $inifile_masks_array[$mask_index][0]
				endif
			next
		endif
		$task_switches = $task_switches & "m(" & $file_mask & ")"
	endif

	$path = StripLongPathPrefix($path)
	IniWrite($ini_path, $app_name, "scheduled_path", $path)
	$task_switches &= ' \"' & $path & '\"" '
	debug("task_switches =>" & $task_switches & "<=", @ScriptLineNumber)

	local $task_command = "schtasks /create /ru " & $user_name & ' /sc "' & $task_frequency & '" /tn "' & $task_name & '" /d ' & _
									$schedule_day & " /f /st " & $schedule_time & ' /tr "\"' & @AutoItExe & '\" ' & $task_switches
	debug("task_cmd =>" & $task_command & "<=", @ScriptLineNumber)

	local $confirm_dialog = MsgBox($MB_OKCANCEL, _T("Create Task?"), _T("The following task will be created") & ".." & @LF & @LF & $task_command)

	if $confirm_dialog = 1 then
		Run($task_command)
	endif

	TraySetState(1)
endfunc


;
; CreateScheduledTask()

; Creates a Windows scheduled task.
;
func CreateScheduledTask()

	local $prev_on_event_mode = AutoItSetOption("GUIOnEventMode", 0)
	local $prev_coord_mode = AutoItSetOption("GUICoordMode", 0)
	local $gui_width = 400
	local $gui_height = 105

	local $gui_handle = GUICreate(_T("On Which Days?"), $gui_width, $gui_height, -1, -1, -1, BitOR($WS_EX_TOPMOST, $WS_EX_WINDOWEDGE), 0)

	GUICtrlCreateLabel(_T("Run the task on which days?"), 10, 10)
	local $day_names[7] = [_T("mon"), _T("tue"), _T("wed"), _T("thu"), _T("fri"), _T("sat"), _T("sun")]
	local $day_checkboxes[7]

	GUISetCoord(-30, 30)

	for $idx = 0 to 6
		$day_checkboxes[$idx] = GUICtrlCreateCheckbox($day_names[$idx], 40, 0, 38, 12)
	next

	local $btn_all = GUICtrlCreateButton(_T("all"), 43, -4, 38, 20)
	local $schedule_result[2]

	GUISetCoord(10, 60)

	GUICtrlCreateLabel(_T("At what time? (in 24h format)"), 0, 0)

	GUISetCoord(10, 80)

	GUICtrlCreateLabel(_T("hour") & ":", 0, 0)
	local $input_hour = GUICtrlCreateInput("00", 28, -3, 75, 20, BitOR($ES_LEFT, $ES_NUMBER), -1)
	GUICtrlCreateLabel(_T("minute") & ":", 85, 3)
	local $input_minute = GUICtrlCreateEdit("00", 38, -3, 75, 20, BitOR($ES_LEFT, $ES_NUMBER), -1)
	GUISetCoord($gui_width - 100, $gui_height - 30)
	local $btn_cancel = GUICtrlCreateButton(_T("Cancel"), 0, 0, 45, 25)
	GUISetCoord($gui_width - 50, $gui_height - 30)
	local $btn_ok = GUICtrlCreateButton(_T("OK"), 0, 0, 45, 25)

	GUISetState(@SW_SHOW, $gui_handle)

	while 1
		switch GUIGetMsg()

			case $GUI_EVENT_CLOSE, $btn_cancel
				exitloop

			case $btn_all

				for $check_idx = 0 to 6
					if GUICtrlRead($day_checkboxes[$check_idx]) = $OFF then
						for $idx = 0 to 6
							GUICtrlSetState($day_checkboxes[$idx], $ON)
						next
						continueloop 2
					endif
				next
				for $idx = 0 to 6
					GUICtrlSetState($day_checkboxes[$idx], $OFF)
				next

			case $btn_ok

				for $idx = 0 to 6
					if GUICtrlRead($day_checkboxes[$idx]) = $ON then
						$schedule_result[0] &= $day_names[$idx] & ","
					endif
				next
				$schedule_result[0] = StringTrimRight($schedule_result[0], 1)
				local $hour_val = Number(GUICtrlRead($input_hour))
				local $minute_val = Number(GUICtrlRead($input_minute))
				if $hour_val > 23 then $hour_val = 23
				if $minute_val > 59 then $minute_val = 59
				if $hour_val < 0 then $hour_val = 0
				if $minute_val < 0 then $minute_val = 0
				$schedule_result[1] = StringFormat("%02d", $hour_val) & ":" & StringFormat("%02d", $minute_val) & ":" & "00"
				exitloop

		endswitch

		if StringLen(GUICtrlRead($input_hour)) > 2 then GUICtrlSetData($input_hour, GUICtrlRead(StringRight($input_hour, 2)))
		if StringLen(GUICtrlRead($input_minute)) > 2 then GUICtrlSetData($input_minute, GUICtrlRead(StringRight($input_minute, 2)))
		if Number(GUICtrlRead($input_hour)) > 23 then GUICtrlSetData($input_hour, 23)
		if Number(GUICtrlRead($input_hour)) < 0 then GUICtrlSetData($input_hour, 0)
		if Number(GUICtrlRead($input_minute)) > 59 then GUICtrlSetData($input_minute, 59)
		if Number(GUICtrlRead($input_minute)) < 0 then GUICtrlSetData($input_minute, 0)
		Sleep(5)
	wend

	GUIDelete($gui_handle)
	AutoItSetOption("GUIOnEventMode", $prev_on_event_mode)
	AutoItSetOption("GUICoordMode", $prev_coord_mode)
	if $schedule_result <> "" then return $schedule_result

endfunc


;
; ChooseTaskType()

; Modal dialog to choose task type for task scheduler.
;
func ChooseTaskType()

	local $prev_on_event_mode = AutoItSetOption("GUIOnEventMode", 0)
	local $prev_coord_mode = AutoItSetOption("GUICoordMode", 0)
	local $gui_width = 400
	local $gui_height = 75

	local $gui_handle = GUICreate($my_msg, $gui_width, $gui_height)
	GUICtrlCreateLabel($my_msg, 10, 10)

	GUISetCoord(10, 30)
	local $btn_create = GUICtrlCreateButton(_T("Create Task"), 0, 0, ($gui_width / 2) - 20, 30)
	GUISetCoord(($gui_width / 2) + 10, 30)
	local $btn_verify = GUICtrlCreateButton(_T("Verify Task"), 0, 0, ($gui_width / 2) - 20, 30)

	GUISetState(@SW_SHOW, $gui_handle)

	while 1
		switch GUIGetMsg()
			case $GUI_EVENT_CLOSE
				exitloop
			case $btn_create
				$operation_mode = "create"
				exitloop
			case $btn_verify
				$operation_mode = "verify"
				exitloop
		endswitch
		Sleep(50)
	wend

	GUIDelete($gui_handle)
	AutoItSetOption("GUIOnEventMode", $prev_on_event_mode)
	AutoItSetOption("GUICoordMode", $prev_coord_mode)

	switch $operation_mode
		case "create"
			DoCreateOptions()
		case "verify"
			DoVerifyOptions()
	endswitch

	if $switches then return $switches
	return false
endfunc

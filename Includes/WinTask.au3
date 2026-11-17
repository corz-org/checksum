#include-once

; Task Scheduler functions for checksum.		v0.2.3
; (c) corz.org 2005->


;
; CreateTaskMaster()

; Start creating a Task Scheduler task, choose the user to run the task under..
;
func CreateTaskMaster()

	TraySetState(2)
	local $user_name = ChecksumTextInput(_T("Enter User Name"), _T("Run the Task under which user account?"), @UserName, 300)

	if not $user_name then
		TraySetState(1)
		return
	endif
	
	$my_msg = _T("Enter a name for this task")
	$full_text = _T("note: The name entered will OVERWRITE any existing tasks with the same name!\n\nAlso note, you can place the task in a subfolder using the format, 'folder\task-name'\n(by default, tasks are placed in a 'checksum' folder in your Task Scheduler)")

	local $task_name = ChecksumTextInput($my_msg, $my_msg & ": " & _L($full_text), _T("My checksum task"), 450)

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
	local $prev_coord_mode = AutoItSetOption("GUICoordMode", 1)
	local $text_scale = ChecksumDialogTextScale()
	local $gui_handle = GUICreate(_T("On Which Days?"), 400, 105, -1, -1, -1, BitOR($WS_EX_TOPMOST, $WS_EX_WINDOWEDGE))
	GUISetFont(9 * $text_scale, default, default, "Segoe UI", $gui_handle)

	local $day_prompt = _T("Run the task on which days?")
	local $time_prompt = _T("At what time? (in 24h format)")
	local $hour_caption = _T("hour") & ":"
	local $minute_caption = _T("minute") & ":"
	local $all_caption = _T("all"), $cancel_caption = _T("Cancel"), $ok_caption = _T("OK")
	local $day_names[7] = [_T("mon"), _T("tue"), _T("wed"), _T("thu"), _T("fri"), _T("sat"), _T("sun")]
	local $day_checkboxes[7], $day_widths[7]
	local $schedule_result[2]

	local $measure = GUICtrlCreateLabel("", 0, 0, 1, 1)
	local $line_height = FitLabelHeight($measure, "Ag", 100)
	local $gap = Ceiling($line_height / 2)
	local $row_height = $line_height + $gap
	local $all_width = FitLabelWidth($measure, $all_caption, @DesktopWidth, 3 * $gap)
	local $cancel_width = FitLabelWidth($measure, $cancel_caption, @DesktopWidth, 3 * $gap)
	local $ok_width = FitLabelWidth($measure, $ok_caption, @DesktopWidth, 3 * $gap)
	local $hour_width = FitLabelWidth($measure, $hour_caption, @DesktopWidth)
	local $minute_width = FitLabelWidth($measure, $minute_caption, @DesktopWidth)
	local $input_width = FitLabelWidth($measure, "00", @DesktopWidth, 3 * $gap)
	local $days_width = $all_width + 2 * $gap
	for $idx = 0 to UBound($day_names) - 1
		$day_widths[$idx] = FitLabelWidth($measure, $day_names[$idx], @DesktopWidth, $row_height)
		$days_width += $day_widths[$idx] + $gap
	next
	local $time_width = $hour_width + $minute_width + 2 * $input_width + 5 * $gap
	local $prompt_width = _Max(FitLabelWidth($measure, $day_prompt, @DesktopWidth), FitLabelWidth($measure, $time_prompt, @DesktopWidth))
	local $gui_width = _Max(_Max($days_width, $time_width), _Max($prompt_width + 2 * $gap, $cancel_width + $ok_width + 3 * $gap))
	local $gui_height = 5 * $row_height + 4 * $gap
	GUICtrlDelete($measure)

	local $outer = WinGetPos($gui_handle), $client = WinGetClientSize($gui_handle)
	WinMove($gui_handle, "", $outer[0] - Int(($gui_width - $client[0]) / 2), $outer[1] - Int(($gui_height - $client[1]) / 2), _
		$gui_width + $outer[2] - $client[0], $gui_height + $outer[3] - $client[1])
	GUICtrlCreateLabel($day_prompt, $gap, $gap, $gui_width - 2 * $gap, $row_height)
	local $day_x = $gap, $days_top = $gap + $row_height
	for $idx = 0 to UBound($day_names) - 1
		$day_checkboxes[$idx] = GUICtrlCreateCheckbox($day_names[$idx], $day_x, $days_top, $day_widths[$idx], $row_height, default, $reading_direction)
		$day_x += $day_widths[$idx] + $gap
	next
	local $btn_all = GUICtrlCreateButton($all_caption, $day_x, $days_top, $all_width, $row_height)

	local $time_top = 2 * ($gap + $row_height)
	GUICtrlCreateLabel($time_prompt, $gap, $time_top, $gui_width - 2 * $gap, $row_height)
	local $fields_top = $time_top + $row_height
	GUICtrlCreateLabel($hour_caption, $gap, $fields_top, $hour_width, $row_height)
	local $input_hour = GUICtrlCreateInput("00", $hour_width + 2 * $gap, $fields_top, $input_width, $row_height, BitOR($ES_LEFT, $ES_NUMBER))
	GUICtrlSetLimit(-1, 2)
	local $minute_x = $hour_width + $input_width + 3 * $gap
	GUICtrlCreateLabel($minute_caption, $minute_x, $fields_top, $minute_width, $row_height)
	local $input_minute = GUICtrlCreateInput("00", $minute_x + $minute_width + $gap, $fields_top, $input_width, $row_height, BitOR($ES_LEFT, $ES_NUMBER))
	GUICtrlSetLimit(-1, 2)
	local $buttons_top = $gui_height - $row_height - $gap
	local $btn_cancel = GUICtrlCreateButton($cancel_caption, $gui_width - $cancel_width - $ok_width - 2 * $gap, $buttons_top, $cancel_width, $row_height)
	local $btn_ok = GUICtrlCreateButton($ok_caption, $gui_width - $ok_width - $gap, $buttons_top, $ok_width, $row_height)

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
	local $prev_coord_mode = AutoItSetOption("GUICoordMode", 1)
	local $text_scale = ChecksumDialogTextScale()
	local $gui_handle = GUICreate($my_msg, 400, 75)
	GUISetFont(9 * $text_scale, default, default, "Segoe UI", $gui_handle)
	local $create_caption = _T("Create Task"), $verify_caption = _T("Verify Task")
	local $label = GUICtrlCreateLabel($my_msg, 0, 0, 1, 1, $text_alignment, $reading_direction)
	local $line_height = FitLabelHeight($label, "Ag", 100)
	local $gap = Ceiling($line_height / 2)
	local $button_width = _Max(FitLabelWidth($label, $create_caption, @DesktopWidth), FitLabelWidth($label, $verify_caption, @DesktopWidth)) + 3 * $gap
	local $button_height = $line_height + $gap
	local $gui_width = _Max(2 * $button_width + 3 * $gap, Ceiling(400 * $text_scale))
	local $label_width = $gui_width - 2 * $gap
	local $label_height = FitLabelHeight($label, $my_msg, $label_width)
	local $gui_height = $label_height + $button_height + 3 * $gap
	local $outer = WinGetPos($gui_handle), $client = WinGetClientSize($gui_handle)
	WinMove($gui_handle, "", $outer[0] - Int(($gui_width - $client[0]) / 2), $outer[1] - Int(($gui_height - $client[1]) / 2), _
		$gui_width + $outer[2] - $client[0], $gui_height + $outer[3] - $client[1])
	GUICtrlSetPos($label, $gap, $gap, $label_width, $label_height)
	local $buttons_top = $label_height + 2 * $gap
	$button_width = Int(($gui_width - 3 * $gap) / 2)
	local $btn_create = GUICtrlCreateButton($create_caption, $gap, $buttons_top, $button_width, $button_height)
	local $btn_verify = GUICtrlCreateButton($verify_caption, $gui_width - $gap - $button_width, $buttons_top, $button_width, $button_height)

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

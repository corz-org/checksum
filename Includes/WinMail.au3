#include-once
#include "corzCrypto.au3"

; Mail functions for checksum.
; (c) corz.org 2005->

; Saves current mail prefs via SaveMailPreferencesToIni, loads presets via LoadMailPresetFromIni, builds test body text, calls SendMail(), shows success/failure message box
func SendTestEmail()

	SaveMailPreferencesToIni()
	LoadMailPresetFromIni()

	local $attached = $attached_files
	$attached = StringReplace($attached, "@log", $log_file_path)
	local $mail_body = @CRLF & "This is a test email sent my checksum. " & @CRLF & "if you are reading this, your email settings are working fine!" & @CRLF & @CRLF & _
																						"-- " & @CRLF & "from checksum. drop-dead simple hashing.." & @LF & $my_url
	local $ret_msg = SendMail($smtp_server, $from_name, $from_address, $to_address, $subject & _
		" [test mail]", $mail_body, $attached, $cc_add, $bcc_add, $mail_priority, $mail_user, _
		$mail_pass, $mail_port, $mail_ssl, $ssl_ntlm_auth_flag, "checksum mailer")

	if @error then
		MsgBox($MB_OK + $MB_ICONERROR + $MB_SYSTEMMODAL, "Error sending email!", "Error code: " & @error & @LF & "Description: " & $ret_msg & " ")
	else
		MsgBox($MB_OK + $MB_ICONINFORMATION + $MB_SYSTEMMODAL, "Success sending email!", " Mail sent successfully! " & @LF & " The mail should be in your inbox in a moment. ")
	endif
endfunc


; Reads INI section names for "mail|" presets, finds matching $current_mail_preset_string, decrypts sensitive fields
; (from/to/cc/bcc addresses, username/password) via CSDecrypt/_StringEncrypt
func LoadMailPresetFromIni()

	EnumerateMailPresets()
	if not IsArray($mail_preset_list_array) then return false

	$current_mail_preset = IniRead($ini_path, $app_name, "current_mail_preset", "mail|default")
	debug(@CRLF & @CRLF & "current_mail_preset =>" & $current_mail_preset & "<=", @ScriptLineNumber)
	local $my_preset

	for $t = 1 to $mail_preset_list_array[0]

		$my_preset = $mail_preset_list_array[$t]
		if $my_preset <> $current_mail_preset then continueloop
		if StringLeft($my_preset, 5) <> "mail|" then continueloop

		$my_mail_hack = IniReadCheckBox($ini_path, $my_preset, "my_mail_hack", $OFF)
		$smtp_server = IniRead($ini_path, $my_preset, "smtp_server", "localhost")
		$from_name = IniRead($ini_path, $my_preset, "from_name", "checksum")
		$from_address = CSDecrypt(IniRead($ini_path, $my_preset, "from_address", ""), $app_name)
		$to_address = CSDecrypt(IniRead($ini_path, $my_preset, "to_address", ""), $app_name)
		$subject = IniRead($ini_path, $my_preset, "subject", "hash failure!")
		$mail_priority = IniRead($ini_path, $my_preset, "mail_priority", "High")
		$mail_user = CSDecrypt(IniRead($ini_path, $my_preset, "mail_user", ""), $app_name)
		$mail_pass = CSDecrypt(_StringEncrypt(0, StringTrimRight(IniRead($ini_path, $my_preset, "mail_pass", ""), 2), $mail_user), $mail_user & $gc_interval_setting & $mail_user, 50)
		$cc_add = CSDecrypt(IniRead($ini_path, $my_preset, "cc_add", ""), $app_name)
		$bcc_add = CSDecrypt(IniRead($ini_path, $my_preset, "bcc_add", ""), $app_name)
		$mail_ssl = IniReadCheckBox($ini_path, $my_preset, "mail_ssl", $OFF)
		$mail_port = IniRead($ini_path, $my_preset, "mail_port", 25)

		if $mail_port < 1 or $mail_port > 65535 then
			if $mail_ssl = $ON then
				$mail_port = 465
			else
				$mail_port = 25
			endif
			IniWrite($ini_path, $my_preset, "mail_port", $mail_port)
		endif

		$attached_files = IniRead($ini_path, $my_preset, "attached_files", "@log")
		$resend_mail = IniReadCheckBox($ini_path, $my_preset, "resend_mail", $ON) ; on send failure
		$resend_mail_max_retry = IniRead($ini_path, $my_preset, "resend_mail_max_retry", 3)
		if $resend_mail_max_retry < 0 then $resend_mail_max_retry = 0
		$retry_delay_seconds = IniRead($ini_path, $my_preset, "mail_sleep_time", 10)
	next

	debug("my_mail_hack =>" & $my_mail_hack & "<=", @ScriptLineNumber)
	debug("smtp_server =>" & $smtp_server & "<=", @ScriptLineNumber)
	debug("from_address =>" & $from_address & "<=", @ScriptLineNumber)
	debug("to_address =>" & $to_address & "<=", @ScriptLineNumber)
	debug("subject =>" & $subject & "<=", @ScriptLineNumber)
	debug("mail_priority =>" & $mail_priority & "<=", @ScriptLineNumber)
	debug("mail_user =>" & $mail_user & "<=", @ScriptLineNumber)
	debug("mail_pass =>" & $mail_pass & "<=", @ScriptLineNumber)
	debug("cc_add =>" & $cc_add & "<=", @ScriptLineNumber)
	debug("bcc_add =>" & $bcc_add & "<=", @ScriptLineNumber)
	debug("mail_ssl =>" & $mail_ssl & "<=", @ScriptLineNumber)
	debug("mail_port =>" & $mail_port & "<=", @ScriptLineNumber)
	debug("attached_files =>" & $attached_files & "<=", @ScriptLineNumber)
	debug("resend_mail =>" & $resend_mail & "<=", @ScriptLineNumber)
	debug("resend_mail_max_retry =>" & $resend_mail_max_retry & "<=", @ScriptLineNumber)

endfunc


; Reads INI section names filtering for mail| prefixed sections and builds array of preset identifiers with decryption of sensitive fields via CSDecrypt helper
func EnumerateMailPresets()

	local $section_names = IniReadSectionNames($ini_path)
	local $preset_accumulator = ""

	if IsArray($section_names) then
		for $index = 1 to $section_names[0]
			if StringLeft($section_names[$index], 5) == "mail|" then $preset_accumulator &= $section_names[$index] & "*"
		next
	endif

	if $preset_accumulator <> "" then
		$mail_preset_list_array = StringSplit($preset_accumulator, "*")
	else
		$mail_preset_list_array = StringSplit("mail|default", ",")
		$current_mail_preset = "mail|default"
		IniWrite($ini_path, $app_name, "current_mail_preset", "mail|default")
	endif

	return $mail_preset_list_array
endfunc


; Extracts short preset names from $mail_presets_array, clears and repopulates the mail status combo box control, selects current preset
func PopulateMailPresetCombo()
	local $preset_names = ""
	for $index = 1 to $mail_preset_list_array[0]
		if StringLeft($mail_preset_list_array[$index], 5) <> "mail|" then continueloop
		local $preset_parts = StringSplit($mail_preset_list_array[$index], "|")
		$preset_names &= $preset_parts[2] & "|"
	next
	$preset_names = StringTrimRight($preset_names, 1)
	local $preset_names_array = StringSplit($preset_names, "|")
	GUICtrlSetData($mail_preset_combo_id, "")
	if $preset_names_array[0] then
		for $index = 1 to $preset_names_array[0]
			if $preset_names_array[$index] then
				ControlCommand("Mail-On-Fail ", "", $mail_preset_combo_id, "AddString", $preset_names_array[$index])
			endif
		next
		local $matching_index = ControlCommand("Mail-On-Fail ", "", $mail_preset_combo_id, "FindString", StringTrimLeft($current_mail_preset, 5))
		ControlCommand("Mail-On-Fail ", "", $mail_preset_combo_id, "SetCurrentselection", $matching_index)
	endif
endfunc


; Calls IniDelete on $current_mail_preset_string section, resets to first available preset, writes new default back
func DeleteCurrentMailPreset()
	IniDelete($ini_path, $current_mail_preset)
	$current_mail_preset = $mail_preset_list_array[1]
	IniWrite($ini_path, $app_name, "current_mail_preset", $current_mail_preset)
	debug("DeleteCurrentMailPreset() NEW current_mail_preset =>" & $current_mail_preset & "<=", @ScriptLineNumber)
endfunc


; Recursively opens ShowMailPreferencesDialog (mail prefs GUI); if it returns "relaunch", calls itself again to refresh after INI changes
func EditMailPreferences()
	if ShowMailPreferencesDialog() == "relaunch" then EditMailPreferences()
endfunc


; Creates full Mail-On-Fail Preferences GUI: SMTP server/user/pass, from/to/cc/bcc addresses, priority, SSL checkbox,
; NTLM, port, attachments with drag-drop support, resend-on-failure settings, preset combo with delete menu; returns "relaunch" if preset changed
func ShowMailPreferencesDialog()

	local $opt_gui_on_event = AutoItSetOption("GUIOnEventMode", 0)
	local $opt_gui_coord = AutoItSetOption("GUICoordMode", 0)
	local $win_pos = WinGetPos($GUI_Options)
	local $pos_x, $pos_y

	if IsArray($win_pos) then
		$pos_x = $win_pos[0]
		$pos_y = $win_pos[1]
		if $pos_x < 0 then $pos_x = 0
		if $pos_y < 0 then $pos_y = 0
	else
		$pos_x = -1
		$pos_y = -1
	endif

	HideWindow($GUI_Options)
	LoadMailPresetFromIni()

	local $gui_width = 256
	local $gui_height = 332
	local $row_offset = 26
	local $control_height = 21
	local $label_width = 75
	local $input_width = 170

	local $gui_handle = GUICreate("Mail-On-Fail Preferences", $gui_width, $gui_height, $pos_x, $pos_y, _
		Bitor($WS_MINIMIZEBOX, $WS_CAPTION, $WS_POPUP, $WS_SYSMENU, $WS_SIZEBOX), Bitor($WS_EX_TOOLWINDOW, $WS_EX_ACCEPTFILES), $GUI_Options)
	GUIRegisterMsg($WM_DROPFILES, "HandleDragDropFiles")
	WinSetOntop($gui_handle, "", 1)

	GUICtrlCreateLabel("checksum can email you about hash failures..", 7, 8, $gui_width - 7, 32)
	local $label_server = GUICtrlCreateLabel("Mail Server:", 0, 27, $label_width, $control_height)
	global $input_smtp_host = GUICtrlCreateInput($smtp_server, $label_width, -4, $input_width, $control_height)
	local $label_user = GUICtrlCreateLabel("User:", -$label_width, $row_offset, $label_width, $control_height)
	global $input_mail_username = GUICtrlCreateInput($mail_user, $label_width, -4, $input_width, $control_height)
	local $label_pass = GUICtrlCreateLabel("Password:", -$label_width, $row_offset, $label_width, $control_height)
	global $input_mail_password = GUICtrlCreateInput($mail_pass, $label_width, -4, $input_width, $control_height, Bitor($ES_LEFT, $ES_AUTOHSCROLL, $ES_PASSWORD))
	local $label_name = GUICtrlCreateLabel("Name:", -$label_width, $row_offset, $label_width, $control_height)
	global $input_display_name = GUICtrlCreateInput($from_name, $label_width, -4, $input_width, $control_height)
	local $label_from = GUICtrlCreateLabel("From:", -$label_width, $row_offset, $label_width, $control_height)
	global $input_from_address = GUICtrlCreateInput($from_address, $label_width, -4, $input_width, $control_height)
	local $label_to = GUICtrlCreateLabel("to:", -$label_width, $row_offset, $label_width, $control_height)
	global $input_to_recipients = GUICtrlCreateInput($to_address, $label_width, -4, $input_width, $control_height)
	local $label_priority = GUICtrlCreateLabel("Priority: ", -$label_width, $row_offset, $label_width, $control_height)
	global $mail_priority_input = GUICtrlCreateInput($mail_priority, $label_width, -4, $input_width, $control_height)
	local $label_cc = GUICtrlCreateLabel("CC: ", -$label_width, $row_offset, $label_width, $control_height)
	global $input_cc_recipients = GUICtrlCreateInput($cc_add, $label_width, -4, $input_width, $control_height)
	local $label_bcc = GUICtrlCreateLabel("BCC: ", -$label_width, $row_offset, $label_width, $control_height)
	global $input_bcc_recipients = GUICtrlCreateInput($bcc_add, $label_width, -4, $input_width, $control_height)
	local $label_port = GUICtrlCreateLabel("SMTP Port: ", -$label_width, $row_offset, $label_width, $control_height)
	global $input_smtp_port = GUICtrlCreateInput($mail_port, $label_width, -4, 40, $control_height, Bitor($WS_TABSTOP, $ES_NUMBER))
	global $checkbox_ssl_enabled = GUICtrlCreateCheckbox("Use SSL: ", 45, -1, 65, $control_height, Bitor($BS_RIGHTBUTTON, $WS_TABSTOP, $BS_AUTOCHECKBOX))
	if $mail_ssl = $ON then GUICtrlSetState(-1, $ON)
	global $checkbox_ntlm_auth = GUICtrlCreateCheckbox("NTLM: ", 74, -1, 51, $control_height, Bitor($BS_RIGHTBUTTON, $WS_TABSTOP, $BS_AUTOCHECKBOX))
	if $ssl_ntlm_auth_flag = $ON then GUICtrlSetState(-1, $ON)
	local $label_attachments = GUICtrlCreateLabel("Attachments: ", -193, $row_offset, $label_width, $control_height)
	global $input_mail_attachments = GUICtrlCreateInput($attached_files, $label_width, -4, $input_width, $control_height)
	GUICtrlSetState(-1, $GUI_DROPACCEPTED)

	global $xr = GUICtrlCreateCheckbox("ReSend on SMTP Failure: ", -$label_width, $row_offset, 140, $control_height, Bitor($BS_RIGHTBUTTON, $WS_TABSTOP, $BS_AUTOCHECKBOX))
	if $resend_mail = $ON then GUICtrlSetState(-1, $ON)
	global $xs = GUICtrlCreateLabel("Max Retries: ", 153, 4, 65, $control_height)
	global $xt = GUICtrlCreateInput($resend_mail_max_retry, 62, -4, 30, $control_height, Bitor($WS_TABSTOP, $ES_NUMBER))

	GUISetCoord(7, $gui_height - 27)

	local $label_preset = GUICtrlCreateLabel("Mail Preset:", 0, 0, $label_width, $control_height)
	$mail_preset_combo_id = GUICtrlCreateCombo("Mail Preset: ", $label_width, -4, $label_width, $control_height)
	local $preset_context_menu = GUICtrlCreateContextMenu($mail_preset_combo_id)
	local $menu_delete_preset = GUICtrlCreateMenuItem("&Delete Current Preset", $preset_context_menu)

	PopulateMailPresetCombo()

	GUISetCoord($gui_width - 59, $gui_height - 27)
	local $btn_test = GUICtrlCreateButton("&Test", 0, 0, 54, 22)
	GUICtrlSetState(-1, $GUI_DISABLE + $GUI_HIDE)
	GUISetCoord($gui_width - 59, $gui_height - 27)
	local $btn_save = GUICtrlCreateButton("&Save", 0, 0, 54, 22, $BS_DEFPUSHBUTTON)

	if $help_tips = $ON then

		GUICtrlSetTip($label_server, " Enter the SMTP Server Address.. ")
		GUICtrlSetTip($input_smtp_host, " Enter the host name of the SMTP server you wish to use to send the mail. ")
		local $tip_text = " Enter the SMTP Server Login User. Often this is an email address.. "
		GUICtrlSetTip($label_user, $tip_text)
		GUICtrlSetTip($input_mail_username, $tip_text)
		$tip_text = " Enter the password for the above mail account.. "
		GUICtrlSetTip($label_pass, $tip_text)
		GUICtrlSetTip($input_mail_password, $tip_text)
		GUICtrlSetTip($label_to, " Enter the recipient's (your) email address. It's okay to use the same to and from address. ")
		GUICtrlSetTip($input_to_recipients, " Enter the email address to send the mail to, i.e. YOUR address. ")
		GUICtrlSetTip($label_name, " Enter the 'from:' (your) Name.. ")
		GUICtrlSetTip($input_display_name, " Enter the 'from:' (your) Name.. ")
		GUICtrlSetTip($label_from, " Enter the 'from:' address.. ")
		GUICtrlSetTip($input_from_address, " Enter the email address you wish to send the mail 'from'. 'alerts@mydomain.com' is good. ")
		GUICtrlSetTip($label_priority, " Enter the mail priority.. ")
		GUICtrlSetTip($mail_priority_input, " Choose from 'Highest', 'High', 'Normal', 'Low' and 'Lower'. 'High' is recommended. ")
		GUICtrlSetTip($label_cc, " Enter any CC (Carbon Copy) addresses (leave blank if not required).. ")
		GUICtrlSetTip($input_cc_recipients, " Enter any CC (Carbon Copy) addresses here (leave blank if not required)..  ")
		GUICtrlSetTip($label_bcc, " Enter any BCC (Blind Carbon Copy) addresses (leave blank if not required).. ")
		GUICtrlSetTip($input_bcc_recipients, " Enter any BCC (Blind Carbon Copy) addresses here (leave blank if not required).. ")
		GUICtrlSetTip($checkbox_ssl_enabled, " Check this box to use SSL (Secure Socket Layer) mail communications.. ")
		GUICtrlSetTip($checkbox_ntlm_auth, " Use NTLM authentication (only for Outlook Servers).. ")
		GUICtrlSetTip($label_port, " if your mail server uses a non-standard port, enter it here.. ")
		GUICtrlSetTip($input_smtp_port, " Enter SMTP server listening port number here. ")
		GUICtrlSetTip($label_attachments, " You can attach files, too..  (use @log to attach the complete log to the email)" & @LF & _
				" Click this label for a File Open Dialog to choose files to attach. ")
		GUICtrlSetTip($input_mail_attachments, " Enter the full path to the file(s). " & @LF & ' Separate multiple entries with semicolons (";"). ' & @LF & _
				" Use @log to attach the complete log to the email. " & @LF & " Note: you can drag-and-drop files onto this input. ")
		GUICtrlSetTip($xr, " In the event of an SMTP mail sending error, checksum can sleep for 10s and try again. " & @LF & _
				" Note: you can hack the sleep time with mail_sleep_time=<seconds> in the [mail|server] section of checksum.ini ")
		$tip_text = " How many times should checksum re-try sending the mail? "
		GUICtrlSetTip($xs, $tip_text)
		GUICtrlSetTip($xt, $tip_text)
		GUICtrlSetTip($btn_test, " Click here to test your current mail settings. Note: Settings will be saved first. ")
		GUICtrlSetTip($btn_save, " Save the settings for the current (or new) preset and close this dialog" & @LF & _
				" Note: Hitting <Enter> from an input does the same thing. " & @LF & ' Hold down the <SHIFT> key to get the "Test" button.')
		$tip_text = " Save a mail preset with a new name, or load an existing mail preset from here. "
		GUICtrlSetTip($label_preset, $tip_text)
		GUICtrlSetTip($mail_preset_combo_id, $tip_text)
	endif

	local $opt_width = Int(GetINIArrayValue($ini_array, "mail_options_width", 0))
	local $opt_height = Int(GetINIArrayValue($ini_array, "mail_options_height", 0))

	if $opt_width and $opt_height then
		if $opt_width > @DesktopWidth or $opt_width < 265 then $opt_width = 265
		if $opt_height > @DesktopHeight or $opt_height < 360 then $opt_height = 360
		WinMove($gui_handle, "", default, default, $opt_width, $opt_height)
	endif

	GUISetState()

	local $preset_changed = false, $msg

	while 1

		$msg = GUIGetMsg()
		if _IsPressed("10") then
			GUICtrlSetState($btn_test, $GUI_ENABLE + $GUI_SHOW)
			GUICtrlSetState($btn_save, $GUI_DISABLE + $GUI_HIDE)
		else
			GUICtrlSetState($btn_test, $GUI_DISABLE + $GUI_HIDE)
			GUICtrlSetState($btn_save, $GUI_ENABLE + $GUI_SHOW)
		endif

		switch $msg

			case $checkbox_ssl_enabled
				local $current_port = GUICtrlRead($input_smtp_port)
				if GUICtrlRead($checkbox_ssl_enabled) = $ON then
					if $current_port = 25 or $current_port = "" then GUICtrlSetData($input_smtp_port, 465)
				else
					if $current_port = 465 or $current_port = "" then GUICtrlSetData($input_smtp_port, 25)
				endif

			case $GUI_EVENT_DROPPED
				GUICtrlSetData($input_mail_attachments, "")
				if @GUI_DragId = -1 then
					local $dropped_files_str = ""
					if UBound($dropped_files) > 1 then
						for $t = 0 to UBound($dropped_files) - 1
							$dropped_files_str &= $dropped_files[$t] & ";"
						next
					else
						if IsDir(@GUI_DragFile) then
							MsgBox($MB_TOPMOST, "Invalid Drag-And-Drop! ", " Directories cannot be attached. Please drag FILES! " & @LF, 30)
							$dropped_files_str = ""
						else
							$dropped_files_str = @GUI_DragFile & ";"
						endif
					endif
					if $dropped_files_str then $attached_files = StringTrimRight($dropped_files_str, 1)
					GUICtrlSetData($input_mail_attachments, $attached_files)
				endif

			case $label_attachments
				local $current_attachments = GUICtrlRead($input_mail_attachments)
				local $init_dir = IniRead($ini_path, "mail", "attach_init_dir", "::{20D04FE0-3AEA-1069-A2D8-08002B30309D}")
				local $selected_files = FileOpenDialog("select a file to attach to the email", $init_dir, "All (*.*)", $FD_FILEMUSTEXIST + $FD_MULTISELECT, "", $gui_handle)
				if $selected_files then
					local $attachments_path_str = ""
					if StringInStr($selected_files, "|") then
						local $split_files = StringSplit($selected_files, "|")
						for $t = 2 to $split_files[0]
							if FileExists($split_files[$t]) then
								$attachments_path_str &= $split_files[1] & "\" & $split_files[$t] & ";"
							endif
						next
					else
						if FileExists($selected_files) then $attachments_path_str = $selected_files & ";"
					endif
					if $current_attachments then $attachments_path_str = $current_attachments & ";" & $attachments_path_str
					if $attachments_path_str then $attachments_path_str = StringTrimRight($attachments_path_str, 1)
					GUICtrlSetData($input_mail_attachments, "")
					GUICtrlSetData($input_mail_attachments, $attachments_path_str)
					IniWrite($ini_path, "mail", "attach_init_dir", @WorkingDir)
				endif

			case $btn_test
				WinSetTitle($gui_handle, "", "Sending Test Mail. Please Wait...")
				GUISetState(@SW_DISABLE, $gui_handle)
				SendTestEmail()
				GUISetState(@SW_ENABLE, $gui_handle)
				WinSetTitle($gui_handle, "", "Mail-On-Fail Preferences")

			case $btn_save
				SaveMailPreferencesToIni()
				exitloop

			case $menu_delete_preset
				DeleteCurrentMailPreset()
				$preset_changed = true
				exitloop

			case $mail_preset_combo_id
				local $selected_preset = "mail|" & GUICtrlRead($mail_preset_combo_id)
				if $selected_preset <> $current_mail_preset then
					IniWrite($ini_path, $app_name, "current_mail_preset", $selected_preset)
					$preset_changed = true
					exitloop
				endif

			case $GUI_EVENT_CLOSE
				exitloop

		endswitch

		Sleep(33)
	wend

	GUIDelete($gui_handle)
	AutoItSetOption("GUIOnEventMode", $opt_gui_on_event)
	AutoItSetOption("GUICoordMode", $opt_gui_coord)

	ShowWindow($GUI_Options)
	if $preset_changed then return "relaunch"

endfunc


; Reads all mail prefs GUI controls and writes them to INI under current preset; encrypts sensitive fields (from/to/cc/bcc/user/password) before storage
func SaveMailPreferencesToIni()

	$current_mail_preset = "mail|" & GUICtrlRead($mail_preset_combo_id)
	debug("current_mail_preset =>" & $current_mail_preset & "<=", @ScriptLineNumber)

	IniWrite($ini_path, $app_name, "current_mail_preset", $current_mail_preset)
	$smtp_server = GUICtrlRead($input_smtp_host)
	IniWriteCheckBox($ini_path, $current_mail_preset, "smtp_server", $smtp_server)
	$from_name = GUICtrlRead($input_display_name)
	IniWriteCheckBox($ini_path, $current_mail_preset, "from_name", $from_name)
	$from_address = GUICtrlRead($input_from_address)
	if $from_address then IniWriteCheckBox($ini_path, $current_mail_preset, "from_address", CSbinEncrypt($from_address, $app_name))
	$to_address = GUICtrlRead($input_to_recipients)
	if $to_address then IniWriteCheckBox($ini_path, $current_mail_preset, "to_address", CSbinEncrypt($to_address, $app_name))
	local $t = ToProperCase(GUICtrlRead($mail_priority_input))
	if $t <> "Highest" and $t <> "High" and $t <> "Normal" and $t <> "Low" and $t <> "Lower" then $t = "Normal"
	$mail_priority = $t
	IniWrite($ini_path, $current_mail_preset, "mail_priority", $mail_priority)
	$mail_user = GUICtrlRead($input_mail_username)
	if $mail_user then IniWrite($ini_path, $current_mail_preset, "mail_user", CSbinEncrypt($mail_user, $app_name))
	$mail_pass = GUICtrlRead($input_mail_password)
	IniWrite($ini_path, $current_mail_preset, "mail_pass", _StringEncrypt(1, CSbinEncrypt($mail_pass, $mail_user & _
																$gc_interval_setting & $mail_user, 50), $mail_user) & "==")
	$cc_add = GUICtrlRead($input_cc_recipients)
	if $cc_add then IniWrite($ini_path, $current_mail_preset, "cc_add", CSbinEncrypt($cc_add, $app_name))
	$bcc_add = GUICtrlRead($input_bcc_recipients)
	if $bcc_add then IniWrite($ini_path, $current_mail_preset, "bcc_add", CSbinEncrypt($bcc_add, $app_name))
	$mail_ssl = GUICtrlRead($checkbox_ssl_enabled)
	IniWriteCheckBox($ini_path, $current_mail_preset, "mail_ssl", $mail_ssl)
	$ssl_ntlm_auth_flag = GUICtrlRead($checkbox_ntlm_auth)
	IniWriteCheckBox($ini_path, $current_mail_preset, "mail_ssl_NTLM", $ssl_ntlm_auth_flag)
	$mail_port = GUICtrlRead($input_smtp_port)
	IniWrite($ini_path, $current_mail_preset, "mail_port", $mail_port)
	$attached_files = GUICtrlRead($input_mail_attachments)
	IniWrite($ini_path, $current_mail_preset, "attached_files", $attached_files)
	$resend_mail = GUICtrlRead($xr)
	IniWrite($ini_path, $current_mail_preset, "resend_mail", $resend_mail)
	$resend_mail_max_retry = GUICtrlRead($xt)
	IniWrite($ini_path, $current_mail_preset, "resend_mail_max_retry", Number($resend_mail_max_retry))

endfunc





; Sends email notification via SMTP server with SSL TLS encryption and NTLM authentication support
; implements retry loop with configurable delay interval until success or user aborts manually
func SendMail($server, $from_name, $from_email, $to_email, $subject = "", $body = "", $my_attachments = "", $cc = "", $bcc = "", _
				$priority = "Normal", $user = "", $pass = "", $port = 25, $ssl = $OFF, $ntlm = $OFF, $mailer = "back-end mailer")
	local $o_cdo = ObjCreate("CDO.Message")
	$o_cdo.from = '"' & $from_name & '"	<' & $from_email & ">"
	$o_cdo.to = $to_email
	if $cc <> "" then $o_cdo.cc = $cc
	if $bcc <> "" then $o_cdo.bcc = $bcc
	$o_cdo.subject = $subject
	if StringInStr($body, "<") and StringInStr($body, ">") then
		$o_cdo.htmlbody = $body
	else
		$o_cdo.textbody = $body & @CRLF
	endif
	if $my_attachments <> "" then
		local $attachments = StringSplit($my_attachments, ";")
		for $i = 1 to $attachments[0]
			$attachments[$i] = ResolveAndNormalizePath($attachments[$i])
			if FileExists($attachments[$i]) then
				debug("File attachment added =>" & $attachments[$i] & "<=", @ScriptLineNumber)
				$o_cdo.addattachment($attachments[$i])
			else
				debug("File attachment not added =>" & $attachments[$i] & "<==>Error code: " & @error & "<=", @ScriptLineNumber)
				SetError(1)
				exitloop
			endif
		next
	endif
	$o_cdo.configuration.fields.item("http://schemas.microsoft.com/cdo/configuration/sendusing") = 2
	$o_cdo.configuration.fields.item("http://schemas.microsoft.com/cdo/configuration/smtpserver") = $server
	if Number($port) = 0 then $port = 25
	$o_cdo.configuration.fields.item("http://schemas.microsoft.com/cdo/configuration/smtpserverport") = $port
	if $ssl = $ON then
		$o_cdo.configuration.fields.item("http://schemas.microsoft.com/cdo/configuration/smtpusessl") = true
	endif
	if $user <> "" then
		local $auth = 1
		if $ntlm = $ON then $auth = 2
		$o_cdo.configuration.fields.item("http://schemas.microsoft.com/cdo/configuration/smtpauthenticate") = $auth
		$o_cdo.configuration.fields.item("http://schemas.microsoft.com/cdo/configuration/sendusername") = $user
		$o_cdo.configuration.fields.item("http://schemas.microsoft.com/cdo/configuration/sendpassword") = $pass
	endif
	$o_cdo.configuration.fields.update
	switch $priority
		case "Highest"
			$o_cdo.fields.item("urn:schemas:mailheader:Importance") = "Highest"
			$o_cdo.fields.item("urn:schemas:mailheader:Priority") = "Highest"
			$o_cdo.fields.item("urn:schemas:mailheader:X-Priority") = "1 (Highest)"
		case "High"
			$o_cdo.fields.item("urn:schemas:mailheader:Importance") = "High"
			$o_cdo.fields.item("urn:schemas:mailheader:Priority") = "High"
			$o_cdo.fields.item("urn:schemas:mailheader:X-Priority") = "2 (High)"
		case "Normal"
			$o_cdo.fields.item("urn:schemas:mailheader:Importance") = "Normal"
			$o_cdo.fields.item("urn:schemas:mailheader:Priority") = "Normal"
			$o_cdo.fields.item("urn:schemas:mailheader:X-Priority") = "3 (Normal)"
		case "Low"
			$o_cdo.fields.item("urn:schemas:mailheader:Importance") = "Low"
			$o_cdo.fields.item("urn:schemas:mailheader:Priority") = "Low"
			$o_cdo.fields.item("urn:schemas:mailheader:X-Priority") = "4 (Low)"
		case "Lowest"
			$o_cdo.fields.item("urn:schemas:mailheader:Importance") = "Lowest"
			$o_cdo.fields.item("urn:schemas:mailheader:Priority") = "Lowest"
			$o_cdo.fields.item("urn:schemas:mailheader:X-Priority") = "5 (Lowest)"
	endswitch
	$o_cdo.fields.item("urn:schemas:mailheader:X-Mailer") = $mailer
	$o_cdo.fields.item("urn:schemas:mailheader:Reply-to") = $from_email
	$o_cdo.fields.update
	$o_cdo.send
	if @error then
		SetError(2)
		return $com_error_details_array[1]
	endif
	$o_cdo = ""
	debug("Sending Mail..." & @LF & @LF & "From: " & $from_name & @LF & "From: " & $from_email & @LF & "to: " & _
		$to_email & @LF & "Subject: " & $subject & @LF & "Body: " & $body & @LF & "Attached:" & $my_attachments & @LF & "CC:" & $cc & @LF & "BCC: " & _
		$bcc & @LF & "Priority: " & $priority & @LF & "SMTP User:" & $user & @LF & "SMTP Pass: " & $pass & @LF & "Port: " & $port & @LF & "SSL: " & _
		ProcessWriteHumanCheckBoxValue($ssl) & @LF, @ScriptLineNumber)
	return "sent"
endfunc



; Email notification..
func SendMailOnFail()

	debug("SendMailOnFail() =>", @ScriptLineNumber)

	if $mail_on_failure = $OFF then return false
	local $mail_string, $wk = "", $err_q = ""
	if UBound($file_queue_array) <> 2 then $wk = "s"
	$mail_string = "checksum has detected errors in the following file" & $wk & ":" & @CRLF & @CRLF

	for $t = 0 to UBound($file_queue_array) - 1
		if $file_queue_array[$t][1] then $err_q &= "  " & $file_queue_array[$t][0] & "  >>>  " & BaseName($file_queue_array[$t][1]) & @LF
	next

	$mail_string &= $err_q
	if not $mail_string then return false

	$mail_string = @CRLF & StringTrimRight($mail_string, 1) & @CRLF & @CRLF & "-- " & @CRLF & "from checksum. drop-dead simple hashing.." & @LF & $my_url
	LoadMailPresetFromIni()

	local $attached = $attached_files
	$attached = StringReplace($attached, "@log", $log_file_path)

	local $ret_msg = SendMail($smtp_server, $from_name, $from_address, $to_address, $subject, $mail_string & @CRLF & @CRLF, _
		$attached, $cc_add, $bcc_add, $mail_priority, $mail_user, $mail_pass, $mail_port, _
		$mail_ssl, $ssl_ntlm_auth_flag, "checksum mailer")

	if @error then
		SetTipWarnColor()
		local $err_msg = @LF & @LF & "Error sending email from " & $from_address & " (server: " & $smtp_server & ") to " & _
			$to_address & "! " & @LF & "time: " & @YEAR & "-" & @MON & "-" & @MDAY & " @ " & @HOUR & "." & @MIN & ":" & @SEC & @LF & _
			"Error code: " & @error & " Description: " & $ret_msg
		DoProgressTips($err_msg)
		debugDump($err_msg, "", $log_folder & "MAIL ERROR" & "-" & @YEAR & "-" & @MON & "-" & @MDAY)
		TraySettoolTip(" sending mail completed.. [MAIL ERROR] ")
	else
		local $my_msg = "checksum sent the mail successfully to " & $to_address
		DoProgressTips($my_msg)
	endif

	return $ret_msg
endfunc



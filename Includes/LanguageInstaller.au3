#include-once

; LanguageInstaller.au3		v0.2.1
; Install and setup languages for checksum.

; Functions for the language installation and initial one-time language
; selection dialog; the one with all the flags.

global $language_code_mappings[]

$language_code_mappings["af"] = "Afrikaans"
$language_code_mappings["am"] = "አማርኛ"
$language_code_mappings["ar"] = "العربية"
$language_code_mappings["az"] = "Azərbaycanca"
$language_code_mappings["be"] = "Беларуская"
$language_code_mappings["bg"] = "Български"
$language_code_mappings["bn"] = "বাংলা"
$language_code_mappings["bs"] = "Bosanski"
$language_code_mappings["ca"] = "Català"
$language_code_mappings["cs"] = "Čeština"
$language_code_mappings["cy"] = "Cymraeg"
$language_code_mappings["da"] = "Dansk"
$language_code_mappings["de"] = "Deutsch"
$language_code_mappings["el"] = "Ελληνικά"
$language_code_mappings["en"] = "English"
$language_code_mappings["es"] = "Español"
$language_code_mappings["et"] = "Eesti"
$language_code_mappings["eu"] = "Euskara"
$language_code_mappings["fa"] = "فارسی"
$language_code_mappings["fi"] = "Suomi"
$language_code_mappings["fr"] = "Français"
$language_code_mappings["ga"] = "Gaeilge"
$language_code_mappings["gd"] = "Gàidhlig"
$language_code_mappings["gl"] = "Galego"
$language_code_mappings["gu"] = "ગુજરાતી"
$language_code_mappings["he"] = "עברית"
$language_code_mappings["hi"] = "हिन्दी"
$language_code_mappings["hr"] = "Hrvatski"
$language_code_mappings["hu"] = "Magyar"
$language_code_mappings["hy"] = "Հայերեն"
$language_code_mappings["id"] = "Bahasa Indonesia"
$language_code_mappings["is"] = "Íslenska"
$language_code_mappings["it"] = "Italiano"
$language_code_mappings["ja"] = "日本語"
$language_code_mappings["ka"] = "ქართული"
$language_code_mappings["kk"] = "Қазақ тілі"
$language_code_mappings["km"] = "ភាសាខ្មែរ"
$language_code_mappings["kn"] = "ಕನ್ನಡ"
$language_code_mappings["ko"] = "한국어"
$language_code_mappings["ky"] = "Кыргызча"
$language_code_mappings["lo"] = "ພາສາລາວ"
$language_code_mappings["lt"] = "Lietuvių"
$language_code_mappings["lv"] = "Latviešu"
$language_code_mappings["mk"] = "Македонски"
$language_code_mappings["ml"] = "മലയാളം"
$language_code_mappings["mn"] = "Монгол"
$language_code_mappings["mr"] = "मराठी"
$language_code_mappings["ms"] = "Bahasa Melayu"
$language_code_mappings["ne"] = "नेपाली"
$language_code_mappings["nl"] = "Nederlands"
$language_code_mappings["no"] = "Norsk"
$language_code_mappings["pa"] = "ਪੰਜਾਬੀ"
$language_code_mappings["pl"] = "Polski"
$language_code_mappings["ps"] = "پښتو"
$language_code_mappings["pt"] = "Português"
$language_code_mappings["qya"] = "Quenya"
$language_code_mappings["ro"] = "Română"
$language_code_mappings["ru"] = "Русский"
$language_code_mappings["si"] = "සිංහල"
$language_code_mappings["sjn"] = "Sindarin"
$language_code_mappings["sk"] = "Slovenčina"
$language_code_mappings["sl"] = "Slovenščina"
$language_code_mappings["sq"] = "Shqip"
$language_code_mappings["sr"] = "Српски"
$language_code_mappings["sv"] = "Svenska"
$language_code_mappings["sw"] = "Kiswahili"
$language_code_mappings["ta"] = "தமிழ்"
$language_code_mappings["te"] = "తెలుగు"
$language_code_mappings["th"] = "ไทย"
$language_code_mappings["tlh"] = "tlhIngan Hol"
$language_code_mappings["tr"] = "Türkçe"
$language_code_mappings["uk"] = "Українська"
$language_code_mappings["ur"] = "اردو"
$language_code_mappings["uz"] = "Oʻzbekcha"
$language_code_mappings["vi"] = "Tiếng Việt"
$language_code_mappings["zh"] = "中文"


#cs
; English Reference:
	$language_code_mappings["af"] = "Afrikaans"
	$language_code_mappings["am"] = "Amharic"
	$language_code_mappings["ar"] = "Arabic"
	$language_code_mappings["az"] = "Azerbaijani"
	$language_code_mappings["be"] = "Belarusian"
	$language_code_mappings["bg"] = "Bulgarian"
	$language_code_mappings["bn"] = "Bengali"
	$language_code_mappings["bs"] = "Bosnian"
	$language_code_mappings["ca"] = "Catalan"
	$language_code_mappings["cs"] = "Czech"
	$language_code_mappings["cy"] = "Welsh"
	$language_code_mappings["da"] = "Danish"
	$language_code_mappings["de"] = "German"
	$language_code_mappings["el"] = "Greek"
	$language_code_mappings["en"] = "English"
	$language_code_mappings["es"] = "Spanish"
	$language_code_mappings["et"] = "Estonian"
	$language_code_mappings["eu"] = "Basque"
	$language_code_mappings["fa"] = "Persian"
	$language_code_mappings["fi"] = "Finnish"
	$language_code_mappings["fr"] = "French"
	$language_code_mappings["ga"] = "Irish"
	$language_code_mappings["gd"] = "Gaelic"
	$language_code_mappings["gl"] = "Galician"
	$language_code_mappings["gu"] = "Gujarati"
	$language_code_mappings["he"] = "Hebrew"
	$language_code_mappings["hi"] = "Hindi"
	$language_code_mappings["hr"] = "Croatian"
	$language_code_mappings["hu"] = "Hungarian"
	$language_code_mappings["hy"] = "Armenian"
	$language_code_mappings["id"] = "Indonesian"
	$language_code_mappings["is"] = "Icelandic"
	$language_code_mappings["it"] = "Italian"
	$language_code_mappings["ja"] = "Japanese"
	$language_code_mappings["ka"] = "Georgian"
	$language_code_mappings["kk"] = "Kazakh"
	$language_code_mappings["km"] = "Khmer"
	$language_code_mappings["kn"] = "Kannada"
	$language_code_mappings["ko"] = "Korean"
	$language_code_mappings["ky"] = "Kyrgyz"
	$language_code_mappings["lo"] = "Lao"
	$language_code_mappings["lt"] = "Lithuanian"
	$language_code_mappings["lv"] = "Latvian"
	$language_code_mappings["mk"] = "Macedonian"
	$language_code_mappings["ml"] = "Malayalam"
	$language_code_mappings["mn"] = "Mongolian"
	$language_code_mappings["mr"] = "Marathi"
	$language_code_mappings["ms"] = "Malay"
	$language_code_mappings["ne"] = "Nepali"
	$language_code_mappings["nl"] = "Dutch"
	$language_code_mappings["no"] = "Norwegian"
	$language_code_mappings["pa"] = "Punjabi"
	$language_code_mappings["pl"] = "Polish"
	$language_code_mappings["ps"] = "Pashto"
	$language_code_mappings["pt"] = "Portuguese"
	$language_code_mappings["qya"] = "Quenya"
	$language_code_mappings["ro"] = "Romanian"
	$language_code_mappings["ru"] = "Russian"
	$language_code_mappings["si"] = "Sinhala"
	$language_code_mappings["sjn"] = "Sindarin"
	$language_code_mappings["sk"] = "Slovak"
	$language_code_mappings["sl"] = "Slovenian"
	$language_code_mappings["sq"] = "Albanian"
	$language_code_mappings["sr"] = "Serbian"
	$language_code_mappings["sv"] = "Swedish"
	$language_code_mappings["sw"] = "Swahili"
	$language_code_mappings["ta"] = "Tamil"
	$language_code_mappings["te"] = "Telugu"
	$language_code_mappings["th"] = "Thai"
	$language_code_mappings["tlh"] = "Klingon"
	$language_code_mappings["tr"] = "Turkish"
	$language_code_mappings["uk"] = "Ukrainian"
	$language_code_mappings["ur"] = "Urdu"
	$language_code_mappings["uz"] = "Uzbek"
	$language_code_mappings["vi"] = "Vietnamese"
	$language_code_mappings["zh"] = "Chinese"
#ce


func GetLangNameFromLangCode($language_code)

	local $lookup_code = StringLower($language_code)
	debug("GetLangNameFromLangCode() --> lookup_code: =>" & $lookup_code & "<=", @ScriptLineNumber, 9)

	if MapExists($language_code_mappings, $lookup_code) then
		local $language_name = $language_code_mappings[$lookup_code]
		debug("GOT language_name: =>" & $language_name & "<=", @ScriptLineNumber, 9)
		return $language_name
	endif

	debug("no language mapping matching supplied code; returning language_code: =>" & $language_code & "<=", @ScriptLineNumber, 7)
	return $language_code
endfunc


func GetUserLanguageSelection($languages_dir)

	global $GUI_language_selector = 0
	global $selection_button_ids[1]
	global $selection_language_codes[1]
	global $selection_language_count = 0

	global $selection_margin = 5
	global $selection_spacing = 3
	global $selected_language_code = ""
	global $selection_button_width = 40
	global $selection_button_height = 30

	global $dialog_is_active = false

	local $flags_dir = $languages_dir & "\flags"
	local $file_search = FileFindFirstFile($languages_dir & "\*.ini")
	if $file_search = -1 then return ""

	$selection_language_count = 0
	dim $selection_language_codes[1]
	local $file_name

	while 1
		$file_name = FileFindNextFile($file_search)
		if @error then exitloop
		if @extended then continueloop

		redim $selection_language_codes[$selection_language_count + 1]
		$selection_language_codes[$selection_language_count] = StringLower(StringTrimRight($file_name, 4))
		$selection_language_count += 1
	wend

	FileClose($file_search)
	if not $selection_language_count then return ""

	local $old_event_mode = AutoItSetOption("GUIOnEventMode", 1)
	local $old_coord_mode = AutoItSetOption("GUICoordMode", 1)

	$selection_margin = 5
	$selection_spacing = 3
	$selection_button_width = 40
	$selection_button_height = 30

	local const $reference_columns = 15, $width_reduction = 60, $extra_height = 12
	local $column_width = $selection_button_width + $selection_spacing
	local $window_width = $reference_columns * $column_width - $selection_spacing + 2 * $selection_margin - $width_reduction
	local $columns = Floor(($window_width - 2 * $selection_margin + $selection_spacing) / $column_width)
	local $rows = Ceiling($selection_language_count / $columns)
	local $window_height = $rows * ($selection_button_height + $selection_spacing) - $selection_spacing + 2 * $selection_margin + $extra_height
	local $window_style = BitOr($WS_CAPTION, $WS_SYSMENU, $WS_MINIMIZEBOX, $WS_MAXIMIZEBOX, $WS_SIZEBOX)

	$GUI_language_selector = GUICreate(_B("Select your preferred language") & ".. ", $window_width, $window_height, -1, -1, $window_style)
	redim $selection_button_ids[$selection_language_count]
	local $flag_path

	GUISetBkColor($COLOR_WHITE, $GUI_language_selector)

	for $index = 0 to $selection_language_count - 1
		$flag_path = $flags_dir & "\" & $selection_language_codes[$index] & ".gif"

		if FileExists($flag_path) then
			$selection_button_ids[$index] = GUICtrlCreatePic($flag_path, 0, 0, $selection_button_width, $selection_button_height, $SS_NOTIFY)
		else
			$selection_button_ids[$index] = GUICtrlCreateButton(StringUpper($selection_language_codes[$index]), 0, 0, $selection_button_width, $selection_button_height)
		endif

		GUICtrlSetTip($selection_button_ids[$index], GetLangNameFromLangCode($selection_language_codes[$index]))
		GUICtrlSetCursor($selection_button_ids[$index], 0)
		GUICtrlSetResizing($selection_button_ids[$index], $GUI_DOCKSIZE)
		GUICtrlSetOnEvent($selection_button_ids[$index], "OnLanguageButtonClick")
	next

	$selected_language_code = ""
	$dialog_is_active = true

	GUISetOnEvent($GUI_EVENT_CLOSE, "OnLanguageDialogClose", $GUI_language_selector)
	GUIRegisterMsg($WM_SIZE, "OnLanguageDialogResize")

	debugGUICtrlBorders($GUI_language_selector)
	GUISetState()

	while $dialog_is_active
		Sleep(10)
	wend

	GUIRegisterMsg($WM_SIZE, "")
	GUIDelete($GUI_language_selector)
	AutoItSetOption("GUIOnEventMode", $old_event_mode)
	AutoItSetOption("GUICoordMode", $old_coord_mode)

	return $selected_language_code
endfunc

func OnLanguageButtonClick()
	local $control_id = @GUI_CtrlId
	for $index = 0 to $selection_language_count - 1
		if $control_id = $selection_button_ids[$index] then
			$selected_language_code = $selection_language_codes[$index]
			$dialog_is_active = false
			exitloop
		endif
	next
endfunc

func OnLanguageDialogClose()
	$dialog_is_active = false
endfunc

func OnLanguageDialogResize($hwnd, $msg, $wparam, $lparam)
	#forceref $msg, $wparam, $lparam
	if $hwnd = $GUI_language_selector then
		ReflowLanguageButtons($selection_button_ids, $GUI_language_selector, $selection_button_width, $selection_button_height, $selection_spacing, $selection_margin)
	endif
	return "GUI_RUNDEFPROC"
endfunc


;
; ReflowLanguageButtons()

; Reflows flags into balanced, centred rows.
;
func ReflowLanguageButtons(byref $button_ids, $dialog_window, $button_width, $button_height, $spacing, $margin)

	local $client_size = WinGetClientSize($dialog_window)
	if not IsArray($client_size) then return

	local $button_count = UBound($button_ids)
	local $max_columns = Floor(($client_size[0] - ($margin * 2) + $spacing) / ($button_width + $spacing))
	if $max_columns < 1 then $max_columns = 1
	if $max_columns > $button_count then $max_columns = $button_count

	local $rows = Ceiling($button_count / $max_columns)
	local $base_columns = Floor($button_count / $rows)
	local $extra_rows = Mod($button_count, $rows)
	local $grid_height = ($rows * ($button_height + $spacing)) - $spacing
	local $top = Int(($client_size[1] - $grid_height) / 2)
	if $top < $margin then $top = $margin

	local $button_index = 0
	local $row_count
	local $row_width
	local $left

	for $row = 0 to $rows - 1

		$row_count = $base_columns
		if $row < $extra_rows then $row_count += 1

		$row_width = ($row_count * ($button_width + $spacing)) - $spacing
		$left = Int(($client_size[0] - $row_width) / 2)
		if $left < $margin then $left = $margin

		for $column = 0 to $row_count - 1
			GUICtrlSetPos($button_ids[$button_index], $left + ($column * ($button_width + $spacing)), $top + ($row * ($button_height + $spacing)), $button_width, $button_height)
			$button_index += 1
		next
	next
endfunc




; Install language files and flags for..
; af, am, ar, az, be, bg, bn, bs, ca, cs, cy, da, de, el, en, es, et, eu, fa, fi, fr, ga, gd, gl, gu, he, hi, hr, hu, hy, id, is, it, ja, ka, kk, km, kn, ko, ky, lo, lt, lv, mk, ml, mn, mr, ms, ne, nl, no, pa, pl, ps, pt, ro, ru, si, sk, sl, sq, sr, sv, sw, ta, te, th, tlh, tr, uk, ur, uz, vi, zh

func InstallLanguageFiles($ini_directory, $flags_directory)

	debug("InstallLanguageFiles() ----------ini_directory-------->>>>>>>>: =>" & $ini_directory & "<=" , @ScriptLineNumber, 7)

    DirCreate($ini_directory)
    DirCreate($flags_directory)

    ; Languages..
	FileInstall("Resources\languages\af.ini", $ini_directory & "\af.ini", 0)
	FileInstall("Resources\languages\am.ini", $ini_directory & "\am.ini", 0)
	FileInstall("Resources\languages\ar.ini", $ini_directory & "\ar.ini", 0)
	FileInstall("Resources\languages\az.ini", $ini_directory & "\az.ini", 0)
	FileInstall("Resources\languages\be.ini", $ini_directory & "\be.ini", 0)
	FileInstall("Resources\languages\bg.ini", $ini_directory & "\bg.ini", 0)
	FileInstall("Resources\languages\bn.ini", $ini_directory & "\bn.ini", 0)
	FileInstall("Resources\languages\bs.ini", $ini_directory & "\bs.ini", 0)
	FileInstall("Resources\languages\ca.ini", $ini_directory & "\ca.ini", 0)
	FileInstall("Resources\languages\cs.ini", $ini_directory & "\cs.ini", 0)
	FileInstall("Resources\languages\cy.ini", $ini_directory & "\cy.ini", 0)
	FileInstall("Resources\languages\da.ini", $ini_directory & "\da.ini", 0)
	FileInstall("Resources\languages\de.ini", $ini_directory & "\de.ini", 0)
	FileInstall("Resources\languages\el.ini", $ini_directory & "\el.ini", 0)
	FileInstall("Resources\languages\en.ini", $ini_directory & "\en.ini", 0)
	FileInstall("Resources\languages\es.ini", $ini_directory & "\es.ini", 0)
	FileInstall("Resources\languages\et.ini", $ini_directory & "\et.ini", 0)
	FileInstall("Resources\languages\eu.ini", $ini_directory & "\eu.ini", 0)
	FileInstall("Resources\languages\fa.ini", $ini_directory & "\fa.ini", 0)
	FileInstall("Resources\languages\fi.ini", $ini_directory & "\fi.ini", 0)
	FileInstall("Resources\languages\fr.ini", $ini_directory & "\fr.ini", 0)
	FileInstall("Resources\languages\ga.ini", $ini_directory & "\ga.ini", 0)
	FileInstall("Resources\languages\gd.ini", $ini_directory & "\gd.ini", 0)
	FileInstall("Resources\languages\gl.ini", $ini_directory & "\gl.ini", 0)
	FileInstall("Resources\languages\gu.ini", $ini_directory & "\gu.ini", 0)
	FileInstall("Resources\languages\he.ini", $ini_directory & "\he.ini", 0)
	FileInstall("Resources\languages\hi.ini", $ini_directory & "\hi.ini", 0)
	FileInstall("Resources\languages\hr.ini", $ini_directory & "\hr.ini", 0)
	FileInstall("Resources\languages\hu.ini", $ini_directory & "\hu.ini", 0)
	FileInstall("Resources\languages\hy.ini", $ini_directory & "\hy.ini", 0)
	FileInstall("Resources\languages\id.ini", $ini_directory & "\id.ini", 0)
	FileInstall("Resources\languages\is.ini", $ini_directory & "\is.ini", 0)
	FileInstall("Resources\languages\it.ini", $ini_directory & "\it.ini", 0)
	FileInstall("Resources\languages\ja.ini", $ini_directory & "\ja.ini", 0)
	FileInstall("Resources\languages\ka.ini", $ini_directory & "\ka.ini", 0)
	FileInstall("Resources\languages\kk.ini", $ini_directory & "\kk.ini", 0)
	FileInstall("Resources\languages\km.ini", $ini_directory & "\km.ini", 0)
	FileInstall("Resources\languages\kn.ini", $ini_directory & "\kn.ini", 0)
	FileInstall("Resources\languages\ko.ini", $ini_directory & "\ko.ini", 0)
	FileInstall("Resources\languages\ky.ini", $ini_directory & "\ky.ini", 0)
	FileInstall("Resources\languages\lo.ini", $ini_directory & "\lo.ini", 0)
	FileInstall("Resources\languages\lt.ini", $ini_directory & "\lt.ini", 0)
	FileInstall("Resources\languages\lv.ini", $ini_directory & "\lv.ini", 0)
	FileInstall("Resources\languages\mk.ini", $ini_directory & "\mk.ini", 0)
	FileInstall("Resources\languages\ml.ini", $ini_directory & "\ml.ini", 0)
	FileInstall("Resources\languages\mn.ini", $ini_directory & "\mn.ini", 0)
	FileInstall("Resources\languages\mr.ini", $ini_directory & "\mr.ini", 0)
	FileInstall("Resources\languages\ms.ini", $ini_directory & "\ms.ini", 0)
	FileInstall("Resources\languages\ne.ini", $ini_directory & "\ne.ini", 0)
	FileInstall("Resources\languages\nl.ini", $ini_directory & "\nl.ini", 0)
	FileInstall("Resources\languages\no.ini", $ini_directory & "\no.ini", 0)
	FileInstall("Resources\languages\pa.ini", $ini_directory & "\pa.ini", 0)
	FileInstall("Resources\languages\pl.ini", $ini_directory & "\pl.ini", 0)
	FileInstall("Resources\languages\ps.ini", $ini_directory & "\ps.ini", 0)
	FileInstall("Resources\languages\pt.ini", $ini_directory & "\pt.ini", 0)
	FileInstall("Resources\languages\ro.ini", $ini_directory & "\ro.ini", 0)
	FileInstall("Resources\languages\ru.ini", $ini_directory & "\ru.ini", 0)
	FileInstall("Resources\languages\si.ini", $ini_directory & "\si.ini", 0)
	FileInstall("Resources\languages\sk.ini", $ini_directory & "\sk.ini", 0)
	FileInstall("Resources\languages\sl.ini", $ini_directory & "\sl.ini", 0)
	FileInstall("Resources\languages\sq.ini", $ini_directory & "\sq.ini", 0)
	FileInstall("Resources\languages\sr.ini", $ini_directory & "\sr.ini", 0)
	FileInstall("Resources\languages\sv.ini", $ini_directory & "\sv.ini", 0)
	FileInstall("Resources\languages\sw.ini", $ini_directory & "\sw.ini", 0)
	FileInstall("Resources\languages\ta.ini", $ini_directory & "\ta.ini", 0)
	FileInstall("Resources\languages\te.ini", $ini_directory & "\te.ini", 0)
	FileInstall("Resources\languages\th.ini", $ini_directory & "\th.ini", 0)
	FileInstall("Resources\languages\tr.ini", $ini_directory & "\tr.ini", 0)
	FileInstall("Resources\languages\uk.ini", $ini_directory & "\uk.ini", 0)
	FileInstall("Resources\languages\ur.ini", $ini_directory & "\ur.ini", 0)
	FileInstall("Resources\languages\uz.ini", $ini_directory & "\uz.ini", 0)
	FileInstall("Resources\languages\vi.ini", $ini_directory & "\vi.ini", 0)
	FileInstall("Resources\languages\zh.ini", $ini_directory & "\zh.ini", 0)

	; Constructed languages.

	; Klingon. A decent corpus of knowledge on the Klingon language exists, so..
	FileInstall("Resources\languages\tlh.ini", $ini_directory & "\tlh.ini", 0)

	; No flags for these two Elven languages. Not really an Elven "nation", is there?
	FileInstall("Resources\languages\qya.ini", $ini_directory & "\qya.ini", 0)
	FileInstall("Resources\languages\sjn.ini", $ini_directory & "\sjn.ini", 0)


	; Flags..
	FileInstall("Resources\languages\flags\af.gif", $flags_directory & "\af.gif", 0)
	FileInstall("Resources\languages\flags\am.gif", $flags_directory & "\am.gif", 0)
	FileInstall("Resources\languages\flags\ar.gif", $flags_directory & "\ar.gif", 0)
	FileInstall("Resources\languages\flags\az.gif", $flags_directory & "\az.gif", 0)
	FileInstall("Resources\languages\flags\be.gif", $flags_directory & "\be.gif", 0)
	FileInstall("Resources\languages\flags\bg.gif", $flags_directory & "\bg.gif", 0)
	FileInstall("Resources\languages\flags\bn.gif", $flags_directory & "\bn.gif", 0)
	FileInstall("Resources\languages\flags\bs.gif", $flags_directory & "\bs.gif", 0)
	FileInstall("Resources\languages\flags\ca.gif", $flags_directory & "\ca.gif", 0)
	FileInstall("Resources\languages\flags\cs.gif", $flags_directory & "\cs.gif", 0)
	FileInstall("Resources\languages\flags\cy.gif", $flags_directory & "\cy.gif", 0)
	FileInstall("Resources\languages\flags\da.gif", $flags_directory & "\da.gif", 0)
	FileInstall("Resources\languages\flags\de.gif", $flags_directory & "\de.gif", 0)
	FileInstall("Resources\languages\flags\el.gif", $flags_directory & "\el.gif", 0)
	FileInstall("Resources\languages\flags\en.gif", $flags_directory & "\en.gif", 0)
	FileInstall("Resources\languages\flags\es.gif", $flags_directory & "\es.gif", 0)
	FileInstall("Resources\languages\flags\et.gif", $flags_directory & "\et.gif", 0)
	FileInstall("Resources\languages\flags\eu.gif", $flags_directory & "\eu.gif", 0)
	FileInstall("Resources\languages\flags\fa.gif", $flags_directory & "\fa.gif", 0)
	FileInstall("Resources\languages\flags\fi.gif", $flags_directory & "\fi.gif", 0)
	FileInstall("Resources\languages\flags\fr.gif", $flags_directory & "\fr.gif", 0)
	FileInstall("Resources\languages\flags\ga.gif", $flags_directory & "\ga.gif", 0)
	FileInstall("Resources\languages\flags\gd.gif", $flags_directory & "\gd.gif", 0)
	FileInstall("Resources\languages\flags\gl.gif", $flags_directory & "\gl.gif", 0)
	FileInstall("Resources\languages\flags\gu.gif", $flags_directory & "\gu.gif", 0)
	FileInstall("Resources\languages\flags\he.gif", $flags_directory & "\he.gif", 0)
	FileInstall("Resources\languages\flags\hi.gif", $flags_directory & "\hi.gif", 0)
	FileInstall("Resources\languages\flags\hr.gif", $flags_directory & "\hr.gif", 0)
	FileInstall("Resources\languages\flags\hu.gif", $flags_directory & "\hu.gif", 0)
	FileInstall("Resources\languages\flags\hy.gif", $flags_directory & "\hy.gif", 0)
	FileInstall("Resources\languages\flags\id.gif", $flags_directory & "\id.gif", 0)
	FileInstall("Resources\languages\flags\is.gif", $flags_directory & "\is.gif", 0)
	FileInstall("Resources\languages\flags\it.gif", $flags_directory & "\it.gif", 0)
	FileInstall("Resources\languages\flags\ja.gif", $flags_directory & "\ja.gif", 0)
	FileInstall("Resources\languages\flags\ka.gif", $flags_directory & "\ka.gif", 0)
	FileInstall("Resources\languages\flags\kk.gif", $flags_directory & "\kk.gif", 0)
	FileInstall("Resources\languages\flags\km.gif", $flags_directory & "\km.gif", 0)
	FileInstall("Resources\languages\flags\kn.gif", $flags_directory & "\kn.gif", 0)
	FileInstall("Resources\languages\flags\ko.gif", $flags_directory & "\ko.gif", 0)
	FileInstall("Resources\languages\flags\ky.gif", $flags_directory & "\ky.gif", 0)
	FileInstall("Resources\languages\flags\lo.gif", $flags_directory & "\lo.gif", 0)
	FileInstall("Resources\languages\flags\lt.gif", $flags_directory & "\lt.gif", 0)
	FileInstall("Resources\languages\flags\lv.gif", $flags_directory & "\lv.gif", 0)
	FileInstall("Resources\languages\flags\mk.gif", $flags_directory & "\mk.gif", 0)
	FileInstall("Resources\languages\flags\ml.gif", $flags_directory & "\ml.gif", 0)
	FileInstall("Resources\languages\flags\mn.gif", $flags_directory & "\mn.gif", 0)
	FileInstall("Resources\languages\flags\mr.gif", $flags_directory & "\mr.gif", 0)
	FileInstall("Resources\languages\flags\ms.gif", $flags_directory & "\ms.gif", 0)
	FileInstall("Resources\languages\flags\ne.gif", $flags_directory & "\ne.gif", 0)
	FileInstall("Resources\languages\flags\nl.gif", $flags_directory & "\nl.gif", 0)
	FileInstall("Resources\languages\flags\no.gif", $flags_directory & "\no.gif", 0)
	FileInstall("Resources\languages\flags\pa.gif", $flags_directory & "\pa.gif", 0)
	FileInstall("Resources\languages\flags\pl.gif", $flags_directory & "\pl.gif", 0)
	FileInstall("Resources\languages\flags\ps.gif", $flags_directory & "\ps.gif", 0)
	FileInstall("Resources\languages\flags\pt.gif", $flags_directory & "\pt.gif", 0)
	FileInstall("Resources\languages\flags\ro.gif", $flags_directory & "\ro.gif", 0)
	FileInstall("Resources\languages\flags\ru.gif", $flags_directory & "\ru.gif", 0)
	FileInstall("Resources\languages\flags\si.gif", $flags_directory & "\si.gif", 0)
	FileInstall("Resources\languages\flags\sk.gif", $flags_directory & "\sk.gif", 0)
	FileInstall("Resources\languages\flags\sl.gif", $flags_directory & "\sl.gif", 0)
	FileInstall("Resources\languages\flags\sq.gif", $flags_directory & "\sq.gif", 0)
	FileInstall("Resources\languages\flags\sr.gif", $flags_directory & "\sr.gif", 0)
	FileInstall("Resources\languages\flags\sv.gif", $flags_directory & "\sv.gif", 0)
	FileInstall("Resources\languages\flags\sw.gif", $flags_directory & "\sw.gif", 0)
	FileInstall("Resources\languages\flags\ta.gif", $flags_directory & "\ta.gif", 0)
	FileInstall("Resources\languages\flags\te.gif", $flags_directory & "\te.gif", 0)
	FileInstall("Resources\languages\flags\th.gif", $flags_directory & "\th.gif", 0)
	FileInstall("Resources\languages\flags\tr.gif", $flags_directory & "\tr.gif", 0)
	FileInstall("Resources\languages\flags\uk.gif", $flags_directory & "\uk.gif", 0)
	FileInstall("Resources\languages\flags\ur.gif", $flags_directory & "\ur.gif", 0)
	FileInstall("Resources\languages\flags\uz.gif", $flags_directory & "\uz.gif", 0)
	FileInstall("Resources\languages\flags\vi.gif", $flags_directory & "\vi.gif", 0)
	FileInstall("Resources\languages\flags\zh.gif", $flags_directory & "\zh.gif", 0)

	FileInstall("Resources\languages\flags\tlh.gif", $flags_directory & "\tlh.gif", 0)

	; Compress the languages directories and files..
	Run(@ComSpec & " /c " & 'compact.exe /C "' & $ini_directory & '"', "", @SW_HIDE)
	Run(@ComSpec & " /c " & 'compact.exe /C "' & $flags_directory & '"', "", @SW_HIDE)
	Run(@ComSpec & " /c " & 'compact.exe /C "' & $ini_directory & "\*.ini", "", @SW_HIDE)
	Run(@ComSpec & " /c " & 'compact.exe /C "' & $flags_directory & "\*.gif", "", @SW_HIDE)

endfunc



#include-once
; Languages.au3 v0.0.1
#include "corzShared.au3"

#cs

  Language Translations for checksum.
  
  checksum is written in English, like code is. Every user facing string instead
  of "some string", is written as _T("some string"), the _T() being our 
  translation macro/function.
  
  The idea behind coding things this way is so that I can keep the full English
  word/phrase inside the code, and have a clue what is going on. The ini stores
  all the translations in their own [language] section, which is the ISO-
  whatever 2+-letter code for each language, e.g. [zh] (Chineses (Simplified)).
	  
	  checksum.ini
	  languages\zh.ini
	  languages\flags\zh.gif

  See inside corzShared.au3 for the main _T() function.	  
  
  There is also a function to handle pre-ini boostrap-type messages in the main
  languages. Sorry if your language isn't there. Feel free to contribute code!

  Usage is straightforward, load the translations with LoadLanguage()
  
  Then, instead of "string", do _T("string") and you get the translated version 
  of that string. To post the string in MsgBox, etc, use _L($my_string_var), 
  which will convert any \n back to proper linebreaks. 
  
  You can transform 1 - 3 variables while translating, like so:
  
	_T("[count] files hashed in [time]s.", "[count]", $files_hashed_count, "[time]", $seconds_elapsed)
  

#ce


;
; LoadLanguage()

; Loads a language translation file and populates the associative array:
; ($translation_dictionary)
;
; We roll our own ini section reader function, bypassing the 32KB limit of 
; INIReadSection() which with UTF-16 is only around 12KB of actual text. 
; Here there are no such limits.
;
func LoadLanguage($my_active_language, $languages_dir)

	debug("MyFunction(my_active_language, languages_dir): " & $my_active_language & "," & $languages_dir & ")...", @ScriptLineNumber, 5)

	local $default_language = "en"
	local $translation_keys = MapKeys($translation_dictionary)
	local $translation_key
	if IsArray($translation_keys) then
		for $translation_key in $translation_keys
			MapRemove($translation_dictionary, $translation_key)
		next
	endif

    local $language_file = $languages_dir & "\" & $my_active_language & ".ini"
    if not FileExists($language_file) then return $default_language
    debug("LOADING LANGUAGE::: --->" & $my_active_language & "<=", @ScriptLineNumber, 5)
	
	; Only UTF-16 LE BOM is allowed..
	if not CheckFileEncoding($language_file, $FO_UTF16_LE) then
		$my_msg = "Cannot load language file!"
		MsgBox($MB_ICONERROR + $MB_TOPMOST, $my_msg, $my_msg & @LF & @LF & "Please convert your language file to UTF-16 LE + BOM")
		return $default_language
	endif

    local $file_handle = FileOpen($language_file, $FO_UNICODE)
    if $file_handle = -1 then return $default_language

    local $file_content = FileRead($file_handle)
    FileClose($file_handle)

    if $file_content = "" then return $default_language
    debug("Inserting LANGUAGE::: --->" & $my_active_language & "<=", @ScriptLineNumber, 5)

    $file_content = StringReplace($file_content, @CRLF, @LF)
    $file_content = StringReplace($file_content, @CR, @LF)

    local $line_array = StringSplit($file_content, @LF)
    local $in_target_section = false

    for $line_index = 1 to $line_array[0]
        local $current_line = $line_array[$line_index]
        local $trimmed_line = StringStripWS($current_line, $STR_STRIP_ENDS)

		; Skip comments, etc..
        if $trimmed_line = "" or StringLeft($trimmed_line, 1) = ";" or StringLeft($trimmed_line, 1) = "#" then continueloop

        if StringLeft($trimmed_line, 1) = "[" and StringRight($trimmed_line, 1) = "]" and not StringInStr($trimmed_line, "=") then
            local $current_section = StringMid($trimmed_line, 2, StringLen($trimmed_line) - 2)
            $in_target_section = ($current_section = $my_active_language)
            continueloop
        endif

        if $in_target_section then
            local $split_pos = FindLanguageIniSeparator($trimmed_line)
            if not $split_pos then continueloop
            local $key = StringStripWS(StringLeft($trimmed_line, $split_pos - 1), $STR_STRIP_ENDS)
            local $value = StringStripWS(StringMid($trimmed_line, $split_pos + 1), $STR_STRIP_ENDS)

            $key = StringReplace($key, "\n", @LF)
            $value = StringReplace($value, "\n", @LF)
            $value = StringReplace(StringReplace($value, "{{", ""), "}}", "")

			if $key <> "" then $translation_dictionary[$key] = $value
        endif
    next

    debugAAList($translation_dictionary, "Translations:", @ScriptLineNumber, 11)
    return $my_active_language
endfunc


;
; FindLanguageIniSeparator()

; Returns the position of the first "=" outside protected {{...}} and [...] tokens.
;
func FindLanguageIniSeparator($line)

	local $curly_depth = 0
	local $square_depth = 0
	local $character
	local $pair

	for $character_index = 1 to StringLen($line)
		$pair = StringMid($line, $character_index, 2)
		if $pair = "{{" then
			$curly_depth += 1
			$character_index += 1
			continueloop
		endif
		if $pair = "}}" and $curly_depth then
			$curly_depth -= 1
			$character_index += 1
			continueloop
		endif

		$character = StringMid($line, $character_index, 1)
		if $character = "[" and not $curly_depth then
			$square_depth += 1
		elseif $character = "]" and $square_depth and not $curly_depth then
			$square_depth -= 1
		elseif $character = "=" and not $curly_depth and not $square_depth then
			return $character_index
		endif
	next

	return 0
endfunc


;
; CheckFileEncoding()

; Send this function a file path and a target encoding.
; Returns true if the file's encoding matches the target, otherwise false.
;
func CheckFileEncoding($file_path, $target_encoding)
	debug("target_encoding: =>" & $target_encoding & "<=" , @ScriptLineNumber, 5)
    local $files_encoding = FileGetEncoding($file_path)
    if @Error then return false
	debug("files_encoding: =>" & $files_encoding & "<=" , @ScriptLineNumber, 5)
    return ($files_encoding = $target_encoding)
endfunc


;
; GetLanguageWidthMultiplier()

; Returns a multiplier used to adjust the width of the GUI based on the width of
; the language. Works fine for long sentences, but not so good for small words 
; and phrases. User can override this in their prefs, but this gives us a 
; reasonable starting place for each language.
;
func GetLanguageWidthMultiplier($language_code)

	debug("GetLanguageWidthMultiplier() ---> language_code: =>" & $language_code & "<=" , @ScriptLineNumber, 5)

	switch $language_code

		; Measured from the short labels in the Create and Verify options dialogs.
		; Malayalam needs the most room (chiefly "search + verify").
		; case "ml"
			; return 1.70

		case "si"
			return 1.50

		case "hy", "ka", "ml", "ta"
			return 1.40

		case "am", "be", "bg", "mt", "sr", "tg", "tk"
			return 1.30

		case "bn", "de", "el", "ja", "kn", "ky", "mk", "nb", "nn", "no", "ru", "so", "sv", "te", "tl", "tlh", "xh", "zh", "zh-cn", "zh-tw", "zu"
			return 1.20

		case "af", "ar", "az", "bs", "cs", "cy", "es", "eu", "fi", "fil", "fr", "ga", "gd", "gl", "he", "hr", "hu", "is", "kk", "ko", "mn", "mr", "ps", "pt", "sk", "sl", "tr", "uk", "vi"
			return 1.10

		case "ca", "da", "en", "eo", "et", "fa", "gu", "hi", "id", "it", "km", "la", "lo", "lt", "lv", "ms", "ne", "nl", "pa", "pl", "ro", "sq", "sw", "th", "ur", "uz", "yi"
			return 1.00

		case else
			return 1.00
			
	endswitch

endfunc


;
; IsRTLLanguage()

; Send this function a language "code", e.g. "en", and it will simply return
; true if it's an RTL language, false if not.
;
func IsRTLLanguage($language_code)
	local $rtl_languages = IniRead($ini_path, $app_name, "rtl_languages", "ar,bal,ckb,dv,fa,he,ks,ps,sd,syr,ug,ur,yi")
	local $base_code = StringLower(StringRegExpReplace($language_code, "[-_].*$", ""))
	return StringRegExp($rtl_languages, "(?i)(?:^|,)\Q" & $base_code & "\E(?:,|$)") > 0
endfunc


;
; _B()

; Bootstrap message translations.
; Used pre-ini, before languages are loaded.
;
func _B($english_text)

	; We use the user's OS locale to determine which language to present.
    local $language_code = @OSLang

    switch $english_text
	
		case "Select your preferred language"
			switch $language_code
				case "0401", "0801", "0c01", "1001", "1401", "1801", "1c01", "2001" ; Arabic
					return "اختر لغتك المفضلة"
				case "0405" ; Czech
					return "Vyberte svůj preferovaný jazyk"
				case "0407" ; German
					return "Wählen Sie Ihre bevorzugte Sprache"
				case "0408" ; Greek
					return "Επιλέξτε την προτιμώμενη γλώσσα σας"
				case "040a", "0a0a", "0c0a", "100a", "140a" ; Spanish
					return "Seleccione su idioma preferido"
				case "040c" ; French
					return "Sélectionnez votre langue préférée"
				case "040d" ; Hebrew
					return "בחר את השפה המועדפת עליך"
				case "0410" ; Italian
					return "Seleziona la lingua preferita"
				case "0411" ; Japanese
					return "希望する言語を選択してください"
				case "0412" ; Korean
					return "선호하는 언어를 선택하세요"
				case "0413", "0813" ; Dutch
					return "Selecteer uw voorkeurstaal"
				case "0415" ; Polish
					return "Wybierz preferowany język"
				case "0416", "0816" ; Portuguese
					return "Selecione seu idioma preferido"
				case "0419" ; Russian
					return "Выберите предпочитаемый язык"
				case "041d" ; Swedish
					return "Välj ditt föredragna språk"
				case "041e" ; Thai
					return "เลือกภาษาที่คุณต้องการ"
				case "041f" ; Turkish
					return "Tercih ettiğiniz dili seçin"
				case "0421" ; Indonesian
					return "Pilih bahasa pilihan Anda"
				case "0422" ; Ukrainian
					return "Виберіть бажану мову"
				case "042a" ; Vietnamese
					return "Chọn ngôn ngữ ưa thích của bạn"
				case "0439" ; Hindi
					return "अपनी पसंदीदा भाषा चुनें"
				case "0804", "0404", "0c04", "1004" ; Chinese
					return "选择您的首选语言"
			endswitch
			
	
        case "Portable Mode Enabled!"
            switch $language_code
                case "0401", "0801", "0c01", "1001", "1401", "1801", "1c01", "2001" ; Arabic
                    return "تم تمكين الوضع المحمول!"
                case "0405" ; Czech
                    return "Přenosný režim povolen!"
                case "0407" ; German
                    return "Portabler Modus aktiviert!"
                case "0408" ; Greek
                    return "Η φορητή λειτουργία ενεργοποιήθηκε!"
                case "040a", "0a0a", "0c0a", "100a", "140a" ; Spanish
                    return "¡Modo portable activado!"
                case "040c" ; French
                    return "Mode portable activé !"
                case "040d" ; Hebrew
                    return "!מצב נייד מופעל"
                case "0410" ; Italian
                    return "Modalità portatile attivata!"
                case "0411" ; Japanese
                    return "ポータブルモードが有効です！"
                case "0412" ; Korean
                    return "휴대용 모드가 활성화되었습니다!"
                case "0413", "0813" ; Dutch
                    return "Draagbare modus ingeschakeld!"
                case "0415" ; Polish
                    return "Tryb przenośny włączony!"
                case "0416", "0816" ; Portuguese
                    return "Modo portátil ativado!"
                case "0419" ; Russian
                    return "Портативный режим включен!"
                case "041d" ; Swedish
                    return "Bärbart läge aktiverat!"
                case "041e" ; Thai
                    return "เปิดใช้งานโหมดพกพาแล้ว!"
                case "041f" ; Turkish
                    return "Taşınabilir Mod Etkinleştirildi!"
                case "0421" ; Indonesian
                    return "Mode Portabel Diaktifkan!"
                case "0422" ; Ukrainian
                    return "Портативний режим увімкнено!"
                case "042a" ; Vietnamese
                    return "Chế độ di động đã được bật!"
                case "0439" ; Hindi
                    return "पोर्टेबल मोड सक्षम है!"
                case "0804", "0404", "0c04", "1004" ; Chinese
                    return "便携模式已启用！"
            endswitch

        case "Portable Mode NOT Enabled!"
            switch $language_code
                case "0401", "0801", "0c01", "1001", "1401", "1801", "1c01", "2001" ; Arabic
                    return "الوضع المحمول غير مُمكّن!"
                case "0405" ; Czech
                    return "Přenosný režim NEBYL povolen!"
                case "0407" ; German
                    return "Portabler Modus NICHT aktiviert!"
                case "0408" ; Greek
                    return "Η φορητή λειτουργία ΔΕΝ ενεργοποιήθηκε!"
                case "040a", "0a0a", "0c0a", "100a", "140a" ; Spanish
                    return "¡Modo portable NO activado!"
                case "040c" ; French
                    return "Mode portable NON activé !"
                case "040d" ; Hebrew
                    return "!מצב נייד לא מופעל"
                case "0410" ; Italian
                    return "Modalità portatile NON attivata!"
                case "0411" ; Japanese
                    return "ポータブルモードが有効ではありません！"
                case "0412" ; Korean
                    return "휴대용 모드가 활성화되지 않았습니다!"
                case "0413", "0813" ; Dutch
                    return "Draagbare modus NIET ingeschakeld!"
                case "0415" ; Polish
                    return "Tryb przenośny NIE włączony!"
                case "0416", "0816" ; Portuguese
                    return "Modo portátil NÃO ativado!"
                case "0419" ; Russian
                    return "Портативный режим НЕ включен!"
                case "041d" ; Swedish
                    return "Bärbart läge INTE aktiverat!"
                case "041e" ; Thai
                    return "โหมดพกพายังไม่ได้เปิดใช้งาน!"
                case "041f" ; Turkish
                    return "Taşınabilir Mod Etkinleştirilmedi!"
                case "0421" ; Indonesian
                    return "Mode Portabel TIDAK Diaktifkan!"
                case "0422" ; Ukrainian
                    return "Портативний режим НЕ увімкнено!"
                case "042a" ; Vietnamese
                    return "Chế độ di động CHƯA được bật!"
                case "0439" ; Hindi
                    return "पोर्टेबल मोड सक्षम नहीं है!"
                case "0804", "0404", "0c04", "1004" ; Chinese
                    return "便携模式未启用！"
            endswitch

        case "Check your folder permissions"
            switch $language_code
                case "0401", "0801", "0c01", "1001", "1401", "1801", "1c01", "2001" ; Arabic
                    return "تحقق من أذونات المجلد الخاص بك"
                case "0405" ; Czech
                    return "Zkontrolujte oprávnění složky"
                case "0407" ; German
                    return "Überprüfen Sie Ihre Ordnerberechtigungen"
                case "0408" ; Greek
                    return "Ελέγξτε τα δικαιώματα του φακέλου σας"
                case "040a", "0a0a", "0c0a", "100a", "140a" ; Spanish
                    return "Compruebe los permisos de su carpeta"
                case "040c" ; French
                    return "Vérifiez les autorisations de votre dossier"
                case "040d" ; Hebrew
                    return "בדוק את הרשאות התיקייה שלך"
                case "0410" ; Italian
                    return "Controlla le autorizzazioni della cartella"
                case "0411" ; Japanese
                    return "フォルダのアクセス許可を確認してください"
                case "0412" ; Korean
                    return "폴더 권한을 확인하십시오"
                case "0413", "0813" ; Dutch
                    return "Controleer uw mapmachtigingen"
                case "0415" ; Polish
                    return "Sprawdź uprawnienia do folderu"
                case "0416", "0816" ; Portuguese
                    return "Verifique as permissões da sua pasta"
                case "0419" ; Russian
                    return "Проверьте разрешения для папки"
                case "041d" ; Swedish
                    return "Kontrollera dina mappersbehörigheter"
                case "041e" ; Thai
                    return "โปรดตรวจสอบสิทธิ์ของโฟลเดอร์ของคุณ"
                case "041f" ; Turkish
                    return "Klasör izinlerinizi kontrol edin"
                case "0421" ; Indonesian
                    return "Periksa izin folder Anda"
                case "0422" ; Ukrainian
                    return "Перевірте дозволи для папки"
                case "042a" ; Vietnamese
                    return "Kiểm tra quyền truy cập thư mục của bạn"
                case "0439" ; Hindi
                    return "अपने फ़ोल्डर की अनुमति जाँचें"
                case "0804", "0404", "0c04", "1004" ; Chinese
                    return "请检查您的文件夹权限"
            endswitch

        case "checksum.ini is missing"
            switch $language_code
                case "0401", "0801", "0c01", "1001", "1401", "1801", "1c01", "2001" ; Arabic
                    return "checksum.ini مفقود"
                case "0405" ; Czech
                    return "checksum.ini chybí"
                case "0407" ; German
                    return "checksum.ini fehlt"
                case "0408" ; Greek
                    return "Το checksum.ini λείπει"
                case "040a", "0a0a", "0c0a", "100a", "140a" ; Spanish
                    return "No se encuentra checksum.ini"
                case "040c" ; French
                    return "checksum.ini est introuvable"
                case "040d" ; Hebrew
                    return "checksum.ini חסר"
                case "0410" ; Italian
                    return "checksum.ini non trovato"
                case "0411" ; Japanese
                    return "checksum.ini が見つかりません"
                case "0412" ; Korean
                    return "checksum.ini 파일이 없습니다"
                case "0413", "0813" ; Dutch
                    return "checksum.ini ontbreekt"
                case "0415" ; Polish
                    return "Brak pliku checksum.ini"
                case "0416", "0816" ; Portuguese
                    return "checksum.ini não foi encontrado"
                case "0419" ; Russian
                    return "Файл checksum.ini не найден"
                case "041d" ; Swedish
                    return "checksum.ini saknas"
                case "041e" ; Thai
                    return "ไม่พบไฟล์ checksum.ini"
                case "041f" ; Turkish
                    return "checksum.ini eksik"
                case "0421" ; Indonesian
                    return "checksum.ini tidak ditemukan"
                case "0422" ; Ukrainian
                    return "checksum.ini відсутній"
                case "042a" ; Vietnamese
                    return "Thiếu tệp checksum.ini"
                case "0439" ; Hindi
                    return "checksum.ini गायब है"
                case "0804", "0404", "0c04", "1004" ; Chinese
                    return "未找到 checksum.ini"
            endswitch

        case "checksum is unable to write a new checksum.ini"
            switch $language_code
                case "0401", "0801", "0c01", "1001", "1401", "1801", "1c01", "2001" ; Arabic
                    return "لا يمكن لـ checksum كتابة ملف checksum.ini جديد"
                case "0405" ; Czech
                    return "checksum nemůže zapsat nový checksum.ini"
                case "0407" ; German
                    return "checksum kann keine neue checksum.ini schreiben"
                case "0408" ; Greek
                    return "Το checksum δεν μπορεί να εγράψει νέο αρχείο checksum.ini"
                case "040a", "0a0a", "0c0a", "100a", "140a" ; Spanish
                    return "checksum no puede escribir un nuevo archivo checksum.ini"
                case "040c" ; French
                    return "checksum est incapable d'écrire un nouveau fichier checksum.ini"
                case "040d" ; Hebrew
                    return "checksum אינו יכול לכתוב קובץ checksum.ini חדש"
                case "0410" ; Italian
                    return "checksum non è in grado di scrivere un nuovo file checksum.ini"
                case "0411" ; Japanese
                    return "checksum は新しい checksum.ini ファイルを書き込むことができません"
                case "0412" ; Korean
                    return "checksum이 새 checksum.ini 파일을 쓸 수 없습니다"
                case "0413", "0813" ; Dutch
                    return "checksum kan geen nieuw checksum.ini-bestand schrijven"
                case "0415" ; Polish
                    return "checksum nie może zapisać nowego pliku checksum.ini"
                case "0416", "0816" ; Portuguese
                    return "checksum não consegue escrever um novo arquivo checksum.ini"
                case "0419" ; Russian
                    return "checksum не может записать новый файл checksum.ini"
                case "041d" ; Swedish
                    return "checksum kan inte skriva en ny checksum.ini"
                case "041e" ; Thai
                    return "checksum ไม่สามารถเขียนไฟล์ checksum.ini ใหม่ได้"
                case "041f" ; Turkish
                    return "checksum yeni bir checksum.ini dosyası yazamıyor"
                case "0421" ; Indonesian
                    return "checksum tidak dapat menulis file checksum.ini baru"
                case "0422" ; Ukrainian
                    return "checksum не може записати новий файл checksum.ini"
                case "042a" ; Vietnamese
                    return "checksum không thể ghi tệp checksum.ini mới"
                case "0439" ; Hindi
                    return "checksum एक नया checksum.ini लिखने में असमर्थ है"
                case "0804", "0404", "0c04", "1004" ; Chinese
                    return "checksum 无法写入新的 checksum.ini 文件"
            endswitch

        case "Please ensure your data folder is writable!"
            switch $language_code
                case "0401", "0801", "0c01", "1001", "1401", "1801", "1c01", "2001" ; Arabic
                    return "يرجى التأكد من أن مجلد البيانات قابل للكتابة!"
                case "0405" ; Czech
                    return "Ujistěte se, že do datové složky lze zapisovat!"
                case "0407" ; German
                    return "Bitte stellen Sie sicher, dass Ihr Datenordner beschreibbar ist!"
                case "0408" ; Greek
                    return "Βεβαιωθείτε ότι ο φάκελος δεδομένων είναι εγγράψιμος!"
                case "040a", "0a0a", "0c0a", "100a", "140a" ; Spanish
                    return "¡Asegúrese de que su carpeta de datos sea de escritura!"
                case "040c" ; French
                    return "Veuillez vous assurer que votre dossier de données est accessible en écriture !"
                case "040d" ; Hebrew
                    return "!אנא ודא שתיקיית הנתונים שלך ניתנת לכתיבה"
                case "0410" ; Italian
                    return "Assicurati che la cartella dei dati sia scrivibile!"
                case "0411" ; Japanese
                    return "データフォルダが書き込み可能であることを確認してください！"
                case "0412" ; Korean
                    return "데이터 폴더에 쓰기 권한이 있는지 확인하십시오!"
                case "0413", "0813" ; Dutch
                    return "Zorg ervoor dat uw gegevensmap beschrijfbaar is!"
                case "0415" ; Polish
                    return "Upewnij się, że folder danych jest zapisywalny!"
                case "0416", "0816" ; Portuguese
                    return "Certifique-se de que sua pasta de dados permite escrita!"
                case "0419" ; Russian
                    return "Убедитесь, что ваша папка данных доступна для записи!"
                case "041d" ; Swedish
                    return "Se till att din datamapp är skrivbar!"
                case "041e" ; Thai
                    return "โปรดตรวจสอบให้แน่ใจว่าโฟลเดอร์ข้อมูลของคุณสามารถเขียนได้!"
                case "041f" ; Turkish
                    return "Lütfen veri klasörünüzün yazılabilir olduğundan emin olun!"
                case "0421" ; Indonesian
                    return "Pastikan folder data Anda dapat ditulis!"
                case "0422" ; Ukrainian
                    return "Переконайтеся, що папка даних доступна для запису!"
                case "042a" ; Vietnamese
                    return "Vui lòng đảm bảo thư mục dữ liệu có quyền ghi!"
                case "0439" ; Hindi
                    return "कृपया सुनिश्चित करें कि आपका डेटा फ़ोल्डर लिखने योग्य है!"
                case "0804", "0404", "0c04", "1004" ; Chinese
                    return "请确保您的数据文件夹可写！"
            endswitch

        case "checksum cannot continue"
            switch $language_code
                case "0401", "0801", "0c01", "1001", "1401", "1801", "1c01", "2001" ; Arabic
                    return "لا يمكن لـ checksum الاستمرار"
                case "0405" ; Czech
                    return "checksum nemůže pokračovat"
                case "0407" ; German
                    return "checksum kann nicht fortgesetzt werden"
                case "0408" ; Greek
                    return "Το checksum δεν μπορεί να συνεχίσει"
                case "040a", "0a0a", "0c0a", "100a", "140a" ; Spanish
                    return "checksum no puede continuar"
                case "040c" ; French
                    return "checksum ne peut pas continuer"
                case "040d" ; Hebrew
                    return "checksum אינו יכול להמשיך"
                case "0410" ; Italian
                    return "checksum non può continuare"
                case "0411" ; Japanese
                    return "checksum 処理を継続できません"
                case "0412" ; Korean
                    return "checksum을 계속할 수 없습니다"
                case "0413", "0813" ; Dutch
                    return "checksum kan niet doorgaan"
                case "0415" ; Polish
                    return "checksum nie może kontynuować"
                case "0416", "0816" ; Portuguese
                    return "checksum não pode continuar"
                case "0419" ; Russian
                    return "checksum не может продолжить работу"
                case "041d" ; Swedish
                    return "checksum kan inte fortsätta"
                case "041e" ; Thai
                    return "checksum ไม่สามารถดำเนินการต่อได้"
                case "041f" ; Turkish
                    return "checksum devam edemiyor"
                case "0421" ; Indonesian
                    return "checksum tidak dapat melanjutkan"
                case "0422" ; Ukrainian
                    return "checksum не може продовжувати"
                case "042a" ; Vietnamese
                    return "checksum không thể tiếp tục"
                case "0439" ; Hindi
                    return "checksum जारी नहीं रह सकता"
                case "0804", "0404", "0c04", "1004" ; Chinese
                    return "checksum 无法继续"
            endswitch
    endswitch

    return $english_text

endfunc


#cs

Language Code Mapping

  af = Afrikaans
  am = Amharic
  ar = Arabic
  az = Azerbaijani
  be = Belarusian
  bg = Bulgarian
  bn = Bengali
  bs = Bosnian
  ca = Catalan
  cs = Czech
  cy = Welsh
  da = Danish
  de = German
  el = Greek
  es = Spanish
  et = Estonian
  eu = Basque
  fa = Persian
  fi = Finnish
  fr = French
  ga = Irish
  gd = Gaelic
  gl = Galician
  gu = Gujarati
  he = Hebrew
  hi = Hindi
  hr = Croatian
  hu = Hungarian
  hy = Armenian
  id = Indonesian
  is = Icelandic
  it = Italian
  ja = Japanese
  ka = Georgian
  kk = Kazakh
  km = Khmer
  kn = Kannada
  ko = Korean
  ky = Kyrgyz
  lo = Lao
  lt = Lithuanian
  lv = Latvian
  mk = Macedonian
  ml = Malayalam
  mn = Mongolian
  mr = Marathi
  ms = Malay
  ne = Nepali
  nl = Dutch
  no = Norwegian
  pa = Punjabi
  pl = Polish
  ps = Pashto
  pt = Portuguese
  ro = Romanian
  ru = Russian
  si = Sinhala
  sk = Slovak
  sl = Slovenian
  sq = Albanian
  sr = Serbian
  sv = Swedish
  sw = Swahili
  ta = Tamil
  te = Telugu
  th = Thai
  tr = Turkish
  uk = Ukrainian
  ur = Urdu
  uz = Uzbek
  vi = Vietnamese
  zh = Chinese (Simplified)
  
  tlh = Klingon

#ce

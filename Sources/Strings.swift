import Foundation

/// UI text in the same 43 languages as the other Atypical Maker apps, following the system
/// language. Each row of `table` lists the strings in the order of the properties below;
/// Quit carries the wording of Screen Light and Timer.
struct Strings {
    private let v: [String]

    var on: String { v[0] }
    var sound: String { v[1] }
    var creak: String { v[2] }
    var squeak: String { v[3] }
    var volume: String { v[4] }
    var folder: String { v[5] }
    var folderHint: String { v[6] }
    var noSensor: String { v[7] }
    var quit: String { v[8] }
    var menuBar: String { v[9] }
    var icon: String { v[10] }
    var angle: String { v[11] }
    var angleInIcon: String { v[12] }
    /// What macOS shows over the menu bar icon, like the battery's "Battery (100%)".
    func lidAngle(_ degrees: Int) -> String { String(format: v[13], "\(degrees)°") }

    private static let count = 14

    static func `for`(_ code: String) -> Strings {
        let row = table[code] ?? []
        return Strings(v: row.count == count ? row : table["en"]!)
    }

    /// First of the system's preferred languages that we have.
    static var detected: String {
        for id in Locale.preferredLanguages {
            if table[id] != nil { return id }
            let lang = Locale.Language(identifier: id)
            guard let code = lang.languageCode?.identifier else { continue }
            if code == "zh" {
                let hant = lang.script?.identifier == "Hant" || ["TW", "HK", "MO"].contains(lang.region?.identifier ?? "")
                return hant ? "zh-Hant" : "zh-Hans"
            }
            if code == "no" || code == "nn" { return "nb" }
            if table[code] != nil { return code }
        }
        return "en"
    }

    static let table: [String: [String]] = [
        "en": ["Play while the lid moves", "Sound", "Creak", "Squeak", "Volume", "Open Sounds Folder", "Every audio file in it (WAV, M4A, MP3, AIFF) becomes a sound in the list. It plays in a loop while the lid moves.", "This Mac has no lid angle sensor.", "Quit", "Menu Bar", "Icon", "Angle", "Angle in Icon", "Lid angle: %@"],
        "pl": ["Graj, gdy klapa się rusza", "Dźwięk", "Skrzypienie", "Piszczenie", "Głośność", "Otwórz folder z dźwiękami", "Każdy plik dźwiękowy w nim (WAV, M4A, MP3, AIFF) staje się dźwiękiem na liście. Gra w pętli, gdy klapa się rusza.", "Ten Mac nie ma czujnika kąta klapy.", "Zakończ", "Pasek menu", "Ikona", "Kąt", "Kąt w ikonie", "Kąt klapy: %@"],
        "de": ["Abspielen, wenn sich der Deckel bewegt", "Ton", "Knarren", "Quietschen", "Lautstärke", "Ordner „Töne“ öffnen", "Jede Audiodatei darin (WAV, M4A, MP3, AIFF) wird zu einem Ton in der Liste. Er spielt in Schleife, solange sich der Deckel bewegt.", "Dieser Mac hat keinen Deckelwinkelsensor.", "Beenden", "Menüleiste", "Symbol", "Winkel", "Winkel im Symbol", "Deckelwinkel: %@"],
        "fr": ["Jouer quand l’écran bouge", "Son", "Grincement", "Couinement", "Volume", "Ouvrir le dossier des sons", "Chaque fichier audio qu’il contient (WAV, M4A, MP3, AIFF) devient un son de la liste. Il joue en boucle tant que l’écran bouge.", "Ce Mac n’a pas de capteur d’angle d’écran.", "Quitter", "Barre des menus", "Icône", "Angle", "Angle dans l’icône", "Angle de l’écran : %@"],
        "es": ["Sonar al mover la tapa", "Sonido", "Crujido", "Chirrido", "Volumen", "Abrir carpeta de sonidos", "Cada archivo de audio que contenga (WAV, M4A, MP3, AIFF) se convierte en un sonido de la lista. Suena en bucle mientras la tapa se mueve.", "Este Mac no tiene sensor de ángulo de la tapa.", "Salir", "Barra de menús", "Icono", "Ángulo", "Ángulo en el icono", "Ángulo de la tapa: %@"],
        "pt": ["Tocar quando a tampa se move", "Som", "Rangido", "Chiado", "Volume", "Abrir pasta de sons", "Cada ficheiro de áudio nela (WAV, M4A, MP3, AIFF) passa a ser um som da lista. Toca em ciclo enquanto a tampa se move.", "Este Mac não tem sensor de ângulo da tampa.", "Sair", "Barra de menus", "Ícone", "Ângulo", "Ângulo no ícone", "Ângulo da tampa: %@"],
        "it": ["Suona quando il coperchio si muove", "Suono", "Scricchiolio", "Cigolio", "Volume", "Apri cartella suoni", "Ogni file audio al suo interno (WAV, M4A, MP3, AIFF) diventa un suono dell’elenco. Suona in loop mentre il coperchio si muove.", "Questo Mac non ha il sensore dell’angolo del coperchio.", "Esci", "Barra dei menu", "Icona", "Angolo", "Angolo nell’icona", "Angolo del coperchio: %@"],
        "nl": ["Afspelen als de klep beweegt", "Geluid", "Kraken", "Piepen", "Volume", "Open geluidenmap", "Elk audiobestand erin (WAV, M4A, MP3, AIFF) wordt een geluid in de lijst. Het speelt in een lus zolang de klep beweegt.", "Deze Mac heeft geen klephoeksensor.", "Stop", "Menubalk", "Symbool", "Hoek", "Hoek in symbool", "Klephoek: %@"],
        "sv": ["Spela när locket rör sig", "Ljud", "Knarr", "Gnissel", "Volym", "Öppna ljudmappen", "Varje ljudfil i den (WAV, M4A, MP3, AIFF) blir ett ljud i listan. Det spelas i en slinga medan locket rör sig.", "Den här Macen har ingen sensor för lockets vinkel.", "Avsluta", "Menyrad", "Symbol", "Vinkel", "Vinkel i symbolen", "Lockets vinkel: %@"],
        "da": ["Afspil, når låget bevæger sig", "Lyd", "Knirken", "Hvin", "Lydstyrke", "Åbn lydmappen", "Hver lydfil i den (WAV, M4A, MP3, AIFF) bliver en lyd på listen. Den spiller i loop, mens låget bevæger sig.", "Denne Mac har ingen sensor til lågets vinkel.", "Slut", "Menulinje", "Symbol", "Vinkel", "Vinkel i symbolet", "Lågets vinkel: %@"],
        "nb": ["Spill når lokket beveger seg", "Lyd", "Knirk", "Pip", "Volum", "Åpne lydmappen", "Hver lydfil i den (WAV, M4A, MP3, AIFF) blir en lyd i listen. Den spilles i loop mens lokket beveger seg.", "Denne Macen har ingen sensor for lokkets vinkel.", "Avslutt", "Menylinje", "Symbol", "Vinkel", "Vinkel i symbolet", "Lokkets vinkel: %@"],
        "fi": ["Soita, kun kansi liikkuu", "Ääni", "Narina", "Vinkuna", "Äänenvoimakkuus", "Avaa äänikansio", "Jokaisesta sen äänitiedostosta (WAV, M4A, MP3, AIFF) tulee ääni luetteloon. Se soi silmukkana, kun kansi liikkuu.", "Tässä Macissa ei ole kannen kulma-anturia.", "Lopeta", "Valikkorivi", "Kuvake", "Kulma", "Kulma kuvakkeessa", "Kannen kulma: %@"],
        "is": ["Spila þegar lokið hreyfist", "Hljóð", "Brak", "Ískur", "Hljóðstyrkur", "Opna hljóðamöppu", "Hver hljóðskrá í henni (WAV, M4A, MP3, AIFF) verður hljóð á listanum. Það spilast í lykkju meðan lokið hreyfist.", "Þessi Mac er ekki með skynjara fyrir horn loksins.", "Hætta", "Valmyndarstika", "Tákn", "Horn", "Horn í tákni", "Horn loksins: %@"],
        "cs": ["Hrát při pohybu víka", "Zvuk", "Vrzání", "Pískání", "Hlasitost", "Otevřít složku zvuků", "Každý zvukový soubor v ní (WAV, M4A, MP3, AIFF) se stane zvukem v seznamu. Hraje ve smyčce, dokud se víko hýbe.", "Tento Mac nemá snímač úhlu víka.", "Ukončit", "Řádek nabídek", "Ikona", "Úhel", "Úhel v ikoně", "Úhel víka: %@"],
        "sk": ["Hrať pri pohybe veka", "Zvuk", "Vŕzganie", "Pískanie", "Hlasitosť", "Otvoriť priečinok zvukov", "Každý zvukový súbor v ňom (WAV, M4A, MP3, AIFF) sa stane zvukom v zozname. Hrá v slučke, kým sa veko hýbe.", "Tento Mac nemá snímač uhla veka.", "Ukončiť", "Lišta menu", "Ikona", "Uhol", "Uhol v ikone", "Uhol veka: %@"],
        "sl": ["Predvajaj, ko se pokrov premika", "Zvok", "Škripanje", "Cviljenje", "Glasnost", "Odpri mapo z zvoki", "Vsaka zvočna datoteka v njej (WAV, M4A, MP3, AIFF) postane zvok na seznamu. Predvaja se v zanki, dokler se pokrov premika.", "Ta Mac nima senzorja kota pokrova.", "Izhod", "Menijska vrstica", "Ikona", "Kot", "Kot v ikoni", "Kot pokrova: %@"],
        "hr": ["Sviraj dok se poklopac pomiče", "Zvuk", "Škripa", "Cviljenje", "Glasnoća", "Otvori mapu zvukova", "Svaka zvučna datoteka u njoj (WAV, M4A, MP3, AIFF) postaje zvuk na popisu. Svira u petlji dok se poklopac pomiče.", "Ovaj Mac nema senzor kuta poklopca.", "Zatvori", "Traka izbornika", "Ikona", "Kut", "Kut u ikoni", "Kut poklopca: %@"],
        "sr": ["Пуштај док се поклопац помера", "Звук", "Шкрипа", "Цвиљење", "Јачина звука", "Отвори фасциклу звукова", "Свака аудио датотека у њој (WAV, M4A, MP3, AIFF) постаје звук на листи. Пушта се у петљи док се поклопац помера.", "Овај Mac нема сензор угла поклопца.", "Изађи", "Трака менија", "Икона", "Угао", "Угао у икони", "Угао поклопца: %@"],
        "bg": ["Звук при движение на капака", "Звук", "Скърцане", "Писукане", "Сила на звука", "Отвори папката със звуци", "Всеки аудиофайл в нея (WAV, M4A, MP3, AIFF) става звук в списъка. Звучи в цикъл, докато капакът се движи.", "Този Mac няма сензор за ъгъла на капака.", "Изход", "Лента с менюта", "Икона", "Ъгъл", "Ъгъл в иконата", "Ъгъл на капака: %@"],
        "ro": ["Redă când capacul se mișcă", "Sunet", "Scârțâit", "Chițăit", "Volum", "Deschide dosarul cu sunete", "Fiecare fișier audio din el (WAV, M4A, MP3, AIFF) devine un sunet din listă. Se redă în buclă cât timp capacul se mișcă.", "Acest Mac nu are senzor pentru unghiul capacului.", "Închideți aplicația", "Bara de meniu", "Pictogramă", "Unghi", "Unghi în pictogramă", "Unghiul capacului: %@"],
        "hu": ["Lejátszás, amikor a fedél mozog", "Hang", "Nyikorgás", "Csikorgás", "Hangerő", "Hangok mappa megnyitása", "Minden benne lévő hangfájl (WAV, M4A, MP3, AIFF) hang lesz a listában. Ismétlődve szól, amíg a fedél mozog.", "Ebben a Macben nincs fedélszög-érzékelő.", "Kilépés", "Menüsor", "Ikon", "Szög", "Szög az ikonban", "Fedélszög: %@"],
        "el": ["Αναπαραγωγή όταν κινείται το καπάκι", "Ήχος", "Τρίξιμο", "Στρίγκλισμα", "Ένταση", "Άνοιγμα φακέλου ήχων", "Κάθε αρχείο ήχου μέσα του (WAV, M4A, MP3, AIFF) γίνεται ήχος στη λίστα. Παίζει σε επανάληψη όσο κινείται το καπάκι.", "Αυτό το Mac δεν έχει αισθητήρα γωνίας καπακιού.", "Τερματισμός", "Γραμμή μενού", "Εικονίδιο", "Γωνία", "Γωνία στο εικονίδιο", "Γωνία καπακιού: %@"],
        "tr": ["Kapak hareket edince çal", "Ses", "Gıcırtı", "Cıyaklama", "Ses Düzeyi", "Sesler Klasörünü Aç", "İçindeki her ses dosyası (WAV, M4A, MP3, AIFF) listede bir ses olur. Kapak hareket ettiği sürece döngüde çalar.", "Bu Mac’te kapak açısı sensörü yok.", "Çık", "Menü Çubuğu", "Simge", "Açı", "Simgede Açı", "Kapak açısı: %@"],
        "uk": ["Грати, коли кришка рухається", "Звук", "Скрип", "Писк", "Гучність", "Відкрити папку звуків", "Кожен аудіофайл у ній (WAV, M4A, MP3, AIFF) стає звуком у списку. Він грає по колу, поки кришка рухається.", "Цей Mac не має датчика кута кришки.", "Завершити", "Рядок меню", "Іконка", "Кут", "Кут в іконці", "Кут кришки: %@"],
        "ru": ["Играть, когда крышка движется", "Звук", "Скрип", "Писк", "Громкость", "Открыть папку звуков", "Каждый аудиофайл в ней (WAV, M4A, MP3, AIFF) становится звуком в списке. Он играет по кругу, пока крышка движется.", "У этого Mac нет датчика угла крышки.", "Завершить", "Строка меню", "Значок", "Угол", "Угол в значке", "Угол крышки: %@"],
        "be": ["Іграць, калі вечка рухаецца", "Гук", "Рыпенне", "Піск", "Гучнасць", "Адкрыць папку гукаў", "Кожны аўдыяфайл у ёй (WAV, M4A, MP3, AIFF) становіцца гукам у спісе. Ён грае па коле, пакуль вечка рухаецца.", "У гэтага Mac няма датчыка вугла вечка.", "Выйсці", "Радок меню", "Значок", "Вугал", "Вугал у значку", "Вугал вечка: %@"],
        "lt": ["Groti, kai dangtis juda", "Garsas", "Girgždėjimas", "Cypimas", "Garsumas", "Atidaryti garsų aplanką", "Kiekvienas jame esantis garso failas (WAV, M4A, MP3, AIFF) tampa garsu sąraše. Jis groja ratu, kol dangtis juda.", "Šis „Mac“ neturi dangčio kampo jutiklio.", "Baigti", "Meniu juosta", "Piktograma", "Kampas", "Kampas piktogramoje", "Dangčio kampas: %@"],
        "lv": ["Atskaņot, kad vāks kustas", "Skaņa", "Čīkstēšana", "Pīkstēšana", "Skaļums", "Atvērt skaņu mapi", "Katrs tajā esošais audiofails (WAV, M4A, MP3, AIFF) kļūst par skaņu sarakstā. Tā skan cilpā, kamēr vāks kustas.", "Šim Mac nav vāka leņķa sensora.", "Iziet", "Izvēļņu josla", "Ikona", "Leņķis", "Leņķis ikonā", "Vāka leņķis: %@"],
        "et": ["Mängi, kui kaas liigub", "Heli", "Kriuksumine", "Kiunumine", "Helitugevus", "Ava helide kaust", "Iga selles olev helifail (WAV, M4A, MP3, AIFF) saab loendis heliks. See mängib kordusena, kuni kaas liigub.", "Sellel Macil pole kaane nurga andurit.", "Lõpeta", "Menüüriba", "Ikoon", "Nurk", "Nurk ikoonis", "Kaane nurk: %@"],
        "ca": ["Sona quan la tapa es mou", "So", "Cruixit", "Xerric", "Volum", "Obre la carpeta de sons", "Cada fitxer d’àudio que contingui (WAV, M4A, MP3, AIFF) es converteix en un so de la llista. Sona en bucle mentre la tapa es mou.", "Aquest Mac no té sensor d’angle de la tapa.", "Surt", "Barra de menús", "Icona", "Angle", "Angle a la icona", "Angle de la tapa: %@"],
        "ar": ["التشغيل عند تحريك الغطاء", "الصوت", "صرير", "صفير", "مستوى الصوت", "فتح مجلد الأصوات", "كل ملف صوتي فيه (WAV وM4A وMP3 وAIFF) يصبح صوتًا في القائمة، ويُشغَّل بشكل متكرر أثناء تحريك الغطاء.", "لا يحتوي جهاز Mac هذا على مستشعر زاوية الغطاء.", "إنهاء", "شريط القائمة", "أيقونة", "الزاوية", "الزاوية في الأيقونة", "زاوية الغطاء: %@"],
        "he": ["השמע כשהמכסה זז", "צליל", "חריקה", "ציוץ", "עוצמת שמע", "פתח את תיקיית הצלילים", "כל קובץ שמע בה (WAV,‏ M4A,‏ MP3,‏ AIFF) הופך לצליל ברשימה. הוא מתנגן בלולאה כל עוד המכסה זז.", "ל־Mac הזה אין חיישן זווית מכסה.", "סיום", "שורת התפריטים", "צלמית", "זווית", "זווית בצלמית", "זווית המכסה: %@"],
        "fa": ["پخش هنگام حرکت درب", "صدا", "جیرجیر", "جیغ", "بلندی صدا", "باز کردن پوشهٔ صداها", "هر فایل صوتی داخل آن (WAV، M4A، MP3، AIFF) یک صدا در فهرست می‌شود و تا وقتی درب حرکت می‌کند تکرار می‌شود.", "این Mac حسگر زاویهٔ درب ندارد.", "خروج", "نوار منو", "نماد", "زاویه", "زاویه در نماد", "زاویهٔ درب: %@"],
        "hi": ["ढक्कन हिलने पर बजाएँ", "ध्वनि", "चरमराहट", "चीं-चीं", "वॉल्यूम", "ध्वनि फ़ोल्डर खोलें", "इसमें हर ऑडियो फ़ाइल (WAV, M4A, MP3, AIFF) सूची में एक ध्वनि बन जाती है। ढक्कन हिलने तक यह लूप में बजती है।", "इस Mac में ढक्कन कोण सेंसर नहीं है।", "बंद करें", "मेनू बार", "आइकन", "कोण", "आइकन में कोण", "ढक्कन का कोण: %@"],
        "bn": ["ঢাকনা নড়লে বাজাও", "শব্দ", "ক্যাঁচক্যাঁচ", "চিঁচিঁ", "ভলিউম", "শব্দের ফোল্ডার খুলুন", "এতে থাকা প্রতিটি অডিও ফাইল (WAV, M4A, MP3, AIFF) তালিকায় একটি শব্দ হয়ে যায়। ঢাকনা নড়া পর্যন্ত এটি লুপে বাজে।", "এই Mac-এ ঢাকনার কোণ সেন্সর নেই।", "বন্ধ করুন", "মেনু বার", "আইকন", "কোণ", "আইকনে কোণ", "ঢাকনার কোণ: %@"],
        "th": ["เล่นเมื่อฝาพับขยับ", "เสียง", "เสียงเอี๊ยด", "เสียงแหลม", "ระดับเสียง", "เปิดโฟลเดอร์เสียง", "ไฟล์เสียงแต่ละไฟล์ในนั้น (WAV, M4A, MP3, AIFF) จะกลายเป็นเสียงในรายการ และเล่นวนซ้ำขณะที่ฝาพับขยับ", "Mac เครื่องนี้ไม่มีเซนเซอร์มุมฝาพับ", "ออก", "แถบเมนู", "ไอคอน", "มุม", "มุมในไอคอน", "มุมฝาพับ: %@"],
        "vi": ["Phát khi nắp di chuyển", "Âm thanh", "Cọt kẹt", "Rít", "Âm lượng", "Mở thư mục âm thanh", "Mỗi tệp âm thanh trong đó (WAV, M4A, MP3, AIFF) trở thành một âm thanh trong danh sách. Nó phát lặp lại khi nắp di chuyển.", "Máy Mac này không có cảm biến góc nắp.", "Thoát", "Thanh menu", "Biểu tượng", "Góc", "Góc trong biểu tượng", "Góc nắp: %@"],
        "id": ["Putar saat penutup bergerak", "Suara", "Derit", "Cicit", "Volume", "Buka Folder Suara", "Setiap file audio di dalamnya (WAV, M4A, MP3, AIFF) menjadi suara di daftar. Suara diputar berulang selama penutup bergerak.", "Mac ini tidak memiliki sensor sudut penutup.", "Tutup", "Bar Menu", "Ikon", "Sudut", "Sudut di Ikon", "Sudut penutup: %@"],
        "ms": ["Main apabila penutup bergerak", "Bunyi", "Keriut", "Decit", "Kelantangan", "Buka Folder Bunyi", "Setiap fail audio di dalamnya (WAV, M4A, MP3, AIFF) menjadi bunyi dalam senarai. Ia dimainkan berulang selagi penutup bergerak.", "Mac ini tiada penderia sudut penutup.", "Keluar", "Bar Menu", "Ikon", "Sudut", "Sudut dalam Ikon", "Sudut penutup: %@"],
        "zh-Hans": ["屏幕开合时播放", "声音", "吱嘎声", "尖叫声", "音量", "打开声音文件夹", "其中的每个音频文件（WAV、M4A、MP3、AIFF）都会成为列表中的一个声音，在屏幕开合时循环播放。", "这台 Mac 没有屏幕角度传感器。", "退出", "菜单栏", "图标", "角度", "图标内显示角度", "屏幕角度：%@"],
        "zh-Hant": ["螢幕開合時播放", "聲音", "嘎吱聲", "尖叫聲", "音量", "打開聲音檔案夾", "其中的每個音訊檔（WAV、M4A、MP3、AIFF）都會成為列表中的一個聲音，在螢幕開合時循環播放。", "這部 Mac 沒有螢幕角度感測器。", "結束", "選單列", "圖像", "角度", "圖像內顯示角度", "螢幕角度：%@"],
        "ja": ["ふたが動くときに鳴らす", "サウンド", "きしみ", "キーキー", "音量", "サウンドフォルダを開く", "中にあるオーディオファイル（WAV、M4A、MP3、AIFF）はそれぞれリストのサウンドになり、ふたが動いている間ループ再生されます。", "このMacにはふたの角度センサーがありません。", "終了", "メニューバー", "アイコン", "角度", "アイコン内に角度", "ふたの角度：%@"],
        "ko": ["덮개가 움직일 때 재생", "사운드", "삐걱", "끼익", "음량", "사운드 폴더 열기", "그 안의 각 오디오 파일(WAV, M4A, MP3, AIFF)이 목록의 사운드가 됩니다. 덮개가 움직이는 동안 반복 재생됩니다.", "이 Mac에는 덮개 각도 센서가 없습니다.", "종료", "메뉴 막대", "아이콘", "각도", "아이콘에 각도", "덮개 각도: %@"],
    ]
}

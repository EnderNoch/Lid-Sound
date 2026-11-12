# Lid Sound

*[Po polsku niżej.](#po-polsku)*

<img src="images/icon.png" width="128" alt="" align="right">

A MacBook lid that creaks like an old door, or squeaks like a dry hinge, or makes any sound you
give it. Lid Sound sits in the menu bar and reads the lid angle sensor built into newer
MacBooks. While the lid moves, the chosen sound plays in a loop. It is loudest when the lid
moves slowly, like a real door, quieter when you swing it fast, and its pitch rises a little
with the speed.

Two sounds are built in, **Creak** and **Squeak**. The app makes both from numbers when it
starts, with no recordings. Your own sounds go in a folder: every audio file in it shows up in
the list. In Finder and the menu bar the app is named in the system's language: "Lid Sound",
"Dźwięk klapy", "Deckelklang"…

Tested on a MacBook Air with M5, macOS 27.

## Install

1. Download [Lid-Sound.zip](https://github.com/EnderNoch/Lid-Sound/raw/main/Lid-Sound.zip)
   and unzip it (double-click).
2. Drag `Lid Sound.app` into Applications and open it. A laptop icon appears in the menu bar.
   There is no window and no Dock icon.
3. First launch: the app is signed ad hoc, not by Apple, so macOS blocks it. Open System
   Settings → Privacy & Security, scroll down, click "Open Anyway" next to the app and confirm.
   After that it opens normally.

Requires macOS 26 or later on a Mac with Apple silicon and a lid angle sensor.

## Your own sounds

Click the menu bar icon, then **Open Sounds Folder**. It opens
`~/Library/Application Support/Lid Sound/Sounds`. Every WAV, M4A, MP3, AIFF, CAF or FLAC file
you put there becomes a sound in the list, named after the file. The list is read again each
time the panel opens. The sound plays in a loop for as long as the lid moves, so a short clip
that ends where it starts works best. A one-off noise works too, it just repeats.

**Packs: start, middle and end.** A pack is a folder whose name ends in `.lidsound`, such as
`Old door.lidsound`, with three files in it: `start`, `middle` and `end` (any of the formats
above; `początek`, `środek` and `koniec` work too). The start plays as the lid starts to move,
the middle while it moves, and the end when it stops; the middle fades out under the end, so
nothing is cut off. Any part may be left out: a start and an end alone make a door that sounds
as it starts and as it stops, with nothing in between. A pack plays at its own pitch, and the ▶
buttons in the panel play each part once.

```
Sounds/
├── Squeaky hinge.wav          a sound that loops
└── Old door.lidsound/         a pack
    ├── start.wav
    ├── middle.wav
    └── end.wav
```

**Loop or Step.** A pack's middle can loop, or go in steps: its first film frame (1/24 s),
such as one crack of the hinge, played once for every degree the lid moves. A slow lid then
clicks slowly and a fast one rattles, like a real hinge.

## Good to know

- **Which Macs have the sensor.** The 16-inch MacBook Pro from 2019, MacBook Pros from 2021 on
  and MacBook Airs from M2 on. Without one, the panel says so and nothing plays.
- **The menu bar shows what you pick.** The icon, the angle as text, or the angle inside the
  icon, the way the battery shows its percentage. It is under Menu Bar in the panel.
- **The panel shows the angle and the speed.** The speed, in degrees per second, is measured
  exactly as LidAngleSensor measures it, read 30 times a second, and sets the loudness. When
  the lid starts and stops comes from the sensor's own one-degree steps instead, since the
  smoothed speed lags the lid: the start plays on the first step, the end about 0.15 s after
  a fast lid stops and up to 0.8 s after a very slow one.
- **It costs almost nothing at rest.** While the lid is still the audio is switched off.
- **Opens at login.** It adds itself on the first launch. Switch it off in System Settings →
  General → Login Items, and it stays off.
- **The sensor isn't a public API.** Apple doesn't document it, so a future macOS may change it.
  [Sam Henri Gold](https://github.com/samhenrigold/LidAngleSensor) found how to read it.

## License

All rights reserved — see [LICENSE](LICENSE). You may download the finished app and use it on
your own computer. This is not open source: copying the code, distributing it other than by a
link to this repository, modifying it and training AI models on it require the author's
written permission.
The lid speed measurement in `Sources/Sensor.swift` follows
[LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor) by Sam Henri Gold, under the
Apache License 2.0.

Made by [EnderNoch](https://github.com/EnderNoch) (Atypical Maker) · part of
[Atypical Maker Mac Apps](https://github.com/EnderNoch/Atypical-Maker-Mac-Apps).

---

## Po polsku

Klapa MacBooka skrzypi jak stare drzwi, piszczy jak suchy zawias albo wydaje dowolny dźwięk,
jaki jej dasz. Dźwięk klapy siedzi na pasku menu i czyta czujnik kąta klapy wbudowany
w nowsze MacBooki. Gdy klapa się rusza, wybrany dźwięk gra w pętli. Najgłośniej gra przy
powolnym ruchu, jak prawdziwe drzwi, ciszej przy szybkim, a wraz z prędkością trochę rośnie
jego wysokość.

Wbudowane są dwa dźwięki: **Skrzypienie** i **Piszczenie**. Aplikacja tworzy oba z liczb przy
starcie, bez żadnych nagrań. Własne dźwięki wrzucasz do folderu: każdy plik dźwiękowy w nim
pojawia się na liście. W Finderze i na pasku menu aplikacja nazywa się w języku systemu:
„Dźwięk klapy”, „Lid Sound”, „Deckelklang”…

Testowane na MacBooku Air z M5, macOS 27.

### Instalacja

1. Pobierz [Lid-Sound.zip](https://github.com/EnderNoch/Lid-Sound/raw/main/Lid-Sound.zip)
   i rozpakuj go (dwuklik).
2. Przeciągnij `Lid Sound.app` do folderu Aplikacje i otwórz. Na pasku menu pojawi się ikona
   laptopa. Nie ma okna ani ikony w Docku.
3. Pierwsze uruchomienie: aplikacja jest podpisana ad-hoc, nie przez Apple, więc macOS ją
   zablokuje. Otwórz Ustawienia → Prywatność i ochrona, przewiń w dół i kliknij „Otwórz mimo
   to” przy aplikacji, potem potwierdź. Później otwiera się już normalnie.

Wymaga macOS 26 lub nowszego, Maca z procesorem Apple i czujnika kąta klapy.

### Własne dźwięki

Kliknij ikonę na pasku menu, potem **Otwórz folder z dźwiękami**. Otworzy się
`~/Library/Application Support/Lid Sound/Sounds`. Każdy plik WAV, M4A, MP3, AIFF, CAF albo
FLAC, który tam wrzucisz, staje się dźwiękiem na liście pod nazwą pliku. Lista odświeża się
przy każdym otwarciu panelu. Dźwięk gra w pętli, dopóki klapa się rusza, więc najlepiej
sprawdza się krótki fragment, który kończy się tak, jak zaczyna. Pojedynczy odgłos też
zadziała, tylko będzie się powtarzał.

**Paczki: początek, środek i koniec.** Paczka to folder, którego nazwa kończy się na
`.lidsound`, np. `Stare drzwi.lidsound`, a w nim trzy pliki: `start`, `middle` i `end` (w
dowolnym z formatów wyżej; działają też `początek`, `środek` i `koniec`). Początek gra, gdy
klapa rusza, środek, gdy się rusza, a koniec, gdy staje; środek wycisza się pod końcem, więc nic
nie jest ucięte. Każdą część można pominąć: sam początek i koniec to drzwi, które odzywają się,
gdy ruszają i gdy stają, a pomiędzy jest cisza. Paczka gra we własnej wysokości, a przyciski ▶
w panelu grają raz każdą część.

```
Sounds/
├── Piszczący zawias.wav       dźwięk w pętli
└── Stare drzwi.lidsound/      paczka
    ├── start.wav
    ├── middle.wav
    └── end.wav
```

**Pętla albo Krok.** Środek paczki może grać w pętli albo krokami: jego pierwsza klatka filmu
(1/24 s), np. pojedynczy trzask zawiasu, gra raz na każdy stopień ruchu klapy. Wolna klapa
trzaska wtedy powoli, a szybka terkocze, jak prawdziwy zawias.

### Dobrze wiedzieć

- **Które Maki mają czujnik.** 16-calowy MacBook Pro z 2019, MacBooki Pro od 2021 i MacBooki
  Air od M2. Bez czujnika panel o tym mówi i nic nie gra.
- **Pasek menu pokazuje to, co wybierzesz.** Ikonę, kąt jako tekst albo kąt w ikonie, tak jak
  bateria pokazuje procent. Ustawia się to w panelu, w polu Pasek menu.
- **Panel pokazuje kąt i prędkość.** Prędkość w stopniach na sekundę jest mierzona dokładnie
  tak jak w LidAngleSensor, z odczytem 30 razy na sekundę, i ustala głośność. To, kiedy klapa
  rusza i staje, bierze się za to z samych kroków czujnika co stopień, bo wygładzona prędkość
  się spóźnia: początek gra przy pierwszym kroku, a koniec ok. 0,15 s po zatrzymaniu szybkiej
  klapy i do 0,8 s po bardzo wolnej.
- **W spoczynku prawie nic nie kosztuje.** Gdy klapa stoi, dźwięk jest wyłączony.
- **Otwiera się przy logowaniu.** Dodaje się sama przy pierwszym uruchomieniu. Wyłączysz to
  w Ustawieniach → Ogólne → Rzeczy otwierane podczas logowania i już tak zostanie.
- **Czujnik nie jest publicznym API.** Apple go nie opisuje, więc przyszły macOS może go
  zmienić. Sposób odczytu znalazł [Sam Henri Gold](https://github.com/samhenrigold/LidAngleSensor).

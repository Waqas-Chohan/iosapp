# Muz for Mac

One app for every Mac with macOS 11 Big Sur or newer — Apple chips
(M1–M4) and Intel. Free; nothing expires.

## Install (first time)

1. Download **Muz.dmg** from
   [Muz.dmg](https://github.com/Waqas-Chohan/iosapp/releases/latest/download/Muz.dmg)
2. Open it and drag **Muz** onto **Applications**. Eject the "Muz" disk.
3. Open **Muz** from Applications. macOS says Apple cannot check it — click
   **Done**.
4. **System Settings → Privacy & Security** → scroll down → next to
   "Muz was blocked…" click **Open Anyway** → enter your password → **Open**.
   (macOS 14 and older: right-click Muz → **Open** → **Open**.)

If macOS says the app "is damaged", run this once in Terminal, then open it:

    xattr -cr /Applications/Muz.app

## Update

You → **Check for updates** → **Download Muz … for Mac**, then drag the new
Muz into Applications and choose **Replace**. Your library, playlists and
settings are kept (they live in
`~/Library/Containers/com.hellophone.app/Data/Documents`).

## Keyboard

| Keys | Action |
|---|---|
| Space | Play / pause |
| ⌘ → / ⌘ ← | Next / previous |
| ⌘ ↑ / ⌘ ↓ | Volume |
| ⌘ L | Now Playing |
| ⌘ F | Search |
| ⌘ N | New playlist |
| ⌘ 1 … ⌘ 5 | Home, Search, Library, Downloads, You |
| ⌘ , | Settings (You) |

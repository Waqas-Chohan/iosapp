# Install Muz on iPhone

Muz is installed with **SideStore**, a free app installer that uses your own Apple ID.
A computer is needed **once** for the first setup; after that, installs, updates and
refreshes happen on the iPhone.

## 1. Install SideStore (one time, needs a computer)

1. Download **iLoader** on your computer from <https://github.com/nab138/iloader/releases>.
2. Connect your iPhone with a cable, unlock it and tap **Trust This Computer**.
3. In iLoader, sign in with your Apple ID and click **Install SideStore**.
4. On the iPhone: **Settings → Privacy & Security → Developer Mode → On** (the phone restarts).
5. **Settings → General → VPN & Device Management** → tap your Apple ID → **Trust**.
6. Install **LocalDevVPN** from the App Store, open it and tap **Connect**.
7. Open **SideStore** and sign in with the **same Apple ID**.

## 2. Add Muz

1. In SideStore, open **Sources → +** and paste:

   ```
   https://github.com/Waqas-Chohan/iosapp/releases/latest/download/source.json
   ```

2. Open the **Muz** source and tap **Install**.

## 3. Updates

- SideStore shows new versions under **My Apps → Update**.
- Inside Muz: **You → Check for updates**.

## The 7-day refresh

Apps signed with a free Apple ID last 7 days. Keep **LocalDevVPN** connected and open
SideStore every few days, then tap **Refresh All** (or turn on Background Refresh in
SideStore settings). Your library, playlists and settings are kept.

## Troubleshooting

| Problem | Fix |
|---|---|
| Sign-in error **-80045** | Apple is temporarily refusing sign-ins. Wait a few hours, switch **SideStore → Settings → Anisette Server**, then try once. |
| "Unable to verify app" | Settings → General → VPN & Device Management → trust your Apple ID again. |
| Refresh fails | Make sure **LocalDevVPN** is connected and you are on Wi-Fi. |

**Prefer a computer?** Download [Muz.ipa](https://github.com/Waqas-Chohan/iosapp/releases/latest/download/Muz.ipa) and install it with Sideloadly or AltStore.

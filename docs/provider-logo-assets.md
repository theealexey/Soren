# Bundled provider logo assets

Retrieval date for all assets below: **2026-07-13**.

These assets are used only to identify subscription providers in Soren. Provider
names and marks remain the property of their respective owners. Except where an
open-source license is stated, inclusion does not imply affiliation or
endorsement. No bundled asset was recolored, redrawn, or generated.

## Asset inventory

| Stable provider ID | Asset catalog name | Provider / display name | Exact source URL | Source host | Source classification | Original → final | Final dimensions | Transformations | Branding / licensing note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `spotify` | `provider_spotify` | Spotify | `https://open.spotifycdn.com/cdn/images/favicon.0f31d2ea.ico` | `open.spotifycdn.com` | Direct official provider resource | ICO → PNG | 48×48 | Decoded and exported with `sips`; no resize or crop | Spotify trademark; official CDN favicon used for provider identification. |
| `yandex_plus` | `provider_yandex_plus` | Яндекс Плюс | `https://yandex.ru/favicon.ico` | `yandex.ru` | Direct official provider resource | ICO → PNG | 48×48 | Decoded and exported through an 8-bit RGBA ImageIO bitmap; no resize or crop | Yandex trademark; official-domain favicon used for provider identification. |
| `mts_premium` | `provider_mts_premium` | МТС Premium | `https://static.mts.ru/mts_rf/images/favicon-eco/apple-touch-icon.png` | `static.mts.ru` | Direct official provider resource | PNG → PNG | 180×180 | None; no resize or crop | MTS trademark; official CDN touch icon. |
| `mts` | `provider_mts` | МТС | `https://static.mts.ru/mts_rf/images/favicon-eco/apple-touch-icon.png` | `static.mts.ru` | Direct official provider resource | PNG → PNG | 180×180 | None; same source bytes as `provider_mts_premium` | MTS trademark. This is an intentional alias for the separate runtime provider ID `mts`, not an unreachable duplicate. |
| `chatgpt_plus` | `provider_chatgpt_plus` | ChatGPT Plus | `https://t1.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=https://openai.com&size=256` | `t1.gstatic.com` | Third-party proxy | PNG → PNG | 180×180 | None after proxy retrieval; no resize or crop | OpenAI trademark. Bundled bytes came from Google's favicon proxy. Google's `Content-Location` pointing at `https://openai.com/favicon.svg` is not treated as first-party provenance. The direct official favicon request returned an HTTP 403 challenge, so this asset retains a provenance risk. See "OpenAI and NordVPN provenance" below. |
| `icloud` | `provider_icloud` | iCloud+ | `https://www.apple.com/favicon.ico` | `www.apple.com` | Direct official provider resource | ICO → PNG | 64×64 | Decoded and exported with `sips`; no resize or crop | Apple trademark. This is Apple's official-domain favicon and is generic Apple branding rather than an iCloud-specific product mark. |
| `netflix` | `provider_netflix` | Netflix | `https://www.netflix.com/favicon.ico` | `www.netflix.com` | Direct official provider resource | ICO → PNG | 64×64 | Decoded and exported with `sips`; no resize or crop | Netflix trademark; official-domain favicon. |
| `nordvpn` | `provider_nordvpn` | NordVPN | `https://t1.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=https://nordvpn.com&size=256` | `t1.gstatic.com` | Third-party proxy | PNG → PNG | 180×180 | None after proxy retrieval; no resize or crop | NordVPN trademark. Bundled bytes came from Google's favicon proxy. Google's `Content-Location` pointing at `https://nordvpn.com/apple-touch-icon-180x180.png` is not treated as first-party provenance. Direct official icon requests returned an HTTP 403 challenge, so this asset retains a provenance risk. See "OpenAI and NordVPN provenance" below. |
| `x_premium` | `provider_x_premium` | X Premium | `https://abs.twimg.com/favicons/twitter.3.ico` | `abs.twimg.com` | Direct official provider resource | ICO → PNG | 32×32 | Decoded and exported with `sips`; no resize or crop | X trademark; official CDN favicon. |
| `youtube_premium` | `provider_youtube_premium` | YouTube Premium | `https://www.youtube.com/s/desktop/6740ecb6/img/favicon_144x144.png` | `www.youtube.com` | Direct official provider resource | PNG → PNG | 144×144 | None; no resize or crop | YouTube trademark; official-domain favicon. |
| `telegram_premium` | `provider_telegram_premium` | Telegram Premium | `https://telegram.org/img/apple-touch-icon.png` | `telegram.org` | Direct official provider resource | PNG → PNG | 180×180 | None; no resize or crop | Telegram trademark; official-domain touch icon. |
| `qobuz` | `provider_qobuz` | Qobuz | `https://static.qobuz.com/images/favicon/favicon.svg` | `static.qobuz.com` | Direct official provider resource | SVG → SVG | viewBox 180×180 | None; vector preserved | Qobuz trademark; official CDN favicon. |
| `github_copilot` | `provider_github_copilot` | GitHub Copilot | `https://raw.githubusercontent.com/primer/octicons/main/icons/copilot-24.svg` | `raw.githubusercontent.com` | Official open-source project | SVG → SVG | viewBox 24×24 | None; vector preserved | GitHub Primer Octicons asset under the MIT License. The required copyright and license notice is bundled in `Soren/Resources/ThirdPartyNotices.txt`. |

## OpenAI and NordVPN provenance

- **OpenAI / ChatGPT Plus:** the current 180×180 PNG bytes were retrieved from
  Google's favicon proxy. A direct request to the official
  `https://openai.com/favicon.svg` endpoint returned an HTTP 403 challenge in
  the retrieval environment. OpenAI's official brand page provides logo usage
  guidance and a logo download, but that does not establish that the current
  square favicon bytes came from the official download. The current asset was
  therefore left unchanged and remains explicitly classified as proxy-sourced.
- **NordVPN:** the current 180×180 PNG bytes were retrieved from Google's favicon
  proxy. Direct requests to official `nordvpn.com` favicon/touch-icon endpoints
  returned an HTTP 403 challenge. An accessible official Nord CDN resource,
  `https://sb.nordcdn.com/m/f89cfd048a9cb201/original/nordvpn-default-svg.svg`,
  was inspected, but it is a 142×32 horizontal wordmark rather than a square app
  icon and was not substituted. The current asset was left unchanged and
  remains explicitly classified as proxy-sourced.

## Stable-ID mapping

`ProviderIcon` resolves bundled catalog assets from the stable provider ID using
the convention `provider_<provider.id>`. Localized display names are not used.

| Runtime provider ID | Resolved bundled asset |
| --- | --- |
| `spotify` | `provider_spotify` |
| `yandex_plus` | `provider_yandex_plus` |
| `mts_premium` | `provider_mts_premium` |
| `mts` | `provider_mts` |
| `chatgpt_plus` | `provider_chatgpt_plus` |
| `icloud` | `provider_icloud` |
| `netflix` | `provider_netflix` |
| `nordvpn` | `provider_nordvpn` |
| `x_premium` | `provider_x_premium` |
| `youtube_premium` | `provider_youtube_premium` |
| `telegram_premium` | `provider_telegram_premium` |
| `qobuz` | `provider_qobuz` |
| `github_copilot` | `provider_github_copilot` |

`provider_mts` is an asset catalog name, not a third provider ID. Both `mts` and
`mts_premium` are present in the runtime catalog and intentionally use separate
asset names backed by the same official MTS image.

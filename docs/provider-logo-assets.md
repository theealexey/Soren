# Bundled provider logo assets

Original batch retrieval date: **2026-07-13**. Apple service assets, the
targeted Yandex Plus, Kindle Unlimited, OneDrive, and Notion AI assets, and the
dating-service, Yandex Disk, and Yandex 360 assets were retrieved from the
sources documented below on **2026-07-14**.

These assets are used only to identify subscription providers in Soren. Provider
names and marks remain the property of their respective owners. Except where an
open-source license is stated, inclusion does not imply affiliation or
endorsement. No bundled asset was recolored, redrawn, or generated.

## Asset inventory

| Stable provider ID | Asset catalog name | Provider / display name | Exact source URL | Source host | Source classification | Original → final | Final dimensions | Transformations | Branding / licensing note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `spotify` | `provider_spotify` | Spotify | `https://open.spotifycdn.com/cdn/images/favicon.0f31d2ea.ico` | `open.spotifycdn.com` | Direct official provider resource | ICO → PNG | 48×48 | Decoded and exported with `sips`; no resize or crop | Spotify trademark; official CDN favicon used for provider identification. |
| `apple_tv_plus` | `provider_apple_tv_plus` | Apple TV+ | `https://tv.apple.com/assets/favicon/favicon-180.png` | `tv.apple.com` | Direct official service resource | PNG → PNG | 180×180 | None; no resize or crop | Apple TV trademark; official service-domain favicon. |
| `apple_music` | `provider_apple_music` | Apple Music | `https://music.apple.com/favicon.ico` | `music.apple.com` | Direct official service resource | ICO → PNG | 48×48 | Largest frame decoded and exported through an 8-bit RGBA ImageIO bitmap; no resize or crop | Apple Music trademark; official service-domain favicon. |
| `apple_arcade` | `provider_apple_arcade` | Apple Arcade | `https://www.apple.com/v/apple-arcade/q/images/overview/icon_apple_arcade__d4z7ckcax46e_large_2x.jpg` | `www.apple.com` | Direct official service resource | JPG → JPG | 124×124 | None; no resize or crop | Apple Arcade trademark; official product-page asset. |
| `apple_fitness_plus` | `provider_apple_fitness_plus` | Apple Fitness+ | `https://www.apple.com/v/apple-fitness-plus/ac/images/overview/icon_fitness_app__ctfuj4sxwl8i_large_2x.png` | `www.apple.com` | Direct official service resource | PNG → PNG | 68×68 | None; no resize or crop | Apple Fitness+ trademark; official product-page Fitness app mark. |
| `apple_one` | `provider_apple_one` | Apple One | `https://www.apple.com/v/apple-one/f/images/overview/hero_logo_apple_one__bhxr6ypxozwy_large_2x.png` | `www.apple.com` | Direct official service resource | PNG → PNG | 326×106 | None; no resize or crop | Apple One trademark; official product-page wordmark. Aspect ratio is preserved by the existing icon renderer. |
| `yandex_plus` | `provider_yandex_plus` | Яндекс Плюс | `https://avatars.mds.yandex.net/get-media-infra/3756502/d787faef9f2f25928f2306d47a099b9bc2de99f1/orig` | `avatars.mds.yandex.net` | Direct official service resource | PNG → PNG | 440×440 | Center-cropped from the official 4584×2400 Yandex Plus service image; no resize, upscale, recolor, or redraw | Yandex Plus trademark; official service artwork linked by `plus.yandex.ru`. The crop preserves the original Plus mark, colors, and proportions. |
| `yandex_disk` | `provider_yandex_disk` | Яндекс Диск | `https://yastatic.net/s3/tuning/static/pages/brand-services/versions/0.0.10/assets/downloads/иконка_диск.png` | `yastatic.net` | Direct official service resource | PNG → PNG | 1000×1000 | None; no resize, crop, recolor, or redraw | Yandex Disk trademark; official service sign from the Яндекс 360 brand-system downloads. |
| `yandex_360` | `provider_yandex_360` | Яндекс 360 | `https://yastatic.net/s3/tuning/static/pages/brand-logo/versions/0.0.12/assets/downloads/main_icon.png` | `yastatic.net` | Direct official service resource | PNG → PNG | 1000×1000 | None; no resize, crop, recolor, or redraw | Yandex 360 trademark; official primary sign provided by the Яндекс 360 brand-system downloads for small-format identity use. |
| `mts_premium` | `provider_mts_premium` | МТС Premium | `https://static.mts.ru/mts_rf/images/favicon-eco/apple-touch-icon.png` | `static.mts.ru` | Direct official provider resource | PNG → PNG | 180×180 | None; no resize or crop | MTS trademark; official CDN touch icon. |
| `mts` | `provider_mts` | МТС | `https://static.mts.ru/mts_rf/images/favicon-eco/apple-touch-icon.png` | `static.mts.ru` | Direct official provider resource | PNG → PNG | 180×180 | None; same source bytes as `provider_mts_premium` | MTS trademark. This is an intentional alias for the separate runtime provider ID `mts`, not an unreachable duplicate. |
| `chatgpt_plus` | `provider_chatgpt_plus` | ChatGPT Plus | `https://t1.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=https://openai.com&size=256` | `t1.gstatic.com` | Third-party proxy | PNG → PNG | 180×180 | None after proxy retrieval; no resize or crop | OpenAI trademark. Bundled bytes came from Google's favicon proxy. Google's `Content-Location` pointing at `https://openai.com/favicon.svg` is not treated as first-party provenance. The direct official favicon request returned an HTTP 403 challenge, so this asset retains a provenance risk. See "OpenAI and NordVPN provenance" below. |
| `icloud` | `provider_icloud` | iCloud+ | `https://www.icloud.com/favicon.ico` | `www.icloud.com` | Direct official service resource | ICO → PNG | 48×48 | Largest frame decoded and exported through an 8-bit RGBA ImageIO bitmap; no resize or crop | iCloud trademark; official service-domain favicon. |
| `netflix` | `provider_netflix` | Netflix | `https://www.netflix.com/favicon.ico` | `www.netflix.com` | Direct official provider resource | ICO → PNG | 64×64 | Decoded and exported with `sips`; no resize or crop | Netflix trademark; official-domain favicon. |
| `nordvpn` | `provider_nordvpn` | NordVPN | `https://t1.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=https://nordvpn.com&size=256` | `t1.gstatic.com` | Third-party proxy | PNG → PNG | 180×180 | None after proxy retrieval; no resize or crop | NordVPN trademark. Bundled bytes came from Google's favicon proxy. Google's `Content-Location` pointing at `https://nordvpn.com/apple-touch-icon-180x180.png` is not treated as first-party provenance. Direct official icon requests returned an HTTP 403 challenge, so this asset retains a provenance risk. See "OpenAI and NordVPN provenance" below. |
| `x_premium` | `provider_x_premium` | X Premium | `https://abs.twimg.com/favicons/twitter.3.ico` | `abs.twimg.com` | Direct official provider resource | ICO → PNG | 32×32 | Decoded and exported with `sips`; no resize or crop | X trademark; official CDN favicon. |
| `youtube_premium` | `provider_youtube_premium` | YouTube Premium | `https://www.youtube.com/s/desktop/6740ecb6/img/favicon_144x144.png` | `www.youtube.com` | Direct official provider resource | PNG → PNG | 144×144 | None; no resize or crop | YouTube trademark; official-domain favicon. |
| `telegram_premium` | `provider_telegram_premium` | Telegram Premium | `https://telegram.org/img/apple-touch-icon.png` | `telegram.org` | Direct official provider resource | PNG → PNG | 180×180 | None; no resize or crop | Telegram trademark; official-domain touch icon. |
| `qobuz` | `provider_qobuz` | Qobuz | `https://static.qobuz.com/images/favicon/favicon.svg` | `static.qobuz.com` | Direct official provider resource | SVG → SVG | viewBox 180×180 | None; vector preserved | Qobuz trademark; official CDN favicon. |
| `github_copilot` | `provider_github_copilot` | GitHub Copilot | `https://raw.githubusercontent.com/primer/octicons/main/icons/copilot-24.svg` | `raw.githubusercontent.com` | Official open-source project | SVG → SVG | viewBox 24×24 | None; vector preserved | GitHub Primer Octicons asset under the MIT License. The required copyright and license notice is bundled in `Soren/Resources/ThirdPartyNotices.txt`. |
| `kindle_unlimited` | `provider_kindle_unlimited` | Kindle Unlimited | `https://m.media-amazon.com/images/G/01/books-voyager/subnav/KULogo.svg` | `m.media-amazon.com` | Direct official service resource | SVG → SVG | viewBox 105×24 | None; vector preserved | Kindle Unlimited trademark; official service wordmark served by Amazon's media CDN and referenced by the Kindle Unlimited product page. |
| `onedrive` | `provider_onedrive` | Microsoft OneDrive | `https://static2.sharepointonline.com/files/fabric/assets/brand-icons/product-fluent/svg/onedrive_48x1.svg` | `static2.sharepointonline.com` | Direct official service resource | SVG → SVG | viewBox 48×48 | None; vector preserved | Microsoft OneDrive trademark; official Microsoft product icon served from the SharePoint Online asset CDN. |
| `notion_ai` | `provider_notion_ai` | Notion AI | `https://www.notion.so/front-static/logo-ios.png` | `www.notion.so` | Direct official provider resource | PNG → PNG | 512×512 | None; no resize or crop | Notion trademark. This intentionally uses the shared official Notion identity because no separate approved Notion AI service mark is bundled; it is not a generated `NA` placeholder. |
| `tinder` | `provider_tinder` | Tinder | `https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/e1/66/97/e1669740-5fd9-c155-0db4-56bfa0d26a71/AppIcon-BrandFlame-0-0-1x_U007ephone-0-1-0-0-sRGB-0-85-220.png/512x512bb.jpg` | `is1-ssl.mzstatic.com` | Official app-distribution resource | JPEG → JPEG | 512×512 | None; no resize, crop, recolor, or redraw | Tinder trademark; current service icon supplied by Tinder LLC through the official Apple App Store listing (track ID 547702041). |
| `bumble` | `provider_bumble` | Bumble | `https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/00/02/69/000269f5-f54d-c73b-1d8c-36e0cfa7c685/AppIcon-0-0-1x_U007ephone-0-1-0-85-220.png/512x512bb.jpg` | `is1-ssl.mzstatic.com` | Official app-distribution resource | JPEG → JPEG | 512×512 | None; no resize, crop, recolor, or redraw | Bumble trademark; current service icon supplied by Bumble Holding Limited through the official Apple App Store listing (track ID 930441707). |
| `hinge` | `provider_hinge` | Hinge | `https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/71/66/44/7166446a-3ab4-d12a-b388-841290862056/AppIcon-0-0-1x_U007emarketing-0-6-0-85-220.png/512x512bb.jpg` | `is1-ssl.mzstatic.com` | Official app-distribution resource | JPEG → JPEG | 512×512 | None; no resize, crop, recolor, or redraw | Hinge trademark; current service icon supplied by Hinge, Inc. through the official Apple App Store listing (track ID 595287172). |
| `badoo` | `provider_badoo` | Badoo | `https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/87/87/d7/8787d7bc-54ab-2710-0152-1aa61e15f15a/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/512x512bb.jpg` | `is1-ssl.mzstatic.com` | Official app-distribution resource | JPEG → JPEG | 512×512 | None; no resize, crop, recolor, or redraw | Badoo trademark; current service icon supplied by Badoo Software Ltd through the official Apple App Store listing (track ID 351331194). |
| `feeld` | `provider_feeld` | Feeld | `https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/3f/66/0c/3f660ccb-a49a-94fc-bb31-ff8408e63089/AppIcon-0-0-1x_U007ephone-0-12-0-85-220.png/512x512bb.jpg` | `is1-ssl.mzstatic.com` | Official app-distribution resource | JPEG → JPEG | 512×512 | None; no resize, crop, recolor, or redraw | Feeld trademark; current service icon supplied by Feeld Ltd through the official Apple App Store listing (track ID 887914690). |
| `her` | `provider_her` | HER | `https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/18/44/31/18443194-6fc5-2ae7-385f-52d6483a2db9/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/512x512bb.jpg` | `is1-ssl.mzstatic.com` | Official app-distribution resource | JPEG → JPEG | 512×512 | None; no resize, crop, recolor, or redraw | HER trademark; current service icon supplied by Bloomer Inc through the official Apple App Store listing (track ID 573328837). |
| `twinby` | `provider_twinby` | Twinby | `https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/ca/24/24/ca2424f9-da09-cc75-2581-87879cacf270/AppIcon-0-0-1x_U007ephone-0-1-sRGB-85-220.png/512x512bb.jpg` | `is1-ssl.mzstatic.com` | Official app-distribution resource | JPEG → JPEG | 512×512 | None; no resize, crop, recolor, or redraw | Twinby trademark; current service icon supplied by NEURALAB TECH SOLUTIONS through the official Apple App Store listing (track ID 1595084386). |
| `mamba` | `provider_mamba` | Mamba | `https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/bd/b9/ce/bdb9ceea-b6bf-0822-76f3-3345c9595193/AppIcon-Mamba-0-0-1x_U007emarketing-0-11-0-85-220.png/512x512bb.jpg` | `is1-ssl.mzstatic.com` | Official app-distribution resource | JPEG → JPEG | 512×512 | None; no resize, crop, recolor, or redraw | Mamba trademark; current service icon supplied by JSC Mamba through the official Apple App Store listing (track ID 326839545). |
| `pure` | `provider_pure` | Pure | `https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/2b/d7/44/2bd74482-0b73-94b7-34fb-0d944e6471e2/AppIcon-0-0-1x_U007ephone-0-1-0-85-220.jpeg/512x512bb.jpg` | `is1-ssl.mzstatic.com` | Official app-distribution resource | JPEG → JPEG | 512×512 | None; no resize, crop, recolor, or redraw | Pure trademark; current service icon supplied by Online Classifieds AG through the official Apple App Store listing (track ID 690661663). |

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
| `yandex_disk` | `provider_yandex_disk` |
| `yandex_360` | `provider_yandex_360` |
| `mts_premium` | `provider_mts_premium` |
| `mts` | `provider_mts` |
| `chatgpt_plus` | `provider_chatgpt_plus` |
| `apple_tv_plus` | `provider_apple_tv_plus` |
| `apple_music` | `provider_apple_music` |
| `apple_arcade` | `provider_apple_arcade` |
| `apple_fitness_plus` | `provider_apple_fitness_plus` |
| `apple_one` | `provider_apple_one` |
| `icloud` | `provider_icloud` |
| `netflix` | `provider_netflix` |
| `nordvpn` | `provider_nordvpn` |
| `x_premium` | `provider_x_premium` |
| `youtube_premium` | `provider_youtube_premium` |
| `telegram_premium` | `provider_telegram_premium` |
| `qobuz` | `provider_qobuz` |
| `github_copilot` | `provider_github_copilot` |
| `kindle_unlimited` | `provider_kindle_unlimited` |
| `onedrive` | `provider_onedrive` |
| `notion_ai` | `provider_notion_ai` |
| `tinder` | `provider_tinder` |
| `bumble` | `provider_bumble` |
| `hinge` | `provider_hinge` |
| `badoo` | `provider_badoo` |
| `feeld` | `provider_feeld` |
| `her` | `provider_her` |
| `twinby` | `provider_twinby` |
| `mamba` | `provider_mamba` |
| `pure` | `provider_pure` |

`provider_mts` is an asset catalog name, not a third provider ID. Both `mts` and
`mts_premium` are present in the runtime catalog and intentionally use separate
asset names backed by the same official MTS image.

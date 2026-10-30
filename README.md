# 견습마법사의 탑

탑을 한 층씩 올라가며 마법을 익히는 트윈스틱 액션 RPG입니다.

- `www/index.html` — 게임 본체 (브라우저에서 바로 열어도 동작)
- `android/` — 게임을 감싸는 안드로이드 앱 (가로 고정, 전체 화면)
- `main` 브랜치에 올라가면 GitHub Actions가 APK를 만들어 **Releases**에 올립니다.

최신 APK: Releases → 맨 위 버전 → `apprentice-tower-v0.N.apk`

## 그림 출처
캐릭터·몬스터·아이템·마법 이펙트 그림은 오픈소스 게임 [Flare](https://github.com/flareteam/flare-game)
(CC-BY-SA 3.0)의 그림을 `tools/flare_convert.py` 로 가공해 썼습니다. 자세한 내용은 `www/assets/CREDITS.md`.
바닥·벽 텍스처와 보물상자는 `tools/` 의 생성 도구로 직접 만들었습니다.

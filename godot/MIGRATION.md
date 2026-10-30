# 고도(Godot) 이전 진행 기록

웹(Canvas 2D) 버전 `www/index.html` 을 고도 4.5(GL Compatibility 렌더러)로 옮기는 작업.
중간에 멈춰도 이 파일을 보고 이어서 하면 된다.

## 원칙
- 지금 웹 버전(`www/`, 워크플로 `build-apk.yml`, 릴리스 `v0.N`)은 이전이 끝날 때까지 건드리지 않는다.
- 고도 버전은 `godot/` 폴더, 워크플로 `godot.yml`, 시험판 릴리스 `g0.N`(prerelease), 패키지 `com.kakario.apprenticetower.godot`(기존 앱과 따로 설치됨).
- 그림은 빌드할 때 `www/assets` 를 `godot/assets` 로 복사해서 쓴다(저장소에 두 번 넣지 않음). 글꼴은 google/fonts 에서 받는다.
- 단위: 1 = 타일 한 칸(웹 32px). 웹 좌표 (x, y) → 3D (x, 0, y). y 가 남쪽(카메라 쪽).
- 카메라: 고도 40°에서 내려다봄, 거리 16.25, 세로 화각 37°. 세운 그림은 1/cos40° 만큼 키움(World.STAND).
- 확인 방법: CI 가 xvfb 로 스크린샷(shots 아티팩트)과 FPS 측정(BENCH 줄)을 남긴다. `--shot=경로 --floor=N --seed=N --bench`.

## 단계
- [x] 1단계(g0.3 완료): 뼈대·CI·APK, 마을/1~15층 맵 생성, 3D 바닥·벽·숲·소품·횃불 빛, 플레이어 8방향 이동(키보드·패드·터치 스틱), 계단/입구로 층 이동, FPS 표시
- [x] 2단계(g0.8): 몬스터(meta.json 전부), AI(flow 길찾기), 마법 4계열 발사·충돌·피해 숫자, 경험치·레벨업, 체력/마나 HUD, 보스 3종
- [x] 3단계(g0.8, 1차): 아이템·가방·장비·상점·NPC 대화, 스킬 트리 화면, 물약 벨트, 안개(시야), 미니맵, 효과(fx_* 스프라이트·파티클), 저장/불러오기, 난이도, 샌드박스, 패드 전체 조작
- [ ] 4단계: 웹판과 화면·밸런스 비교, 성능 측정, 패키지 이름을 기존 앱과 같게 바꿔 교체

## 웹 코드 위치(옮길 때 참고, www/index.html 줄번호는 v0.12 기준)
- 데이터(몬스터·보스·마법·아이템): ~350–435
- 맵 생성 genFloor/goTown/decorate: 527–660 → godot/scripts/mapgen.gd (완료)
- 입력 readInput: ~1110–1170
- update(전투·AI): 1511–1620
- 그리기 draw*: 1624–2460 → world.gd / actor.gd 로 대체

## 기록
- CI 결과(스크린샷 town/floor1/floor5.png, import/run/export.log, BENCH 줄)는 `ci-out` 가지에 강제 푸시된다.
  이 작업 환경에서는 Actions 로그·아티팩트 다운로드가 막혀 있으므로 `git fetch origin +ci-out:refs/remotes/origin/ci-out` 후 `git archive` 로 꺼내 본다.
- CI 의 xvfb 는 소프트웨어 렌더링이라 FPS 숫자는 의미 없음(폰에서 화면 왼쪽 위 FPS 로 확인).
- g0.3 APK 약 125MB(텍스처 무손실+밉맵). 4단계에서 ETC2/ASTC 압축으로 줄일 것.
- 다음 할 일(2단계 시작점): 웹 DATA.monsters(357~) · spawnEnemy · 적 AI(update 1511~, stepToward 668) · 마법 발사(castPrim 근처) 를 scripts/combat.gd 로.
- 1단계 작성: mapgen.gd, world.gd, actor.gd, main.gd, hud.gd, stick_pad.gd
- g0.8: 웹 규칙 전체를 game.gd(픽셀 좌표 그대로)로, 그리기는 view.gd/world.gd, HUD 는 hud.gd, 메뉴는 ui.gd, 아이콘은 tools/godot_icons.py 로 미리 그린 godot/ui/*.png.
- 주의: GDScript 에서 `pass` 는 예약어라 P["pass"] 로 씀. 함수 안에서는 `:=` 대신 `=`(Variant 추론 오류 방지).
- CI 에 스크립트 검사 단계(check.log) 있음. 시험 장면: --mode=title|levelup|bag|talk|pause|sand, --floor=N.
- 남은 일(4단계): 폰 피드백 반영, 텍스처 압축(용량), 패키지 이름을 기존 앱으로 바꿔 교체, 웹판과 세부 비교(러그·균열 장식, 타이틀 탑 그림 등은 아직 없음).
- 빠른 캡처(로컬, 약 75초): 고도 실행 파일을 `https://github.com/godotengine/godot/releases/download/4.5.1-stable/Godot_v4.5.1-stable_linux.x86_64.zip` 에서 바로 받아 /tmp/claude-0/godot 에 풀고,
  `cp -r www/assets godot/assets`, 글꼴은 로컬 미리보기용으로 Noto CJK KR 을 fontTools 로 뽑아 godot/fonts 에 넣은 뒤 `--headless --import`, 그리고 `tools/samples.sh OUT_DIR` (한 번 실행으로 9장).
- g0.11: 70층(5 네임드·10 준보스·15 네임드·20 계층보스 반복, 70 최종), 20층마다 테마(D.THEMES), 층마다 고정 시드(runSeed), 11·21…층 웨이포인트(마을 탑 문에서 선택),
  이어하기 시 그 층에서 시작, 북쪽 벽을 판 계단(mapgen.carve_alcove, world._build_alcoves) + 회색 반원 + 빨려 들어가는 페이드(G.pull), 테라스(enter_terrace/leave_terrace, G.stash),
  장비 7칸(목걸이·스태프·망토·반지2·허리띠·장화), 가방 칸 구매(P.bagMax), 상점 랜덤 장비(G.shop), 떠다니는 조이스틱, 미니맵 내 위치, 거래하기 버튼.

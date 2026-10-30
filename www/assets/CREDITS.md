# 그림 출처

## Flare (CC-BY-SA 3.0)
`assets/sprites/` 안의 다음 파일은 오픈소스 게임 **Flare** 의 그림을 가공한 것입니다.
- 원본: https://github.com/flareteam/flare-game (mods/fantasycore)
- 제작: Clint Bellanger, Justin Jacobs, Justin Nichol 외 Flare 기여자 (원본 CREDITS.txt 참고)
- 라이선스: Creative Commons Attribution-ShareAlike 3.0 — https://creativecommons.org/licenses/by-sa/3.0/
- 가공 내용: 동작별 프레임을 다시 배치하고 크기를 줄임, 마법사 옷 레이어 합성(player), 색조 변경(lich)
- 가공한 그림도 같은 CC-BY-SA 3.0 으로 배포합니다.

해당 파일: player, guide, shop, skel, archer, mage, lich, zombie, goblin, fire_ant, antlion, antlion_small,
minotaur, wyvern_fire, loot_*, fx_*

## 이 프로젝트에서 직접 만든 그림
- `assets/sprites/chest.png`, `chest_open.png`: tools/models.py + tools/sdf.py 로 렌더링
- `assets/tiles/*`: tools/textures.py 로 생성

- `assets/ui/icons.png`, `assets/ui/glyphs.png`: Flare `mods/fantasycore/images/icons/icons.png` (CC-BY-SA 3.0). 마법 문양은 돌판 배경을 지우고 흰 문양만 남김, 아이템은 검은 배경을 투명 처리.
- `assets/props/*`, `assets/tiles/grass3.png`, `path3.png`: Flare 타일셋(`tileset_grassland`, `tileset_dungeon`, CC-BY-SA 3.0)에서 잘라냄. 바닥은 아이소메트릭 마름모를 정사각형으로 펼침 (`tools/flare_props.py`).

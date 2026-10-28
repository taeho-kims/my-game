# Evidence: Story 002 — 영웅 강하·착지 충격·기사 자동전투

**Story**: production/epics/slime-nodaji/story-002-hero-drop-combat.md
**Type**: Visual/Feel
**Date**: 2026-10-28

## Retained screenshots
- production/qa/evidence/story-002-hero-drop-combat/01-landing-impact.png — 착지 링과 점선 미리보기
- production/qa/evidence/story-002-hero-drop-combat/02-knights-fighting.png — 기사 전투, 피해 숫자, 체력 바, 코인
(2026-10-28 재촬영: 현재 설정인 창 2배(1280×720) + canvas_items 상태, hero_level 3, 자동 낙하 1초 간격. 걷기 bob 수정 이후 코드 기준.)

## Playtest observation
2026-10-28 사용자가 데모를 직접 실행해 10개 기준을 확인했다. 착지 순간이 "묵직하고 쫀득하게" 느껴진다는 판단을 받았다.
기준 확인은 강하·착지·전투·손맛 4묶음 단위로 이루어졌다.

## Sign-off
| Role | Name | Decision |
|------|------|----------|
| Feel / Visual lead | Taeho Kim | [x] Approved |

## Notes
- 흔들림 `shake_offset_factor` 1.0 유지 (프로토타입 대비 약 2배).
- 피해 숫자 가독성은 `production/polish-notes.md` #3에 기록.

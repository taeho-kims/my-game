# Story 003: 커서 자석 수집 + 상자 5등급·배율

> **Epic**: slime-nodaji
> **Status**: In Progress
> **Layer**: N/A (minimal — no layers)
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-28

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 3 — 커서 자석 코인 수집 + 상자 5등급과 배율 (프로토타입 `TIERS` 값 그대로)

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (Core loop 2, Who it's for), values from the prototype:*

- [ ] 커서 반경 `24 + 5×magnet 레벨` 안의 바닥 코인은 상자로 날아간다 (곡선 경로, 약 0.42초). 커서가 필드 밖이면 자석은 꺼진다. *(기본 반경은 프로토타입 환산값 17에서 24로 올린 의도적 변경 — 아래 Implementation Notes 참고)*
- [ ] 코인이 상자에 도착하면 상자 값에 코인 가치가 더해지고, 상자가 살짝 튀어 오른다. 같은 코인은 한 번만 더해진다.
- [ ] 상자 등급 임계는 40 / 140 / 400 / 1100에 `1.07^판 수`를 곱한 값이고, 등급은 임계 이상인 가장 높은 단계다 (나무·구리·은·금·수정).
- [ ] 등급 배율은 `기본 배율 + 0.1×chest 레벨 × 등급 번호`이고, 기본 배율은 1 / 1.25 / 1.5 / 2 / 3이다.
- [ ] 커서 위치에 자석 반경 원이 그려진다.
- [ ] 코인 흡수 효과음은 종류별 음높이(구리 760·은 990·보석 1320)로 나오고, 45ms 안에서는 한 번만 난다.
- [ ] 자석으로 코인을 빨아들이는 감각이 끈적하고 만족스럽다 — 영상 또는 스크린샷과 서명으로 확인한다.

---

## Implementation Notes

- 값의 출처는 프로토타입의 `TIERS`, `tierOf`, `multOf`, `update`의 코인 구간이다.
- **단위 변환 (2026-10-27):** 프로토타입의 공간 단위 값은 1280×720 기준이라 640×360에서는 0.5배로 옮겼다 (자석 반경 `34 + 10×레벨` → `17 + 5×레벨`). 등급 임계·배율 같은 비공간 값은 그대로다.
- 등급 임계와 배율은 외부 데이터 파일(`assets/data/chest_tiers.json`)에서 읽는다.
- 한 판의 시간 종료 후(개봉 단계)에는 흡수하지 않는다 (story 004).
- **손맛 조정 — 의도적 변경 (플레이 테스트, 2026-10-28):** AC-7 손맛이 처음에 실패했다 (자석 범위가 좁아 커서를 코인에 거의 붙여야 끌려오고, 상자에 들어갈 때 반응이 약함). `assets/data/chest_tiers.json`을 조정했고, 다시 플레이해 둘 다 좋아진 것을 확인한 뒤 이 값으로 확정했다. 프로토타입 환산값과 다르며 오류가 아니다: 자석 `base_radius` 17 → 24 (레벨당 +5는 그대로), 상자 `bump_scale` 0.08 → 0.2, `bump_lift` 2 → 5. 목록은 `design/game-brief.md`의 "손맛 조정으로 프로토타입과 달라진 값".
- **가시성 (story-001 플레이 후 메모, 2026-10-27):** 640×360에서 바닥 코인이 너무 작아 보인다. 이 스토리에서 코인 크기를 키우거나 반짝임(하이라이트 깜빡임 등)을 더해 잘 보이게 한다. 크기·반짝임 값은 데이터 파일에 둔다. 상세: `production/polish-notes.md`
- **피해 숫자 가독성 (story-002 플레이 후 메모, 2026-10-28):** 피해 숫자가 회색이라 초록 들판에서 잘 안 보인다. 흰 글씨에 어두운 테두리로 바꾼다 (피해 숫자는 `src/gameplay/hero/hero_squad.gd`에서 그려진다). 색·테두리 값은 데이터 파일에 둔다. 상세: `production/polish-notes.md` #3

---

## Out of Scope

- story 004: 시간제 한 판과 개봉 연출, 정산
- story 005: `magnet`·`chest` 노드 구매

---

## Files

- src/gameplay/chest/chest_tiers.gd (+ .uid)
- src/gameplay/chest/chest.gd (+ .uid)
- src/gameplay/magnet/magnet.gd (+ .uid)
- assets/data/chest_tiers.json
- src/gameplay/coin/coin.gd — flight support (begin_flight, fly_to) and polish note 2 (draw_scale, sparkle)
- src/gameplay/slime/slime_field.gd — coin schema keys for the polish values
- assets/data/slime_field.json — coin.draw_scale, sparkle_* (polish note 2)
- src/gameplay/hero/hero_squad.gd — damage popup outline and fade_start (polish note 3)
- assets/data/hero_knight.json — popup.outline_size, popup.fade_start (polish note 3)
- src/gameplay/slime/slime_field_demo.gd — dev harness: magnet_level, chest_level, chest and magnet wired in
- tests/unit/chest/chest_tier_test.gd — 30 tests (written although qa.level is minimal, at the user's request)
- tests/integration/chest/chest_data_test.gd — 6 tests: chest_tiers.json against the prototype's TIERS

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*`qa.level: minimal`: 테스트는 면제(권고)이며, 유지되는 스크린샷은 면제되지 않는다.*

**Story Type**: Logic
**Required evidence**: `tests/unit/chest/chest_tier_test.gd` (권고)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/slime-nodaji/story-001-slime-field.md`
- Unlocks: `production/epics/slime-nodaji/story-004-run-timer-burst.md`

# Story 003: 커서 자석 수집 + 상자 5등급·배율

> **Epic**: slime-nodaji
> **Status**: Ready
> **Layer**: N/A (minimal — no layers)
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] 커서 반경 `34 + 10×magnet 레벨` 안의 바닥 코인은 상자로 날아간다 (곡선 경로, 약 0.42초). 커서가 필드 밖이면 자석은 꺼진다.
- [ ] 코인이 상자에 도착하면 상자 값에 코인 가치가 더해지고, 상자가 살짝 튀어 오른다. 같은 코인은 한 번만 더해진다.
- [ ] 상자 등급 임계는 40 / 140 / 400 / 1100에 `1.07^판 수`를 곱한 값이고, 등급은 임계 이상인 가장 높은 단계다 (나무·구리·은·금·수정).
- [ ] 등급 배율은 `기본 배율 + 0.1×chest 레벨 × 등급 번호`이고, 기본 배율은 1 / 1.25 / 1.5 / 2 / 3이다.
- [ ] 커서 위치에 자석 반경 원이 그려진다.
- [ ] 코인 흡수 효과음은 종류별 음높이(구리 760·은 990·보석 1320)로 나오고, 45ms 안에서는 한 번만 난다.
- [ ] 자석으로 코인을 빨아들이는 감각이 끈적하고 만족스럽다 — 영상 또는 스크린샷과 서명으로 확인한다.

---

## Implementation Notes

- 값의 출처는 프로토타입의 `TIERS`, `tierOf`, `multOf`, `update`의 코인 구간이다.
- 등급 임계와 배율은 외부 데이터 파일(`assets/data/chest_tiers.json`)에서 읽는다.
- 한 판의 시간 종료 후(개봉 단계)에는 흡수하지 않는다 (story 004).

---

## Out of Scope

- story 004: 시간제 한 판과 개봉 연출, 정산
- story 005: `magnet`·`chest` 노드 구매

---

## Files

- src/gameplay/magnet/magnet.gd
- src/gameplay/chest/chest.gd
- src/gameplay/chest/chest_tiers.gd
- assets/data/chest_tiers.json
- tests/unit/chest/chest_tier_test.gd

---

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

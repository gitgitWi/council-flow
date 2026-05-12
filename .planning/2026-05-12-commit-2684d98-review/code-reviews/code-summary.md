---
title: "Code review summary — commit 2684d98"
type: code-summary
task: commit-2684d98-review
task_date: 2026-05-12
created: 2026-05-12
last_updated: 2026-05-12
status: active
size: M
related:
  - ./code-gemini.md
  - ./code-glm.md
reviewers:
  - gemini-3.1-pro-preview
  - opencode-go/glm-5.1
missing_reviewers:
  - opencode-go/deepseek-v4-pro
commit: 2684d98fc74dce924c4d58c8baf775a5b2295a17
---

# 코드 리뷰 요약 — commit 2684d98

> `feat(plan,multi-llm): brainstorming sub-phase + file-write dispatch contract`

## 전체 평가

두 리뷰어 모두 **request changes** verdict. 핵심 설계(file-write contract, sentinel, heartbeat, quorum policy)는 잘 짜였다고 평가하지만, **load-bearing한 운영 결함 세 가지**가 머지 전 picked up되었어야 한다는 것이 일치된 의견:

1. `watch_review`가 파일이 절대 생성되지 않는 실패 경로(silent crash, immediate exit 1)에서 25분 동안 hang
2. CLI Write tool 권한 기본값에 대한 미검증 가정 — opencode는 실제로 별도 플래그가 필요했음 (오늘 세션에서 입증)
3. Gemini 모델 ID가 같은 커밋 안에서 3가지 변형으로 산재 (single source of truth 원칙 위반)

이번 작업으로 일부는 이미 해결됨 (모델 ID 통일, `--format json` 제거). 나머지는 후속 패치로.

## 합의된 주요 이슈

- **[CRITICAL] `watch_review` 파일-미생성 경로 hang** — Gemini, GLM. heartbeat watcher가 `[[ ! -f "$file" ]]` 분기에서 `stale_count`를 증가시키지 않고 그냥 `continue` → 외부 CLI가 즉시 죽어도 25 cycles(25분)를 다 돌고 나서야 timeout. 부모 셸이 `wait`로 묶여 있으면 10분 timeout 정책이 사실상 25분으로 늘어남.
  - 권장 수정: `exit` sidecar 파일을 watcher에 같이 넘겨서 `[[ -f "$exit_file" ]]`로 조기 종료, 또는 `wait_count`를 `stale_count`와 분리해 5분 cap.

- **[MAJOR] OpenCode `--format json`이 runlog-as-diagnostic 계약 위반** — Gemini, GLM. JSONL 이벤트 스트림은 사람도 grep도 읽기 어려움. multi-llm.md 본문은 stdout이 diagnostic runlog라고 하면서 호출 예시는 JSONL로 만듦.
  - **이미 후속 커밋 `8cd20aa`에서 수정됨.** Verified.

- **[MAJOR/CRITICAL] Gemini 모델 ID 산재** — Gemini (MINOR), GLM (CRITICAL). 같은 커밋 안에 `gemini-3.1-pro`, `gemini-3-pro-preview`, `gemini-3.1-pro-preview` 세 형태가 공존. multi-llm.md L76의 "Model IDs come from references/models.md, edit there not here" 규칙이 같은 파일에서 깨짐.
  - **이미 후속 커밋 `a11bb91`에서 `gemini-3.1-pro-preview`로 통일.** Verified.

- **[NIT] sentinel `tail -1` trailing newline edge case** — Gemini, GLM. LLM Write tool이 trailing `\n` 또는 `\n\n`을 붙이면 sentinel 검사가 false negative.
  - 권장 수정: `grep -v '^[[:space:]]*$' "$file" | tail -1` 또는 `tail -n 2 | grep -q sentinel`.

- **[QUESTION] CLI Write tool 권한 기본 동작 미검증** — Gemini, GLM. spec은 `gemini --yolo`, `opencode run`, `codex exec`, `claude -p` 모두 Write tool을 비대화 모드에서 노출한다고 주장하지만 `opencode run`의 권한 모델은 명시 안 됨. **오늘 세션에서 실증**: `--dangerously-skip-permissions` 없이 호출하면 Write tool 권한 승인 대기에서 무한 hang.

## 모델 간 의견이 갈리는 지점

가장 중요한 결정 포인트:

1. **모델 ID 산재의 심각도** — Gemini는 MINOR, GLM은 CRITICAL.
   - GLM의 근거가 더 강함: "Model IDs come from references/models.md" 규칙을 그 규칙을 명시한 파일 자신이 위반. 세 가지 변형이 공존했음. 우리 판단: 후속 커밋으로 이미 해결됐지만 머지 전이었다면 MAJOR.

2. **Heredoc quoting mismatch는 GLM만 잡음** (MAJOR) — multi-llm.md L32는 `<<'PROMPT'`(single-quoted, no expansion)이고 L234와 plan/SKILL.md L106은 `<<PROMPT`(expand active). 변수 expansion 위해 필요한 차이지만 문서화되지 않아 copy-paste 함정. 권장: 변경된 heredoc 양식 옆에 짧은 코멘트, 또는 변수만 별도 export하고 모든 prompt를 single-quoted heredoc으로 통일.

3. **30k 토큰 콜드스타트 비용 노출** (GLM만, QUESTION) — M-size brainstorming은 cross-module/security/public-surface면 기본 yes로 트리거되는데, opencode 한 번 호출당 30k 토큰 콜드스타트가 누적. 작은 M-size 작업에서는 single-lens(gemini)로 충분할 수 있다는 지적. orchestrate decision framework에 비용 신호 추가 가치 있음.

## 인라인 코멘트 개수

- CRITICAL: 3개 (`watch_review` hang × 2 표현, 모델 ID 산재 GLM critical 1)
- MAJOR: 4개 (`--format json`, 모델 ID Gemini-minor/GLM-critical 합산, watch_review, heredoc quoting)
- MINOR: 3개 (모델 ID Gemini, 상대 경로, sentinel newline edge)
- NIT: 2개 (sentinel tail edge case, runlog 변수 명명 불일치)
- QUESTION: 3개 (Write tool 권한, M-size 30k 비용, write availability per CLI)

## 머지 권장

- [ ] **조건부 권장** — 머지 전 받았다면 `watch_review` 파일-미생성 hang은 머지 차단했을 critical. 모델 ID 통일과 `--format json` 제거도 머지 전 요구. 이미 머지된 commit 회고로는: 후속 패치(`8cd20aa`, `afd3613`, `5adea51`, `a11bb91`)와 오늘 세션의 발견으로 **MAJOR 두 개는 해결**, `watch_review` CRITICAL은 **아직 미해결** — 별도 후속 작업 필요.

## 결손 리뷰어

- **opencode-go/deepseek-v4-pro** — 기본 trio의 세 번째 리뷰어. 다중 시도 후 silent hang으로 실패.
  - **근본 원인 (오늘 세션에서 진단)**: `opencode run "$PROMPT"`처럼 prompt를 positional argument로 넘기면 일정 크기/복잡도 이상에서 LLM 세션 자체가 시작되지 못함. args parsing과 서비스 부트스트랩은 통과하지만 `build · model` 헤더가 안 나오고 외부 LLM 호출이 없음. octo:review의 spawn.sh가 이미 같은 버그를 발견하고 (Issue #173) 모든 provider를 stdin 파이프로 전환한 이력 있음. GLM-5.1은 stdin 변환 후 정상 종료 — opencode CLI에 영구적 패턴 변경 필요. 자세한 진단은 본 디렉토리 `_runlog-glm-debug.stderr` 참조.

## 모델별 리뷰 원본

- [Gemini 3.1 Pro Preview](./code-gemini.md)
- [GLM 5.1](./code-glm.md)

## 운영 노트 (이번 dispatch에서 새로 발견)

이 리뷰를 실제로 돌리면서 발견한 사항으로, 후속으로 `references/multi-llm.md`에 반영해야 함:

1. **OpenCode prompt 전달은 반드시 stdin 파이프** — positional arg는 큰 prompt에서 silent hang. octo의 Issue #173과 동일 증상을 우리도 재현. 패턴: `printf '%s' "$prompt" | opencode run -m model`.

2. **OpenCode file-write contract에는 `--dangerously-skip-permissions` 필수** — Write tool 권한 승인 자동화가 없으면 agent loop가 영원히 멈춤. octo:review는 stdout-capture라 이 플래그 불필요했지만 우리는 file-write라 필수.

3. **opencode-go provider의 wall-clock 현실** — 30k 콜드스타트 + 리모트 라우팅으로, 같은 prompt에서 Gemini가 ~2분 끝낼 작업을 opencode-go/glm-5.1은 7분 가량 걸림. timeout 기본값 540s는 빠듯할 수 있음, 900s 권장.

4. **Agent의 "optional" Read 자제 어려움** — 프롬프트에 "Read only if needed"라고 명시해도 glm-5.1은 모든 참조 파일을 다 Read. 이는 모델 행동 특성이라 회피 어려움. 프롬프트를 "DO NOT Read additional files. The diff alone is sufficient."처럼 강하게 쓰면 효과 있을 수 있음.

<!-- council-flow:review-complete -->

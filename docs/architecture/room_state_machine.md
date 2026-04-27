# Room State Machine

## Purpose
Define canonical state-machine truth for Room/Member/Queue/Battle domains, capability projection, and legacy alias compatibility rules.

## 1. Canonical State Dictionary

### 1.1 Room Phase
- `idle`
- `queue_entering`
- `queue_active`
- `queue_cancelling`
- `battle_allocating`
- `battle_entry_ready`
- `battle_entering`
- `in_battle`
- `returning_to_room`
- `closed`

Rule: room phase only describes business stage. Terminal outcomes must go to reason fields.

### 1.2 Room Last Reason
- `none`
- `queue_cancelled`
- `queue_failed`
- `assignment_expired`
- `match_finalized`
- `manual_battle_started`
- `battle_entry_acknowledged`
- `battle_finished`
- `return_completed`
- `room_closed`

### 1.3 Member Phase
- `idle`
- `ready`
- `queue_locked`
- `in_battle`
- `disconnected`

### 1.4 Queue Phase
- `idle`
- `queued`
- `assignment_pending`
- `allocating_battle`
- `entry_ready`
- `completed`

Queue terminal reason:
- `none`
- `client_cancelled`
- `assignment_expired`
- `assignment_missing`
- `allocation_failed`
- `match_finalized`
- `heartbeat_timeout`

### 1.5 Battle Handoff Phase
- `idle`
- `allocating`
- `ready`
- `entering`
- `active`
- `returning`
- `completed`

Battle terminal reason:
- `none`
- `manual_start`
- `match_assignment`
- `allocation_failed`
- `entry_acknowledged`
- `battle_finished`
- `return_completed`

## 2. FSM Ownership

- Room Aggregate FSM authority: `services/room_service/internal/roomapp/`
- Member Participation FSM authority: `services/room_service/internal/roomapp/`
- Queue FSM authority: `services/game_service/internal/queue/`
- Battle Handoff FSM source facts: `services/game_service/internal/queue/`, projected authority in room snapshot by `room_service`.

## 3. Transition Model

All transitions must be command/event driven:
`current_phase + command + guard -> next_phase + reason + side_effects`.

Rules:
1. No direct raw-string phase assignment in business handlers.
2. No state whitelist permission model like `if state in (...)`.
3. Terminal outcomes do not occupy stable phase slots.

## 4. Capability Projection Rules

Room snapshot must include server-authoritative capabilities:
- `can_toggle_ready`
- `can_start_manual_battle`
- `can_update_selection`
- `can_update_match_room_config`
- `can_enter_queue`
- `can_cancel_queue`
- `can_leave_room`

Rules:
1. Frontend consumes capability directly; no local permission inference as source of truth.
2. Capability is rebuilt from canonical room/member/queue/battle phases after each transition.
3. Room UI button state must align with capability fields.

## 5. Compatibility Alias Rules

During migration, legacy fields may remain:
- `lifecycle_state`
- `queue_state`
- `battle_allocation_state`
- `battle_entry_ready`
- `ready` (member)

Constraints:
1. Legacy fields are derived output only.
2. Business guards and transitions must use canonical fields.
3. Alias derivation must be centralized and deterministic.

## 6. Projection Contract

Room snapshot canonical fields:
- `room_phase`
- `room_phase_reason`
- `queue_phase`
- `queue_terminal_reason`
- `queue_status_text`
- `queue_error_code`
- `queue_user_message`
- `queue_entry_id`
- `battle_entry.phase`
- `battle_entry.terminal_reason`
- `battle_entry.status_text`
- `members[].member_phase`
- capability booleans

Client mapping and UI consumption must prioritize canonical fields over aliases.

## 7. Regression Guardrails

To prevent fallback into raw-string whitelist logic, the following contract tests are mandatory guardrails:

- `tests/contracts/runtime/room_state_machine_projection_contract_test.gd`
  - Guards canonical room snapshot projection keys and capability fields.
  - Guards room protobuf and room_service encoder canonical field coverage.
- `tests/contracts/path/no_raw_room_state_whitelist_contract_test.gd`
  - Guards that RoomViewModel formal path consumes capability fields directly.
  - Guards that leave-room queue-cancel decision is canonical queue-phase driven.

Any change to room/queue/battle/member state contracts must update these guardrails in the same change set.

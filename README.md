# Greedy Dice – LSL HUD Game

PvP dice game for Second Life. Bank **more than 100 points** to win.

---

## Game Rules

| Mechanic | Detail |
|---|---|
| **Challenge** | Attach the HUD, click the root prim to scan for nearby players and send a challenge. |
| **Die selection** | The *challenged* player picks the dice type: **d4, d6, d8, d10, d12, or d20**. |
| **Taking a turn** | Click the visible die to roll. The result is added to your *turn total*. Roll again as many times as you like. |
| **Rolling a 1** | Your turn ends immediately and you lose all *unbanked* turn points. |
| **Banking** | Click **BANK** to add your turn total to your score and pass the turn. You may bank 0 points. |
| **Win condition** | Banking with a total score **over 100** wins the game. Scoring exactly 100 does not win — keep rolling! |
| **Cheat (your turn)** | Click **CHEAT** to upgrade the active die one step (d4→d6→…→d20). Usable multiple times per turn up to d20, after which the button disappears until your turn ends. |
| **Cheat (opponent's turn)** | Click **CHEAT** to instantly end your opponent's turn (they lose all unbanked turn points). The cheat button then hides for the remainder of their turn. |
| **End Game** | Click **END GAME** to reset both HUDs and return to the idle/challenge state. |
| **Open-ended play** | After a winner is announced the game intentionally continues. Players may keep rolling and banking — useful for "double or nothing" arrangements or simply trying to outscore the leader. |

---

## HUD Build Instructions

### Prim layout

Create a **linked set** (one root + ten children) in Second Life and place the scripts as described below.

| Prim | Name | Description | Script |
|---|---|---|---|
| Root | *(any)* | *(any)* | `greedy_controller.lsl` |
| Child | `d4` | `4` | `greedy_die.lsl` |
| Child | `d6` | `6` | `greedy_die.lsl` |
| Child | `d8` | `8` | `greedy_die.lsl` |
| Child | `d10` | `10` | `greedy_die.lsl` |
| Child | `d12` | `12` | `greedy_die.lsl` |
| Child | `d20` | `20` | `greedy_die.lsl` |
| Child | `Bank` | *(any)* | `greedy_bank.lsl` |
| Child | `Cheat` | *(any)* | `greedy_cheat.lsl` |
| Child | `End Game` | *(any)* | `greedy_endgame.lsl` |
| Child | `Score Display` | *(any)* | `greedy_display.lsl` |

> **Important:** The die prim's **Description** field must be set to the plain integer face count (`4`, `6`, `8`, `10`, `12`, or `20`) *before* the script is added. The script reads its own prim description on startup to identify which die it is.

### Script placement

1. Open the **Contents** tab of each prim.
2. Create a new script (or drag in an existing one from inventory).
3. Paste the corresponding `.lsl` source from the `scripts/` folder.
4. Save.

All child prims start invisible. They show and hide automatically based on game state.

---

## Communication Architecture

| Channel | Purpose |
|---|---|
| `LOBBY_CHANNEL` (`-987654321`) | Region-wide challenge broadcast sent via `llRegionSayTo` (targeted, not heard by others). |
| Private game channel | Derived by XOR-ing the first 7 hex digits of both players' UUIDs. Negative and unique per pair of players. |
| `llMessageLinked` | Internal HUD communication between the controller (root prim) and child prims. |

### Link-message numbers

| Number | Direction | Meaning |
|---|---|---|
| `1` | Controller → prims | Game reset / idle |
| `2` | Controller → prims | My turn started; `str` = active die face count |
| `3` | Controller → prims | Opponent's turn started |
| `4` | Controller → prims | Score text update; `str` = display string |
| `5` | Controller → prims | Hide cheat button |
| `6` | Controller → prims | Show cheat button |
| `100` | Prim → controller | Die rolled; `str` = roll result integer |
| `101` | Prim → controller | Bank button clicked |
| `102` | Prim → controller | Cheat button clicked |
| `103` | Prim → controller | End Game button clicked |

---

## Files

```
scripts/
  greedy_controller.lsl   Root prim – game state machine & networking
  greedy_die.lsl          Shared die script (used in all six die prims)
  greedy_bank.lsl         Bank button
  greedy_cheat.lsl        Cheat button
  greedy_endgame.lsl      End Game button
  greedy_display.lsl      Score / status floating-text display
```

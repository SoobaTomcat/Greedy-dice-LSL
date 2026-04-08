// ============================================================
// Greedy Dice – Cheat Button Script
//
// Place in a child prim named "Cheat".
//
// Behaviour:
//   • During YOUR turn  – upgrades the active die one step
//     (d4→d6→d8→d10→d12→d20).  Once at d20 the button hides
//     until the turn ends.  Multiple upgrades per turn are
//     allowed up to the d20 cap.
//   • During OPPONENT's turn – immediately ends their turn
//     (they lose all unbanked turn points).  Button then hides
//     for the remainder of their turn.
// ============================================================

// Link-message numbers (must match greedy_controller.lsl)
integer MSG_GAME_RESET = 1;
integer MSG_MY_TURN    = 2;
integer MSG_OPP_TURN   = 3;
integer MSG_CHEAT_HIDE = 5;
integer MSG_CHEAT_SHOW = 6;
integer MSG_CHEAT_HIT  = 102;

integer active = FALSE;

default
{
    state_entry()
    {
        llSetAlpha(0.0, ALL_SIDES);
        llSetText("", ZERO_VECTOR, 0.0);
        active = FALSE;
    }

    touch_start(integer nd)
    {
        if (!active) return;
        llMessageLinked(LINK_ROOT, MSG_CHEAT_HIT, "", NULL_KEY);
    }

    link_message(integer sender, integer num, string str, key id)
    {
        if (num == MSG_MY_TURN || num == MSG_OPP_TURN || num == MSG_CHEAT_SHOW)
        {
            llSetAlpha(1.0, ALL_SIDES);
            llSetText("CHEAT", <1.0, 0.5, 0.0>, 1.0);
            active = TRUE;
        }
        else if (num == MSG_CHEAT_HIDE || num == MSG_GAME_RESET)
        {
            llSetAlpha(0.0, ALL_SIDES);
            llSetText("", ZERO_VECTOR, 0.0);
            active = FALSE;
        }
    }
}

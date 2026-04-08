// ============================================================
// Greedy Dice – End Game Button Script
//
// Place in a child prim named "End Game".
// Visible whenever a game is in progress (either player's turn).
// Clicking sends MSG_END_HIT to the controller which resets
// the HUD on both sides, allowing a new challenge to begin.
// ============================================================

// Link-message numbers (must match greedy_controller.lsl)
integer MSG_GAME_RESET = 1;
integer MSG_MY_TURN    = 2;
integer MSG_OPP_TURN   = 3;
integer MSG_END_HIT    = 103;

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
        llMessageLinked(LINK_ROOT, MSG_END_HIT, "", NULL_KEY);
    }

    link_message(integer sender, integer num, string str, key id)
    {
        if (num == MSG_MY_TURN || num == MSG_OPP_TURN)
        {
            llSetAlpha(1.0, ALL_SIDES);
            llSetText("END GAME", <1.0, 0.0, 0.0>, 1.0);
            active = TRUE;
        }
        else if (num == MSG_GAME_RESET)
        {
            llSetAlpha(0.0, ALL_SIDES);
            llSetText("", ZERO_VECTOR, 0.0);
            active = FALSE;
        }
    }
}

// ============================================================
// Greedy Dice – Bank Button Script
//
// Place in a child prim named "Bank".
// Visible and clickable only during the local player's turn.
// Clicking sends MSG_BANK_HIT to the controller.
// Banking 0 points is intentionally allowed.
// ============================================================

// Link-message numbers (must match greedy_controller.lsl)
integer MSG_GAME_RESET = 1;
integer MSG_MY_TURN    = 2;
integer MSG_OPP_TURN   = 3;
integer MSG_BANK_HIT   = 101;

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
        llMessageLinked(LINK_ROOT, MSG_BANK_HIT, "", NULL_KEY);
    }

    link_message(integer sender, integer num, string str, key id)
    {
        if (num == MSG_MY_TURN)
        {
            llSetAlpha(1.0, ALL_SIDES);
            llSetText("BANK", <0.0, 1.0, 0.0>, 1.0);
            active = TRUE;
        }
        else if (num == MSG_OPP_TURN || num == MSG_GAME_RESET)
        {
            llSetAlpha(0.0, ALL_SIDES);
            llSetText("", ZERO_VECTOR, 0.0);
            active = FALSE;
        }
    }
}

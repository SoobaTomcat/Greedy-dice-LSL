// ============================================================
// Greedy Dice – Score Display Script
//
// Place in a child prim named "Score Display".
// This prim has no touch interaction; it only shows floating
// text that the controller sends via MSG_SCORE_TXT.
// ============================================================

// Link-message number (must match greedy_controller.lsl)
integer MSG_SCORE_TXT = 4;

default
{
    state_entry()
    {
        llSetText("=== GREEDY DICE ===\nIdle – waiting for game...",
                  <1.0, 1.0, 1.0>, 1.0);
    }

    link_message(integer sender, integer num, string str, key id)
    {
        if (num == MSG_SCORE_TXT)
            llSetText(str, <1.0, 1.0, 1.0>, 1.0);
    }
}

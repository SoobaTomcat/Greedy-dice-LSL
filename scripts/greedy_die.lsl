// ============================================================
// Greedy Dice – Die Prim Script
//
// Place ONE copy of this script in each of the six die prims.
// Before placing the script, set the prim's DESCRIPTION to the
// number of faces for that die:
//
//   Prim name "d4"  → description "4"
//   Prim name "d6"  → description "6"
//   Prim name "d8"  → description "8"
//   Prim name "d10" → description "10"
//   Prim name "d12" → description "12"
//   Prim name "d20" → description "20"
//
// The script reads its own prim description at startup to
// discover its face count; no per-die edits are required.
// ============================================================

// Link-message numbers (must match greedy_controller.lsl)
integer MSG_GAME_RESET = 1;
integer MSG_MY_TURN    = 2;
integer MSG_OPP_TURN   = 3;
integer MSG_DIE_ROLLED = 100;

integer dieSize  = 0;    // Face count read from prim description
integer isActive = FALSE; // TRUE when this die is the selected die on our turn

default
{
    state_entry()
    {
        // Read face count from this prim's own description
        dieSize = (integer)llList2String(
            llGetLinkPrimitiveParams(llGetLinkNumber(), [PRIM_DESC]), 0);

        if (dieSize < 2) dieSize = 6; // safety fallback

        // Hidden until activated
        llSetAlpha(0.0, ALL_SIDES);
        llSetText("", ZERO_VECTOR, 0.0);
        isActive = FALSE;
    }

    touch_start(integer nd)
    {
        if (!isActive) return;

        // Roll this die: uniform integer in [1 .. dieSize]
        integer roll = (integer)llFrand((float)dieSize) + 1;

        llSetText("d" + (string)dieSize + "\n" + (string)roll,
                  <1.0, 1.0, 1.0>, 1.0);

        // Report roll to the controller (root prim)
        llMessageLinked(LINK_ROOT, MSG_DIE_ROLLED, (string)roll, NULL_KEY);

        // Clear the roll display after 2 s
        llSetTimerEvent(2.0);
    }

    timer()
    {
        llSetTimerEvent(0.0);
        if (isActive)
            llSetText("d" + (string)dieSize, <1.0, 1.0, 1.0>, 1.0);
    }

    link_message(integer sender, integer num, string str, key id)
    {
        if (num == MSG_MY_TURN)
        {
            // Show only the die whose face count matches the active die
            integer activeDie = (integer)str;
            if (activeDie == dieSize)
            {
                llSetAlpha(1.0, ALL_SIDES);
                llSetText("d" + (string)dieSize, <1.0, 1.0, 1.0>, 1.0);
                isActive = TRUE;
            }
            else
            {
                llSetAlpha(0.0, ALL_SIDES);
                llSetText("", ZERO_VECTOR, 0.0);
                isActive = FALSE;
            }
        }
        else if (num == MSG_OPP_TURN || num == MSG_GAME_RESET)
        {
            llSetAlpha(0.0, ALL_SIDES);
            llSetText("", ZERO_VECTOR, 0.0);
            isActive = FALSE;
            llSetTimerEvent(0.0);
        }
    }
}

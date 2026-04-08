// ============================================================
// Greedy Dice – HUD Controller Script
//
// Place this script in the ROOT prim of the HUD linkset.
//
// The root prim itself acts as the "click to challenge" button
// while the game is idle.  All other prims are child prims.
//
// Link-message protocol
// ---------------------
// Outgoing (controller → all prims via LINK_SET):
//   MSG_GAME_RESET  1  – game reset / idle; hide all interactables
//   MSG_MY_TURN     2  – my turn; str = active die size as integer string
//   MSG_OPP_TURN    3  – opponent's turn; restrict interactables
//   MSG_SCORE_TXT   4  – score/status text; str = display text
//   MSG_CHEAT_HIDE  5  – hide cheat button (reached d20 or used on opp turn)
//   MSG_CHEAT_SHOW  6  – show cheat button again
//
// Incoming (child prims → controller via LINK_ROOT):
//   MSG_DIE_ROLLED  100 – die was clicked; str = roll integer string
//   MSG_BANK_HIT    101 – bank button clicked
//   MSG_CHEAT_HIT   102 – cheat button clicked
//   MSG_END_HIT     103 – end-game button clicked
// ============================================================

// ---- Outgoing link-message numbers ----
integer MSG_GAME_RESET = 1;
integer MSG_MY_TURN    = 2;
integer MSG_OPP_TURN   = 3;
integer MSG_SCORE_TXT  = 4;
integer MSG_CHEAT_HIDE = 5;
integer MSG_CHEAT_SHOW = 6;

// ---- Incoming link-message numbers ----
integer MSG_DIE_ROLLED = 100;
integer MSG_BANK_HIT   = 101;
integer MSG_CHEAT_HIT  = 102;
integer MSG_END_HIT    = 103;

// ---- Region channels ----
integer LOBBY_CHANNEL = -987654321;  // All HUDs listen here for challenges

// ---- Die order (ascending) ----
list DIE_SEQUENCE = [4, 6, 8, 10, 12, 20];

// ---- Game-state constants ----
integer GS_IDLE        = 0;   // No game; waiting for challenge
integer GS_CHALLENGING = 1;   // Challenger chose target; awaiting opponent pick
integer GS_PICK_DIE    = 2;   // Challenged player selecting die (or challenger waiting)
integer GS_MY_TURN     = 3;   // Active turn for the local player
integer GS_OPP_TURN    = 4;   // Opponent's turn

// ---- Persistent variables ----
integer gameState   = 0;
integer myScore     = 0;
integer oppScore    = 0;
integer turnTotal   = 0;
integer currentDie  = 6;     // Active die face count
integer isChallenger = FALSE; // TRUE when this player sent the challenge

key    myKey;
string myName;
key    oppKey;
string oppName = "Opponent";

integer gameChannel = 0;
integer gcHandle    = 0;   // listen handle for private game channel
integer lobbyHandle = 0;   // listen handle for lobby channel

// ---- Dialog state ----
integer dlgChannel = 0;
integer dlgHandle  = 0;
list    nearNames  = [];
list    nearKeys   = [];

// ---- Helpers ----

// Build the floating-text score string
string scoreText()
{
    string who;
    if      (gameState == GS_MY_TURN)  who = "*** YOUR TURN ***";
    else if (gameState == GS_OPP_TURN) who = "*** " + oppName + "'s TURN ***";
    else                               who = "Idle – click to challenge";

    string lead = "";
    if (myScore > 100 && myScore >= oppScore)
        lead = "\n>>> YOU are leading! <<<";
    else if (oppScore > 100 && oppScore > myScore)
        lead = "\n>>> " + oppName + " is leading! <<<";

    return "=== GREEDY DICE ===\n"
         + "You: "    + (string)myScore   + "   "
         + oppName    + ": " + (string)oppScore + "\n"
         + "Turn:  "  + (string)turnTotal + "\n"
         + who + lead;
}

// Broadcast score text to all display prims
broadcastScore()
{
    llMessageLinked(LINK_SET, MSG_SCORE_TXT, scoreText(), NULL_KEY);
}

// Transition to "my turn"
startMyTurn()
{
    gameState = GS_MY_TURN;
    turnTotal = 0;
    llMessageLinked(LINK_SET, MSG_MY_TURN,    (string)currentDie, NULL_KEY);
    llMessageLinked(LINK_SET, MSG_CHEAT_SHOW, "",                 NULL_KEY);
    broadcastScore();
}

// Transition to "opponent's turn"
startOppTurn()
{
    gameState = GS_OPP_TURN;
    turnTotal = 0;
    llMessageLinked(LINK_SET, MSG_OPP_TURN,   "", NULL_KEY);
    llMessageLinked(LINK_SET, MSG_CHEAT_SHOW, "", NULL_KEY);
    broadcastScore();
}

// End local player's turn and hand control to opponent
passToOpponent()
{
    llRegionSayTo(oppKey, gameChannel, "TURN_START|" + (string)currentDie);
    startOppTurn();
}

// Full game reset (called on End Game or when opponent ends game)
doReset()
{
    gameState  = GS_IDLE;
    myScore    = 0;
    oppScore   = 0;
    turnTotal  = 0;
    currentDie = 6;
    oppName    = "Opponent";
    oppKey     = NULL_KEY;

    if (gcHandle)  { llListenRemove(gcHandle);  gcHandle  = 0; }
    if (dlgHandle) { llListenRemove(dlgHandle); dlgHandle = 0; }

    llMessageLinked(LINK_SET, MSG_GAME_RESET, "", NULL_KEY);
    broadcastScore();
    llSetText("GREEDY DICE\nClick to challenge", <1.0, 1.0, 0.0>, 1.0);
}

// ============================================================
default
{
    state_entry()
    {
        myKey       = llGetOwner();
        myName      = llKey2Name(myKey);
        lobbyHandle = llListen(LOBBY_CHANNEL, "", NULL_KEY, "");
        llSetText("GREEDY DICE\nClick to challenge", <1.0, 1.0, 0.0>, 1.0);
        broadcastScore();
    }

    // Refresh owner key / lobby listener on (re-)attach
    attach(key id)
    {
        if (id != NULL_KEY)
        {
            myKey = llGetOwner();
            myName = llKey2Name(myKey);
            if (!lobbyHandle)
                lobbyHandle = llListen(LOBBY_CHANNEL, "", NULL_KEY, "");
        }
    }

    // Root prim touched → start a challenge scan
    touch_start(integer nd)
    {
        if (gameState != GS_IDLE) return;
        llSensor("", NULL_KEY, AGENT, 20.0, PI);
    }

    sensor(integer nd)
    {
        nearNames = [];
        nearKeys  = [];
        integer i;
        for (i = 0; i < nd && llGetListLength(nearNames) < 12; i++)
        {
            key k = llDetectedKey(i);
            if (k != myKey)
            {
                nearNames += [llDetectedName(i)];
                nearKeys  += [(string)k];
            }
        }
        if (!llGetListLength(nearNames))
        {
            llOwnerSay("No other players found nearby.");
            return;
        }
        if (dlgHandle) { llListenRemove(dlgHandle); dlgHandle = 0; }
        dlgChannel = -1 - (integer)llFrand(2000000.0);
        dlgHandle  = llListen(dlgChannel, "", myKey, "");
        gameState  = GS_CHALLENGING;
        llDialog(myKey, "Challenge which player?", nearNames, dlgChannel);
    }

    no_sensor()
    {
        llOwnerSay("No other players found nearby.");
    }

    // -------------------------------------------------------
    listen(integer ch, string name, key id, string msg)
    {
        // ---- Dialog responses (from local player) ----
        if (ch == dlgChannel)
        {
            llListenRemove(dlgHandle);
            dlgHandle = 0;

            // --- Challenger picked a target ---
            if (gameState == GS_CHALLENGING)
            {
                integer idx = llListFindList(nearNames, [msg]);
                if (idx < 0) { gameState = GS_IDLE; return; }

                oppName = msg;
                oppKey  = (key)llList2Key(nearKeys, idx);

                // Derive a private game channel from both UUIDs
                integer h1 = (integer)("0x" + llGetSubString((string)myKey,  0, 6));
                integer h2 = (integer)("0x" + llGetSubString((string)oppKey, 0, 6));
                gameChannel = h1 ^ h2;
                if (gameChannel >= 0) gameChannel = -(gameChannel + 1);

                if (gcHandle) { llListenRemove(gcHandle); gcHandle = 0; }
                gcHandle     = llListen(gameChannel, "", NULL_KEY, "");
                isChallenger = TRUE;
                gameState    = GS_PICK_DIE;

                // Send challenge to opponent over lobby channel
                llRegionSayTo(oppKey, LOBBY_CHANNEL,
                    "CHALLENGE|" + myName
                    + "|" + (string)myKey
                    + "|" + (string)gameChannel);

                llOwnerSay("Challenge sent to " + oppName + "! Waiting for their die choice...");
                llSetText("Waiting for " + oppName + "...", <1.0, 0.6, 0.0>, 1.0);
                return;
            }

            // --- Challenged player picked a die (or declined) ---
            if (gameState == GS_PICK_DIE && !isChallenger)
            {
                if (msg == "Decline")
                {
                    llRegionSayTo(oppKey, gameChannel, "DECLINE");
                    doReset();
                    return;
                }
                // Parse "d6" → 6
                integer ds = (integer)llGetSubString(msg, 1, -1);
                if (llListFindList(DIE_SEQUENCE, [ds]) < 0) return;

                currentDie = ds;
                // Tell challenger which die was picked; they go first
                llRegionSayTo(oppKey, gameChannel, "DIE_CHOSEN|" + (string)ds);
                llOwnerSay("You chose d" + (string)ds + "! " + oppName + " goes first.");
                llSetText("GREEDY DICE", <1.0, 1.0, 0.0>, 1.0);
                startOppTurn();   // challenger's turn, so we wait
                return;
            }
            return;
        }

        // ---- Lobby: incoming challenge ----
        if (ch == LOBBY_CHANNEL)
        {
            list   p   = llParseString2List(msg, ["|"], []);
            string cmd = llList2String(p, 0);
            if (cmd != "CHALLENGE") return;
            if (gameState != GS_IDLE) return;  // Already in a game

            string challengerName = llList2String(p, 1);
            key    challengerKey  = (key)llList2String(p, 2);
            integer incomingCh    = (integer)llList2String(p, 3);

            // Ignore self-challenges (edge-case guard)
            if (challengerKey == myKey) return;

            oppName     = challengerName;
            oppKey      = challengerKey;
            gameChannel = incomingCh;
            isChallenger = FALSE;

            if (gcHandle) { llListenRemove(gcHandle); gcHandle = 0; }
            gcHandle = llListen(gameChannel, "", NULL_KEY, "");

            if (dlgHandle) { llListenRemove(dlgHandle); dlgHandle = 0; }
            dlgChannel = -1 - (integer)llFrand(2000000.0);
            dlgHandle  = llListen(dlgChannel, "", myKey, "");

            gameState = GS_PICK_DIE;
            llDialog(myKey,
                challengerName + " challenges you!\nPick your dice:",
                ["d4","d6","d8","d10","d12","d20","Decline"],
                dlgChannel);
            return;
        }

        // ---- Private game channel: opponent messages ----
        if (ch == gameChannel)
        {
            list   p   = llParseString2List(msg, ["|"], []);
            string cmd = llList2String(p, 0);

            if (cmd == "DECLINE")
            {
                // Opponent declined our challenge
                gameState = GS_IDLE;
                llOwnerSay(oppName + " declined your challenge.");
                llSetText("GREEDY DICE\nClick to challenge", <1.0, 1.0, 0.0>, 1.0);
            }
            else if (cmd == "DIE_CHOSEN")
            {
                // We are the challenger; opponent chose the die; our turn first
                currentDie = (integer)llList2String(p, 1);
                llOwnerSay(oppName + " chose d" + (string)currentDie + ". Your turn first!");
                llSetText("GREEDY DICE", <1.0, 1.0, 0.0>, 1.0);
                startMyTurn();
            }
            else if (cmd == "TURN_START")
            {
                // Opponent passed the turn to us
                currentDie = (integer)llList2String(p, 1);
                startMyTurn();
            }
            else if (cmd == "BANK")
            {
                // Opponent banked some points
                oppScore = (integer)llList2String(p, 1);
                if (llList2String(p, 2) == "WIN")
                    llOwnerSay(">>> " + oppName + " banked "
                        + (string)oppScore
                        + " pts and is WINNING!  Keep playing or press End Game.");
                broadcastScore();
            }
            else if (cmd == "CHEAT_END_TURN")
            {
                // Opponent cheated to end our turn
                if (gameState == GS_MY_TURN)
                {
                    llOwnerSay(oppName + " used CHEAT – your turn ends! Turn points lost.");
                    turnTotal = 0;
                    passToOpponent();
                }
            }
            else if (cmd == "END_GAME")
            {
                doReset();
                llOwnerSay(oppName + " ended the game. HUD reset.");
            }
        }
    }

    // -------------------------------------------------------
    link_message(integer sender, integer num, string str, key id)
    {
        // ---- Die rolled ----
        if (num == MSG_DIE_ROLLED)
        {
            if (gameState != GS_MY_TURN) return;
            integer roll = (integer)str;
            if (roll == 1)
            {
                turnTotal = 0;
                llOwnerSay("Rolled a 1!  Turn over – turn points lost.");
                passToOpponent();
            }
            else
            {
                turnTotal += roll;
                llOwnerSay("Rolled " + str + "!  Turn total: " + (string)turnTotal);
                broadcastScore();
            }
        }

        // ---- Bank button hit ----
        else if (num == MSG_BANK_HIT)
        {
            if (gameState != GS_MY_TURN) return;
            myScore   += turnTotal;
            turnTotal  = 0;

            if (myScore > 100)
            {
                // Announce win; game intentionally stays open-ended
                llRegionSayTo(oppKey, gameChannel,
                    "BANK|" + (string)myScore + "|WIN");
                llOwnerSay(">>> YOU WIN with "
                    + (string)myScore
                    + " pts!  Game stays open – press End Game to reset.");
            }
            else
            {
                llRegionSayTo(oppKey, gameChannel, "BANK|" + (string)myScore);
            }

            broadcastScore();
            passToOpponent();   // always pass turn after banking
        }

        // ---- Cheat button hit ----
        else if (num == MSG_CHEAT_HIT)
        {
            if (gameState == GS_MY_TURN)
            {
                // Upgrade die one step toward d20
                integer idx = llListFindList(DIE_SEQUENCE, [currentDie]);
                if (idx < 0 || idx == llGetListLength(DIE_SEQUENCE) - 1)
                {
                    llOwnerSay("Already at d20 – cheat exhausted for this turn.");
                    llMessageLinked(LINK_SET, MSG_CHEAT_HIDE, "", NULL_KEY);
                    return;
                }
                currentDie = llList2Integer(DIE_SEQUENCE, idx + 1);
                llOwnerSay("CHEAT!  Die upgraded to d" + (string)currentDie + ".");
                if (currentDie == 20)
                    llMessageLinked(LINK_SET, MSG_CHEAT_HIDE, "", NULL_KEY);
                // Refresh die visibility with new size
                llMessageLinked(LINK_SET, MSG_MY_TURN, (string)currentDie, NULL_KEY);
            }
            else if (gameState == GS_OPP_TURN)
            {
                // Immediately end opponent's turn
                llRegionSayTo(oppKey, gameChannel, "CHEAT_END_TURN");
                llOwnerSay("CHEAT!  " + oppName + "'s turn ended.");
                llMessageLinked(LINK_SET, MSG_CHEAT_HIDE, "", NULL_KEY);
            }
        }

        // ---- End Game button hit ----
        else if (num == MSG_END_HIT)
        {
            if (gameState == GS_IDLE) return;
            llRegionSayTo(oppKey, gameChannel, "END_GAME");
            doReset();
            llOwnerSay("Game ended.  HUD reset.");
        }
    }
}

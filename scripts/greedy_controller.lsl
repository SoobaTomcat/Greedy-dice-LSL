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
//   MSG_WAITING     4  – challenge sent; only End Game button shown
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
integer MSG_WAITING    = 4;   // Challenge sent; only End Game button shown
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
integer baseDie     = 6;     // Die chosen at game start; never modified by cheating
integer currentDie  = 6;     // Active die this turn; reset to baseDie each turn start
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

// ---- HUD-presence ping state ----
integer pingChannel = 0;
integer pingHandle  = 0;

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

    string bankable = "";
    if (gameState == GS_MY_TURN && turnTotal > 0)
        bankable = "Bank: " + (string)(myScore + turnTotal) + "\n";

    return "=== GREEDY DICE ===\n"
         + myName  + ": " + (string)myScore   + "\n"
         + oppName + ": " + (string)oppScore  + "\n"
         + bankable
         + "Turn:  "  + (string)turnTotal + "\n"
         + who + lead;
}

// Set score text on the root prim
broadcastScore()
{
    llSetText(scoreText(), <1.0, 1.0, 1.0>, 1.0);
}

// Transition to "my turn"
startMyTurn()
{
    llSetAlpha(0.0, ALL_SIDES);
    gameState = GS_MY_TURN;
    turnTotal = 0;
    llMessageLinked(LINK_SET, MSG_MY_TURN,    (string)currentDie, NULL_KEY);
    llMessageLinked(LINK_SET, MSG_CHEAT_SHOW, "",                 NULL_KEY);
    broadcastScore();
}

// Transition to "opponent's turn"
startOppTurn()
{
    llSetAlpha(0.0, ALL_SIDES);
    gameState = GS_OPP_TURN;
    turnTotal = 0;
    llMessageLinked(LINK_SET, MSG_OPP_TURN,   "", NULL_KEY);
    llMessageLinked(LINK_SET, MSG_CHEAT_SHOW, "", NULL_KEY);
    broadcastScore();
}

// End local player's turn and hand control to opponent
passToOpponent()
{
    currentDie = baseDie;   // Revert any cheat upgrade; opponent gets the base die
    llRegionSayTo(oppKey, gameChannel, "TURN_START|" + (string)baseDie);
    startOppTurn();
}

// Full game reset (called on End Game or when opponent ends game)
doReset()
{
    gameState  = GS_IDLE;
    myScore    = 0;
    oppScore   = 0;
    turnTotal  = 0;
    baseDie    = 6;
    currentDie = 6;
    oppName    = "Opponent";
    oppKey     = NULL_KEY;

    if (gcHandle)   { llListenRemove(gcHandle);   gcHandle   = 0; }
    if (dlgHandle)  { llListenRemove(dlgHandle);  dlgHandle  = 0; }
    if (pingHandle) { llListenRemove(pingHandle); pingHandle = 0; }
    llSetTimerEvent(0.0);

    llMessageLinked(LINK_SET, MSG_GAME_RESET, "", NULL_KEY);
    broadcastScore();
    llSetAlpha(1.0, ALL_SIDES);
}

// ============================================================
default
{
    state_entry()
    {
        llSetAlpha(1.0, ALL_SIDES);
        myKey       = llGetOwner();
        myName      = llKey2Name(myKey);
        lobbyHandle = llListen(LOBBY_CHANNEL, "", NULL_KEY, "");
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

    // Root prim touched → start a HUD-presence scan
    touch_start(integer nd)
    {
        if (gameState != GS_IDLE) return;
        // Clear previous results and cancel any in-progress scan
        nearNames = [];
        nearKeys  = [];
        if (pingHandle) { llListenRemove(pingHandle); pingHandle = 0; }
        llSetTimerEvent(0.0);
        pingChannel = -1000000 - (integer)llFrand(1000000.0);
        pingHandle  = llListen(pingChannel, "", NULL_KEY, "");
        llSensor("", NULL_KEY, AGENT, 20.0, PI);
    }

    sensor(integer nd)
    {
        // Ping each nearby agent; only HUDs wearing this game will reply
        integer i;
        integer sent = 0;
        for (i = 0; i < nd && sent < 12; i++)
        {
            key k = llDetectedKey(i);
            if (k != myKey)
            {
                llRegionSayTo(k, LOBBY_CHANNEL,
                    "HUD_PING|" + (string)myKey + "|" + (string)pingChannel);
                ++sent;
            }
        }
        if (!sent)
        {
            if (pingHandle) { llListenRemove(pingHandle); pingHandle = 0; }
            llOwnerSay("No other players found nearby.");
            return;
        }
        llSetTimerEvent(2.0);   // Wait 2 s for HUD_PONG replies
    }

    no_sensor()
    {
        if (pingHandle) { llListenRemove(pingHandle); pingHandle = 0; }
        llSetTimerEvent(0.0);
        llOwnerSay("No other players found nearby.");
    }

    timer()
    {
        llSetTimerEvent(0.0);
        if (pingHandle) { llListenRemove(pingHandle); pingHandle = 0; }
        if (gameState != GS_IDLE)           // State changed before timer fired
        {
            nearNames = [];
            nearKeys  = [];
            return;
        }
        if (!llGetListLength(nearNames))
        {
            llOwnerSay("No other players with the Greedy Dice HUD found nearby.");
            return;
        }
        if (dlgHandle) { llListenRemove(dlgHandle); dlgHandle = 0; }
        dlgChannel = -1000000 - (integer)llFrand(1000000.0);
        dlgHandle  = llListen(dlgChannel, "", myKey, "");
        gameState  = GS_CHALLENGING;
        llDialog(myKey, "Challenge which player?", nearNames, dlgChannel);
    }

    // -------------------------------------------------------
    listen(integer ch, string name, key id, string msg)
    {
        // ---- HUD-presence pong (challenger collects responding HUDs) ----
        if (ch == pingChannel)
        {
            list   p   = llParseString2List(msg, ["|"], []);
            if (llList2String(p, 0) == "HUD_PONG")
            {
                string pName = llList2String(p, 1);
                string pKey  = llList2String(p, 2);
                // Avoid duplicates; cap at 12 entries (LSL dialog button limit)
                if (llListFindList(nearKeys, [pKey]) < 0
                        && llGetListLength(nearNames) < 12)
                {
                    nearNames += [pName];
                    nearKeys  += [pKey];
                }
            }
            return;
        }

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

                // Show End Game button so the challenger can quit while waiting
                llMessageLinked(LINK_SET, MSG_WAITING, "", NULL_KEY);

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
                baseDie    = ds;
                // Tell challenger which die was picked; they go first
                llRegionSayTo(oppKey, gameChannel, "DIE_CHOSEN|" + (string)ds);
                llOwnerSay("You chose d" + (string)ds + "! " + oppName + " goes first.");
                startOppTurn();   // challenger's turn, so we wait
                return;
            }
            return;
        }

        // ---- Lobby: incoming messages ----
        if (ch == LOBBY_CHANNEL)
        {
            list   p   = llParseString2List(msg, ["|"], []);
            string cmd = llList2String(p, 0);

            // HUD-presence ping – reply so the sender knows we have the HUD
            if (cmd == "HUD_PING")
            {
                key    requesterKey  = (key)llList2String(p, 1);
                integer replyChannel = (integer)llList2String(p, 2);
                if (requesterKey != myKey)
                    llRegionSayTo(requesterKey, replyChannel,
                        "HUD_PONG|" + myName + "|" + (string)myKey);
                return;
            }

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
            dlgChannel = -1000000 - (integer)llFrand(1000000.0);
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
                doReset();
                llOwnerSay(oppName + " declined your challenge.");
            }
            else if (cmd == "DIE_CHOSEN")
            {
                // We are the challenger; opponent chose the die; our turn first
                currentDie = (integer)llList2String(p, 1);
                baseDie    = currentDie;
                llOwnerSay(oppName + " chose d" + (string)currentDie + ". Your turn first!");
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

IMPLEMENTATION MODULE NPC;

(* NPC / set-figure system matching original FTA.
   Data from setfig_table[] and speeches[] in the original. *)

FROM Strings IMPORT Assign;
FROM Actor IMPORT actors, actorCount, MaxActors,
                  TypeSetfig, StStill, StDead, GoalWait, GoalStand;
FROM WorldObj IMPORT objects, objCount;
FROM Assets IMPORT currentRegion;

TYPE
  SetfigDef = RECORD
    spriteBank: INTEGER;
    imageBase:  INTEGER;
    canTalk:    BOOLEAN
  END;

VAR
  sfTable: ARRAY [0..13] OF SetfigDef;

  (* Track which WorldObj indices are currently materialized as actors *)
  materialized: ARRAY [0..199] OF BOOLEAN;

  (* Speech table — transcribed from original narr.c speeches[] *)
  speeches: ARRAY [0..49] OF ARRAY [0..127] OF CHAR;

(* --- Setfig table init --- *)

PROCEDURE InitSetfigTable;
BEGIN
  sfTable[0].spriteBank := 0; sfTable[0].imageBase := 0; sfTable[0].canTalk := TRUE;
  sfTable[1].spriteBank := 0; sfTable[1].imageBase := 4; sfTable[1].canTalk := TRUE;
  sfTable[2].spriteBank := 1; sfTable[2].imageBase := 0; sfTable[2].canTalk := FALSE;
  sfTable[3].spriteBank := 1; sfTable[3].imageBase := 1; sfTable[3].canTalk := FALSE;
  sfTable[4].spriteBank := 1; sfTable[4].imageBase := 2; sfTable[4].canTalk := FALSE;
  sfTable[5].spriteBank := 1; sfTable[5].imageBase := 4; sfTable[5].canTalk := TRUE;
  sfTable[6].spriteBank := 1; sfTable[6].imageBase := 6; sfTable[6].canTalk := FALSE;
  sfTable[7].spriteBank := 1; sfTable[7].imageBase := 7; sfTable[7].canTalk := FALSE;
  sfTable[8].spriteBank := 2; sfTable[8].imageBase := 0; sfTable[8].canTalk := FALSE;
  sfTable[9].spriteBank := 3; sfTable[9].imageBase := 0; sfTable[9].canTalk := FALSE;
  sfTable[10].spriteBank := 3; sfTable[10].imageBase := 6; sfTable[10].canTalk := FALSE;
  sfTable[11].spriteBank := 3; sfTable[11].imageBase := 7; sfTable[11].canTalk := FALSE;
  sfTable[12].spriteBank := 4; sfTable[12].imageBase := 0; sfTable[12].canTalk := TRUE;
  sfTable[13].spriteBank := 4; sfTable[13].imageBase := 4; sfTable[13].canTalk := TRUE
END InitSetfigTable;

PROCEDURE GetSetfigSprite(race: INTEGER; VAR bank, frame: INTEGER);
BEGIN
  IF (race >= 0) AND (race <= 13) THEN
    bank := sfTable[race].spriteBank;
    frame := sfTable[race].imageBase
  ELSE
    bank := 0;
    frame := 0
  END
END GetSetfigSprite;

(* --- Speech table init --- *)

PROCEDURE InitSpeeches;
BEGIN
  Assign("% tried to talk but got only a snarl.", speeches[0]);
  Assign("Human must die! said the goblin-man.", speeches[1]);
  Assign("Doom! wailed the wraith.", speeches[2]);
  Assign("A clattering of bones was the only reply.", speeches[3]);
  Assign("% knew it is a waste of time to talk to a snake.", speeches[4]);
  Assign("...", speeches[5]);
  Assign("There was no reply.", speeches[6]);
  Assign("Die, foolish mortal! he said.", speeches[7]);
  Assign("No need to shout, son! he said.", speeches[8]);
  Assign("Nice weather we're having, isn't it?", speeches[9]);
  Assign("Good luck, sonny! Hope you win!", speeches[10]);
  Assign("If you need to cross the lake, there's a raft north of here.", speeches[11]);
  Assign("Would you like to buy something? said the tavern keeper.", speeches[12]);
  Assign("Good Morning. Hope you slept well.", speeches[13]);
  Assign("Have a drink! said the tavern keeper.", speeches[14]);
  Assign("State your business! said the guard.", speeches[15]);
  Assign("Please, sir, rescue me from this prison! pleaded the princess.", speeches[16]);
  Assign("I cannot help you. My armies are decimated.", speeches[17]);
  Assign("Here is a writ designating you as my official agent.", speeches[18]);
  Assign("I already gave the golden statue to another.", speeches[19]);
  Assign("If you could rescue the princess, the King's courage would be restored.", speeches[20]);
  Assign("Sorry, I have no use for it.", speeches[21]);
  Assign("The dragon's cave is directly north of here.", speeches[22]);
  Assign("Alms! Alms for the poor!", speeches[23]);
  Assign("I have a prophecy for you, m'lord.", speeches[24]);
  Assign("Lovely Jewels, glint in the night!", speeches[25]);
  Assign("Where is the hidden city? How can you find what you cannot see?", speeches[26]);
  Assign("Kind deeds could gain thee a friend from the sea.", speeches[27]);
  Assign("Seek the place darker than night!", speeches[28]);
  Assign("A crystal Orb can help to find things concealed.", speeches[29]);
  Assign("The Witch lives in Grimwood. Her gaze is Death!", speeches[30]);
  Assign("Only the light of the Sun can destroy the Witch's Evil.", speeches[31]);
  Assign("The maiden lies imprisoned in an unreachable castle.", speeches[32]);
  Assign("Tame the golden beast! But what rope could hold it?", speeches[33]);
  Assign("Just what I needed! he said.", speeches[34]);
  Assign("Away with you, young ruffian!", speeches[35]);
  Assign("Seek your enemy on the spirit plane.", speeches[36]);
  Assign("When you wish to travel quickly, seek the power of the Stones.", speeches[37]);
  Assign("Since you are brave of heart, I shall Heal all your wounds.", speeches[38]);
  Assign("Here is one of the golden statues of Azal-Car-Ithil.", speeches[39]);
  Assign("Repent, Sinner!", speeches[40]);
  Assign("None may enter the sacred shrine!", speeches[41]);
  Assign("You have earned the right to enter and claim the prize.", speeches[42]);
  Assign("So this is the so-called Hero. Simply Pathetic!", speeches[43]);
  Assign("The Necromancer has been transformed into a normal man.", speeches[44]);
  Assign("Welcome. Here is one of the golden figurines you need.", speeches[45]);
  Assign("Look into my eyes and Die!! hissed the witch.", speeches[46]);
  Assign("Bring me bones of the ancient King.", speeches[47]);
  Assign("% gave him the ancient bones.", speeches[48]);
  Assign("Well met, traveler.", speeches[49])
END InitSpeeches;

(* --- Materialization --- *)

PROCEDURE MaterializeNPCs(heroX, heroY, region: INTEGER);
VAR i, dx, dy, idx, race: INTEGER;
BEGIN
  FOR i := 0 TO objCount - 1 DO
    IF (objects[i].status = 3) AND
       ((objects[i].region = region) OR (objects[i].region = -1)) THEN
      dx := heroX - objects[i].x;
      dy := heroY - objects[i].y;
      IF dx < 0 THEN dx := -dx END;
      IF dy < 0 THEN dy := -dy END;

      IF (dx < 400) AND (dy < 400) THEN
        (* Close enough — materialize if not already *)
        IF NOT materialized[i] THEN
          IF actorCount < MaxActors THEN
            idx := actorCount;
            race := objects[i].objId;
            IF race > 13 THEN race := 0 END;  (* clamp to setfig table *)
            actors[idx].absX := objects[i].x;
            actors[idx].absY := objects[i].y;
            actors[idx].actorType := TypeSetfig;
            actors[idx].race := race;
            actors[idx].state := StStill;
            actors[idx].goal := GoalWait;
            actors[idx].vitality := 999;
            actors[idx].weapon := 0;
            actors[idx].facing := 4;  (* south by default *)
            actors[idx].visible := TRUE;
            actors[idx].environ := 0;
            actors[idx].tactic := 0;
            actors[idx].velX := 0;
            actors[idx].velY := 0;
            INC(actorCount);
            materialized[i] := TRUE;
          END
        END
      ELSE
        (* Too far — could dematerialize, but keep simple for now *)
      END
    END
  END
END MaterializeNPCs;

(* --- Interaction --- *)

PROCEDURE FindNearestNPC(heroX, heroY: INTEGER): INTEGER;
VAR i, dx, dy, bestDist, dist, bestIdx: INTEGER;
BEGIN
  bestDist := 9999;
  bestIdx := -1;
  FOR i := 1 TO actorCount - 1 DO
    IF (actors[i].actorType = TypeSetfig) AND
       (actors[i].state # StDead) THEN
      dx := heroX - actors[i].absX;
      dy := heroY - actors[i].absY;
      IF dx < 0 THEN dx := -dx END;
      IF dy < 0 THEN dy := -dy END;
      dist := dx + dy;
      IF (dx < 40) AND (dy < 40) AND (dist < bestDist) THEN
        bestDist := dist;
        bestIdx := i;
        (* Face toward player *)
        IF heroX - actors[i].absX > 5 THEN actors[i].facing := 2
        ELSIF heroX - actors[i].absX < -5 THEN actors[i].facing := 6
        ELSIF heroY - actors[i].absY > 5 THEN actors[i].facing := 4
        ELSIF heroY - actors[i].absY < -5 THEN actors[i].facing := 0
        END
      END
    END
  END;
  RETURN bestIdx
END FindNearestNPC;

PROCEDURE NpcName(race: INTEGER; VAR name: ARRAY OF CHAR);
BEGIN
  CASE race OF
    0: Assign("a wizard", name) |
    1: Assign("a priest", name) |
    2, 3: Assign("a guard", name) |
    4: Assign("the princess", name) |
    5: Assign("the king", name) |
    6: Assign("a noble", name) |
    7: Assign("the sorceress", name) |
    8: Assign("the tavern keeper", name) |
    9: Assign("the witch", name) |
   10: Assign("a spectre", name) |
   11: Assign("a ghost", name) |
   12: Assign("a ranger", name) |
   13: Assign("a beggar", name)
  ELSE
    Assign("someone", name)
  END
END NpcName;

PROCEDURE LookAtNPC(heroX, heroY: INTEGER; VAR desc: ARRAY OF CHAR): BOOLEAN;
VAR idx: INTEGER;
BEGIN
  idx := FindNearestNPC(heroX, heroY);
  IF idx >= 0 THEN
    NpcName(actors[idx].race, desc);
    RETURN TRUE
  END;
  RETURN FALSE
END LookAtNPC;

(* Select speech index based on NPC race *)
PROCEDURE SelectSpeech(race: INTEGER): INTEGER;
BEGIN
  CASE race OF
    0:  RETURN 27 |   (* wizard — random hint *)
    1:  RETURN 36 |   (* priest *)
    4:  RETURN 16 |   (* princess *)
    5:  RETURN 17 |   (* king *)
    6:  RETURN 20 |   (* noble *)
    7:  RETURN 45 |   (* sorceress *)
    8:  RETURN 12 |   (* bartender *)
    9:  RETURN 46 |   (* witch *)
   10:  RETURN 47 |   (* spectre *)
   12:  RETURN 22 |   (* ranger *)
   13:  RETURN 23     (* beggar *)
  ELSE
    RETURN 49         (* generic *)
  END
END SelectSpeech;

PROCEDURE TalkToNPC(heroX, heroY: INTEGER; VAR speech: ARRAY OF CHAR): BOOLEAN;
VAR idx, race, speechIdx: INTEGER;
BEGIN
  idx := FindNearestNPC(heroX, heroY);
  IF idx < 0 THEN RETURN FALSE END;
  race := actors[idx].race;
  speechIdx := SelectSpeech(race);
  IF (speechIdx >= 0) AND (speechIdx < MaxSpeeches) THEN
    Assign(speeches[speechIdx], speech)
  ELSE
    Assign("...", speech)
  END;
  RETURN TRUE
END TalkToNPC;

PROCEDURE GetSpeech(idx: INTEGER; VAR text: ARRAY OF CHAR);
BEGIN
  IF (idx >= 0) AND (idx < MaxSpeeches) THEN
    Assign(speeches[idx], text)
  ELSE
    Assign("...", text)
  END
END GetSpeech;

PROCEDURE InitNPCs;
VAR i: INTEGER;
BEGIN
  FOR i := 0 TO 199 DO materialized[i] := FALSE END;
  InitSetfigTable;
  InitSpeeches
END InitNPCs;

END NPC.

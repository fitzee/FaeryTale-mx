IMPLEMENTATION MODULE Music;

FROM SYSTEM IMPORT ADDRESS, ADR;
FROM InOut IMPORT WriteString, WriteInt, WriteLn;
FROM Playback IMPORT DeviceID, InitAudio, QuitAudio,
                     OpenDevice, CloseDevice, ResumeDevice,
                     QueueSamples, GetQueuedBytes, ClearQueued,
                     FormatS16;
FROM BinaryIO IMPORT OpenRead, Close, ReadBytes;
FROM Assets IMPORT AssetPath;
FROM Storage IMPORT ALLOCATE, DEALLOCATE;
FROM MathLib IMPORT sin;

CONST
  NumVoices   = 4;
  MaxTracks   = 28;
  WavBufSize  = 1024;   (* 8 waveforms × 128 bytes *)
  VolBufSize  = 2560;   (* 10 envelopes × 256 bytes *)
  WaveLen     = 128;    (* bytes per waveform *)
  EnvLen      = 256;    (* bytes per envelope *)
  OutputRate  = 44100;  (* output sample rate — higher for better quality *)
  TickRate    = 50;     (* Amiga vblank rate (PAL) *)
  SamplesPerTick = OutputRate DIV TickRate;  (* 882 samples at 50Hz tick rate *)
  AmigaClock  = 3546895; (* PAL clock for period→freq *)

TYPE
  Voice = RECORD
    waveNum:    INTEGER;
    volNum:     INTEGER;
    volDelay:   INTEGER;
    vceStat:    INTEGER;
    eventStart: LONGINT;
    eventStop:  LONGINT;
    volPos:     INTEGER;    (* position in volume envelope *)
    volume:     INTEGER;    (* current volume 0-64 *)
    trakPtr:    INTEGER;    (* offset into track data *)
    trakBeg:    INTEGER;    (* loop start offset *)
    period:     INTEGER;    (* current Amiga period *)
    waveOff:    INTEGER;    (* waveform offset within 128-byte block *)
    waveLen:    INTEGER;    (* waveform length in words *)
    phase:      LONGREAL;   (* playback phase accumulator *)
    active:     BOOLEAN
  END;

VAR
  dev: DeviceID;
  voices: ARRAY [0..3] OF Voice;
  timeclock: LONGINT;
  tempo: INTEGER;
  nosound: BOOLEAN;
  currentMood: INTEGER;

  (* Raw data buffers *)
  wavMem: ARRAY [0..1023] OF CHAR;   (* waveform data *)
  volMem: ARRAY [0..2559] OF CHAR;   (* volume envelope data *)
  trackData: ARRAY [0..5999] OF CHAR; (* score data *)
  trackOff: ARRAY [0..27] OF INTEGER; (* offset of each track *)
  trackLen: ARRAY [0..27] OF INTEGER; (* length of each track *)
  numTracks: INTEGER;

  (* Instrument map (from new_wave) *)
  insMap: ARRAY [0..11] OF INTEGER;

  (* Output buffer *)
  outBuf: ARRAY [0..1023] OF LONGREAL;

  (* Period table — Amiga periods for each note *)
  ptable: ARRAY [0..95] OF INTEGER;   (* period values *)
  ptableOff: ARRAY [0..95] OF INTEGER; (* waveform offsets *)

  (* Note duration table *)
  notevals: ARRAY [0..63] OF INTEGER;

  inited: BOOLEAN;
  dbgCount: INTEGER;
  tickAccum: INTEGER;  (* sample counter for 50Hz sequencer tick *)

PROCEDURE InitPtable;
VAR i: INTEGER;
BEGIN
  (* From gdriver.c ptable — (period, offset) pairs for each note.
     6 notes per octave grouping, organized by range. *)
  (* Octave -1 *)
  ptable[0]:=1440; ptableOff[0]:=0;
  ptable[1]:=1356; ptableOff[1]:=0;
  ptable[2]:=1280; ptableOff[2]:=0;
  ptable[3]:=1208; ptableOff[3]:=0;
  ptable[4]:=1140; ptableOff[4]:=0;
  ptable[5]:=1076; ptableOff[5]:=0;
  (* Octave 0 *)
  ptable[6]:=1016; ptableOff[6]:=0;
  ptable[7]:=960;  ptableOff[7]:=0;
  ptable[8]:=906;  ptableOff[8]:=0;
  ptable[9]:=856;  ptableOff[9]:=0;
  ptable[10]:=808; ptableOff[10]:=0;
  ptable[11]:=762; ptableOff[11]:=0;
  ptable[12]:=720; ptableOff[12]:=0;
  ptable[13]:=678; ptableOff[13]:=0;
  ptable[14]:=640; ptableOff[14]:=0;
  ptable[15]:=604; ptableOff[15]:=0;
  ptable[16]:=570; ptableOff[16]:=0;
  ptable[17]:=538; ptableOff[17]:=0;
  (* Octave 1 *)
  ptable[18]:=508; ptableOff[18]:=0;
  ptable[19]:=480; ptableOff[19]:=0;
  ptable[20]:=453; ptableOff[20]:=0;
  ptable[21]:=428; ptableOff[21]:=0;
  ptable[22]:=404; ptableOff[22]:=0;
  ptable[23]:=381; ptableOff[23]:=0;
  ptable[24]:=360; ptableOff[24]:=0;
  ptable[25]:=339; ptableOff[25]:=0;
  ptable[26]:=320; ptableOff[26]:=0;
  ptable[27]:=302; ptableOff[27]:=0;
  ptable[28]:=285; ptableOff[28]:=0;
  ptable[29]:=269; ptableOff[29]:=0;
  (* Octave 2 — with waveform offset 16 *)
  ptable[30]:=508; ptableOff[30]:=16;
  ptable[31]:=480; ptableOff[31]:=16;
  ptable[32]:=453; ptableOff[32]:=16;
  ptable[33]:=428; ptableOff[33]:=16;
  ptable[34]:=404; ptableOff[34]:=16;
  ptable[35]:=381; ptableOff[35]:=16;
  ptable[36]:=360; ptableOff[36]:=16;
  ptable[37]:=339; ptableOff[37]:=16;
  ptable[38]:=320; ptableOff[38]:=16;
  ptable[39]:=302; ptableOff[39]:=16;
  ptable[40]:=285; ptableOff[40]:=16;
  ptable[41]:=269; ptableOff[41]:=16;
  (* Octave 3 — offset 24 *)
  ptable[42]:=508; ptableOff[42]:=24;
  ptable[43]:=480; ptableOff[43]:=24;
  ptable[44]:=453; ptableOff[44]:=24;
  ptable[45]:=428; ptableOff[45]:=24;
  ptable[46]:=404; ptableOff[46]:=24;
  ptable[47]:=381; ptableOff[47]:=24;
  ptable[48]:=360; ptableOff[48]:=24;
  ptable[49]:=339; ptableOff[49]:=24;
  ptable[50]:=320; ptableOff[50]:=24;
  ptable[51]:=302; ptableOff[51]:=24;
  ptable[52]:=285; ptableOff[52]:=24;
  ptable[53]:=269; ptableOff[53]:=24;
  (* Octave 4 — offset 28 *)
  ptable[54]:=508; ptableOff[54]:=28;
  ptable[55]:=480; ptableOff[55]:=28;
  ptable[56]:=453; ptableOff[56]:=28;
  ptable[57]:=428; ptableOff[57]:=28;
  ptable[58]:=404; ptableOff[58]:=28;
  ptable[59]:=381; ptableOff[59]:=28;
  ptable[60]:=360; ptableOff[60]:=28;
  ptable[61]:=339; ptableOff[61]:=28;
  ptable[62]:=320; ptableOff[62]:=28;
  ptable[63]:=302; ptableOff[63]:=28;
  ptable[64]:=285; ptableOff[64]:=28;
  ptable[65]:=269; ptableOff[65]:=28;
  (* Octave 5 — offset 28, higher *)
  ptable[66]:=254; ptableOff[66]:=28;
  ptable[67]:=240; ptableOff[67]:=28;
  ptable[68]:=226; ptableOff[68]:=28;
  ptable[69]:=214; ptableOff[69]:=28;
  ptable[70]:=202; ptableOff[70]:=28;
  ptable[71]:=190; ptableOff[71]:=28;
  ptable[72]:=180; ptableOff[72]:=28;
  ptable[73]:=170; ptableOff[73]:=28;
  ptable[74]:=160; ptableOff[74]:=28;
  ptable[75]:=151; ptableOff[75]:=28;
  ptable[76]:=143; ptableOff[76]:=28;
  ptable[77]:=135; ptableOff[77]:=28;
  FOR i := 78 TO 95 DO
    ptable[i] := 269; ptableOff[i] := 0
  END
END InitPtable;

PROCEDURE InitNotevals;
BEGIN
  notevals[0]:=26880; notevals[1]:=13440; notevals[2]:=6720;
  notevals[3]:=3360; notevals[4]:=1680; notevals[5]:=840;
  notevals[6]:=420; notevals[7]:=210;
  notevals[8]:=40320; notevals[9]:=20160; notevals[10]:=10080;
  notevals[11]:=5040; notevals[12]:=2520; notevals[13]:=1260;
  notevals[14]:=630; notevals[15]:=315;
  notevals[16]:=17920; notevals[17]:=8960; notevals[18]:=4480;
  notevals[19]:=2240; notevals[20]:=1120; notevals[21]:=560;
  notevals[22]:=280; notevals[23]:=140;
  notevals[24]:=26880; notevals[25]:=13440; notevals[26]:=6720;
  notevals[27]:=3360; notevals[28]:=1680; notevals[29]:=840;
  notevals[30]:=420; notevals[31]:=210;
  notevals[32]:=21504; notevals[33]:=10752; notevals[34]:=5376;
  notevals[35]:=2688; notevals[36]:=1344; notevals[37]:=672;
  notevals[38]:=336; notevals[39]:=168;
  notevals[40]:=32256; notevals[41]:=16128; notevals[42]:=8064;
  notevals[43]:=4032; notevals[44]:=2016; notevals[45]:=1008;
  notevals[46]:=504; notevals[47]:=252;
  notevals[48]:=23040; notevals[49]:=11520; notevals[50]:=5760;
  notevals[51]:=2880; notevals[52]:=1440; notevals[53]:=720;
  notevals[54]:=360; notevals[55]:=180;
  notevals[56]:=34560; notevals[57]:=17280; notevals[58]:=8640;
  notevals[59]:=4320; notevals[60]:=2160; notevals[61]:=1080;
  notevals[62]:=540; notevals[63]:=270
END InitNotevals;

PROCEDURE InitInsMap;
BEGIN
  insMap[0]:=0; insMap[1]:=0; insMap[2]:=0; insMap[3]:=0;
  insMap[4]:=5; insMap[5]:=514; insMap[6]:=257; insMap[7]:=259;
  insMap[8]:=4; insMap[9]:=1284; insMap[10]:=256; insMap[11]:=1280
END InitInsMap;

PROCEDURE LoadData(): BOOLEAN;
VAR fd: ADDRESS;
    n, i, off, packLen: INTEGER;
    buf4: ARRAY [0..3] OF CHAR;
    p: ARRAY [0..127] OF CHAR;
BEGIN
  (* Load waveforms *)
  AssetPath("wavmem.bin", p);
  OpenRead(p, fd);
  IF fd = NIL THEN
    WriteString("Music: wavmem.bin not found"); WriteLn;
    RETURN FALSE
  END;
  ReadBytes(fd, ADR(wavMem), WavBufSize, n);
  Close(fd);
  WriteString("Music: wav read "); WriteInt(n, 5);
  WriteString(" bytes, wav[1]="); WriteInt(ORD(wavMem[1]), 4); WriteLn;
  IF n < WavBufSize THEN
    WriteString("Music: wav read failed!"); WriteLn;
    RETURN FALSE
  END;

  (* Load volume envelopes *)
  AssetPath("volmem.bin", p);
  OpenRead(p, fd);
  IF fd = NIL THEN
    WriteString("Music: volmem.bin not found"); WriteLn;
    RETURN FALSE
  END;
  ReadBytes(fd, ADR(volMem), VolBufSize, n);
  Close(fd);
  IF n < VolBufSize THEN
    WriteString("Music: vol read failed!"); WriteLn;
    RETURN FALSE
  END;

  (* Load songs/tracks *)
  AssetPath("songs.bin", p);
  OpenRead(p, fd);
  IF fd = NIL THEN
    WriteString("Music: songs.bin not found"); WriteLn;
    RETURN FALSE
  END;
  off := 0;
  numTracks := 0;
  FOR i := 0 TO MaxTracks - 1 DO
    ReadBytes(fd, ADR(buf4), 4, n);
    IF n < 4 THEN
      i := MaxTracks
    ELSE
      packLen := ORD(buf4[0]) * 16777216 + ORD(buf4[1]) * 65536 +
                 ORD(buf4[2]) * 256 + ORD(buf4[3]);
      trackOff[numTracks] := off;
      trackLen[numTracks] := packLen * 2;
      IF off + packLen * 2 > 5999 THEN
        i := MaxTracks
      ELSE
        ReadBytes(fd, ADR(trackData[off]), packLen * 2, n);
        INC(off, packLen * 2);
        INC(numTracks)
      END
    END
  END;
  Close(fd);

  WriteString("Music: "); WriteInt(numTracks, 1);
  WriteString(" tracks loaded"); WriteLn;
  RETURN numTracks > 0
END LoadData;

PROCEDURE InitVoice(VAR v: Voice);
BEGIN
  v.waveNum := 0; v.volNum := 0;
  v.volDelay := -1; v.vceStat := 0;
  v.eventStart := 0; v.eventStop := 0;
  v.volPos := 0; v.volume := 0;
  v.trakPtr := -1; v.trakBeg := -1;
  v.period := 428; v.waveOff := 0; v.waveLen := 32;
  v.phase := 0.0; v.active := FALSE
END InitVoice;

PROCEDURE InitMusic(): BOOLEAN;
VAR i: INTEGER;
BEGIN
  inited := FALSE;
  nosound := TRUE;
  dbgCount := 0;
  tickAccum := 0;
  lpState := 0.0;
  currentMood := -1;
  timeclock := 0;
  tempo := 150;

  FOR i := 0 TO 3 DO InitVoice(voices[i]) END;
  InitPtable;
  InitNotevals;
  InitInsMap;

  IF NOT LoadData() THEN RETURN FALSE END;

  IF NOT InitAudio() THEN
    WriteString("Music: SDL audio init failed"); WriteLn;
    RETURN FALSE
  END;

  dev := OpenDevice(OutputRate, 1, FormatS16, 2048);
  IF dev = 0 THEN
    WriteString("Music: audio device open failed"); WriteLn;
    QuitAudio;
    RETURN FALSE
  END;

  ResumeDevice(dev);
  inited := TRUE;
  WriteString("Music: initialized"); WriteLn;
  RETURN TRUE
END InitMusic;

PROCEDURE ShutdownMusic;
BEGIN
  IF inited THEN
    CloseDevice(dev);
    QuitAudio;
    inited := FALSE
  END
END ShutdownMusic;

PROCEDURE StopMusic;
VAR i: INTEGER;
BEGIN
  nosound := TRUE;
  FOR i := 0 TO 3 DO
    voices[i].active := FALSE;
    voices[i].volume := 0
  END;
  ClearQueued(dev)
END StopMusic;

PROCEDURE IsPlaying(): BOOLEAN;
VAR i: INTEGER;
BEGIN
  FOR i := 0 TO 3 DO
    IF voices[i].active THEN RETURN TRUE END
  END;
  RETURN FALSE
END IsPlaying;

PROCEDURE SetMood(mood: INTEGER);
VAR i, tIdx: INTEGER;
BEGIN
  IF NOT inited THEN RETURN END;
  IF mood = currentMood THEN RETURN END;
  currentMood := mood;

  (* Set 4 voices to tracks mood+0..mood+3 *)
  timeclock := 0;
  tickAccum := 0;
  FOR i := 0 TO 3 DO
    tIdx := mood + i;
    IF (tIdx >= 0) AND (tIdx < numTracks) THEN
      voices[i].trakBeg := trackOff[tIdx];
      voices[i].trakPtr := trackOff[tIdx];
      voices[i].eventStart := 0;
      voices[i].eventStop := 0;
      voices[i].volDelay := -1;
      voices[i].vceStat := 0;
      voices[i].volume := 0;
      voices[i].phase := 0.0;
      voices[i].active := TRUE;
      (* Init voice waveform from instrument map.
         new_wave[i] is big-endian: high byte = waveNum, low byte = volNum *)
      voices[i].waveNum := insMap[i] DIV 256;
      voices[i].volNum := insMap[i] MOD 256
    ELSE
      voices[i].active := FALSE
    END
  END;
  nosound := FALSE;
  tempo := 150
END SetMood;

PROCEDURE ProcessVoice(VAR v: Voice);
VAR cmd, val, noteIdx, durIdx: INTEGER;
    dur, gap: LONGINT;
BEGIN
  IF NOT v.active THEN RETURN END;
  IF v.trakPtr < 0 THEN RETURN END;

  (* Check if time for new event *)
  IF timeclock < v.eventStart THEN
    (* Between events — handle volume envelope *)
    IF timeclock >= v.eventStop THEN
      v.volume := 0  (* note ended, silence *)
    ELSIF v.volDelay >= 0 THEN
      (* Step volume envelope *)
      IF v.volPos < EnvLen THEN
        val := ORD(volMem[v.volNum * EnvLen + v.volPos]);
        IF val < 128 THEN
          IF val > 64 THEN val := 64 END;  (* clamp to Amiga range *)
          v.volume := val;
          INC(v.volPos)
        END
      END
    END;
    RETURN
  END;

  (* Process commands until we get a note or run out *)
  LOOP
    IF (v.trakPtr < 0) OR (v.trakPtr + 1 >= 6000) THEN
      v.active := FALSE;
      RETURN
    END;

    cmd := ORD(trackData[v.trakPtr]);
    val := ORD(trackData[v.trakPtr + 1]);
    INC(v.trakPtr, 2);

    IF cmd = 255 THEN
      (* End track *)
      IF val # 0 THEN
        v.trakPtr := v.trakBeg  (* loop *)
      ELSE
        v.active := FALSE;
        RETURN
      END
    ELSIF cmd = 129 THEN
      (* Set instrument — val & 0x0F indexes into insMap.
         Big-endian word: high byte = waveNum, low byte = volNum *)
      val := BAND(CARDINAL(val), 0FH);
      IF val < 12 THEN
        v.waveNum := insMap[val] DIV 256;
        v.volNum := insMap[val] MOD 256
      END
    ELSIF cmd = 144 THEN
      (* Set tempo *)
      tempo := BAND(CARDINAL(val), 0FFH)
    ELSE
      (* Note or rest *)
      noteIdx := BAND(CARDINAL(cmd), 7FH);
      durIdx := BAND(CARDINAL(val), 3FH);

      IF durIdx > 63 THEN durIdx := 63 END;
      dur := LONGINT(notevals[durIdx]);
      gap := dur - 300;
      IF gap < 0 THEN gap := dur END;

      v.eventStop := v.eventStart + gap;
      v.eventStart := v.eventStart + dur;

      IF cmd >= 128 THEN
        (* Rest *)
        v.volume := 0
      ELSE
        (* Note *)
        IF noteIdx < 78 THEN
          v.period := ptable[noteIdx];
          v.waveOff := ptableOff[noteIdx] * 4;
          v.waveLen := 32 - ptableOff[noteIdx]
        END;
        (* Start volume envelope *)
        v.volPos := 0;
        v.volDelay := 0;
        IF v.volNum * EnvLen < VolBufSize THEN
          v.volume := ORD(volMem[v.volNum * EnvLen]);
          INC(v.volPos)
        ELSE
          v.volume := 64
        END
      END;
      RETURN  (* one note per tick *)
    END
  END
END ProcessVoice;

VAR
  lpState: LONGREAL;  (* low-pass filter state *)

PROCEDURE GetWavSample(idx: INTEGER): LONGREAL;
VAR v: INTEGER;
BEGIN
  IF (idx < 0) OR (idx >= WavBufSize) THEN RETURN 0.0 END;
  v := ORD(wavMem[idx]);
  IF v >= 128 THEN DEC(v, 256) END;
  RETURN FLOAT(v) / 128.0
END GetWavSample;

(* Render one output sample by mixing all 4 voices *)
PROCEDURE RenderSample(): LONGREAL;
VAR i, waveBase, waveBytes, idx0, idx1: INTEGER;
    freq, phaseInc, mix, frac, s0, s1, voiceSample: LONGREAL;
BEGIN
  mix := 0.0;
  FOR i := 0 TO 3 DO
    IF voices[i].active AND (voices[i].volume > 0) AND
       (voices[i].period > 0) THEN
      waveBase := voices[i].waveNum * WaveLen + voices[i].waveOff;
      waveBytes := voices[i].waveLen * 2;
      IF waveBytes <= 0 THEN waveBytes := 64 END;

      freq := FLOAT(AmigaClock) / FLOAT(voices[i].period);
      phaseInc := freq / FLOAT(OutputRate);

      (* Linear interpolation between adjacent waveform samples *)
      idx0 := TRUNC(voices[i].phase) MOD waveBytes;
      IF idx0 < 0 THEN idx0 := 0 END;
      idx1 := (idx0 + 1) MOD waveBytes;
      frac := voices[i].phase - FLOAT(TRUNC(voices[i].phase));

      s0 := GetWavSample(waveBase + idx0);
      s1 := GetWavSample(waveBase + idx1);
      voiceSample := s0 + (s1 - s0) * frac;

      mix := mix + voiceSample * FLOAT(voices[i].volume) / 256.0;

      voices[i].phase := voices[i].phase + phaseInc;
      WHILE voices[i].phase >= FLOAT(waveBytes) DO
        voices[i].phase := voices[i].phase - FLOAT(waveBytes)
      END
    END
  END;

  (* Simple one-pole low-pass filter to emulate Amiga's analog output.
     Cutoff ~4kHz at 44100Hz: alpha ~= 0.5 *)
  lpState := lpState * 0.6 + mix * 0.4;

  IF lpState > 1.0 THEN RETURN 1.0
  ELSIF lpState < -1.0 THEN RETURN -1.0
  END;
  RETURN lpState
END RenderSample;

(* Advance the sequencer by one 50 Hz tick *)
PROCEDURE SequencerTick;
VAR i: INTEGER;
BEGIN
  (* 2x multiplier needed — empirically matches original playback speed.
     Our sequencer ticks at 50Hz but original timing requires this. *)
  INC(timeclock, LONGINT(tempo) * 2);
  FOR i := 0 TO 3 DO
    ProcessVoice(voices[i])
  END
END SequencerTick;

PROCEDURE UpdateMusic;
CONST
  MaxSamplesPerCall = 2205;  (* ~50ms per call at 44100Hz *)
  QueueTarget = 4410;        (* keep ~100ms buffered *)
VAR s, toGenerate, sampleCount: INTEGER;
    queued: CARDINAL;
    ok: BOOLEAN;
BEGIN
  IF NOT inited THEN RETURN END;
  IF nosound THEN RETURN END;

  (* Determine how many samples to generate this call.
     Fill up to QueueTarget bytes ahead (1 sample = 2 bytes S16). *)
  queued := GetQueuedBytes(dev);
  IF queued >= CARDINAL(QueueTarget * 2) THEN RETURN END;
  toGenerate := QueueTarget - INTEGER(queued) DIV 2;
  IF toGenerate > MaxSamplesPerCall THEN toGenerate := MaxSamplesPerCall END;
  IF toGenerate <= 0 THEN RETURN END;

  (* Generate audio in chunks of SamplesPerTick (441).
     The sequencer ticks once per chunk boundary — exactly 50 Hz. *)
  sampleCount := 0;
  WHILE sampleCount < toGenerate DO
    (* If we've reached a tick boundary, advance the sequencer *)
    IF tickAccum >= SamplesPerTick THEN
      DEC(tickAccum, SamplesPerTick);
      SequencerTick
    END;

    (* Render one sample *)
    outBuf[sampleCount] := RenderSample();
    INC(sampleCount);
    INC(tickAccum);

    (* Safety: don't overflow outBuf *)
    IF sampleCount >= 1024 THEN
      ok := QueueSamples(dev, ADR(outBuf), sampleCount, 1);
      sampleCount := 0
    END
  END;

  (* Queue remaining samples *)
  IF sampleCount > 0 THEN
    ok := QueueSamples(dev, ADR(outBuf), sampleCount, 1)
  END
END UpdateMusic;

END Music.

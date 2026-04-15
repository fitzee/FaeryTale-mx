IMPLEMENTATION MODULE SFX;

(* Sound effects using a second SDL audio device for one-shot playback.
   Loads 6 WAV samples, plays them by queuing to the SFX device. *)

FROM SYSTEM IMPORT ADDRESS, ADR;
FROM Playback IMPORT DeviceID, OpenDevice, CloseDevice,
                     ResumeDevice, QueueBytes, ClearQueued,
                     FormatS16;
FROM Assets IMPORT AssetPath;
FROM InOut IMPORT WriteString, WriteInt, WriteLn;
FROM BinaryIO IMPORT OpenRead, Close, ReadBytes, Done;
FROM Storage IMPORT ALLOCATE, DEALLOCATE;

CONST
  NumSamples = 6;
  SampleRate = 22050;
  MaxSampleBytes = 4096;

VAR
  sfxDev: DeviceID;
  samples: ARRAY [0..5] OF ADDRESS;
  sampleLen: ARRAY [0..5] OF INTEGER;
  loaded: BOOLEAN;

PROCEDURE LoadSample(idx: INTEGER; name: ARRAY OF CHAR): BOOLEAN;
VAR p: ARRAY [0..127] OF CHAR;
    fd: CARDINAL;
    buf: ADDRESS;
    n: CARDINAL;
BEGIN
  AssetPath(name, p);
  (* For now, load raw PCM from WAV files.
     WAV header is 44 bytes, skip it to get raw S16 data. *)
  OpenRead(p, fd);
  IF NOT Done THEN
    WriteString("SFX: cannot open "); WriteString(name); WriteLn;
    RETURN FALSE
  END;
  ALLOCATE(buf, MaxSampleBytes);
  ReadBytes(fd, buf, MaxSampleBytes, n);
  Close(fd);
  IF n <= 44 THEN
    DEALLOCATE(buf, MaxSampleBytes);
    RETURN FALSE
  END;
  (* Skip 44-byte WAV header — store pointer to PCM data *)
  samples[idx] := buf;
  sampleLen[idx] := INTEGER(n);
  RETURN TRUE
END LoadSample;

PROCEDURE InitSFX(): BOOLEAN;
VAR i: INTEGER;
BEGIN
  loaded := FALSE;
  FOR i := 0 TO NumSamples - 1 DO
    samples[i] := NIL;
    sampleLen[i] := 0
  END;

  sfxDev := OpenDevice(SampleRate, 1, FormatS16, 512);
  IF sfxDev = 0 THEN
    WriteString("SFX: cannot open audio device"); WriteLn;
    RETURN FALSE
  END;
  ResumeDevice(sfxDev);

  LoadSample(0, "fta_sample_0.wav");
  LoadSample(1, "fta_sample_1.wav");
  LoadSample(2, "fta_sample_2.wav");
  LoadSample(3, "fta_sample_3.wav");
  LoadSample(4, "fta_sample_4.wav");
  LoadSample(5, "fta_sample_5.wav");

  loaded := TRUE;
  WriteString("SFX: loaded "); WriteInt(NumSamples, 1);
  WriteString(" samples"); WriteLn;
  RETURN TRUE
END InitSFX;

PROCEDURE PlayEffect(num: INTEGER);
VAR ok: BOOLEAN;
BEGIN
  IF NOT loaded THEN RETURN END;
  IF (num < 0) OR (num >= NumSamples) THEN RETURN END;
  IF samples[num] = NIL THEN RETURN END;
  IF sampleLen[num] <= 44 THEN RETURN END;
  (* Clear any currently playing effect, queue the new one.
     Skip 44-byte WAV header. *)
  ClearQueued(sfxDev);
  ok := QueueBytes(sfxDev, samples[num], CARDINAL(sampleLen[num]))
END PlayEffect;

PROCEDURE ShutdownSFX;
VAR i: INTEGER;
BEGIN
  IF sfxDev # 0 THEN
    CloseDevice(sfxDev);
    sfxDev := 0
  END;
  FOR i := 0 TO NumSamples - 1 DO
    IF samples[i] # NIL THEN
      DEALLOCATE(samples[i], MaxSampleBytes);
      samples[i] := NIL
    END
  END;
  loaded := FALSE
END ShutdownSFX;

END SFX.

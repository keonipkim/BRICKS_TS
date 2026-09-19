/* DODFR -- DODFMR Statement of Service / PEBD (PAT parity)            */
/* Engine port of personnel-admin-tools/public/dodfmr/dodfmr_core.js   */
/* DoD FMR Vol 7A Ch 1: 30/360, inclusive +1, DEP §2.1.4.12,          */
/* lost time §2.4.1.3.1 / officer §2.2.2 / PEBD retard §2.4.1.4.      */

ADDRESS CICS

EXEC CICS ASSIGN DATE(TODAY) END-EXEC
IF DATATYPE(TODAY,'W') \= 1 | LENGTH(STRIP(TODAY)) \= 8 THEN TODAY = '20260101'

MAP.GRADE = 'E'
EXEC CICS SEND MAP('DODF1') ERASE END-EXEC

DO FOREVER
  EXEC CICS RECEIVE MAP('DODF1') END-EXEC
  IF EIBRESP \= 0 THEN DO
    EXEC CICS SEND TEXT FROM('RECEIVE failed') ERASE END-EXEC
    EXEC CICS RETURN TRANSID('MYMU') END-EXEC
  END

  AID = C2X(EIBAID)
  IF AID = 'F3' THEN EXEC CICS RETURN TRANSID('MYMU') END-EXEC

  EDIPI   = STRIP(MAP.EDIPI)
  NAME    = STRIP(MAP.NAME)
  ASOF    = STRIP(MAP.ASOF)
  RECPEBD = STRIP(MAP.RECPEBD)
  GRADE   = TRANSLATE(STRIP(MAP.GRADE))
  IF GRADE = '' THEN GRADE = 'E'

  CALL NormDate ASOF
  ASOF = NORMDATE
  IF ASOF = '' THEN ASOF = TODAY
  CALL NormDate RECPEBD
  RECPEBD = NORMDATE

  OFFICER = 0
  IF GRADE = 'O' | GRADE = 'W' THEN OFFICER = 1

  IF AID = 'F9' THEN DO
    CALL ClearEntryMap
    MAP.GRADE = 'E'
    EXEC CICS SEND MAP('DODF1') ERASE END-EXEC
    ITERATE
  END

  CALL LoadPeriodsFromDODF1
  CALL ClassifyPeriods

  IF AID = 'F4' THEN DO
    CALL SendReviewMap
    CALL ReviewAndDeleteLoop
    IF ReviewAction = 'BACK' THEN ITERATE
    IF ReviewAction \= 'CALC' THEN ITERATE
    CALL ClassifyPeriods
  END

  LEAVE
END

/* ---- PAT calculateServiceData ------------------------------------- */
LOSTTOTAL = 0
LOSTN = 0
DEPNOTES = ''
GROSSDAYS = 0
MERGED.0 = 0
NETDAYS = 0
CALCPEBD = ASOF
PEBDBASE = ASOF
STATUS = 'Calculated only (no Record PEBD entered)'
DIFF = ''

NIN = 0
DO i = 1 TO PERIODS.0
  IF PERIODS.i.CR = 'Y' | PERIODS.i.ISLOST = 1 THEN DO
    IF PERIODS.i.FROM \= '' THEN DO
      NIN = NIN + 1
      MERGEIN.NIN.FROM = PERIODS.i.FROM
      MERGEIN.NIN.TO   = PERIODS.i.TO
    END
  END
  IF PERIODS.i.ISLOST = 1 THEN DO
    LOSTN = LOSTN + 1
    LOSTA.LOSTN.FROM = PERIODS.i.FROM
    LOSTA.LOSTN.TO   = PERIODS.i.TO
    LOSTA.LOSTN.RS   = PERIODS.i.RS
    LOSTA.LOSTN.MTFS = PERIODS.i.LT
    IF OFFICER = 1 THEN DO
      LOSTA.LOSTN.DAYS = 0
      LOSTA.LOSTN.METH = 'Officer Exception'
      LOSTA.LOSTN.NOTE = 'Per 2.2.2 lost time does not affect officer PEBD'
    END
    ELSE IF PERIODS.i.FROM \= '' & PERIODS.i.TO \= '' THEN DO
      CALL ComputeLostDaysCh1 PERIODS.i.FROM, PERIODS.i.TO
      LOSTA.LOSTN.DAYS = CH1DAYS
      LOSTA.LOSTN.METH = 'Not Made Good (Deducted)'
      LOSTA.LOSTN.NOTE = 'Per 2.4.1.3.1 30-day month, start-on-31st counts'
    END
    ELSE DO
      LOSTA.LOSTN.DAYS = PERIODS.i.LT
      LOSTA.LOSTN.METH = 'MCTFS Value'
      LOSTA.LOSTN.NOTE = 'Using LOST field (no from/to on row)'
    END
    LOSTTOTAL = LOSTTOTAL + LOSTA.LOSTN.DAYS
  END
  IF PERIODS.i.DEPNOTE \= '' THEN DO
    IF DEPNOTES = '' THEN DEPNOTES = PERIODS.i.DEPNOTE
    ELSE DEPNOTES = DEPNOTES || ' | ' || PERIODS.i.DEPNOTE
  END
END

IF NIN > 0 THEN DO
  DO i = 1 TO NIN-1
    DO j = i+1 TO NIN
      IF MERGEIN.i.FROM > MERGEIN.j.FROM THEN DO
        t = MERGEIN.i.FROM; MERGEIN.i.FROM = MERGEIN.j.FROM; MERGEIN.j.FROM = t
        t = MERGEIN.i.TO;   MERGEIN.i.TO   = MERGEIN.j.TO;   MERGEIN.j.TO   = t
      END
    END
  END

  MERGED.0 = 1
  MERGED.1.FROM = MERGEIN.1.FROM
  MERGED.1.TO   = MERGEIN.1.TO
  DO i = 2 TO NIN
    last = MERGED.0
    CALL AddCalDays MERGED.last.TO, 1
    IF MERGEIN.i.FROM <= OUTDATE THEN DO
      IF MERGEIN.i.TO > MERGED.last.TO THEN MERGED.last.TO = MERGEIN.i.TO
    END
    ELSE DO
      MERGED.0 = MERGED.0 + 1
      n = MERGED.0
      MERGED.n.FROM = MERGEIN.i.FROM
      MERGED.n.TO   = MERGEIN.i.TO
    END
  END

  DO i = 1 TO MERGED.0
    CALL ComputeSegmentDays30 MERGED.i.FROM, MERGED.i.TO
    MERGED.i.BASE = SEGDAYS
    MERGED.i.DAYS = SEGDAYS + 1
    GROSSDAYS = GROSSDAYS + MERGED.i.DAYS
  END
END

NETDAYS = GROSSDAYS - LOSTTOTAL
IF NETDAYS < 0 THEN NETDAYS = 0
YRS = NETDAYS % 360
REM = NETDAYS // 360
MOS = REM % 30
DYS = REM // 30
BREAKDOWN = YRS || ' years, ' || MOS || ' months, ' || DYS || ' days'

IF MERGED.0 = 1 THEN PEBDBASE = MERGED.1.FROM
ELSE IF GROSSDAYS <= 0 THEN PEBDBASE = ASOF
ELSE DO
  TARGET = GROSSDAYS - 1
  IF TARGET < 0 THEN TARGET = 0
  GY = TARGET % 360
  GR = TARGET // 360
  GM = GR % 30
  GD = GR // 30
  CALL CalcPebdGuess ASOF, GY, GM, GD
  BEST = PEBDGUESS
  CALL ComputeSegmentDays30 BEST, ASOF
  BESTERR = ABS(SEGDAYS - TARGET)
  DO delta = -20 TO 20
    IF delta = 0 THEN ITERATE
    CALL AddCalDays PEBDGUESS, delta
    CAND = OUTDATE
    CALL ComputeSegmentDays30 CAND, ASOF
    ERR = ABS(SEGDAYS - TARGET)
    IF ERR < BESTERR | (ERR = BESTERR & SEGDAYS = TARGET) THEN DO
      BEST = CAND
      BESTERR = ERR
      IF SEGDAYS = TARGET THEN LEAVE
    END
  END
  CALL ComputeSegmentDays30 BEST, ASOF
  ERR = SEGDAYS - TARGET
  IF ERR \= 0 THEN DO
    CALL AddCalDays BEST, 0 - ERR
    CAND = OUTDATE
    CALL ComputeSegmentDays30 CAND, ASOF
    IF ABS(SEGDAYS - TARGET) <= BESTERR THEN BEST = CAND
  END
  PEBDBASE = BEST
END

CALCPEBD = PEBDBASE
IF LOSTTOTAL > 0 & OFFICER = 0 THEN DO
  LY = LOSTTOTAL % 360
  LR = LOSTTOTAL // 360
  LM = LR % 30
  LD = LR // 30
  CALL AddYmd30 PEBDBASE, LY, LM, LD
  CALCPEBD = OUTDATE
END

IF RECPEBD \= '' THEN DO
  CALL ToJdn CALCPEBD
  J1 = JDN
  CALL ToJdn RECPEBD
  DIFFDAYS = J1 - JDN
  IF DIFFDAYS = 0 THEN DO
    STATUS = 'MATCH'
    IF LOSTTOTAL > 0 THEN STATUS = 'MATCH (lost time already on PEBD per 2.4.1.4)'
    DIFF = '0 days'
  END
  ELSE DO
    AD = ABS(DIFFDAYS)
    IF AD = 1 THEN STATUS = 'CLOSE MATCH'
    ELSE IF AD <= 3 THEN STATUS = 'MINOR DIFF'
    ELSE IF AD <= 7 THEN STATUS = 'MODERATE DIFF'
    ELSE STATUS = 'SIGNIFICANT DIFF'
    IF DIFFDAYS > 0 THEN DIFF = '+'||DIFFDAYS||' days'
    ELSE DIFF = DIFFDAYS||' days'
  END
END

/* ---- report ------------------------------------------------------- */
IF OFFICER = 1 THEN CLASSSTR = 'OFFICER (O/W)'
ELSE CLASSSTR = 'ENLISTED'

TXT = LEFT('=== DODFMR STATEMENT OF SERVICE (PAT / Ch 1) ===', 80)
TXT = TXT || LEFT('', 80)
TXT = TXT || LEFT('EDIPI : ' || EDIPI, 80)
TXT = TXT || LEFT('NAME  : ' || NAME, 80)
TXT = TXT || LEFT('Grade : ' || GRADE || '   ' || CLASSSTR, 80)
TXT = TXT || LEFT('As of Date            : ' || ASOF, 80)
TXT = TXT || LEFT('Gross creditable days : ' || GROSSDAYS, 80)
TXT = TXT || LEFT('Lost time deducted    : ' || LOSTTOTAL, 80)
TXT = TXT || LEFT('Net creditable days   : ' || NETDAYS || '  (' || BREAKDOWN || ')', 80)
TXT = TXT || LEFT('', 80)
TXT = TXT || LEFT('--- PEBD COMPARISON ---', 80)
TXT = TXT || LEFT('PEBD before lost add  : ' || PEBDBASE, 80)
TXT = TXT || LEFT('Calculated PEBD       : ' || CALCPEBD, 80)
TXT = TXT || LEFT('Record PEBD           : ' || RECPEBD, 80)
TXT = TXT || LEFT('Difference            : ' || DIFF, 80)
TXT = TXT || LEFT('Status                : ' || STATUS, 80)
TXT = TXT || LEFT(COPIES('-', 70), 80)

IF PERIODS.0 > 0 THEN DO
  TXT = TXT || LEFT('Service periods (CR=Y counts for PEBD):', 80)
  DO i = 1 TO PERIODS.0
    LINE = RIGHT(i,2)||'. '||PERIODS.i.FROM||' -> '||PERIODS.i.TO||'  '||,
           LEFT(PERIODS.i.BR,4)||' '||LEFT(PERIODS.i.CP,5)||' '||,
           LEFT(PERIODS.i.RS,6)||' LT='||PERIODS.i.LT||' CR='||PERIODS.i.CR
    TXT = TXT || LEFT(LINE, 80)
    IF PERIODS.i.DEPNOTE \= '' THEN TXT = TXT || LEFT('    '||PERIODS.i.DEPNOTE, 80)
  END
END

IF MERGED.0 > 0 THEN DO
  TXT = TXT || LEFT('', 80)
  TXT = TXT || LEFT('Merged timeline (creditable + dated lost holes):', 80)
  DO i = 1 TO MERGED.0
    TXT = TXT || LEFT(RIGHT(i,2)||'. '||MERGED.i.FROM||' -> '||MERGED.i.TO||,
           '  days='||MERGED.i.DAYS, 80)
  END
END

IF LOSTN > 0 THEN DO
  TXT = TXT || LEFT('', 80)
  TXT = TXT || LEFT('Lost time analysis:', 80)
  DO i = 1 TO LOSTN
    TXT = TXT || LEFT(RIGHT(i,2)||'. '||LOSTA.i.FROM||' -> '||LOSTA.i.TO||,
           '  '||LOSTA.i.RS||'  deduct='||LOSTA.i.DAYS||'  '||LOSTA.i.METH, 80)
    TXT = TXT || LEFT('    '||LOSTA.i.NOTE, 80)
  END
END

IF DEPNOTES \= '' THEN DO
  TXT = TXT || LEFT('', 80)
  TXT = TXT || LEFT('DEP notes: '||DEPNOTES, 80)
END

TXT = TXT || LEFT('', 80)
TXT = TXT || LEFT('Press ENTER or PF3 to return to the menu.', 80)

EXEC CICS SEND TEXT FROM(TXT) ERASE END-EXEC
EXEC CICS RETURN TRANSID('MYMU') END-EXEC


/* ================================================================== */
/* Helpers — CALL only (PROCEDURE labels). Result vars via EXPOSE.    */
/* ================================================================== */

NormDate: PROCEDURE EXPOSE NORMDATE
  PARSE ARG raw
  s = STRIP(raw)
  NORMDATE = ''
  IF s = '' | s = '00000000' THEN RETURN
  IF DATATYPE(s,'W') = 1 & LENGTH(s) = 8 THEN DO
    NORMDATE = s
    RETURN
  END
  IF LENGTH(s) = 10 & SUBSTR(s,5,1) = '-' & SUBSTR(s,8,1) = '-' THEN DO
    NORMDATE = SUBSTR(s,1,4)||SUBSTR(s,6,2)||SUBSTR(s,9,2)
    RETURN
  END
RETURN

DaysInMonth: PROCEDURE EXPOSE DIM
  PARSE ARG y, m
  DIM = 31
  IF m = 4 | m = 6 | m = 9 | m = 11 THEN DIM = 30
  IF m = 2 THEN DO
    DIM = 28
    IF y // 400 = 0 THEN DIM = 29
    ELSE IF y // 100 = 0 THEN DIM = 28
    ELSE IF y // 4 = 0 THEN DIM = 29
  END
RETURN

AddCalDays: PROCEDURE EXPOSE OUTDATE DIM
  PARSE ARG ymd, delta
  OUTDATE = ymd
  IF ymd = '' THEN RETURN
  y = SUBSTR(ymd,1,4)+0
  m = SUBSTR(ymd,5,2)+0
  d = SUBSTR(ymd,7,2)+0
  d = d + delta
  DO WHILE d > 0
    CALL DaysInMonth y, m
    IF d <= DIM THEN LEAVE
    d = d - DIM
    m = m + 1
    IF m > 12 THEN DO
      m = 1
      y = y + 1
    END
  END
  DO WHILE d < 1
    m = m - 1
    IF m < 1 THEN DO
      m = 12
      y = y - 1
    END
    CALL DaysInMonth y, m
    d = d + DIM
  END
  OUTDATE = RIGHT(y,4,'0')||RIGHT(m,2,'0')||RIGHT(d,2,'0')
RETURN

AdjustDay: PROCEDURE EXPOSE ADJ
  PARSE ARG day, month, year
  ADJ = day
  IF day = 31 THEN ADJ = 30
  IF month = 2 & (day = 28 | day = 29) THEN ADJ = 30
RETURN

ComputeSegmentDays30: PROCEDURE EXPOSE SEGDAYS ADJ
  PARSE ARG start, end
  SEGDAYS = 0
  IF start = '' | end = '' | start > end THEN RETURN
  ys = SUBSTR(start,1,4)+0; ms = SUBSTR(start,5,2)+0; ds = SUBSTR(start,7,2)+0
  ye = SUBSTR(end,1,4)+0;   me = SUBSTR(end,5,2)+0;   de = SUBSTR(end,7,2)+0
  CALL AdjustDay ds, ms, ys; ds = ADJ
  CALL AdjustDay de, me, ye; de = ADJ
  days = de - ds
  months = me - ms
  years = ye - ys
  IF days < 0 THEN DO
    days = days + 30
    months = months - 1
  END
  IF months < 0 THEN DO
    months = months + 12
    years = years - 1
  END
  SEGDAYS = years * 360 + months * 30 + days
  IF SEGDAYS < 0 THEN SEGDAYS = 0
RETURN

ComputeLostDaysCh1: PROCEDURE EXPOSE CH1DAYS ADJ SEGDAYS
  PARSE ARG start, end
  CH1DAYS = 0
  IF start = '' | end = '' | start > end THEN RETURN
  extra = 0
  s = start
  IF SUBSTR(s,7,2)+0 = 31 THEN DO
    extra = 1
    IF s = end THEN DO
      CH1DAYS = 1
      RETURN
    END
    y = SUBSTR(s,1,4)+0
    m = SUBSTR(s,5,2)+0 + 1
    IF m > 12 THEN DO
      m = 1
      y = y + 1
    END
    s = RIGHT(y,4,'0')||RIGHT(m,2,'0')||'01'
    IF s > end THEN DO
      CH1DAYS = 1
      RETURN
    END
  END
  ys = SUBSTR(s,1,4)+0; ms = SUBSTR(s,5,2)+0; ds = SUBSTR(s,7,2)+0
  ye = SUBSTR(end,1,4)+0; me = SUBSTR(end,5,2)+0; de = SUBSTR(end,7,2)+0
  CALL AdjustDay ds, ms, ys; ds = ADJ
  CALL AdjustDay de, me, ye; de = ADJ
  days = de - ds + 1
  months = me - ms
  years = ye - ys
  IF days < 0 THEN DO
    days = days + 30
    months = months - 1
  END
  IF months < 0 THEN DO
    months = months + 12
    years = years - 1
  END
  tot = extra + years * 360 + months * 30 + days
  IF tot < 0 THEN tot = 0
  CH1DAYS = tot
RETURN

AddYmd30: PROCEDURE EXPOSE OUTDATE DIM
  PARSE ARG ymd, years, months, days
  OUTDATE = ymd
  IF ymd = '' THEN RETURN
  y = SUBSTR(ymd,1,4)+0
  m = SUBSTR(ymd,5,2)+0
  day = SUBSTR(ymd,7,2)+0
  IF day = 31 THEN day = 30
  m = m + years * 12 + months
  DO WHILE m > 12
    m = m - 12
    y = y + 1
  END
  DO WHILE m < 1
    m = m + 12
    y = y - 1
  END
  day = day + days
  DO WHILE day > 30
    day = day - 30
    m = m + 1
    IF m > 12 THEN DO
      m = 1
      y = y + 1
    END
  END
  DO WHILE day < 1
    day = day + 30
    m = m - 1
    IF m < 1 THEN DO
      m = 12
      y = y - 1
    END
  END
  CALL DaysInMonth y, m
  IF day > DIM THEN day = DIM
  OUTDATE = RIGHT(y,4,'0')||RIGHT(m,2,'0')||RIGHT(day,2,'0')
RETURN

CalcPebdGuess: PROCEDURE EXPOSE PEBDGUESS DIM OUTDATE
  PARSE ARG asof, years, months, days
  y0 = SUBSTR(asof,1,4)+0
  m0 = SUBSTR(asof,5,2)+0
  d0 = SUBSTR(asof,7,2)+0
  m0 = m0 - (years * 12 + months)
  DO WHILE m0 <= 0
    m0 = m0 + 12
    y0 = y0 - 1
  END
  CALL DaysInMonth y0, m0
  day = d0
  IF day > DIM THEN day = DIM
  PEBDGUESS = RIGHT(y0,4,'0')||RIGHT(m0,2,'0')||RIGHT(day,2,'0')
  CALL AddCalDays PEBDGUESS, 0 - days
  PEBDGUESS = OUTDATE
RETURN

ToJdn: PROCEDURE EXPOSE JDN
  PARSE ARG ymd
  JDN = 0
  IF ymd = '' | LENGTH(ymd) \= 8 THEN RETURN
  y = SUBSTR(ymd,1,4)+0
  m = SUBSTR(ymd,5,2)+0
  d = SUBSTR(ymd,7,2)+0
  a = (14 - m) % 12
  yy = y + 4800 - a
  mm = m + 12 * a - 3
  JDN = d + (153 * mm + 2) % 5 + 365 * yy + yy % 4 - yy % 100 + yy % 400 - 32045
RETURN

IsLostReason: PROCEDURE EXPOSE ISLOST
  PARSE ARG r
  r = TRANSLATE(STRIP(r))
  ISLOST = 0
  IF r = 'CNFD' | r = 'EXPECC' | r = 'IHCA' | r = 'IHFA' | r = 'RTFD' | r = 'UA/DES' THEN ISLOST = 1
RETURN

EvalDep: PROCEDURE EXPOSE DEPOK DEPNOTE
  PARSE ARG from
  DEPOK = 0
  DEPNOTE = ''
  IF from = '' THEN DO
    DEPNOTE = 'DEP not creditable (missing from date) 2.1.4.12'
    RETURN
  END
  ymd = from + 0
  IF ymd < 19850101 THEN DO
    DEPOK = 1
    DEPNOTE = 'DEP creditable (enlistment before 1 Jan 1985) 2.1.4.12'
    RETURN
  END
  IF ymd <= 19891128 THEN DO
    DEPNOTE = 'DEP not creditable (1 Jan 1985-28 Nov 1989) 2.1.4.12.1'
    RETURN
  END
  DEPNOTE = 'DEP not creditable (on/after 29 Nov 1989); if RT07 IDT set COMP=RES 2.2.1.8.1'
RETURN

LoadOneRow: PROCEDURE EXPOSE PERIODS. ASOF NORMDATE
  PARSE ARG fromraw, toraw, br, cp, rs, lt
  CALL NormDate fromraw
  f = NORMDATE
  IF f = '' THEN RETURN
  CALL NormDate toraw
  t = NORMDATE
  IF t = '' THEN t = ASOF
  n = PERIODS.0 + 1
  PERIODS.0 = n
  PERIODS.n.FROM = f
  PERIODS.n.TO   = t
  PERIODS.n.BR   = TRANSLATE(STRIP(br))
  PERIODS.n.CP   = TRANSLATE(STRIP(cp))
  PERIODS.n.RS   = TRANSLATE(STRIP(rs))
  IF PERIODS.n.RS = '' THEN PERIODS.n.RS = 'ACT'
  lv = STRIP(lt)
  IF DATATYPE(lv,'N') THEN PERIODS.n.LT = lv + 0
  ELSE PERIODS.n.LT = 0
  PERIODS.n.CR = 'Y'
  PERIODS.n.ISLOST = 0
  PERIODS.n.DEPNOTE = ''
RETURN

LoadPeriodsFromDODF1: PROCEDURE EXPOSE PERIODS. MAP. ASOF NORMDATE
  PERIODS.0 = 0
  CALL LoadOneRow MAP.FROM1, MAP.TO1, MAP.BR1, MAP.CP1, MAP.RS1, MAP.LT1
  CALL LoadOneRow MAP.FROM2, MAP.TO2, MAP.BR2, MAP.CP2, MAP.RS2, MAP.LT2
  CALL LoadOneRow MAP.FROM3, MAP.TO3, MAP.BR3, MAP.CP3, MAP.RS3, MAP.LT3
  CALL LoadOneRow MAP.FROM4, MAP.TO4, MAP.BR4, MAP.CP4, MAP.RS4, MAP.LT4
  CALL LoadOneRow MAP.FROM5, MAP.TO5, MAP.BR5, MAP.CP5, MAP.RS5, MAP.LT5
  CALL LoadOneRow MAP.FROM6, MAP.TO6, MAP.BR6, MAP.CP6, MAP.RS6, MAP.LT6
  CALL LoadOneRow MAP.FROM7, MAP.TO7, MAP.BR7, MAP.CP7, MAP.RS7, MAP.LT7
  CALL LoadOneRow MAP.FROM8, MAP.TO8, MAP.BR8, MAP.CP8, MAP.RS8, MAP.LT8
RETURN

ClassifyPeriods: PROCEDURE EXPOSE PERIODS. ISLOST DEPOK DEPNOTE
  DO i = 1 TO PERIODS.0
    PERIODS.i.CR = 'Y'
    PERIODS.i.ISLOST = 0
    PERIODS.i.DEPNOTE = ''
    CALL IsLostReason PERIODS.i.RS
    IF ISLOST = 1 THEN DO
      PERIODS.i.ISLOST = 1
      PERIODS.i.CR = 'N'
      ITERATE
    END
    IF PERIODS.i.CP = 'DEP' THEN DO
      CALL EvalDep PERIODS.i.FROM
      PERIODS.i.DEPNOTE = DEPNOTE
      IF DEPOK = 1 THEN PERIODS.i.CR = 'Y'
      ELSE PERIODS.i.CR = 'N'
    END
  END
RETURN

SendReviewMap: PROCEDURE EXPOSE PERIODS. MAP.
  MAP.LINE01 = ''; MAP.LINE02 = ''; MAP.LINE03 = ''; MAP.LINE04 = ''; MAP.LINE05 = ''
  MAP.LINE06 = ''; MAP.LINE07 = ''; MAP.LINE08 = ''; MAP.LINE09 = ''; MAP.LINE10 = ''
  MAP.MSG = ''
  MAP.STATUS = ''
  cnt = PERIODS.0
  IF cnt = 0 THEN MAP.MSG = 'No periods. PF3 back to entry and add FROM dates.'
  ELSE MAP.STATUS = 'CR=Y counts for PEBD. Number + PF5 deletes. ENTER/PF6 calculates.'
  DO i = 1 TO cnt
    IF i > 10 THEN LEAVE
    lineText = RIGHT(i,2)||'  '||LEFT(PERIODS.i.FROM,10)||'  '||LEFT(PERIODS.i.TO,10)||'  '||,
               LEFT(PERIODS.i.BR,4)||' '||LEFT(PERIODS.i.CP,5)||' '||,
               LEFT(PERIODS.i.RS,6)||' '||RIGHT(PERIODS.i.LT,4)||'  '||PERIODS.i.CR
    SELECT
      WHEN i = 1  THEN MAP.LINE01 = lineText
      WHEN i = 2  THEN MAP.LINE02 = lineText
      WHEN i = 3  THEN MAP.LINE03 = lineText
      WHEN i = 4  THEN MAP.LINE04 = lineText
      WHEN i = 5  THEN MAP.LINE05 = lineText
      WHEN i = 6  THEN MAP.LINE06 = lineText
      WHEN i = 7  THEN MAP.LINE07 = lineText
      WHEN i = 8  THEN MAP.LINE08 = lineText
      WHEN i = 9  THEN MAP.LINE09 = lineText
      WHEN i = 10 THEN MAP.LINE10 = lineText
      OTHERWISE NOP
    END
  END
  MAP.SEL = ''
  EXEC CICS SEND MAP('DODF2') ERASE END-EXEC
RETURN

DeletePeriodByNumber: PROCEDURE EXPOSE PERIODS. MAP.
  PARSE ARG num
  num = num + 0
  IF num < 1 | num > PERIODS.0 THEN DO
    MAP.MSG = 'Invalid selection - enter 1 to' PERIODS.0
    RETURN
  END
  DO j = num TO PERIODS.0 - 1
    k = j + 1
    PERIODS.j.FROM = PERIODS.k.FROM
    PERIODS.j.TO   = PERIODS.k.TO
    PERIODS.j.BR   = PERIODS.k.BR
    PERIODS.j.CP   = PERIODS.k.CP
    PERIODS.j.RS   = PERIODS.k.RS
    PERIODS.j.LT   = PERIODS.k.LT
    PERIODS.j.CR   = PERIODS.k.CR
    PERIODS.j.ISLOST = PERIODS.k.ISLOST
    PERIODS.j.DEPNOTE = PERIODS.k.DEPNOTE
  END
  PERIODS.0 = PERIODS.0 - 1
  MAP.MSG = 'Period' num 'deleted.'
RETURN

PrefillDODF1FromPeriods: PROCEDURE EXPOSE PERIODS. MAP. EDIPI NAME ASOF RECPEBD GRADE
  MAP.EDIPI = EDIPI
  MAP.NAME = NAME
  MAP.ASOF = ASOF
  MAP.RECPEBD = RECPEBD
  MAP.GRADE = GRADE
  MAP.FROM1 = ''; MAP.TO1 = ''; MAP.BR1 = ''; MAP.CP1 = ''; MAP.RS1 = ''; MAP.LT1 = ''
  MAP.FROM2 = ''; MAP.TO2 = ''; MAP.BR2 = ''; MAP.CP2 = ''; MAP.RS2 = ''; MAP.LT2 = ''
  MAP.FROM3 = ''; MAP.TO3 = ''; MAP.BR3 = ''; MAP.CP3 = ''; MAP.RS3 = ''; MAP.LT3 = ''
  MAP.FROM4 = ''; MAP.TO4 = ''; MAP.BR4 = ''; MAP.CP4 = ''; MAP.RS4 = ''; MAP.LT4 = ''
  MAP.FROM5 = ''; MAP.TO5 = ''; MAP.BR5 = ''; MAP.CP5 = ''; MAP.RS5 = ''; MAP.LT5 = ''
  MAP.FROM6 = ''; MAP.TO6 = ''; MAP.BR6 = ''; MAP.CP6 = ''; MAP.RS6 = ''; MAP.LT6 = ''
  MAP.FROM7 = ''; MAP.TO7 = ''; MAP.BR7 = ''; MAP.CP7 = ''; MAP.RS7 = ''; MAP.LT7 = ''
  MAP.FROM8 = ''; MAP.TO8 = ''; MAP.BR8 = ''; MAP.CP8 = ''; MAP.RS8 = ''; MAP.LT8 = ''
  DO i = 1 TO PERIODS.0
    IF i > 8 THEN LEAVE
    SELECT
      WHEN i = 1 THEN DO
        MAP.FROM1 = PERIODS.1.FROM; MAP.TO1 = PERIODS.1.TO; MAP.BR1 = PERIODS.1.BR
        MAP.CP1 = PERIODS.1.CP; MAP.RS1 = PERIODS.1.RS; MAP.LT1 = PERIODS.1.LT
      END
      WHEN i = 2 THEN DO
        MAP.FROM2 = PERIODS.2.FROM; MAP.TO2 = PERIODS.2.TO; MAP.BR2 = PERIODS.2.BR
        MAP.CP2 = PERIODS.2.CP; MAP.RS2 = PERIODS.2.RS; MAP.LT2 = PERIODS.2.LT
      END
      WHEN i = 3 THEN DO
        MAP.FROM3 = PERIODS.3.FROM; MAP.TO3 = PERIODS.3.TO; MAP.BR3 = PERIODS.3.BR
        MAP.CP3 = PERIODS.3.CP; MAP.RS3 = PERIODS.3.RS; MAP.LT3 = PERIODS.3.LT
      END
      WHEN i = 4 THEN DO
        MAP.FROM4 = PERIODS.4.FROM; MAP.TO4 = PERIODS.4.TO; MAP.BR4 = PERIODS.4.BR
        MAP.CP4 = PERIODS.4.CP; MAP.RS4 = PERIODS.4.RS; MAP.LT4 = PERIODS.4.LT
      END
      WHEN i = 5 THEN DO
        MAP.FROM5 = PERIODS.5.FROM; MAP.TO5 = PERIODS.5.TO; MAP.BR5 = PERIODS.5.BR
        MAP.CP5 = PERIODS.5.CP; MAP.RS5 = PERIODS.5.RS; MAP.LT5 = PERIODS.5.LT
      END
      WHEN i = 6 THEN DO
        MAP.FROM6 = PERIODS.6.FROM; MAP.TO6 = PERIODS.6.TO; MAP.BR6 = PERIODS.6.BR
        MAP.CP6 = PERIODS.6.CP; MAP.RS6 = PERIODS.6.RS; MAP.LT6 = PERIODS.6.LT
      END
      WHEN i = 7 THEN DO
        MAP.FROM7 = PERIODS.7.FROM; MAP.TO7 = PERIODS.7.TO; MAP.BR7 = PERIODS.7.BR
        MAP.CP7 = PERIODS.7.CP; MAP.RS7 = PERIODS.7.RS; MAP.LT7 = PERIODS.7.LT
      END
      WHEN i = 8 THEN DO
        MAP.FROM8 = PERIODS.8.FROM; MAP.TO8 = PERIODS.8.TO; MAP.BR8 = PERIODS.8.BR
        MAP.CP8 = PERIODS.8.CP; MAP.RS8 = PERIODS.8.RS; MAP.LT8 = PERIODS.8.LT
      END
      OTHERWISE NOP
    END
  END
RETURN

ClearEntryMap: PROCEDURE EXPOSE MAP.
  MAP.EDIPI = ''; MAP.NAME = ''; MAP.ASOF = ''; MAP.RECPEBD = ''; MAP.GRADE = 'E'
  MAP.FROM1 = ''; MAP.TO1 = ''; MAP.BR1 = ''; MAP.CP1 = ''; MAP.RS1 = ''; MAP.LT1 = ''
  MAP.FROM2 = ''; MAP.TO2 = ''; MAP.BR2 = ''; MAP.CP2 = ''; MAP.RS2 = ''; MAP.LT2 = ''
  MAP.FROM3 = ''; MAP.TO3 = ''; MAP.BR3 = ''; MAP.CP3 = ''; MAP.RS3 = ''; MAP.LT3 = ''
  MAP.FROM4 = ''; MAP.TO4 = ''; MAP.BR4 = ''; MAP.CP4 = ''; MAP.RS4 = ''; MAP.LT4 = ''
  MAP.FROM5 = ''; MAP.TO5 = ''; MAP.BR5 = ''; MAP.CP5 = ''; MAP.RS5 = ''; MAP.LT5 = ''
  MAP.FROM6 = ''; MAP.TO6 = ''; MAP.BR6 = ''; MAP.CP6 = ''; MAP.RS6 = ''; MAP.LT6 = ''
  MAP.FROM7 = ''; MAP.TO7 = ''; MAP.BR7 = ''; MAP.CP7 = ''; MAP.RS7 = ''; MAP.LT7 = ''
  MAP.FROM8 = ''; MAP.TO8 = ''; MAP.BR8 = ''; MAP.CP8 = ''; MAP.RS8 = ''; MAP.LT8 = ''
RETURN

ReviewAndDeleteLoop: PROCEDURE EXPOSE PERIODS. MAP. ReviewAction ASOF EDIPI NAME RECPEBD GRADE ISLOST DEPOK DEPNOTE
  ReviewAction = ''
  DO FOREVER
    EXEC CICS RECEIVE MAP('DODF2') END-EXEC
    IF EIBRESP \= 0 THEN DO
      ReviewAction = 'CALC'
      RETURN
    END
    rAID = C2X(EIBAID)
    IF rAID = 'F3' THEN DO
      CALL PrefillDODF1FromPeriods
      EXEC CICS SEND MAP('DODF1') ERASE END-EXEC
      ReviewAction = 'BACK'
      RETURN
    END
    IF rAID = 'F5' THEN DO
      sel = STRIP(MAP.SEL)
      IF sel \= '' THEN CALL DeletePeriodByNumber sel
      CALL ClassifyPeriods
      CALL SendReviewMap
      ITERATE
    END
    IF rAID = '7D' | rAID = 'F6' | rAID = '7E' THEN DO
      ReviewAction = 'CALC'
      RETURN
    END
    IF rAID = 'F9' THEN DO
      PERIODS.0 = 0
      CALL PrefillDODF1FromPeriods
      EXEC CICS SEND MAP('DODF1') ERASE END-EXEC
      ReviewAction = 'BACK'
      RETURN
    END
  END
RETURN

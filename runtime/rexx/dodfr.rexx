/* DODFR -- DODFMR Statement of Service / PEBD (PAT parity)            */
/* Engine port of personnel-admin-tools/public/dodfmr/dodfmr_core.js   */
/* DoD FMR Vol 7A Ch 1: 30/360, inclusive +1, DEP 2.1.4.12,            */
/* lost time 2.4.1.3.1 / officer 2.2.2 / while-enlisted / PEBD 2.4.1.4 */
/* Typed dates only. As-of stands in for PAT's wall-clock today.       */
/* Blank TO is open (PRESENT): merged through as-of, lost count uses   */
/* the typed LOST field. WE=Y applies enlisted lost time on grade O/W. */

ADDRESS CICS

EXEC CICS ASSIGN DATE(TODAY) END-EXEC
IF DATATYPE(TODAY,'W') \= 1 | LENGTH(STRIP(TODAY)) \= 8 THEN TODAY = '20260101'

MAP.GRADE = 'E'
EXEC CICS SEND MAP('DODF1') ERASE END-EXEC

DO FOREVER /* session: entry -> report -> edit or menu */

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

  CALL ValidateEntry
  IF ERRTEXT \= '' THEN DO
    MAP.ERRMSG = ERRTEXT
    EXEC CICS SEND MAP('DODF1') ERASE END-EXEC
    ITERATE
  END
  MAP.ERRMSG = ''

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
LOSTCOUNTED = 0
LOSTN = 0
MADEN = 0
HASPRIOR = 0
HASOFFEX = 0
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
  IF PERIODS.i.ISLOST = 1 THEN CALL ApplyLostRow i
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
NETBREAK = YRS || 'y ' || MOS || 'm ' || DYS || 'd'
BREAKDOWN = YRS || ' years, ' || MOS || ' months, ' || DYS || ' days'
LY = LOSTTOTAL % 360
LR = LOSTTOTAL // 360
LM = LR % 30
LD = LR // 30
LOSTBREAK = LY || 'y ' || LM || 'm ' || LD || 'd'
CY = LOSTCOUNTED % 360
CR = LOSTCOUNTED // 360
CM = CR % 30
CD = CR // 30
COUNTBREAK = CY || 'y ' || CM || 'm ' || CD || 'd'

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
IF LOSTTOTAL > 0 THEN DO
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
    IF LOSTTOTAL > 0 THEN
      STATUS = 'MATCH - recorded PEBD matches calculated (lost time already applied to PEBD per 2.4.1.4)'
    ELSE STATUS = 'MATCH'
    DIFF = '0 days'
  END
  ELSE DO
    AD = ABS(DIFFDAYS)
    IF DIFFDAYS > 0 THEN sgn = '+'
    ELSE sgn = ''
    IF AD = 1 THEN
      STATUS = 'CLOSE MATCH ('||sgn||DIFFDAYS||' day) - likely MCTFS data entry variance'
    ELSE IF AD <= 3 THEN
      STATUS = 'MINOR DIFF: '||sgn||DIFFDAYS||' days - verify with finance'
    ELSE IF AD <= 7 THEN
      STATUS = 'MODERATE DIFF: '||sgn||DIFFDAYS||' days - investigate calculation'
    ELSE
      STATUS = 'SIGNIFICANT DIFF: '||sgn||DIFFDAYS||' days - requires investigation'
    IF DIFFDAYS > 0 THEN DIFF = '+'||DIFFDAYS||' days'
    ELSE DIFF = DIFFDAYS||' days'
  END
END

/* ---- report. Pad to the real screen so a 32/43-row TN3270 is not blank. */
EXEC CICS ASSIGN SCREENHT(SCRNHT) SCREENWD(SCRNWD) END-EXEC
IF DATATYPE(SCRNHT,'W') \= 1 | SCRNHT < 24 THEN SCRNHT = 24
IF SCRNHT > 43 THEN SCRNHT = 43
IF DATATYPE(SCRNWD,'W') \= 1 | SCRNWD < 80 THEN SCRNWD = 80
IF SCRNWD > 80 THEN SCRNWD = 80
BODY = SCRNHT - 2
IF BODY < 1 THEN BODY = 22
CALL BuildReport
IF NLINES < 1 THEN DO
  NLINES = 1
  RL.1 = 'Report failed to build. PEBD '||CALCPEBD||' '||STATUS
END
PAGE = 1
PAGES = (NLINES + BODY - 1) % BODY
IF PAGES < 1 THEN PAGES = 1
edit = 0
DO FOREVER
  TXT = ''
  start = (PAGE - 1) * BODY + 1
  DO r = 1 TO BODY
    idx = start + r - 1
    IF idx <= NLINES THEN line = RL.idx
    ELSE line = ''
    TXT = TXT || LEFT(line, SCRNWD)
  END
  TXT = TXT || LEFT('PF7=prev  PF8=next  ENTER/PF12=edit  PF3=menu', SCRNWD)
  TXT = TXT || LEFT('Page '||PAGE||'/'||PAGES||'  PEBD '||CALCPEBD||'  '||STATUS, SCRNWD)
  EXEC CICS SEND TEXT FROM(TXT) ERASE END-EXEC
  AID = C2X(EIBAID)
  IF AID = 'F7' THEN DO
    IF PAGE > 1 THEN PAGE = PAGE - 1
    ITERATE
  END
  IF AID = 'F8' THEN DO
    IF PAGE < PAGES THEN PAGE = PAGE + 1
    ITERATE
  END
  IF AID = '7D' | AID = '7C' THEN DO
    edit = 1
    LEAVE
  END
  LEAVE
END
IF edit = 1 THEN DO
  CALL PrefillDODF1FromPeriods
  EXEC CICS SEND MAP('DODF1') ERASE END-EXEC
  ITERATE
END
EXEC CICS RETURN TRANSID('MYMU') END-EXEC
END

/* ================================================================== */
/* Helpers. CALL only (PROCEDURE labels). Result vars via EXPOSE.     */
/* ================================================================== */

ApplyLostRow: PROCEDURE EXPOSE PERIODS. LOSTA. LOSTN LOSTTOTAL LOSTCOUNTED,
  MADEN HASPRIOR HASOFFEX OFFICER CH1DAYS D30DAYS CALDAYS JDN ADJ SEGDAYS,
  MADEGOOD ISLOST OUTDATE
  PARSE ARG i
  LOSTN = LOSTN + 1
  n = LOSTN
  LOSTA.n.FROM = PERIODS.i.FROM
  LOSTA.n.TO = PERIODS.i.TO
  LOSTA.n.OPEN = PERIODS.i.OPEN
  LOSTA.n.RS = PERIODS.i.RS
  LOSTA.n.MTFS = PERIODS.i.LT
  LOSTA.n.WE = PERIODS.i.WE
  dated = 0
  IF PERIODS.i.OPEN = 0 & PERIODS.i.FROM \= '' & PERIODS.i.TO \= '' THEN dated = 1
  LOSTA.n.DATED = dated
  IF dated = 1 THEN DO
    CALL ComputeLostDaysCh1 PERIODS.i.FROM, PERIODS.i.TO
    LOSTA.n.CH1 = CH1DAYS
    CALL ComputeLostDays30 PERIODS.i.FROM, PERIODS.i.TO
    LOSTA.n.D30 = D30DAYS
    CALL CalDaysIncl PERIODS.i.FROM, PERIODS.i.TO
    LOSTA.n.CAL = CALDAYS
    counted = CH1DAYS
  END
  ELSE DO
    counted = PERIODS.i.LT
    LOSTA.n.CH1 = ''
    LOSTA.n.D30 = ''
    LOSTA.n.CAL = ''
  END
  LOSTA.n.COUNTED = counted
  PERIODS.i.COUNTED = counted
  whileE = 0
  IF PERIODS.i.WE = 'Y' THEN whileE = 1
  offEx = 0
  IF OFFICER = 1 & whileE = 0 THEN offEx = 1
  madeGood = 0
  IF dated = 1 THEN DO
    CALL IsMadeGood i
    madeGood = MADEGOOD
  END
  IF offEx = 1 THEN DO
    applied = 0
    meth = 'Officer Exception'
    note = 'Per 2.2.2 / 2.4.1.4: lost time while in officer status does not affect length of service. Counted days are shown for audit and are not applied to PEBD.'
    LOSTA.n.APPLIEDFLG = 0
    HASOFFEX = 1
  END
  ELSE IF dated = 0 THEN DO
    applied = counted
    IF whileE = 1 THEN DO
      meth = 'Prior Enlisted Lost Time (MCTFS Value)'
      note = 'Lost time occurred while enlisted. Using MCTFS-provided LOST field value ('||counted||' days). Non-creditable for pay/PEBD under 2.4.1.3.1 / 2.4.1.4.'
      HASPRIOR = 1
    END
    ELSE DO
      meth = 'MCTFS Value'
      note = 'Using MCTFS-provided LOST field value ('||counted||' days)'
    END
    LOSTA.n.APPLIEDFLG = 1
  END
  ELSE DO
    applied = LOSTA.n.CH1
    IF madeGood = 1 THEN
      enlistedNote = 'Per 10 U.S.C. 972 and DoD FMR: Lost time is always non-creditable for pay/PEBD, even if made good by serving extra time. ETS/EAOS is extended; PEBD is not restored. Count is 2.4.1.3.1 (30-day).'
    ELSE
      enlistedNote = 'Per DoD FMR 2.4.1.3.1: lost time not made good is counted on a 30-day month (start-on-31st included) and added to PEBD per 2.4.1.4.'
    IF whileE = 1 THEN DO
      IF madeGood = 1 THEN meth = 'Prior Enlisted Lost Time (Made Good, Still Deducted)'
      ELSE meth = 'Prior Enlisted Lost Time (Deducted)'
      note = 'Lost time occurred while enlisted. It is non-creditable and retards PEBD under the enlisted Chapter 1 rules, even though present grade is officer. '||enlistedNote
      HASPRIOR = 1
    END
    ELSE DO
      IF madeGood = 1 THEN meth = 'Made Good (Still Deducted)'
      ELSE meth = 'Not Made Good (Deducted)'
      note = enlistedNote
    END
    LOSTA.n.APPLIEDFLG = 1
  END
  LOSTA.n.DAYS = applied
  LOSTA.n.METH = meth
  LOSTA.n.NOTE = note
  PERIODS.i.APPLIEDFLG = LOSTA.n.APPLIEDFLG
  LOSTTOTAL = LOSTTOTAL + applied
  LOSTCOUNTED = LOSTCOUNTED + counted
  IF PERIODS.i.FROM \= '' THEN MADEN = MADEN + 1
RETURN

IsMadeGood: PROCEDURE EXPOSE PERIODS. MADEGOOD CALDAYS JDN ISLOST
  PARSE ARG idx
  MADEGOOD = 0
  lostEnd = PERIODS.idx.TO
  IF lostEnd = '' THEN RETURN
  CALL CalDaysIncl PERIODS.idx.FROM, lostEnd
  lostDays = CALDAYS
  hasSub = 0
  hasOpen = 0
  subDays = 0
  DO j = 1 TO PERIODS.0
    CALL IsLostReason PERIODS.j.RS
    IF ISLOST = 1 THEN ITERATE
    IF PERIODS.j.FROM = '' | PERIODS.j.FROM <= lostEnd THEN ITERATE
    hasSub = 1
    IF PERIODS.j.OPEN = 1 THEN hasOpen = 1
    ELSE DO
      CALL CalDaysIncl PERIODS.j.FROM, PERIODS.j.TO
      subDays = subDays + CALDAYS
    END
  END
  IF hasSub = 0 THEN RETURN
  IF hasOpen = 1 THEN MADEGOOD = 1
  ELSE IF subDays >= lostDays THEN MADEGOOD = 1
RETURN

CalDaysIncl: PROCEDURE EXPOSE CALDAYS JDN
  PARSE ARG start, end
  CALDAYS = 0
  IF start = '' | end = '' | start > end THEN RETURN
  CALL ToJdn start
  j1 = JDN
  CALL ToJdn end
  CALDAYS = JDN - j1 + 1
RETURN

ComputeLostDays30: PROCEDURE EXPOSE D30DAYS ADJ
  PARSE ARG start, end
  D30DAYS = 0
  IF start = '' | end = '' | start > end THEN RETURN
  ys = SUBSTR(start,1,4)+0; ms = SUBSTR(start,5,2)+0; ds = SUBSTR(start,7,2)+0
  ye = SUBSTR(end,1,4)+0;   me = SUBSTR(end,5,2)+0;   de = SUBSTR(end,7,2)+0
  IF ds \= 31 THEN DO
    CALL AdjustDay ds, ms, ys
    ds = ADJ
  END
  CALL AdjustDay de, me, ye
  de = ADJ
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
  D30DAYS = years * 360 + months * 30 + days
  IF D30DAYS < 0 THEN D30DAYS = 0
RETURN

FmtSlash: PROCEDURE EXPOSE SLASH
  PARSE ARG ymd
  IF ymd = '' THEN SLASH = ''
  ELSE SLASH = SUBSTR(ymd,1,4)||'/'||SUBSTR(ymd,5,2)||'/'||SUBSTR(ymd,7,2)
RETURN

AddRep: PROCEDURE EXPOSE RL. NLINES
  PARSE ARG text
  IF NLINES >= 160 THEN RETURN
  NLINES = NLINES + 1
  RL.NLINES = LEFT(text, 80)
RETURN

AddWrap: PROCEDURE EXPOSE RL. NLINES
  PARSE ARG text, width, indent
  IF width = '' | width = 0 THEN width = 80
  line = ''
  cont = 0
  DO WHILE text \= ''
    PARSE VAR text word text
    IF word = '' THEN ITERATE
    IF line = '' THEN DO
      IF cont = 1 THEN line = indent||word
      ELSE line = word
    END
    ELSE IF LENGTH(line) + 1 + LENGTH(word) > width THEN DO
      CALL AddRep line
      cont = 1
      line = indent||word
    END
    ELSE line = line||' '||word
  END
  IF line \= '' THEN CALL AddRep line
RETURN

BuildReport: PROCEDURE EXPOSE RL. NLINES PERIODS. LOSTA. MERGED. SLASH,
  OFFICER GRADE EDIPI NAME ASOF RECPEBD GROSSDAYS LOSTTOTAL LOSTCOUNTED,
  NETDAYS NETBREAK LOSTBREAK COUNTBREAK PEBDBASE CALCPEBD STATUS DIFF,
  LOSTN MADEN HASPRIOR HASOFFEX ISLOST
  NLINES = 0
  IF OFFICER = 1 THEN CLASSSTR = 'OFFICER (O/W grade)'
  ELSE CLASSSTR = 'ENLISTED'
  CALL AddRep '=== DODFMR STATEMENT OF SERVICE (PAT / Ch 1) ==='
  CALL AddRep 'MEMBER CLASSIFICATION: '||CLASSSTR
  IF OFFICER = 1 THEN DO
    IF HASPRIOR = 1 & HASOFFEX = 1 THEN
      onote = '  Note: Lost time while enlisted is non-creditable and retards PEBD (2.4.1.3.1 / 2.4.1.4). Lost time while in officer status does not (2.2.2).'
    ELSE IF HASPRIOR = 1 THEN
      onote = '  Note: Lost time on this record is marked while enlisted. It is non-creditable and retards PEBD under 2.4.1.3.1 / 2.4.1.4 even though present grade is officer.'
    ELSE
      onote = '  Note: Per DODFMR 2.2.2, lost time while in officer status does not affect length of service. Counted days are still shown. Set WE=Y if a lost-time row was during enlisted service.'
    CALL AddWrap onote, 80, ''
  END
  CALL AddRep ''
  CALL AddRep 'EDIPI '||EDIPI||' NAME: '||NAME
  CALL FmtSlash ASOF
  CALL AddRep 'Grade: '||GRADE||'    As of: '||SLASH||'    (typed entry, no D188)'
  IF RECPEBD = '' THEN CALL AddRep 'Record PEBD: (none)'
  ELSE DO
    CALL FmtSlash RECPEBD
    CALL AddRep 'Record PEBD: '||SLASH
  END
  CALL AddRep COPIES('=', 80)
  CALL AddRep ''
  CALL AddRep 'SERVICE PERIODS:'
  CALL AddRep LEFT('Branch',12)||LEFT('Component',12)||LEFT('Reason',12)||LEFT('From (YYYY/MM/DD)',18)||LEFT('To (YYYY/MM/DD)',18)||'TmLost'
  CALL AddRep COPIES('-', 80)
  DO i = 1 TO PERIODS.0
    ORD.i = i
  END
  DO i = 1 TO PERIODS.0 - 1
    DO j = i + 1 TO PERIODS.0
      ki = ORD.i
      kj = ORD.j
      IF PERIODS.kj.FROM > PERIODS.ki.FROM THEN DO
        t = ORD.i; ORD.i = ORD.j; ORD.j = t
      END
    END
  END
  star = 0
  DO i = 1 TO PERIODS.0
    k = ORD.i
    CALL FmtSlash PERIODS.k.FROM
    froms = SLASH
    IF PERIODS.k.OPEN = 1 THEN tos = 'PRESENT'
    ELSE DO
      CALL FmtSlash PERIODS.k.TO
      tos = SLASH
    END
    lost = 'N/A'
    CALL IsLostReason PERIODS.k.RS
    IF ISLOST = 1 THEN DO
      lost = PERIODS.k.COUNTED||'d'
      IF PERIODS.k.APPLIEDFLG = 0 THEN DO
        lost = lost||'*'
        star = 1
      END
    END
    ELSE IF PERIODS.k.LT > 0 THEN lost = PERIODS.k.LT||'d'
    CALL AddRep LEFT(PERIODS.k.BR,12)||LEFT(PERIODS.k.CP,12)||LEFT(PERIODS.k.RS,12)||,
         LEFT(froms,18)||LEFT(tos,18)||lost
  END
  CALL AddRep COPIES('-', 80)
  IF star = 1 THEN
    CALL AddRep 'TmLost * = counted days not applied to PEBD (officer exception, 2.2.2).'
  CALL AddRep ''
  depn = 0
  DO i = 1 TO PERIODS.0
    IF PERIODS.i.CP = 'DEP' THEN depn = depn + 1
  END
  IF depn > 0 THEN DO
    CALL AddRep 'DEP CREDITABILITY (DoD FMR Vol 7A Ch 1 2.1.4.12 / 2.2.1.7-2.2.1.8):'
    CALL AddWrap 'Year-based DEP rules only. Typed entry has no IDT flag - post-29 Nov 1989 DEP is excluded by default. If RT07 shows IDT before AD/ADT for a DEP begin date, reclass that row to RES and recalculate.', 80, ''
    DO i = 1 TO PERIODS.0
      IF PERIODS.i.CP \= 'DEP' THEN ITERATE
      CALL FmtSlash PERIODS.i.FROM
      froms = SLASH
      IF PERIODS.i.OPEN = 1 THEN tos = 'PRESENT'
      ELSE DO
        CALL FmtSlash PERIODS.i.TO
        tos = SLASH
      END
      IF PERIODS.i.CR = 'Y' THEN st = 'INCLUDED'
      ELSE st = 'EXCLUDED'
      CALL AddRep '  '||froms||' -> '||tos||': '||st||' - '||PERIODS.i.DEPNOTE||' ['||PERIODS.i.DEPRULE||']'
      IF PERIODS.i.DEPACTION \= '' THEN
        CALL AddWrap '    ACTION: '||PERIODS.i.DEPACTION, 80, ''
    END
    CALL AddRep ''
  END
  thead = 'CREDITABLE SERVICE TIMELINE (DODFMR 30/360 Method, Merged'
  IF MADEN > 0 THEN thead = thead||', Made-Good Periods Included'
  thead = thead||'):'
  CALL AddWrap thead, 80, ''
  CALL AddRep 'Start Date         End Date               Days (30/360 + 1 inclusive)'
  CALL AddRep COPIES('-', 80)
  DO i = 1 TO MERGED.0
    CALL FmtSlash MERGED.i.FROM
    froms = SLASH
    CALL FmtSlash MERGED.i.TO
    tos = SLASH
    CALL AddRep LEFT(froms,18)||LEFT(tos,22)||MERGED.i.DAYS||' days  ('||MERGED.i.BASE||' base + 1)'
  END
  CALL AddRep ''
  CALL AddWrap 'Note: +1 inclusive day added per segment per DODFMR 2.4.1.3.2 examples', 80, ''
  CALL AddRep ''
  IF LOSTN > 0 THEN DO
    CALL AddRep COPIES('=', 80)
    CALL AddRep 'DODFMR LOST TIME ANALYSIS (Per Vol 7A, Ch 1, 2.4.1.3.1 / 2.4.1.4):'
    CALL AddRep COPIES('-', 80)
    DO i = 1 TO LOSTN
      CALL FmtSlash LOSTA.i.FROM
      froms = SLASH
      IF LOSTA.i.OPEN = 1 THEN tos = 'PRESENT'
      ELSE DO
        CALL FmtSlash LOSTA.i.TO
        tos = SLASH
      END
      CALL AddRep 'Period: '||froms||' -> '||tos||' ('||LOSTA.i.RS||')'
      CALL AddRep '  MCTFS LOST Field:    '||LOSTA.i.MTFS||' days'
      IF LOSTA.i.DATED = 1 THEN DO
        IF LOSTA.i.APPLIEDFLG = 0 THEN applyNote = 'counted; not applied to PEBD'
        ELSE applyNote = 'counted; applied to PEBD'
        CALL AddRep '  30-Day Basis (2.4.1.3.1): '||LOSTA.i.CH1||' days  ('||applyNote||')'
        CALL AddRep '  Day-to-Day Calc:          '||LOSTA.i.CAL||' days  (calendar / AFADBD clock; 2.4.1.3.2 if hitch completed)'
      END
      CALL AddRep '  Method:             '||LOSTA.i.METH
      CALL AddRep '  Days Counted:       '||LOSTA.i.COUNTED
      CALL AddRep '  Days Deducted:      '||LOSTA.i.DAYS
      CALL AddWrap '  Determination:      '||LOSTA.i.NOTE, 80, '                      '
      CALL AddRep ''
    END
    CALL AddRep 'Total Lost Time Counted:  '||LOSTCOUNTED||' days'
    CALL AddRep 'Total Lost Time Applied:  '||LOSTTOTAL||' days'
    CALL AddRep ''
  END
  CALL AddRep COPIES('=', 80)
  CALL AddRep 'SERVICE SUMMARY AND PEBD VALIDATION:'
  CALL AddRep COPIES('-', 80)
  gline = 'Gross Creditable Service: '||GROSSDAYS||' days'
  IF MADEN > 0 THEN
    gline = gline||' (includes made-good lost time periods per 2.4.1.3.2)'
  CALL AddWrap gline, 80, ''
  IF MERGED.0 = 1 THEN iday = 'day'
  ELSE iday = 'days'
  CALL AddRep '  (Includes +'||MERGED.0||' inclusive '||iday||' per 2.4.1.3.2)'
  CALL AddRep 'Total Lost Time Counted:  '||LOSTCOUNTED||' days'
  CALL AddRep 'Total Lost Time Applied:  '||LOSTTOTAL||' days'
  IF LOSTCOUNTED > 0 & LOSTTOTAL = 0 THEN
    CALL AddWrap 'Counted lost time is not applied to PEBD because each lost-time row is under the officer exception (2.2.2). Set WE=Y on a row if that lost time was during enlisted service.', 80, ''
  ELSE IF LOSTCOUNTED \= LOSTTOTAL THEN
    CALL AddWrap 'Applied days are less than counted days because one or more lost-time rows were in officer status and are not deducted (2.2.2).', 80, ''
  CALL AddRep 'Net Creditable Service:   '||NETDAYS||' days ('||NETBREAK||')'
  CALL AddRep ''
  CALL FmtSlash PEBDBASE
  pbase = SLASH
  CALL FmtSlash CALCPEBD
  pcalc = SLASH
  IF RECPEBD = '' THEN prec = '(none)'
  ELSE DO
    CALL FmtSlash RECPEBD
    prec = SLASH
  END
  CALL AddRep 'PEBD COMPARISON (DoDFMR Ch 1 2.4.1.4):'
  CALL AddRep 'PEBD before lost time:    '||pbase
  CALL AddRep 'Lost time counted:        '||COUNTBREAK||' ('||LOSTCOUNTED||' days)'
  CALL AddRep 'Lost time applied:        '||LOSTBREAK||' ('||LOSTTOTAL||' days)'
  CALL AddRep 'Calculated PEBD (retarded): '||pcalc
  CALL AddRep 'Recorded PEBD (System):   '||prec
  CALL AddWrap 'Validation Status:        '||STATUS, 80, '                          '
  IF POS('SIGNIFICANT', STATUS) > 0 | POS('MODERATE', STATUS) > 0 |,
     POS('MINOR', STATUS) > 0 | (POS('DIFF', STATUS) > 0 & POS('MATCH', STATUS) = 0) THEN DO
    CALL AddRep ''
    CALL AddRep 'PEBD DISCREPANCY DETECTED - Possible reasons:'
    CALL AddRep '    - Administrative adjustment in MCTFS not reflected in typed history'
    CALL AddRep '    - Lost time treatment differs from DODFMR strict interpretation'
    CALL AddRep '    - Officer/enlisted classification may need verification'
    CALL AddRep '    - Prior service from another branch may not be entered'
    CALL AddRep '    - MCTFS may have a data entry error (verify with finance)'
    CALL AddRep '    - Review the DODFMR LOST TIME ANALYSIS section above'
    CALL AddRep '    - Refer to DODFMR Vol 7A, Ch 1 for specific rules'
  END
  ELSE IF POS('CLOSE MATCH', STATUS) > 0 THEN DO
    CALL AddRep ''
    CALL AddWrap 'CLOSE MATCH: 1-day variance is common due to MCTFS data entry timing or 30/360 adjustments at month-end/31st/Feb dates. This is typically within acceptable tolerance per finance practice.', 80, ''
  END
  ELSE IF POS('MATCH', STATUS) > 0 & LOSTTOTAL > 0 THEN DO
    CALL AddRep ''
    CALL AddWrap 'Calculated PEBD is the PEBD-before-lost plus lost Y/M/D on a 30-day month (DoD FMR 2.4.1.4). Recorded PEBD matches.', 80, ''
  END
  CALL AddRep ''
  CALL AddRep COPIES('=', 80)
  CALL FmtSlash ASOF
  CALL AddRep 'Generated on: '||SLASH
  CALL AddRep 'Report computed per DODFMR Vol 7A, Chapter 1'
  CALL AddRep 'Enlisted PEBD = PEBD-before-lost plus lost Y/M/D on a 30-day month (2.4.1.4)'
  CALL AddRep 'Lost time counted per 2.4.1.3.1 (30-day month; start-on-31st included)'
  CALL AddRep 'Officer exception per 2.2.2 applies only to lost time while in officer status'
  CALL AddRep 'Lost time while enlisted is non-creditable and retards PEBD (2.4.1.3.1 / 2.4.1.4)'
RETURN

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

CheckYmd: PROCEDURE EXPOSE CHECKYMD DIM
  PARSE ARG ymd
  CHECKYMD = 0
  IF LENGTH(ymd) \= 8 | DATATYPE(ymd,'W') \= 1 THEN RETURN
  y = SUBSTR(ymd,1,4)+0
  m = SUBSTR(ymd,5,2)+0
  d = SUBSTR(ymd,7,2)+0
  IF y < 1800 | y > 2200 THEN RETURN
  IF m < 1 | m > 12 THEN RETURN
  CALL DaysInMonth y, m
  IF d < 1 | d > DIM THEN RETURN
  CHECKYMD = 1
RETURN

ValidReason: PROCEDURE EXPOSE RSVALID
  PARSE ARG r
  r = TRANSLATE(STRIP(r))
  RSVALID = 0
  IF r = '' | r = 'ACT' | r = 'INACT' | r = 'CNFD' | r = 'EXPECC' |,
     r = 'IHCA' | r = 'IHFA' | r = 'RTFD' | r = 'UA/DES' THEN RSVALID = 1
RETURN

ValidateRow: PROCEDURE EXPOSE ERRTEXT NORMDATE CHECKYMD DIM RSVALID
  PARSE ARG fromraw, toraw, br, cp, rs, lt, we, rown
  f = STRIP(fromraw)
  t = STRIP(toraw)
  br = STRIP(br)
  cp = STRIP(cp)
  rs = STRIP(rs)
  lt = STRIP(lt)
  we = TRANSLATE(STRIP(we))
  has = 0
  IF t \= '' | br \= '' | cp \= '' | rs \= '' | lt \= '' | we \= '' THEN has = 1
  IF f = '' THEN DO
    IF has = 1 THEN ERRTEXT = 'Row ' || rown || ': FROM date required'
    RETURN
  END
  CALL NormDate f
  fymd = NORMDATE
  IF fymd = '' THEN DO
    ERRTEXT = 'Row ' || rown || ': FROM must be YYYYMMDD'
    RETURN
  END
  CALL CheckYmd fymd
  IF CHECKYMD = 0 THEN DO
    ERRTEXT = 'Row ' || rown || ': FROM is not a valid date'
    RETURN
  END
  tymd = ''
  IF t \= '' THEN DO
    CALL NormDate t
    tymd = NORMDATE
    IF tymd = '' THEN DO
      ERRTEXT = 'Row ' || rown || ': TO must be YYYYMMDD'
      RETURN
    END
    CALL CheckYmd tymd
    IF CHECKYMD = 0 THEN DO
      ERRTEXT = 'Row ' || rown || ': TO is not a valid date'
      RETURN
    END
    IF fymd > tymd THEN DO
      ERRTEXT = 'Row ' || rown || ': FROM is after TO'
      RETURN
    END
  END
  CALL ValidReason rs
  IF RSVALID = 0 THEN DO
    ERRTEXT = 'Row ' || rown || ': REASON must be ACT/INACT/CNFD/EXPECC/IHCA/IHFA/RTFD/UA/DES'
    RETURN
  END
  IF lt \= '' THEN DO
    IF DATATYPE(lt,'N') \= 1 THEN DO
      ERRTEXT = 'Row ' || rown || ': LOST days must be numeric'
      RETURN
    END
    IF lt + 0 < 0 THEN DO
      ERRTEXT = 'Row ' || rown || ': LOST days cannot be negative'
      RETURN
    END
  END
  IF we \= '' & we \= 'Y' & we \= 'N' & we \= 'YES' & we \= 'NO' &,
     we \= '1' & we \= '0' THEN DO
    ERRTEXT = 'Row ' || rown || ': WE must be Y or N'
    RETURN
  END
RETURN

ValidateEntry: PROCEDURE EXPOSE MAP. ERRTEXT NORMDATE CHECKYMD DIM RSVALID
  ERRTEXT = ''
  g = TRANSLATE(STRIP(MAP.GRADE))
  IF g = '' THEN g = 'E'
  IF g \= 'E' & g \= 'O' & g \= 'W' THEN DO
    ERRTEXT = 'GRADE must be E, O, or W'
    RETURN
  END
  asofraw = STRIP(MAP.ASOF)
  IF asofraw \= '' THEN DO
    CALL NormDate asofraw
    IF NORMDATE = '' THEN DO
      ERRTEXT = 'AS OF must be YYYYMMDD'
      RETURN
    END
    CALL CheckYmd NORMDATE
    IF CHECKYMD = 0 THEN DO
      ERRTEXT = 'AS OF is not a valid date'
      RETURN
    END
  END
  recraw = STRIP(MAP.RECPEBD)
  IF recraw \= '' THEN DO
    CALL NormDate recraw
    IF NORMDATE = '' THEN DO
      ERRTEXT = 'RECORD PEBD must be YYYYMMDD'
      RETURN
    END
    CALL CheckYmd NORMDATE
    IF CHECKYMD = 0 THEN DO
      ERRTEXT = 'RECORD PEBD is not a valid date'
      RETURN
    END
  END
  CALL ValidateRow MAP.FROM1, MAP.TO1, MAP.BR1, MAP.CP1, MAP.RS1, MAP.LT1, MAP.WE1, 1
  IF ERRTEXT \= '' THEN RETURN
  CALL ValidateRow MAP.FROM2, MAP.TO2, MAP.BR2, MAP.CP2, MAP.RS2, MAP.LT2, MAP.WE2, 2
  IF ERRTEXT \= '' THEN RETURN
  CALL ValidateRow MAP.FROM3, MAP.TO3, MAP.BR3, MAP.CP3, MAP.RS3, MAP.LT3, MAP.WE3, 3
  IF ERRTEXT \= '' THEN RETURN
  CALL ValidateRow MAP.FROM4, MAP.TO4, MAP.BR4, MAP.CP4, MAP.RS4, MAP.LT4, MAP.WE4, 4
  IF ERRTEXT \= '' THEN RETURN
  CALL ValidateRow MAP.FROM5, MAP.TO5, MAP.BR5, MAP.CP5, MAP.RS5, MAP.LT5, MAP.WE5, 5
  IF ERRTEXT \= '' THEN RETURN
  CALL ValidateRow MAP.FROM6, MAP.TO6, MAP.BR6, MAP.CP6, MAP.RS6, MAP.LT6, MAP.WE6, 6
  IF ERRTEXT \= '' THEN RETURN
  CALL ValidateRow MAP.FROM7, MAP.TO7, MAP.BR7, MAP.CP7, MAP.RS7, MAP.LT7, MAP.WE7, 7
  IF ERRTEXT \= '' THEN RETURN
  CALL ValidateRow MAP.FROM8, MAP.TO8, MAP.BR8, MAP.CP8, MAP.RS8, MAP.LT8, MAP.WE8, 8
RETURN

EvalDep: PROCEDURE EXPOSE DEPOK DEPNOTE DEPRULE DEPACTION
  PARSE ARG from
  DEPOK = 0
  DEPNOTE = ''
  DEPRULE = '2.1.4.12'
  DEPACTION = ''
  IF from = '' THEN DO
    DEPNOTE = 'DEP - Not Creditable (missing enlistment/from date)'
    RETURN
  END
  ymd = from + 0
  IF ymd < 19850101 THEN DO
    DEPOK = 1
    DEPNOTE = 'DEP - Creditable (enlistment before 1 Jan 1985)'
    RETURN
  END
  IF ymd <= 19891128 THEN DO
    DEPRULE = '2.1.4.12.1 / 2.2.1.7'
    DEPNOTE = 'DEP - Not Creditable (enlistment 1 Jan 1985-28 Nov 1989)'
    RETURN
  END
  DEPRULE = '2.2.1.8.1'
  DEPNOTE = 'DEP - Not Creditable (on/after 29 Nov 1989; typed entry defaults exclude)'
  DEPACTION = 'If RT07 Career Retirement Credit Report shows IDT for this begin date before AD/ADT, change component to RES and recalculate (common for NG DEP with drills). [FMR 2.1.4.12.2.1]'
RETURN

NormWe: PROCEDURE EXPOSE WEOUT
  PARSE ARG raw
  w = TRANSLATE(STRIP(raw))
  WEOUT = 'N'
  IF w = 'Y' | w = 'YES' | w = '1' THEN WEOUT = 'Y'
RETURN

LoadOneRow: PROCEDURE EXPOSE PERIODS. ASOF NORMDATE WEOUT
  PARSE ARG fromraw, toraw, br, cp, rs, lt, we
  CALL NormDate fromraw
  f = NORMDATE
  IF f = '' THEN RETURN
  CALL NormDate toraw
  t = NORMDATE
  n = PERIODS.0 + 1
  PERIODS.0 = n
  PERIODS.n.FROM = f
  PERIODS.n.OPEN = 0
  IF t = '' THEN DO
    PERIODS.n.OPEN = 1
    t = ASOF
  END
  PERIODS.n.TO   = t
  PERIODS.n.BR   = TRANSLATE(STRIP(br))
  PERIODS.n.CP   = TRANSLATE(STRIP(cp))
  PERIODS.n.RS   = TRANSLATE(STRIP(rs))
  IF PERIODS.n.RS = '' THEN PERIODS.n.RS = 'ACT'
  lv = STRIP(lt)
  IF DATATYPE(lv,'N') THEN PERIODS.n.LT = lv + 0
  ELSE PERIODS.n.LT = 0
  CALL NormWe we
  PERIODS.n.WE = WEOUT
  PERIODS.n.CR = 'Y'
  PERIODS.n.ISLOST = 0
  PERIODS.n.DEPNOTE = ''
RETURN

LoadPeriodsFromDODF1: PROCEDURE EXPOSE PERIODS. MAP. ASOF NORMDATE WEOUT
  PERIODS.0 = 0
  CALL LoadOneRow MAP.FROM1, MAP.TO1, MAP.BR1, MAP.CP1, MAP.RS1, MAP.LT1, MAP.WE1
  CALL LoadOneRow MAP.FROM2, MAP.TO2, MAP.BR2, MAP.CP2, MAP.RS2, MAP.LT2, MAP.WE2
  CALL LoadOneRow MAP.FROM3, MAP.TO3, MAP.BR3, MAP.CP3, MAP.RS3, MAP.LT3, MAP.WE3
  CALL LoadOneRow MAP.FROM4, MAP.TO4, MAP.BR4, MAP.CP4, MAP.RS4, MAP.LT4, MAP.WE4
  CALL LoadOneRow MAP.FROM5, MAP.TO5, MAP.BR5, MAP.CP5, MAP.RS5, MAP.LT5, MAP.WE5
  CALL LoadOneRow MAP.FROM6, MAP.TO6, MAP.BR6, MAP.CP6, MAP.RS6, MAP.LT6, MAP.WE6
  CALL LoadOneRow MAP.FROM7, MAP.TO7, MAP.BR7, MAP.CP7, MAP.RS7, MAP.LT7, MAP.WE7
  CALL LoadOneRow MAP.FROM8, MAP.TO8, MAP.BR8, MAP.CP8, MAP.RS8, MAP.LT8, MAP.WE8
RETURN

ClassifyPeriods: PROCEDURE EXPOSE PERIODS. ISLOST DEPOK DEPNOTE DEPRULE DEPACTION CH1DAYS ADJ SEGDAYS
  DO i = 1 TO PERIODS.0
    PERIODS.i.CR = 'Y'
    PERIODS.i.ISLOST = 0
    PERIODS.i.DEPNOTE = ''
    CALL IsLostReason PERIODS.i.RS
    IF ISLOST = 1 THEN DO
      PERIODS.i.ISLOST = 1
      PERIODS.i.CR = 'N'
      /* PAT fills a blank LOST field from 2.4.1.3.1 when from/to exist. */
      /* A typed non-zero LOST stays as the MCTFS audit value.            */
      IF PERIODS.i.OPEN = 0 & PERIODS.i.FROM \= '' & PERIODS.i.TO \= '' THEN DO
        CALL ComputeLostDaysCh1 PERIODS.i.FROM, PERIODS.i.TO
        IF PERIODS.i.LT = 0 THEN PERIODS.i.LT = CH1DAYS
      END
      ITERATE
    END
    IF PERIODS.i.CP = 'DEP' THEN DO
      CALL EvalDep PERIODS.i.FROM
      PERIODS.i.DEPNOTE = DEPNOTE
      PERIODS.i.DEPRULE = DEPRULE
      PERIODS.i.DEPACTION = DEPACTION
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
  ELSE MAP.STATUS = 'CR=Y counts. WE=Y lost while enlisted. Number+PF5 deletes. ENTER=calc.'
  DO i = 1 TO cnt
    IF i > 10 THEN LEAVE
    showTo = PERIODS.i.TO
    IF PERIODS.i.OPEN = 1 THEN showTo = 'PRESENT'
    lineText = RIGHT(i,2)||'  '||LEFT(PERIODS.i.FROM,10)||'  '||LEFT(showTo,10)||'  '||,
               LEFT(PERIODS.i.BR,4)||' '||LEFT(PERIODS.i.CP,5)||' '||,
               LEFT(PERIODS.i.RS,6)||' '||RIGHT(PERIODS.i.LT,5)||'  '||,
               PERIODS.i.WE||' '||PERIODS.i.CR
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
    PERIODS.j.WE   = PERIODS.k.WE
    PERIODS.j.OPEN = PERIODS.k.OPEN
    PERIODS.j.CR   = PERIODS.k.CR
    PERIODS.j.ISLOST = PERIODS.k.ISLOST
    PERIODS.j.DEPNOTE = PERIODS.k.DEPNOTE
    PERIODS.j.DEPRULE = PERIODS.k.DEPRULE
    PERIODS.j.DEPACTION = PERIODS.k.DEPACTION
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
  MAP.ERRMSG = ''
  MAP.FROM1 = ''; MAP.TO1 = ''; MAP.BR1 = ''; MAP.CP1 = ''; MAP.RS1 = ''; MAP.LT1 = ''; MAP.WE1 = ''
  MAP.FROM2 = ''; MAP.TO2 = ''; MAP.BR2 = ''; MAP.CP2 = ''; MAP.RS2 = ''; MAP.LT2 = ''; MAP.WE2 = ''
  MAP.FROM3 = ''; MAP.TO3 = ''; MAP.BR3 = ''; MAP.CP3 = ''; MAP.RS3 = ''; MAP.LT3 = ''; MAP.WE3 = ''
  MAP.FROM4 = ''; MAP.TO4 = ''; MAP.BR4 = ''; MAP.CP4 = ''; MAP.RS4 = ''; MAP.LT4 = ''; MAP.WE4 = ''
  MAP.FROM5 = ''; MAP.TO5 = ''; MAP.BR5 = ''; MAP.CP5 = ''; MAP.RS5 = ''; MAP.LT5 = ''; MAP.WE5 = ''
  MAP.FROM6 = ''; MAP.TO6 = ''; MAP.BR6 = ''; MAP.CP6 = ''; MAP.RS6 = ''; MAP.LT6 = ''; MAP.WE6 = ''
  MAP.FROM7 = ''; MAP.TO7 = ''; MAP.BR7 = ''; MAP.CP7 = ''; MAP.RS7 = ''; MAP.LT7 = ''; MAP.WE7 = ''
  MAP.FROM8 = ''; MAP.TO8 = ''; MAP.BR8 = ''; MAP.CP8 = ''; MAP.RS8 = ''; MAP.LT8 = ''; MAP.WE8 = ''
  DO i = 1 TO PERIODS.0
    IF i > 8 THEN LEAVE
    showTo = PERIODS.i.TO
    IF PERIODS.i.OPEN = 1 THEN showTo = ''
    SELECT
      WHEN i = 1 THEN DO
        MAP.FROM1 = PERIODS.1.FROM; MAP.TO1 = showTo; MAP.BR1 = PERIODS.1.BR
        MAP.CP1 = PERIODS.1.CP; MAP.RS1 = PERIODS.1.RS; MAP.LT1 = PERIODS.1.LT
        MAP.WE1 = PERIODS.1.WE
      END
      WHEN i = 2 THEN DO
        MAP.FROM2 = PERIODS.2.FROM; MAP.TO2 = showTo; MAP.BR2 = PERIODS.2.BR
        MAP.CP2 = PERIODS.2.CP; MAP.RS2 = PERIODS.2.RS; MAP.LT2 = PERIODS.2.LT
        MAP.WE2 = PERIODS.2.WE
      END
      WHEN i = 3 THEN DO
        MAP.FROM3 = PERIODS.3.FROM; MAP.TO3 = showTo; MAP.BR3 = PERIODS.3.BR
        MAP.CP3 = PERIODS.3.CP; MAP.RS3 = PERIODS.3.RS; MAP.LT3 = PERIODS.3.LT
        MAP.WE3 = PERIODS.3.WE
      END
      WHEN i = 4 THEN DO
        MAP.FROM4 = PERIODS.4.FROM; MAP.TO4 = showTo; MAP.BR4 = PERIODS.4.BR
        MAP.CP4 = PERIODS.4.CP; MAP.RS4 = PERIODS.4.RS; MAP.LT4 = PERIODS.4.LT
        MAP.WE4 = PERIODS.4.WE
      END
      WHEN i = 5 THEN DO
        MAP.FROM5 = PERIODS.5.FROM; MAP.TO5 = showTo; MAP.BR5 = PERIODS.5.BR
        MAP.CP5 = PERIODS.5.CP; MAP.RS5 = PERIODS.5.RS; MAP.LT5 = PERIODS.5.LT
        MAP.WE5 = PERIODS.5.WE
      END
      WHEN i = 6 THEN DO
        MAP.FROM6 = PERIODS.6.FROM; MAP.TO6 = showTo; MAP.BR6 = PERIODS.6.BR
        MAP.CP6 = PERIODS.6.CP; MAP.RS6 = PERIODS.6.RS; MAP.LT6 = PERIODS.6.LT
        MAP.WE6 = PERIODS.6.WE
      END
      WHEN i = 7 THEN DO
        MAP.FROM7 = PERIODS.7.FROM; MAP.TO7 = showTo; MAP.BR7 = PERIODS.7.BR
        MAP.CP7 = PERIODS.7.CP; MAP.RS7 = PERIODS.7.RS; MAP.LT7 = PERIODS.7.LT
        MAP.WE7 = PERIODS.7.WE
      END
      WHEN i = 8 THEN DO
        MAP.FROM8 = PERIODS.8.FROM; MAP.TO8 = showTo; MAP.BR8 = PERIODS.8.BR
        MAP.CP8 = PERIODS.8.CP; MAP.RS8 = PERIODS.8.RS; MAP.LT8 = PERIODS.8.LT
        MAP.WE8 = PERIODS.8.WE
      END
      OTHERWISE NOP
    END
  END
RETURN

ClearEntryMap: PROCEDURE EXPOSE MAP.
  MAP.EDIPI = ''; MAP.NAME = ''; MAP.ASOF = ''; MAP.RECPEBD = ''; MAP.GRADE = 'E'
  MAP.ERRMSG = ''
  MAP.FROM1 = ''; MAP.TO1 = ''; MAP.BR1 = ''; MAP.CP1 = ''; MAP.RS1 = ''; MAP.LT1 = ''; MAP.WE1 = ''
  MAP.FROM2 = ''; MAP.TO2 = ''; MAP.BR2 = ''; MAP.CP2 = ''; MAP.RS2 = ''; MAP.LT2 = ''; MAP.WE2 = ''
  MAP.FROM3 = ''; MAP.TO3 = ''; MAP.BR3 = ''; MAP.CP3 = ''; MAP.RS3 = ''; MAP.LT3 = ''; MAP.WE3 = ''
  MAP.FROM4 = ''; MAP.TO4 = ''; MAP.BR4 = ''; MAP.CP4 = ''; MAP.RS4 = ''; MAP.LT4 = ''; MAP.WE4 = ''
  MAP.FROM5 = ''; MAP.TO5 = ''; MAP.BR5 = ''; MAP.CP5 = ''; MAP.RS5 = ''; MAP.LT5 = ''; MAP.WE5 = ''
  MAP.FROM6 = ''; MAP.TO6 = ''; MAP.BR6 = ''; MAP.CP6 = ''; MAP.RS6 = ''; MAP.LT6 = ''; MAP.WE6 = ''
  MAP.FROM7 = ''; MAP.TO7 = ''; MAP.BR7 = ''; MAP.CP7 = ''; MAP.RS7 = ''; MAP.LT7 = ''; MAP.WE7 = ''
  MAP.FROM8 = ''; MAP.TO8 = ''; MAP.BR8 = ''; MAP.CP8 = ''; MAP.RS8 = ''; MAP.LT8 = ''; MAP.WE8 = ''
RETURN

ReviewAndDeleteLoop: PROCEDURE EXPOSE PERIODS. MAP. ReviewAction ASOF EDIPI NAME RECPEBD GRADE ISLOST DEPOK DEPNOTE CH1DAYS ADJ SEGDAYS
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

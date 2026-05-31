/* DODFR -- DODFMR Statement of Service Calculator (Improved Display) */
/* Now supports PF4=Review Periods with delete before calculating */

ADDRESS CICS

/* ========== Initial Entry Screen ========== */
EXEC CICS SEND MAP('DODF1') ERASE END-EXEC

DO FOREVER
  EXEC CICS RECEIVE MAP('DODF1') END-EXEC
  IF EIBRESP \= 0 THEN DO
      EXEC CICS SEND TEXT FROM('RECEIVE failed') ERASE END-EXEC
      EXEC CICS RETURN TRANSID('MYMU') END-EXEC
  END

  AID = C2X(EIBAID)
  IF AID = 'F3' THEN EXEC CICS RETURN TRANSID('MYMU') END-EXEC

  /* === Collect header info === */
  EDIPI   = STRIP(MAP.EDIPI)
  NAME    = STRIP(MAP.NAME)
  ASOF    = STRIP(MAP.ASOF)
  RECPEBD = STRIP(MAP.RECPEBD)
  IF ASOF = '' | ASOF = '00000000' THEN ASOF = '20260524'

  /* Load periods into working stem (supports review/delete cycle) */
  CALL LoadPeriodsFromDODF1

  IF AID = 'F4' THEN DO
    /* User wants to review / delete before calculating */

    /* Load the periods from the main screen into the working stem
       (this is what makes ENTER calculate correctly). */
    CALL LoadPeriodsFromDODF1

    /* Send a clean review screen with headers + a loading message.
       The real data will be populated on the very first pass inside the review loop
       before the first RECEIVE (using the PERIODS. stem we just loaded). */
    MAP.LINE01 = ''; MAP.LINE02 = ''; MAP.LINE03 = ''; MAP.LINE04 = ''; MAP.LINE05 = ''
    MAP.LINE06 = ''; MAP.LINE07 = ''; MAP.LINE08 = ''; MAP.LINE09 = ''; MAP.LINE10 = ''
    MAP.MSG = ''
    MAP.STATUS = 'Loading periods from main screen... (press any key to display list)'
    MAP.SEL = ''
    EXEC CICS SEND MAP('DODF2') ERASE END-EXEC

    /* Enter the review loop. The loop will immediately call SendReviewMap
       (which populates from the stem) before waiting for input. */
    CALL ReviewAndDeleteLoop

    /* After review loop returns... */
    IF ReviewAction = 'CALC' THEN LEAVE
    IF ReviewAction = 'BACK' THEN ITERATE
    LEAVE

    /* (old dead code removed) */

    /* After review loop returns... */
    IF ReviewAction = 'CALC' THEN LEAVE
    IF ReviewAction = 'BACK' THEN ITERATE
    LEAVE
  END

  /* Normal ENTER on main screen - proceed to calculate */
  LEAVE
END

/* At this point we have a populated PERIODS. stem ready for calculation */

/* === Merge overlapping periods (now using PERIODS. stem) === */
MERGED.0 = 0
TOTAL_DAYS = 0
MERGED_NOTE = ''

IF PERIODS.0 > 0 THEN DO
    /* Sort by FROM date */
    DO i = 1 TO PERIODS.0-1
        DO j = i+1 TO PERIODS.0
            IF PERIODS.i.FROM > PERIODS.j.FROM THEN DO
                t = PERIODS.i.FROM; PERIODS.i.FROM = PERIODS.j.FROM; PERIODS.j.FROM = t
                t = PERIODS.i.TO;   PERIODS.i.TO   = PERIODS.j.TO;   PERIODS.j.TO   = t
            END
        END
    END

    /* Merge */
    MERGED.0 = 1
    MERGED.1.FROM = PERIODS.1.FROM
    MERGED.1.TO   = PERIODS.1.TO
    MERGED.1.MERGED = 0

    DO i = 2 TO PERIODS.0
        last = MERGED.0
        IF PERIODS.i.FROM <= MERGED.last.TO THEN DO
            IF PERIODS.i.TO > MERGED.last.TO THEN DO
                MERGED.last.TO = PERIODS.i.TO
                MERGED.last.MERGED = 1
            END
        END
        ELSE DO
            MERGED.0 = MERGED.0 + 1
            n = MERGED.0
            MERGED.n.FROM = PERIODS.i.FROM
            MERGED.n.TO   = PERIODS.i.TO
            MERGED.n.MERGED = 0
        END
    END

    /* Calculate total from merged periods */
    DO i = 1 TO MERGED.0
        FDATE = MERGED.i.FROM
        TDATE = MERGED.i.TO

        Y1 = SUBSTR(FDATE,1,4)+0; M1=SUBSTR(FDATE,5,2)+0; D1=SUBSTR(FDATE,7,2)+0
        Y2 = SUBSTR(TDATE,1,4)+0; M2=SUBSTR(TDATE,5,2)+0; D2=SUBSTR(TDATE,7,2)+0
        IF D1=31 THEN D1=30
        IF D2=31 THEN D2=30

        d = (Y2-Y1)*360 + (M2-M1)*30 + (D2-D1) + 1
        IF d < 0 THEN d = 0
        TOTAL_DAYS = TOTAL_DAYS + d
    END
END

/* === Years / Months / Days breakdown === */
YRS = TOTAL_DAYS % 360
REM = TOTAL_DAYS // 360
MOS = REM % 30
DYS = REM // 30
BREAKDOWN = YRS || ' years, ' || MOS || ' months, ' || DYS || ' days'

/* === PEBD Calculation === */
ASOF_Y = SUBSTR(ASOF,1,4)+0
ASOF_M = SUBSTR(ASOF,5,2)+0
ASOF_D = SUBSTR(ASOF,7,2)+0

PEBD_Y = ASOF_Y; PEBD_M = ASOF_M; PEBD_D = ASOF_D
DAYS_LEFT = TOTAL_DAYS

DO WHILE DAYS_LEFT > 0
    PEBD_D = PEBD_D - 1
    IF PEBD_D < 1 THEN DO
        PEBD_M = PEBD_M - 1
        IF PEBD_M < 1 THEN DO
            PEBD_M = 12
            PEBD_Y = PEBD_Y - 1
        END
        PEBD_D = 30
    END
    DAYS_LEFT = DAYS_LEFT - 1
END

CALC_PEBD = RIGHT(PEBD_Y,4,'0')||RIGHT(PEBD_M,2,'0')||RIGHT(PEBD_D,2,'0')

/* === Comparison === */
STATUS = 'Calculated only (no Record PEBD entered)'
DIFF   = ''

IF RECPEBD \= '' THEN DO
    Y1 = SUBSTR(CALC_PEBD,1,4)+0; M1=SUBSTR(CALC_PEBD,5,2)+0; D1=SUBSTR(CALC_PEBD,7,2)+0
    Y2 = SUBSTR(RECPEBD,1,4)+0; M2=SUBSTR(RECPEBD,5,2)+0; D2=SUBSTR(RECPEBD,7,2)+0
    IF D1=31 THEN D1=30
    IF D2=31 THEN D2=30
    DIFF_DAYS = (Y2-Y1)*360 + (M2-M1)*30 + (D2-D1)

    IF DIFF_DAYS = 0 THEN STATUS = 'MATCH'
    ELSE IF ABS(DIFF_DAYS) <= 7 THEN STATUS = 'CLOSE'
    ELSE STATUS = 'MISMATCH'

    IF DIFF_DAYS > 0 THEN DIFF = '+'||DIFF_DAYS||' days'
    ELSE IF DIFF_DAYS < 0 THEN DIFF = DIFF_DAYS||' days'
    ELSE DIFF = '0 days'
END

/* === Report === */
TXT = LEFT('=== DODFMR STATEMENT OF SERVICE ===', 80)
TXT = TXT || LEFT('', 80)
TXT = TXT || LEFT('EDIPI : ' || EDIPI, 80)
TXT = TXT || LEFT('NAME  : ' || NAME, 80)
TXT = TXT || LEFT('As of Date            : ' || ASOF, 80)
TXT = TXT || LEFT('Total Creditable Days : ' || TOTAL_DAYS || '  (' || BREAKDOWN || ')', 80)
TXT = TXT || LEFT('', 80)
TXT = TXT || LEFT('--- PEBD COMPARISON ---', 80)
TXT = TXT || LEFT('Calculated PEBD   : ' || CALC_PEBD, 80)
TXT = TXT || LEFT('Record PEBD       : ' || RECPEBD, 80)
TXT = TXT || LEFT('Difference        : ' || DIFF, 80)
TXT = TXT || LEFT('Status            : ' || STATUS, 80)
TXT = TXT || LEFT(COPIES('-', 70), 80)

IF MERGED.0 > 0 THEN DO
    TXT = TXT || LEFT('Service Periods Counted (after merging):', 80)
    DO i = 1 TO MERGED.0
        note = ''
        IF MERGED.i.MERGED = 1 THEN note = '  * (overlapped - merged)'
        TXT = TXT || LEFT(RIGHT(i,2)||'. ' || MERGED.i.FROM || ' -> ' || MERGED.i.TO || note, 80)
    END
    IF MERGED_NOTE \= '' THEN TXT = TXT || LEFT(MERGED_NOTE, 80)
END

TXT = TXT || LEFT('', 80)
TXT = TXT || LEFT('Press ENTER to continue or PF3 to exit.', 80)

EXEC CICS SEND TEXT FROM(TXT) ERASE END-EXEC
EXEC CICS RETURN TRANSID('MYMU') END-EXEC


/* ====================================================================== */
/*                        NEW HELPER ROUTINES                             */
/* ====================================================================== */

/* Load the 8 period fields from DODF1 into the working PERIODS. stem */
LoadPeriodsFromDODF1: PROCEDURE EXPOSE PERIODS. MAP. ASOF
  PERIODS.0 = 0

  /* Explicit per-row to avoid dynamic VALUE issues in this REXX dialect */
  IF STRIP(MAP.FROM1) \= '' THEN DO
    n = 1; PERIODS.0 = 1
    PERIODS.1.FROM = STRIP(MAP.FROM1)
    PERIODS.1.TO   = STRIP(MAP.TO1); IF PERIODS.1.TO = '' | PERIODS.1.TO = '00000000' THEN PERIODS.1.TO = ASOF
    PERIODS.1.BR   = STRIP(MAP.BR1)
    PERIODS.1.CP   = STRIP(MAP.CP1)
    PERIODS.1.RS   = STRIP(MAP.RS1)
    PERIODS.1.LT   = STRIP(MAP.LT1)
  END
  IF STRIP(MAP.FROM2) \= '' THEN DO
    n = PERIODS.0 + 1; PERIODS.0 = n
    PERIODS.n.FROM = STRIP(MAP.FROM2)
    PERIODS.n.TO   = STRIP(MAP.TO2); IF PERIODS.n.TO = '' | PERIODS.n.TO = '00000000' THEN PERIODS.n.TO = ASOF
    PERIODS.n.BR   = STRIP(MAP.BR2)
    PERIODS.n.CP   = STRIP(MAP.CP2)
    PERIODS.n.RS   = STRIP(MAP.RS2)
    PERIODS.n.LT   = STRIP(MAP.LT2)
  END
  IF STRIP(MAP.FROM3) \= '' THEN DO
    n = PERIODS.0 + 1; PERIODS.0 = n
    PERIODS.n.FROM = STRIP(MAP.FROM3)
    PERIODS.n.TO   = STRIP(MAP.TO3); IF PERIODS.n.TO = '' | PERIODS.n.TO = '00000000' THEN PERIODS.n.TO = ASOF
    PERIODS.n.BR   = STRIP(MAP.BR3)
    PERIODS.n.CP   = STRIP(MAP.CP3)
    PERIODS.n.RS   = STRIP(MAP.RS3)
    PERIODS.n.LT   = STRIP(MAP.LT3)
  END
  IF STRIP(MAP.FROM4) \= '' THEN DO
    n = PERIODS.0 + 1; PERIODS.0 = n
    PERIODS.n.FROM = STRIP(MAP.FROM4)
    PERIODS.n.TO   = STRIP(MAP.TO4); IF PERIODS.n.TO = '' | PERIODS.n.TO = '00000000' THEN PERIODS.n.TO = ASOF
    PERIODS.n.BR   = STRIP(MAP.BR4)
    PERIODS.n.CP   = STRIP(MAP.CP4)
    PERIODS.n.RS   = STRIP(MAP.RS4)
    PERIODS.n.LT   = STRIP(MAP.LT4)
  END
  IF STRIP(MAP.FROM5) \= '' THEN DO
    n = PERIODS.0 + 1; PERIODS.0 = n
    PERIODS.n.FROM = STRIP(MAP.FROM5)
    PERIODS.n.TO   = STRIP(MAP.TO5); IF PERIODS.n.TO = '' | PERIODS.n.TO = '00000000' THEN PERIODS.n.TO = ASOF
    PERIODS.n.BR   = STRIP(MAP.BR5)
    PERIODS.n.CP   = STRIP(MAP.CP5)
    PERIODS.n.RS   = STRIP(MAP.RS5)
    PERIODS.n.LT   = STRIP(MAP.LT5)
  END
  IF STRIP(MAP.FROM6) \= '' THEN DO
    n = PERIODS.0 + 1; PERIODS.0 = n
    PERIODS.n.FROM = STRIP(MAP.FROM6)
    PERIODS.n.TO   = STRIP(MAP.TO6); IF PERIODS.n.TO = '' | PERIODS.n.TO = '00000000' THEN PERIODS.n.TO = ASOF
    PERIODS.n.BR   = STRIP(MAP.BR6)
    PERIODS.n.CP   = STRIP(MAP.CP6)
    PERIODS.n.RS   = STRIP(MAP.RS6)
    PERIODS.n.LT   = STRIP(MAP.LT6)
  END
  IF STRIP(MAP.FROM7) \= '' THEN DO
    n = PERIODS.0 + 1; PERIODS.0 = n
    PERIODS.n.FROM = STRIP(MAP.FROM7)
    PERIODS.n.TO   = STRIP(MAP.TO7); IF PERIODS.n.TO = '' | PERIODS.n.TO = '00000000' THEN PERIODS.n.TO = ASOF
    PERIODS.n.BR   = STRIP(MAP.BR7)
    PERIODS.n.CP   = STRIP(MAP.CP7)
    PERIODS.n.RS   = STRIP(MAP.RS7)
    PERIODS.n.LT   = STRIP(MAP.LT7)
  END
  IF STRIP(MAP.FROM8) \= '' THEN DO
    n = PERIODS.0 + 1; PERIODS.0 = n
    PERIODS.n.FROM = STRIP(MAP.FROM8)
    PERIODS.n.TO   = STRIP(MAP.TO8); IF PERIODS.n.TO = '' | PERIODS.n.TO = '00000000' THEN PERIODS.n.TO = ASOF
    PERIODS.n.BR   = STRIP(MAP.BR8)
    PERIODS.n.CP   = STRIP(MAP.CP8)
    PERIODS.n.RS   = STRIP(MAP.RS8)
    PERIODS.n.LT   = STRIP(MAP.LT8)
  END
RETURN

/* ---------------------------------------------------------------------- */
/* Review / Delete loop - stays on DODF2 until user chooses to calculate  */
/* or go back. Supports the "see all lines + delete + stay on screen" UX  */
/* ---------------------------------------------------------------------- */
ReviewAndDeleteLoop: PROCEDURE EXPOSE PERIODS. MAP. ReviewAction ASOF EDIPI NAME RECPEBD
  ReviewAction = ''

  DO FOREVER
    /* Screen is already sent by the caller (F4 path) or after delete/refresh */
    EXEC CICS RECEIVE MAP('DODF2') END-EXEC
    IF EIBRESP \= 0 THEN DO
      ReviewAction = 'CALC'
      RETURN
    END

    rAID = C2X(EIBAID)

    IF rAID = 'F3' THEN DO
      /* Go back to entry screen, pre-filling what is left */
      CALL PrefillDODF1FromPeriods
      EXEC CICS SEND MAP('DODF1') ERASE END-EXEC
      ReviewAction = 'BACK'
      RETURN
    END

    IF rAID = 'F5' THEN DO
      /* Delete the selected line number */
      sel = STRIP(MAP.SEL)
      IF sel \= '' THEN DO
        CALL DeletePeriodByNumber(sel)
      END
      /* Re-display the updated list from the current stem */
      CALL SendReviewMap
      ITERATE
    END

    /* ENTER or PF6 = Calculate with current (possibly reduced) list */
    IF rAID = '7D' | rAID = 'F6' | rAID = '7E' THEN DO
      ReviewAction = 'CALC'
      RETURN
    END

    /* PF9 = Clear everything and go back to clean entry screen */
    IF rAID = 'F9' THEN DO
      PERIODS.0 = 0
      CALL PrefillDODF1FromPeriods
      EXEC CICS SEND MAP('DODF1') ERASE END-EXEC
      ReviewAction = 'BACK'
      RETURN
    END
  END
RETURN

/* Send the DODF2 review map populated from current PERIODS. stem */
SendReviewMap: PROCEDURE EXPOSE PERIODS. MAP.
  MAP.LINE01 = ''; MAP.LINE02 = ''; MAP.LINE03 = ''; MAP.LINE04 = ''; MAP.LINE05 = ''
  MAP.LINE06 = ''; MAP.LINE07 = ''; MAP.LINE08 = ''; MAP.LINE09 = ''; MAP.LINE10 = ''

  cnt = PERIODS.0
  MAP.MSG = ''
  MAP.STATUS = ''

  IF cnt = 0 THEN
    MAP.MSG = 'No periods entered yet. Go back (PF3) and add some on the main screen.'
  ELSE
    MAP.STATUS = 'Showing' cnt 'period(s).  Enter number + PF5 to delete.  ENTER or PF6 to calculate.'

  DO i = 1 TO cnt
    IF i > 10 THEN LEAVE

    lineText = RIGHT(i,2) || '  ' ||,
               LEFT(PERIODS.i.FROM,10) || '  ' || LEFT(PERIODS.i.TO,10) || '  ' ||,
               LEFT(PERIODS.i.BR,2) || '  ' || LEFT(PERIODS.i.CP,2) || '  ' ||,
               LEFT(PERIODS.i.RS,6) || '  ' || LEFT(PERIODS.i.LT,5)

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

/* Delete one period by the number the user typed */
DeletePeriodByNumber: PROCEDURE EXPOSE PERIODS. MAP.
  PARSE ARG num
  num = num + 0
  IF num < 1 | num > PERIODS.0 THEN DO
    MAP.MSG = 'Invalid selection - enter a number between 1 and' PERIODS.0
    RETURN
  END

  /* Shift remaining entries up */
  DO j = num TO PERIODS.0 - 1
    k = j + 1
    PERIODS.j.FROM = PERIODS.k.FROM
    PERIODS.j.TO   = PERIODS.k.TO
    PERIODS.j.BR   = PERIODS.k.BR
    PERIODS.j.CP   = PERIODS.k.CP
    PERIODS.j.RS   = PERIODS.k.RS
    PERIODS.j.LT   = PERIODS.k.LT
  END
  PERIODS.0 = PERIODS.0 - 1

  MAP.MSG = 'Period' num 'deleted. List refreshed.'
RETURN

/* Pre-fill the DODF1 entry fields from the current PERIODS. stem */
PrefillDODF1FromPeriods: PROCEDURE EXPOSE PERIODS. MAP.
  /* Clear all period fields first (rows 1-8) */
  MAP.FROM1 = ''; MAP.TO1 = ''; MAP.BR1 = ''; MAP.CP1 = ''; MAP.RS1 = ''; MAP.LT1 = ''
  MAP.FROM2 = ''; MAP.TO2 = ''; MAP.BR2 = ''; MAP.CP2 = ''; MAP.RS2 = ''; MAP.LT2 = ''
  MAP.FROM3 = ''; MAP.TO3 = ''; MAP.BR3 = ''; MAP.CP3 = ''; MAP.RS3 = ''; MAP.LT3 = ''
  MAP.FROM4 = ''; MAP.TO4 = ''; MAP.BR4 = ''; MAP.CP4 = ''; MAP.RS4 = ''; MAP.LT4 = ''
  MAP.FROM5 = ''; MAP.TO5 = ''; MAP.BR5 = ''; MAP.CP5 = ''; MAP.RS5 = ''; MAP.LT5 = ''
  MAP.FROM6 = ''; MAP.TO6 = ''; MAP.BR6 = ''; MAP.CP6 = ''; MAP.RS6 = ''; MAP.LT6 = ''
  MAP.FROM7 = ''; MAP.TO7 = ''; MAP.BR7 = ''; MAP.CP7 = ''; MAP.RS7 = ''; MAP.LT7 = ''
  MAP.FROM8 = ''; MAP.TO8 = ''; MAP.BR8 = ''; MAP.CP8 = ''; MAP.RS8 = ''; MAP.LT8 = ''

  /* Populate from the working PERIODS. stem */
  DO i = 1 TO PERIODS.0
    IF i > 8 THEN LEAVE

    SELECT
      WHEN i = 1 THEN DO
        MAP.FROM1 = PERIODS.1.FROM; MAP.TO1 = PERIODS.1.TO; MAP.BR1 = PERIODS.1.BR
        MAP.CP1 = PERIODS.1.CP;   MAP.RS1 = PERIODS.1.RS; MAP.LT1 = PERIODS.1.LT
      END
      WHEN i = 2 THEN DO
        MAP.FROM2 = PERIODS.2.FROM; MAP.TO2 = PERIODS.2.TO; MAP.BR2 = PERIODS.2.BR
        MAP.CP2 = PERIODS.2.CP;   MAP.RS2 = PERIODS.2.RS; MAP.LT2 = PERIODS.2.LT
      END
      WHEN i = 3 THEN DO
        MAP.FROM3 = PERIODS.3.FROM; MAP.TO3 = PERIODS.3.TO; MAP.BR3 = PERIODS.3.BR
        MAP.CP3 = PERIODS.3.CP;   MAP.RS3 = PERIODS.3.RS; MAP.LT3 = PERIODS.3.LT
      END
      WHEN i = 4 THEN DO
        MAP.FROM4 = PERIODS.4.FROM; MAP.TO4 = PERIODS.4.TO; MAP.BR4 = PERIODS.4.BR
        MAP.CP4 = PERIODS.4.CP;   MAP.RS4 = PERIODS.4.RS; MAP.LT4 = PERIODS.4.LT
      END
      WHEN i = 5 THEN DO
        MAP.FROM5 = PERIODS.5.FROM; MAP.TO5 = PERIODS.5.TO; MAP.BR5 = PERIODS.5.BR
        MAP.CP5 = PERIODS.5.CP;   MAP.RS5 = PERIODS.5.RS; MAP.LT5 = PERIODS.5.LT
      END
      WHEN i = 6 THEN DO
        MAP.FROM6 = PERIODS.6.FROM; MAP.TO6 = PERIODS.6.TO; MAP.BR6 = PERIODS.6.BR
        MAP.CP6 = PERIODS.6.CP;   MAP.RS6 = PERIODS.6.RS; MAP.LT6 = PERIODS.6.LT
      END
      WHEN i = 7 THEN DO
        MAP.FROM7 = PERIODS.7.FROM; MAP.TO7 = PERIODS.7.TO; MAP.BR7 = PERIODS.7.BR
        MAP.CP7 = PERIODS.7.CP;   MAP.RS7 = PERIODS.7.RS; MAP.LT7 = PERIODS.7.LT
      END
      WHEN i = 8 THEN DO
        MAP.FROM8 = PERIODS.8.FROM; MAP.TO8 = PERIODS.8.TO; MAP.BR8 = PERIODS.8.BR
        MAP.CP8 = PERIODS.8.CP;   MAP.RS8 = PERIODS.8.RS; MAP.LT8 = PERIODS.8.LT
      END
      OTHERWISE NOP
    END
  END
RETURN
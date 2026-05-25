/* DODFR -- DODFMR Statement of Service Calculator (Improved Display) */

ADDRESS CICS

EXEC CICS SEND MAP('DODF1') ERASE END-EXEC
EXEC CICS RECEIVE MAP('DODF1') END-EXEC

IF EIBRESP \= 0 THEN DO
    EXEC CICS SEND TEXT FROM('RECEIVE failed') ERASE END-EXEC
    EXEC CICS RETURN TRANSID('MYMU') END-EXEC
END

IF C2X(EIBAID) = 'F3' THEN EXEC CICS RETURN TRANSID('MYMU') END-EXEC

/* === Collect input === */
EDIPI   = STRIP(MAP.EDIPI)
NAME    = STRIP(MAP.NAME)
ASOF    = STRIP(MAP.ASOF)
RECPEBD = STRIP(MAP.RECPEBD)

IF ASOF = '' | ASOF = '00000000' THEN ASOF = '20260524'

/* Store original periods */
NUM_ORIG = 0
DO i = 1 TO 8
    FROM = STRIP(VALUE('MAP.FROM' || i))
    IF FROM = '' THEN ITERATE
    TO = STRIP(VALUE('MAP.TO' || i))
    IF TO = '' | TO = '00000000' THEN TO = ASOF

    NUM_ORIG = NUM_ORIG + 1
    ORIG_FROM.NUM_ORIG = FROM
    ORIG_TO.NUM_ORIG   = TO
END

/* === Merge overlapping periods === */
MERGED.0 = 0
TOTAL_DAYS = 0
MERGED_NOTE = ''

IF NUM_ORIG > 0 THEN DO
    /* Sort by FROM date */
    DO i = 1 TO NUM_ORIG-1
        DO j = i+1 TO NUM_ORIG
            IF ORIG_FROM.i > ORIG_FROM.j THEN DO
                t = ORIG_FROM.i; ORIG_FROM.i = ORIG_FROM.j; ORIG_FROM.j = t
                t = ORIG_TO.i;   ORIG_TO.i   = ORIG_TO.j;   ORIG_TO.j   = t
            END
        END
    END

    /* Merge */
    MERGED.0 = 1
    MERGED.1.FROM = ORIG_FROM.1
    MERGED.1.TO   = ORIG_TO.1
    MERGED.1.MERGED = 0

    DO i = 2 TO NUM_ORIG
        last = MERGED.0
        IF ORIG_FROM.i <= MERGED.last.TO THEN DO
            IF ORIG_TO.i > MERGED.last.TO THEN DO
                MERGED.last.TO = ORIG_TO.i
                MERGED.last.MERGED = 1
            END
        END
        ELSE DO
            MERGED.0 = MERGED.0 + 1
            n = MERGED.0
            MERGED.n.FROM = ORIG_FROM.i
            MERGED.n.TO   = ORIG_TO.i
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
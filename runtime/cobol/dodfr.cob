      *> DODC -- COBOL twin of DODF (dodfr.rexx). PAT / DoD FMR Vol 7A
      *> Ch 1 PEBD: 30/360, inclusive +1, DEP 2.1.4.12, lost 2.4.1.3.1,
      *> officer 2.2.2, PEBD retard 2.4.1.4. Same DODF1/DODF2 maps.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DODFR.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY DFHAID.
       COPY DFHRESP.

       01 TY         PIC 9(4).
       01 TM         PIC 9(2).
       01 TD         PIC 9(2).
       01 TODAY-N    PIC 9(8).

       01 SCR.
          05 EDIPI    PIC X(10).
          05 NAME     PIC X(30).
          05 ASOF     PIC X(8).
          05 GRADE    PIC X(1).
          05 RECPEBD  PIC X(8).
          05 FROM1    PIC X(10).
          05 TO1      PIC X(10).
          05 BR1      PIC X(4).
          05 CP1      PIC X(5).
          05 RS1      PIC X(6).
          05 LT1      PIC X(10).
          05 FROM2    PIC X(10).
          05 TO2      PIC X(10).
          05 BR2      PIC X(4).
          05 CP2      PIC X(5).
          05 RS2      PIC X(6).
          05 LT2      PIC X(10).
          05 FROM3    PIC X(10).
          05 TO3      PIC X(10).
          05 BR3      PIC X(4).
          05 CP3      PIC X(5).
          05 RS3      PIC X(6).
          05 LT3      PIC X(10).
          05 FROM4    PIC X(10).
          05 TO4      PIC X(10).
          05 BR4      PIC X(4).
          05 CP4      PIC X(5).
          05 RS4      PIC X(6).
          05 LT4      PIC X(10).
          05 FROM5    PIC X(10).
          05 TO5      PIC X(10).
          05 BR5      PIC X(4).
          05 CP5      PIC X(5).
          05 RS5      PIC X(6).
          05 LT5      PIC X(10).
          05 FROM6    PIC X(10).
          05 TO6      PIC X(10).
          05 BR6      PIC X(4).
          05 CP6      PIC X(5).
          05 RS6      PIC X(6).
          05 LT6      PIC X(10).
          05 FROM7    PIC X(10).
          05 TO7      PIC X(10).
          05 BR7      PIC X(4).
          05 CP7      PIC X(5).
          05 RS7      PIC X(6).
          05 LT7      PIC X(10).
          05 FROM8    PIC X(10).
          05 TO8      PIC X(10).
          05 BR8      PIC X(4).
          05 CP8      PIC X(5).
          05 RS8      PIC X(6).
          05 LT8      PIC X(10).
          05 ERRMSG   PIC X(70).

       01 REV.
          05 LINE01   PIC X(78).
          05 LINE02   PIC X(78).
          05 LINE03   PIC X(78).
          05 LINE04   PIC X(78).
          05 LINE05   PIC X(78).
          05 LINE06   PIC X(78).
          05 LINE07   PIC X(78).
          05 LINE08   PIC X(78).
          05 LINE09   PIC X(78).
          05 LINE10   PIC X(78).
          05 MSG      PIC X(78).
          05 SEL      PIC X(3).
          05 STATUS   PIC X(78).

       01 PERIODS.
          05 P-FROM    OCCURS 8 TIMES PIC 9(8).
          05 P-TO      OCCURS 8 TIMES PIC 9(8).
          05 P-BR      OCCURS 8 TIMES PIC X(4).
          05 P-CP      OCCURS 8 TIMES PIC X(5).
          05 P-RS      OCCURS 8 TIMES PIC X(6).
          05 P-LT      OCCURS 8 TIMES PIC 9(5).
          05 P-CR      OCCURS 8 TIMES PIC X(1).
          05 P-ISLOST  OCCURS 8 TIMES PIC X(1).
          05 P-DEPNOTE OCCURS 8 TIMES PIC X(60).

       01 MERGED.
          05 M-FROM    OCCURS 8 TIMES PIC 9(8).
          05 M-TO      OCCURS 8 TIMES PIC 9(8).
          05 M-DAYS    OCCURS 8 TIMES PIC 9(7).

       01 LOSTA.
          05 L-FROM    OCCURS 8 TIMES PIC 9(8).
          05 L-TO      OCCURS 8 TIMES PIC 9(8).
          05 L-RS      OCCURS 8 TIMES PIC X(6).
          05 L-DAYS    OCCURS 8 TIMES PIC 9(7).
          05 L-METH    OCCURS 8 TIMES PIC X(24).

       01 NPER       PIC 9(2) VALUE 0.
       01 NIN        PIC 9(2) VALUE 0.
       01 NMERGE     PIC 9(2) VALUE 0.
       01 NLOST      PIC 9(2) VALUE 0.
       01 I          PIC 9(2).
       01 J          PIC 9(2).
       01 K          PIC 9(2).
       01 LASTN      PIC 9(2).
       01 SELN       PIC 9(2).
       01 OFFICER    PIC 9(1) VALUE 0.
       01 ASOF-N     PIC 9(8).
       01 REC-N      PIC 9(8).
       01 LOSTTOTAL  PIC S9(7) VALUE 0.
       01 GROSSDAYS  PIC S9(7) VALUE 0.
       01 NETDAYS    PIC S9(7) VALUE 0.
       01 YRS        PIC 9(4).
       01 MOS        PIC 9(2).
       01 DYS        PIC 9(2).
       01 REM        PIC S9(7).
       01 PEBDBASE   PIC 9(8).
       01 CALCPEBD   PIC 9(8).
       01 TARGET     PIC S9(7).
       01 GY         PIC 9(4).
       01 GM         PIC 9(2).
       01 GD         PIC 9(2).
       01 GR         PIC S9(7).
       01 BEST       PIC 9(8).
       01 CAND       PIC 9(8).
       01 BESTERR    PIC 9(7).
       01 ERR        PIC S9(7).
       01 DELTA      PIC S9(3).
       01 AD         PIC 9(7).
       01 DIFFDAYS   PIC S9(7).
       01 J1         PIC S9(8).
       01 J2         PIC S9(8).
       01 TMP8       PIC 9(8).
       01 TMPX       PIC X(8).
       01 GRADE-U    PIC X(1).
       01 RS-U       PIC X(6).
       01 CP-U       PIC X(5).
       01 ISLOST     PIC 9(1).
       01 DEPOK      PIC 9(1).
       01 DONE-FLAG  PIC X(1) VALUE 'N'.
       01 WS-OK      PIC X(1) VALUE 'Y'.
       01 CHECKYMD   PIC 9(1) VALUE 0.
       01 CHK-DATE   PIC 9(8) VALUE 0.
       01 RSVALID    PIC 9(1) VALUE 0.
       01 ROW-N      PIC 9(1).
       01 WS-FROMX   PIC X(10).
       01 WS-TOX     PIC X(10).
       01 WS-BRX     PIC X(4).
       01 WS-CPX     PIC X(5).
       01 WS-RSX     PIC X(6).
       01 WS-LTX     PIC X(10).
       01 WS-TRIM    PIC X(10).
       01 ROW-HAS    PIC X(1).
       01 REV-ACT    PIC X(4).
       01 EXIT-FLAG  PIC X(1) VALUE 'N'.

       01 WS-D1      PIC 9(8).
       01 WS-D2      PIC 9(8).
       01 WS-DATE    PIC 9(8).
       01 WS-OUT     PIC 9(8).
       01 WS-GUESS   PIC 9(8).
       01 WS-Y       PIC S9(4).
       01 WS-M       PIC S9(4).
       01 WS-D       PIC S9(4).
       01 YS         PIC S9(4).
       01 MS         PIC S9(4).
       01 DS         PIC S9(4).
       01 YE         PIC S9(4).
       01 ME         PIC S9(4).
       01 DE         PIC S9(4).
       01 WS-DIM     PIC 9(2).
       01 WS-DELTA   PIC S9(7).
       01 WS-DAYS    PIC S9(7).
       01 WS-EXTRA   PIC 9(2).
       01 TDAYS      PIC S9(7).
       01 TMONTHS    PIC S9(7).
       01 TYEARS     PIC S9(7).
       01 JA         PIC S9(8).
       01 JYY        PIC S9(8).
       01 JMM        PIC S9(8).
       01 LY         PIC 9(4).
       01 LM         PIC 9(2).
       01 LD         PIC 9(2).
       01 LR         PIC S9(7).

       01 WS-LINE    PIC X(80).
       01 RCOUNT     PIC 9(2).
       01 STATUS-TXT PIC X(40).
       01 DIFF-TXT   PIC X(16).
       01 CLASS-TXT  PIC X(16).
       01 BREAK-TXT  PIC X(40).
       01 NET-YMD    PIC X(16).
       01 LOST-YMD   PIC X(16).
       01 YMD-Y      PIC ZZ9.
       01 YMD-M      PIC Z9.
       01 YMD-D      PIC Z9.
       01 NPER-X     PIC Z9.
       01 DAYS-X     PIC Z(6)9.
       01 LT-X       PIC Z(4)9.

       01 REPORT.
          05 R-LINE OCCURS 40 TIMES PIC X(80).

       PROCEDURE DIVISION.
       MAIN.
           EXEC CICS ASSIGN TODAYYR(TY) TODAYMO(TM) TODAYDY(TD)
                     END-EXEC.
           COMPUTE TODAY-N = TY * 10000 + TM * 100 + TD.

           MOVE SPACES TO SCR.
           MOVE 'E' TO GRADE.
           MOVE 'N' TO EXIT-FLAG.
           PERFORM SESSION-LOOP UNTIL EXIT-FLAG = 'Y'.
           STOP RUN.

       SESSION-LOOP.
           MOVE 'N' TO DONE-FLAG.
           PERFORM ENTRY-LOOP UNTIL DONE-FLAG = 'Y'.
           PERFORM CALCULATE-ALL.
           PERFORM PAINT-REPORT.
           EXEC CICS RECEIVE INTO(WS-LINE) END-EXEC.
           EVALUATE EIBAID
               WHEN ENTER
               WHEN PF12
                   PERFORM PREFILL-ENTRY
               WHEN OTHER
                   EXEC CICS RETURN TRANSID('MYMU') END-EXEC
                   STOP RUN
           END-EVALUATE.

       ENTRY-LOOP.
           EXEC CICS SEND MAP('DODF1') FROM(SCR) ERASE END-EXEC.
           EXEC CICS RECEIVE MAP('DODF1') INTO(SCR) END-EXEC.

           EVALUATE EIBAID
               WHEN PF03
                   EXEC CICS RETURN TRANSID('MYMU') END-EXEC
                   STOP RUN
               WHEN PF09
                   MOVE SPACES TO SCR
                   MOVE 'E' TO GRADE
               WHEN PF04
                   PERFORM VALIDATE-ENTRY
                   IF WS-OK = 'Y' THEN
                       PERFORM LOAD-PERIODS
                       PERFORM CLASSIFY-PERIODS
                       PERFORM REVIEW-FLOW
                   END-IF
               WHEN OTHER
                   PERFORM VALIDATE-ENTRY
                   IF WS-OK = 'Y' THEN
                       PERFORM LOAD-PERIODS
                       PERFORM CLASSIFY-PERIODS
                       MOVE 'Y' TO DONE-FLAG
                   END-IF
           END-EVALUATE.

       REVIEW-FLOW.
           MOVE 'LOOP' TO REV-ACT.
           PERFORM SEND-REVIEW.
           PERFORM REVIEW-ONCE UNTIL REV-ACT = 'CALC' OR REV-ACT = 'BACK'.
           IF REV-ACT = 'CALC' THEN
               PERFORM CLASSIFY-PERIODS
               MOVE 'Y' TO DONE-FLAG
           END-IF.

       REVIEW-ONCE.
           EXEC CICS RECEIVE MAP('DODF2') INTO(REV) END-EXEC.
           EVALUATE EIBAID
               WHEN PF03
                   PERFORM PREFILL-ENTRY
                   MOVE 'BACK' TO REV-ACT
               WHEN PF09
                   MOVE 0 TO NPER
                   PERFORM PREFILL-ENTRY
                   MOVE 'BACK' TO REV-ACT
               WHEN PF05
                   MOVE FUNCTION NUMVAL(SEL) TO SELN
                   PERFORM DELETE-PERIOD
                   PERFORM CLASSIFY-PERIODS
                   PERFORM SEND-REVIEW
               WHEN PF06
                   MOVE 'CALC' TO REV-ACT
               WHEN ENTER
                   MOVE 'CALC' TO REV-ACT
               WHEN OTHER
                   PERFORM SEND-REVIEW
           END-EVALUATE.

       LOAD-PERIODS.
           MOVE FUNCTION NUMVAL(ASOF) TO ASOF-N.
           IF ASOF-N = 0 THEN
               MOVE TODAY-N TO ASOF-N
           END-IF.
           MOVE 0 TO NPER.
           PERFORM LOAD-ROW-1.
           PERFORM LOAD-ROW-2.
           PERFORM LOAD-ROW-3.
           PERFORM LOAD-ROW-4.
           PERFORM LOAD-ROW-5.
           PERFORM LOAD-ROW-6.
           PERFORM LOAD-ROW-7.
           PERFORM LOAD-ROW-8.
           MOVE FUNCTION NUMVAL(RECPEBD) TO REC-N.
           MOVE FUNCTION UPPER-CASE(GRADE) TO GRADE-U.
           MOVE 0 TO OFFICER.
           IF GRADE-U = 'O' OR GRADE-U = 'W' THEN
               MOVE 1 TO OFFICER
           END-IF.
           IF GRADE-U = SPACES THEN
               MOVE 'E' TO GRADE-U
           END-IF.

       TAKE-ROW.
           ADD 1 TO NPER.
           MOVE NPER TO I.
           MOVE WS-D1 TO P-FROM(I).
           IF WS-D2 = 0 THEN
               MOVE ASOF-N TO WS-D2
           END-IF.
           IF WS-D2 = 0 THEN
               MOVE TODAY-N TO WS-D2
           END-IF.
           MOVE WS-D2 TO P-TO(I).
           MOVE FUNCTION UPPER-CASE(P-BR(I)) TO P-BR(I).
           MOVE FUNCTION UPPER-CASE(P-CP(I)) TO P-CP(I).
           MOVE FUNCTION UPPER-CASE(P-RS(I)) TO P-RS(I).
           IF P-RS(I) = SPACES THEN
               MOVE 'ACT' TO P-RS(I)
           END-IF.
           MOVE 'Y' TO P-CR(I).
           MOVE 'N' TO P-ISLOST(I).
           MOVE SPACES TO P-DEPNOTE(I).

       LOAD-ROW-1.
           MOVE FUNCTION NUMVAL(FROM1) TO WS-D1.
           MOVE FUNCTION NUMVAL(TO1) TO WS-D2.
           IF WS-D1 NOT = 0 THEN
               MOVE BR1 TO P-BR(NPER + 1)
               MOVE CP1 TO P-CP(NPER + 1)
               MOVE RS1 TO P-RS(NPER + 1)
               MOVE FUNCTION NUMVAL(LT1) TO P-LT(NPER + 1)
               PERFORM TAKE-ROW
           END-IF.
       LOAD-ROW-2.
           MOVE FUNCTION NUMVAL(FROM2) TO WS-D1.
           MOVE FUNCTION NUMVAL(TO2) TO WS-D2.
           IF WS-D1 NOT = 0 THEN
               MOVE BR2 TO P-BR(NPER + 1)
               MOVE CP2 TO P-CP(NPER + 1)
               MOVE RS2 TO P-RS(NPER + 1)
               MOVE FUNCTION NUMVAL(LT2) TO P-LT(NPER + 1)
               PERFORM TAKE-ROW
           END-IF.
       LOAD-ROW-3.
           MOVE FUNCTION NUMVAL(FROM3) TO WS-D1.
           MOVE FUNCTION NUMVAL(TO3) TO WS-D2.
           IF WS-D1 NOT = 0 THEN
               MOVE BR3 TO P-BR(NPER + 1)
               MOVE CP3 TO P-CP(NPER + 1)
               MOVE RS3 TO P-RS(NPER + 1)
               MOVE FUNCTION NUMVAL(LT3) TO P-LT(NPER + 1)
               PERFORM TAKE-ROW
           END-IF.
       LOAD-ROW-4.
           MOVE FUNCTION NUMVAL(FROM4) TO WS-D1.
           MOVE FUNCTION NUMVAL(TO4) TO WS-D2.
           IF WS-D1 NOT = 0 THEN
               MOVE BR4 TO P-BR(NPER + 1)
               MOVE CP4 TO P-CP(NPER + 1)
               MOVE RS4 TO P-RS(NPER + 1)
               MOVE FUNCTION NUMVAL(LT4) TO P-LT(NPER + 1)
               PERFORM TAKE-ROW
           END-IF.
       LOAD-ROW-5.
           MOVE FUNCTION NUMVAL(FROM5) TO WS-D1.
           MOVE FUNCTION NUMVAL(TO5) TO WS-D2.
           IF WS-D1 NOT = 0 THEN
               MOVE BR5 TO P-BR(NPER + 1)
               MOVE CP5 TO P-CP(NPER + 1)
               MOVE RS5 TO P-RS(NPER + 1)
               MOVE FUNCTION NUMVAL(LT5) TO P-LT(NPER + 1)
               PERFORM TAKE-ROW
           END-IF.
       LOAD-ROW-6.
           MOVE FUNCTION NUMVAL(FROM6) TO WS-D1.
           MOVE FUNCTION NUMVAL(TO6) TO WS-D2.
           IF WS-D1 NOT = 0 THEN
               MOVE BR6 TO P-BR(NPER + 1)
               MOVE CP6 TO P-CP(NPER + 1)
               MOVE RS6 TO P-RS(NPER + 1)
               MOVE FUNCTION NUMVAL(LT6) TO P-LT(NPER + 1)
               PERFORM TAKE-ROW
           END-IF.
       LOAD-ROW-7.
           MOVE FUNCTION NUMVAL(FROM7) TO WS-D1.
           MOVE FUNCTION NUMVAL(TO7) TO WS-D2.
           IF WS-D1 NOT = 0 THEN
               MOVE BR7 TO P-BR(NPER + 1)
               MOVE CP7 TO P-CP(NPER + 1)
               MOVE RS7 TO P-RS(NPER + 1)
               MOVE FUNCTION NUMVAL(LT7) TO P-LT(NPER + 1)
               PERFORM TAKE-ROW
           END-IF.
       LOAD-ROW-8.
           MOVE FUNCTION NUMVAL(FROM8) TO WS-D1.
           MOVE FUNCTION NUMVAL(TO8) TO WS-D2.
           IF WS-D1 NOT = 0 THEN
               MOVE BR8 TO P-BR(NPER + 1)
               MOVE CP8 TO P-CP(NPER + 1)
               MOVE RS8 TO P-RS(NPER + 1)
               MOVE FUNCTION NUMVAL(LT8) TO P-LT(NPER + 1)
               PERFORM TAKE-ROW
           END-IF.

       CLASSIFY-PERIODS.
           MOVE 1 TO I.
           PERFORM CLASSIFY-ONE UNTIL I > NPER.

       CLASSIFY-ONE.
           MOVE 'Y' TO P-CR(I).
           MOVE 'N' TO P-ISLOST(I).
           MOVE SPACES TO P-DEPNOTE(I).
           MOVE P-RS(I) TO RS-U.
           MOVE 0 TO ISLOST.
           IF RS-U = 'CNFD' OR RS-U = 'EXPECC' OR RS-U = 'IHCA'
              OR RS-U = 'IHFA' OR RS-U = 'RTFD' OR RS-U = 'UA/DES' THEN
               MOVE 1 TO ISLOST
           END-IF.
           IF ISLOST = 1 THEN
               MOVE 'Y' TO P-ISLOST(I)
               MOVE 'N' TO P-CR(I)
               IF P-FROM(I) NOT = 0 AND P-TO(I) NOT = 0 THEN
                   MOVE P-FROM(I) TO WS-D1
                   MOVE P-TO(I) TO WS-D2
                   PERFORM LOST-DAYS-CH1
                   MOVE WS-DAYS TO P-LT(I)
               END-IF
           END-IF.
           IF ISLOST = 0 THEN
               MOVE P-CP(I) TO CP-U
               IF CP-U = 'DEP' THEN
                   PERFORM EVAL-DEP
                   IF DEPOK = 0 THEN
                       MOVE 'N' TO P-CR(I)
                   END-IF
               END-IF
           END-IF.
           ADD 1 TO I.

       EVAL-DEP.
           MOVE 0 TO DEPOK.
           MOVE SPACES TO P-DEPNOTE(I).
           IF P-FROM(I) = 0 THEN
               MOVE 'DEP not creditable (no from date) 2.1.4.12'
                   TO P-DEPNOTE(I)
           ELSE
               IF P-FROM(I) < 19850101 THEN
                   MOVE 1 TO DEPOK
                   MOVE 'DEP creditable (before 1 Jan 1985) 2.1.4.12'
                       TO P-DEPNOTE(I)
               ELSE
                   IF P-FROM(I) <= 19891128 THEN
                       MOVE 'DEP not creditable (1985-28 Nov 1989)'
                           TO P-DEPNOTE(I)
                   ELSE
                       MOVE 'DEP not creditable; set COMP=RES if RT07 IDT'
                           TO P-DEPNOTE(I)
                   END-IF
               END-IF
           END-IF.

       VALIDATE-ENTRY.
           MOVE 'Y' TO WS-OK.
           MOVE SPACES TO ERRMSG.
           MOVE FUNCTION UPPER-CASE(GRADE) TO GRADE-U.
           IF GRADE-U = SPACES THEN
               MOVE 'E' TO GRADE-U
           END-IF.
           IF GRADE-U NOT = 'E' AND GRADE-U NOT = 'O'
              AND GRADE-U NOT = 'W' THEN
               MOVE 'GRADE must be E, O, or W' TO ERRMSG
               MOVE 'N' TO WS-OK
           END-IF.
           IF WS-OK = 'Y' THEN
               IF FUNCTION TRIM(ASOF) NOT = SPACES THEN
                   MOVE FUNCTION NUMVAL(ASOF) TO CHK-DATE
                   PERFORM CHECK-YMD
                   IF CHECKYMD = 0 THEN
                       MOVE 'AS OF must be a valid YYYYMMDD' TO ERRMSG
                       MOVE 'N' TO WS-OK
                   END-IF
               END-IF
           END-IF.
           IF WS-OK = 'Y' THEN
               IF FUNCTION TRIM(RECPEBD) NOT = SPACES THEN
                   MOVE FUNCTION NUMVAL(RECPEBD) TO CHK-DATE
                   PERFORM CHECK-YMD
                   IF CHECKYMD = 0 THEN
                       MOVE 'RECORD PEBD must be a valid YYYYMMDD'
                           TO ERRMSG
                       MOVE 'N' TO WS-OK
                   END-IF
               END-IF
           END-IF.
           IF WS-OK = 'Y' THEN
               MOVE FROM1 TO WS-FROMX
               MOVE TO1 TO WS-TOX
               MOVE BR1 TO WS-BRX
               MOVE CP1 TO WS-CPX
               MOVE RS1 TO WS-RSX
               MOVE LT1 TO WS-LTX
               MOVE 1 TO ROW-N
               PERFORM VALIDATE-ONE-ROW
           END-IF.
           IF WS-OK = 'Y' THEN
               MOVE FROM2 TO WS-FROMX
               MOVE TO2 TO WS-TOX
               MOVE BR2 TO WS-BRX
               MOVE CP2 TO WS-CPX
               MOVE RS2 TO WS-RSX
               MOVE LT2 TO WS-LTX
               MOVE 2 TO ROW-N
               PERFORM VALIDATE-ONE-ROW
           END-IF.
           IF WS-OK = 'Y' THEN
               MOVE FROM3 TO WS-FROMX
               MOVE TO3 TO WS-TOX
               MOVE BR3 TO WS-BRX
               MOVE CP3 TO WS-CPX
               MOVE RS3 TO WS-RSX
               MOVE LT3 TO WS-LTX
               MOVE 3 TO ROW-N
               PERFORM VALIDATE-ONE-ROW
           END-IF.
           IF WS-OK = 'Y' THEN
               MOVE FROM4 TO WS-FROMX
               MOVE TO4 TO WS-TOX
               MOVE BR4 TO WS-BRX
               MOVE CP4 TO WS-CPX
               MOVE RS4 TO WS-RSX
               MOVE LT4 TO WS-LTX
               MOVE 4 TO ROW-N
               PERFORM VALIDATE-ONE-ROW
           END-IF.
           IF WS-OK = 'Y' THEN
               MOVE FROM5 TO WS-FROMX
               MOVE TO5 TO WS-TOX
               MOVE BR5 TO WS-BRX
               MOVE CP5 TO WS-CPX
               MOVE RS5 TO WS-RSX
               MOVE LT5 TO WS-LTX
               MOVE 5 TO ROW-N
               PERFORM VALIDATE-ONE-ROW
           END-IF.
           IF WS-OK = 'Y' THEN
               MOVE FROM6 TO WS-FROMX
               MOVE TO6 TO WS-TOX
               MOVE BR6 TO WS-BRX
               MOVE CP6 TO WS-CPX
               MOVE RS6 TO WS-RSX
               MOVE LT6 TO WS-LTX
               MOVE 6 TO ROW-N
               PERFORM VALIDATE-ONE-ROW
           END-IF.
           IF WS-OK = 'Y' THEN
               MOVE FROM7 TO WS-FROMX
               MOVE TO7 TO WS-TOX
               MOVE BR7 TO WS-BRX
               MOVE CP7 TO WS-CPX
               MOVE RS7 TO WS-RSX
               MOVE LT7 TO WS-LTX
               MOVE 7 TO ROW-N
               PERFORM VALIDATE-ONE-ROW
           END-IF.
           IF WS-OK = 'Y' THEN
               MOVE FROM8 TO WS-FROMX
               MOVE TO8 TO WS-TOX
               MOVE BR8 TO WS-BRX
               MOVE CP8 TO WS-CPX
               MOVE RS8 TO WS-RSX
               MOVE LT8 TO WS-LTX
               MOVE 8 TO ROW-N
               PERFORM VALIDATE-ONE-ROW
           END-IF.

       VALIDATE-ONE-ROW.
           MOVE 'N' TO ROW-HAS.
           IF FUNCTION TRIM(WS-TOX) NOT = SPACES
              OR FUNCTION TRIM(WS-BRX) NOT = SPACES
              OR FUNCTION TRIM(WS-CPX) NOT = SPACES
              OR FUNCTION TRIM(WS-RSX) NOT = SPACES
              OR FUNCTION TRIM(WS-LTX) NOT = SPACES THEN
               MOVE 'Y' TO ROW-HAS
           END-IF.
           IF FUNCTION TRIM(WS-FROMX) = SPACES THEN
               IF ROW-HAS = 'Y' THEN
                   MOVE SPACES TO ERRMSG
                   STRING 'Row ' DELIMITED BY SIZE
                          ROW-N DELIMITED BY SIZE
                          ': FROM date required' DELIMITED BY SIZE
                       INTO ERRMSG
                   MOVE 'N' TO WS-OK
               END-IF
           ELSE
               MOVE FUNCTION NUMVAL(WS-FROMX) TO CHK-DATE
               PERFORM CHECK-YMD
               IF CHECKYMD = 0 THEN
                   MOVE SPACES TO ERRMSG
                   STRING 'Row ' DELIMITED BY SIZE
                          ROW-N DELIMITED BY SIZE
                          ': FROM is not a valid date' DELIMITED BY SIZE
                       INTO ERRMSG
                   MOVE 'N' TO WS-OK
               ELSE
                   IF FUNCTION TRIM(WS-TOX) NOT = SPACES THEN
                       MOVE FUNCTION NUMVAL(WS-TOX) TO CHK-DATE
                       PERFORM CHECK-YMD
                       IF CHECKYMD = 0 THEN
                           MOVE SPACES TO ERRMSG
                           STRING 'Row ' DELIMITED BY SIZE
                                  ROW-N DELIMITED BY SIZE
                                  ': TO is not a valid date'
                                  DELIMITED BY SIZE
                               INTO ERRMSG
                           MOVE 'N' TO WS-OK
                       ELSE
                           IF FUNCTION NUMVAL(WS-FROMX) >
                              FUNCTION NUMVAL(WS-TOX) THEN
                               MOVE SPACES TO ERRMSG
                               STRING 'Row ' DELIMITED BY SIZE
                                      ROW-N DELIMITED BY SIZE
                                      ': FROM is after TO'
                                      DELIMITED BY SIZE
                                   INTO ERRMSG
                               MOVE 'N' TO WS-OK
                           END-IF
                       END-IF
                   END-IF
                   IF WS-OK = 'Y' THEN
                       PERFORM VALID-REASON
                       IF RSVALID = 0 THEN
                           MOVE SPACES TO ERRMSG
                           STRING 'Row ' DELIMITED BY SIZE
                                  ROW-N DELIMITED BY SIZE
                                  ': REASON must be ACT/INACT/CNFD/EXPECC/IHCA/IHFA/RTFD/UA/DES'
                                  DELIMITED BY SIZE
                               INTO ERRMSG
                           MOVE 'N' TO WS-OK
                       END-IF
                   END-IF
                   IF WS-OK = 'Y' THEN
                       IF FUNCTION TRIM(WS-LTX) NOT = SPACES THEN
                           IF FUNCTION NUMVAL(WS-LTX) < 0 THEN
                               MOVE SPACES TO ERRMSG
                               STRING 'Row ' DELIMITED BY SIZE
                                      ROW-N DELIMITED BY SIZE
                                      ': LOST days cannot be negative'
                                      DELIMITED BY SIZE
                                   INTO ERRMSG
                               MOVE 'N' TO WS-OK
                           END-IF
                       END-IF
                   END-IF
               END-IF
           END-IF.

       VALID-REASON.
           MOVE FUNCTION UPPER-CASE(WS-RSX) TO RS-U.
           MOVE 0 TO RSVALID.
           IF RS-U = SPACES OR RS-U = 'ACT' OR RS-U = 'INACT'
              OR RS-U = 'CNFD' OR RS-U = 'EXPECC' OR RS-U = 'IHCA'
              OR RS-U = 'IHFA' OR RS-U = 'RTFD' OR RS-U = 'UA/DES' THEN
               MOVE 1 TO RSVALID
           END-IF.

       CHECK-YMD.
           MOVE 0 TO CHECKYMD.
           IF CHK-DATE = 0 THEN
               CONTINUE
           ELSE
               MOVE CHK-DATE TO WS-DATE
               PERFORM SPLIT-DATE
               IF WS-Y >= 1800 AND WS-Y <= 2200 THEN
                   IF WS-M >= 1 AND WS-M <= 12 THEN
                       PERFORM DAYS-IN-MONTH
                       IF WS-D >= 1 AND WS-D <= WS-DIM THEN
                           MOVE 1 TO CHECKYMD
                       END-IF
                   END-IF
               END-IF
           END-IF.

       SEND-REVIEW.
           MOVE SPACES TO REV.
           IF NPER = 0 THEN
               MOVE 'No periods. PF3 back and add FROM dates.' TO MSG
           ELSE
               MOVE 'CR=Y counts for PEBD. Number+PF5 deletes. ENTER=calc.'
                   TO STATUS
           END-IF.
           MOVE 1 TO I.
           PERFORM FILL-REV-LINE UNTIL I > NPER OR I > 8.
           EXEC CICS SEND MAP('DODF2') FROM(REV) ERASE END-EXEC.

       FILL-REV-LINE.
           MOVE SPACES TO WS-LINE.
           MOVE P-FROM(I) TO TMP8.
           MOVE TMP8 TO TMPX.
           STRING I DELIMITED BY SIZE
                  '  ' DELIMITED BY SIZE
                  TMPX DELIMITED BY SIZE
                  '  ' DELIMITED BY SIZE
               INTO WS-LINE
           END-STRING.
           MOVE P-TO(I) TO TMP8.
           MOVE TMP8 TO TMPX.
           MOVE P-LT(I) TO LT-X.
           STRING FUNCTION TRIM(WS-LINE) DELIMITED BY SIZE
                  '  ' DELIMITED BY SIZE
                  TMPX DELIMITED BY SIZE
                  '  ' DELIMITED BY SIZE
                  P-BR(I) DELIMITED BY SIZE
                  ' ' DELIMITED BY SIZE
                  P-CP(I) DELIMITED BY SIZE
                  ' ' DELIMITED BY SIZE
                  P-RS(I) DELIMITED BY SIZE
                  ' LT=' DELIMITED BY SIZE
                  FUNCTION TRIM(LT-X) DELIMITED BY SIZE
                  ' CR=' DELIMITED BY SIZE
                  P-CR(I) DELIMITED BY SIZE
               INTO WS-LINE
           END-STRING.
           EVALUATE I
               WHEN 1 MOVE WS-LINE TO LINE01
               WHEN 2 MOVE WS-LINE TO LINE02
               WHEN 3 MOVE WS-LINE TO LINE03
               WHEN 4 MOVE WS-LINE TO LINE04
               WHEN 5 MOVE WS-LINE TO LINE05
               WHEN 6 MOVE WS-LINE TO LINE06
               WHEN 7 MOVE WS-LINE TO LINE07
               WHEN 8 MOVE WS-LINE TO LINE08
               WHEN OTHER CONTINUE
           END-EVALUATE.
           ADD 1 TO I.

       DELETE-PERIOD.
           IF SELN < 1 OR SELN > NPER THEN
               MOVE 'Invalid selection.' TO MSG
           ELSE
               MOVE SELN TO J
               PERFORM SHIFT-DOWN UNTIL J >= NPER
               SUBTRACT 1 FROM NPER
               MOVE 'Period deleted.' TO MSG
           END-IF.

       SHIFT-DOWN.
           COMPUTE K = J + 1.
           IF K <= NPER THEN
               MOVE P-FROM(K) TO P-FROM(J)
               MOVE P-TO(K) TO P-TO(J)
               MOVE P-BR(K) TO P-BR(J)
               MOVE P-CP(K) TO P-CP(J)
               MOVE P-RS(K) TO P-RS(J)
               MOVE P-LT(K) TO P-LT(J)
               MOVE P-CR(K) TO P-CR(J)
               MOVE P-ISLOST(K) TO P-ISLOST(J)
               MOVE P-DEPNOTE(K) TO P-DEPNOTE(J)
           END-IF.
           ADD 1 TO J.

       PREFILL-ENTRY.
           MOVE SPACES TO ERRMSG.
           MOVE SPACES TO FROM1.
           MOVE SPACES TO TO1.
           MOVE SPACES TO BR1.
           MOVE SPACES TO CP1.
           MOVE SPACES TO RS1.
           MOVE SPACES TO LT1.
           MOVE SPACES TO FROM2.
           MOVE SPACES TO TO2.
           MOVE SPACES TO BR2.
           MOVE SPACES TO CP2.
           MOVE SPACES TO RS2.
           MOVE SPACES TO LT2.
           MOVE SPACES TO FROM3.
           MOVE SPACES TO TO3.
           MOVE SPACES TO BR3.
           MOVE SPACES TO CP3.
           MOVE SPACES TO RS3.
           MOVE SPACES TO LT3.
           MOVE SPACES TO FROM4.
           MOVE SPACES TO TO4.
           MOVE SPACES TO BR4.
           MOVE SPACES TO CP4.
           MOVE SPACES TO RS4.
           MOVE SPACES TO LT4.
           MOVE SPACES TO FROM5.
           MOVE SPACES TO TO5.
           MOVE SPACES TO BR5.
           MOVE SPACES TO CP5.
           MOVE SPACES TO RS5.
           MOVE SPACES TO LT5.
           MOVE SPACES TO FROM6.
           MOVE SPACES TO TO6.
           MOVE SPACES TO BR6.
           MOVE SPACES TO CP6.
           MOVE SPACES TO RS6.
           MOVE SPACES TO LT6.
           MOVE SPACES TO FROM7.
           MOVE SPACES TO TO7.
           MOVE SPACES TO BR7.
           MOVE SPACES TO CP7.
           MOVE SPACES TO RS7.
           MOVE SPACES TO LT7.
           MOVE SPACES TO FROM8.
           MOVE SPACES TO TO8.
           MOVE SPACES TO BR8.
           MOVE SPACES TO CP8.
           MOVE SPACES TO RS8.
           MOVE SPACES TO LT8.
           MOVE GRADE-U TO GRADE.
           MOVE ASOF-N TO TMP8.
           MOVE TMP8 TO ASOF.
           IF REC-N NOT = 0 THEN
               MOVE REC-N TO TMP8
               MOVE TMP8 TO RECPEBD
           END-IF.
           IF NPER >= 1 THEN
               MOVE P-FROM(1) TO TMP8
               MOVE TMP8 TO FROM1
               MOVE P-TO(1) TO TMP8
               MOVE TMP8 TO TO1
               MOVE P-BR(1) TO BR1
               MOVE P-CP(1) TO CP1
               MOVE P-RS(1) TO RS1
               MOVE P-LT(1) TO LT-X
               MOVE LT-X TO LT1
           END-IF.
           IF NPER >= 2 THEN
               MOVE P-FROM(2) TO TMP8
               MOVE TMP8 TO FROM2
               MOVE P-TO(2) TO TMP8
               MOVE TMP8 TO TO2
               MOVE P-BR(2) TO BR2
               MOVE P-CP(2) TO CP2
               MOVE P-RS(2) TO RS2
               MOVE P-LT(2) TO LT-X
               MOVE LT-X TO LT2
           END-IF.
           IF NPER >= 3 THEN
               MOVE P-FROM(3) TO TMP8
               MOVE TMP8 TO FROM3
               MOVE P-TO(3) TO TMP8
               MOVE TMP8 TO TO3
               MOVE P-BR(3) TO BR3
               MOVE P-CP(3) TO CP3
               MOVE P-RS(3) TO RS3
               MOVE P-LT(3) TO LT-X
               MOVE LT-X TO LT3
           END-IF.
           IF NPER >= 4 THEN
               MOVE P-FROM(4) TO TMP8
               MOVE TMP8 TO FROM4
               MOVE P-TO(4) TO TMP8
               MOVE TMP8 TO TO4
               MOVE P-BR(4) TO BR4
               MOVE P-CP(4) TO CP4
               MOVE P-RS(4) TO RS4
               MOVE P-LT(4) TO LT-X
               MOVE LT-X TO LT4
           END-IF.
           IF NPER >= 5 THEN
               MOVE P-FROM(5) TO TMP8
               MOVE TMP8 TO FROM5
               MOVE P-TO(5) TO TMP8
               MOVE TMP8 TO TO5
               MOVE P-BR(5) TO BR5
               MOVE P-CP(5) TO CP5
               MOVE P-RS(5) TO RS5
               MOVE P-LT(5) TO LT-X
               MOVE LT-X TO LT5
           END-IF.
           IF NPER >= 6 THEN
               MOVE P-FROM(6) TO TMP8
               MOVE TMP8 TO FROM6
               MOVE P-TO(6) TO TMP8
               MOVE TMP8 TO TO6
               MOVE P-BR(6) TO BR6
               MOVE P-CP(6) TO CP6
               MOVE P-RS(6) TO RS6
               MOVE P-LT(6) TO LT-X
               MOVE LT-X TO LT6
           END-IF.
           IF NPER >= 7 THEN
               MOVE P-FROM(7) TO TMP8
               MOVE TMP8 TO FROM7
               MOVE P-TO(7) TO TMP8
               MOVE TMP8 TO TO7
               MOVE P-BR(7) TO BR7
               MOVE P-CP(7) TO CP7
               MOVE P-RS(7) TO RS7
               MOVE P-LT(7) TO LT-X
               MOVE LT-X TO LT7
           END-IF.
           IF NPER >= 8 THEN
               MOVE P-FROM(8) TO TMP8
               MOVE TMP8 TO FROM8
               MOVE P-TO(8) TO TMP8
               MOVE TMP8 TO TO8
               MOVE P-BR(8) TO BR8
               MOVE P-CP(8) TO CP8
               MOVE P-RS(8) TO RS8
               MOVE P-LT(8) TO LT-X
               MOVE LT-X TO LT8
           END-IF.
           EXEC CICS SEND MAP('DODF1') FROM(SCR) ERASE END-EXEC.

       CALCULATE-ALL.
           MOVE 0 TO LOSTTOTAL.
           MOVE 0 TO GROSSDAYS.
           MOVE 0 TO NIN.
           MOVE 0 TO NMERGE.
           MOVE 0 TO NLOST.
           MOVE ASOF-N TO CALCPEBD.
           MOVE ASOF-N TO PEBDBASE.
           MOVE 1 TO I.
           PERFORM ACCUM-ONE UNTIL I > NPER.
           IF NIN > 0 THEN
               PERFORM SORT-MERGEIN
               PERFORM MERGE-SEGS
               PERFORM SUM-MERGED
           END-IF.
           COMPUTE NETDAYS = GROSSDAYS - LOSTTOTAL.
           IF NETDAYS < 0 THEN
               MOVE 0 TO NETDAYS
           END-IF.
           COMPUTE YRS = NETDAYS / 360.
           COMPUTE REM = NETDAYS - YRS * 360.
           COMPUTE MOS = REM / 30.
           COMPUTE DYS = REM - MOS * 30.
           MOVE YRS TO YMD-Y.
           MOVE MOS TO YMD-M.
           MOVE DYS TO YMD-D.
           MOVE SPACES TO NET-YMD.
           STRING FUNCTION TRIM(YMD-Y) DELIMITED BY SIZE
                  'y ' DELIMITED BY SIZE
                  FUNCTION TRIM(YMD-M) DELIMITED BY SIZE
                  'm ' DELIMITED BY SIZE
                  FUNCTION TRIM(YMD-D) DELIMITED BY SIZE
                  'd' DELIMITED BY SIZE
               INTO NET-YMD
           END-STRING.
           COMPUTE LY = LOSTTOTAL / 360.
           COMPUTE LR = LOSTTOTAL - LY * 360.
           COMPUTE LM = LR / 30.
           COMPUTE LD = LR - LM * 30.
           MOVE LY TO YMD-Y.
           MOVE LM TO YMD-M.
           MOVE LD TO YMD-D.
           MOVE SPACES TO LOST-YMD.
           STRING FUNCTION TRIM(YMD-Y) DELIMITED BY SIZE
                  'y ' DELIMITED BY SIZE
                  FUNCTION TRIM(YMD-M) DELIMITED BY SIZE
                  'm ' DELIMITED BY SIZE
                  FUNCTION TRIM(YMD-D) DELIMITED BY SIZE
                  'd' DELIMITED BY SIZE
               INTO LOST-YMD
           END-STRING.
           PERFORM DERIVE-PEBD.
           PERFORM COMPARE-PEBD.

       ACCUM-ONE.
           IF P-CR(I) = 'Y' OR P-ISLOST(I) = 'Y' THEN
               IF P-FROM(I) NOT = 0 THEN
                   ADD 1 TO NIN
                   MOVE P-FROM(I) TO M-FROM(NIN)
                   MOVE P-TO(I) TO M-TO(NIN)
               END-IF
           END-IF.
           IF P-ISLOST(I) = 'Y' THEN
               ADD 1 TO NLOST
               MOVE P-FROM(I) TO L-FROM(NLOST)
               MOVE P-TO(I) TO L-TO(NLOST)
               MOVE P-RS(I) TO L-RS(NLOST)
               IF OFFICER = 1 THEN
                   MOVE 0 TO L-DAYS(NLOST)
                   MOVE 'Officer Exception' TO L-METH(NLOST)
               ELSE
                   IF P-FROM(I) NOT = 0 AND P-TO(I) NOT = 0 THEN
                       MOVE P-FROM(I) TO WS-D1
                       MOVE P-TO(I) TO WS-D2
                       PERFORM LOST-DAYS-CH1
                       MOVE WS-DAYS TO L-DAYS(NLOST)
                       MOVE 'Ch1 2.4.1.3.1 deducted' TO L-METH(NLOST)
                   ELSE
                       MOVE P-LT(I) TO L-DAYS(NLOST)
                       MOVE 'MCTFS LOST field' TO L-METH(NLOST)
                   END-IF
               END-IF
               ADD L-DAYS(NLOST) TO LOSTTOTAL
           END-IF.
           ADD 1 TO I.

       SORT-MERGEIN.
           MOVE 1 TO I.
           PERFORM SORT-OUTER UNTIL I >= NIN.

       SORT-OUTER.
           COMPUTE J = I + 1.
           PERFORM SORT-INNER UNTIL J > NIN.
           ADD 1 TO I.

       SORT-INNER.
           IF M-FROM(I) > M-FROM(J) THEN
               MOVE M-FROM(I) TO TMP8
               MOVE M-FROM(J) TO M-FROM(I)
               MOVE TMP8 TO M-FROM(J)
               MOVE M-TO(I) TO TMP8
               MOVE M-TO(J) TO M-TO(I)
               MOVE TMP8 TO M-TO(J)
           END-IF.
           ADD 1 TO J.

       MERGE-SEGS.
           MOVE 1 TO NMERGE.
           MOVE 2 TO I.
           PERFORM MERGE-ONE UNTIL I > NIN.

       MERGE-ONE.
           MOVE NMERGE TO LASTN.
           MOVE M-TO(LASTN) TO WS-D1.
           MOVE 1 TO WS-DELTA.
           PERFORM ADD-CAL-DAYS.
           IF M-FROM(I) <= WS-OUT THEN
               IF M-TO(I) > M-TO(LASTN) THEN
                   MOVE M-TO(I) TO M-TO(LASTN)
               END-IF
           ELSE
               ADD 1 TO NMERGE
               MOVE M-FROM(I) TO M-FROM(NMERGE)
               MOVE M-TO(I) TO M-TO(NMERGE)
           END-IF.
           ADD 1 TO I.

       SUM-MERGED.
           MOVE 1 TO I.
           PERFORM SUM-ONE UNTIL I > NMERGE.

       SUM-ONE.
           MOVE M-FROM(I) TO WS-D1.
           MOVE M-TO(I) TO WS-D2.
           PERFORM SEG-DAYS-30.
           COMPUTE M-DAYS(I) = WS-DAYS + 1.
           ADD M-DAYS(I) TO GROSSDAYS.
           ADD 1 TO I.

       DERIVE-PEBD.
           IF NMERGE = 1 THEN
               MOVE M-FROM(1) TO PEBDBASE
           ELSE
               IF GROSSDAYS <= 0 THEN
                   MOVE ASOF-N TO PEBDBASE
               ELSE
                   PERFORM SEARCH-PEBD
               END-IF
           END-IF.
           MOVE PEBDBASE TO CALCPEBD.
           IF LOSTTOTAL > 0 AND OFFICER = 0 THEN
               COMPUTE LY = LOSTTOTAL / 360
               COMPUTE LR = LOSTTOTAL - LY * 360
               COMPUTE LM = LR / 30
               COMPUTE LD = LR - LM * 30
               MOVE PEBDBASE TO WS-D1
               PERFORM ADD-YMD-30
               MOVE WS-OUT TO CALCPEBD
           END-IF.

       SEARCH-PEBD.
           COMPUTE TARGET = GROSSDAYS - 1.
           IF TARGET < 0 THEN
               MOVE 0 TO TARGET
           END-IF.
           COMPUTE GY = TARGET / 360.
           COMPUTE GR = TARGET - GY * 360.
           COMPUTE GM = GR / 30.
           COMPUTE GD = GR - GM * 30.
           PERFORM CALC-PEBD-GUESS.
           MOVE WS-OUT TO BEST.
           MOVE WS-OUT TO WS-GUESS.
           MOVE BEST TO WS-D1.
           MOVE ASOF-N TO WS-D2.
           PERFORM SEG-DAYS-30.
           COMPUTE ERR = WS-DAYS - TARGET.
           IF ERR < 0 THEN
               COMPUTE BESTERR = 0 - ERR
           ELSE
               MOVE ERR TO BESTERR
           END-IF.
           MOVE -20 TO DELTA.
           PERFORM SEARCH-DELTA UNTIL DELTA > 20.
           MOVE BEST TO WS-D1.
           MOVE ASOF-N TO WS-D2.
           PERFORM SEG-DAYS-30.
           COMPUTE ERR = WS-DAYS - TARGET.
           IF ERR NOT = 0 THEN
               MOVE BEST TO WS-D1
               COMPUTE WS-DELTA = 0 - ERR
               PERFORM ADD-CAL-DAYS
               MOVE WS-OUT TO CAND
               MOVE CAND TO WS-D1
               MOVE ASOF-N TO WS-D2
               PERFORM SEG-DAYS-30
               COMPUTE AD = WS-DAYS - TARGET
               IF AD < 0 THEN
                   COMPUTE AD = 0 - AD
               END-IF
               IF AD <= BESTERR THEN
                   MOVE CAND TO BEST
               END-IF
           END-IF.
           MOVE BEST TO PEBDBASE.

       SEARCH-DELTA.
           IF DELTA NOT = 0 THEN
               MOVE WS-GUESS TO WS-D1
               MOVE DELTA TO WS-DELTA
               PERFORM ADD-CAL-DAYS
               MOVE WS-OUT TO CAND
               MOVE CAND TO WS-D1
               MOVE ASOF-N TO WS-D2
               PERFORM SEG-DAYS-30
               COMPUTE ERR = WS-DAYS - TARGET
               IF ERR < 0 THEN
                   COMPUTE AD = 0 - ERR
               ELSE
                   MOVE ERR TO AD
               END-IF
               IF AD < BESTERR THEN
                   MOVE CAND TO BEST
                   MOVE AD TO BESTERR
               END-IF
               IF AD = BESTERR AND WS-DAYS = TARGET THEN
                   MOVE CAND TO BEST
               END-IF
           END-IF.
           ADD 1 TO DELTA.

       CALC-PEBD-GUESS.
           MOVE ASOF-N TO WS-DATE.
           PERFORM SPLIT-DATE.
           COMPUTE WS-M = WS-M - (GY * 12 + GM).
           PERFORM UNTIL WS-M > 0
               ADD 12 TO WS-M
               SUBTRACT 1 FROM WS-Y
           END-PERFORM.
           PERFORM DAYS-IN-MONTH.
           IF WS-D > WS-DIM THEN
               MOVE WS-DIM TO WS-D
           END-IF.
           PERFORM PACK-DATE.
           MOVE WS-OUT TO WS-D1.
           COMPUTE WS-DELTA = 0 - GD.
           PERFORM ADD-CAL-DAYS.

       COMPARE-PEBD.
           MOVE 'Calculated only (no Record PEBD)' TO STATUS-TXT.
           MOVE SPACES TO DIFF-TXT.
           IF REC-N NOT = 0 THEN
               MOVE CALCPEBD TO WS-DATE
               PERFORM TO-JDN
               MOVE JA TO J1
               MOVE REC-N TO WS-DATE
               PERFORM TO-JDN
               MOVE JA TO J2
               COMPUTE DIFFDAYS = J1 - J2
               IF DIFFDAYS = 0 THEN
                   MOVE 'MATCH' TO STATUS-TXT
                   MOVE '0 days' TO DIFF-TXT
               ELSE
                   IF DIFFDAYS < 0 THEN
                       COMPUTE AD = 0 - DIFFDAYS
                   ELSE
                       MOVE DIFFDAYS TO AD
                   END-IF
                   IF AD = 1 THEN
                       MOVE 'CLOSE MATCH' TO STATUS-TXT
                   ELSE
                       IF AD <= 7 THEN
                           MOVE 'MODERATE DIFF' TO STATUS-TXT
                       ELSE
                           MOVE 'SIGNIFICANT DIFF' TO STATUS-TXT
                       END-IF
                   END-IF
                   MOVE DIFFDAYS TO DAYS-X
                   MOVE DAYS-X TO DIFF-TXT
               END-IF
           END-IF.

       SPLIT-DATE.
           COMPUTE WS-Y = WS-DATE / 10000.
           COMPUTE WS-M = (WS-DATE - WS-Y * 10000) / 100.
           COMPUTE WS-D = WS-DATE - WS-Y * 10000 - WS-M * 100.

       PACK-DATE.
           COMPUTE WS-OUT = WS-Y * 10000 + WS-M * 100 + WS-D.

       DAYS-IN-MONTH.
           MOVE 31 TO WS-DIM.
           IF WS-M = 4 OR WS-M = 6 OR WS-M = 9 OR WS-M = 11 THEN
               MOVE 30 TO WS-DIM
           END-IF.
           IF WS-M = 2 THEN
               MOVE 28 TO WS-DIM
               COMPUTE JA = WS-Y / 400
               IF WS-Y = JA * 400 THEN
                   MOVE 29 TO WS-DIM
               ELSE
                   COMPUTE JA = WS-Y / 100
                   IF WS-Y = JA * 100 THEN
                       MOVE 28 TO WS-DIM
                   ELSE
                       COMPUTE JA = WS-Y / 4
                       IF WS-Y = JA * 4 THEN
                           MOVE 29 TO WS-DIM
                       END-IF
                   END-IF
               END-IF
           END-IF.

       ADJUST-DAY.
           IF WS-D = 31 THEN
               MOVE 30 TO WS-D
           END-IF.
           IF WS-M = 2 THEN
               IF WS-D = 28 OR WS-D = 29 THEN
                   MOVE 30 TO WS-D
               END-IF
           END-IF.

       SEG-DAYS-30.
           MOVE 0 TO WS-DAYS.
           IF WS-D1 NOT = 0 AND WS-D2 NOT = 0 AND WS-D1 <= WS-D2 THEN
               MOVE WS-D1 TO WS-DATE
               PERFORM SPLIT-DATE
               MOVE WS-Y TO YS
               MOVE WS-M TO MS
               MOVE WS-D TO DS
               MOVE WS-D2 TO WS-DATE
               PERFORM SPLIT-DATE
               MOVE WS-Y TO YE
               MOVE WS-M TO ME
               MOVE WS-D TO DE
               MOVE DS TO WS-D
               MOVE MS TO WS-M
               PERFORM ADJUST-DAY
               MOVE WS-D TO DS
               MOVE DE TO WS-D
               MOVE ME TO WS-M
               PERFORM ADJUST-DAY
               MOVE WS-D TO DE
               COMPUTE TDAYS = DE - DS
               COMPUTE TMONTHS = ME - MS
               COMPUTE TYEARS = YE - YS
               IF TDAYS < 0 THEN
                   ADD 30 TO TDAYS
                   SUBTRACT 1 FROM TMONTHS
               END-IF
               IF TMONTHS < 0 THEN
                   ADD 12 TO TMONTHS
                   SUBTRACT 1 FROM TYEARS
               END-IF
               COMPUTE WS-DAYS = TYEARS * 360 + TMONTHS * 30 + TDAYS
               IF WS-DAYS < 0 THEN
                   MOVE 0 TO WS-DAYS
               END-IF
           END-IF.

       LOST-DAYS-CH1.
           MOVE 0 TO WS-DAYS.
           MOVE 0 TO WS-EXTRA.
           MOVE 'Y' TO WS-OK.
           IF WS-D1 = 0 OR WS-D2 = 0 OR WS-D1 > WS-D2 THEN
               MOVE 'N' TO WS-OK
           END-IF.
           IF WS-OK = 'Y' THEN
               MOVE WS-D1 TO WS-DATE
               PERFORM SPLIT-DATE
               IF WS-D = 31 THEN
                   MOVE 1 TO WS-EXTRA
                   IF WS-D1 = WS-D2 THEN
                       MOVE 1 TO WS-DAYS
                       MOVE 'N' TO WS-OK
                   ELSE
                       ADD 1 TO WS-M
                       IF WS-M > 12 THEN
                           MOVE 1 TO WS-M
                           ADD 1 TO WS-Y
                       END-IF
                       MOVE 1 TO WS-D
                       PERFORM PACK-DATE
                       IF WS-OUT > WS-D2 THEN
                           MOVE 1 TO WS-DAYS
                           MOVE 'N' TO WS-OK
                       ELSE
                           MOVE WS-OUT TO WS-D1
                       END-IF
                   END-IF
               END-IF
           END-IF.
           IF WS-OK = 'Y' THEN
               MOVE WS-D1 TO WS-DATE
               PERFORM SPLIT-DATE
               MOVE WS-Y TO YS
               MOVE WS-M TO MS
               MOVE WS-D TO DS
               MOVE WS-D2 TO WS-DATE
               PERFORM SPLIT-DATE
               MOVE WS-Y TO YE
               MOVE WS-M TO ME
               MOVE WS-D TO DE
               MOVE DS TO WS-D
               MOVE MS TO WS-M
               PERFORM ADJUST-DAY
               MOVE WS-D TO DS
               MOVE DE TO WS-D
               MOVE ME TO WS-M
               PERFORM ADJUST-DAY
               MOVE WS-D TO DE
               COMPUTE TDAYS = DE - DS + 1
               COMPUTE TMONTHS = ME - MS
               COMPUTE TYEARS = YE - YS
               IF TDAYS < 0 THEN
                   ADD 30 TO TDAYS
                   SUBTRACT 1 FROM TMONTHS
               END-IF
               IF TMONTHS < 0 THEN
                   ADD 12 TO TMONTHS
                   SUBTRACT 1 FROM TYEARS
               END-IF
               COMPUTE WS-DAYS = WS-EXTRA + TYEARS * 360
                                + TMONTHS * 30 + TDAYS
               IF WS-DAYS < 0 THEN
                   MOVE 0 TO WS-DAYS
               END-IF
           END-IF.

       ADD-CAL-DAYS.
           MOVE WS-D1 TO WS-DATE.
           PERFORM SPLIT-DATE.
           ADD WS-DELTA TO WS-D.
           PERFORM DAYS-IN-MONTH.
           PERFORM UNTIL WS-D <= WS-DIM AND WS-D >= 1
               IF WS-D > WS-DIM THEN
                   SUBTRACT WS-DIM FROM WS-D
                   ADD 1 TO WS-M
                   IF WS-M > 12 THEN
                       MOVE 1 TO WS-M
                       ADD 1 TO WS-Y
                   END-IF
                   PERFORM DAYS-IN-MONTH
               END-IF
               IF WS-D < 1 THEN
                   SUBTRACT 1 FROM WS-M
                   IF WS-M < 1 THEN
                       MOVE 12 TO WS-M
                       SUBTRACT 1 FROM WS-Y
                   END-IF
                   PERFORM DAYS-IN-MONTH
                   ADD WS-DIM TO WS-D
               END-IF
           END-PERFORM.
           PERFORM PACK-DATE.

       ADD-YMD-30.
           MOVE WS-D1 TO WS-DATE.
           PERFORM SPLIT-DATE.
           IF WS-D = 31 THEN
               MOVE 30 TO WS-D
           END-IF.
           COMPUTE WS-M = WS-M + LY * 12 + LM.
           PERFORM UNTIL WS-M <= 12
               SUBTRACT 12 FROM WS-M
               ADD 1 TO WS-Y
           END-PERFORM.
           PERFORM UNTIL WS-M >= 1
               ADD 12 TO WS-M
               SUBTRACT 1 FROM WS-Y
           END-PERFORM.
           ADD LD TO WS-D.
           PERFORM UNTIL WS-D <= 30
               SUBTRACT 30 FROM WS-D
               ADD 1 TO WS-M
               IF WS-M > 12 THEN
                   MOVE 1 TO WS-M
                   ADD 1 TO WS-Y
               END-IF
           END-PERFORM.
           PERFORM DAYS-IN-MONTH.
           IF WS-D > WS-DIM THEN
               MOVE WS-DIM TO WS-D
           END-IF.
           PERFORM PACK-DATE.

       TO-JDN.
           PERFORM SPLIT-DATE.
           COMPUTE JA = (14 - WS-M) / 12.
           COMPUTE JYY = WS-Y + 4800 - JA.
           COMPUTE JMM = WS-M + 12 * JA - 3.
           COMPUTE JA = WS-D
                      + (153 * JMM + 2) / 5
                      + 365 * JYY
                      + JYY / 4
                      - JYY / 100
                      + JYY / 400
                      - 32045.

       PAINT-REPORT.
           MOVE SPACES TO REPORT.
           MOVE 1 TO RCOUNT.
           IF OFFICER = 1 THEN
               MOVE 'OFFICER (O/W)' TO CLASS-TXT
           ELSE
               MOVE 'ENLISTED' TO CLASS-TXT
           END-IF.
           MOVE SPACES TO WS-LINE.
           MOVE '=== DODFMR STATEMENT OF SERVICE (PAT / Ch 1 COBOL) ==='
               TO WS-LINE.
           PERFORM ADD-REP.
           MOVE SPACES TO WS-LINE.
           STRING 'EDIPI : ' DELIMITED BY SIZE
                  EDIPI DELIMITED BY SIZE
               INTO WS-LINE
           END-STRING.
           PERFORM ADD-REP.
           MOVE SPACES TO WS-LINE.
           STRING 'NAME  : ' DELIMITED BY SIZE
                  NAME DELIMITED BY SIZE
               INTO WS-LINE
           END-STRING.
           PERFORM ADD-REP.
           MOVE SPACES TO WS-LINE.
           STRING 'Grade : ' DELIMITED BY SIZE
                  GRADE-U DELIMITED BY SIZE
                  '  ' DELIMITED BY SIZE
                  CLASS-TXT DELIMITED BY SIZE
               INTO WS-LINE
           END-STRING.
           PERFORM ADD-REP.
           MOVE ASOF-N TO TMP8.
           MOVE TMP8 TO TMPX.
           MOVE SPACES TO WS-LINE.
           STRING 'As of : ' DELIMITED BY SIZE
                  TMPX DELIMITED BY SIZE
               INTO WS-LINE
           END-STRING.
           PERFORM ADD-REP.
           MOVE GROSSDAYS TO DAYS-X.
           MOVE SPACES TO WS-LINE.
           STRING 'Gross creditable : ' DELIMITED BY SIZE
                  DAYS-X DELIMITED BY SIZE
                  ' days' DELIMITED BY SIZE
               INTO WS-LINE
           END-STRING.
           PERFORM ADD-REP.
           MOVE LOSTTOTAL TO DAYS-X.
           MOVE SPACES TO WS-LINE.
           STRING 'Lost deducted    : ' DELIMITED BY SIZE
                  DAYS-X DELIMITED BY SIZE
                  ' days  (' DELIMITED BY SIZE
                  LOST-YMD DELIMITED BY SIZE
                  ')' DELIMITED BY SIZE
               INTO WS-LINE
           END-STRING.
           PERFORM ADD-REP.
           MOVE NETDAYS TO DAYS-X.
           MOVE SPACES TO WS-LINE.
           STRING 'Net creditable   : ' DELIMITED BY SIZE
                  DAYS-X DELIMITED BY SIZE
                  ' days  (' DELIMITED BY SIZE
                  NET-YMD DELIMITED BY SIZE
                  ')' DELIMITED BY SIZE
               INTO WS-LINE
           END-STRING.
           PERFORM ADD-REP.
           MOVE PEBDBASE TO TMP8.
           MOVE TMP8 TO TMPX.
           MOVE SPACES TO WS-LINE.
           STRING 'PEBD before lost : ' DELIMITED BY SIZE
                  TMPX DELIMITED BY SIZE
               INTO WS-LINE
           END-STRING.
           PERFORM ADD-REP.
           MOVE SPACES TO WS-LINE.
           STRING 'Lost time 30-day : ' DELIMITED BY SIZE
                  LOST-YMD DELIMITED BY SIZE
               INTO WS-LINE
           END-STRING.
           PERFORM ADD-REP.
           MOVE CALCPEBD TO TMP8.
           MOVE TMP8 TO TMPX.
           MOVE SPACES TO WS-LINE.
           STRING 'Calculated PEBD  : ' DELIMITED BY SIZE
                  TMPX DELIMITED BY SIZE
               INTO WS-LINE
           END-STRING.
           PERFORM ADD-REP.
           MOVE SPACES TO WS-LINE.
           IF REC-N = 0 THEN
               MOVE 'Record PEBD      : (none)' TO WS-LINE
           ELSE
               MOVE REC-N TO TMP8
               MOVE TMP8 TO TMPX
               STRING 'Record PEBD      : ' DELIMITED BY SIZE
                      TMPX DELIMITED BY SIZE
                   INTO WS-LINE
               END-STRING
           END-IF.
           PERFORM ADD-REP.
           MOVE SPACES TO WS-LINE.
           STRING 'Status : ' DELIMITED BY SIZE
                  STATUS-TXT DELIMITED BY SIZE
                  '  ' DELIMITED BY SIZE
                  DIFF-TXT DELIMITED BY SIZE
               INTO WS-LINE
           END-STRING.
           PERFORM ADD-REP.
           MOVE 1 TO I.
           PERFORM REP-PERIOD UNTIL I > NPER.
           IF NLOST > 0 THEN
               MOVE SPACES TO WS-LINE
               MOVE 'Lost time analysis:' TO WS-LINE
               PERFORM ADD-REP
               MOVE 1 TO I
               PERFORM REP-LOST UNTIL I > NLOST
           END-IF.
           MOVE SPACES TO WS-LINE.
           MOVE 'ENTER/PF12=edit input  PF3=menu' TO WS-LINE.
           PERFORM ADD-REP.
           EXEC CICS SEND TEXT FROM(REPORT) ERASE END-EXEC.

       REP-PERIOD.
           MOVE SPACES TO WS-LINE.
           MOVE P-FROM(I) TO TMP8.
           MOVE TMP8 TO TMPX.
           STRING I DELIMITED BY SIZE
                  '. ' DELIMITED BY SIZE
                  TMPX DELIMITED BY SIZE
                  ' -> ' DELIMITED BY SIZE
               INTO WS-LINE
           END-STRING.
           MOVE P-TO(I) TO TMP8.
           MOVE TMP8 TO TMPX.
           STRING FUNCTION TRIM(WS-LINE) DELIMITED BY SIZE
                  TMPX DELIMITED BY SIZE
                  ' ' DELIMITED BY SIZE
                  P-BR(I) DELIMITED BY SIZE
                  ' ' DELIMITED BY SIZE
                  P-CP(I) DELIMITED BY SIZE
                  ' ' DELIMITED BY SIZE
                  P-RS(I) DELIMITED BY SIZE
                  ' CR=' DELIMITED BY SIZE
                  P-CR(I) DELIMITED BY SIZE
               INTO WS-LINE
           END-STRING.
           PERFORM ADD-REP.
           ADD 1 TO I.

       REP-LOST.
           MOVE SPACES TO WS-LINE.
           MOVE L-FROM(I) TO TMP8.
           MOVE TMP8 TO TMPX.
           MOVE L-DAYS(I) TO DAYS-X.
           STRING I DELIMITED BY SIZE
                  '. ' DELIMITED BY SIZE
                  TMPX DELIMITED BY SIZE
                  ' -> ' DELIMITED BY SIZE
               INTO WS-LINE
           END-STRING.
           MOVE L-TO(I) TO TMP8.
           MOVE TMP8 TO TMPX.
           STRING FUNCTION TRIM(WS-LINE) DELIMITED BY SIZE
                  TMPX DELIMITED BY SIZE
                  ' ' DELIMITED BY SIZE
                  L-RS(I) DELIMITED BY SIZE
                  ' deduct=' DELIMITED BY SIZE
                  FUNCTION TRIM(DAYS-X) DELIMITED BY SIZE
                  ' ' DELIMITED BY SIZE
                  L-METH(I) DELIMITED BY SIZE
               INTO WS-LINE
           END-STRING.
           PERFORM ADD-REP.
           ADD 1 TO I.

       ADD-REP.
           IF RCOUNT >= 1 AND RCOUNT <= 40 THEN
               MOVE WS-LINE TO R-LINE(RCOUNT)
           END-IF.
           IF RCOUNT < 40 THEN
               ADD 1 TO RCOUNT
           END-IF.

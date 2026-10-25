      *> ABNH -- HANDLE ABEND catching a condition abend (COBOL). The
      *> READ of a missing key has no RESP, so the NOTFND condition
      *> is unhandled and CICS abends the task AEIM. HANDLE ABEND
      *> LABEL(RECOVER) intercepts that abend: control goes to
      *> RECOVER, which reads the code with ASSIGN ABCODE and shows
      *> CAUGHT AEIM. EIBRESP still holds 13 (NOTFND) there.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ABNH.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 REC     PIC X(80).
       01 WS-CODE PIC X(4).
       01 SCR.
          05 FILLER   PIC X(7)  VALUE 'CAUGHT '.
          05 SCR-CODE PIC X(4).
          05 FILLER   PIC X(9)  VALUE ' EIBRESP='.
          05 SCR-RESP PIC 9(4).

       PROCEDURE DIVISION.
       MAIN.
           EXEC CICS HANDLE ABEND LABEL(RECOVER) END-EXEC.
           EXEC CICS READ FILE('customers') INTO(REC)
                     RIDFLD('NOSUCHKEY') END-EXEC.
      *> Never reached: the READ abends AEIM and HANDLE ABEND
      *> sends control to RECOVER.
           EXEC CICS RETURN END-EXEC.
           GOBACK.

       RECOVER.
      *> Save EIBRESP first: every EXEC CICS, ASSIGN included, sets
      *> it again (to NORMAL).
           MOVE EIBRESP TO SCR-RESP.
           EXEC CICS ASSIGN ABCODE(WS-CODE) END-EXEC.
           MOVE WS-CODE TO SCR-CODE.
           EXEC CICS SEND TEXT FROM(SCR) ERASE END-EXEC.
           EXEC CICS RETURN END-EXEC.
           GOBACK.

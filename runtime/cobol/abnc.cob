      *> ABNC -- unhandled CICS condition demo (COBOL). The READ asks
      *> for a key that is not on file and codes neither RESP nor
      *> NOHANDLE, and no HANDLE CONDITION is active. As on IBM CICS
      *> the NOTFND condition is unhandled, so the task abends AEIM
      *> and the terminal shows DFHAC2206 ... abend AEIM. Compare ABNH
      *> (the same READ caught by HANDLE ABEND) and GUST (RESP coded).
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ABNC.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 REC     PIC X(80).
       01 SCR     PIC X(79).

       PROCEDURE DIVISION.
       MAIN.
           EXEC CICS READ FILE('customers') INTO(REC)
                     RIDFLD('NOSUCHKEY') END-EXEC.
      *> Never reached: the READ above abends the task AEIM.
           MOVE 'ABNC: READ RETURNED - NOT EXPECTED' TO SCR.
           EXEC CICS SEND TEXT FROM(SCR) ERASE END-EXEC.
           EXEC CICS RETURN END-EXEC.
           GOBACK.

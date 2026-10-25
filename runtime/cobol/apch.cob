      *> APCH -- abend APCT demo (COBOL). HANDLE ABEND PROGRAM names
      *> an exit program, NOPGM, that is not defined. When the task
      *> then abends with ABEND ABCODE('TEST'), CICS cannot load the
      *> exit, so the task abends APCT instead of TEST; the log keeps
      *> the original code (APCT detail ... original=TEST). APCT
      *> drives no further exit.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. APCH.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 SCR     PIC X(79).

       PROCEDURE DIVISION.
       MAIN.
           EXEC CICS HANDLE ABEND PROGRAM('NOPGM') END-EXEC.
           EXEC CICS ABEND ABCODE('TEST') END-EXEC.
      *> Never reached: the ABEND above ends the task APCT.
           MOVE 'APCH: ABEND RETURNED - NOT EXPECTED' TO SCR.
           EXEC CICS SEND TEXT FROM(SCR) ERASE END-EXEC.
           EXEC CICS RETURN END-EXEC.
           GOBACK.

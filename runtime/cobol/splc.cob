      *> SPLC -- abend ASP7 demo (COBOL). The same refused commit as
      *> SPDB (two INSERTs of one key into SPDB_DEMO, whose unique key
      *> Postgres checks only at COMMIT), but this time a WRITE to the
      *> customers file is pending too. The database votes No at the
      *> SYNCPOINT: CICS backs the file update out as well and abends
      *> the task ASP7. No HANDLE ABEND exit is driven for it, and the
      *> SPLC0001 record never reaches the file.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SPLC.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-KEY  PIC X(8)  VALUE 'SPLC0001'.
       01 WS-REC  PIC X(80)
                  VALUE 'SPLC DEMO RECORD - BACKED OUT BY ASP7'.
       01 SCR     PIC X(79).

       PROCEDURE DIVISION.
       MAIN.
           EXEC SQL CREATE TABLE IF NOT EXISTS spdb_demo (id integer,
                CONSTRAINT spdb_demo_u UNIQUE (id)
                DEFERRABLE INITIALLY DEFERRED) END-EXEC.
           EXEC SQL DELETE FROM spdb_demo END-EXEC.
           EXEC CICS SYNCPOINT END-EXEC.
           EXEC CICS WRITE FILE('customers') FROM(WS-REC)
                     RIDFLD(WS-KEY) END-EXEC.
           EXEC SQL INSERT INTO spdb_demo (id) VALUES (2) END-EXEC.
           EXEC SQL INSERT INTO spdb_demo (id) VALUES (2) END-EXEC.
           EXEC CICS SYNCPOINT END-EXEC.
      *> Never reached: the SYNCPOINT above abends the task ASP7.
           MOVE 'SPLC: SYNCPOINT RETURNED - NOT EXPECTED' TO SCR.
           EXEC CICS SEND TEXT FROM(SCR) ERASE END-EXEC.
           EXEC CICS RETURN END-EXEC.
           GOBACK.

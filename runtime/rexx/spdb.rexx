/* SPDB -- abend ASP3 demo (REXX). Table SPDB_DEMO has a unique key  */
/* that Postgres checks only at COMMIT (DEFERRABLE INITIALLY         */
/* DEFERRED), so both INSERTs of key 1 succeed and the SYNCPOINT     */
/* commit is refused with SQLSTATE 23505. Nothing local (file or TS) */
/* was pending, so the database alone backed the unit of work out:   */
/* the task abends ASP3. No HANDLE ABEND exit is driven for it.      */
/* Compare SPLC, where a pending file update makes it ASP7.          */
ADDRESS CICS
EXEC SQL CREATE TABLE IF NOT EXISTS spdb_demo (id integer, CONSTRAINT spdb_demo_u UNIQUE (id) DEFERRABLE INITIALLY DEFERRED) END-EXEC
EXEC SQL DELETE FROM spdb_demo END-EXEC
EXEC CICS SYNCPOINT END-EXEC
EXEC CICS HANDLE ABEND LABEL(CATCH) END-EXEC
EXEC SQL INSERT INTO spdb_demo (id) VALUES (1) END-EXEC
EXEC SQL INSERT INTO spdb_demo (id) VALUES (1) END-EXEC
EXEC CICS SYNCPOINT END-EXEC
/* Never reached: the SYNCPOINT above abends the task ASP3.          */
EXEC CICS SEND TEXT FROM('SPDB: SYNCPOINT RETURNED - NOT EXPECTED') ERASE END-EXEC
EXEC CICS RETURN END-EXEC
EXIT
/* Never reached either: ASP3 drives no HANDLE ABEND exit.           */
CATCH:
EXEC CICS SEND TEXT FROM('SPDB: EXIT RAN - NOT EXPECTED') ERASE END-EXEC
EXEC CICS RETURN END-EXEC

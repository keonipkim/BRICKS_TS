/* ABMR -- abend ABM0 demo (REXX). RECEIVE MAP names the mapset     */
/* HELO1, which exists, and a map NOPE that it does not contain.     */
/* IBM CICS abends the task ABM0 (map not found in the mapset).      */
/* It is an abend, not the MAPFAIL condition: RESP does not absorb   */
/* it, and it ends a REXX task too. A mapset that does not exist at  */
/* all is still the MAPFAIL condition.                               */
ADDRESS CICS
EXEC CICS RECEIVE MAP('NOPE') MAPSET('HELO1') INTO(SCR.) RESP(RCODE) END-EXEC
/* Never reached: the RECEIVE above abends the task ABM0.            */
EXEC CICS SEND TEXT FROM('ABMR: RECEIVE RETURNED - NOT EXPECTED') ERASE END-EXEC
EXEC CICS RETURN END-EXEC

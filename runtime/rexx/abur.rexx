/* ABUR -- user abend demo (REXX). The program ends itself with      */
/* EXEC CICS ABEND ABCODE('USR1'): an application abend code, not a  */
/* CICS one. ABEND with ABCODE and without NODUMP takes a transaction */
/* dump, so the dump is in abend.log; CAID has no rule for a code    */
/* the application invented and lists the typical causes instead.    */
ADDRESS CICS
reason = 'CUSTOMER RECORD MISSING'
count = 0
/* A real program would test a response code here and abend only     */
/* when it cannot carry on; this demo abends unconditionally.        */
/* reason says why; a HANDLE ABEND exit could log it.              */
EXEC CICS ABEND ABCODE('USR1') END-EXEC
EXEC CICS RETURN END-EXEC

       IDENTIFICATION DIVISION.
       PROGRAM-ID. DODFR.
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 REPORT-LINE      PIC X(80).

       PROCEDURE DIVISION.
           EXEC CICS RECEIVE MAP('DODF1') END-EXEC

           MOVE '                          STATEMENT OF SERVICE REPORT' TO REPORT-LINE
           EXEC CICS SEND TEXT FROM(REPORT-LINE) ERASE END-EXEC

           MOVE '             Per DODFMR Chapter 1 - Creditable Service Computation' TO REPORT-LINE
           EXEC CICS SEND TEXT FROM(REPORT-LINE) END-EXEC

           MOVE '================================================================' TO REPORT-LINE
           EXEC CICS SEND TEXT FROM(REPORT-LINE) END-EXEC

           MOVE 'You entered periods - full calculation coming next' TO REPORT-LINE
           EXEC CICS SEND TEXT FROM(REPORT-LINE) END-EXEC

           MOVE 'Press ENTER or PF3 to return to the prompt.' TO REPORT-LINE
           EXEC CICS SEND TEXT FROM(REPORT-LINE) END-EXEC

           EXEC CICS RETURN TRANSID('MYMU') END-EXEC.
       END PROGRAM DODFR.

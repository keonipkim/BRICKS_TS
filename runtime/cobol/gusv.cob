      *> GUSV -- COBOL twin of cusv.rexx. Customer-number validator,
      *> invoked via EXEC CICS LINK PROGRAM('GUSV') COMMAREA(...) from
      *> GUST. Reads the candidate customer number from DFHCOMMAREA,
      *> uppercases it, and writes the cleaned form back. The caller gets
      *> back exactly the 8 bytes it passed (IBM: a LINK cannot change the
      *> COMMAREA length), blank-padded like the REXX twin's STRIP result
      *> once GUST moves it into its PIC X(8) field.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. GUSV.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 KEY-IN PIC X(8).

       PROCEDURE DIVISION.
       MAIN.
           MOVE FUNCTION UPPER-CASE(DFHCOMMAREA) TO KEY-IN.
           DISPLAY 'GUSV: validated customer number = ' KEY-IN.
           MOVE KEY-IN TO DFHCOMMAREA.
           EXEC CICS RETURN END-EXEC.
           GOBACK.

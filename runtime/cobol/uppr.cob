      *> UPPR -- COBOL sample: fold a customer's text to upper case with
      *> the INSPECT ... CONVERTING verb, then show it on a simple map.
      *>
      *> The operator types free-form customer text (any case) into the
      *> CUSTIN field of the UPPR1 map and presses ENTER. INSPECT
      *> CONVERTING maps every lower-case letter to its upper-case
      *> partner through a translation table -- the canonical COBOL
      *> idiom for case folding. (REPLACING only swaps whole literal
      *> runs, so it cannot fold letter-by-letter.) The table covers
      *> a-z plus the 30 Latin-1 lower-case letters (a-grave through
      *> thorn, 56 characters each side): bricks stores program data
      *> one byte per character (Latin-1), so "straße äöü" folds to
      *> "STRAßE ÄÖÜ". Sharp s and y-diaeresis have no single-character
      *> upper case and stay as they are, as on z/OS.
      *> Characters outside the from-set -- digits, spaces, punctuation
      *> -- pass through unchanged. The upper-cased copy is sent back in
      *> CUSTOUT. PF3 at the prompt exits.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. UPPR.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY DFHAID.

      *> SCR is the UPPR1 map IO group. CUSTIN is the unprotected field
      *> the operator types into; CUSTOUT echoes the upper-cased copy;
      *> MSG is the status line.
       01 SCR.
          05 CUSTIN  PIC X(40).
          05 CUSTOUT PIC X(40).
          05 MSG     PIC X(70).

      *> INSPECT CONVERTING translation tables, filled in MAIN.
       01 WS-LOWER PIC X(56).
       01 WS-UPPER PIC X(56).

       PROCEDURE DIVISION.
       MAIN.
           MOVE SPACES TO CUSTIN.
           MOVE SPACES TO CUSTOUT.
           MOVE 'Type customer text (any case), then press ENTER.'
               TO MSG.

      *> Paint the empty form and wait for the operator's input.
           EXEC CICS SEND MAP('UPPR1') FROM(SCR) ERASE END-EXEC.
           EXEC CICS RECEIVE MAP('UPPR1') INTO(SCR) END-EXEC.

      *> PF3 at the prompt leaves the transaction.
           IF EIBAID = PF03 THEN
               EXEC CICS RETURN END-EXEC
           END-IF.

      *> Copy the input, then fold the lower-case letters in place. The
      *> from and to sets are equal length (56 characters, one byte
      *> each) so every letter maps one-for-one. The ASCII and Latin-1
      *> halves are concatenated with STRING because a literal cannot
      *> span source lines.
           MOVE CUSTIN TO CUSTOUT.
           STRING 'abcdefghijklmnopqrstuvwxyz'
                  'àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþ'
                  DELIMITED BY SIZE INTO WS-LOWER.
           STRING 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
                  'ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞ'
                  DELIMITED BY SIZE INTO WS-UPPER.
           INSPECT CUSTOUT CONVERTING WS-LOWER TO WS-UPPER.

           MOVE 'Folded to upper case with INSPECT CONVERTING.'
               TO MSG.

      *> Show the result and end the task; the operator is returned to
      *> the prompt. Type UPPR again to convert another string.
           EXEC CICS SEND MAP('UPPR1') FROM(SCR) END-EXEC.
           EXEC CICS RETURN END-EXEC.
           GOBACK.

      *> DFHVALUE  EXEC CICS CVDA values (QUERY SECURITY).
      *>
      *> COPY DFHVALUE into WORKING-STORAGE SECTION, then compare
      *> the host variables QUERY SECURITY writes against the named
      *> codes instead of bare integers:
      *>
      *>     EXEC CICS QUERY SECURITY RESCLASS('BANK')
      *>                              RESID('ACCOUNT')
      *>                              RESIDLENGTH(7)
      *>                              UPDATE(WS-SEC-CVDA)
      *>                              LOGMESSAGE(DFHVALUE(LOG))
      *>                              END-EXEC.
      *>     IF WS-SEC-CVDA = DFHVALUE-UPDATABLE THEN ...
      *>     IF WS-SEC-CVDA = UPDATABLE          THEN ...
      *>
      *> Every code is declared twice -- once under the short name
      *> (READABLE, NOTREADABLE, UPDATABLE, ...) and once under the
      *> IBM-traditional DFHVALUE-prefixed alias.  Both forms hold
      *> the same value, so programs may pick either style or mix
      *> them.  The inline DFHVALUE(name) form works too.
      *>
      *> The numbers are IBM's CVDA values:
      *>
      *>   READ     35 READABLE    / 36 NOTREADABLE
      *>   UPDATE   37 UPDATABLE   / 38 NOTUPDATABLE
      *>   CONTROL  56 CTRLABLE    / 57 NOTCTRLABLE
      *>   ALTER    52 ALTERABLE   / 53 NOTALTERABLE
      *>   LOGMESSAGE input: 54 LOG / 55 NOLOG
      *>
      *> Access levels nest ALTER > CONTROL > UPDATE > READ and come
      *> from runtime/security.conf (or, for transactions and
      *> programs, from transactions.conf).
      *>
      *> ====================================================================
      *> IMPORTANT  --  bricks decimal-text deviation from IBM canonical
      *> ====================================================================
      *> On a z/OS CICS region these constants are usually declared as
      *> PIC S9(8) COMP (a 4-byte binary fullword), matching the
      *> COMP-format integer the host variables receive from QUERY
      *> SECURITY.  Bricks ships the constants as PIC S9(8) VALUE
      *> (DISPLAY, decimal-text) instead.
      *>
      *> Reason: the bricks COBOL -> cics bridge resolves every
      *> EXEC CICS host variable as DISPLAY text (the same convention
      *> the ESDS RBA host-var lesson documents).  A target variable
      *> declared
      *>     PIC S9(8)               -- DISPLAY, "00000037"
      *> receives decimal text from the bridge; a later
      *>     IF WS-SEC-CVDA = DFHVALUE-UPDATABLE
      *> comparison must therefore have DFHVALUE-UPDATABLE in the
      *> SAME representation, hence VALUE 37 (DISPLAY), not COMP 37.
      *>
      *> Operators who reflexively declare the target host variable
      *> AND the constant as PIC S9(8) COMP -- IBM-canonical for
      *> 30 years -- will hit the decimal-text-vs-binary mismatch:
      *> the IF-equals always falls false.  Use PIC S9(8) on the
      *> target (DISPLAY) to match.
       01 READABLE              PIC S9(8) VALUE 35.
       01 DFHVALUE-READABLE     PIC S9(8) VALUE 35.
       01 NOTREADABLE           PIC S9(8) VALUE 36.
       01 DFHVALUE-NOTREADABLE  PIC S9(8) VALUE 36.
       01 UPDATABLE             PIC S9(8) VALUE 37.
       01 DFHVALUE-UPDATABLE    PIC S9(8) VALUE 37.
       01 NOTUPDATABLE          PIC S9(8) VALUE 38.
       01 DFHVALUE-NOTUPDATABLE PIC S9(8) VALUE 38.
       01 ALTERABLE             PIC S9(8) VALUE 52.
       01 DFHVALUE-ALTERABLE    PIC S9(8) VALUE 52.
       01 NOTALTERABLE          PIC S9(8) VALUE 53.
       01 DFHVALUE-NOTALTERABLE PIC S9(8) VALUE 53.
       01 LOG                   PIC S9(8) VALUE 54.
       01 DFHVALUE-LOG          PIC S9(8) VALUE 54.
       01 NOLOG                 PIC S9(8) VALUE 55.
       01 DFHVALUE-NOLOG        PIC S9(8) VALUE 55.
       01 CTRLABLE              PIC S9(8) VALUE 56.
       01 DFHVALUE-CTRLABLE     PIC S9(8) VALUE 56.
       01 NOTCTRLABLE           PIC S9(8) VALUE 57.
       01 DFHVALUE-NOTCTRLABLE  PIC S9(8) VALUE 57.

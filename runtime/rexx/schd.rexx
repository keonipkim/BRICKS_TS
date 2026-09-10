/* SCHD -- demo of three new bricks features, in one transaction.      */
/*                                                                     */
/*   1. EXEC CICS START ... AFTER SECONDS(n)                           */
/*      the composite fire-time form of START                          */
/*   2. ADDRESS()                                                      */
/*      the current host-command environment                           */
/*   3. SYMBOL(name)                                                   */
/*      probe a name: VAR, LIT or BAD                                  */
/*                                                                     */
/* Type SCHD at the prompt. The program probes ADDRESS() and SYMBOL(), */
/* paints one PASS/FAIL row per check, then schedules ITSELF to run    */
/* again with EXEC CICS START AFTER SECONDS(...).                      */
/*                                                                     */
/* Two paths in one program, the same shape TIMR uses:                 */
/*   Cold start -- RETRIEVE gives RESP=29 (ENDDATA). Run the checks,   */
/*                 then START AFTER SECONDS(n) with a payload.         */
/*   Timer fire -- RETRIEVE gives RESP=0 and the payload. Report the   */
/*                 wake-up and stop. No reschedule, so no loop.        */
/*                                                                     */
/* Why AFTER matters: before it existed a program had to hand-pack     */
/* HHMMSS for INTERVAL(...) -- see the HH/MM/SS arithmetic in          */
/* timr.rexx. AFTER takes additive counts, not clock digits, so        */
/* SECONDS(90) is a minute and a half rather than an invalid value.    */
/*                                                                     */
/* 3270 has no line feed: every logical row is LEFT-padded to 80 and   */
/* concatenated into one flat row-major buffer for SEND TEXT.          */

ADDRESS CICS

/* ---- which of the two paths is this run? -------------------------- */
/* RETRIEVE hands back the FROM(...) payload of the START that queued  */
/* this run. RESP=29 (ENDDATA) means nothing queued us: cold start.    */
BUF = ''
EXEC CICS RETRIEVE INTO(BUF) END-EXEC
FIRED = 0
IF EIBRESP = 0 THEN FIRED = 1

IF FIRED = 1 THEN DO
  TXT = LEFT('SCHD -- woken by EXEC CICS START AFTER SECONDS', 80)
  TXT = TXT || LEFT('', 80)
  TXT = TXT || LEFT('Payload from FROM(...):  ' || BUF, 80)
  TXT = TXT || LEFT('ADDRESS() on this run:   ' || ADDRESS(), 80)
  TXT = TXT || LEFT('', 80)
  TXT = TXT || LEFT('This run issued no START, so the demo ends here.', 80)
  TXT = TXT || LEFT('Press CLEAR to exit.', 80)
  EXEC CICS SEND TEXT FROM(TXT) ERASE END-EXEC
  EXEC CICS RETURN END-EXEC
END

/* ---- 2. ADDRESS() ------------------------------------------------- */
/* Bare ADDRESS() names the environment host commands are sent to.     */
/* Under bricks that is CICS, established when the program starts.     */
ENV = ADDRESS()
T1 = 'FAIL'
IF ENV = 'CICS' THEN T1 = 'PASS'

/* A PROCEDURE may switch environments for its own duration; the       */
/* caller's environment is restored on RETURN. PROBEADDR reports what  */
/* it saw from the inside, and we confirm ours survived the call.      */
INNER = PROBEADDR()
T2 = 'FAIL'
IF INNER = 'SYSTEM' & ADDRESS() = 'CICS' THEN T2 = 'PASS'

/* ---- 3. SYMBOL() -------------------------------------------------- */
/* SYMBOL takes the STRING its argument evaluates to and asks what     */
/* that name is:                                                       */
/*   VAR -- a valid symbol that has been assigned a value              */
/*   LIT -- a valid symbol with no value, or a constant symbol         */
/*   BAD -- not a valid REXX symbol at all                             */
CUSTNM = 'ACME'
S1 = SYMBOL('CUSTNM')          /* assigned            gives VAR */
S2 = SYMBOL('NOSUCH')          /* never assigned      gives LIT */
S3 = SYMBOL('A B')             /* a blank is illegal  gives BAD */
T3 = 'FAIL'
IF S1 = 'VAR' & S2 = 'LIT' & S3 = 'BAD' THEN T3 = 'PASS'

/* Two-step evaluation, the part that trips people up. SYMBOL(CUSTNM)  */
/* tests the name ACME -- the VALUE of CUSTNM -- not CUSTNM itself.    */
/* ACME was never assigned, so the answer is LIT. Quoting the name     */
/* instead, SYMBOL('CUSTNM'), is what tests CUSTNM.                    */
S4 = SYMBOL(CUSTNM)
T4 = 'FAIL'
IF S4 = 'LIT' THEN T4 = 'PASS'

/* Compound tails are derived before the lookup, exactly as a source   */
/* level RATE.J reference would be: with J = 3 the name tested is      */
/* RATE.3. With K unset, RATE.K stays RATE.K and has no value.         */
J = 3
RATE.3 = '4.25'
S5 = SYMBOL('RATE.J')
S6 = SYMBOL('RATE.K')
T5 = 'FAIL'
IF S5 = 'VAR' & S6 = 'LIT' THEN T5 = 'PASS'

/* The practical idiom: probe a name before using it, with no NOVALUE  */
/* trap and no sentinel value. OPTDELAY is not set anywhere in this    */
/* program, so the ELSE arm supplies the default.                      */
IF SYMBOL('OPTDELAY') = 'VAR' THEN DELAYSECS = OPTDELAY
ELSE DELAYSECS = 10

/* ---- 1. EXEC CICS START ... AFTER SECONDS(n) ---------------------- */
/* Additive counts, not clock digits -- no HHMMSS packing. The task    */
/* fires against this terminal DELAYSECS from now and re-enters SCHD   */
/* on the timer-fire path above.                                       */
PAYLOAD = 'queued by SCHD with AFTER SECONDS(' || DELAYSECS || ')'
EXEC CICS START TRANSID('SCHD') AFTER SECONDS(DELAYSECS) FROM(PAYLOAD) END-EXEC
T6 = 'FAIL'
IF EIBRESP = 0 THEN T6 = 'PASS'

/* ---- paint the results as 80-column rows -------------------------- */
TXT = LEFT('SCHD -- START AFTER, ADDRESS() and SYMBOL() demo', 80)
TXT = TXT || LEFT('', 80)
TXT = TXT || LEFT('1. ADDRESS() reports              ' || LEFT(ENV, 10) || T1, 80)
TXT = TXT || LEFT('2. ADDRESS() restored after call  ' || LEFT(INNER, 10) || T2, 80)
TXT = TXT || LEFT('3. SYMBOL() VAR / LIT / BAD       ' || LEFT(S1 S2 S3, 10) || T3, 80)
TXT = TXT || LEFT('4. SYMBOL() two-step evaluation   ' || LEFT(S4, 10) || T4, 80)
TXT = TXT || LEFT('5. SYMBOL() derived compound tail ' || LEFT(S5 S6, 10) || T5, 80)
TXT = TXT || LEFT('6. START AFTER SECONDS accepted   ' || LEFT(EIBRESP, 10) || T6, 80)
TXT = TXT || LEFT('', 80)
TXT = TXT || LEFT('SCHD will run again in ' || DELAYSECS || ' seconds on this terminal.', 80)
TXT = TXT || LEFT('Press CLEAR to exit.', 80)

EXEC CICS SEND TEXT FROM(TXT) ERASE END-EXEC
EXEC CICS RETURN END-EXEC
EXIT

/* -- internal routine, callable as a function ----------------------- */
/* Switches its own host-command environment and reports what          */
/* ADDRESS() sees from in here. The switch dies with the RETURN.       */
PROBEADDR: PROCEDURE
  ADDRESS SYSTEM
  RETURN ADDRESS()

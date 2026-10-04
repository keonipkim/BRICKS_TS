      *> TODO -- multi-user, multi-list to-do REST API (WAPI + VSAM).
      *>
      *> This program serves every /api/todo/... route in web_routes.conf.
      *> It works out what was asked from the HTTP get method plus the shape
      *> of the path (EVALUATE WS-SHAPE ALSO WS-METHOD in MAIN), so the
      *> routing table and this program have to agree.
      *>
      *>   users > lists > items      (each user only ever sees their own)
      *>
      *> Files (bbolt KSDS, created on first WRITE):
      *>   TODOUSR  key user(16)
      *>   TODOLST  key user(16) list 9(6)
      *>   TODOITM  key user(16) list 9(6) item 9(8)
      *> Every key part is fixed width and space padded, so user "bob"
      *> never runs into "bobby" as long as we always compare the
      *> whople fixed width part during a browse (see COLLECT-ITEMS /
      *> DO-LISTS-GET). IBM's CICS right-trims keys and records at the
      *> boundary, which is harmless: the last key part is numeric, or
      *> it is the user id which is trimmed the same way.
      *>
      *> Auth: POST /users carries user + key in the body. Every other
      *> call needs X-Todo-User and X-Todo-Key headers. Passwords are
      *> never stored, only a toy digest (see COMPUTE-DIGEST).
      *>
      *> Request bodies: application/x-www-form-urlencoded as before, or
      *> application/json. A JSON body is taken apart once with JSON
      *> PARSE into JI-REC (CHECK-BODY); READ-FIELD then hands out the
      *> fields the same way for both, so every validation rule below
      *> applies unchanged whatever the client sent.
      *>
      *> Unit of work rules: all input is validated BEFORE the first file
      *> update, because a COBOL runtime error (bad NUMVAL, refmod out of
      *> range...) ends the task without backout. Any unexpected RESP
      *> after an update does SYNCPOINT ROLLBACK and answers 500 IOERR.
      *> Lock order is item -> list -> user, except for purge and the
      *> list cascade delete, which take the list (and, for the cascade,
      *> the user) first and then lock items. bricks READ UPDATE never
      *> waits, so the worst case is a 409 BUSY, never a deadlock. The
      *> lock that guards an invariant is always let go by the LAST
      *> write of the UOW (child WRITE first, parent REWRITE last).
      *>
      *> Rseponses: every JSON object is made by JSON GENERATE from a
      *> small flat JO-* record (lower-case names via NAME OF, item
      *> "done" via CONVERTING ... TO JSON BOOLEAN). Arrays and the few
      *> envelopes that wrap them are glued together with STRING ...
      *> WITH POINTER (yeah!), because bricks has no OCCURS DEPENDING ON and a
      *> fixed OCCURS 200 table would always come out with 200 entries.
      *> The finished body goes out in ONE WEB SEND at the very end,
      *> since only the first SEND sets the status code.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TODO.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY DFHRESP.

      *> ---- request ---------------------------------------------------
       01 WS-METHOD      PIC X(10).
       01 WS-PATH        PIC X(512).
       01 WS-REST        PIC X(512).
       01 WS-SEG1        PIC X(64).
       01 WS-SEG2        PIC X(64).
       01 WS-SEG3        PIC X(64).
       01 WS-SEG4        PIC X(64).
       01 WS-SEG5        PIC X(64).
       01 WS-SEG6        PIC X(64).
       01 WS-SHAPE       PIC X(8).
       01 WS-BODY        PIC X(4096).
       01 WS-BODY-LEN    PIC 9(5).
       01 WS-CTYPE       PIC X(128).
       01 WS-JSON-IN     PIC X VALUE 'N'.
       01 WS-QS          PIC X(4096).
       01 WS-QS-LEN      PIC 9(6).
       01 VT-BUF         PIC X(4096).
       01 VT-LEN         PIC 9(5).
       01 VT-OK          PIC X.
      *> raw {list} / {id} path captures (bricks lets a capture win over
      *> a query param of the same name)
       01 CAP-LIST       PIC X(64).
       01 CAP-LIST-LEN   PIC 9(5).
       01 CAP-LIST-SET   PIC X.
       01 CAP-ID         PIC X(64).
       01 CAP-ID-LEN     PIC 9(5).
       01 CAP-ID-SET     PIC X.
       01 WS-TRY         PIC 9.

      *> ---- JSON request body (JSON PARSE target) ---------------------
      *> Everything starts as LOW-VALUES; a member the client did not
      *> send stays LOW-VALUES, which is how READ-FIELD tells "absent"
      *> from "sent but empty". EVERY member is as wide as the body can
      *> be (4096), so JSON PARSE never cuts a value short and the
      *> validators see exactly what was sent, 2      junk" must fail
      *> as a version just like it does in a form body.
       01 JI-REC.
          05 JI-USER       PIC X(4096).
          05 JI-KEY        PIC X(4096).
          05 JI-NAME       PIC X(4096).
          05 JI-TITLE      PIC X(4096).
          05 JI-PRIO       PIC X(4096).
          05 JI-VERSION    PIC X(4096).
          05 JI-DONE       PIC X(4096).
       01 JI-REV         PIC X(4096).
       01 JI-TRAIL       PIC 9(5).

      *> authenticated caller  
       01 AU-USER        PIC X(16).
       01 AU-KEY         PIC X(128).
       01 WS-AUTH-OK     PIC X.

      *>  validation scratch
       01 V-IN           PIC X(64).
       01 V-LEN          PIC 9(5).
       01 V-OK           PIC X.
       01 V-OUT          PIC X(32).
       01 V-I            PIC 9(5).
       01 T-IN           PIC X(4096).
       01 T-LEN          PIC 9(5).
       01 T-TLEN         PIC 9(5).
       01 T-MAX          PIC 9(3).
       01 T-OK           PIC X.
       01 T-OUT          PIC X(128).
       01 N-IN           PIC X(64).
       01 N-LEN          PIC 9(5).
       01 N-MAX          PIC 9(2).
       01 N-OK           PIC X.
       01 N-VAL          PIC 9(8).
       01 F-NAME         PIC X(16).
       01 F-FOUND        PIC X.

       01 WS-LOWER       PIC X(26) VALUE 'abcdefghijklmnopqrstuvwxyz'.
       01 WS-IDCH        PIC X(37)
                         VALUE 'abcdefghijklmnopqrstuvwxyz0123456789-'.
       01 WS-DIGITS      PIC X(10) VALUE '0123456789'.
       01 WS-HEX         PIC X(22) VALUE '0123456789abcdefABCDEF'.

      *> x'21' thru x'7E' in order. POS() into this string is our
      *> stand-in for ORD (bricks has no ORD intrinsic): '!' = 1 ... '~' = 94.
       01 WS-PRINT       PIC X(94) VALUE
          '!"#$%&''()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~'.
      
      *> same again with the blank in front, for the digest char codes
      *> (passwords may contain spaces): ' ' = 1, '!' = 2 ... '~' = 95.
       01 WS-PRINT95     PIC X(95) VALUE
          ' !"#$%&''()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~'.

      *> parsed parameters
       01 P-LIST         PIC 9(6).
       01 P-ITEM         PIC 9(8).
       01 P-VERSION      PIC 9(6).
       01 P-VER-SET      PIC X.
       01 P-TITLE        PIC X(80).
       01 P-TITLE-SET    PIC X.
       01 P-DONE         PIC X.
       01 P-DONE-SET     PIC X.
       01 P-PRIO         PIC X.
       01 P-PRIO-SET     PIC X.
       01 P-NAME         PIC X(40).
       01 P-FILTER       PIC X(4).
       01 WS-DCHG        PIC X.

      *> keys
       01 K-USR          PIC X(16).
       01 K-LST.
          05 K-LST-USR   PIC X(16).
          05 K-LST-ID    PIC 9(6).
       01 K-ITM.
          05 K-ITM-USR   PIC X(16).
          05 K-ITM-LST   PIC 9(6).
          05 K-ITM-ID    PIC 9(8).
       01 K-BR           PIC X(30).

      *> rceords
       01 USR-REC.
          05 USR-ID        PIC X(16).
          05 USR-DIGEST    PIC 9(18).
          05 USR-NEXTLIST  PIC 9(6).
          05 USR-LISTS     PIC 9(3).
          05 USR-CREATED   PIC X(19).
       01 LST-REC.
          05 LST-KEY.
             10 LST-USER   PIC X(16).
             10 LST-ID     PIC 9(6).
          05 LST-NEXTITEM  PIC 9(8).
          05 LST-COUNT     PIC 9(5).
          05 LST-DONE      PIC 9(5).
          05 LST-VERSION   PIC 9(6).
          05 LST-CREATED   PIC X(19).
          05 LST-UPDATED   PIC X(19).
          05 LST-NAME      PIC X(40).
       01 ITM-REC.
          05 ITM-KEY.
             10 ITM-USER   PIC X(16).
             10 ITM-LIST   PIC 9(6).
             10 ITM-ID     PIC 9(8).
          05 ITM-DONE      PIC X.
          05 ITM-PRIO      PIC X.
          05 ITM-VERSION   PIC 9(6).
          05 ITM-CREATED   PIC X(19).
          05 ITM-UPDATED   PIC X(19).
          05 ITM-TITLE     PIC X(80).

      *> id table for purge / cascade delee
       01 WS-IDTAB.
          05 WS-TID        PIC 9(8) OCCURS 200 TIMES.
       01 WS-TN          PIC 9(4).
       01 WS-TI          PIC 9(4).
       01 WS-TOVER       PIC X.
       01 WS-ALLDONE     PIC X.
       01 WS-BR-END      PIC X.
       01 WS-BR-BAD      PIC X.
       01 WS-COUNT       PIC 9(5).
       01 WS-DELN        PIC 9(5).

      *> digest
       01 DG-SRC         PIC X(160).
       01 DG-LEN         PIC 9(4).
       01 DG-PTR         PIC 9(4).
       01 DG-PIECE       PIC X(128).
       01 DG-PLEN        PIC 9(4).
       01 DG-I           PIC 9(4).
       01 DG-C           PIC 9(4).
       01 DG-H1          PIC 9(12).
       01 DG-H2          PIC 9(12).
       01 DG-T           PIC 9(15).
       01 DG-Q           PIC 9(15).
       01 DG-P1          PIC 9(9) VALUE 999999937.
       01 DG-P2          PIC 9(9) VALUE 999999929.
       01 DG-DIGEST      PIC 9(18).

      *>    tjhe time
       01 WS-ABS         PIC 9(15).
       01 WS-DATE        PIC X(10).
       01 WS-TIME        PIC X(8).
       01 WS-NOW         PIC X(19).

      *> JSON output records (one JSON GENERATE each)
      *> Stamps are X(20): the stored X(19) UTC stamp plus a 'Z'.
       01 JO-LIST.
          05 JO-L-ID       PIC 9(6).
          05 JO-L-NAME     PIC X(40).
          05 JO-L-COUNT    PIC 9(5).
          05 JO-L-DONE     PIC 9(5).
          05 JO-L-VERSION  PIC 9(6).
          05 JO-L-CREATED  PIC X(20).
          05 JO-L-UPDATED  PIC X(20).
       01 JO-ITEM.
          05 JO-I-ID       PIC 9(8).
          05 JO-I-LIST     PIC 9(6).
          05 JO-I-TITLE    PIC X(80).
          05 JO-I-DONE     PIC X.
          05 JO-I-PRIO     PIC X.
          05 JO-I-VERSION  PIC 9(6).
          05 JO-I-CREATED  PIC X(20).
          05 JO-I-UPDATED  PIC X(20).
       01 JO-ME.
          05 JO-M-USER     PIC X(16).
          05 JO-M-LISTS    PIC 9(3).
          05 JO-M-CREATED  PIC X(20).
       01 JO-USER.
          05 JO-U-USER     PIC X(16).
       01 JO-COUNT.
          05 JO-C-COUNT    PIC 9(5).
       01 JO-DEL.
          05 JO-D-DELETED  PIC 9(8).
       01 JO-LDEL.
          05 JO-LD-DELETED PIC 9(6).
          05 JO-LD-ITEMS   PIC 9(5).
       01 JO-ERR.
          05 JO-ERROR.
             10 JO-E-CODE  PIC X(16).
             10 JO-E-MSG   PIC X(80).

      *> response
       01 WS-RESP        PIC S9(8).
       01 WS-RESP2       PIC S9(8).
       01 WS-ERR         PIC X.
       01 WS-STATUS      PIC 9(3).
       01 WS-FILE        PIC X(8).
       01 E-CODE         PIC X(16).
       01 E-MSG          PIC X(80).
       01 E-CUR          PIC X.
       01 JSON-BUF       PIC X(64000).
       01 JS-PTR         PIC 9(6).
       01 JS-LEN         PIC 9(6).
       01 JS-PIECE       PIC X(512).
       01 JS-PLEN        PIC 9(4).
       01 JS-FIRST       PIC X.
       01 WS-JSFAIL      PIC X VALUE 'N'.
       01 JS-NUM         PIC 9(18).
       01 JS-ED          PIC Z(17)9.
       01 JS-NUMTXT      PIC X(18).

       PROCEDURE DIVISION.
       MAIN.
           MOVE 'N' TO WS-ERR.
           MOVE 1 TO JS-PTR.
           MOVE SPACE TO E-CUR.
           MOVE 200 TO WS-STATUS.
           EXEC CICS WEB EXTRACT HTTPMETHOD(WS-METHOD) PATH(WS-PATH)
                RESP(WS-RESP) END-EXEC.
           PERFORM PARSE-ROUTE.
      *> size check comes before anything else for POST/PUT.
           IF WS-METHOD = 'POST' OR 'PUT'
               PERFORM CHECK-BODY
           END-IF.
           IF WS-ERR = 'N'
               PERFORM CHECK-QUERY
           END-IF.
           IF WS-ERR = 'N'
               PERFORM READ-CAPTURES
           END-IF.
           IF WS-ERR = 'N'
               EVALUATE WS-SHAPE ALSO WS-METHOD
                   WHEN 'USERS' ALSO 'POST'   PERFORM DO-NEW-USER
                   WHEN 'ME'    ALSO 'GET'    PERFORM DO-ME
                   WHEN 'LISTS' ALSO 'GET'    PERFORM DO-LISTS-GET
                   WHEN 'LISTS' ALSO 'POST'   PERFORM DO-LIST-CREATE
                   WHEN 'LIST'  ALSO 'PUT'    PERFORM DO-LIST-PUT
                   WHEN 'LIST'  ALSO 'DELETE' PERFORM DO-LIST-DELETE
                   WHEN 'ITEMS' ALSO 'GET'    PERFORM DO-ITEMS-GET
                   WHEN 'ITEMS' ALSO 'POST'   PERFORM DO-ITEM-CREATE
                   WHEN 'PURGE' ALSO 'POST'   PERFORM DO-PURGE
                   WHEN 'ITEM'  ALSO 'GET'    PERFORM DO-ITEM-GET
                   WHEN 'ITEM'  ALSO 'PUT'    PERFORM DO-ITEM-PUT
                   WHEN 'ITEM'  ALSO 'DELETE' PERFORM DO-ITEM-DELETE
                   WHEN OTHER                 PERFORM BAD-METHOD
               END-EVALUATE
           END-IF.
           PERFORM SEND-RESPONSE.
           EXEC CICS RETURN END-EXEC.
           GOBACK.


      *> Routnng helpers
      *> 
       PARSE-ROUTE.
      *> Split whatever follows /api/todo/ on '/' and name the shape.
      *> The shape decides the handler; the {list} / {id} values
      *> themselves come from the route captures (READ-CAPTURES) and
      *> must match these segments, so ?list= in the query can't win.
           MOVE SPACES TO WS-SEG1 WS-SEG2 WS-SEG3 WS-SEG4 WS-SEG5 WS-SEG6.
           MOVE SPACES TO WS-SHAPE WS-REST.
           MOVE FUNCTION UPPER-CASE(WS-METHOD) TO WS-METHOD.
           IF WS-PATH(1:10) = '/api/todo/'
               MOVE WS-PATH(11:500) TO WS-REST
               UNSTRING WS-REST DELIMITED BY '/'
                   INTO WS-SEG1 WS-SEG2 WS-SEG3 WS-SEG4 WS-SEG5 WS-SEG6
               END-UNSTRING
           END-IF.
           EVALUATE TRUE
               WHEN WS-SEG5 NOT = SPACES OR WS-SEG6 NOT = SPACES
                   CONTINUE
               WHEN WS-SEG1 = 'users' AND WS-SEG2 = SPACES
                   MOVE 'USERS' TO WS-SHAPE
               WHEN WS-SEG1 = 'me' AND WS-SEG2 = SPACES
                   MOVE 'ME' TO WS-SHAPE
               WHEN WS-SEG1 NOT = 'lists'
                   CONTINUE
               WHEN WS-SEG2 = SPACES
                   MOVE 'LISTS' TO WS-SHAPE
               WHEN WS-SEG3 = SPACES
                   MOVE 'LIST' TO WS-SHAPE
               WHEN WS-SEG3 = 'items' AND WS-SEG4 = SPACES
                   MOVE 'ITEMS' TO WS-SHAPE
               WHEN WS-SEG3 = 'purge' AND WS-SEG4 = SPACES
                   MOVE 'PURGE' TO WS-SHAPE
               WHEN WS-SEG3 = 'items'
                   MOVE 'ITEM' TO WS-SHAPE
           END-EVALUATE.

       BAD-METHOD.
           MOVE 405 TO WS-STATUS.
           MOVE 'BADMETHOD' TO E-CODE.
           MOVE 'method not allowed for this path' TO E-MSG.
           PERFORM SET-ERR.

       CHECK-BODY.
      *> Recieve the raw body first so oversized requests are turned
      *> away (413) before we look at a single field.
           MOVE SPACES TO WS-BODY WS-CTYPE.
           MOVE 0 TO WS-BODY-LEN.
           EXEC CICS WEB RECEIVE INTO(WS-BODY) MAXLENGTH(4096)
                LENGTH(WS-BODY-LEN) MEDIATYPE(WS-CTYPE)
                RESP(WS-RESP) END-EXEC.
           IF WS-RESP = DFHRESP(LENGERR)
               MOVE 413 TO WS-STATUS
               MOVE 'TOOLARGE' TO E-CODE
               MOVE 'request body is over 4096 bytes' TO E-MSG
               PERFORM SET-ERR
               EXIT PARAGRAPH
           END-IF.
           IF WS-RESP NOT = DFHRESP(NORMAL)
               MOVE 0 TO WS-BODY-LEN
           END-IF.
           MOVE FUNCTION LOWER-CASE(WS-CTYPE) TO WS-CTYPE.
      *> "application/json", optionally followed by "; charset=..."
           IF WS-CTYPE(1:16) = 'application/json'
              AND (WS-CTYPE(17:1) = SPACE OR ';')
               PERFORM PARSE-JSON-BODY
               EXIT PARAGRAPH
           END-IF.
      *> In go the url.ParseQuery (used by WEB READ FORMFIELD) quietly drops
      *> a pair with a bad %xx escape or a ';' in it -- the field just
      *> looks absent. Better to tell the client their body is broken
      *> than to act on half of it, so we check it here first.
           MOVE WS-BODY TO VT-BUF.
           MOVE WS-BODY-LEN TO VT-LEN.
           PERFORM VET-ENCODED.
           IF VT-OK = 'N'
               MOVE 400 TO WS-STATUS
               MOVE 'BADBODY' TO E-CODE
               MOVE 'malformed form body' TO E-MSG
               PERFORM SET-ERR
           END-IF.

       PARSE-JSON-BODY.
      *> One JSON PARSE for every endpoint; members an endpoint doesn't
      *> use are simply never asked for. An empty body counts as {} so a
      *> client that always sends the JSON content type can still purge.
      *> JSON-CODE 106 ("no member matched anything", e.g. {}) is not an
      *> error for us either -- the handler's own checks decide.
           MOVE 'Y' TO WS-JSON-IN.
           MOVE LOW-VALUES TO JI-REC.
           IF WS-BODY-LEN = 0
               EXIT PARAGRAPH
           END-IF.
           JSON PARSE WS-BODY INTO JI-REC
               NAME OF JI-REC IS OMITTED
                    JI-USER IS 'user' JI-KEY IS 'key' JI-NAME IS 'name'
                    JI-TITLE IS 'title' JI-PRIO IS 'priority'
                    JI-VERSION IS 'version' JI-DONE IS 'done'
               CONVERTING JI-DONE FROM JSON BOOLEAN USING 'true' AND 'false'
               ON EXCEPTION
                   IF JSON-CODE NOT = 106
                       MOVE 400 TO WS-STATUS
                       MOVE 'BADBODY' TO E-CODE
                       MOVE 'malformed JSON body' TO E-MSG
                       PERFORM SET-ERR
                   END-IF
           END-JSON.

       CHECK-QUERY.
      *> Same story for the query string: ?version=%zz would otherwise
      *> just vanish and a DELETE would go ahead with no version check.
           MOVE SPACES TO WS-QS.
           MOVE 0 TO WS-QS-LEN.
           EXEC CICS WEB EXTRACT QUERYSTRING(WS-QS)
                QUERYSTRINGLENGTH(WS-QS-LEN) RESP(WS-RESP) END-EXEC.
           IF WS-RESP NOT = DFHRESP(NORMAL)
               MOVE 0 TO WS-QS-LEN
           END-IF.
           MOVE 'Y' TO VT-OK.
           IF WS-QS-LEN > 4096
               MOVE 'N' TO VT-OK
           ELSE
               MOVE WS-QS TO VT-BUF
               MOVE WS-QS-LEN TO VT-LEN
               PERFORM VET-ENCODED
           END-IF.
           IF VT-OK = 'N'
               MOVE 400 TO WS-STATUS
               MOVE 'BADQUERY' TO E-CODE
               MOVE 'malformed query string' TO E-MSG
               PERFORM SET-ERR
           END-IF.

       VET-ENCODED.
      *> VT-BUF(1:VT-LEN) must be clean form encoding: no ';' and every
      *> '%' followed by two hex digits. Result in VT-OK.
           MOVE 'Y' TO VT-OK.
           PERFORM VARYING V-I FROM 1 BY 1
                   UNTIL V-I > VT-LEN OR VT-OK = 'N'
               EVALUATE TRUE
                   WHEN VT-BUF(V-I:1) = ';'
                       MOVE 'N' TO VT-OK
                   WHEN VT-BUF(V-I:1) NOT = '%'
                       CONTINUE
                   WHEN V-I + 2 > VT-LEN
                       MOVE 'N' TO VT-OK
                   WHEN FUNCTION POS(VT-BUF(V-I + 1:1), WS-HEX) = 0
                     OR FUNCTION POS(VT-BUF(V-I + 2:1), WS-HEX) = 0
                       MOVE 'N' TO VT-OK
               END-EVALUATE
           END-PERFORM.

       READ-CAPTURES.
      *> The route table matches on the ESCAPED path, so /lists/1%2Fitems
      *> %2F2 matches the {list} route with list = "1/items/2", while the
      *> decoded PATH we split on looks like an item URL, wich it isn't.
      *> Any '/' in a capture means an encoded slash -> 400 BADID before
      *> we dispatch.
           MOVE 'list' TO F-NAME.
           PERFORM READ-QPARM.
           MOVE F-FOUND TO CAP-LIST-SET.
           MOVE T-LEN TO CAP-LIST-LEN.
           MOVE T-IN TO CAP-LIST.
           IF F-FOUND = 'Y' AND FUNCTION POS('/', T-IN) > 0
               PERFORM ERR-SLASH
               EXIT PARAGRAPH
           END-IF.
           MOVE 'id' TO F-NAME.
           PERFORM READ-QPARM.
           MOVE F-FOUND TO CAP-ID-SET.
           MOVE T-LEN TO CAP-ID-LEN.
           MOVE T-IN TO CAP-ID.
           IF F-FOUND = 'Y' AND FUNCTION POS('/', T-IN) > 0
               PERFORM ERR-SLASH
           END-IF.

       ERR-SLASH.
           MOVE 400 TO WS-STATUS.
           MOVE 'BADID' TO E-CODE.
           MOVE 'encoded slash in list or item id' TO E-MSG.
           PERFORM SET-ERR.


      *> POST /api/todo/users   body: user, key
      *> One UOW: WRITE the user, WRITE their first list "My tasks".

       DO-NEW-USER.
           MOVE 'user' TO F-NAME.
           PERFORM READ-FIELD.
           PERFORM T-TO-V.
           PERFORM CHECK-NAME-ID.
           IF V-OK = 'N'
               MOVE 400 TO WS-STATUS
               MOVE 'BADUSER' TO E-CODE
               MOVE 'user name must be 1-16 chars a-z 0-9 - starting with a letter'
                   TO E-MSG
               PERFORM SET-ERR
               EXIT PARAGRAPH
           END-IF.
           MOVE V-OUT TO AU-USER.
           MOVE 'key' TO F-NAME.
           PERFORM READ-FIELD.
           PERFORM CHECK-KEY.
           IF T-OK = 'N'
               PERFORM ERR-BADKEY
               EXIT PARAGRAPH
           END-IF.
           MOVE T-OUT TO AU-KEY.
           PERFORM COMPUTE-DIGEST.
           PERFORM GET-NOW.
           MOVE SPACES TO USR-REC.
           MOVE AU-USER TO USR-ID.
           MOVE DG-DIGEST TO USR-DIGEST.
           MOVE 1 TO USR-NEXTLIST.
           MOVE 1 TO USR-LISTS.
           MOVE WS-NOW TO USR-CREATED.
           MOVE 'TODOUSR' TO WS-FILE.
           EXEC CICS WRITE FILE('TODOUSR') FROM(USR-REC) RIDFLD(USR-ID)
                RESP(WS-RESP) END-EXEC.
           EVALUATE WS-RESP
               WHEN DFHRESP(NORMAL)
                   CONTINUE
               WHEN DFHRESP(DUPREC)
                   MOVE 409 TO WS-STATUS
                   MOVE 'EXISTS' TO E-CODE
                   MOVE 'user already exists' TO E-MSG
                   PERFORM SET-ERR
                   EXIT PARAGRAPH
               WHEN OTHER
                   PERFORM FAIL-IO
                   EXIT PARAGRAPH
           END-EVALUATE.
      *> The user record is written now if the list WRITE fails the
      *> rollback in FAIL-IO takes the user away again, so we never
      *> end up with a user that has no list and LISTS = 1.
           MOVE SPACES TO LST-REC.
           MOVE AU-USER TO LST-USER.
           MOVE 1 TO LST-ID.
           MOVE 0 TO LST-NEXTITEM.
           MOVE 0 TO LST-COUNT.
           MOVE 0 TO LST-DONE.
           MOVE 1 TO LST-VERSION.
           MOVE WS-NOW TO LST-CREATED.
           MOVE WS-NOW TO LST-UPDATED.
           MOVE 'My tasks' TO LST-NAME.
           MOVE 'TODOLST' TO WS-FILE.
           EXEC CICS WRITE FILE('TODOLST') FROM(LST-REC) RIDFLD(LST-KEY)
                RESP(WS-RESP) END-EXEC.
           IF WS-RESP NOT = DFHRESP(NORMAL)
               PERFORM FAIL-IO
               EXIT PARAGRAPH
           END-IF.
      *> {"user":"bob","lists":[{..}]} -- {"user":"bob"} comes from
      *> JSON GENERATE, we just open it up again before the last brace
           MOVE 201 TO WS-STATUS.
           MOVE AU-USER TO JO-U-USER.
           JSON GENERATE JS-PIECE FROM JO-USER COUNT IN JS-PLEN
               NAME OF JO-USER IS OMITTED JO-U-USER IS 'user'
               ON EXCEPTION PERFORM FAIL-JSON
           END-JSON.
           SUBTRACT 1 FROM JS-PLEN.
           PERFORM PUT-PIECE.
           STRING ',"lists":[' DELIMITED BY SIZE
               INTO JSON-BUF WITH POINTER JS-PTR
               ON OVERFLOW PERFORM FAIL-JSON
           END-STRING.
           PERFORM GEN-LIST.
           PERFORM PUT-PIECE.
           STRING ']}' DELIMITED BY SIZE
               INTO JSON-BUF WITH POINTER JS-PTR
               ON OVERFLOW PERFORM FAIL-JSON
           END-STRING.
      *> reply built first: if it didn't fit DO-COMMIT rolls back, so
      *> a 500 never goes out for a write that was committed
           PERFORM DO-COMMIT.


      *> GET /api/todo/me

       DO-ME.
           PERFORM AUTHENTICATE.
           IF WS-ERR = 'Y'
               EXIT PARAGRAPH
           END-IF.
           MOVE AU-USER TO JO-M-USER.
           MOVE USR-LISTS TO JO-M-LISTS.
           MOVE USR-CREATED TO JO-M-CREATED.
           MOVE 'Z' TO JO-M-CREATED(20:1).
           JSON GENERATE JS-PIECE FROM JO-ME COUNT IN JS-PLEN
               NAME OF JO-ME IS OMITTED JO-M-USER IS 'user'
                    JO-M-LISTS IS 'lists' JO-M-CREATED IS 'created'
               ON EXCEPTION PERFORM FAIL-JSON
           END-JSON.
           PERFORM PUT-PIECE.


      *> GET /api/todo/lists -- browse TODOLST on the user prefix

       DO-LISTS-GET.
           PERFORM AUTHENTICATE.
           IF WS-ERR = 'Y'
               EXIT PARAGRAPH
           END-IF.
           MOVE 0 TO WS-COUNT.
           MOVE 'Y' TO JS-FIRST.
           STRING '{"lists":[' DELIMITED BY SIZE
               INTO JSON-BUF WITH POINTER JS-PTR
               ON OVERFLOW PERFORM FAIL-JSON
           END-STRING.
           MOVE 0 TO K-LST-ID.
           MOVE 'TODOLST' TO WS-FILE.
           MOVE 'N' TO WS-BR-END.
           MOVE 'N' TO WS-BR-BAD.
           EXEC CICS STARTBR FILE('TODOLST') RIDFLD(K-LST) GTEQ
                RESP(WS-RESP) END-EXEC.
           EVALUATE WS-RESP
               WHEN DFHRESP(NOTFND)
                   MOVE 'Y' TO WS-BR-END
               WHEN DFHRESP(NORMAL)
                   PERFORM UNTIL WS-BR-END = 'Y'
                       EXEC CICS READNEXT FILE('TODOLST') INTO(LST-REC)
                            RIDFLD(K-BR) RESP(WS-RESP) END-EXEC
                       EVALUATE TRUE
                           WHEN WS-RESP = DFHRESP(ENDFILE)
                               MOVE 'Y' TO WS-BR-END
                           WHEN WS-RESP NOT = DFHRESP(NORMAL)
                               MOVE 'Y' TO WS-BR-END
                               MOVE 'Y' TO WS-BR-BAD
      *> full 16 byte compare, or "bob" would wander into "bobby"
                           WHEN LST-USER NOT = AU-USER
                               MOVE 'Y' TO WS-BR-END
                           WHEN OTHER
                               PERFORM PUT-COMMA
                               PERFORM GEN-LIST
                               PERFORM PUT-PIECE
                               ADD 1 TO WS-COUNT
                       END-EVALUATE
                   END-PERFORM
                   EXEC CICS ENDBR FILE('TODOLST') RESP(WS-RESP2) END-EXEC
               WHEN OTHER
                   PERFORM FAIL-IO
                   EXIT PARAGRAPH
           END-EVALUATE.
           IF WS-BR-BAD = 'Y'
               PERFORM FAIL-IO
               EXIT PARAGRAPH
           END-IF.
           STRING '],' DELIMITED BY SIZE
               INTO JSON-BUF WITH POINTER JS-PTR
               ON OVERFLOW PERFORM FAIL-JSON
           END-STRING.
           PERFORM PUT-COUNT-TAIL.


      *> POST /api/todo/lists   body: name
      *> READ UPDATE user -> limit -> WRITE list -> REWRITE user LAST.
      *> The user lock (it guards NEXTLIST/LISTS) is only let go by the
      *> final REWRITE, so nobody can slip in between the two writes.

       DO-LIST-CREATE.
           PERFORM AUTHENTICATE.
           IF WS-ERR = 'Y'
               EXIT PARAGRAPH
           END-IF.
           PERFORM GET-NAME.
           IF T-OK = 'N'
               PERFORM ERR-BADNAME
               EXIT PARAGRAPH
           END-IF.
           MOVE 'TODOUSR' TO WS-FILE.
           MOVE 0 TO WS-TRY.
           PERFORM WITH TEST AFTER
                   UNTIL WS-RESP NOT = DFHRESP(ENQBUSY) OR WS-TRY > 3
               PERFORM BUSY-PAUSE
               EXEC CICS READ FILE('TODOUSR') INTO(USR-REC) RIDFLD(K-USR)
                    UPDATE RESP(WS-RESP) END-EXEC
               ADD 1 TO WS-TRY
           END-PERFORM.
           EVALUATE WS-RESP
               WHEN DFHRESP(NORMAL)
                   CONTINUE
               WHEN DFHRESP(ENQBUSY)
                   PERFORM FAIL-BUSY
                   EXIT PARAGRAPH
               WHEN OTHER
                   PERFORM FAIL-IO
                   EXIT PARAGRAPH
           END-EVALUATE.
           IF USR-LISTS >= 20 OR USR-NEXTLIST >= 999999
               EXEC CICS UNLOCK FILE('TODOUSR') RESP(WS-RESP2) END-EXEC
               MOVE 409 TO WS-STATUS
               MOVE 'LIMIT' TO E-CODE
               MOVE 'a user can have at most 20 lists' TO E-MSG
               PERFORM SET-ERR
               EXIT PARAGRAPH
           END-IF.
           ADD 1 TO USR-NEXTLIST.
           ADD 1 TO USR-LISTS.
           PERFORM GET-NOW.
           MOVE SPACES TO LST-REC.
           MOVE AU-USER TO LST-USER.
           MOVE USR-NEXTLIST TO LST-ID.
           MOVE 0 TO LST-NEXTITEM.
           MOVE 0 TO LST-COUNT.
           MOVE 0 TO LST-DONE.
           MOVE 1 TO LST-VERSION.
           MOVE WS-NOW TO LST-CREATED.
           MOVE WS-NOW TO LST-UPDATED.
           MOVE P-NAME TO LST-NAME.
           MOVE 'TODOLST' TO WS-FILE.
           EXEC CICS WRITE FILE('TODOLST') FROM(LST-REC) RIDFLD(LST-KEY)
                RESP(WS-RESP) END-EXEC.
           IF WS-RESP NOT = DFHRESP(NORMAL)
               PERFORM FAIL-IO
               EXIT PARAGRAPH
           END-IF.
           MOVE 'TODOUSR' TO WS-FILE.
           EXEC CICS REWRITE FILE('TODOUSR') FROM(USR-REC)
                RESP(WS-RESP) END-EXEC.
           IF WS-RESP NOT = DFHRESP(NORMAL)
               PERFORM FAIL-IO
               EXIT PARAGRAPH
           END-IF.
           MOVE 201 TO WS-STATUS.
           PERFORM GEN-LIST.
           PERFORM PUT-PIECE.
      *> reply built first: if it didn't fit DO-COMMIT rolls back, so
      *> a 500 never goes out for a write that was committed
           PERFORM DO-COMMIT.


      *> PUT /api/todo/lists/{list}   body: name, version
 
       DO-LIST-PUT.
           PERFORM AUTHENTICATE.
           IF WS-ERR = 'Y'
               EXIT PARAGRAPH
           END-IF.
           PERFORM GET-LIST-ID.
           IF N-OK = 'N'
               EXIT PARAGRAPH
           END-IF.
           PERFORM GET-NAME.
           IF T-OK = 'N'
               PERFORM ERR-BADNAME
               EXIT PARAGRAPH
           END-IF.
           MOVE 'version' TO F-NAME.
           PERFORM READ-FIELD.
           PERFORM GET-VERSION.
           IF P-VER-SET NOT = 'Y'
               PERFORM ERR-BADVERSION
               EXIT PARAGRAPH
           END-IF.
           MOVE 'TODOLST' TO WS-FILE.
           MOVE 0 TO WS-TRY.
           PERFORM WITH TEST AFTER
                   UNTIL WS-RESP NOT = DFHRESP(ENQBUSY) OR WS-TRY > 3
               PERFORM BUSY-PAUSE
               EXEC CICS READ FILE('TODOLST') INTO(LST-REC) RIDFLD(K-LST)
                    UPDATE RESP(WS-RESP) END-EXEC
               ADD 1 TO WS-TRY
           END-PERFORM.
           EVALUATE WS-RESP
               WHEN DFHRESP(NORMAL)
                   CONTINUE
               WHEN DFHRESP(NOTFND)
                   PERFORM ERR-LIST-404
                   EXIT PARAGRAPH
               WHEN DFHRESP(ENQBUSY)
                   PERFORM FAIL-BUSY
                   EXIT PARAGRAPH
               WHEN OTHER
                   PERFORM FAIL-IO
                   EXIT PARAGRAPH
           END-EVALUATE.
           IF LST-VERSION NOT = P-VERSION
               EXEC CICS UNLOCK FILE('TODOLST') RESP(WS-RESP2) END-EXEC
               MOVE 'L' TO E-CUR
               PERFORM ERR-CONFLICT
               EXIT PARAGRAPH
           END-IF.
           PERFORM GET-NOW.
           MOVE P-NAME TO LST-NAME.
           IF LST-VERSION >= 999999
               MOVE 1 TO LST-VERSION
           ELSE
               ADD 1 TO LST-VERSION
           END-IF.
           MOVE WS-NOW TO LST-UPDATED.
           EXEC CICS REWRITE FILE('TODOLST') FROM(LST-REC)
                RESP(WS-RESP) END-EXEC.
           IF WS-RESP NOT = DFHRESP(NORMAL)
               PERFORM FAIL-IO
               EXIT PARAGRAPH
           END-IF.
           PERFORM GEN-LIST.
           PERFORM PUT-PIECE.
      *> reply built first: if it didn't fit DO-COMMIT rolls back, so
      *> a 500 never goes out for a write that was committed
           PERFORM DO-COMMIT.


      *> DELETE /api/todo/lists/{list}[?version=n]
      *> Cascade: lock the list, then the user, collect every item id,
      *> delete each item, delete the list, REWRITE the user last.
      *> All or nothing -- one locked item and the lot is rolled back.

       DO-LIST-DELETE.
           PERFORM AUTHENTICATE.
           IF WS-ERR = 'Y'
               EXIT PARAGRAPH
           END-IF.
           PERFORM GET-LIST-ID.
           IF N-OK = 'N'
               EXIT PARAGRAPH
           END-IF.
           PERFORM GET-QVERSION.
           IF WS-ERR = 'Y'
               EXIT PARAGRAPH
           END-IF.
           MOVE 'TODOLST' TO WS-FILE.
           MOVE 0 TO WS-TRY.
           PERFORM WITH TEST AFTER
                   UNTIL WS-RESP NOT = DFHRESP(ENQBUSY) OR WS-TRY > 3
               PERFORM BUSY-PAUSE
               EXEC CICS READ FILE('TODOLST') INTO(LST-REC) RIDFLD(K-LST)
                    UPDATE RESP(WS-RESP) END-EXEC
               ADD 1 TO WS-TRY
           END-PERFORM.
           EVALUATE WS-RESP
               WHEN DFHRESP(NORMAL)
                   CONTINUE
               WHEN DFHRESP(NOTFND)
                   PERFORM ERR-LIST-404
                   EXIT PARAGRAPH
               WHEN DFHRESP(ENQBUSY)
                   PERFORM FAIL-BUSY
                   EXIT PARAGRAPH
               WHEN OTHER
                   PERFORM FAIL-IO
                   EXIT PARAGRAPH
           END-EVALUATE.
           IF P-VER-SET = 'Y' AND LST-VERSION NOT = P-VERSION
               EXEC CICS UNLOCK FILE('TODOLST') RESP(WS-RESP2) END-EXEC
               MOVE 'L' TO E-CUR
               PERFORM ERR-CONFLICT
               EXIT PARAGRAPH
           END-IF.
      *> user lock next, still before anything is written (so a short
      *> retry is ok here too)
           MOVE 'TODOUSR' TO WS-FILE.
           MOVE 0 TO WS-TRY.
           PERFORM WITH TEST AFTER
                   UNTIL WS-RESP NOT = DFHRESP(ENQBUSY) OR WS-TRY > 3
               PERFORM BUSY-PAUSE
               EXEC CICS READ FILE('TODOUSR') INTO(USR-REC) RIDFLD(K-USR)
                    UPDATE RESP(WS-RESP) END-EXEC
               ADD 1 TO WS-TRY
           END-PERFORM.
           EVALUATE WS-RESP
               WHEN DFHRESP(NORMAL)
                   CONTINUE
               WHEN DFHRESP(ENQBUSY)
                   PERFORM FAIL-BUSY
                   EXIT PARAGRAPH
               WHEN OTHER
                   PERFORM FAIL-IO
                   EXIT PARAGRAPH
           END-EVALUATE.
           MOVE 'Y' TO WS-ALLDONE.
           PERFORM COLLECT-ITEMS.
           IF WS-ERR = 'Y'
               EXIT PARAGRAPH
           END-IF.
           MOVE 0 TO WS-DELN.
           MOVE 'TODOITM' TO WS-FILE.
           PERFORM VARYING WS-TI FROM 1 BY 1
                   UNTIL WS-TI > WS-TN OR WS-ERR = 'Y'
               MOVE WS-TID(WS-TI) TO K-ITM-ID
               EXEC CICS READ FILE('TODOITM') INTO(ITM-REC) RIDFLD(K-ITM)
                    UPDATE RESP(WS-RESP) END-EXEC
               EVALUATE WS-RESP
                   WHEN DFHRESP(NORMAL)
                       EXEC CICS DELETE FILE('TODOITM') RESP(WS-RESP)
                            END-EXEC
                       IF WS-RESP = DFHRESP(NORMAL)
                           ADD 1 TO WS-DELN
                       ELSE
                           PERFORM FAIL-IO
                       END-IF
                   WHEN DFHRESP(ENQBUSY)
                       PERFORM FAIL-BUSY
                   WHEN DFHRESP(NOTFND)
                       CONTINUE
                   WHEN OTHER
                       PERFORM FAIL-IO
               END-EVALUATE
           END-PERFORM.
           IF WS-ERR = 'Y'
               EXIT PARAGRAPH
           END-IF.
           MOVE 'TODOLST' TO WS-FILE.
           EXEC CICS DELETE FILE('TODOLST') RESP(WS-RESP) END-EXEC.
           IF WS-RESP NOT = DFHRESP(NORMAL)
               PERFORM FAIL-IO
               EXIT PARAGRAPH
           END-IF.
           IF USR-LISTS > 0
               SUBTRACT 1 FROM USR-LISTS
           END-IF.
           MOVE 'TODOUSR' TO WS-FILE.
           EXEC CICS REWRITE FILE('TODOUSR') FROM(USR-REC)
                RESP(WS-RESP) END-EXEC.
           IF WS-RESP NOT = DFHRESP(NORMAL)
               PERFORM FAIL-IO
               EXIT PARAGRAPH
           END-IF.
           MOVE P-LIST TO JO-LD-DELETED.
           MOVE WS-DELN TO JO-LD-ITEMS.
           JSON GENERATE JS-PIECE FROM JO-LDEL COUNT IN JS-PLEN
               NAME OF JO-LDEL IS OMITTED JO-LD-DELETED IS 'deleted'
                    JO-LD-ITEMS IS 'items'
               ON EXCEPTION PERFORM FAIL-JSON
           END-JSON.
           PERFORM PUT-PIECE.
      *> reply built first: if it didn't fit DO-COMMIT rolls back, so
      *> a 500 never goes out for a write that was committed
           PERFORM DO-COMMIT.


      *> GET /api/todo/lists/{list}/items[?filter=all|open|done]

       DO-ITEMS-GET.
           PERFORM AUTHENTICATE.
           IF WS-ERR = 'Y'
               EXIT PARAGRAPH
           END-IF.
           PERFORM GET-LIST-ID.
           IF N-OK = 'N'
               EXIT PARAGRAPH
           END-IF.
           MOVE 'all' TO P-FILTER.
           MOVE 'filter' TO F-NAME.
           PERFORM READ-QPARM.
           IF F-FOUND = 'Y' AND T-LEN > 0
               MOVE FUNCTION LOWER-CASE(T-IN) TO T-IN
               EVALUATE TRUE
                   WHEN T-LEN = 3 AND T-IN(1:3) = 'all'
                       MOVE 'all' TO P-FILTER
                   WHEN T-LEN = 4 AND T-IN(1:4) = 'open'
                       MOVE 'open' TO P-FILTER
                   WHEN T-LEN = 4 AND T-IN(1:4) = 'done'
                       MOVE 'done' TO P-FILTER
                   WHEN OTHER
                       MOVE 400 TO WS-STATUS
                       MOVE 'BADFILTER' TO E-CODE
                       MOVE 'filter must be all, open or done' TO E-MSG
                       PERFORM SET-ERR
                       EXIT PARAGRAPH
               END-EVALUATE
           END-IF.
           MOVE 'TODOLST' TO WS-FILE.
           EXEC CICS READ FILE('TODOLST') INTO(LST-REC) RIDFLD(K-LST)
                RESP(WS-RESP) END-EXEC.
           EVALUATE WS-RESP
               WHEN DFHRESP(NORMAL)
                   CONTINUE
               WHEN DFHRESP(NOTFND)
                   PERFORM ERR-LIST-404
                   EXIT PARAGRAPH
               WHEN OTHER
                   PERFORM FAIL-IO
                   EXIT PARAGRAPH
           END-EVALUATE.
           STRING '{"list":' DELIMITED BY SIZE
               INTO JSON-BUF WITH POINTER JS-PTR
               ON OVERFLOW PERFORM FAIL-JSON
           END-STRING.
           PERFORM GEN-LIST.
           PERFORM PUT-PIECE.
           STRING ',"items":[' DELIMITED BY SIZE
               INTO JSON-BUF WITH POINTER JS-PTR
               ON OVERFLOW PERFORM FAIL-JSON
           END-STRING.
           MOVE 'Y' TO JS-FIRST.
           MOVE 0 TO WS-COUNT.
           MOVE 0 TO K-ITM-ID.
           MOVE 'TODOITM' TO WS-FILE.
           MOVE 'N' TO WS-BR-END.
           MOVE 'N' TO WS-BR-BAD.
           EXEC CICS STARTBR FILE('TODOITM') RIDFLD(K-ITM) GTEQ
                RESP(WS-RESP) END-EXEC.
           EVALUATE WS-RESP
               WHEN DFHRESP(NOTFND)
                   MOVE 'Y' TO WS-BR-END
               WHEN DFHRESP(NORMAL)
                   PERFORM UNTIL WS-BR-END = 'Y'
                       EXEC CICS READNEXT FILE('TODOITM') INTO(ITM-REC)
                            RIDFLD(K-BR) RESP(WS-RESP) END-EXEC
                       EVALUATE TRUE
                           WHEN WS-RESP = DFHRESP(ENDFILE)
                               MOVE 'Y' TO WS-BR-END
                           WHEN WS-RESP NOT = DFHRESP(NORMAL)
                               MOVE 'Y' TO WS-BR-END
                               MOVE 'Y' TO WS-BR-BAD
                           WHEN ITM-USER NOT = AU-USER
                             OR ITM-LIST NOT = P-LIST
                               MOVE 'Y' TO WS-BR-END
                           WHEN P-FILTER = 'all'
                             OR (P-FILTER = 'open' AND ITM-DONE = 'N')
                             OR (P-FILTER = 'done' AND ITM-DONE = 'Y')
                               PERFORM PUT-COMMA
                               PERFORM GEN-ITEM
                               PERFORM PUT-PIECE
                               ADD 1 TO WS-COUNT
                       END-EVALUATE
                   END-PERFORM
                   EXEC CICS ENDBR FILE('TODOITM') RESP(WS-RESP2) END-EXEC
               WHEN OTHER
                   PERFORM FAIL-IO
                   EXIT PARAGRAPH
           END-EVALUATE.
           IF WS-BR-BAD = 'Y'
               PERFORM FAIL-IO
               EXIT PARAGRAPH
           END-IF.
           STRING '],' DELIMITED BY SIZE
               INTO JSON-BUF WITH POINTER JS-PTR
               ON OVERFLOW PERFORM FAIL-JSON
           END-STRING.
           PERFORM PUT-COUNT-TAIL.

      *> =============================================================
      *> POST /api/todo/lists/{list}/items   body: title, priority
      *> READ UPDATE list -> limit -> WRITE item -> REWRITE list LAST,
      *> so the list lock is held right up to the final write. If the
      *> WRITE fails we roll back and the id is never burnt.
      *> =============================================================
       DO-ITEM-CREATE.
           PERFORM AUTHENTICATE.
           IF WS-ERR = 'Y'
               EXIT PARAGRAPH
           END-IF.
           PERFORM GET-LIST-ID.
           IF N-OK = 'N'
               EXIT PARAGRAPH
           END-IF.
           MOVE 'title' TO F-NAME.
           PERFORM READ-FIELD.
           IF F-FOUND = 'N'
               MOVE 0 TO T-LEN
           END-IF.
           MOVE 80 TO T-MAX.
           PERFORM CHECK-TEXT.
           IF T-OK = 'N'
               PERFORM ERR-BADTITLE
               EXIT PARAGRAPH
           END-IF.
           MOVE T-OUT TO P-TITLE.
           PERFORM GET-PRIO.
           IF WS-ERR = 'Y'
               EXIT PARAGRAPH
           END-IF.
           IF P-PRIO-SET = 'N'
               MOVE 'N' TO P-PRIO
           END-IF.
           MOVE 'TODOLST' TO WS-FILE.
           MOVE 0 TO WS-TRY.
           PERFORM WITH TEST AFTER
                   UNTIL WS-RESP NOT = DFHRESP(ENQBUSY) OR WS-TRY > 3
               PERFORM BUSY-PAUSE
               EXEC CICS READ FILE('TODOLST') INTO(LST-REC) RIDFLD(K-LST)
                    UPDATE RESP(WS-RESP) END-EXEC
               ADD 1 TO WS-TRY
           END-PERFORM.
           EVALUATE WS-RESP
               WHEN DFHRESP(NORMAL)
                   CONTINUE
               WHEN DFHRESP(NOTFND)
                   PERFORM ERR-LIST-404
                   EXIT PARAGRAPH
               WHEN DFHRESP(ENQBUSY)
                   PERFORM FAIL-BUSY
                   EXIT PARAGRAPH
               WHEN OTHER
                   PERFORM FAIL-IO
                   EXIT PARAGRAPH
           END-EVALUATE.
           IF LST-COUNT >= 200 OR LST-NEXTITEM >= 99999999
               EXEC CICS UNLOCK FILE('TODOLST') RESP(WS-RESP2) END-EXEC
               MOVE 409 TO WS-STATUS
               MOVE 'LIMIT' TO E-CODE
               MOVE 'a list can hold at most 200 items' TO E-MSG
               PERFORM SET-ERR
               EXIT PARAGRAPH
           END-IF.
           ADD 1 TO LST-NEXTITEM.
           ADD 1 TO LST-COUNT.
           PERFORM GET-NOW.
           MOVE SPACES TO ITM-REC.
           MOVE AU-USER TO ITM-USER.
           MOVE P-LIST TO ITM-LIST.
           MOVE LST-NEXTITEM TO ITM-ID.
           MOVE 'N' TO ITM-DONE.
           MOVE P-PRIO TO ITM-PRIO.
           MOVE 1 TO ITM-VERSION.
           MOVE WS-NOW TO ITM-CREATED.
           MOVE WS-NOW TO ITM-UPDATED.
           MOVE P-TITLE TO ITM-TITLE.
           MOVE 'TODOITM' TO WS-FILE.
           EXEC CICS WRITE FILE('TODOITM') FROM(ITM-REC) RIDFLD(ITM-KEY)
                RESP(WS-RESP) END-EXEC.
           IF WS-RESP NOT = DFHRESP(NORMAL)
      *> DUPREC lands here as well. Nothing is written yet, the rollback
      *> just lets go of the list lock with the counter untouched.
               PERFORM FAIL-IO
               EXIT PARAGRAPH
           END-IF.
           MOVE 'TODOLST' TO WS-FILE.
           EXEC CICS REWRITE FILE('TODOLST') FROM(LST-REC)
                RESP(WS-RESP) END-EXEC.
           IF WS-RESP NOT = DFHRESP(NORMAL)
               PERFORM FAIL-IO
               EXIT PARAGRAPH
           END-IF.
           MOVE 201 TO WS-STATUS.
           PERFORM GEN-ITEM.
           PERFORM PUT-PIECE.
      *> reply built first: if it didn't fit DO-COMMIT rolls back, so
      *> a 500 never goes out for a write that was committed
           PERFORM DO-COMMIT.


      *> POST /api/todo/lists/{list}/purge -- remove all done items
      *> Lock the list FIRST and keep it until the closing REWRITE, so
      *> no create/update can move the counters while we delete. (That
      *> is list -> item, against the usual order; bricks READ UPDATE
      *> never waits, so the worst outcome is a 409 BUSY, not a hang.)

       DO-PURGE.
           PERFORM AUTHENTICATE.
           IF WS-ERR = 'Y'
               EXIT PARAGRAPH
           END-IF.
           PERFORM GET-LIST-ID.
           IF N-OK = 'N'
               EXIT PARAGRAPH
           END-IF.
           MOVE 'TODOLST' TO WS-FILE.
           MOVE 0 TO WS-TRY.
           PERFORM WITH TEST AFTER
                   UNTIL WS-RESP NOT = DFHRESP(ENQBUSY) OR WS-TRY > 3
               PERFORM BUSY-PAUSE
               EXEC CICS READ FILE('TODOLST') INTO(LST-REC) RIDFLD(K-LST)
                    UPDATE RESP(WS-RESP) END-EXEC
               ADD 1 TO WS-TRY
           END-PERFORM.
           EVALUATE WS-RESP
               WHEN DFHRESP(NORMAL)
                   CONTINUE
               WHEN DFHRESP(NOTFND)
                   PERFORM ERR-LIST-404
                   EXIT PARAGRAPH
               WHEN DFHRESP(ENQBUSY)
                   PERFORM FAIL-BUSY
                   EXIT PARAGRAPH
               WHEN OTHER
                   PERFORM FAIL-IO
                   EXIT PARAGRAPH
           END-EVALUATE.
           MOVE 'N' TO WS-ALLDONE.
           PERFORM COLLECT-ITEMS.
           IF WS-ERR = 'Y'
               EXIT PARAGRAPH
           END-IF.
      *> Lock each item before deleting it and re-check the done flag:
      *> somebody may have flipped it back since teh browse ran.
           MOVE 0 TO WS-DELN.
           MOVE 'TODOITM' TO WS-FILE.
           PERFORM VARYING WS-TI FROM 1 BY 1
                   UNTIL WS-TI > WS-TN OR WS-ERR = 'Y'
               MOVE WS-TID(WS-TI) TO K-ITM-ID
               EXEC CICS READ FILE('TODOITM') INTO(ITM-REC) RIDFLD(K-ITM)
                    UPDATE RESP(WS-RESP) END-EXEC
               EVALUATE WS-RESP ALSO ITM-DONE
                   WHEN DFHRESP(NORMAL) ALSO 'Y'
                       EXEC CICS DELETE FILE('TODOITM') RESP(WS-RESP)
                            END-EXEC
                       IF WS-RESP = DFHRESP(NORMAL)
                           ADD 1 TO WS-DELN
                       ELSE
                           PERFORM FAIL-IO
                       END-IF
                   WHEN DFHRESP(NORMAL) ALSO ANY
                       EXEC CICS UNLOCK FILE('TODOITM') RESP(WS-RESP2)
                            END-EXEC
                   WHEN DFHRESP(ENQBUSY) ALSO ANY
                       PERFORM FAIL-BUSY
                   WHEN DFHRESP(NOTFND) ALSO ANY
                       CONTINUE
                   WHEN OTHER
                       PERFORM FAIL-IO
               END-EVALUATE
           END-PERFORM.
           IF WS-ERR = 'Y'
               EXIT PARAGRAPH
           END-IF.
           IF WS-DELN > 0
               IF LST-COUNT >= WS-DELN
                   SUBTRACT WS-DELN FROM LST-COUNT
               ELSE
                   MOVE 0 TO LST-COUNT
               END-IF
               IF LST-DONE >= WS-DELN
                   SUBTRACT WS-DELN FROM LST-DONE
               ELSE
                   MOVE 0 TO LST-DONE
               END-IF
               MOVE 'TODOLST' TO WS-FILE
               EXEC CICS REWRITE FILE('TODOLST') FROM(LST-REC)
                    RESP(WS-RESP) END-EXEC
               IF WS-RESP NOT = DFHRESP(NORMAL)
                   PERFORM FAIL-IO
                   EXIT PARAGRAPH
               END-IF
           ELSE
               EXEC CICS UNLOCK FILE('TODOLST') RESP(WS-RESP2) END-EXEC
           END-IF.
           MOVE WS-DELN TO JO-D-DELETED.
           PERFORM GEN-DELETED.
      *> reply built first: if it didn't fit DO-COMMIT rolls back, so
      *> a 500 never goes out for a write that was committed
           PERFORM DO-COMMIT.


      *> GET /api/todo/lists/{list}/items/{id}

       DO-ITEM-GET.
           PERFORM AUTHENTICATE.
           IF WS-ERR = 'Y'
               EXIT PARAGRAPH
           END-IF.
           PERFORM GET-LIST-ID.
           IF N-OK = 'N'
               EXIT PARAGRAPH
           END-IF.
           PERFORM GET-ITEM-ID.
           IF N-OK = 'N'
               EXIT PARAGRAPH
           END-IF.
           MOVE 'TODOITM' TO WS-FILE.
           EXEC CICS READ FILE('TODOITM') INTO(ITM-REC) RIDFLD(K-ITM)
                RESP(WS-RESP) END-EXEC.
           EVALUATE WS-RESP
               WHEN DFHRESP(NORMAL)
                   PERFORM GEN-ITEM
                   PERFORM PUT-PIECE
               WHEN DFHRESP(NOTFND)
                   PERFORM ERR-ITEM-404
               WHEN OTHER
                   PERFORM FAIL-IO
           END-EVALUATE.


      *> PUT /api/todo/lists/{list}/items/{id}
      *>   body: version (required) + any of title, done, priority
      *> READ UPDATE item -> version check -> (list lock if the done
      *> flag flips) -> REWRITE list -> REWRITE item (last, so the item
      *> lock is held until the final write).

       DO-ITEM-PUT.
           PERFORM AUTHENTICATE.
           IF WS-ERR = 'Y'
               EXIT PARAGRAPH
           END-IF.
           PERFORM GET-LIST-ID.
           IF N-OK = 'N'
               EXIT PARAGRAPH
           END-IF.
           PERFORM GET-ITEM-ID.
           IF N-OK = 'N'
               EXIT PARAGRAPH
           END-IF.
           MOVE 'version' TO F-NAME.
           PERFORM READ-FIELD.
           PERFORM GET-VERSION.
           IF P-VER-SET NOT = 'Y'
               PERFORM ERR-BADVERSION
               EXIT PARAGRAPH
           END-IF.
           MOVE 'N' TO P-TITLE-SET.
           MOVE 'title' TO F-NAME.
           PERFORM READ-FIELD.
           IF F-FOUND = 'Y'
               MOVE 80 TO T-MAX
               PERFORM CHECK-TEXT
               IF T-OK = 'N'
                   PERFORM ERR-BADTITLE
                   EXIT PARAGRAPH
               END-IF
               MOVE T-OUT TO P-TITLE
               MOVE 'Y' TO P-TITLE-SET
           END-IF.
           MOVE 'N' TO P-DONE-SET.
           MOVE 'done' TO F-NAME.
           PERFORM READ-FIELD.
           IF F-FOUND = 'Y'
               MOVE 'Y' TO P-DONE-SET
               EVALUATE TRUE
                   WHEN T-LEN = 4 AND T-IN(1:4) = 'true'
                       MOVE 'Y' TO P-DONE
                   WHEN T-LEN = 5 AND T-IN(1:5) = 'false'
                       MOVE 'N' TO P-DONE
                   WHEN OTHER
                       MOVE 400 TO WS-STATUS
                       MOVE 'BADDONE' TO E-CODE
                       MOVE 'done must be true or false' TO E-MSG
                       PERFORM SET-ERR
                       EXIT PARAGRAPH
               END-EVALUATE
           END-IF.
           PERFORM GET-PRIO.
           IF WS-ERR = 'Y'
               EXIT PARAGRAPH
           END-IF.
           IF P-TITLE-SET = 'N' AND P-DONE-SET = 'N' AND P-PRIO-SET = 'N'
               MOVE 400 TO WS-STATUS
               MOVE 'NOCHANGE' TO E-CODE
               MOVE 'give at least one of title, done, priority'
                   TO E-MSG
               PERFORM SET-ERR
               EXIT PARAGRAPH
           END-IF.

           MOVE 'TODOITM' TO WS-FILE.
           MOVE 0 TO WS-TRY.
           PERFORM WITH TEST AFTER
                   UNTIL WS-RESP NOT = DFHRESP(ENQBUSY) OR WS-TRY > 3
               PERFORM BUSY-PAUSE
               EXEC CICS READ FILE('TODOITM') INTO(ITM-REC) RIDFLD(K-ITM)
                    UPDATE RESP(WS-RESP) END-EXEC
               ADD 1 TO WS-TRY
           END-PERFORM.
           EVALUATE WS-RESP
               WHEN DFHRESP(NORMAL)
                   CONTINUE
               WHEN DFHRESP(NOTFND)
                   PERFORM ERR-ITEM-404
                   EXIT PARAGRAPH
               WHEN DFHRESP(ENQBUSY)
                   PERFORM FAIL-BUSY
                   EXIT PARAGRAPH
               WHEN OTHER
                   PERFORM FAIL-IO
                   EXIT PARAGRAPH
           END-EVALUATE.
           IF ITM-VERSION NOT = P-VERSION
               EXEC CICS UNLOCK FILE('TODOITM') RESP(WS-RESP2) END-EXEC
               MOVE 'I' TO E-CUR
               PERFORM ERR-CONFLICT
               EXIT PARAGRAPH
           END-IF.
           MOVE 'N' TO WS-DCHG.
           IF P-DONE-SET = 'Y' AND P-DONE NOT = ITM-DONE
               MOVE 'Y' TO WS-DCHG
           END-IF.
      *> Take the list lock while we still hold the item lock (order:
      *> item -> list), write the list first and the item LAST, so the
      *> item lock stays put until the final write of the UOW.
           IF WS-DCHG = 'Y'
               MOVE 'TODOLST' TO WS-FILE
               MOVE 0 TO WS-TRY
               PERFORM WITH TEST AFTER
                       UNTIL WS-RESP NOT = DFHRESP(ENQBUSY) OR WS-TRY > 3
                   PERFORM BUSY-PAUSE
                   EXEC CICS READ FILE('TODOLST') INTO(LST-REC)
                        RIDFLD(K-LST) UPDATE RESP(WS-RESP) END-EXEC
                   ADD 1 TO WS-TRY
               END-PERFORM
               EVALUATE WS-RESP
                   WHEN DFHRESP(NORMAL)
                       CONTINUE
                   WHEN DFHRESP(NOTFND)
                       PERFORM FAIL-LIST-GONE
                       EXIT PARAGRAPH
                   WHEN DFHRESP(ENQBUSY)
                       PERFORM FAIL-BUSY
                       EXIT PARAGRAPH
                   WHEN OTHER
                       PERFORM FAIL-IO
                       EXIT PARAGRAPH
               END-EVALUATE
               IF P-DONE = 'Y'
                   ADD 1 TO LST-DONE
               ELSE
                   IF LST-DONE > 0
                       SUBTRACT 1 FROM LST-DONE
                   END-IF
               END-IF
               EXEC CICS REWRITE FILE('TODOLST') FROM(LST-REC)
                    RESP(WS-RESP) END-EXEC
               IF WS-RESP NOT = DFHRESP(NORMAL)
                   PERFORM FAIL-IO
                   EXIT PARAGRAPH
               END-IF
           END-IF.
           PERFORM GET-NOW.
           IF P-TITLE-SET = 'Y'
               MOVE P-TITLE TO ITM-TITLE
           END-IF.
           IF P-DONE-SET = 'Y'
               MOVE P-DONE TO ITM-DONE
           END-IF.
           IF P-PRIO-SET = 'Y'
               MOVE P-PRIO TO ITM-PRIO
           END-IF.
           IF ITM-VERSION >= 999999
               MOVE 1 TO ITM-VERSION
           ELSE
               ADD 1 TO ITM-VERSION
           END-IF.
           MOVE WS-NOW TO ITM-UPDATED.
           MOVE 'TODOITM' TO WS-FILE.
           EXEC CICS REWRITE FILE('TODOITM') FROM(ITM-REC)
                RESP(WS-RESP) END-EXEC.
           IF WS-RESP NOT = DFHRESP(NORMAL)
               PERFORM FAIL-IO
               EXIT PARAGRAPH
           END-IF.
           PERFORM GEN-ITEM.
           PERFORM PUT-PIECE.
      *> reply built first: if it didn't fit DO-COMMIT rolls back, so
      *> a 500 never goes out for a write that was committed
           PERFORM DO-COMMIT.


      *> DELETE /api/todo/lists/{list}/items/{id}[?version=n]
 
       DO-ITEM-DELETE.
           PERFORM AUTHENTICATE.
           IF WS-ERR = 'Y'
               EXIT PARAGRAPH
           END-IF.
           PERFORM GET-LIST-ID.
           IF N-OK = 'N'
               EXIT PARAGRAPH
           END-IF.
           PERFORM GET-ITEM-ID.
           IF N-OK = 'N'
               EXIT PARAGRAPH
           END-IF.
           PERFORM GET-QVERSION.
           IF WS-ERR = 'Y'
               EXIT PARAGRAPH
           END-IF.
           MOVE 'TODOITM' TO WS-FILE.
           MOVE 0 TO WS-TRY.
           PERFORM WITH TEST AFTER
                   UNTIL WS-RESP NOT = DFHRESP(ENQBUSY) OR WS-TRY > 3
               PERFORM BUSY-PAUSE
               EXEC CICS READ FILE('TODOITM') INTO(ITM-REC) RIDFLD(K-ITM)
                    UPDATE RESP(WS-RESP) END-EXEC
               ADD 1 TO WS-TRY
           END-PERFORM.
           EVALUATE WS-RESP
               WHEN DFHRESP(NORMAL)
                   CONTINUE
               WHEN DFHRESP(NOTFND)
                   PERFORM ERR-ITEM-404
                   EXIT PARAGRAPH
               WHEN DFHRESP(ENQBUSY)
                   PERFORM FAIL-BUSY
                   EXIT PARAGRAPH
               WHEN OTHER
                   PERFORM FAIL-IO
                   EXIT PARAGRAPH
           END-EVALUATE.
           IF P-VER-SET = 'Y' AND ITM-VERSION NOT = P-VERSION
               EXEC CICS UNLOCK FILE('TODOITM') RESP(WS-RESP2) END-EXEC
               MOVE 'I' TO E-CUR
               PERFORM ERR-CONFLICT
               EXIT PARAGRAPH
           END-IF.
      *> list lock before the DELETE; the list REWRITE is the last
      *> write and the one that lets go of it
           MOVE 'TODOLST' TO WS-FILE.
           MOVE 0 TO WS-TRY.
           PERFORM WITH TEST AFTER
                   UNTIL WS-RESP NOT = DFHRESP(ENQBUSY) OR WS-TRY > 3
               PERFORM BUSY-PAUSE
               EXEC CICS READ FILE('TODOLST') INTO(LST-REC) RIDFLD(K-LST)
                    UPDATE RESP(WS-RESP) END-EXEC
               ADD 1 TO WS-TRY
           END-PERFORM.
           EVALUATE WS-RESP
               WHEN DFHRESP(NORMAL)
                   CONTINUE
               WHEN DFHRESP(NOTFND)
                   PERFORM FAIL-LIST-GONE
                   EXIT PARAGRAPH
               WHEN DFHRESP(ENQBUSY)
                   PERFORM FAIL-BUSY
                   EXIT PARAGRAPH
               WHEN OTHER
                   PERFORM FAIL-IO
                   EXIT PARAGRAPH
           END-EVALUATE.
           MOVE 'TODOITM' TO WS-FILE.
           EXEC CICS DELETE FILE('TODOITM') RIDFLD(K-ITM)
                RESP(WS-RESP) END-EXEC.
           IF WS-RESP NOT = DFHRESP(NORMAL)
               PERFORM FAIL-IO
               EXIT PARAGRAPH
           END-IF.
           IF LST-COUNT > 0
               SUBTRACT 1 FROM LST-COUNT
           END-IF.
           IF ITM-DONE = 'Y' AND LST-DONE > 0
               SUBTRACT 1 FROM LST-DONE
           END-IF.
           MOVE 'TODOLST' TO WS-FILE.
           EXEC CICS REWRITE FILE('TODOLST') FROM(LST-REC)
                RESP(WS-RESP) END-EXEC.
           IF WS-RESP NOT = DFHRESP(NORMAL)
               PERFORM FAIL-IO
               EXIT PARAGRAPH
           END-IF.
           MOVE P-ITEM TO JO-D-DELETED.
           PERFORM GEN-DELETED.
      *> reply built first: if it didn't fit DO-COMMIT rolls back, so
      *> a 500 never goes out for a write that was committed
           PERFORM DO-COMMIT.

 
      *> AUTHENTICATE -- headers X-Todo-User / X-Todo-Key.
      *> Leaves AU-*, K-USR, K-LST/K-ITM prefixes and USR-REC set.
 
       AUTHENTICATE.
           MOVE 'Y' TO WS-AUTH-OK.
           MOVE 'X-Todo-User' TO F-NAME.
           PERFORM READ-HEADER.
           PERFORM T-TO-V.
           PERFORM CHECK-NAME-ID.
           IF V-OK = 'N'
               MOVE 'N' TO WS-AUTH-OK
           END-IF.
           MOVE V-OUT TO AU-USER.
           MOVE 'X-Todo-Key' TO F-NAME.
           PERFORM READ-HEADER.
           PERFORM CHECK-KEY.
           IF T-OK = 'N'
               MOVE 'N' TO WS-AUTH-OK
           END-IF.
           MOVE T-OUT TO AU-KEY.
           IF WS-AUTH-OK = 'N'
               MOVE 400 TO WS-STATUS
               MOVE 'BADAUTH' TO E-CODE
               MOVE 'X-Todo-User or X-Todo-Key missing or malformed'
                   TO E-MSG
               PERFORM SET-ERR
               EXIT PARAGRAPH
           END-IF.
           MOVE AU-USER TO K-USR K-LST-USR K-ITM-USR.
           MOVE 'TODOUSR' TO WS-FILE.
           EXEC CICS READ FILE('TODOUSR') INTO(USR-REC) RIDFLD(K-USR)
                RESP(WS-RESP) END-EXEC.
           EVALUATE WS-RESP
               WHEN DFHRESP(NORMAL)
                   CONTINUE
               WHEN DFHRESP(NOTFND)
                   PERFORM ERR-AUTH-401
                   EXIT PARAGRAPH
               WHEN OTHER
                   PERFORM FAIL-IO
                   EXIT PARAGRAPH
           END-EVALUATE.
           PERFORM COMPUTE-DIGEST.
           IF DG-DIGEST NOT = USR-DIGEST
               PERFORM ERR-AUTH-401
           END-IF.

 
      *> COMPUTE-DIGEST , TOY DIGEST, NOT CRYPTOGRAPHY.
      *> Input: AU-USER ':' AU-KEY (key trimmed both ends, inner blanks
      *> kept). Two polynomial rolling hashes over the char codes (POS
      *> into WS-PRINT95, so ' '=1 '!'=2 .. '~'=95):
      *>     h1 = (h1 * 131 + c) mod 999999937      seed 7
      *>     h2 = (h2 * 257 + c) mod 999999929      seed 11
      *> digest = h1 * 10**9 + h2  -> 18 digits.
      *> Both moduli are primes below 10**9 so h*257+95 stays far inside
      *> the int64 engine (bricks has no DIVIDE REMAINDER, so the mod is
      *> t - (t / p) * p with an integer quotient). It only stops the
      *> secret sitting in clear in the file -- anyone with the file can
      *> brute force it. Do not reuse this for anything real.
 
       COMPUTE-DIGEST.
           MOVE SPACES TO DG-SRC.
           MOVE 1 TO DG-PTR.
           MOVE AU-USER TO DG-PIECE.
           PERFORM DG-ADD.
           MOVE ':' TO DG-PIECE.
           PERFORM DG-ADD.
           MOVE AU-KEY TO DG-PIECE.
           PERFORM DG-ADD.
           COMPUTE DG-LEN = DG-PTR - 1.
           MOVE 7 TO DG-H1.
           MOVE 11 TO DG-H2.
           PERFORM VARYING DG-I FROM 1 BY 1 UNTIL DG-I > DG-LEN
               COMPUTE DG-C = FUNCTION POS(DG-SRC(DG-I:1), WS-PRINT95)
               COMPUTE DG-T = DG-H1 * 131 + DG-C
               COMPUTE DG-Q = DG-T / DG-P1
               COMPUTE DG-H1 = DG-T - DG-Q * DG-P1
               COMPUTE DG-T = DG-H2 * 257 + DG-C
               COMPUTE DG-Q = DG-T / DG-P2
               COMPUTE DG-H2 = DG-T - DG-Q * DG-P2
           END-PERFORM.
           COMPUTE DG-DIGEST = DG-H1 * 1000000000 + DG-H2.

       DG-ADD.
      *> pieces never start with a blank (the key was TRIMmed), so the
      *> TRIM length is the right-trimmed length and inner blanks stay
           COMPUTE DG-PLEN = FUNCTION LENGTH(FUNCTION TRIM(DG-PIECE)).
           IF DG-PLEN > 0
               MOVE DG-PIECE(1:DG-PLEN) TO DG-SRC(DG-PTR:DG-PLEN)
               ADD DG-PLEN TO DG-PTR
           END-IF.


      *> Field readers and validators
 
       READ-FIELD.
      *> T-IN/T-LEN <- body field F-NAME; F-FOUND = Y/N. Form bodies go
      *> through WEB READ FORMFIELD, JSON bodies were already parsed
      *> into JI-REC by PARSE-JSON-BODY.
           MOVE SPACES TO T-IN.
           MOVE 0 TO T-LEN.
           MOVE 'N' TO F-FOUND.
           IF WS-JSON-IN = 'Y'
               PERFORM READ-JSON-FIELD
               EXIT PARAGRAPH
           END-IF.
           EXEC CICS WEB READ FORMFIELD(F-NAME) VALUE(T-IN) LENGTH(T-LEN)
                RESP(WS-RESP) END-EXEC.
           IF WS-RESP = DFHRESP(NORMAL)
               MOVE 'Y' TO F-FOUND
           ELSE
               MOVE 0 TO T-LEN
           END-IF.

       READ-JSON-FIELD.
      *> A member still holding LOW-VALUES was not in the JSON at all
      *> (or was null). For the rest the length is "up to the last
      *> non-blank", like a form field would report it after trimming
      *> the padding -- counted with INSPECT on the reversed text.
           EVALUATE TRUE
               WHEN F-NAME = 'user' AND JI-USER NOT = LOW-VALUES
                   MOVE JI-USER TO T-IN
               WHEN F-NAME = 'key' AND JI-KEY NOT = LOW-VALUES
                   MOVE JI-KEY TO T-IN
               WHEN F-NAME = 'name' AND JI-NAME NOT = LOW-VALUES
                   MOVE JI-NAME TO T-IN
               WHEN F-NAME = 'title' AND JI-TITLE NOT = LOW-VALUES
                   MOVE JI-TITLE TO T-IN
               WHEN F-NAME = 'priority' AND JI-PRIO NOT = LOW-VALUES
                   MOVE JI-PRIO TO T-IN
               WHEN F-NAME = 'version' AND JI-VERSION NOT = LOW-VALUES
                   MOVE JI-VERSION TO T-IN
               WHEN F-NAME = 'done' AND JI-DONE NOT = LOW-VALUES
                   MOVE JI-DONE TO T-IN
               WHEN OTHER
                   EXIT PARAGRAPH
           END-EVALUATE.
           MOVE 'Y' TO F-FOUND.
           MOVE FUNCTION REVERSE(T-IN) TO JI-REV.
           MOVE 0 TO JI-TRAIL.
           INSPECT JI-REV TALLYING JI-TRAIL FOR LEADING SPACES.
           COMPUTE T-LEN = 4096 - JI-TRAIL.

       READ-QPARM.
           MOVE SPACES TO T-IN.
           MOVE 0 TO T-LEN.
           MOVE 'N' TO F-FOUND.
           EXEC CICS WEB READ QUERYPARM(F-NAME) VALUE(T-IN) LENGTH(T-LEN)
                RESP(WS-RESP) END-EXEC.
           IF WS-RESP = DFHRESP(NORMAL)
               MOVE 'Y' TO F-FOUND
           ELSE
               MOVE 0 TO T-LEN
           END-IF.

       READ-HEADER.
      *> T-IN/T-LEN <- request header F-NAME (NOTFND -> length 0)
           MOVE SPACES TO T-IN.
           MOVE 0 TO T-LEN.
           EXEC CICS WEB READ HTTPHEADER(F-NAME) VALUE(T-IN) LENGTH(T-LEN)
                RESP(WS-RESP) END-EXEC.
           IF WS-RESP NOT = DFHRESP(NORMAL)
               MOVE 0 TO T-LEN
           END-IF.

       T-TO-V.
           MOVE T-IN TO V-IN.
           MOVE T-LEN TO V-LEN.

       CHECK-NAME-ID.
      *> user name: 1-16 of [a-z0-9-], first one a letter. Lower-cased
      *> and stripped of surrounding blanks first, so " Moshix " is
      *> just "moshix". V-LEN comes in as the raw length; anything over
      *> the 64 byte buffer can't be a valid name anyway.
           MOVE 'N' TO V-OK.
           MOVE SPACES TO V-OUT.
           IF V-LEN > 64
               MOVE 0 TO V-LEN
           END-IF.
           IF V-LEN > 0
               MOVE FUNCTION LOWER-CASE(FUNCTION TRIM(V-IN)) TO V-IN
               COMPUTE V-LEN = FUNCTION LENGTH(FUNCTION TRIM(V-IN))
           END-IF.
           IF V-LEN >= 1 AND V-LEN <= 16
              AND FUNCTION POS(V-IN(1:1), WS-LOWER) > 0
               MOVE 'Y' TO V-OK
               PERFORM VARYING V-I FROM 1 BY 1 UNTIL V-I > V-LEN
                   IF FUNCTION POS(V-IN(V-I:1), WS-IDCH) = 0
                       MOVE 'N' TO V-OK
                   END-IF
               END-PERFORM
           END-IF.
           IF V-OK = 'Y'
               MOVE V-IN(1:V-LEN) TO V-OUT
           END-IF.

       CHECK-KEY.
      *> Password: no length or complexity rules on purpose. Any of
      *> x'20'..x'7E', not blank, at most 128 chars once trimmed (that
      *> cap only keeps AU-KEY and the digest loop bounded). Leading and
      *> trailing blanks are dropped -- HTTP strips them off header
      *> values anyway, so the body side has to do the same or the user
      *> could never log in.
           MOVE 128 TO T-MAX.
           PERFORM CHECK-TEXT.

       CHECK-TEXT.
      *> T-IN/T-LEN -> T-OUT. Every byte must be x'20'..x'7E' (so a JSON
      *> é or a raw UTF-8 byte is turned away just like a tab), then
      *> 1..T-MAX chars once leading/trailing spaces are trimmed.
           MOVE 'N' TO T-OK.
           MOVE SPACES TO T-OUT.
           MOVE 0 TO T-TLEN.
           IF T-LEN > 0 AND T-LEN <= 4096
               MOVE 'Y' TO T-OK
               PERFORM VARYING V-I FROM 1 BY 1
                       UNTIL V-I > T-LEN OR T-OK = 'N'
                   IF T-IN(V-I:1) NOT = SPACE
                      AND FUNCTION POS(T-IN(V-I:1), WS-PRINT) = 0
                       MOVE 'N' TO T-OK
                   END-IF
               END-PERFORM
           END-IF.
           IF T-OK = 'Y'
               COMPUTE T-TLEN = FUNCTION LENGTH(FUNCTION TRIM(T-IN))
               IF T-TLEN < 1 OR T-TLEN > T-MAX
                   MOVE 'N' TO T-OK
               ELSE
                   MOVE FUNCTION TRIM(T-IN) TO T-OUT
               END-IF
           END-IF.

       CHECK-NUM.
      *> N-IN(1:N-LEN) must be 1..N-MAX digits -> N-VAL
           MOVE 'N' TO N-OK.
           MOVE 0 TO N-VAL.
           IF N-LEN >= 1 AND N-LEN <= N-MAX
               MOVE 'Y' TO N-OK
               PERFORM VARYING V-I FROM 1 BY 1 UNTIL V-I > N-LEN
                   IF FUNCTION POS(N-IN(V-I:1), WS-DIGITS) = 0
                       MOVE 'N' TO N-OK
                   END-IF
               END-PERFORM
           END-IF.
      *> only now is NUMVAL safe -- it abends on anything non numeric
           IF N-OK = 'Y'
               COMPUTE N-VAL = FUNCTION NUMVAL(N-IN(1:N-LEN))
           END-IF.

       GET-LIST-ID.
      *> the {list} capture is the truth; it must also be exactly what
      *> sits in the path segment we dispatched on
           MOVE CAP-LIST TO N-IN.
           MOVE CAP-LIST-LEN TO N-LEN.
           MOVE 6 TO N-MAX.
           PERFORM CHECK-NUM.
           IF CAP-LIST-SET NOT = 'Y' OR CAP-LIST NOT = WS-SEG2
              OR N-VAL = 0
               MOVE 'N' TO N-OK
           END-IF.
           IF N-OK = 'N'
               MOVE 400 TO WS-STATUS
               MOVE 'BADID' TO E-CODE
               MOVE 'list id must be 1-6 digits and above zero' TO E-MSG
               PERFORM SET-ERR
           ELSE
               MOVE N-VAL TO P-LIST
               MOVE P-LIST TO K-LST-ID K-ITM-LST
           END-IF.

       GET-ITEM-ID.
           MOVE CAP-ID TO N-IN.
           MOVE CAP-ID-LEN TO N-LEN.
           MOVE 8 TO N-MAX.
           PERFORM CHECK-NUM.
           IF CAP-ID-SET NOT = 'Y' OR CAP-ID NOT = WS-SEG4
              OR N-VAL = 0
               MOVE 'N' TO N-OK
           END-IF.
           IF N-OK = 'N'
               MOVE 400 TO WS-STATUS
               MOVE 'BADID' TO E-CODE
               MOVE 'item id must be 1-8 digits and above zero' TO E-MSG
               PERFORM SET-ERR
           ELSE
               MOVE N-VAL TO P-ITEM
               MOVE P-ITEM TO K-ITM-ID
           END-IF.

       GET-VERSION.
      *> uses whatever READ-FIELD / READ-QPARM just left in T-IN
           MOVE 'N' TO P-VER-SET.
           IF F-FOUND = 'N'
               EXIT PARAGRAPH
           END-IF.
           MOVE T-IN TO N-IN.
           MOVE T-LEN TO N-LEN.
           MOVE 6 TO N-MAX.
           PERFORM CHECK-NUM.
      *> versions start at 1, so 0 can only be a mistake
           IF N-OK = 'Y' AND N-VAL > 0
               MOVE N-VAL TO P-VERSION
               MOVE 'Y' TO P-VER-SET
           ELSE
               MOVE 'X' TO P-VER-SET
           END-IF.

       GET-QVERSION.
      *> optional ?version= on DELETE; present-but-bad is a 400
           MOVE 'version' TO F-NAME.
           PERFORM READ-QPARM.
           PERFORM GET-VERSION.
           IF P-VER-SET = 'X'
               PERFORM ERR-BADVERSION
           END-IF.

       GET-NAME.
           MOVE 'name' TO F-NAME.
           PERFORM READ-FIELD.
           IF F-FOUND = 'N'
               MOVE 0 TO T-LEN
           END-IF.
           MOVE 40 TO T-MAX.
           PERFORM CHECK-TEXT.
           IF T-OK = 'Y'
               MOVE T-OUT TO P-NAME
           END-IF.

       GET-PRIO.
      *> optional; empty counts as not given
           MOVE 'N' TO P-PRIO-SET.
           MOVE 'priority' TO F-NAME.
           PERFORM READ-FIELD.
           IF F-FOUND = 'N' OR T-LEN = 0
               EXIT PARAGRAPH
           END-IF.
           MOVE FUNCTION UPPER-CASE(T-IN(1:1)) TO P-PRIO.
           IF T-LEN NOT = 1
              OR NOT (P-PRIO = 'L' OR P-PRIO = 'N' OR P-PRIO = 'H')
               MOVE 400 TO WS-STATUS
               MOVE 'BADPRIO' TO E-CODE
               MOVE 'priority must be L, N or H' TO E-MSG
               PERFORM SET-ERR
           ELSE
               MOVE 'Y' TO P-PRIO-SET
           END-IF.


      *> COLLECT-ITEMS -- ids of this list's items (all, or only done
      *> ones when WS-ALLDONE = 'N') into WS-TID / WS-TN. Browse is
      *> closed again before the caller starts deleting.

       COLLECT-ITEMS.
           MOVE 0 TO WS-TN.
           MOVE 'N' TO WS-TOVER.
           MOVE 'N' TO WS-BR-END.
           MOVE 'N' TO WS-BR-BAD.
           MOVE 0 TO K-ITM-ID.
           MOVE 'TODOITM' TO WS-FILE.
           EXEC CICS STARTBR FILE('TODOITM') RIDFLD(K-ITM) GTEQ
                RESP(WS-RESP) END-EXEC.
           EVALUATE WS-RESP
               WHEN DFHRESP(NOTFND)
                   MOVE 'Y' TO WS-BR-END
               WHEN DFHRESP(NORMAL)
                   PERFORM UNTIL WS-BR-END = 'Y'
                       EXEC CICS READNEXT FILE('TODOITM') INTO(ITM-REC)
                            RIDFLD(K-BR) RESP(WS-RESP) END-EXEC
                       EVALUATE TRUE
                           WHEN WS-RESP = DFHRESP(ENDFILE)
                               MOVE 'Y' TO WS-BR-END
                           WHEN WS-RESP NOT = DFHRESP(NORMAL)
                               MOVE 'Y' TO WS-BR-END
                               MOVE 'Y' TO WS-BR-BAD
                           WHEN ITM-USER NOT = AU-USER
                             OR ITM-LIST NOT = P-LIST
                               MOVE 'Y' TO WS-BR-END
                           WHEN WS-ALLDONE = 'N' AND ITM-DONE NOT = 'Y'
                               CONTINUE
                           WHEN WS-TN >= 200
                               MOVE 'Y' TO WS-TOVER
                               MOVE 'Y' TO WS-BR-END
                           WHEN OTHER
                               ADD 1 TO WS-TN
                               MOVE ITM-ID TO WS-TID(WS-TN)
                       END-EVALUATE
                   END-PERFORM
                   EXEC CICS ENDBR FILE('TODOITM') RESP(WS-RESP2) END-EXEC
               WHEN OTHER
                   MOVE 'Y' TO WS-BR-END
                   MOVE 'Y' TO WS-BR-BAD
           END-EVALUATE.
           MOVE 0 TO K-ITM-ID.
           EVALUATE TRUE
               WHEN WS-BR-BAD = 'Y'
                   PERFORM FAIL-IO
               WHEN WS-TOVER = 'Y'
                   EXEC CICS SYNCPOINT ROLLBACK RESP(WS-RESP2) END-EXEC
                   MOVE 500 TO WS-STATUS
                   MOVE 'IOERR' TO E-CODE
                   MOVE 'TODOITM more than 200 items in list' TO E-MSG
                   PERFORM SET-ERR
           END-EVALUATE.


      *> Time stamp YYYY-MM-DDTHH:MM:SS (UTC) into WS-NOW

       GET-NOW.
           EXEC CICS ASKTIME ABSTIME(WS-ABS) RESP(WS-RESP2) END-EXEC.
           EXEC CICS FORMATTIME ABSTIME(WS-ABS) YYYYMMDD(WS-DATE)
                DATESEP('-') TIME(WS-TIME) TIMESEP(':')
                TIMEZONE('UTC') RESP(WS-RESP2) END-EXEC.
           MOVE SPACES TO WS-NOW.
           STRING WS-DATE 'T' WS-TIME DELIMITED BY SIZE INTO WS-NOW
           END-STRING.


      *> Error helpers

       FAIL-IO.
      *> Something unexpected came back from a file verb. Undo the
      *> whole UOW and say which file / RESP -- nothing more.
           MOVE WS-RESP TO JS-ED.
           MOVE FUNCTION TRIM(JS-ED) TO JS-NUMTXT.
           EXEC CICS SYNCPOINT ROLLBACK RESP(WS-RESP2) END-EXEC.
           MOVE 500 TO WS-STATUS.
           MOVE 'IOERR' TO E-CODE.
           STRING WS-FILE DELIMITED BY SPACE
                  ' RESP ' DELIMITED BY SIZE
                  JS-NUMTXT DELIMITED BY SPACE
               INTO E-MSG
           END-STRING.
           PERFORM SET-ERR.

       FAIL-BUSY.
           EXEC CICS SYNCPOINT ROLLBACK RESP(WS-RESP2) END-EXEC.
           MOVE 409 TO WS-STATUS.
           MOVE 'BUSY' TO E-CODE.
           MOVE 'record busy, retry' TO E-MSG.
           PERFORM SET-ERR.

       FAIL-LIST-GONE.
      *> the list was deleted under us in the middle of a UOW
           EXEC CICS SYNCPOINT ROLLBACK RESP(WS-RESP2) END-EXEC.
           PERFORM ERR-LIST-404.

       BUSY-PAUSE.
      *> Only used in front of the first READ UPDATE(s) of a UOW, while
      *> nothing is written yet: a short nap before trying again beats
      *> bouncing a 409 straight back at the client.
           IF WS-TRY > 0
               EXEC CICS DELAY FOR MILLISECS(25) RESP(WS-RESP2) END-EXEC
           END-IF.

       DO-COMMIT.
      *> Called after the success reply is already in JSON-BUF. If that
      *> reply didn't fit, undo the UOW (SEND-RESPONSE then answers 500)
      *> so a client retry can't duplicate a write it never saw.
      *> SYNCPOINT itself can fail (ROLLEDBACK); if that occured, no 2xx.
           IF WS-JSFAIL = 'Y'
               EXEC CICS SYNCPOINT ROLLBACK RESP(WS-RESP2) END-EXEC
               EXIT PARAGRAPH
           END-IF.
           EXEC CICS SYNCPOINT RESP(WS-RESP) END-EXEC.
           IF WS-RESP NOT = DFHRESP(NORMAL)
               MOVE 'SYNCPT' TO WS-FILE
               PERFORM FAIL-IO
           END-IF.

       ERR-BADKEY.
           MOVE 400 TO WS-STATUS.
           MOVE 'BADKEY' TO E-CODE.
           IF T-TLEN > 128
               MOVE 'password too long' TO E-MSG
           ELSE
               MOVE 'password must be printable ASCII and not blank'
                   TO E-MSG
           END-IF.
           PERFORM SET-ERR.

       ERR-BADNAME.
           MOVE 400 TO WS-STATUS.
           MOVE 'BADNAME' TO E-CODE.
           MOVE 'name must be 1-40 printable chars' TO E-MSG.
           PERFORM SET-ERR.

       ERR-BADTITLE.
           MOVE 400 TO WS-STATUS.
           MOVE 'BADTITLE' TO E-CODE.
           MOVE 'title must be 1-80 printable chars' TO E-MSG.
           PERFORM SET-ERR.

       ERR-BADVERSION.
           MOVE 400 TO WS-STATUS.
           MOVE 'BADVERSION' TO E-CODE.
           MOVE 'version must be 1-6 digits and above zero' TO E-MSG.
           PERFORM SET-ERR.

       ERR-AUTH-401.
           MOVE 401 TO WS-STATUS.
           MOVE 'UNAUTHORIZED' TO E-CODE.
           MOVE 'user or key is wrong' TO E-MSG.
           PERFORM SET-ERR.

       ERR-CONFLICT.
           MOVE 409 TO WS-STATUS.
           MOVE 'CONFLICT' TO E-CODE.
           MOVE 'version mismatch, somebody changed it first' TO E-MSG.
           PERFORM SET-ERR.

       ERR-LIST-404.
           MOVE P-LIST TO JS-ED.
           MOVE FUNCTION TRIM(JS-ED) TO JS-NUMTXT.
           STRING 'list ' DELIMITED BY SIZE
                  JS-NUMTXT DELIMITED BY SPACE
                  ' not found' DELIMITED BY SIZE
               INTO E-MSG
           END-STRING.
           MOVE 404 TO WS-STATUS.
           MOVE 'NOTFOUND' TO E-CODE.
           PERFORM SET-ERR.

       ERR-ITEM-404.
           MOVE P-ITEM TO JS-ED.
           MOVE FUNCTION TRIM(JS-ED) TO JS-NUMTXT.
           STRING 'item ' DELIMITED BY SIZE
                  JS-NUMTXT DELIMITED BY SPACE
                  ' not found' DELIMITED BY SIZE
               INTO E-MSG
           END-STRING.
           MOVE 404 TO WS-STATUS.
           MOVE 'NOTFOUND' TO E-CODE.
           PERFORM SET-ERR.

       SET-ERR.
      *> Throws away anything built so far and writes the error body:
      *> {"error":{"code":"..","message":".."}} from JSON GENERATE. For
      *> a CONFLICT the generated object is opened up before its last
      *> brace and ,"current":{item or list} is put in.
           MOVE 'Y' TO WS-ERR.
           MOVE 'N' TO WS-JSFAIL.
           MOVE SPACES TO JSON-BUF.
           MOVE 1 TO JS-PTR.
           MOVE E-CODE TO JO-E-CODE.
           MOVE E-MSG TO JO-E-MSG.
           JSON GENERATE JS-PIECE FROM JO-ERR COUNT IN JS-PLEN
               NAME OF JO-ERR IS OMITTED JO-ERROR IS 'error'
                    JO-E-CODE IS 'code' JO-E-MSG IS 'message'
               ON EXCEPTION PERFORM FAIL-JSON
           END-JSON.
           IF E-CUR NOT = 'I' AND NOT = 'L'
               PERFORM PUT-PIECE
               EXIT PARAGRAPH
           END-IF.
           SUBTRACT 1 FROM JS-PLEN.
           PERFORM PUT-PIECE.
           STRING ',"current":' DELIMITED BY SIZE
               INTO JSON-BUF WITH POINTER JS-PTR
               ON OVERFLOW PERFORM FAIL-JSON
           END-STRING.
           IF E-CUR = 'I'
               PERFORM GEN-ITEM
           ELSE
               PERFORM GEN-LIST
           END-IF.
           PERFORM PUT-PIECE.
           STRING '}' DELIMITED BY SIZE
               INTO JSON-BUF WITH POINTER JS-PTR
               ON OVERFLOW PERFORM FAIL-JSON
           END-STRING.


      *> JSON output. GEN-* fill a JO-* record and JSON GENERATE it into
      *> JS-PIECE / JS-PLEN; PUT-* append to JSON-BUF at JS-PTR with
      *> STRING ... WITH POINTER. Any overflow (receiver too small)
      *> sets WS-JSFAIL and SEND-RESPONSE turns that into a 500.

       GEN-LIST.
           MOVE LST-ID TO JO-L-ID.
           MOVE LST-NAME TO JO-L-NAME.
           MOVE LST-COUNT TO JO-L-COUNT.
           MOVE LST-DONE TO JO-L-DONE.
           MOVE LST-VERSION TO JO-L-VERSION.
           MOVE LST-CREATED TO JO-L-CREATED.
           MOVE LST-UPDATED TO JO-L-UPDATED.
           MOVE 'Z' TO JO-L-CREATED(20:1) JO-L-UPDATED(20:1).
           JSON GENERATE JS-PIECE FROM JO-LIST COUNT IN JS-PLEN
               NAME OF JO-LIST IS OMITTED
                    JO-L-ID IS 'id' JO-L-NAME IS 'name'
                    JO-L-COUNT IS 'count' JO-L-DONE IS 'done'
                    JO-L-VERSION IS 'version'
                    JO-L-CREATED IS 'created' JO-L-UPDATED IS 'updated'
               ON EXCEPTION PERFORM FAIL-JSON
           END-JSON.

       GEN-ITEM.
           MOVE ITM-ID TO JO-I-ID.
           MOVE ITM-LIST TO JO-I-LIST.
           MOVE ITM-TITLE TO JO-I-TITLE.
           MOVE ITM-DONE TO JO-I-DONE.
           MOVE ITM-PRIO TO JO-I-PRIO.
           MOVE ITM-VERSION TO JO-I-VERSION.
           MOVE ITM-CREATED TO JO-I-CREATED.
           MOVE ITM-UPDATED TO JO-I-UPDATED.
           MOVE 'Z' TO JO-I-CREATED(20:1) JO-I-UPDATED(20:1).
           JSON GENERATE JS-PIECE FROM JO-ITEM COUNT IN JS-PLEN
               NAME OF JO-ITEM IS OMITTED
                    JO-I-ID IS 'id' JO-I-LIST IS 'list'
                    JO-I-TITLE IS 'title' JO-I-DONE IS 'done'
                    JO-I-PRIO IS 'priority' JO-I-VERSION IS 'version'
                    JO-I-CREATED IS 'created' JO-I-UPDATED IS 'updated'
               CONVERTING JO-I-DONE TO JSON BOOLEAN USING 'Y'
               ON EXCEPTION PERFORM FAIL-JSON
           END-JSON.

       GEN-DELETED.
      *> {"deleted":n} for purge and item delete
           JSON GENERATE JS-PIECE FROM JO-DEL COUNT IN JS-PLEN
               NAME OF JO-DEL IS OMITTED JO-D-DELETED IS 'deleted'
               ON EXCEPTION PERFORM FAIL-JSON
           END-JSON.
           PERFORM PUT-PIECE.

       PUT-COUNT-TAIL.
      *> "count":n} -- generate {"count":n} and drop its opening brace
           MOVE WS-COUNT TO JO-C-COUNT.
           JSON GENERATE JS-PIECE FROM JO-COUNT COUNT IN JS-PLEN
               NAME OF JO-COUNT IS OMITTED JO-C-COUNT IS 'count'
               ON EXCEPTION PERFORM FAIL-JSON
           END-JSON.
           IF WS-JSFAIL = 'N'
               STRING JS-PIECE(2:JS-PLEN - 1) DELIMITED BY SIZE
                   INTO JSON-BUF WITH POINTER JS-PTR
                   ON OVERFLOW PERFORM FAIL-JSON
               END-STRING
           END-IF.

       PUT-PIECE.
           IF WS-JSFAIL = 'Y' OR JS-PLEN = 0
               EXIT PARAGRAPH
           END-IF.
           STRING JS-PIECE(1:JS-PLEN) DELIMITED BY SIZE
               INTO JSON-BUF WITH POINTER JS-PTR
               ON OVERFLOW PERFORM FAIL-JSON
           END-STRING.

       PUT-COMMA.
           IF JS-FIRST = 'Y'
               MOVE 'N' TO JS-FIRST
           ELSE
               STRING ',' DELIMITED BY SIZE
                   INTO JSON-BUF WITH POINTER JS-PTR
                   ON OVERFLOW PERFORM FAIL-JSON
               END-STRING
           END-IF.

       FAIL-JSON.
           MOVE 'Y' TO WS-JSFAIL.


      *> One and only WEB SEND
 
       SEND-RESPONSE.
      *> A response that didn't fit is a server problem, never a 2xx.
      *> (The buffers are sized for the worst case -- 200 fully escaped
      *> items is about 62,650 bytes so this is belt and braces.)
           IF WS-JSFAIL = 'Y'
               MOVE SPACE TO E-CUR
               MOVE 500 TO WS-STATUS
               MOVE 'JSONERR' TO E-CODE
               MOVE 'response does not fit the reply buffer' TO E-MSG
               PERFORM SET-ERR
           END-IF.
           COMPUTE JS-LEN = JS-PTR - 1.
           EXEC CICS WEB WRITE HTTPHEADER('Cache-Control')
                VALUE('no-store') RESP(WS-RESP2) END-EXEC.
           EXEC CICS WEB SEND FROM(JSON-BUF) LENGTH(JS-LEN)
                STATUSCODE(WS-STATUS) MEDIATYPE('application/json')
                RESP(WS-RESP2) END-EXEC.

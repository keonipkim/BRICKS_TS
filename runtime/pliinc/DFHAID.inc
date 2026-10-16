/* DFHAID - 3270 attention-identifier (AID) byte mnemonics.          */
/*                                                                   */
/* %INCLUDE DFHAID; inside the MAIN procedure, then compare EIBAID   */
/* against named bytes instead of raw hex literals:                  */
/*                                                                   */
/*    IF EIBAID = PF03   THEN ...      bricks mnemonic               */
/*    IF EIBAID = DFHPF3 THEN ...      classic CICS alias            */
/*                                                                   */
/* Every key is declared twice, once under the bricks-style short    */
/* name (PF01..PF24, ENTER, CLEAR, PA1..PA3) and once under the      */
/* IBM-traditional DFH-prefixed alias. Both names have the same      */
/* VALUE. Mirrors runtime/cobolcopy/DFHAID.cpy.                      */

DCL ENTER     CHAR(1) VALUE('7D'X);
DCL DFHENTER  CHAR(1) VALUE('7D'X);
DCL CLEAR     CHAR(1) VALUE('6D'X);
DCL DFHCLEAR  CHAR(1) VALUE('6D'X);
DCL PA1       CHAR(1) VALUE('6C'X);
DCL DFHPA1    CHAR(1) VALUE('6C'X);
DCL PA2       CHAR(1) VALUE('6E'X);
DCL DFHPA2    CHAR(1) VALUE('6E'X);
DCL PA3       CHAR(1) VALUE('6B'X);
DCL DFHPA3    CHAR(1) VALUE('6B'X);
DCL PF01      CHAR(1) VALUE('F1'X);
DCL DFHPF1    CHAR(1) VALUE('F1'X);
DCL PF02      CHAR(1) VALUE('F2'X);
DCL DFHPF2    CHAR(1) VALUE('F2'X);
DCL PF03      CHAR(1) VALUE('F3'X);
DCL DFHPF3    CHAR(1) VALUE('F3'X);
DCL PF04      CHAR(1) VALUE('F4'X);
DCL DFHPF4    CHAR(1) VALUE('F4'X);
DCL PF05      CHAR(1) VALUE('F5'X);
DCL DFHPF5    CHAR(1) VALUE('F5'X);
DCL PF06      CHAR(1) VALUE('F6'X);
DCL DFHPF6    CHAR(1) VALUE('F6'X);
DCL PF07      CHAR(1) VALUE('F7'X);
DCL DFHPF7    CHAR(1) VALUE('F7'X);
DCL PF08      CHAR(1) VALUE('F8'X);
DCL DFHPF8    CHAR(1) VALUE('F8'X);
DCL PF09      CHAR(1) VALUE('F9'X);
DCL DFHPF9    CHAR(1) VALUE('F9'X);
DCL PF10      CHAR(1) VALUE('7A'X);
DCL DFHPF10   CHAR(1) VALUE('7A'X);
DCL PF11      CHAR(1) VALUE('7B'X);
DCL DFHPF11   CHAR(1) VALUE('7B'X);
DCL PF12      CHAR(1) VALUE('7C'X);
DCL DFHPF12   CHAR(1) VALUE('7C'X);
DCL PF13      CHAR(1) VALUE('C1'X);
DCL DFHPF13   CHAR(1) VALUE('C1'X);
DCL PF14      CHAR(1) VALUE('C2'X);
DCL DFHPF14   CHAR(1) VALUE('C2'X);
DCL PF15      CHAR(1) VALUE('C3'X);
DCL DFHPF15   CHAR(1) VALUE('C3'X);
DCL PF16      CHAR(1) VALUE('C4'X);
DCL DFHPF16   CHAR(1) VALUE('C4'X);
DCL PF17      CHAR(1) VALUE('C5'X);
DCL DFHPF17   CHAR(1) VALUE('C5'X);
DCL PF18      CHAR(1) VALUE('C6'X);
DCL DFHPF18   CHAR(1) VALUE('C6'X);
DCL PF19      CHAR(1) VALUE('C7'X);
DCL DFHPF19   CHAR(1) VALUE('C7'X);
DCL PF20      CHAR(1) VALUE('C8'X);
DCL DFHPF20   CHAR(1) VALUE('C8'X);
DCL PF21      CHAR(1) VALUE('C9'X);
DCL DFHPF21   CHAR(1) VALUE('C9'X);
DCL PF22      CHAR(1) VALUE('4A'X);
DCL DFHPF22   CHAR(1) VALUE('4A'X);
DCL PF23      CHAR(1) VALUE('4B'X);
DCL DFHPF23   CHAR(1) VALUE('4B'X);
DCL PF24      CHAR(1) VALUE('4C'X);
DCL DFHPF24   CHAR(1) VALUE('4C'X);

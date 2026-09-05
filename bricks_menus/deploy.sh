#!/bin/bash
# Run this from your BRICKS root directory
BRICKS_ROOT="."
cp bricks_menus/map/*.map   "$BRICKS_ROOT/runtime/map/"
cp bricks_menus/rexx/*.rexx "$BRICKS_ROOT/runtime/rexx/"
echo "Deployed all maps and REXX programs."
echo ""
echo "Now add these to runtime/transactions.conf if missing:"
cat bricks_menus/transactions_additions.conf
echo ""
echo "Do not replace the sample HELP transaction. Menu help is MHLP."
echo "And set in bricks.cnf:  start_transaction = MYMU"

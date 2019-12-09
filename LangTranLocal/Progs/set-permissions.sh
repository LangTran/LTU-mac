#!/bin/sh
# set-permissions.sh
# makes LangTranUpdate and LangTranUpdate/Progs writable by group.
#
chgrp -R langtran /Users/Shared/LangTranLocal
chmod g+ws /Users/Shared/LangTranLocal
chmod g+ws /Users/Shared/LangTranLocal/Progs

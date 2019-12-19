#!/bin/bash
# LangTranUpdate.sh
#
# This is a comment, because it begins with "#".
#
# This script will find the folders you want to update
# from the LangTran system,
# and for each one
#     if there is no folder for that folder
#         it will make it.
#     It will then update that folder from the LangTran server.
#
# Version 3.06, last edited 2019-12-14 at 21:29
# This version, when pruning the archive, does pushd to the folder
# and then calls PruneArchive.sh, then does popd back again.
#
MYNAME=$0
echo 

case `uname` in
    Linux)
	LTBehaviour=Behaviour.sh
	LTplatform=Linux
	;;
    Darwin)
	LTBehaviour=Behaviour.txt
	LTplatform=Mac

	# On a Mac, when you double-click a shell script,
	# it runs in your home directory,
	# so a cd to the installed folder is needed.
	LTUhome=/Users/Shared/LangTranLocal
	cd $LTUhome ||
	{
	    echo $MYNAME: Failed to cd to $LTUhome. Please investigate >&2
	    exit 1
	}
	;;
esac

echo "Don't let the text window startle you."
echo "I'm using it to report my progress."
echo 
echo This program is part of the LangTran system,
echo and its full path and name is
echo The current directory is `pwd` 
echo and my name is $0
# echo Here are the processes:
# ps -f
echo
echo This program copies the files in the folders that you have selected
echo from the LangTran server onto your computer, in the current folder,
echo by default, /Users/Shared/LangTranLocal

export LTserver=63.142.243.28
LangTranList=LangTranList.txt
export FolderCount=FoldersUpdated.txt
FirstRun=FirstRun.txt
PATHbak="$PATH"
# echo path starts as $PATH
PATH=.:"`pwd`/Progs:$PATH"
# echo path is now $PATH
echo HOME is $HOME.
echo

# function to end the script, called from several places.
#
EndScript () {
    FolderCountSize=`ls -l Progs/FoldersUpdated.txt | awk '{print $5}'`

    if [ -s Progs/$FolderCount ]
    then
        if [ "$FolderCountSize" -gt 5 ]
        then
            echo I have updated your computer from the LangTran server.
            cat Progs/$FolderCount
            echo
        fi
    fi

    cat Progs/$FirstRun
    PATH=$PATHbak
    # echo path is now $PATH
    
    # Remove command to kill this script.
    #
    if [ -s Progs/Kill_LTupdate.sh ]
    then
        rm Progs/Kill_LTupdate.sh
    fi
    
    if [ "${Silent}" != "yes" ]
    then
        read -n1 -r -p "Press any key to continue... " key   # = DOS pause
    fi
    exit 0
}

# Function to format listing of files like this:
#
# Jan 21 01:16  9.2K LangTranUpdate.sh*
# Dec 29 13:15  9.1K LangTranUpdate.sh~*
# Jan 20 21:35     0 Progs/
# 
# FileLists:
# Jan 21 01:16  2.0K LTF_20160121_0116.txt*
# 
# Progs:
# Jan 19  2015   52K diff2html.sh*
# Jan 21 01:16   212 FirstRun.txt*
#
ListMyFiles () {
    ls -FhlR | 
        sed -e '/^total [0-9]/d' -e 's/^\.\///' | 
        awk '/^[dl-]/ \
            {printf "%s %2s %5s %5s", $6, $7, $8, $5;
            for(i=9;i<=NF;++i)printf " %s", $i; 
            printf "\n"}
            /^[^dl-]/
            /^ *$/'
}

RemoveAny () {
    while read line
    do
        rm "$line"
    done
}

# Make sure the folders FileLists and Diffs exist.
[ -d FileLists ] || mkdir FileLists
[ -d Diffs ] || mkdir Diffs

# Set the default values for variables to control behaviour.
#
DiffContext=1
PruneDiffs=yes
ShowDifferences=yes
KeepNr=31
Persistent=no
# TiMeOut delay in seconds (5 minutes)
export Tmo=300
KeepArchive=no
ArchiveDir=~/Downloads/archive
KeepArchNr=4


# Get the control file, changing the values of some variables.
. ./$LTBehaviour || 
    {
	echo "I wasn't able to load the contents of ${LTBehaviour}."
	echo "Please investigate."
    } >&2

[ "$Persistent" = "yes" ] && echo Persistent mode is on.

# First thing after installation, when the installer runs this script,
# give the user an opportunity not to proceed.
#
if [ ! -f Progs/$FolderCount ]
then
    {
        echo -e "\r"
        echo -e "When you want to run this LangTran Update program another time,\r"

	case $LTplatform in
	    Linux)
		echo -e "Double-click the icon on the desktop\r"
		echo -e "or open the START menu, go to the Internet section\r"
		echo -e "and click LangTranUpdate.\r"
		echo -e " \r"
		echo -e "If you want to change update behaviour,\r"
		echo -e "open the menu for Preferences and click a LangTran item.\r"
		;;
	    Mac)
		echo -e "Use Finder to go to $LTUhome\r"
		echo -e "and double-click LangTranUpdate.\r"
		echo -e " \r"
		echo -e "If you want to change update behaviour,\r"
		echo -e "in the folder $LTUhome, double-click Behaviour.txt\r"
		;;
	esac

    } >  Progs/$FirstRun
    
    echo "I'm running because the software installer started me."
    Answer=y
    
    # echo Silent is $Silent
    
    if [ "$Silent" != "yes" ]
    then
        echo If you want to do your first update now, type y otherwise type n
        read -p "Do you want to do the first update now? [Yn] " -t 10 Answer
    fi

    case "$Answer" in
        [Yy]*|'')
            # Answer is yes or nothing, so skipping down.
            ;;
        *)
            # ending the script
            EndScript
            ;;
    esac
fi

# Make a list of the files here before we download any.
FirstTime=`date +%Y%m%d_%H%M`

{
    echo Listing made at $FirstTime
    ListMyFiles
} > FileLists/LTF_$FirstTime.txt

# Now that Persistent mode is an option, the process could be running for hours.
# If Persistent is on, 
#    we'll remember the process ID of this script in Progs/Kill_LTupdate.sh,
#    so another job can kill this one if it goes on and on too long.
#

# If an earlier instance of this program is still running,
#     kill it.
#
[ -s Progs/Kill_LTupdate.sh ] && Progs/Kill_LTupdate.sh

# :SavePID
if [ "$Persistent" = "yes" ]
then
    # bash and dash provide the PID in $$, but other shells may not.
    #
    if [ "$$" = "" ]
    then
        echo "$0 here -- This shell does not provide PID in \$\$" 1>&2
        echo Please investigate. 1>&2
    else
        echo "/bin/kill $$" > Progs/Kill_LTupdate.sh
        echo "rm \$0" >> Progs/Kill_LTupdate.sh
        chmod +x Progs/Kill_LTupdate.sh
    fi
fi

echo

# Some old systems have a version of rsync that doesn't do --delete-delay
#
RsyncDelType=--delete-delay
export RsyncDelType

rsync $RsyncDelType --version 2>/dev/null >/dev/null || RsyncDelType=--delete-after

Attempts=5
# :WhileCheckingConnection
while [ "$Attempts" -gt 0 ]
do
    echo Please wait while I check for a connection to the LangTran server . . .
    rsync $LTserver:: | grep "LangTran Rsync Server"

    if [ $? = 0 ]
    then
        echo "That's what I wanted to see."
        break
    fi

    # :NoRsyncConnection
    echo
    echo "Error: it seems you don't have access to the LangTran server." 1>&2
    echo 1>&2
    echo "I'll try to see if I can find it." 1>&2
    echo Please note the results of this "ping" command: 1>&2
    ping -c 4 $LTserver 1>&2
    echo 1>&2
    echo Please check that you are connected to the internet 1>&2

    if [ "$Persistent" = "yes" ]
    then
        Attempts=$((Attempts - 1))
        echo "Number of attempts to try: $Attempts"
        continue
    fi

    echo then run this file 1>&2
    echo "\($0\)" 1>&2
    echo again. 1>&2
    EndScript
done

# :RsyncConnection
 
export FOLDERSUPDATED=0
echo $FOLDERSUPDATED > Progs/$FolderCount

# We have a connection, so let's get to work.
#
echo
echo Updating folders into the folder: `pwd`
echo

echo Checking for updates to the LangTranUpdate system first . . .
Progs/RsyncFolder.sh Mac/Mac/Basis_Mac
ERRORLEVEL=$?
# echo back from script RsyncFolder.sh, errorlevel is $ERRORLEVEL

FOLDERSUPDATED=0
echo $FOLDERSUPDATED > Progs/$FolderCount

# Now process the folders selected in the control file
#
cat LangTranList.txt |
while read line
do
    # echo Line is \"$line\"
    FolderToSync=`echo $line | sed -e '/^[[:space:]]*#/d' -e 's/#.*//' -e 's/[[:space:]]*$//'`
    if [ "$FolderToSync" != "" ]
    then
        echo Folder to sync is \"$FolderToSync\"
        RsyncFolder.sh "$FolderToSync"
        # echo FolderCount is `cat Progs/$FolderCount`
    fi
done

echo

# dir Progs/$FolderCount

# Make a list of the files here now.
#
TimeNow=`date +%Y%m%d_%H%M`
echo TimeNow is $TimeNow

echo Listing made at $TimeNow > FileLists/LTF_$TimeNow.txt
# ListMyFiles | sed 's/\\r*$/\\r/' >> FileLists/LTF_$TimeNow.txt
ListMyFiles >> FileLists/LTF_$TimeNow.txt

# Get the newest listing.
NewList=`ls -1r FileLists/LTF*.txt | sed -n 1p`

# and the one just before that.
PrevList=`ls -1r FileLists/LTF*.txt | sed -n 2p`

# Now to compare the two lists
{
    echo "\"@@\" markers show line numbers where the files are different."
    echo "\"-\" at start of line shows old version of file, or file removed."
    echo "\"+\" at start of line shows new version of file."
    echo "Unmarked lines are the context of changes."
} > Diffs/diff_$TimeNow.txt
# Check for pruning internal system files from diff file.
#
if [ "$PruneDiffs" != "" ]
then
    sed -e "/diff_[_0-9]*\.txt/d" -e "/LTF_[_0-9]*\.txt/d" -e "/FoldersUpdated.txt/d" $PrevList > Progs/Prev.txt
    PrevList=Progs/Prev.txt
    sed -e "/diff_[0-9_]*\.txt/d" -e "/LTF_[_0-9]*\.txt/d" -e "/FoldersUpdated.txt/d" $NewList > Progs/NewList.txt
    NewList=Progs/NewList.txt
fi

diff -U $DiffContext -I ' 0 .*/' -I "Kill_LTupdate.sh" $PrevList $NewList >> Diffs/diff_$TimeNow.txt
[ -f Progs/Prev.txt ] && rm Progs/Prev.txt
[ -f Progs/NewList.txt ] && rm Progs/NewList.txt

if [ "$ShowDifferences" == yes ]
then
    echo "I'm opening Diffs/diff_$TimeNow.txt in your pager,"
    echo so you can see the changes that happened this time.
    echo When you have finished looking through the file,
    echo please close the pager, and then I can continue.
    read -t 10 -p "Press any key to continue . . . " Answer
    ${PAGER:=less} Diffs/diff_$TimeNow.txt
    echo
fi

# Remove FileLists and Diffs files older than the latest KeepNr
#
ls -1t FileLists/*| sed "1,${KeepNr}d" | RemoveAny
ls -1t Diffs/*    | sed "1,${KeepNr}d" | RemoveAny

# :CheckForArchiving
if [ "$KeepArchive" != yes ]
then
    set +vx
    EndScript
fi

# :SaveArchive
if [ ! -d "$ArchiveDir" ]
then
    mkdir "$ArchiveDir"
    if [ -d "$ArchiveDir" ]
    then
        echo "Made Archive directory \"$ArchiveDir\"" > "$ArchiveDir/NewArchive.txt"
    else
        echo "Sorry, I wasn't able to make the folder "$ArchiveDir"."
        echo "I can't keep an expanding archive of your LangTran files."
        EndScript
    fi
fi

# :ArchiveDirExists
if [ -f "$ArchiveDir/NewArchive.txt" ]
then
    echo "Don't panic -- I'm about to copy lots of files from your LangTranLocal folder"
    echo "to your archive:"
    echo "  $ArchiveDir"

    if [ "$Silent" != "yes" ]
    then
        read -t 10 -p "Press any key to continue . . . " Answer
    fi
fi

# :CopyArchiveNow
echo
echo Updating your local repository to your archive at
echo "  $ArchiveDir"
echo
# set -x
rsync -bvrLtP --perms --chmod=a=rwx --timeout=300 --partial-dir=.rsync-bit -f "-! */***" \
    -f "- /Diffs/*" -f "- /FileLists/*" -f "- ${ArchiveDir}/*" ./ "$ArchiveDir/"
set +x
[ -f "$ArchiveDir/NewArchive.txt" ] && rm "$ArchiveDir/NewArchive.txt"
echo

# :PruneArchive
echo Finished updating your LangTran files to "$ArchiveDir/"
echo Now I am going to prune the archive to keep $KeepArchNr versions of each
echo installer that has numbered versions.
echo "It can take a while, so please be patient :-) . . . "

# For each folder in the tree of archived files
#   pushd to the folder,
#       call PruneArchive.sh with ArchKeepNr and the folder name
#       This will prune numbered files to that number of versions.
#   popd back to the working folder.
#
WorkDir=`pwd`

find "$ArchiveDir" -type d -print | 
    while read line
    do
        pushd "$line" > /tmp/LTU_pushd.txt
            ${WorkDir}/Progs/PruneArchive.sh "$KeepArchNr" "$line"
            # read -t 10 -p "Press any key to continue . . . " Answer
        popd > /tmp/LTU_pushd.txt
    done

EndScript

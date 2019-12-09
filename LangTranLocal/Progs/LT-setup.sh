#!/bin/sh
# LT-setup.sh
#
# Makes a group "langtran" and makes the current user a member of that group.
#
# set > /tmp/LT-setup-env.txt

# ThisUser=`who am i | awk '{print $$1}'`
ThisUser=`set | sed -n 's/USER=//p'`
# ThisUser=$$USER
# echo my username is $$ThisUser and my groups are:
# id $$ThisUser

LTgroup=langtran

# if the langtran group doesn't exist, make it
#
case `uname` in
    Linux)
	grep $$LTgroup /etc/group >/dev/null ||
	    groupadd -r $$LTgroup 
	# If the user is not a member of the group, 
	#    add the group to the user's groups.
	#
	id $$ThisUser | grep $$LTgroup >/dev/null ||
	    usermod -a -G $$LTgroup $$ThisUser
	;;
    Darwin)
	# Macs run a system derived from Free BSD, 
	# so don't have groupadd and don't update /etc/group.
	# set -x
	#
	# Create group called $$LTgroup
	# with the next gid
	#
	LTdsclErrors=0

	dscl . list /Groups | grep $$LTgroup >/dev/null ||
	{
	    LTtopGpNo=`dscl . list /Groups PrimaryGroupID |
		sort -n +1 | sed -n -e 's/[^0-9]*//' -e '$$p'`
	    LTdsclErrors=`expr $$LTdsclErrors + $$?`
	    echo Top group number is $$LTtopGpNo
	    LTnewGpNo=`expr $$LTtopGpNo + 1`
	    echo new group No is $$LTnewGpNo
	    dscl . create /Groups/$$LTgroup
	    LTdsclErrors=`expr $$LTdsclErrors + $$?`
	    dscl . create /Groups/$$LTgroup RealName \
		"LangTran software distribution system"
	    LTdsclErrors=`expr $$LTdsclErrors + $$?`
	    dscl . create /Groups/$$LTgroup gid $$LTnewGpNo
	    LTdsclErrors=`expr $$LTdsclErrors + $$?`
	    echo Here are the details of the group:
	    dscl . read /Groups/$$LTgroup

	    [[ "$$LTdsclErrors" -gt 0 ]] &&
	    {
		echo $$0 failed to create group $$LTgroup >&2
		exit
	    }
	}

	# If the user is not a member of the group, 
	#    add the group to the user's groups.
	#
	dscl . read /Groups/$$LTgroup GroupMembership | 
	    grep $$ThisUser > /dev/null ||
	{
	    dscl . append /Groups/$$LTgroup GroupMembership $$ThisUser
	    LTdsclErrors=`expr $$LTdsclErrors + $$?`
	}

	[[ "$$LTdsclErrors" -gt 0 ]] &&
	{
	    echo $$0: failed to add $$ThisUser to group $$LTgroup >&2
	    exit
	} ||
	{
	    echo The users in the group $$LTgroup are:
	    dscl . read /Groups/$$LTgroup GroupMembership
	}
	;;
esac

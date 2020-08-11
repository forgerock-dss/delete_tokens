#!/bin/bash

<< ////

The sample code described herein is provided on an "as is" basis, without warranty of any kind, to the fullest extent permitted by law. ForgeRock does not warrant or guarantee the individual success developers may have in implementing the sample code on their development platforms or in production configurations.

ForgeRock does not warrant, guarantee or make any representations regarding the use, results of use, accuracy, timeliness or completeness of any data or information relating to the sample script. ForgeRock disclaims all warranties, expressed or implied, and in particular, disclaims all warranties of merchantability, and warranties related to the script/code, or any service or software related thereto.

ForgeRock shall not be liable for any direct, indirect or consequential damages or costs of any type arising out of any action taken by you or others related to the sample script/code.

////

# Parameters. Modify as appropriate:
REALM=test
AM_HOST=http://openam.test.com:9499/openam
AM_AUTHENTICATE=$AM_HOST/json/realms/ROOT/authenticate
AM_USER_AUTHENTICATE=$AM_HOST/json/realms/$REALM/authenticate
CONTENT_HEADER='Content-Type: application/json'
AM_AUTHENTICATE_VERSION='Accept-API-Version: resource=2.0, protocol=1.0'
AM_SESSIONS_VERSION='Accept-API-Version: resource=3.1, protocol=1.0'
AM_USER_VERSION='Accept-API-Version: protocol=2.1,resource=3.0'
LOCK_ATTRIBUTE=inetUserStatus
ADMIN_USERNAME=amadmin
ADMIN_PASSWORD=password
TARGET_USERNAME=darinder
TARGET_PASSWORD=Ch4ng31t
TARGET_AUTHN_ITERATIONS='5'
USER=$1

if [ -z "$1" ]; then
	echo "Execute using ./delete_tokens.sh <username>. For example ./delete_tokens.sh demo"
	exit 1
else
	AM_USER_ENDPOINT=$AM_HOST/json/realms/$REALM/users/$USER
	if [ $REALM == "root" ]; then
        AM_LIST_SESSIONS=$AM_HOST/json/realms/$REALM/sessions?_queryFilter=username%20eq%20%22$USER%22%20and%20realm%20eq%20%22%2F%22
else
        AM_LIST_SESSIONS=$AM_HOST/json/realms/$REALM/sessions?_queryFilter=username%20eq%20%22$USER%22%20and%20realm%20eq%20%22%2F$REALM%22
fi
	AM_DELETE_SESSIONS=$AM_HOST/json/realms/$REALM/sessions/?_action=logoutByHandle
fi

jqCheck(){
hash jq &> /dev/null
if [ $? -eq 1 ]; then
	echo >&2 "The jq Command-line JSON processor is not installed on the system. Please install and re-run."
	exit 1
fi
}

authNTarget(){
clear
echo "*********************"
echo "Authenticating $TARGET_USERNAME user $TARGET_AUTHN_ITERATIONS times to generate a set of sample SSO tokens"

for (( n=1; n<=$TARGET_AUTHN_ITERATIONS; n++ ))
do
        USER_SSO_TOKEN=`curl -s \
        --request POST \
        --header "$CONTENT_HEADER" \
        --header "$AM_AUTHENTICATE_VERSION" \
        --header "X-OpenAM-Username: $TARGET_USERNAME" \
        --header "X-OpenAM-Password: $TARGET_PASSWORD" \
        --data '' \
        "$AM_USER_AUTHENTICATE"  | jq -r .tokenId`
        echo "SSO Token for user $TARGET_USERNAME is: $USER_SSO_TOKEN"
done
}

authNAdmin(){
echo "*********************"
echo "Authenticating $ADMIN_USERNAME user to generate SSO token"
SSO_TOKEN=`curl -s \
--request POST \
--header "$CONTENT_HEADER" \
--header "$AM_AUTHENTICATE_VERSION" \
--header "X-OpenAM-Username: $ADMIN_USERNAME" \
--header "X-OpenAM-Password: $ADMIN_PASSWORD" \
--data '' \
"$AM_AUTHENTICATE"  | jq -r .tokenId`
echo "SSO Token for user $ADMIN_USERNAME is: $SSO_TOKEN"
}

setUserInactive(){
echo "*********************"
echo "Disabling $USER user by setting $LOCK_ATTRIBUTE to Inactive:"
curl -s \
--request PUT \
--header "iplanetDirectoryPro: $SSO_TOKEN" \
--header "$CONTENT_HEADER" \
--header "$AM_USER_VERSION" \
--header "If-Match: *" \
--data '{ "'$LOCK_ATTRIBUTE'": "Inactive" }' \
$AM_USER_ENDPOINT | jq -r .inetUserStatus
}

getActiveSessions(){
echo "*********************"
echo "Getting active SSO sessions for user: $USER"
ACTIVE_LIST=`curl -s \
--request GET \
--header "$CONTENT_HEADER" \
--header "Cache-Control: no-cache" \
--header "iPlanetDirectoryPro: $SSO_TOKEN" \
--header "$AM_SESSIONS_VERSION" \
$AM_LIST_SESSIONS | jq '.result[].sessionHandle'`
if [[ -n "${ACTIVE_LIST/[ ]*\n/}" ]]; then
	ACTIVE_SESSIONS=`echo $ACTIVE_LIST | sed -r 's/[[:space:]]+/,/g'`
	echo "Number of active sessions found for user $USER: `echo $ACTIVE_LIST | wc -w`"
	echo $ACTIVE_LIST | jq .
	deleteActiveSession
else
	echo "No active sessions found"
fi
}

deleteActiveSession(){
echo "*********************"
echo "Deleting all active SSO sessions for user: $USER"
curl -s \
--request POST \
--header "$CONTENT_HEADER" \
--header "Cache-Control: no-cache" \
--header "iplanetDirectoryPro: $SSO_TOKEN" \
--header "$AM_SESSIONS_VERSION" \
--data '{
    "sessionHandles": [
    '$ACTIVE_SESSIONS'
    ]
}' \
$AM_DELETE_SESSIONS | jq .
}

#Functions
jqCheck
authNTarget
authNAdmin
setUserInactive # Note need to manually re-enable/set to Active before executing again
getActiveSessions
getActiveSessions

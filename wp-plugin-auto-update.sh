#!/bin/bash

###
# @license http://www.apache.org/licenses/LICENSE-2.0 Apache License, Version 2.0
# @author Mehdi Chaouch <mehdi@advocodo.com> <@advocodo>
# @copyright Copyright (c) 2021 ADVOCODO (https://www.advocodo.com)
# @description This script create a pull request with plugin code update
# @usage ./wp-plugin-auto-update.sh
###

#set -v
#set -x

START=$(date +%s)
CURRENT_DATE=$(date +%Y%m%d-%H%M%S)
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGNAME=$(basename $0)

error_exit() {
  echo "⚠️  ${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
  exit 1
}

read -p 'What is your Bitbucket username? ' USERNAME
[ -z "${USERNAME}" ] && error_exit "Username is not set"

read -s -p 'What is your Bitbucket password? ' PASSWORD
echo
[ -z "${PASSWORD}" ] && error_exit "Password is not set"

read -p 'What is your Bitbucket workspace and repository slug? [mehdichaouch/mon-wordpress-youpi] ' WORKSPACE__REPO_SLUG
WORKSPACE__REPO_SLUG=${WORKSPACE__REPO_SLUG:-mehdichaouch/mon-wordpress-youpi}

read -p 'Which plugin update checking branch? [master] ' BRANCH_TO_CHECK_PLUGIN_UPDATE
BRANCH_TO_CHECK_PLUGIN_UPDATE=${BRANCH_TO_CHECK_PLUGIN_UPDATE:-master}

read -p 'For pull request what is your branch destination? [develop] ' BRANCH_TO
BRANCH_TO=${BRANCH_TO:-develop}

WP_PLUGIN_LIST_UPDATE="/tmp/${CURRENT_DATE}-wp-plugin-list-update.csv"
PULL_REQUESTS_URL="https://api.bitbucket.org/2.0/repositories/${WORKSPACE__REPO_SLUG}/pullrequests"
AUTHORIZATION=$(echo -n ${USERNAME}:${PASSWORD} | base64)

git checkout ${BRANCH_TO_CHECK_PLUGIN} --quiet
wp plugin list --update=available --fields=name,title --format=csv > ${WP_PLUGIN_LIST_UPDATE} \
  && echo "🍺  Exported plugin list to update successfully" || error_exit "Error exporting plugin list to update"

sed -i '1d' ${WP_PLUGIN_LIST_UPDATE} && echo "🍺  Removed plugin list headers successfully" || error_exit "Error removing plugin list headers"

while IFS=, read -r NAME TITLE
do
  git checkout master --quiet && git pull --quiet && echo "🍺  Switched to master branch successfully" || error_exit "Error switching to master branch"
  git checkout -b ${NAME} --quiet && echo "🍺  Created new branch ${NAME} successfully" || error_exit "Error creating new branch ${NAME}"
  wp plugin update ${NAME} && echo "🍺  Updated plugin ${NAME} successfully" || error_exit "Error updating ${NAME} plugin"
  git add . && git ci -m "Update $(echo ${TITLE} | xargs) plugin" --quiet && echo "🍺  Committed plugin ${NAME} successfully" || error_exit "Error committing ${NAME} plugin"
  git push --set-upstream origin ${NAME} --quiet > /dev/null && echo "🍺  Pushed branch ${NAME} successfully" || error_exit "Error pushing ${NAME} branch"

  # View PR
  #curl -s "https://api.bitbucket.org/2.0/repositories/${WORKSPACE__REPO_SLUG}/pullrequests/1" -H "Authorization: Basic ${AUTHORIZATION}" | jq .

  BRANCH_FROM=$(git rev-parse --abbrev-ref HEAD)
  DATA="{\"title\":\"Update $(echo ${TITLE} | xargs)\ plugin",\"description\":\"Pull request made by 🤖\",\"source\":{\"branch\":{\"name\":\"${NAME}\"}},\"destination\":{\"branch\":{\"name\":\"${BRANCH_TO}\"}},\"close_source_branch\":true}"
  curl -s "${PULL_REQUESTS_URL}" -H "Authorization: Basic ${AUTHORIZATION}" -H 'Content-Type: application/json' -d "${DATA}" \
    && echo "🍺  Created PR ${NAME} successfully" || error_exit "Error creating PR ${NAME}"
  echo
  echo "🦄️  🦄️  🦄️  🦄️  🦄️  🦄️  🦄️  🦄️  🦄️  🦄️  🦄️  🦄️  🦄️️  🦄️️  🦄️️️  🦄️️️  🦄️️️  🦄️️️  🦄️️️  🦄️️️️  🦄️️️️  🦄️️️️  🦄️️️️  🦄️️️️  🦄️"
  echo
done < ${WP_PLUGIN_LIST_UPDATE}

rm ${WP_PLUGIN_LIST_UPDATE}

END=$(date +%s)
RUNTIME=$((END - START))
echo "⏱️  Total runtime: $(($RUNTIME / 60)) minutes and $((RUNTIME % 60)) seconds"

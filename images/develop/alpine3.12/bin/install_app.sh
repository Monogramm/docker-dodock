#!/bin/bash -xe

APP_NAME=${1}
APP_REPO=${2}
APP_BRANCH=${3}

cd /home/dodock/dodock-bench/ || exit

. env/bin/activate

echo "${APP_NAME}" > sites/apps.txt
cd ./apps || exit
[ "${APP_BRANCH}" ] && BRANCH="-b ${APP_BRANCH}"
git clone --depth 1 -o upstream ${BRANCH} "${APP_REPO}" "${APP_NAME}"
sed -i -e 's/GitPython==2\.1\.11/GitPython==2\.1\.15/' "${APP_NAME}/requirements.txt"
#sed -i -e 's/urllib3==.*/urllib3==1.25.10/' "${APP_NAME}/requirements.txt"
grep 'ldap3' "${APP_NAME}/requirements.txt" || echo -e '\nldap3==2.7' >> "${APP_NAME}/requirements.txt";
pip3 install --no-cache-dir -e "/home/dodock/dodock-bench/apps/${APP_NAME}"
cd "${APP_NAME}"
yarn
yarn run production
yarn install --production=true

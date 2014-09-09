#! /bin/sh
# Glassfish WAR Application Deployer Script

####################################################################################################
####################################################################################################
# VARIABLES
####################################################################################################

####################################################################################################
# setup the environment variables
####################################################################################################
export SCRIPT_HOME="/var/scripts/glassfish/"
export RUN_DATE=`date +"%Y-%m-%d.%H.%M"`
export RUN_LOG='test-glassfish-deployer-out.log'
export ERR_LOG='test-glassfish-deployer-err.log'
export GLASSFISH_HOME='/home/glassfish/opensource/glassfish3/glassfish/'
export GLASSFISH_BIN=${GLASSFISH_HOME}'bin/'
export GLASSFISH_UPLOAD='/home/glassfish/upload-for-deploy/'
export GLASSFISH_CURRENT='/home/glassfish/currently-deployed/'
export GLASSFISH_PREVIOUS='/home/glassfish/previously-deployed/'
export TEST_APPS_LOCAL_NODE=${GLASSFISH_HOME}'nodes/localhost-test-apps/'
export TEST_ONE_CLUSTER_AUTODEPLOY=${MOPAR_APPS_LOCAL_NODE}'test1_i1/autodeploy/'
export TEST_ADMIN_APP_AUTODEPLOY=${MOPAR_APPS_LOCAL_NODE}'test-admin/autodeploy/'

####################################################################################################
####################################################################################################
#FUNCTIONS
####################################################################################################

###
####################################################################################################
# Function Name: deploy
# Parms: $1(WAR file to deploy) $2(Server's auto deploy directory)
# Usage: Takes the exploded war and deploys it to the propper glassfish server instance
####################################################################################################
deploy()
{
	cp -fr $1 $2
	
	if [ "$?" -ne "0" ]; then
    	echo "Deployment failed!"
    	return 500
  	fi
}

###
####################################################################################################
# Function Name: setpermissions
# Parms: (none)
# Usage: sets the correct perrmissions on the glassfish home files and dirs
####################################################################################################
setpermissions()
{
	echo "Setting file permissions"
	chown -R glassfish:glassfishadm ${GLASSFISH_HOME}
	
	if [ "$?" -ne "0" ]; then
    	echo "Setting file permissions in ${GLASSFISH_HOME} failed"
    	return 2
  	fi
  
	setfacl -Rm d:g:developers:rwx ${GLASSFISH_HOME}
	
	if [ "$?" -ne "0" ]; then
    	echo 'setfacl -Rm d:g:developers:rwx failed'
    	return 2
  	fi
	
	setfacl -Rm g:developers:rwx ${GLASSFISH_HOME}
	
	if [ "$?" -ne "0" ]; then
    	echo 'setfacl -Rm g:developers:rwx failed'
    	return 2
  	fi
}

### template for additional functions
####################################################################################################
# Function Name: 
# Parms:
# Usage:
####################################################################################################

####################################################################################################
####################################################################################################
# SCRIPT BEGINS
####################################################################################################

####################################################################################################
# make sure permissions are right
# calls setpermissions function
####################################################################################################
setpermissions

if [ "$?" -eq "2" ]; then
  echo "Something went wrong with setting permissions!"
  exit 1;
fi

####################################################################################################
# check upload-for deploy for zip and war file presense if not exits
####################################################################################################
echo "looking for zip file to deploy"
if [ -f ${GLASSFISH_UPLOAD}*.zip ]; then
  echo "Found zip file proceeding with deployment"
else
   echo "No zip files found checking for exploded  wars"
  if [ -d ${GLASSFISH_UPLOAD}*.war ]; then
    echo "wars found continue with deployment"
  else
    echo "no valid war or zip found exiting deployment"
	exit 1
  fi
fi

####################################################################################################
# change work directory and setup logging
####################################################################################################
echo "changing working directory and setting up logging"
cd ${SCRIPT_HOME}
touch ${RUN_LOG}
exec 6>&1           # Link file descriptor #6 with stdout.
exec 1> ${RUN_LOG}     # stdout replaced with file $RUN_LOG.

touch ${ERR_LOG}
exec 7>&2           # Link file descriptor #7 with stderr.
exec 2> ${ERR_LOG}    # stderr replaced with file $ERR_LOG.

####################################################################################################
# check upload-for-deploy for zip file(s) and explode(s) 
####################################################################################################
echo "\n\n\nchanging directory to upload for deploy"
cd ${GLASSFISH_UPLOAD}

for zipfile in ${GLASSFISH_UPLOAD}*.zip
do
  echo "${zipfile} -- proceeding with extpansion"
  echo "\n\n\nExpanding deployment archive file: ${zipfile}"
  unzip ${zipfile}
done

echo "\n\n\nStarting Normal Deployment Process"

####################################################################################################
# take the previous-deployed folder and zip it then push off to backup server with timestamp
####################################################################################################

####################################################################################################
# copy currently deployed application into the previously deployed folder if rollback is needed
####################################################################################################
cp -fr ${GLASSFISH_CURRENT}* ${GLASSFISH_PREVIOUS}

####################################################################################################
# autodeploy war file
# calls the deploy and setpermissions functions
####################################################################################################
for warfile in ${GLASSFISH_UPLOAD}*.war
do
  ### autodeploys to the domain virtual server
  echo "AutoDeploying ${warfile} to domain virtual server"
  deploy ${warfile} ${GLASSFISH_CURRENT}

  ### tests if its a test-app or test-admin-app war file and deploys to correct instance
  if [ "${warfile}" -eq "int.*.war" ]; then
      echo "AutoDeploying ${warfile} to test-admin-app server"
      deploy ${warfile} ${TEST_ADMIN_APP_AUTODEPLOY}
    else
      echo "AutoDeploying ${warfile} to test-apps cluster"
      deploy ${warfile} ${TEST_ONE_CLUSTER_AUTODEPLOY}
  fi
  
  setpermissions
  
  if [ "$?" -eq "2" ]; then
  	echo "Something went wrong with setting permissions!"
  	exit 1;
  fi
done

####################################################################################################
# clean up the upload-for-deployment directory
####################################################################################################
echo "Cleaning up......"
rm -rf ${GLASSFISH_UPLOAD}*

####################################################################################################
# wait 5 seconds and then reset standard out and standard error back to normal
####################################################################################################
echo "Resetting stout and sterr to their default locations"
sleep 5
exec 1>&6 6>&-       # Restore stout.
exec 2<&7 7<&-       # Restore sterr.

####################################################################################################
# move the out log and error log to the previous-deployed directory for history
####################################################################################################
mv -f ${SCRIPT_HOME}${RUN_LOG} ${GLASSFISH_PREVIOUS}
mv -f ${SCRIPT_HOME}${ERR_LOG} ${GLASSFISH_PREVIOUS}
exit;

####################################################################################################
####################################################################################################
# SCRIPT ENDS
####################################################################################################

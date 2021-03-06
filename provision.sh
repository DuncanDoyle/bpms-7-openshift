#!/bin/sh
#!/bin/bash
set -e

command -v oc >/dev/null 2>&1 || {
  echo >&2 "The oc client tools need to be installed to connect to OpenShift.";
  echo >&2 "Download it from https://www.openshift.org/download.html and confirm that \"oc version\" runs.";
  exit 1;
}

################################################################################
# Provisioning script to deploy the demo on an OpenShift environment           #
################################################################################
function usage() {
    echo
    echo "Usage:"
    echo " $0 [command] [demo-name] [options]"
    echo " $0 --help"
    echo
    echo "Example:"
    echo " $0 setup --maven-mirror-url http://nexus.repo.com/content/groups/public/ --project-suffix s40d"
    echo
    echo "COMMANDS:"
    echo "   setup                    Set up the demo projects and deploy demo apps"
    echo "   deploy                   Deploy demo apps"
    echo "   delete                   Clean up and remove demo projects and objects"
    echo "   verify                   Verify the demo is deployed correctly"
    echo "   idle                     Make all demo services idle"
    echo
    echo "DEMOS:"
    echo "   bpms-7        	      Red Hat JBoss BPM Suite 7."
    echo
    echo "OPTIONS:"
    echo "   --user [username]         The admin user for the demo projects. mandatory if logged in as system:admin"
    echo "   --project-suffix [suffix] Suffix to be added to demo project names e.g. ci-SUFFIX. If empty, user will be used as suffix."
    echo "   --run-verify              Run verify after provisioning"
    echo "   --with-imagestreams       Creates the image streams in the project. Useful when required ImageStreams are not available in the 'openshift' namespace and cannot be provisioned in that 'namespace'."
    # TODO support --maven-mirror-url
    echo
}

ARG_USERNAME=
ARG_PROJECT_SUFFIX=
ARG_COMMAND=
ARG_RUN_VERIFY=false
ARG_WITH_IMAGESTREAMS=false
ARG_DEMO=

while :; do
    case $1 in
        setup)
            ARG_COMMAND=setup
            if [ -n "$2" ]; then
                ARG_DEMO=$2
                shift
            fi
            ;;
        deploy)
            ARG_COMMAND=deploy
            if [ -n "$2" ]; then
                ARG_DEMO=$2
                shift
            fi
            ;;
        delete)
            ARG_COMMAND=delete
            if [ -n "$2" ]; then
                ARG_DEMO=$2
                shift
            fi
            ;;
        verify)
            ARG_COMMAND=verify
            if [ -n "$2" ]; then
                ARG_DEMO=$2
                shift
            fi
            ;;
        idle)
            ARG_COMMAND=idle
            if [ -n "$2" ]; then
                ARG_DEMO=$2
                shift
            fi
            ;;
        --user)
            if [ -n "$2" ]; then
                ARG_USERNAME=$2
                shift
            else
                printf 'ERROR: "--user" requires a non-empty value.\n' >&2
                usage
                exit 255
            fi
            ;;
        --project-suffix)
            if [ -n "$2" ]; then
                ARG_PROJECT_SUFFIX=$2
                shift
            else
                printf 'ERROR: "--project-suffix" requires a non-empty value.\n' >&2
                usage
                exit 255
            fi
            ;;
        --run-verify)
            ARG_RUN_VERIFY=true
            ;;
        --with-imagestreams)
            ARG_WITH_IMAGESTREAMS=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            shift
            ;;
        *)               # Default case: If no more options then break out of the loop.
            break
    esac

    shift
done


################################################################################
# Configuration                                                                #
################################################################################
LOGGEDIN_USER=$(oc whoami)
OPENSHIFT_USER=${ARG_USERNAME:-$LOGGEDIN_USER}

# Project name needs to be unique across OpenShift Online

PRJ_SUFFIX=${ARG_PROJECT_SUFFIX:-`echo $OPENSHIFT_USER | sed -e 's/[^-a-z0-9]/-/g'`}

PRJ=("bpms-7-$PRJ_SUFFIX" "BPM Suite 7" "Red Hat JBoss BPM Suite 7 Demo")

# config
# TODO: I don't think we need to reference Git in this setup.
#GITHUB_ACCOUNT=${GITHUB_ACCOUNT:-DuncanDoyle}
#GIT_REF=${GITHUB_REF:-master}
#GIT_URI=https://github.com/$GITHUB_ACCOUNT/fsi-onboarding-bpm

################################################################################
# DEMO MATRIX                                                                  #
################################################################################
case $ARG_DEMO in
    bpms-7)
	   # No need to set anything here anymore.
	;;
    *)
        echo "ERROR: Invalid demo name: \"$ARG_DEMO\""
        usage
        exit 255
        ;;
esac


################################################################################
# Functions                                                                    #
################################################################################

function echo_header() {
  echo
  echo "########################################################################"
  echo $1
  echo "########################################################################"
}

function print_info() {
  echo_header "Configuration"

  OPENSHIFT_MASTER=$(oc status | head -1 | sed 's#.*\(https://[^ ]*\)#\1#g') # must run after projects are created

  echo "Demo name:           $ARG_DEMO"
  echo "OpenShift master:    $OPENSHIFT_MASTER"
  echo "Current user:        $LOGGEDIN_USER"
  echo "Project suffix:      $PRJ_SUFFIX"
  echo "GitHub repo:         $GIT_URI"
  echo "GitHub branch/tag:   $GITHUB_REF"
}

function pre_condition_check() {
  echo_header "Checking pre-conditions"
  echo_header "Testing connection to Red Hat Engineering Docker Registry"
  # Disable "set -e" as we want to check for exit conditions when "ping" returns non-zero so we can print a proper error message."
  set +e
  ping -q -c5 docker-registry.engineering.redhat.com  > /dev/null
  if [ $? -eq 0 ]
  then
    echo "ok"
  else
    echo "Host unreachable, unable to retrieve OpenShift BPM Suite images. Please enable your Red Hat VPN to continue the setup."
    exit 1
  fi
  set -e
}

# waits while the condition is true until it becomes false or it times out
function wait_while_empty() {
  local _NAME=$1
  local _TIMEOUT=$(($2/5))
  local _CONDITION=$3

  echo "Waiting for $_NAME to be ready..."
  local x=1
  while [ -z "$(eval ${_CONDITION})" ]
  do
    echo "."
    sleep 5
    x=$(( $x + 1 ))
    if [ $x -gt $_TIMEOUT ]
    then
      echo "$_NAME still not ready, I GIVE UP!"
      exit 255
    fi
  done

  echo "$_NAME is ready."
}

# Create Project
function create_projects() {
  echo_header "Creating project..."

  echo "Creating project ${PRJ[0]}"
#  oc new-project $PRJ --display-name="$PRJ_DISPLAY_NAME" --description="$PRJ_DESCRIPTION" >/dev/null
  oc new-project "${PRJ[0]}" --display-name="${PRJ[1]}" --description="${PRJ[2]}" >/dev/null
}

function import_imagestreams_and_templates() {
  echo_header "Importing Image Streams"
  oc create -f ./openshift/image_streams.json

  echo_header "Importing Templates"
  oc create -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-businesscentral-monitoring-with-smartrouter.json
  oc create -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-businesscentral-monitoring.json
  oc create -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-businesscentral.json
  oc create -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-executionserver-externaldb.json
  oc create -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-executionserver-postgresql.json
  oc create -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-executionserver-s2i.json
  oc create -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-executionserver.json
  oc create -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-full-mysql-persistent.json
  oc create -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-full-mysql.json
}


function import_secrets_and_service_account() {
  echo_header "Importing secrets and service account."
  oc create -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/secrets/bpmsuite-app-secret.json
}

function create_application() {
  echo_header "Creating BPM Suite 7 Application config."

  IMAGE_STREAM_NAMESPACE="openshift"

  if [ "$ARG_WITH_IMAGESTREAMS" = true ] ; then
    IMAGE_STREAM_NAMESPACE=$PRJ
  fi 
  
  oc new-app --template=bpmsuite70-businesscentral -p APPLICATION_NAME="$ARG_DEMO" -p IMAGE_STREAM_NAMESPACE="$PRJ"
}

function build_and_deploy() {
  echo_header "Starting OpenShift build and deploy..."
  #TODO: name of the app
  oc start-build myapp-buscentr
#  oc start-build client-onboarding-entando
}


function verify_build_and_deployments() {
  echo_header "Verifying build and deployments"

  # verify builds
  local _BUILDS_FAILED=false
  for buildconfig in optaplanner-employee-rostering
  do
    if [ -n "$(oc get builds -n $PRJ | grep $buildconfig | grep Failed)" ] && [ -z "$(oc get builds -n $PRJ | grep $buildconfig | grep Complete)" ]; then
      _BUILDS_FAILED=true
      echo "WARNING: Build $project/$buildconfig has failed..."
    fi
  done

  # verify deployments
  for project in $PRJ
  do
    local _DC=
    for dc in $(oc get dc -n $project -o=custom-columns=:.metadata.name,:.status.replicas); do
      if [ $dc = 0 ] && [ -z "$(oc get pods -n $project | grep "$dc-[0-9]\+-deploy" | grep Running)" ] ; then
        echo "WARNING: Deployment $project/$_DC in project $project is not complete..."
      fi
      _DC=$dc
    done
  done
}

function make_idle() {
  echo_header "Idling Services"
  oc idle -n $PRJ_CI --all
  oc idle -n $PRJ_TRAVEL_AGENCY_PROD --all
}

# GPTE convention
function set_default_project() {
  if [ $LOGGEDIN_USER == 'system:admin' ] ; then
    oc project default >/dev/null
  fi
}

################################################################################
# Main deployment                                                              #
################################################################################

if [ "$LOGGEDIN_USER" == 'system:admin' ] && [ -z "$ARG_USERNAME" ] ; then
  # for verify and delete, --project-suffix is enough
  if [ "$ARG_COMMAND" == "delete" ] || [ "$ARG_COMMAND" == "verify" ] && [ -z "$ARG_PROJECT_SUFFIX" ]; then
    echo "--user or --project-suffix must be provided when running $ARG_COMMAND as 'system:admin'"
    exit 255
  # deploy command
  elif [ "$ARG_COMMAND" != "delete" ] && [ "$ARG_COMMAND" != "verify" ] ; then
    echo "--user must be provided when running $ARG_COMMAND as 'system:admin'"
    exit 255
  fi
fi

#pushd ~ >/dev/null
START=`date +%s`

echo_header "Client Onboarding OpenShift Demo ($(date))"

case "$ARG_COMMAND" in
    delete)
        echo "Delete BPM Suite 7 demo ($ARG_DEMO)..."
        oc delete project $PRJ
        ;;

    verify)
        echo "Verifying BPM Suite 7 demo ($ARG_DEMO)..."
        print_info
        verify_build_and_deployments
        ;;

    idle)
        echo "Idling BPM Suite 7 OpenShift demo ($ARG_DEMO)..."
        print_info
        make_idle
        ;;

    setup)
        echo "Setting up and deploying BPM Suite 7 ($ARG_DEMO)..."

        print_info
        pre_condition_check
        create_projects
        if [ "$ARG_WITH_IMAGESTREAMS" = true ] ; then
           import_imagestreams_and_templates
        fi
	import_secrets_and_service_account
        create_application

        if [ "$ARG_RUN_VERIFY" = true ] ; then
          echo "Waiting for deployments to finish..."
          sleep 30
          verify_build_and_deployments
        fi
        ;;

    deploy)
        echo "Deploying BPM Suite 7 ($ARG_DEMO)..."

        print_info

        build_and_deploy

        if [ "$ARG_RUN_VERIFY" = true ] ; then
          echo "Waiting for deployments to finish..."
          sleep 30
          verify_build_and_deployments
        fi
        ;;

    *)
        echo "Invalid command specified: '$ARG_COMMAND'"
        usage
        ;;
esac

set_default_project
#popd >/dev/null

END=`date +%s`
echo
echo "Provisioning done! (Completed in $(( ($END - $START)/60 )) min $(( ($END - $START)%60 )) sec)"

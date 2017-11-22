BPM Suite 7 Automatic Installation
==================================

This project provides an automatic provisioning script for the Red Hat BPM Suite v7 platform onto an OpenShift environment.


Prerequisits
============

In order to deploy the BPM Suite v7 patform, you need an OpenShift environment with
* 4+ GB memory quota if deploying Business Central and Execution Server components
* JBoss imagestreams installed when using the default provisioning/setup option (check _Troubleshooting_ section for details.)


Installing the Platfom
----------------------
Default installation:
```
./provision.sh setup bpms-7
```

Installation with image-streams and templates in the project namespace (instead of the openshift namespace).
```
./provision.sh setup bpms-7 --with-imagestreams true
```

Deleting the Platform
---------------------
```
./provision delete bpms-7
```

Troubleshooting
================
* If you see an error like `An error occurred while starting the build.imageStream ...` it might be due to JBoss imagestreams not being installed on your OpenShift environment. Contact the OpenShift admin to install these imagestreams with the following commands:

  ```
  oc login -u system:admin

  oc delete -n openshift -f ./openshift/image_streams.json
  oc create  -n openshift -f ./openshift/image_streams.json
 
  oc delete -n openshift -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-businesscentral-monitoring-with-smartrouter.json
  oc delete -n openshift -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-businesscentral-monitoring.json
  oc delete -n openshift -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-businesscentral.json
  oc delete -n openshift -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-executionserver-externaldb.json
  oc delete -n openshift -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-executionserver-postgresql.json
  oc delete -n openshift -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-executionserver-s2i.json
  oc delete -n openshift -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-executionserver.json
  oc delete -n openshift -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-full-mysql-persistent.json
  oc delete -n openshift -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-full-mysql.json

  oc create -n openshift -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-businesscentral-monitoring-with-smartrouter.json
  oc create -n openshift -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-businesscentral-monitoring.json
  oc create -n openshift -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-businesscentral.json
  oc create -n openshift -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-executionserver-externaldb.json
  oc create -n openshift -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-executionserver-postgresql.json
  oc create -n openshift -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-executionserver-s2i.json
  oc create -n openshift -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-executionserver.json
  oc create -n openshift -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-full-mysql-persistent.json
  oc create -n openshift -f https://raw.githubusercontent.com/jboss-openshift/application-templates/bpmsuite-wip/bpmsuite/bpmsuite70-full-mysql.json
  ```
* If you attempt to deploy any of the services, and nothing happens, it may just be taking a while to download the Docker builder images. Visit the OpenShift web console and navigate to
Browse->Events and look for errors, and re-run the 'oc delete ; oc create' commands to re-install the images (as outlined at the beginning.)



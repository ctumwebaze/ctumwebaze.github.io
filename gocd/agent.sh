#!/usr/bin/env bash
# ****************************** Installing Docker ********************************
echo ">> Installing docker"
#apt-get update
#
#echo ">> Install docker prequisites"
#apt-get install -y apt-transport-https ca-certificates
#apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
#echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" >> /etc/apt/sources.list.d/docker.list
#
#apt-get update
#apt-get purge lxc-docker
#apt-get install -y linux-image-extra-$(uname -r)
#apt-get install -y apparmor
#
#echo ">> installing docker"
#apt-get update
#apt-get install -y docker-engine
#service docker start

# **************************** Installing GOCD Server ************************
echo ">> creating docker file"
read -r -d '' DOCKER_FILE_CONTENT <<-"EOM"
  FROM ubuntu:14.04
  MAINTAINER Charles Tumwebaze <ctumwebaze@gmail.com>

  # Add Build Essentials
  RUN (ln -s -f /bin/true /usr/bin/chfn) && \
      (apt-get update -y) && \
      (apt-get install software-properties-common -y) && \
      (apt-add-repository ppa:webupd8team/java -y) && \
      (apt-get update -y) && \
      (echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections) && \
      (apt-get install oracle-java8-installer -y --no-install-recommends) && \
      (apt-get install -y --no-install-recommends build-essential git openssh-client curl wget rsync lib32stdc++6 lib32z1 unzip) && \
      (apt-get clean) && \
      (rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*)

  ENV JAVA_HOME /usr/lib/jvm/java-8-oracle

  # installing maven
  RUN (wget http://www.us.apache.org/dist/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz) && \
      (tar -zxf apache-maven-3.3.9-bin.tar.gz) && \
      (cp -R apache-maven-3.3.9 /usr/local) && \
      (ln -sf /usr/local/apache-maven-3.3.9/bin/mvn /usr/bin/mvn) && \
      (mvn --version)

  # installing android sdk
  ENV ANDROID_HOME /usr/local/android_sdk
  RUN (mkdir -p $ANDROID_HOME) && \
      (wget http://dl.google.com/android/android-sdk_r24.4.1-linux.tgz -O - | tar zx -C $ANDROID_HOME --strip-components 1) && \
      (echo 'y' | $ANDROID_HOME/tools/android --silent update sdk --no-ui --force --all --filter tools) && \
      (echo 'y' | $ANDROID_HOME/tools/android --silent update sdk --no-ui --force --all --filter platform-tools) && \
      (echo 'y' | $ANDROID_HOME/tools/android --silent update sdk --no-ui --force --all --filter build-tools-23.0.2) && \
      (echo 'y' | $ANDROID_HOME/tools/android --silent update sdk --no-ui --force --all --filter build-tools-20.0.0) && \
      (echo 'y' | $ANDROID_HOME/tools/android --silent update sdk --no-ui --force --all --filter extra-android-m2repository) && \
      (echo 'y' | $ANDROID_HOME/tools/android --silent update sdk --no-ui --force --all --filter extra-android-support) && \
      (echo 'y' | $ANDROID_HOME/tools/android --silent update sdk --no-ui --force --all --filter extra-google-m2repository) && \
      (echo 'y' | $ANDROID_HOME/tools/android --silent update sdk --no-ui --force --all --filter android-19)
      (echo 'y' | $ANDROID_HOME/tools/android --silent update sdk --no-ui --force --all --filter android-21)
      (echo 'y' | $ANDROID_HOME/tools/android --silent update sdk --no-ui --force --all --filter android-22)
      (echo 'y' | $ANDROID_HOME/tools/android --silent update sdk --no-ui --force --all --filter android-23)

  # Download gocd agent
  RUN (wget https://download.go.cd/binaries/15.2.0-2248/generic/go-agent-15.2.0-2248.zip) && \
      (unzip go-agent-15.2.0-2248.zip) && \
      (cp -R go-agent-15.2.0 /usr/local) && \
      (mv /usr/local/go-agent-15.2.0 /usr/local/go-agent) && \
      (chmod 775 /usr/local/go-agent/agent.sh) && \
      (chmod 775 /usr/local/go-agent/stop-agent.sh)

  ENTRYPOINT /usr/local/go-agent/agent.sh
  CMD []
EOM

AGENT_FOLDER=/opt/gocd/agent
mkdir -p $AGENT_FOLDER

touch $AGENT_FOLDER/Dockerfile
echo "$DOCKER_FILE_CONTENT" > $AGENT_FOLDER/Dockerfile

echo ">> Building the gocd docker image"
read -r -d '' GOCD_AGENT_BUILD_FILE <<-"EOM"
  # building the gocd agent docker image
  echo "************ creating gocd agent image ******************"
  docker build -t gocd_agent /opt/gocd/agent

  # removing dangling images
  if [ -n "$(docker images -f 'dangling=true' -q 2> /dev/null)" ]; then
    echo "******* cleanup: removing dangling images. ********"
    docker rmi -f $(docker images -f "dangling=true" -q)
  fi
EOM

echo "$GOCD_AGENT_BUILD_FILE" > $AGENT_FOLDER/build.sh
chmod 0555 $AGENT_FOLDER/build.sh
source $AGENT_FOLDER/build.sh

read -r -d '' GOCD_CONTAINER_START <<-"EOM"
  agent_counter=0
  NUMBER_OF_AGENTS=1

  # stop and remove existing agents.
  while [ $agent_counter -lt $NUMBER_OF_AGENTS ]
  do
  CONTAINER_NAME="gocd_agent_$agent_counter"
  if [ -n "$(docker ps -aq -f "name=$CONTAINER_NAME" 2> /dev/null)" ]; then
    echo "************** removing $CONTAINER_NAME container ********"
    docker stop $CONTAINER_NAME
    docker rm $CONTAINER_NAME
  fi
  agent_counter="expr $agent_counter + 1"
  done

  agent_counter=0
  while [ $agent_counter -lt $NUMBER_OF_AGENTS ]
  do
  CONTAINER_NAME="gocd_agent_$agent_counter"
  if [ -n "$(docker ps -aq -f "name=$CONTAINER_NAME" 2> /dev/null)" ]; then
    # start container in the event it was not removed.
    echo "******** starting old $CONTAINER_NAME **********"
    docker start $CONTAINER_NAME
  else
    # start the container in the event it was removed.
    echo "*********** starting new $CONTAINER_NAME ********"
    docker run -d --restart=always -t \
      -e GO_SERVER=192.168.50.4 \
      -e GO_SERVER_PORT=8153 \
      --name $CONTAINER_NAME gocd_agent
  fi
  agent_counter="expr $agent_counter + 1"
  done
EOM

echo "$GOCD_CONTAINER_START" > $AGENT_FOLDER/run.sh
chmod 0555 $AGENT_FOLDER/run.sh
source $AGENT_FOLDER/run.sh

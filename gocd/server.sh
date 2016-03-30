#!/usr/bin/env bash
# ****************************** Installing Docker ********************************
echo ">> Installing docker"
#apt-get update

#echo ">> Install docker prequisites"
#apt-get install -y apt-transport-https ca-certificates
#apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
#echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" >> /etc/apt/sources.list.d/docker.list

#apt-get update
#apt-get purge lxc-docker
#apt-get install -y linux-image-extra-$(uname -r)
#apt-get install -y apparmor

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

  #Download gocd server
  RUN (wget https://download.go.cd/binaries/15.2.0-2248/generic/go-server-15.2.0-2248.zip) && \
      (unzip go-server-15.2.0-2248.zip) && \
      (cp -R go-server-15.2.0 /usr/local) && \
      (mv /usr/local/go-server-15.2.0 /usr/local/go-server) && \
      (chmod 775 /usr/local/go-server/server.sh) && \
      (chmod 775 /usr/local/go-server/stop-server.sh)

  ENTRYPOINT /usr/local/go-server/server.sh
  CMD []
EOM

SERVER_FOLDER=/opt/gocd/server
mkdir -p $SERVER_FOLDER

touch $SERVER_FOLDER/Dockerfile
echo "$DOCKER_FILE_CONTENT" > $SERVER_FOLDER/Dockerfile

echo ">> Building the gocd docker image"
read -r -d '' GOCD_SERVER_BUILD_FILE <<-EOM
CONTAINER_NAME='gocd_server'

# build gocd server docker image
echo "************ creating gocd server image ******************"
docker build -t gocd_server /opt/gocd/server

# cleanup after build
if [ -n "$(docker images -f 'dangling=true' -q 2> /dev/null)" ]; then
  echo "****** cleanup: remove dangling images. ********"
  docker rmi -f $(docker images -f "dangling=true" -q)
fi
EOM

echo "$GOCD_SERVER_BUILD_FILE" > $SERVER_FOLDER/build.sh
chmod 0555 $SERVER_FOLDER/build.sh
source $SERVER_FOLDER/build.sh

read -r -d '' GOCD_CONTAINER_START <<-"EOM"
  CONTAINER_NAME='gocd_server'
  GOCD_DOCKER_IMAGE='gocd_server'

  echo "**************** creating data volume container for gocd server **********"
  GOCD_DB_VOLUME='gocd_db'
  GOCD_CONFIG_REPO_VOLUME='gocd_config_repo'
  GOCD_CONFIG_VOLUME='gocd_config'

  if [ -z "$(docker ps -aq -f 'name=gocd_db' 2> /dev/null)" ]; then
    docker create -v /usr/local/go-server/db/h2db --name $GOCD_DB_VOLUME $GOCD_DOCKER_IMAGE /bin/true
  fi

  if [ -z "$(docker ps -aq -f 'name=gocd_config_repo' 2> /dev/null)" ]; then
    docker create -v /usr/local/go-server/db/config.git --name $GOCD_CONFIG_REPO_VOLUME $GOCD_DOCKER_IMAGE /bin/true
  fi

  if [ -z "$(docker ps -aq -f 'name=gocd_config$' 2> /dev/null)" ]; then
    docker create -v /usr/local/go-server/config --name $GOCD_CONFIG_VOLUME $GOCD_DOCKER_IMAGE /bin/true
  fi

  if [ -n "$(docker ps -aq -f 'name=gocd_server' 2> /dev/null)" ]; then
    echo "************** removing gocd server container ********"
    docker stop $CONTAINER_NAME
    docker rm $CONTAINER_NAME
  fi

  if [ -n "$(docker ps -aq -f 'name=gocd_server' 2> /dev/null)" ]; then
    # start the container in the event it wasn't removed.
    echo "******* starting old gocd_server container ******"
    docker start $CONTAINER_NAME
  else
    # create config directory
    mkdir -p /opt/gocd/conf

    # start the container in the event it was removed.
    echo "******* starting new gocd_server container ******"
    docker run -d --restart=always -t \
      --volumes-from $GOCD_DB_VOLUME \
      --volumes-from $GOCD_CONFIG_REPO_VOLUME \
      --volumes-from $GOCD_CONFIG_VOLUME \
      -v /opt/gocd/conf:/opt/gocd/conf \
      --expose 8153 \
      -p 8153:8153 \
      -p 8154:8154 \
      --name $CONTAINER_NAME $GOCD_DOCKER_IMAGE
  fi
EOM

echo "$GOCD_CONTAINER_START" > $SERVER_FOLDER/run.sh
chmod 0555 $SERVER_FOLDER/run.sh
source $SERVER_FOLDER/run.sh

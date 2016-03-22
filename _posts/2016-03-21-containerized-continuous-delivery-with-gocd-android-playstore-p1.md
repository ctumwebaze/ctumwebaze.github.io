---
layout: post
title: Containerized Continuous Delivery with GoCD and Android PlayStore Part 1
categories: android
---
This is the first part in a series about Continuous Delivery with [GoCD](https://www.go.cd/) and the [Android PlayStore](https://play.google.com/store). The series  will be focusing on automated delivery of an android application right through development to production.

Continuous Delivery is really about releasing software frequently where every change to the system is releasable. This can be automated or done manually by a push of a button. This comes with many advantages, one of them being taking the ritual out of releasing software.  
You have probably been part of a team that has released software especially in the enterprise setting where before the software can go into production, it goes through multiple sign offs/approvals and it can be weeks or months before you can see changes in production.

For further reading about the subject of continuous delivery, this book [Continuous Delivery](http://www.amazon.com/gp/product/0321601912) by Jez Humble and David Farley does a good job on the topic.

At the heart of Continuous Delivery, is [Continuous Integration](https://en.wikipedia.org/wiki/Continuous_integration) and [DevOps](https://en.wikipedia.org/wiki/DevOps). A number of tools are available to achieve continuous delivery and in this part of the series you will see how to setup [GoCD](https://www.go.cd/) in a docker environment to achieve continuous delivery for an Android App.

First things first, you will need a machine to host you GoCD server and agent(s). You can find well priced virtual servers at [Digital Ocean](https://www.digitalocean.com/pricing/) or [Linode](https://www.linode.com/pricing). If this is not an option for you and you have you own server well go for it. For those that just want to practice; [Vagrant](https://www.vagrantup.com/) might be an option as well although working with vagrant is outside the scope of this post.

Now that we have the machine (this post assumes it's running Ubuntu 14.04) let's get started.

Our container technology of choice is `Docker` and if you would like to know more about it, [What is Docker?](https://www.docker.com/what-docker) is a good place to start.

### Installing Docker
Run the following commands in your terminal to install docker; make sure you have the necessary permissions to do install software on your machine. `sudo su` usually does the trick.

```bash
apt-get update

# install docker prequisites
apt-get install -y apt-transport-https ca-certificates
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" >> /etc/apt/sources.list.d/docker.list

apt-get update
apt-get purge lxc-docker
apt-get install -y linux-image-extra-$(uname -r)
apt-get install -y apparmor

# installing docker
apt-get update
apt-get install -y docker-engine
service docker start
```

Alternatively you can create a file called `docker_install.sh` and copy the content of the above script into it, save the file and change the file permissions to make it executable `chmod 0555 docker_install.sh`. You can then execute the file by running `./docker_install.sh`

### Setting up the GoCD Server

#### Step 1: Creating the GoCD Server Dockerfile
The first step in setting up the GoCD server is to create a `Dockerfile`. A `Dockerfile` is just a set of instructions on how to build a docker image which can later be used to create docker containers. For more information about how to write a `Dockerfile` see the [Dockerfile Reference](https://docs.docker.com/engine/reference/builder/)

```
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
RUN (wget https://download.go.cd/gocd/go-server-15.2.0-2248.zip) && \
    (unzip go-server-15.2.0-2248.zip) && \
    (cp -R go-server-15.2.0 /usr/local) && \
    (mv /usr/local/go-server-15.2.0 /usr/local/go-server) && \
    (chmod 775 /usr/local/go-server/server.sh) && \
    (chmod 775 /usr/local/go-server/stop-server.sh)

ENTRYPOINT /usr/local/go-server/server.sh
CMD []
```

1. Create a folder `mkdir -p /opt/gocd/server` where the file GoCD `Dockerfile` will reside
2. Create `Dockerfile` in folder created above; `touch /opt/gocd/server/Dockerfile`
3. Fire up your text editor (`nano /opt/gocd/server/Dockerfile`), add the copy & paste snippet above then save the file;

#### Step 2: Building GoCD Server docker image
Now that we have our `Dockerfile` ready, we need to build an image that will be used to create our GoCD server container.

```bash
CONTAINER_NAME='gocd_server'

# build gocd server docker image
echo "************ creating gocd server image ******************"
GOCD_DOCKER_IMAGE='gocd_server'
docker build -t $GOCD_DOCKER_IMAGE /opt/gocd/server

# cleanup after build
if [ -n "$(docker images -f 'dangling=true' -q 2> /dev/null)" ]; then
  echo "****** cleanup: remove dangling images. ********"
  docker rmi -f $(docker images -f "dangling=true" -q)
fi
```

1. Create a file `build.sh` place it in the `/opt/gocd/server` folder
2. Copy & paste the above snippet into it and save the file.
3. Change the necessary permissions to the file `chmod 0555 /opt/gocd/server/build.sh`
4. Execute the file from the terminal `$/opt/gocd/server/build.sh`

This will build a docker image based on the `Dockerfile` you created in step 1. And you can see which images are available by running `$ docker images` on the terminal.

#### Step 3: Installing a GoCD Server Container
A container is simply an instance of an image. And since we have an image built in step 2, we can simply fire up a container based on that image and we should have a running GoCD Server.

```bash
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
```

1. Create a file `run.sh` place it in the `/opt/gocd/server` folder
2. Copy & paste the above snippet into it and save the file.
3. Change the necessary permissions to the file `chmod 0555 /opt/gocd/server/run.sh`
4. Execute the file from the terminal `$/opt/gocd/server/run.sh`

With this you should have a running container; to see which containers are currently running, in the terminal run `$ docker ps` and the output should show a running gocd_server container.

Once the GoCD server in the container has started up, you can fire up your browser and go to `http://host:8153/` and you should see a page similar to the one below;

![GoCD Server Screenshot]()

Even with a running server, You are not ready to start the deployment process. You will need to setup agents that will be responsible for the building/deployment process.

### Setting up the GoCD Agent

#### Step 1: Creating the GoCD Agent Dockerfile

Because the agents are going to be containers as well, you will need to create a docker image from which our containers will be derived. To do this, create a `Dockerfile`

```
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
RUN (wget https://download.go.cd/gocd/go-agent-15.2.0-2248.zip) && \
    (unzip go-agent-15.2.0-2248.zip) && \
    (cp -R go-agent-15.2.0 /usr/local) && \
    (mv /usr/local/go-agent-15.2.0 /usr/local/go-agent) && \
    (chmod 775 /usr/local/go-agent/agent.sh) && \
    (chmod 775 /usr/local/go-agent/stop-agent.sh)

ENTRYPOINT /usr/local/go-agent/agent.sh
CMD []
```

1. Create a folder `mkdir -p /opt/gocd/agent` where the GoCD Agent `Dockerfile` will reside
2. Create `Dockerfile` in the folder created above; `touch /opt/gocd/agent/Dockerfile`
3. Fire up you text editor `nano /opt/gocd/agent/Dockerfile`, copy & paste the snippet above into it and save.

Based on the `Dockerfile` above, once the image is built, it will contain; `Java`, `Maven`, `Android SDK` and the GoCD Agent software that will run the build process.

#### Step 2: Building GoCD Agent docker image
Now that the `Dockerfile` is ready, the next step is to build a docker image for the Agent.

```bash
# building the gocd agent docker image
echo "************ creating gocd agent image ******************"
GOCD_DOCKER_IMAGE='gocd_agent'
docker build -t $GOCD_DOCKER_IMAGE /opt/gocd/agent

# removing dangling images
if [ -n "$(docker images -f 'dangling=true' -q 2> /dev/null)" ]; then
  echo "******* cleanup: removing dangling images. ********"
  docker rmi -f $(docker images -f "dangling=true" -q)
fi
```

1. Create a file `build.sh` and place it in the `/opt/gocd/agent` folder
2. Copy & Paste the above snippet into it and save the file.
3. Change the necessary permissions to the file `chmod 0555 /opt/gocd/agent/build.sh`
4. Execute the file from the terminal `$ /opt/gocd/agent/build.sh`

This will build hthe docker image based on the `Dockerfile` created in step 1. You can check that the image was created by running `$ docker images` on the terminal.

#### Step 3: Installing the GoCD Agent container
With the image done, create a container from the agent image.

```bash
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
      -e                            GO_SERVER=127.0.0.1 \
      -e GO_SERVER_PORT=8153 \
      --name $CONTAINER_NAME $GOCD_DOCKER_IMAGE
  fi
  agent_counter="expr $agent_counter + 1"
done
```

1. Create a file `run.sh` place it in the `/opt/gocd/agent` folder
2. Copy & Paste the above snippet into it and save it.
3. Change the necessary permissions to the file `chmod 0555 /opt/gocd/agent/run.sh`
4. Execute the file from the terminal `$ /opt/gocd/agent/run.sh`

You should now have a running a agent container and you can see that by running `$ docker ps` which will show a list of running containers. Look out for a container named `gocd_agent_1`.  
The reason there is a `1` at the indicates the number of the gocd agent. With the script above, you can create multiple agents by assigning the `NUMBER_OF_AGENTS` variable a value of the number of agents you want. You can have as many agents as you wish. In fact this is good because you can have parallel builds taking place.

The last step in the process is to make sure the agents are registered with the gocd server otherwise they will not be used for building. To do that;

1. Open the GoCD server by going to `http://localhost:8153`
2. Go to the `Agents` tab and you should see a list of agents
3. Select the agents you want to register and click `Enable`.

Now the agents are part of our build cloud and can start building.

There are a number of things that have not been dealt with in this post regarding your Continuous Delivery environment i.e. Security, Backup etc. With regard to security, it's of utmost importance that you secure your environment because it can be the weakest link in your entire infrastructure. See [Handling authentication with GoCD](https://docs.go.cd/current/configuration/dev_authentication.html) on how to configure an authentication mechanism for your server.

The next part of the series will focus on configuring a build pipeline to achieve continuous delivery. I hope you enjoy this process let me know in the comments what your experience has been.

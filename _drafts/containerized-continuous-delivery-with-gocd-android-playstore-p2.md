---
layout: post
title: Containerized Continuous Delivery with GoCD and Android PlayStore Part 2
categories: android
---
In [Part 1]({% post_url _posts/2016-03-21-containerized-continuous-delivery-with-gocd-android-playstore-p1 %}) of this series, you saw how to setup [GoCD](https://www.go.cd/). If you have not been through that post, be sure to check it out.
In this post however, you will be configuring your Build & Deployment pipeline to achieve continuous delivery. A pipeline is really a sequence of steps that performed in series or parallel leading up to a common goal.  
A simple pipeline could look something like this;  

![Build Pipeline](/images/simple_build_pipeline.png)

This is a linear pipeline and each step will be executed after the previous step is complete. Pipelines can get slightly more complex with multiple steps running in parallel then converge into a single step like this;  

![Complex Build Pipeline](/images/complex_build_pipeline.png)

You can see from the above illustration that Build/Deployment pipelines help demystify build processes for complex systems but also provide a secondary benefit of releasing the team resources to focus on adding features rather than releasing software especially when combined with Continuous Delivery Tools like [GoCD](https://www.go.cd/) which has pipelines as first class citizens.

Now lets get back to setting up a pipeline for our android app. For this exercise i setup a simple android app [here](https://github.com/ctumwebaze/blog-android).  
First things first before we go any further;  

1. Make sure you have read [Part 1]({% post_url _posts/2016-03-21-containerized-continuous-delivery-with-gocd-android-playstore-p1 %}) of this series and setup your [GoCD](https://www.go.cd/) environment.
2. Setup a PlayStore Account, you can find information on how to do that [here](http://developer.android.com/distribute/googleplay/start.html)
3. Familiarize yourself with configuring pipelines in Go [here](https://docs.go.cd/current/configuration/quick_pipeline_setup.html)

The build/deployment pipeline for the app is a simple four step process;

1. Get code from source control
2. Run unit tests
3. Package App for release
4. Deploy to Google PlayStore

![App Deployment Pipeline](/images/blog_4step_build_pipeline.png)

To create the pipeline in GoCD, access the GoCD server through the browser: in my case `http://localhost:8153` & click the **PIPELINES** tab. This will show the pipeline wizard since you don't have any pipelines created.

![Pipeline Wizard](/images/pipeline_wizard.png)

### Step 1: Basic Pipeline Settings
Give your pipeline a name, in my case i gave it `ANDROID_BLOG_APP`. You can also specify a group if you like or just the default. Hit `NEXT` when you are done to move on to the next step.

### Step 2: Materials
This is where we configure where to pick our source code. In my case i create a simple app for my blog [here](https://github.com/ctumwebaze/blog-android). For more information visit [Step 2: Material](https://docs.go.cd/current/configuration/quick_pipeline_setup.html#step-2-material)

![Material Configuration](/images/step2_material_configuration.png)

***Note: This is the first step in our deployment pipeline. `Get code from source control`***

Hit **NEXT** when you are done to move to the next step.

### Step 3: Stage/Job Configuration
In GoCD, pipelines contain one or more stages and each stage can have one or more jobs/tasks. In our case, the remaining three steps; `Unit Tests`, `Packaging`, 'Deploy to PlayStore' will constitute the stages.

In this step, since we are configuring a new pipeline, we shall configure the `Unit Tests` step and then add the rest of the steps once the pipeline has been created.

1. Assign `TESTING` for the `Stage Name`
2. Assign `UNIT_TESTS` for the initial task/Job name - This is the job/task that executes the unit tests.
3. Select `More` for the `TaskType`
4. Assign `/bin/bash` for the command
5. Assign `arguments` as below   

        -c
        mvn clean test -U -f app/pom.xml -Dandroid.sdk.path=$ANDROID_HOME


When done, your configuration should look something like this;

![Configuring Unit Testing Stage](/images/step3_configuring_stage.png)

Go ahead and hit **FINISH** and you should have something like this;

![Pipeline Configuration Complete](/images/step3_stage_configuration_successful.png)

Now lets configure the remaining steps;

#### Packaging Stage
This is the stage where we package the app what will later be deployed to the PlayStore. Follow the steps [here](https://docs.go.cd/current/configuration/managing_pipelines.html#add-a-new-stage-to-an-existing-pipeline) to create a new stage to an existing pipeline.

1. Assign `PACKAGING` for the `Stage Name`
2. Assign `SIGN_AND_PACKAGE` for the initial task/Job name - this is the task that packages and signs the app.
3. Select `More` for the `TaskType`
4. Assign `/bin/sh` for the command
5. Assign `arguments` as `sign_and_package.sh`

This assumes you have a shell script `sign_and_package.sh` as part of your code base. You can look at one i created earlier [sign_and_package.sh](https://github.com/ctumwebaze/blog-android/blob/master/sign_and_package.sh) and have something similar for your app. Don't forget to make the file executable. `chmod 0755 sign_and_package.sh`.

The packaging scripts expects certain environments to be set and you can set the environment variables for this stage by clicking the `Environment Variables` tab under the configurations of the stage;

1. `SIGNING_CERTIFICATE` - this is a self signed certificate we create that is used when signing our application.  
  ```
  openssl req -x509 -nodes -days 10000 -newkey rsa:2048 -keyout signing.key -out signing.crt
  ```   
  You should configure this variable as a secure variable. Get the content of the `signing.crt` file `paste -s -d "\t" signing.crt | pbcopy` and then paste the content into the value field.
2. `SIGNING_KEY` - key associated with the self signed certificate. Get the content of the `signing.key` file `paste -s -d "\t" signing.key | pbcopy` and then paste the content in a value field. This should also be configured as a secure variable.
3. `KEYSTORE_KEY_ALIAS` - Alias for the key that will be stored in the keystore. Configure as regular variable.
4. `KEYSTORE_PASSWORD` - Password for the keystore. Configure as regular variable.

After configuring the variables, you should have something like this;

![Sign and Package Environment Variable Configuration](/images/sign_package_env_variables.png)

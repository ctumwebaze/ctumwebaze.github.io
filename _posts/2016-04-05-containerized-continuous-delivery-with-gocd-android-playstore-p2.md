---
layout: post
title: Containerized Continuous Delivery with GoCD and Android PlayStore Part 2
categories: android
---
In [Part 1]({% post_url 2016-03-21-containerized-continuous-delivery-with-gocd-android-playstore-p1 %}) of this series, you saw how to setup [GoCD](https://www.go.cd/). If you have not been through that post, be sure to check it out.
In this post however, you will be configuring your Build & Deployment pipeline to achieve continuous delivery.   
A pipeline is really a sequence of steps performed in series or parallel leading up to a common goal. A simple pipeline could look something like this;  

![Build Pipeline](/images/simple_build_pipeline.png)

This is a linear pipeline and each step will be executed after the previous step is complete. Pipelines can get slightly more complex with multiple steps running in parallel then converge into a single step like this;  

![Complex Build Pipeline](/images/complex_build_pipeline.png)

One of the many benefits as you can see from the above illustration is that Build/Deployment pipelines help demystify build processes for complex systems. They also help teams focus on adding features rather than releasing software especially when combined with Continuous Delivery Tools like [GoCD](https://www.go.cd/) which has pipelines as first class citizens.

Now lets get back to setting up a pipeline for our android app. For this exercise i setup a simple android app [here](https://github.com/ctumwebaze/blog-android). The app doesn't have much but you can see how it's setup.
First things first before we go any further;  

1. Make sure you have read [Part 1]({% post_url 2016-03-21-containerized-continuous-delivery-with-gocd-android-playstore-p1 %}) of this series and setup your [GoCD](https://www.go.cd/) environment.
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
Give your pipeline a name, in my case i gave it `ANDROID_BLOG_APP`. You can also specify a group if you like or just the default. Hit **NEXT** when you are done to move on to the next step.

### Step 2: Materials
This is where you configure where to pick our source code. In my case i create a simple app for my blog [here](https://github.com/ctumwebaze/blog-android). For more information visit [Step 2: Material](https://docs.go.cd/current/configuration/quick_pipeline_setup.html#step-2-material)

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
        ./install-libs.sh && mvn clean test -U -f app/pom.xml -Dandroid.sdk.path=$ANDROID_HOME


When done, your configuration should look something like this;

![Configuring Unit Testing Stage](/images/step3_configuring_stage.png)

Go ahead and hit **FINISH** and you should have something like this;

![Pipeline Configuration Complete](/images/step3_stage_configuration_successful.png)

Now lets configure the remaining steps;

#### Packaging Stage
This is the stage where you package the app what will later be deployed to the PlayStore. Follow the steps [here](https://docs.go.cd/current/configuration/managing_pipelines.html#add-a-new-stage-to-an-existing-pipeline) to create a new stage to an existing pipeline.

1. Assign `PACKAGING` for the `Stage Name`
2. Assign `SIGN_AND_PACKAGE` for the initial task/Job name - this is the task that packages and signs the app.
3. Select `More` for the `TaskType`
4. Assign `/bin/sh` for the command
5. Assign `arguments` as `sign_and_package.sh`

This assumes you have a shell script `sign_and_package.sh` as part of your code base. You can look at one i created earlier [sign_and_package.sh](https://github.com/ctumwebaze/blog-android/blob/master/sign_and_package.sh) and have something similar for your app. Don't forget to make the file executable. `chmod 0755 sign_and_package.sh`.

The script just contains instructions to package and sign an apk. It delegates to [Maven](https://maven.apache.org/) represented by the `mvn` binary which delegates to the [Android Maven Plugin](http://simpligility.github.io/android-maven-plugin/). You can see the configuration [pom.xml](https://github.com/ctumwebaze/blog-android/blob/master/app/pom.xml)

The packaging script also expects certain environments to be set and you can set the environment variables for this stage by clicking the `Environment Variables` tab under the configurations of the stage;

1. **SIGNING_CERTIFICATE** - this is a self signed certificate we create that is used when signing our application.  
  ```
  openssl req -x509 -nodes -days 10000 -newkey rsa:2048 -keyout signing.key -out signing.crt
  ```   
  You should configure this variable as a secure variable. Get the content of the `signing.crt` file `paste -s -d "\t" signing.crt | pbcopy` and then paste the content into the value field. The `paste -s -d "\t" signing.crt` is to replace newline characters with tabs and the output it piped into `pbcopy` which stores it's input in the clipboard.
2. **SIGNING_KEY** - key associated with the self signed certificate. Get the content of the `signing.key` file `paste -s -d "\t" signing.key | pbcopy` and then paste the content in a value field. This should also be configured as a secure variable.
3. **KEYSTORE_KEY_ALIAS** - Alias for the key that will be stored in the keystore. Configure as regular variable.
4. **KEYSTORE_PASSWORD** - Password for the keystore. Configure as regular variable.

After configuring the variables, you should have something like this;

![Sign and Package Environment Variable Configuration](/images/sign_package_env_variables.png)

Note: *SIGNING_CERTIFICATE and SIGNING_KEY environment variable values are prepared the way we do because we are unable to set actual files as values so we use the file content as the variable values and then later recreate the files using the values of the environment variables.*

#### Deploying to the PlayStore Stage
The assumption here is that you already have a Google Play account. If you have not done that already checkout out [Get Started with Publishing](http://developer.android.com/distribute/googleplay/start.html).

You will also need to create a service account that will be used to do publications to the play store. For more information visit [Google Play Developer API](https://developers.google.com/android-publisher/getting_started#using_oauth_clients). Be sure to get the `p12` key for the service account instead of the `json` key format you will be using the p12 shortly.

To create the deployment state, follow the steps [here](https://docs.go.cd/current/configuration/managing_pipelines.html#add-a-new-stage-to-an-existing-pipeline) to create a new stage to an existing pipeline;

1. Assign `DEPLOYMENT` for the `Stage Name`
2. Assign `GOOGLE_PLAY_STORE` for the initial task/Job name - this is the task that packages and signs the app.
3. Select `More` for the `TaskType`
4. Assign `/bin/sh` for the command
5. Assign `arguments` as `playstore_deploy.sh`

Again the assumption is that you have `playstore_deploy.sh` as part of your code base. You can look at one i created earlier [here](https://github.com/ctumwebaze/blog-android/blob/master/playstore_deploy.sh). As you can see, it delegates to maven which uses the [Android Maven Plugin](http://simpligility.github.io/android-maven-plugin/) to publish to google play.

The deployment script also expects certain environment variables to be set and you can set the variables for this stage by clicking the `Environment Variables` tab under the configurations for the stage;

The following variable should be configured as secure variables. The benefit of this is that no one can get their values after they are created unlike the ordinary variables.

1. **PUBLISHER_PRIVATE_KEY** - this is the private key of the signing account. To obtain this value, export it from the `p12` keystore you downloaded earlier.
    1. Rename the downloaded keystore file to `publisher.p12`
    2. Run `openssl pkcs12 -in publisher.p12 -nocerts -out publisher.key` on the terminal to export the private key as `publisher.key`
    3. Run `paste -s -d "\t" publisher.key | pbcopy` - this replaces newline characters with tab characters and outputs the content to the clipboard.
    4. Paste the value of the clipboard into the value of the environment variable.  
2. **PUBLISHER_CERTIFICATE** - this is the certificate associated with the publisher's private key. To obtain the value, export it form the `p12` keystore you downloaded earlier.
    1. Rename the downloaded keystore file to `publisher.p12` if you have not done so above.
    2. Run `openssl pkcs12 -in publisher.p12 -clcerts -nokeys -out publisher.crt` on the terminal to export the certificate as `publisher.crt`
    3. Run `paste -s -d "\t" publisher.crt | pbcopy` - this replaces the newline characters with tab characters and outputs the content to the clipboard.
    4. Paste the value of the clipboard into the value of the environment variable.

Once your done configuring, you should have something like this;

![Deployment Environment Variables](/images/deployment_stage_variables.png)

The only downside i can point out is; you have to manually upload a signed apk to google play once for automatic publishing to work thereafter otherwise you will be facing a brick wall.

One more thing to note; GoCD does not allow configuring files as environment variables without the help of plugins that is why the content of the files is copied into the environment variables and files will be created out of that content.

I sure do hope this has been helpful. I do look forward to your feedback in the comments including the apps you have released using this method.

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
3. Package App for released
4. Deploy to Google PlayStore

![App Deployment Pipeline](/images/blog_4step_build_pipeline.png)

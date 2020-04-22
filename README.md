# IoT Edge image clean up module

Example module for automatically cleaning up unused Docker images from your IoT Edge boxes

## Background

If you've worked with IoT Edge, particularly as you develop modules and roll out new versions over time, one of the issues you'll see is that the old docker images 'pile up' on the machine.  There is no built-in provision for IoT Edge to clean up these old, unused images.  Eventually this can lead to the IoT Edge box running out of disk space.

There are a number of ways to deal with these old images that we've seen, such as a cron or scheduled job that does a 'docker image prune'.   However, we had not previously seen an example of how to do this in an 'edge-y' way.  

This repo and module attempts to provide one example of how you might do that.

** NOTE:  at this time, this module supports IoT Edge running on Linux only. Additionally, we've only tested on Ubuntu. **

##  How does it work?

The bulk of the work is done in the [run.sh](module/run.sh) script in the modules folder.  This bash script checks some optional input environment variables and then sets up an infinite loop where it purges unused images and then sleeps for some configurable amount of time...

The 'meat' of the solution is this line:

    curl -X POST -s --unix-socket /var/run/docker.sock http://localhost/images/prune?filters=%7B%22dangling%22%3A%20%5B%22false%22%5D%7D

This line calls the /images/prune docker runtime API (via the aforementioned domain socket).  That API does the heavy lifting.  We also pass in, url encoded, the query string 'filters={"dangling":["true"]} parameter.  This tells the API to get rid of ALL unused images, not just the ones that are dangling (i.e. have \<none>:\<none> for image repo and name)

That's it.  The rest of the script is mostly 'salad'

Beyond that, we provide a [Dockerfile](module/Dockerfile) to build the actual container image to be deployed to IoT Edge

## How to build and use it

### Building
The modules folder contains the script and Dockerfile.  Clone the repo to a development machine with Docker installed and run

```bash
cd iot-edge-image-clean/modules

docker build -t <your repo name>/<your image name>:<your tag> .

docker login <your repo name> -u <user id> -p <password>
docker push <your repo name>/<your image name>:<your tag> 
```
(note the '.' on the end of the build command, don't forget it)

alternately, if you clone the repo to a machine with VS Code on it and the "Docker" extension, you can right click on the Dockerfile and click "Build Image...".   Enter in your repo, image name, and tag and hit enter.  Then from the terminal window do a 'docker login' and 'docker push' as specified above

### Using

To you the module on your IoT Edge box, you just add it to your deployment (i.e via the deployment JSON *OR* via Set Modules in the Azure Portal)

For the module URI, specify the image name you used above

there are two optional environment variables you can specify to control how often the image pruning runs  (which shouldn't be terribly often)

* SleepTime -- the amount of time to sleep betwen runs.  Must be an integer
* SleepUnit -- the 'unit' to apply to SleepTime.  i.e. 's' for seconds, 'm' for minutes, 'h' for hours, or 'd' for days.  

If you don't specify values, the script will default to 24 hours

The final thing you need to do is bind the /var/lib/docker.sock unix domain socket to the container.  Do that, in your "container create options", specify

```json
{
  "HostConfig": {
    "Binds": [
      "/var/run/docker.sock:/var/run/docker.sock"
    ]
  }
}
```

That's it.  Once the deployment is submitted, you can log into your IoT Edge box and do a 'iotedge logs -f \<modulename>' to watch the results...

To test the module, feel free to pull down a few random docker images. Here are a ideas few to test with

```bash
docker pull hello-world
docker pull nginx
docker pull mysql
```

then do a 

```bash
docker images
```

to see them.  Then, the next time the module wakes up to prune, return the 'docker images' and watch the images disappear.


##  A few words of warning

Before we leave you, a few words of warning.  

#### Powerful access
For this module to work, you have to bind or map the /var/lib/docker.sock unix domain socket from the IoT Edge host into the edge module container.  This is the unix domain socket upon which the docker runtime listens for commands (i.e. you type 'docker image purge' from the docker CLI, under the covers it's talking to the docker daemon on this socket).

By mapping his docker daemon socket into the container, you are giving the module free reign on your docker installation, to do whatever it wants.  So code within the module can do pretty much anything you can do with the docker cli, including deleting containers, images, etc. Only you can determine the risk level in doing that for your particular installation.

#### It's like a tactical nuke
This module prunes ALL unused images on your box, not just the ones that might have been pull by IoT Edge.  So, *if* you use your IoT Edge machine for other docker things, and there are docker images laying around unused related to other projects, the module will nuke them too.  Docker can obviously re-pull the images when it needs them for containers, but just be aware of this on slower networks.

#### Possible race conditions
We haven't tested all the potential race conditions that might be involved. For example, one potential one might be that you are stopping IoT Edge (via 'sudo systemctl stop iotedge'), which prompts the iotedge daemon to stop all the modules and delete the containers.  We aren't sure the order in which this happens is deterministic.  So, *if* say edgeHub gets stopped and the container gets removed and *if* this module is still running and hits a 'prune' cycle in that exact moment before it's shut down itself, it could nuke the edgeHub image.  Highly unlikely timing, but somewhere in the infinite universe this might happen. Another potential race condition could be that this module gets started first before the others, and nukes some of the images that Edge is using to start the other containers.  Again, IoT Edge would just re-pull the images it needs, but just be aware of this on potentially slow or unreliable networks.


## Future enhancements

This was primarily done as a proof-of-concept to see if the unused docker images could be purged from within IoT Edge itself.  So a bash shell was purposely used to minimize language dependencies, etc.  

A few future enhancements we are thinking about:
* add a delay to start-up to address one of the possible race conditions mentioned previously
* having the module post the 'results' of each purge to edgeHub (and thus you can route to IoT Hub) to report up to the cloud when it purges
* having the module post to Azure Log Analtics for operational reporting
* Re-writing in a 'better' language than bash (mayby python, for example) to make it easier to do the first two bullets :-)

## Enjoy!

Enjoy and let us know if you find any issues (via..  well.. issues!).  Also, feel free to contribute.  We happily take pull requests!
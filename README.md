# [Jupiter-x-Docker](https://jupyter-x-docker.herokuapp.com/)

[![Jupyter x Docker on Heroku](Jupyter_x_Docker_to_Heroku.jpg)](https://jupyter-x-docker.herokuapp.com/)

Jupyter is a tool for running interactive notebooks; basically add Python with Markdown and you've got Jupyter.

Deploy a Jupyter Notebook server on Heroku using Docker. 

## The big caveat
Jupyter has the ability to create new notebooks and they will 100% save on your deployed docker-based Jupyter server... but they will **disappear** as soon as you deploy a new version. That's because containers, by their very nature, are ephemeral by default. 

This caveat doesn't mean we shouldn't do this... it just means it is a HUGE consideration when using this guide over something like http://colab.research.google.com.

So encounter this issue, We will package all your Jupyter contents, download it, and unpackage it again when we deploy.


### Final Project Structure

```bash
|   .dockerignore
|   Dockerfile
|   Jupyter_x_Docker_to_Heroku.jpg
|   Pipfile
|   Pipfile.lock
|   README.md
|   
+---.github
|   \---workflows
|           publish.yml
|           
+---configuration
|       jupyter.py
|       
+---root
|       LoadUnload.ipynb
|       notebook.tar.gz
|       
\---scripts
        docker_build.ps1
        docker_build.sh
        docker_push.ps1
        docker_push.sh
        docker_run_dockerhub.ps1
        docker_run_dockerhub.sh
        docker_run_github_registry.ps1
        docker_run_github_registry.sh
        entrypoint.sh
        github_registry_push.ps1
        github_registry_push.sh
        heroku_push.ps1
        heroku_push.sh
```

## How it's done.

#### 1. Use `pipenv` and install `jupyter`

```bash
pip install pipenv
cd jupyter-x-docker
pipenv install jupyter --python 3.9
```

#### 2. Create Jupyter Configuration

**Generate Default Config**

```bash
jupyter notebook --generate-config
```

This command creates the default `jupyter_notebook_config.py` file on your local machine. Mine was stored on `~/.jupyter/jupyter_notebook_config.py`

**Create `configuration/jupyter.py`**

```bash
mkdir configuration
echo "" > configuration/jupyter.py
```

In `configuration/jupyter.py` add:

```python
import os
c = get_config()

# Kernel config
c.IPKernelApp.pylab = 'inline'  # if you want plotting support always in your notebook

# Notebook config
c.NotebookApp.notebook_dir = 'root'
c.NotebookApp.allow_origin = u'jupyter-x-docker.herokuapp.com' # put your public IP Address here
c.NotebookApp.ip = '*'
c.NotebookApp.allow_remote_access = True
c.NotebookApp.open_browser = False

# ipython -c "from notebook.auth import passwd; passwd()"
c.NotebookApp.password = u"argon2:$argon2id$v=19$m=10240,t=10,p=8$98xA9epRaTToOra3j2dg/w$BCZmhp+/xaajsl2R8P57BigZvVT/KjkCqe9InvdyHwQ"
c.NotebookApp.port = int(os.environ.get("PORT", 8888))
c.NotebookApp.allow_root = True
c.NotebookApp.allow_password_change = True
c.ConfigurableHTTPProxy.command = ['configurable-http-proxy', '--redirect-port', '80']
```

A few noteable setup items here:

- `c.NotebookApp.notebook_dir` I set as `root` which means you should create a directory as `root` for your default notebooks directory. In my case, jupyter will open right to this directory ignoring all others.
- `c.NotebookApp.password` - this has to be a hashed password. To create a new one, just run `ipython -c "from notebook.auth import passwd; passwd()"` on your command line.
- `c.NotebookApp.port` - Heroku sets this value in our environment variables thus `int(os.environ.get("PORT", 8888))` as our default.


Test your new configuration locally with: `jupyter notebook --config=./configuration/jupyter.py`


#### 3.Create a notebook under -> `root/LoadUnload.ipynb`

This will be how you can handle the ephemeral nature of Docker containers with Jupyter notebooks. Just create a new notebook called `LoadUnload.ipynb`, and add the following:

```python
mode = "unload"

if mode == 'unload':
    # Zip all files in the current directory
    !tar chvfz notebook.tar.gz *
elif mode == 'load:
    # Unzip all files in the current directory
    !!tar -xv -f notebook.tar.gz
```


#### 4. Add your `Dockerfile`

This is the absolute minimum setup here. You might want to add additional items as needed. Certain packages, especially the ones for data science, require additional installs for our docker-based linux server.

```dockerfile
FROM python:3.9.0

ENV APP_HOME /app
WORKDIR ${APP_HOME}

COPY . ./

RUN pip install pip pipenv --upgrade
RUN pipenv install --skip-lock --system --dev

LABEL org.opencontainers.image.source https://github.com/JayantGoel001/Jupyter-x-Docker
LABEL org.opencontainers.image.description Jupyter Notebook Server built with Docker & deployed on Heroku.

RUN [ "chmod", "+x", "./scripts/entrypoint.sh" ]

CMD ["./scripts/entrypoint.sh"]
```

This is the one I used [Jupyter-x-Docker](https://jupyter-x-docker.herokuapp.com/)

Since, You might need additional packages (like `numpy` or `pandas` or `opencv`) in your project.

```dockerfile
FROM python:3.9.0

ENV APP_HOME /app
WORKDIR ${APP_HOME}

COPY . ./

# Install Ubuntu dependencies
# libopencv-dev = opencv dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        tzdata \
        libopencv-dev \ 
        build-essential \
        libssl-dev \
        libpq-dev \
        libcurl4-gnutls-dev \
        libexpat1-dev \
        gettext \
        unzip \
        supervisor \
        python3-setuptools \
        python3-pip \
        python3-dev \
        python3-venv \
        python3-urllib3 \
        git \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*


RUN pip install pip pipenv --upgrade

# sklearn opencv, numpy, and pandas
RUN pip install scikit-learn opencv-contrib-python numpy pandas

# tensorflow (including Keras)
RUN pip install tensorflow keras

# pytorch (cpu)
RUN apt-get update && apt-get -y install gcc mono-mcs && rm -rf /var/lib/apt/lists/*
RUN pip install torch==1.10.1+cpu torchvision==0.11.2+cpu torchaudio==0.10.1 -f https://download.pytorch.org/whl/torch_stable.html

# fastai
RUN pip install fastai

# Project installs
RUN pipenv install --skip-lock --system --dev

LABEL org.opencontainers.image.source https://github.com/JayantGoel001/Jupyter-x-Docker
LABEL org.opencontainers.image.description Jupyter Notebook Server built with Docker & deployed on Heroku.

RUN [ "chmod", "+x", "./scripts/entrypoint.sh" ]

CMD [ "./scripts/entrypoint.sh" ]
```

> The most noteable part of this all is that 
    (1) We are using `pipenv` locally and in docker and 
    (2) We have both installed `pipenv` and run `pipenv install --system` to install all pipenv dependancies to the entire docker container (instead of in a virtual environment within the container as well).


#### 5. Create `scripts/entrypoint.sh`

I perfer using a `entrypoint.sh` script for the `CMD` in Dockerfiles. 

```bash
#!/bin/bash

/usr/local/bin/jupyter notebook --config=./configuration/jupyter.py
```


#### 6. Build & Run Docker Locally

```bash
docker build -t jayantgoel001/jupyter-x-docker:latest .
docker run --env PORT=8888 -it -p 8888:8888 jayantgoel001/jupyter-x-docker
```

#### 7. Heroku Setup

##### 1. Create heroku app

```bash
heroku create jupyter-x-docker
```
- Change `jupyter-x-docker` to your app name

##### 2. Login to Heroku Container Registry

```bash
heroku container:login
```

#### 7. Push & Release To Heroku

```bash
heroku container:push web -a jupyter-x-docker 
heroku container:release web -a jupyter-x-docker 
```

- `web` is the default for our `Dockerfile`. 

#### 8. That's it

```bash
heroku open
```

This should allow you to open up your project.

## Additional Reference

### `Pipfile`

```
[[source]]
url = "https://pypi.org/simple"
verify_ssl = true
name = "pypi"

[packages]
jupyter = "*"

[dev-packages]

[requires]
python_version = "3.9"

```
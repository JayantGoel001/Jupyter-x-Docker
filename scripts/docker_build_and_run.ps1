docker build -t jupyter-x-docker:latest .
docker run --env PORT=8888 -it -p 8888:8888 jupyter-x-docker
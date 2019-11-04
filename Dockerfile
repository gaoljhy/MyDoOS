FROM ubuntu:16.04
MAINTAINER Sergey Matyukevich <gaoljhy@gmail.com>
RUN apt-get update && apt-get install -y gcc-aarch64-linux-gnu build-essential

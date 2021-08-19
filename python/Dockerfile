# syntax=docker/dockerfile:1

FROM eecsautograder/ubuntu18:latest

RUN apt-get update && apt-get install -y unzip

RUN apt-get update && apt-get -yq install software-properties-common

RUN add-apt-repository ppa:deadsnakes/ppa -y

RUN DEBIAN_FRONTEND=noninteractive apt-get -yq install python3.10


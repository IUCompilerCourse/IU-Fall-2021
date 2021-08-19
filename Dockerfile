# syntax=docker/dockerfile:1

FROM eecsautograder/ubuntu18:latest

RUN apt-get update && apt-get install -y racket

RUN apt-get update && apt-get install -y unzip




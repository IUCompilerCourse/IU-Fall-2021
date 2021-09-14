# syntax=docker/dockerfile:1

FROM eecsautograder/ubuntu18:latest

RUN apt-get update && apt-get install -y racket

RUN raco pkg install --batch --auto --no-setup graph

RUN apt-get update && apt-get install -y unzip


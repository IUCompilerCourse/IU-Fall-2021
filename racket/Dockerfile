# syntax=docker/dockerfile:1

FROM eecsautograder/ubuntu18:latest

RUN apt-get update && apt-get install -y racket

RUN apt-get update && apt-get install -y sqlite

RUN apt-get update && apt-get install -y libssl-dev

RUN apt-get update && apt-get install -y ca-certificates

RUN raco pkg install --batch --auto graph

RUN apt-get update && apt-get install -y unzip


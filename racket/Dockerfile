# syntax=docker/dockerfile:1

FROM eecsautograder/ubuntu18:latest

RUN apt-get update && apt-get install -y racket

RUN raco setup --doc-index --force-user-docs

RUN raco pkg install -i --batch --auto graph

RUN apt-get update && apt-get install -y unzip


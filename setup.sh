#!/bin/bash

unzip -q course-compiler.zip

gcc -c -std=c99 runtime.c

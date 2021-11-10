#!/bin/bash

unzip -q python-compiler.zip

gcc -c -std=c99 runtime.c

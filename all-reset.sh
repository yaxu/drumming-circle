#!/bin/bash
parallel-ssh -i -h hosts.txt killall -9 feedforward 
parallel-ssh -i -h hosts.txt killall -9 dirt-pa


#!/bin/bash

killall omxplayer
./replay $1 $2
omxplayer -b  /home/pi/wybourn/$1.mp4

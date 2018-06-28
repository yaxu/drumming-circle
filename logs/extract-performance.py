#!/usr/bin/python3

# from matplotlib.dates import epoch2num, date2num
#import matplotlib.pyplot as plt
#import numpy as np
import io
import json
import sys
import time, os

day = 1529971200


# GROUP 1 PERF 1: 2018-06-26T09:34:59
# eval was at 2:15, i.e. 9:37:14
# timestamp says 
# 09:39:24
# 2:10 out !
# real start = 2018-06-26T09:37:09

# GROUP 1 PERF 2: 2018-06-26T09:44:30
# 09:45:47

# GROUP 2 PERF 1: 2018-06-26T11:38:49
# 11:40:06

# GROUP 2 PERF 2: 2018-06-26T11:47:14
# 11:48:14

# GROUP 3 PERF 1: 2018-06-26T13:57:59
# 13:59:44

date_format ='%Y-%m-%dT%H:%M:%S'


sessions = [{'name': 'session-1-1',
             #'start': '2018-06-26T09:34:59',
             'start': '2018-06-26T09:37:09',
             'duration': 466,
             #'stop':  '2018-06-26T09:44:20' # guess
            },
            {'name': 'session-1-2',
             #'start': '2018-06-26T09:44:30',
             'start': '2018-06-26T09:46:40',
             'duration': 570,
             'stop':  '2018-06-26T10:00:00' # guess
            },
            {'name': 'session-2-1',
             #'start': '2018-06-26T11:38:49',
             'start': '2018-06-26T11:40:59',
             'duration': 472,
             'stop':  '2018-06-26T11:47:00' # guess
            },
            {'name': 'session-2-2',
             #'start': '2018-06-26T11:47:14',
             'start': '2018-06-26T11:49:24',
             'duration': 570,             
             'stop':  '2018-06-26T12:10:00' # guess
            },
            {'name': 'session-3-1',
             #'start': '2018-06-26T13:57:59',
             'start': '2018-06-26T14:00:09',
             'duration': 339,
             'stop':  '2018-06-26T14:15:59' # guess
            }
]

# bst
tz_offset = 60 * 60

computers = ['drum1', 'drum2', 'drum3', 'drum4',
             'drum5', 'drum6', 'drum7', 'drum8',
             'drum9'
            ]
            
os.environ['TZ']='GMT'


for session in sessions:
    name = session['name']
    print(name)

    start = session['start']
    print(start)
    #stop = session['stop']
    #print(stop)
    
    ut_start = int(time.mktime(time.strptime(start,date_format))) - tz_offset
    #ut_stop  = int(time.mktime(time.strptime(stop,date_format))) - tz_offset
    ut_stop  = ut_start + session['duration']

    print(ut_start)
    print(ut_stop)

    for computer in computers:
        fn = "/home/alex/src/drumming-circle/logs/" + computer + ".json"
        f = io.open(fn)
        ls = f.readlines()
        f.close()

        flag = False
        startTimes = []
        for l in ls:
            if l.startswith("// connect"):
                flag = True
            else:
                if (flag == True) and (not l.startswith("//")):
                    j = json.loads(l)
                    t = j['cWhen']
                    startTimes.append(t)
                    #print("startTime: " + str(t))
                    flag = False

        connectTime = 0
        for startTime in startTimes:
            if startTime <= ut_start:
                connectTime = startTime
        #print("ut_start: " + str(ut_start) + " connectTime: " + str(connectTime) + " delta: " + str(ut_start - connectTime))
        
        def f(l):
            j = json.loads(l)
            t = j['cWhen']
            return(t > ut_start and t < ut_stop)

        ls = filter(f, filter(lambda l: not l.startswith("//"), ls))
        print(" > " + computer)
        #print("   " + str(len(ls)))
        ofn = "/home/alex/src/feedforward/src/logs/sessions/" + name + "-" + computer + ".json"
        fo = open(ofn, "w")
        fo.write("{\"cWhen\":" + str(ut_start) + ",\"tag\":\"Eval\",\"cAll\":true}\n")
        fo.write("\n".join(ls))
        fo.close()

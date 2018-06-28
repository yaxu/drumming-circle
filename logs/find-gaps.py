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
# 09:37:34

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
             'start': '2018-06-26T09:37:34',
             'duration': 466,
             #'stop':  '2018-06-26T09:44:20' # guess
            },
            {'name': 'session-1-2',
             #'start': '2018-06-26T09:44:30',
             'start': '2018-06-26T09:45:47',
             'duration': 570,
             'stop':  '2018-06-26T10:00:00' # guess
            },
            {'name': 'session-2-1',
             #'start': '2018-06-26T11:38:49',
             'start': '2018-06-26T11:40:06',
             'duration': 472,
             'stop':  '2018-06-26T11:47:00' # guess
            },
            {'name': 'session-2-2',
             #'start': '2018-06-26T11:47:14',
             'start': '2018-06-26T11:48:14',
             'duration': 570,             
             'stop':  '2018-06-26T12:10:00' # guess
            },
            {'name': 'session-3-1',
             #'start': '2018-06-26T13:57:59',
             'start': '2018-06-26T13:59:44',
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

ts = []
for computer in computers:
    fn = "/home/alex/src/drumming-circle/logs/" + computer + ".json"
    f = io.open(fn)
    ls = f.readlines()
    f.close()

    for l in ls:
        if (not l.startswith("//")):
            j = json.loads(l)
            t = j['cWhen']
            ts.append(t)

ts.sort()

prev = 0
c = 0
for t in ts:
    if prev > 0:
        delta = t - prev

        if delta > 30:
            humanT = time.strftime("%a, %d %b %Y %H:%M:%S %Z", time.localtime(t))
            print(humanT + ": " + str(delta) + " (" + str(c) + ")")
            c = 0
    prev = t
    c = c + 1


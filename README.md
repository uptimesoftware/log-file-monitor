log-file-monitor
================

The Log File Monitor replaces the older "Enhanced Log File Monitor".  It has the same capabilities but is built with more reliable code.  The Log File Monitor will search a given text file for a desired string (both can be entered as regular expressions).

Note: the file needs to have read permission for the user that runs the up.time Agent.  (ex. by default, the uptimeagent user runs the up.time Agent on Linux)


1. Fields
-------------------------

Below is a description of each of the Log Monitor settings that are used:

 Script Name - the location of the script on the up.time Monitoring Station that is responsible for connecting to the up.time Agent and running the remote log-file-monitor.pl script
 Port - port used by up.time Agent (default 9998)
 Password - password defined in the up.time Agent (Windows only)                 
 Logs Directory - the full path location of the log files on the Agent system that are to be searched
 Log Files to Search - a string representing one or more files to be searched (regex compatible)
 Search String - the search string to search for in the file (regex compatible)
 Ignore String - a string used to ignore lines in the file(s) being searched. If the string is matched, the line is ignored (regex compatible) (optional)
 Occurrences - total number of lines the search string was found
 Response Time - total amount of time the monitor took to run (in ms)

IMPORTANT NOTE: The "Max Rechecks" alert setting should be set to zero (0) because this service monitor utilizes a bookmark file to avoid finding the same occurrence of a search string on subsequent runs.  If Max Rechecks is set to a value greater than zero, it is very likely that no alert message will get sent out.


2. Agent Installation
-------------------------

POSIX:
a. Place the log-file-monitor.pl file in the directory 
   /opt/uptime-agent/scripts/ (create the directory if needed)
b. Add a new entry to the /opt/uptime-agent/bin/.uptmpasswd keyword file:
   log-file-monitor /opt/uptime-agent/scripts/log-file-monitor.pl

WINDOWS:
a. Place the log-file-monitor.pl file in the up.time Agent scripts directory 
   (ex. C:\Program Files (x86)\uptime software\up.time agent\scripts)
   (create the scripts directory if needed)
b. Open the up.time Agent Console and click on Advanced > Custom Scripts
c. Enter the following 
(change <perl_dir> to the proper Perl path; ex. C:\Strawberry\perl\bin\perl.exe):
Command Name:   log-file-monitor
Path to Script: cmd.exe /c "{PERL_DIR} "C:\Program Files (x86)\uptime software\up.time agent\scripts\log-file-monitor.pl""


3. Examples
-------------------------

Here are some example settings for the Log File Monitor:

Search the directory "/usr/local/uptime/logs" in files named "uptime.log.*" for "error" or "exception":
Port                - 9998
Password            - *********
Log Directory       - /usr/local/uptime/logs/
Log Files to Search - uptime\.log.*
Search String       - (error)|(exception)
Ignore String       - 
Occurrences         - Critical: is greater than 0
Max Rechecks        - 0


Search the file "/usr/local/uptime/logs/uptime.log" for "up.time software" and ignore lines that do not start with "2014-10":
Port                - 9998
Password            - *********
Log Directory       - /usr/local/uptime/logs/
Log Files to Search - uptime.log
Search String       - up.time software
Ignore String       - [^(2014-10)]
Occurrences         - Critical: is greater than 0
Max Rechecks        - 0

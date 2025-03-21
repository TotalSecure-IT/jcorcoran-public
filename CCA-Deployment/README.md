If you need to rename the machine, do that FIRST and reboot--the script will use the default hostname and autojoin to a domain if you dont.

Copy the entire 'CCA-Deployment' folder to C:\

Run deploy.bat AS AN ADMINISTRATOR....

If there are any problems, try to run the script a second time. If that doesnt work, suck it.

changes:

+ improved logging
+ improved redundancy
+ improved error handling
+ added acronis installation
+ increased check statuses 

known issues: 

+ join domain function incorrectly/cosmetically reports success on failure
+ the VPN connect sometimes works great, but maybe its the old sonicwall being old and doesnt respond in a timely manner. the script will attempt retries but it still may time out. just run the script again

plans:

+ allow script to launch from USB stick

* IMPORTANT *

Do the windows updates first. This script uses msiexec to install Acronis and it may fail if windows is driving
If you need to rename the machine, do that FIRST and reboot--the script will use the default hostname and autojoin to a domain if you dont.

* STEPS *

Copy the entire 'CCA-Deployment' folder to C:\

Run deploy.bat AS AN ADMINISTRATOR....

If there are any problems, try to run the script a second time. If that doesnt work, suck it.

changes:

+ fixed issue with --nowarn error, requiring winget update prior to ps7 install
+ improved logging
+ improved redundancy
+ improved error handling
+ added acronis installation
+ increased check statuses 

known issues: 

+ join domain function incorrectly/cosmetically reports success on failure
+ the VPN connect sometimes works great, but maybe its the old sonicwall being old and doesnt respond in a timely manner. the script will attempt retries but it still may time out. just run the script again
+ the acronis installer is bulky and if msiexec messes up or if the window closes, those processess may hang and msiexec may need to be killed in the task manager or a reboot may be required

plans:

+ allow script to launch from USB stick

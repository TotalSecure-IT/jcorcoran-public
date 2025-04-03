@echo off
setlocal enabledelayedexpansion
set a[0]=0214-LT-121015
set a[1]=0308-DT-121095
set a[2]=0308-DT-121099
set a[3]=EMILY??
set a[4]=0303-DT-121090
set a[5]=hampton-10
set a[6]=hampton-06
set a[7]=0321-DT-1210125
set a[8]=hampton-02
set a[9]=hampton-07
set a[10]=hampton-01
set a[11]=H_R-CONF_RM
set a[12]=JOE??
set a[13]=0301-LT-121020
set a[14]=BLANK
set a[15]=0308-DT-121094
set a[16]=0307-LT-121024
set a[17]=0307-LT-121023
set a[18]=hampton-08

:start
for /l %%n in (0,1,18) do (
	echo ~----!a[%%n]!----~
	powershell -Command "& {(Get-WmiObject -Class Win32_ComputerSystemProduct -ComputerName !a[%%n]!).UUID}"
)
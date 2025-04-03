@echo off
setlocal enabledelayedexpansion
set a[0]=Hl-brian
set a[1]=Hl-dusty
set a[2]=Hl-elizabeth
set a[3]=Cw0006202
set a[4]=Amyp
set a[5]=Hl-amy
set a[6]=Crystal-pc
set a[7]=Devri-hl
set a[8]=Hl-kerri
set a[9]=Hl-mindy
set a[10]=Hl-sid
set a[11]=H_R-CONF_RM
set a[12]=Minint-jeff
set a[13]=Minint-russ
set a[14]=Minint-sid
set a[15]=Minint-todd
set a[16]=DESKTOP-853ABBO
set a[17]=Minint-deb
set a[18]=Julie-hl

:start
for /l %%n in (0,1,18) do (
	echo ~----!a[%%n]!----~
	mkdir \\!a[%%n]!\c$\renametest\
	timeout /t 1 /nobreak
	\\!a[%%n]!\c$\renametest\ testrename
	timeout /t 1 /nobreak
)
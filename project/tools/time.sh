#!/bin/bash
# Program:
#	Get inferno and bonfire used time
# History:
# 2012/04/25	Kevin	First release
# 2012/05/03	Kevin	Sencond release 
# modify directory sn and time getways
# 2012/05/05	Kevin	Third release
# add time select and if sn is the same,use the new one
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
RESULT=""
P105Number=0
P106Number=0
P107Number=0
P105allInfernosecond=0
P105allBonfiresecond=0
P106allInfernosecond=0
P106allBonfiresecond=0
P107allInfernosecond=0
P107allBonfiresecond=0

#change the time string **:**:** to second
function getsecond()
{
	if [ "$1" = "" ]
	then
		echo 0
		return 0
	fi
	local hour=`echo $1 | cut -d ':' -f 1 | sed 's/^0//'`
	local minute=`echo $1 | cut -d ':' -f 2 | sed 's/^0//'`
	local second=`echo $1 | cut -d ':' -f 3 | sed 's/^0//'`
	local allsecond=$(($hour*60*60+$minute*60+$second))
	echo $allsecond
}

#change the second to time string **:**:**
function getHMS()
{
	local hour=$(($1/60/60))
	local minute=$(($1%3600/60))
	local second=$(($1%60))
	echo $hour:$minute:$second
}

function getInfernotime()
{
	Infernostarttime=`sed -n 1p "$1"/Earthbound/summary.csv | sed 's/.*\([0-9]\{4\}-[0-9 -:]\{14\}\).*/\1/'`
	Infernoendtime=`tail -n 1 "$1"/Earthbound/summary.csv | head -n 1 |  sed 's/.*\([0-9]\{4\}-[0-9 -:]\{14\}\).*/\1/'`

	Infernostartsecond=`date -j -f "%Y-%m-%d %H:%M:%S" "$Infernostarttime" +%s`
	Infernoendsecond=`date -j -f "%Y-%m-%d %H:%M:%S" "$Infernoendtime" +%s`

	Infernoallsecond=$(($Infernoendsecond-$Infernostartsecond))
	echo $Infernoallsecond
}

function getBonfiretime()
{	
	Bonfirestarttime=`grep -a "C8TH" $1/Bonfire/Battery.csv | cut -d ',' -f 5`
	Bonfireendtime=`grep -a "C8TH" $1/Bonfire/Battery.csv  | cut -d ',' -f 6`
	Bonfirestartsecond=`date -j -f "%Y-%m-%d %H:%M:%S" "$Bonfirestarttime" +%s`
	Bonfireendsecond=`date -j -f "%Y-%m-%d %H:%M:%S" "$Bonfireendtime" +%s`
	local Bonfireallsecond=0
	Bonfireallsecond=$(($Bonfireendsecond-$Bonfirestartsecond))
	echo $Bonfireallsecond
}

function gettime()
{
	local Infernoallsecond=`getInfernotime $1`
	local Infernotime=`getHMS $Infernoallsecond`

	local Bonfireallsecond=`getBonfiretime $1`
	local Bonfiretime=`getHMS $Bonfireallsecond`

	
	config=`cat $1/Inferno/log.txt | grep 'CFG#:' | head -n 1 | cut -d ':' -f 2 |cut -d '/' -f 1| tr -d ' '`
	sn=`cat $1/Inferno/log.txt | grep 'SrNm:' | head -n 1 | cut -d ':' -f 2 |tr -d ' '`
	exist=`echo "$RESULT" | grep $sn`
	if [ "$exist" != "" ]
	then
		return 1
	fi
	RESULT="$RESULT\n$sn,$config,$Infernotime,$Bonfiretime"
	case $config in
	"P105") 
		P105Number=$(($P105Number+1))
		P105allInfernosecond=$(($P105allInfernosecond+$Infernoallsecond))
		P105allBonfiresecond=$(($P105allBonfiresecond+$Bonfireallsecond))
	;;
	"P106") 
		P106Number=$(($P106Number+1))
		P106allInfernosecond=$(($P106allInfernosecond+$Infernoallsecond))
		P106allBonfiresecond=$(($P106allBonfiresecond+$Bonfireallsecond))
	;;
	"P107") 
		P107Number=$(($P107Number+1))
		P107allInfernosecond=$(($P107allInfernosecond+$Infernoallsecond))
		P107allBonfiresecond=$(($P107allBonfiresecond+$Bonfireallsecond))
	;;
	*)
		echo "ERROR!"
	;;
	esac
}


if [ $# -lt 1 ]
then	
	read -p "Please input the path of alllog:" alllogpath
else
	alllogpath=$1
fi
alllogpath=`echo $alllogpath | tr -d "'"`

if [ ! -d "$alllogpath" ]
then
	echo "The first parameter should be the logpath!"
	exit 1
fi
	
RESULT="SN,CONFIG,INFERNO TIME,BONFIRE TIME"
bonfirePath=`find "$alllogpath" -name Bonfire | sort -r`

parameter="$@"
OLDIFS=$IFS
parameter_t=`echo $parameter | grep '\-t'`
parameter_I=`echo $parameter | grep '\-I'`
parameter_B=`echo $parameter | grep '\-B'`


if [ "$parameter_t" != "" ]
then
	while [ "$1" != "-t" ]
	do
		shift
	done
	
	starttime=$2
	endtime=$3
	
	starttime=`date -j -f "%Y-%m-%d_%H:%M:%S" "$starttime" +%s 2> /dev/null`	
	while [ $? -ne 0 ] 
	do
		read -p "Please input the correct starttime(such as 2012-04-25 02:23:00):" starttime
		starttime=`date -j -f "%Y-%m-%d_%H:%M:%S" "$starttime" +%s 2> /dev/null`
	done
	
	endtime=`date -j -f "%Y-%m-%d_%H:%M:%S" "$endtime" +%s 2> /dev/null`
	while [ $? -ne 0 ] 
	do
		read -p "Please input the correct endtime(such as 2012-04-25 02:23:00):" endtime
		endtime=`date -j -f "%Y-%m-%d_%H:%M:%S" "$endtime" +%s 2> /dev/null`
	done
	
	IFS="
	"
	for path in ${bonfirePath}
	do
		logPath=`dirname "$path"`
#		foldertime=`ls -ldT $logPath | awk '{print $9"-"$6"-"$7"_"$8}'`
#		becasue in different env month 5 will be May that will course error
		foldertime=`stat -lt "%Y-%m-%d_%H:%M:%S" $logPath | cut -d ' ' -f 6`
		foldertime=`date -j -f "%Y-%m-%d_%H:%M:%S" "$foldertime" +%s`
		if [ $foldertime -ge $starttime ] && [ $foldertime -le $endtime ]
		then
			gettime "$logPath"
		fi
	done
	IFS=$OLDIFS
else
	IFS="
	"
	for path in ${bonfirePath}
	do
		logPath=`dirname "$path"`			
		gettime "$logPath"
	done
	IFS=$OLDIFS
fi

if [ "$parameter_I" != "" ]
then
	echo "$RESULT" | sed -n '2,$p' | cut -d ',' -f 3
	exit 0
elif [ "$parameter_B" != "" ]
then
	echo "$RESULT" | sed -n '2,$p' | cut -d ',' -f 4
	exit 0
fi

RESULT=`echo "$RESULT" | sort -t ',' -k 2`

if [ "$P105Number" -gt 0 ]
then
	P105averageInfernosecond=$(($P105allInfernosecond/$P105Number))
	P105averageInfernotime=`getHMS "$P105averageInfernosecond"`
	P105averageBonfiresecond=$(($P105allBonfiresecond/$P105Number))
	P105averageBonfiretime=`getHMS "$P105averageBonfiresecond"`
	RESULT="$RESULT\nAVERAGE,P105,$P105averageInfernotime,$P105averageBonfiretime"
fi

if [ "$P106Number" -gt 0 ]
then 
	P106averageInfernosecond=$(($P106allInfernosecond/$P106Number))
	P106averageInfernotime=`getHMS "$P106averageInfernosecond"`
	P106averageBonfiresecond=$(($P106allBonfiresecond/$P106Number))
	P106averageBonfiretime=`getHMS "$P106averageBonfiresecond"`
	RESULT="$RESULT\nAVERAGE,P106,$P106averageInfernotime,$P106averageBonfiretime"
fi

if [ "$P107Number" -gt 0 ]
then 	
	P107averageInfernosecond=$(($P107allInfernosecond/$P107Number))
	P107averageInfernotime=`getHMS "$P107averageInfernosecond"`
	P107averageBonfiresecond=$(($P107allBonfiresecond/$P107Number))
	P107averageBonfiretime=`getHMS "$P107averageBonfiresecond"`
	RESULT="$RESULT\nAVERAGE,P107,$P107averageInfernotime,$P107averageBonfiretime"
fi

echo "$RESULT"
exit 0

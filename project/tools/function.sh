#!/bin/sh

# function.sh

if [ -z "$ENV_VARIABLE_HEADER" ];then
    exit 1
fi



function parseSmokeyFailure
{
    local smokeyResults=$1
    local testName=$2   
    local superTestName=$3
    local prefix=$4
    local line
    local limitFailOrNot
    local efiFailOrNot
    local efiFailFlag="EfiCommand: command had errors:"
    local efiFailedCommand
    local limitFailFlag="failed limits"
    local newFormat=""
    if [ -n "$prefix" ];then
        prefix="$prefix ";#add a blank
    fi
    if [ -n "$superTestName" ];then
        superTestName="$superTestName ";#add a blank
    fi
    if [ -n "$testName" -a -n "$smokeyResults" ];then
        testNameResult=`echo "$smokeyResults" | grep -a "SmokeyResults:.* $testName "`
        if [ -n "$testNameResult" ];then
            while read line
            do
                limitFailOrNot=`echo "$line" | grep -a "$limitFailFlag"`
                efiFailOrNot=`echo "$line" | grep -a "$efiFailFlag"`
                if [ "$limitFailOrNot" != "" ];then
                    newFormat="$prefix$superTestName$testName - limit fail"
                elif [ "$efiFailOrNot" != "" ];then
                    efiFailedCommand=${line##*: }
                    newFormat="$prefix$superTestName$testName($efiFailedCommand) - EfiCommand fail"
                else
                    newFormat="$prefix$superTestName$testName"
                fi
                echo "$newFormat"
            done <<< "$testNameResult"
        fi
    fi
}

function foundSmokeyResultString
{
    local smokeyLogPath=$1
    cat "$smokeyLogPath" | sed -n '/All errors:/,/Rebooting/p'
}

function judgeWildfilreTest
{
    local returnCode=1;#1 means fail
    local testName=$1
    local smokeyLogPath=$2
    if [ -n "$testName" -a -e "$smokeyLogPath" ];then
        grep -a -q "^\[.*\.\.\.\. \t\t\[1] $testName" "$smokeyLogPath" > /dev/null 2>&1
        returnCode=$?
    fi
    return $returnCode
}

#now the same as judgeWildfilreTest
function judgeAgniTest
{
    local returnCode=1;#1 means fail
    local testName=$1
    local smokeyLogPath=$2
    if [ -n "$testName" -a -e "$smokeyLogPath" ];then
        grep -a -q "^\[.*\.\.\.\. \t\t\[1] $testName" "$smokeyLogPath" > /dev/null 2>&1
        returnCode=$?
    fi
    return $returnCode
}

function parseBurninFailure
{
    local failure
    local finalColumn
    local testName
    local subTestName
    local pdcaKey
    local errorCode
    local reason
    local wildfireJudge
    local agniJudge
    local newFormat
    local rawFailures=`cat "$summaryPath" | grep -v "^#" | grep -v "^IGNORE" | grep -v "^PASS" | grep -v "^$" | awk -F, '{OFS=",";print $4,$10,$NF,$2}' | sort -u`
    if [ -n "$rawFailures" ];then
        while read failure
        do
            testName=`echo $failure | cut -d "," -f1`;
            errorCode=`echo $failure | cut -d "," -f2`;
            finalColumn=`echo $failure | cut -d "," -f3`;
            pdcaKey=`echo $failure | cut -d "," -f4`;
            wildfireJudge=`judgeWildfilreTest "$testName" "$smokeyPath"`
            wildfireJudge=$?
            agniJudge=`judgeAgniTest "$testName" "$agniSmokeyPath"`
            agniJudge=$?
            #echo "$testName wildfire:$wildfireJudge agni:$agniJudge"
            if [ $wildfireJudge -eq 0 ];then
                #wildfire failure item
                smokeyResultString=`foundSmokeyResultString "$smokeyPath"`
                parseSmokeyFailure "$smokeyResultString" "$testName" "" "WILDFIRE"
            elif [ $agniJudge -eq 0 ];then
                #agni failure item
                subTestName=`echo "$pdcaKey" | cut -d '/' -f 3`
                if [ -n "$subTestName" ];then
                    smokeyResultString=`foundSmokeyResultString "$agniSmokeyPath"`
                    parseSmokeyFailure "$smokeyResultString" "$subTestName" "$testName" "Agni"
                else
                    smokeyResultString=`foundSmokeyResultString "$agniSmokeyPath"`
                    parseSmokeyFailure "$smokeyResultString" "$testName" "" "Agni"
                fi
            elif [ "$testName" = "WakeOnWiFi" ];then
                #WakeOnWifi
                line=`grep -a -n "Earthbound: $finalColumn" $logtxtPath | cut -d ':' -f1`
                reason=`head -$line $logtxtPath | grep -a -w "Wake reason:" | tail -1 | cut -d ':' -f2 | sed 's/\ //g'`
                newFormat="$testName $errorCode - $reason"
                echo "$newFormat"
            else
                newFormat="$testName $errorCode"
                echo "$newFormat"
            fi
        done <<< "$rawFailures"
    fi
}
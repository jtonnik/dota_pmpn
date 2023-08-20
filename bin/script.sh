#!/bin/bash

player_id=(83480096 128254692)
player_nick=("FatBoyJ" "SlimL")
player_amount=${#player_id[@]}
#Seconds per Day
SPD=86400
weekdays=(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)
#Different types of activites (new var for doubled activities)
declare -A type_act
type_act["PushUps"]=0
type_act["SitUps"]=1
type_act["Lunges"]=2
type_act["RowingReps"]=3
type_act["Curls"]=4
type_act["LateralLifts"]=5
#Activity mapping to weekday
activity=("PushUps" "Lunges" "LateralLifts" "RowingReps" "PushUps" "SitUps" "Curls") #Activities Monday through Sunday
multiplier_FatBoyJ=(3 3 3 3 3 3 3) #Activities multiplier per death Monday through Sunday
multiplier_SlimL=(3 3 3 3 3 4 3) #Activities multiplier per death Monday through Sunday

#Reset stat document
truncate --size 0 "status.txt"

for ((players = 0; players < $player_amount; players++)); do
    # Query matches from API, after beginning of pmpn -> Output two coloumns - UNIX Start Timestamp & Amount of Deaths
    curl -s https://api.opendota.com/api/players/${player_id[players]}/matches | jq '.[] | select(.start_time > 1691696862) | "\(.start_time) \(.deaths)"' > stats_${player_nick[players]}.json

    #(Re)set variable counts
    record_day=(0 0 0 0 0 0 0) #Records by activities Monday through Sunday
    record_act=(0 0 0 0 0 0) #Records by activities overarching
    sum_day=(0 0 0 0 0 0 0) #Sum of activities Monday through Sunday
    sum_act=(0 0 0 0 0 0) #Sum of activities overarching

    # Introduce & empty temp file to modify data
    tempfile="temp_${player_nick[players]}.json"
    truncate --size 0 "$tempfile"

    # Empty line for readability
    if [ "$players" -ne "0" ]; then
        echo "" >> status.txt
    fi
            
    # Loop receiving input file of API call, splitting (existing) two coloumn API output into respective variables that were queried. Timestamp is converted and mapped to physical acitivies in the process
    while IFS=" " read -r timestamp deaths; do
        # UNIX Timestamp -> Weekday

        # remove " from values
        timestamp="${timestamp//'"'}"
        deaths="${deaths//'"'}"
        unix_timestamp=$timestamp

        #Convert Time Stamp from seconds to days (rounding down)
        let timestamp=$timestamp/$SPD

        #Calculate rest of the Division of the UNIX Timestamp - Offset by 3 to map array variables starting on Monday
        rest=$(((timestamp + 3) % 7))
        
        # Split date into readable formats
        date_whole=$(date -d "@$unix_timestamp" '+%Y-%m-%d')
        date_year=$(date -d "@$unix_timestamp" '+%Y')
        date_month=$(date -d "@$unix_timestamp" '+%m')
        date_day=$(date -d "@$unix_timestamp" '+%d')

        # Fill temp file with readable data
        echo $date_whole $date_year $date_month $date_day ${weekdays[rest]} ${activity[rest]} $((deaths * multiplier_${player_nick[players]}[$rest])) >> $tempfile

        #Sum up all activities, depending on the weekday. Update record.
        for day in {0..6}; do
            if [ "$day" -eq $rest ]; then
            sum_day[$day]=$((sum_day[$day] + deaths * multiplier_${player_nick[players]}[$day]))
            fi
        done

        #if [ "${sum_day[day]}" >"${record_day[day]}" ]; then
            #    record_day[$day]=${sum_day[day]}
            #    echo record for $day = ${record_day[day]}
        #fi



    done < "stats_${player_nick[players]}.json"

    #Print sum of activities per weekday, exluding 0 values
    echo Sum of ${player_nick[players]}s daily acitivites: >> status.txt
    for day in {0..6}; do
        if [ "${sum_day[day]}" -ne "0" ]; then
            echo ${player_nick[players]} has already done ${sum_day[day]} ${activity[day]} by relentlessly feeding in DotA on ${weekdays[day]}s! >> status.txt
        fi
    done
    #Sum up all activities, depending on the activity
    for type in "${!type_act[@]}"; do
        for day in {0..6}; do
            if [ "${activity[day]}" == "$type" ]; then
                index="${type_act["$type"]}"
                sum_act[$index]=$((sum_act[$index] + sum_day[$day]))
            fi
        done
    done
    #Print sum of activities per type, exluding 0 values
    echo Sum of ${player_nick[players]}s acitivity types:  >> status.txt
    for type in "${!type_act[@]}"; do
        index="${type_act["$type"]}"
        if [ "${sum_act[index]}" -ne "0" ]; then
            echo ${player_nick[players]} has overall already done ${sum_act[index]} $type by relentlessly feeding in DotA! >> status.txt
        fi
    done

    date_list=()
    sum_date_list=()
    act_date_list=()
    while IFS=" " read -r date_whole date_year date_month date_day weekday_type count_act; do
        if [[ ! " ${date_list[@]} " =~ " ${date_whole} " ]]; then
            date_list+=("$date_whole") # Add the new value to the array
        fi
    done < "temp_${player_nick[players]}.json"

    for date in "${date_list[@]}"; do
        sum_date=0
        while IFS=" " read -r date_whole date_year date_month date_day weekday_type act_type count_act; do
            if [ "$date" == "$date_whole" ]; then
                act_date=$act_type
                sum_date=$((sum_date + count_act))
            fi
        done < "temp_${player_nick[players]}.json"
        sum_date_list+=("$sum_date") # Add the new value to the array
        act_date_list+=("$act_date") # Add the new value to the array
    done

    #Determine daily record for each category
    days_amount=${#date_list[@]}
    for act in "${!type_act[@]}"; do
        index="${type_act["$act"]}"
        for ((i = 0; i < $days_amount; i++)); do
            if [ "${act_date_list[i]}" == "$act" ] && [ "${sum_date_list[i]}" > "${record_act[index]}" ]; then
                record_act[$index]=${sum_date_list[i]}
            fi
        done
    done

    #Print daily record for each category
    echo ${player_nick[players]}s records: >> status.txt
    for act in "${!type_act[@]}"; do
        index="${type_act["$act"]}"
        if [ "${record_act[index]}" -gt "0" ]; then
            echo ${player_nick[players]}s record for $act in a day by relentlessly feeding in DotA is ${record_act[index]}! >> status.txt
        fi
    done



done


######################################
######## Future ideas to add #########
######################################
# - Records for each activity        # - Done
# - Data usable for statistics       # - Done
#   - Per week                       # - Done
#   - Per month                      # - Done
#   - Per activity                   # - Done
# - Diagrams                         #
#   - Per week                       #
#   - Per month                      #
#   - Per activity                   #
# - Website                          #
# - Application for popup after game #
######################################
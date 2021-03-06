# author: David Fager s185120
#!/bin/zsh


# Ensuring the user has setup their darknet correctly
echo "Before continuing, please make sure that you have done the following:"
echo "Necessary steps:"
echo " - Compiled (with 'make') the darknet project with gpu=1, cudnn=1 and opencv=0"
echo " - Backed up any important files in your darknet directory"
echo " - Have downloaded and unzipped the test-files and test-images files into the darknet directory."
echo "   Link: https://drive.google.com/file/d/1jrqQi3YgKfDs7x58z_3cxXpseI7dJgDM/view"

echo "Recommended steps:"
echo " - Placed this project in the same directory as darknet, so they share the same directory"
echo " - Got your own weights or images? Then add them to the test-files or test-images folder, with"
echo "   a .txt file describing contents or the .cfg file. Exactly like the other files in the folders."
echo ""

while [[ true ]]; do
    echo "Continue?"
    echo "(y/n)"
    read answer
    echo ""
    if [ "${answer}" = "y" ]; then
        break
    elif [ "${answer}" = "n" ]; then
        echo "Ok bye."
        exit
    fi
    echo "Unrecognized input."
done


absolute_path=""

# Looking for the darknet outside the current directory
# If no success then it asks the user for the directory path
if [ -d "../darknet" ]; then
    absolute_path="../darknet" && \
    echo "Found the darknet folder outside the current directory."
else
    echo "This project does not share directory with darknet."
    while [[ true ]]; do
        echo "Please specify the absolute path to darknet:"
        read absolute_path
        echo ""

        if [ "$(basename ${absolute_path})" = "darknet" ]; then
            [ -d ${absolute_path} ] && \
            echo "Looks like darknet alright." && break

            echo "Unable to change directory to the specified path. Try again."
            continue
        fi

        echo "The basename of the given directory was not 'darknet'."
        echo "Are you sure this is darknet?"
        echo "(y/n)"
        read answer
        echo ""

        [ "${answer}" = "y" ] && break

        echo "The darknet directory needs to be specified."
    done
fi


# This became impossible because GitHub has file size limits on uploads
# Unzipping test material if folders are non-existent
#echo "Unzipping test-files.zip"
#[ ! -d "${absolute_path}/test-files" ] && cp test-files.zip ${absolute_path} \
#&& unzip -q ${absolute_path}/test-files.zip -d ${absolute_path} \
#&& rm -rf ${absolute_path}/test-files.zip

#echo "Unzipping test-images.zip"
#[ ! -d "${absolute_path}/test-images" ] && cp test-images.zip ${absolute_path} \
#&& unzip -q ${absolute_path}/test-images.zip -d ${absolute_path} && \
#rm -rf ${absolute_path}/test-images.zip


# Entering the darknet directory
echo "" && cd ${absolute_path} && echo "Entered the darknet directory. ($( pwd )))"


# Reading the unique names of the contents in the test-images and test-files folders, then makes
# an array of those names. This ensures that the user can add weights and images themselves.
cd test-files && find . -name '*.weights' | cut -d "." -f 2 | cut -d "/" -f 2 \
| sort > 0contents.txt && cd ..
files=()
while IFS= read -r line; do
    files+=("$line")
done < test-files/0contents.txt
echo "Loaded array: ${files[*]}"

cd test-images && (find . -name '*.png' && find . -name '*.jpg') \
| cut -d "." -f 2 | cut -d "/" -f 2 | sort > 0contents.txt && cd ..
images=()
while IFS= read -r line; do
   images+=("$line")
done < test-images/0contents.txt
echo "Loaded array: ${images[*]}"


# Make or remake the test-output directory
[ -d "test-output" ] && rm -rf test-output
mkdir test-output && echo "Created a test-output directory."


path_collected_results="analysis-collected-results.out"
echo "---------- collected analysis results ----------" > ${path_collected_results}

path_temp_sorted_actual="test-output/temp_sorted_actual.txt"
path_temp_sorted_detected="test-output/temp_sorted_detected.txt"


# Warm up the darknet detector
echo "Running a darknet warmup ..."
./darknet detector test cfg/owndata.data test-files/v3-retrained.cfg \
test-files/v3-retrained.weights test-images/overlaying-clubs-diamonds.png


# Data analysis loop, goes through each image for each weights file
for weight_name in ${files[*]}; do
    # Each weights file's results initialisation
    darknet_exec_time=0.0
    avg_percent=0.0

    number_of_cards=0
    possible_detections=0
    hits=0
    guesses=0
    misses=0
    ignored=0


    # The paths of existing files and result saving destination
    path_file_cfg="test-files/${weight_name}.cfg"
	path_file_weights="test-files/${weight_name}.weights"
	path_result_percentages="test-output/${weight_name}-percents.txt"


    # Looping through each image for the current weights file
    for image_name in ${images[*]}; do

        # Path of image and results destinations
        path_image=""
        if [ -e "test-images/${image_name}.png" ]; then
            path_image="test-images/${image_name}.png"
        elif [ -e "test-images/${image_name}.jpg" ]; then
            path_image="test-images/${image_name}.jpg"
        else
            echo "Error finding the image path. Exiting." && exit
        fi

        path_image_txt="test-images/${image_name}.txt"
        path_result_full="test-output/${weight_name}-${image_name}.out"
        path_result_cards="test-output/${weight_name}-${image_name}-cards.txt"


        echo "" && echo "performing analysis with '${weight_name}' on '${image_name}' (${path_image})"

        # Darknet performing its detection and saving the output
        start_time=$(date +%s.%N)
        ./darknet detector test cfg/owndata.data ${path_file_cfg} \
        ${path_file_weights} ${path_image} > ${path_result_full}
        end_time=$(date +%s.%N)
        echo "execution time $(( ${end_time} - ${start_time} )) seconds"
        darknet_exec_time=$(( ${darknet_exec_time} + (${end_time} - ${start_time}) ))


        # Taking the output and trimming it to the percentage integer
        # and appending it to a percentage file
		cat ${path_result_full} | cut -d " " -f 2 | cut -d "%" -f 1 | sed '1d' \
        >> ${path_result_percentages}

        # Trimming output to only consist of the card values and suits
        cat ${path_result_full} | cut -d " " -f 1 | cut -d ":" -f 1 | sed '1d' \
        >> ${path_result_cards}


        # Find how many detections should have occured at max
        possible_detections=$(( $possible_detections + \
        $(cat ${path_image_txt} | wc -l) ))

        # Find how many correct guesses it had and how many wrong
        guesses=$(( ${guesses} + $(cat ${path_result_cards} | wc -l) ))
        sort ${path_image_txt} | uniq > ${path_temp_sorted_actual}
        sort ${path_result_cards} | uniq > ${path_temp_sorted_detected}

        while read possible; do
            hits=$(( ${hits} + $(cat ${path_result_cards} | grep ${possible} | wc -l) ))
            sed -i "/${possible}/d" ${path_result_cards}
        done < ${path_temp_sorted_actual}
        misses=$(( ${misses} + $(cat ${path_result_cards} | wc -l) ))

        number_of_cards=$(( ${number_of_cards} + $(cat ${path_temp_sorted_actual} | wc -l) ))
        while read detection; do
            sed -i "/${detection}/d" ${path_temp_sorted_actual}
        done < ${path_temp_sorted_detected}
        ignored=$(( ${ignored} + $(cat ${path_temp_sorted_actual} | wc -l) ))

        rm ${path_temp_sorted_actual}
        rm ${path_temp_sorted_detected}


        # Print the collective hits as of this image
        twodecimals=$(printf '%.2f' \
        "$((${hits}.0/${possible_detections}.0*100.0))") \
        && echo \
        "correct detections ${hits}/${possible_detections} (~ ${twodecimals}%)"

        # Print the collective misses as of this image
        twodecimals=$(printf '%.2f' \
        "$((${misses}.0/${guesses}.0*100.0))") \
        && echo \
        "impossible detections ${misses}/${guesses} (~ ${twodecimals}%)"

        # Print the collective ignored as of this image
        twodecimals=$(printf '%.2f' \
        "$((${ignored}.0/${number_of_cards}.0*100.0))") \
        && echo \
        "ignored cards ${ignored}/${number_of_cards} (~ ${twodecimals}%)"
    done

    echo "${weight_name} results:" >> ${path_collected_results}

    # Saving the average execution time of darknet
    twodecimals=$( printf '%.2f' "$((${darknet_exec_time} / ${#images[@]}))" ) \
    && echo -e "darknet execution time ..... ${twodecimals}s" \
    >> ${path_collected_results}


    # Goes through the whole percentage file for the current weights file,
    # calculates the average percentage and appends it to the percentage file
	while read percentage; do
        avg_percent=$(( $avg_percent + $percentage ))
    done < ${path_result_percentages}
    avg_percent=$(( $avg_percent / $(cat ${path_result_percentages} | wc -l) ))

    twodecimals=$(printf '%.2f' "${avg_percent}") \
    && echo -e "average detection percentage ${twodecimals}%" \
    >> ${path_collected_results}


    # Save information of hits with all images processed
    twodecimals=$(printf '%.2f' \
    "$((${hits}.0/${possible_detections}.0*100.0))") \
    && echo -e \
    "correct detections ......... ${hits}/${possible_detections} (~ ${twodecimals}%)" \
    >> ${path_collected_results}

    # Save information of misses with all images processed
    twodecimals=$(printf '%.2f' \
    "$((${misses}.0/${guesses}.0*100.0))") \
    && echo -e \
    "impossible detections ...... ${misses}/${guesses} (~ ${twodecimals}%)" \
    >> ${path_collected_results}

    # Save information of ignored cards with all images processed
    twodecimals=$(printf '%.2f' \
    "$((${ignored}.0/${number_of_cards}.0*100.0))") \
    && echo -e \
    "ignored cards .............. ${ignored}/${number_of_cards} (~ ${twodecimals}%)" \
    >> ${path_collected_results}


    echo "-" >> ${path_collected_results}
done

# Printing everything in the collected results txt file
clear
cat ${path_collected_results}

echo "How to read output:" >> ${path_collected_results}
echo "darknet execution time .....: time in seconds for darknet to run its detection" \
>> ${path_collected_results}
echo "average detection percentage: darknets average detection percent for each card" \
>> ${path_collected_results}
echo "correct detections .........: total corners detected with correct suit and value / total corners visible" \
>> ${path_collected_results}
echo "impossible detections ......: total corners detected with a wrong suit / total corners detected" \
>> ${path_collected_results}
echo "ignored cards ..............: total cards without any detected corner / total cards visible" \
>> ${path_collected_results}
echo "NOTE: as the included models where only trained on the diagonal corners, then a correct detections score of around 50% is optimal." \
>> ${path_collected_results}
echo "All corners were counted because detections of the corners not on the diagonal is occasional." \
>> ${path_collected_results}
echo "" >> ${path_collected_results}

while [[ true ]]; do
    echo "Would you like information on how to read the output?"
    echo "(y/n)"
    read answer
    if [ "${answer}" = "y" ]; then
        tail -7 ${path_collected_results}
        break
    elif [ "${answer}" = "n" ]; then
        break
    fi
    echo "Unrecognized input."
done

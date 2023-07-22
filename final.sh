#!/bin/bash
function display_content() {
    local path="$path"
    local current_dir=$(basename "$path")
    echo "Current Directory: $current_path"
    echo "------------------------------------------------"
    local items=()
    while IFS= read -r -d $'\0' item; do
        items+=("$item")
    done < <(find "$path" -maxdepth 1 -mindepth 1 -print0)

    if [ -f "$current_path" ]; then
        echo "The path '$path' belongs to a file."
        PS3="Selected a Wrong file? Enter '0' to go back:"
        select item in "${items[@]}"; do
                if [[ "$REPLY" -eq 0 ]]; then
                        delimiter="/"
                        current_path="${current_path%$delimiter*}"
                        return
                else
                        echo "Invalid Choice. Try Again."
                fi
        done
    else
        PS3="Select a directory or file (Enter '0' to go back): "
        select item in "${items[@]}"; do
            if [[ "$REPLY" -eq 0 ]]; then
               cd ..
               current_path=$(pwd)
               return
            elif [[ -n "$item" ]]; then
                if [[ -d "$item" ]]; then
                   cd "$item"
                   current_path=$(pwd)
                 elif [[ -f "$item" ]]; then
                    echo "You selected file: $item"
                    modified_string="${item#?}"
                    current_path="$current_path$modified_string"
                 else
                    echo "Invalid choice. Try again."
                  fi
                return
            else
                echo "Invalid choice. Try again."
            fi
        done
    fi
}
function get_directory(){
        path="."
	current_path=$(pwd)
        while true; do
		echo -e "\nCurrent Directory:- $current_path"
                echo "Do you want to continue selecting directories or files? (y/n): "
                read -r continue_selection

                case "$continue_selection" in
                        [Nn]*)
                                echo "Exiting..."
                                 break
                                 ;;
                         *)
                                 echo
                                 ;;
                esac
                display_content "$path" "$current_path"
        done

}
display_disks() {
    df -h | awk 'NR>1 {print $1}'
}

select_disk() {
    local disk=""
    PS3="Select a disk number: "
    select disk_name in $(display_disks); do
        if [[ -n "$disk_name" ]]; then
            disk="$disk_name"
            break
        else
            echo "Invalid choice. Try again."
        fi
    done
    echo "$disk"
}

show_available_space() {
    local disk="$1"
    df -h "$disk" | awk 'NR==2 {print "Available space on", $1, ":", $4}'
}

show_space_utilized() {
    local disk="$1"
    df -h "$disk" | awk 'NR==2 {print "Space utilized on", $1, ":", $3}'
}

display_available_disk_space(){
	echo -e "\n\n--------------------------------------------"
	selected_disk=$(select_disk)
	if [[ -n "$selected_disk" ]]; then
    		show_available_space "$selected_disk"
	else
    		echo "No disk selected."
	fi
	echo -e "--------------------------------------------\n\n"
}

display_space_utilized(){
	echo -e "\n\n--------------------------------------------"
	selected_disk=$(select_disk)
	if [[ -n "$selected_disk" ]]; then
    		show_space_utilized "$selected_disk"
	else
    		echo "No disk selected."
	fi
	echo -e "--------------------------------------------\n\n"
}

get_file_type() {
    local file="$1"
    local extension="${file##*.}"

    case "$extension" in
        jpg|jpeg|png|gif)
            echo "Images"
            ;;
        mp4|avi|mkv|mov)
            echo "Videos"
            ;;
        mp3|wav|flac|ogg)
            echo "Audios"
            ;;
        pdf|doc|docx|txt|xls|xlsx|ppt|pptx)
            echo "Documents"
            ;;
        apk)
            echo "Apks"
            ;;
        *)
            echo "Other"
            ;;
    esac
}
display_space_used_by_file_types() {
    echo -e "\n\nSelect the directory path for which you want the report" 
    get_directory
    search_dir="$current_path"
    echo -e "\n\n------------------------------------------------------"
    echo -e "Selected Directory:- $current_path \n\n"

    if [[ ! -d "$search_dir" ]]; then
        echo "Error: The specified directory '$search_dir' does not exist."
        exit 1
    fi

    # Find all files and pass the list to 'du' for size calculation
    all_files=$(find "$search_dir" -type f)
    declare -A file_types   # Associative array to store file types and their corresponding space usage
    total_space_used=0

    for file in $all_files; do
        file_type=$(get_file_type "$file")
        size=$(du -b "$file" | cut -f1)
        total_space_used=$((total_space_used + size))

        # Update space used for the specific file type in the array
        if [[ -z ${file_types[$file_type]} ]]; then
            file_types[$file_type]=$size
        else
            file_types[$file_type]=$((file_types[$file_type] + size))
        fi
    done

    # Convert total space used to human-readable format
    total_space_used_hr=$(numfmt --to=iec $total_space_used)

    # Display space used by different file types
    echo "Total space used in '$search_dir': $total_space_used_hr"
    for type in "${!file_types[@]}"; do
        size_hr=$(numfmt --to=iec ${file_types[$type]})
        echo "$type: $size_hr"
    done
    echo -e "------------------------------------------------\n\n"
}

detect_duplicate_files() {
    echo -e "\n\nSelect the Path of directory where you want to find duplicate files:-"
    get_directory
    search_dir="$current_path"
    echo -e "\n\n------------------------------------------------------"
    echo -e "Selected Directory:- $current_path \n\n"
    declare -A file_hashes

    if [[ ! -d "$search_dir" ]]; then
        echo "Error: The specified directory '$search_dir' does not exist."
        exit 1
    fi
    flag=0
    while IFS= read -rd '' file; do
        if [[ -f "$file" ]]; then
            # Calculate the MD5 hash of the file
            hash=$(md5sum "$file" | awk '{print $1}')

            # Check if the hash already exists in the associative array (duplicate)
            if [[ -n ${file_hashes[$hash]} ]]; then
		flag=1
                echo "Duplicate found:"
                echo "  Original: ${file_hashes[$hash]}"
                echo "  Duplicate: $file"
                echo
            else
                file_hashes[$hash]="$file"
            fi
        fi
    done < <(find "$search_dir" -type f -print0)
    if [[ $flag -eq 0 ]]
    then
	    echo "No Duplicates Found inside the directory"
    fi
    echo -e "------------------------------------------------------\n\n"
}

identify_large_files() {
	
    echo -e "\n\nSelect the directory where to want to search the large files:"
    get_directory
    search_dir="$current_path"
    echo -e "\n\n------------------------------------------------------"
    echo -e "Selected Directory:- $current_path \n\n"

    echo "Enter the threshold size for large files in MB(Enter '-1' if you want to use standard threshold i.e., 4M)"
    read threshold_size
    if [[ $threshold_size -eq -1 ]]
    then
	    threshold_size=4
    fi
    threshold_store=$threshold_size
    threshold_size=$((threshold_size * 1024 * 1024))
    if [[ ! -d "$search_dir" ]]; then
        echo "Error: The specified directory '$search_dir' does not exist."
        exit 1
    fi

    # Find large files and pass the list to 'du' for size calculation
    large_files=$(find "$search_dir" -type f -size +"$threshold_size"c)
    total_large_files=$(echo "$large_files" | wc -l)

    if [[ "$total_large_files" -eq 0 ]]; then
        echo "No large files found in '$search_dir' above ${threshold_store} MB."
    else
        echo "Large files in '$search_dir' above ${threshold_store} MB:"
        echo "$large_files"
        echo -e "------------------------------------------------------\n\n"
    fi
}

identify_large_files_by_type() {
    echo -e "\n\nSelect the directory where to want to search the large files:"
    get_directory
    search_dir="$current_path"
    echo -e "\n\n------------------------------------------------------"
    echo -e "Selected Directory:- $current_path \n\n"

    echo "Enter the threshold size for large files in MB(Enter '-1' if you want to use standard threshold i.e., 4M)"
    read threshold_size
    if [[ $threshold_size -eq -1 ]]
    then
            threshold_size=4
    fi
    threshold_store=$threshold_size
    threshold_size=$((threshold_size * 1024 * 1024))
    # Display the menu and read the user's choices for file types
    display_menu
    read -r choices

    # Process the user's choices to determine the corresponding file types
    file_types=""
    for choice in $choices; do
        case "$choice" in
            1)
                file_types+="jpg jpeg png gif "
                ;;
            2)
                file_types+="mp4 avi mkv mov "
                ;;
            3)
                file_types+="mp3 wav flac ogg "
                ;;
            4)
                file_types+="pdf doc docx txt xls xlsx ppt pptx "
                ;;
            5)
                file_types+="! -regex '.*\.\(jpg\|jpeg\|png\|gif\|mp4\|avi\|mkv\|mov\|mp3\|wav\|flac\|ogg\|pdf\|doc\|docx\|txt\|xls\|xlsx\|ppt\|pptx\)' "
                ;;
            *)
                echo "Invalid choice. Skipping unrecognized option: $choice"
                ;;
       esac
    done


    if [[ ! -d "$search_dir" ]]; then
        echo "Error: The specified directory '$search_dir' does not exist."
        exit 1
    fi

    # Declare associative arrays to store files based on their types
    declare -A large_files_by_type
    declare -A file_types_map

    # Initialize arrays for each file type
    for type in $file_types; do
        large_files_by_type[$type]=""
        file_types_map[$type]=$(get_file_type "$type")
    done

    # Find large files for each specified file type and pass the list to 'du' for size calculation
    for type in $file_types; do
        large_files=$(find "$search_dir" -type f -iname "*.$type" -size +"$threshold_size"c)
        total_large_files=$(echo "$large_files" | wc -l)

        if [[ "$total_large_files" -gt 0 ]]; then
            large_files_by_type[$type]+="$large_files"$'\n'
        fi
    done

    # Display large files for each file type that has large files
    for type in $file_types; do
        files=${large_files_by_type[$type]}
        len=${#files}
        if [[ $len != 1 ]]; then
            echo "Large ${file_types_map[$type]} in '$search_dir' above ${threshold_store} MB:"
            echo "$files"
            echo -e "------------------------------------------------------\n\n"
            echo
        fi
    done
}

display_menu() {
    echo "Select the file types (separated by space):"
    echo "1. Images"
    echo "2. Videos"
    echo "3. Audios"
    echo "4. Documents"
    echo "5. Others"
    echo "Enter your choices (e.g., 1 3 5): "
}


identify_files_by_type() {
    echo -e "\n\nSelect the directory where to want to scan the files:"
    get_directory
    search_dir="$current_path"
    echo -e "\n\n------------------------------------------------------"
    echo -e "Selected Directory:- $current_path \n\n"

    # Display the menu and read the user's choices for file types
    display_menu
    read -r choices

    # Process the user's choices to determine the corresponding file types
    file_types=""
    for choice in $choices; do
        case "$choice" in
            1)
                file_types+="jpg jpeg png gif "
                ;;
            2)
                file_types+="mp4 avi mkv mov "
                ;;
            3)
                file_types+="mp3 wav flac ogg "
                ;;
            4)
                file_types+="pdf doc docx txt xls xlsx ppt pptx "
                ;;
            5)
                file_types+="! -regex '.*\.\(jpg\|jpeg\|png\|gif\|mp4\|avi\|mkv\|mov\|mp3\|wav\|flac\|ogg\|pdf\|doc\|docx\|txt\|xls\|xlsx\|ppt\|pptx\)' "
                ;;
            *)
                echo "Invalid choice. Skipping unrecognized option: $choice"
                ;;
       esac
    done

    if [[ ! -d "$search_dir" ]]; then
        echo "Error: The specified directory '$search_dir' does not exist."
        exit 1
    fi

    # Declare associative arrays to store files based on their types
    declare -A files_by_type
    declare -A file_types_map

    # Initialize arrays for each file type
    for type in $file_types; do
        files_by_type[$type]=""
        file_types_map[$type]=$(get_file_type "$type")
    done

    # Find all files for each specified file type and store the list in the arrays
    for type in $file_types; do
        files=$(find "$search_dir" -type f -iname "*.$type")
        if [[ -n "$files" ]]; then
            files_by_type[$type]+="$files"$'\n'
        fi
    done

    # Display all files for each file type that has files
    for type in $file_types; do
        files=${files_by_type[$type]}
        if [[ -n "$files" ]]; then
            echo "$(get_file_type "$type") files in '$search_dir':"
            echo "$files"
            echo
            echo -e "------------------------------------------------------\n\n"
        fi
    done

}

delete_files_and_folders() {
    echo "\n\nSelect the file or directory path to delete: "
    get_directory
    search_dir="$current_path"
    echo -e "\n\n------------------------------------------------------"
    echo -e "Selected Directory:- $current_path \n\n"

    
    if test -f "$search_dir"; then
            read -p "Are you sure you want to delete this file ?(Y/N):" confirm
            if [[ "$confirm" != "Y" && "$confirm" != "y" ]]; then
                    echo "Deletion canceled."
                    exit 0
            fi
            rm "$search_dir"
            echo "File deleted Successfully"
    elif test -d "$search_dir"; then
            read -p "Are you sure you want to delete all files and folders in '$search_dir'? (Y/N): " confirm
            if [[ "$confirm" != "Y" && "$confirm" != "y" ]]; then
                    echo "Deletion canceled."
                    exit 0
            fi
            # Delete directories
            rm -r "$search_dir"
            echo "All files and folders in '$search_dir' have been deleted."
    else
        echo "Error: The specified directory or file '$search_dir' does not exist."
        exit 1
    fi
    echo -e "\n\n------------------------------------------------------"

}

delete_files_by_type() {
    
    echo -e "\n\nSelect directory path to delete: "
    get_directory
    search_dir="$current_path"
    echo -e "\n\n------------------------------------------------------"
    echo -e "Selected Directory:- $current_path \n\n"

    
    # Display the menu and read the user's choices for file types
    display_menu
    read -r choices

   # Process the user's choices to determine the corresponding file types
   file_types=""
   for choice in $choices; do
    case "$choice" in
        1)
            file_types+="jpg jpeg png gif "
            ;;
        2)
            file_types+="mp4 avi mkv mov "
            ;;
        3)
            file_types+="mp3 wav flac ogg "
            ;;
        4)
            file_types+="pdf doc docx txt xls xlsx ppt pptx "
            ;;
        5)
            echo "Enter custom file type(s) (e.g., txt pdf): "
            read -r custom_file_types
            file_types+="$custom_file_types "
            ;;
        *)
            echo "Invalid choice. Skipping unrecognized option: $choice"
            ;;
    esac
   done


    if [[ ! -d "$search_dir" ]]; then
        echo "Error: The specified directory '$search_dir' does not exist."
        exit 1
    fi
    read -p "Are you sure you want to delete all files and folders in '$search_dir'? (Y/N): " confirm
    if [[ "$confirm" != "Y" && "$confirm" != "y" ]]; then
            echo "Deletion canceled."
            exit 0
    fi
    echo "Deleting files of types: $file_types from '$search_dir' and its subdirectories..."

    # Split the file types string into an array
    IFS=' ' read -r -a file_types_array <<< "$file_types"

    # Loop through the array and use find to locate and delete files of each type
    for file_type in "${file_types_array[@]}"; do
        find "$search_dir" -type f -iname "*.$file_type" -exec rm -i {} \;
    done

    echo "Deletion of files of types: $file_types completed."
    echo -e "\n\n------------------------------------------------------"

}


#delete_files_by_type
#identify_files_by_type
#identify_large_files_by_type
#identify_large_files
#detect_duplicate_files
#display_available_disk_space
#display_space_used_by_file_types
#display_space_utilized
function display_main_menu() {
    echo "Menu:"
    echo "1. Display available disk space"
    echo "2. Display space utilized by each directory"
    echo "3. Display space used by file types"
    echo "4. Detect duplicate files"
    echo "5. Identify large files"
    echo "6. Identify files by type"
    echo "7. Delete files and folders"
    echo "8. Delete files by type"
    echo "9. Identify large files by type"
    echo "0. Exit"
    echo "Enter your choice: "
}

while true; do
    display_main_menu
    read -r choice

    case "$choice" in
        1) display_available_disk_space ;;
        2) display_space_utilized ;;
        3) display_space_used_by_file_types ;;
        4) detect_duplicate_files ;;
        5) identify_large_files ;;
        6) identify_files_by_type ;;
        7) delete_files_and_folders ;;
        8) delete_files_by_type ;;
        9) identify_large_files_by_type ;;
        0) echo "Exiting..."; break ;;
        *) echo "Invalid choice. Try again." ;;
    esac

    echo
done

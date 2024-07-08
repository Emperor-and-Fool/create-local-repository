#!/bin/bash

# General functions & global variables
current_directory=$(pwd)  # <----not very functional

# Terminal output user info logic

# Function to center text output
center_text() {
    local text="$1"
    local terminal_width=$(tput cols)
    local text_width=${#text}
    local padding=$(( ($terminal_width + $text_width) / 2 ))
    printf "%*s\n" $padding "$text"
}

# Function to print in green (centered)
print_green() {
    local message="$1"
    center_text "$(echo -e "\e[32m$message\e[0m")"
}

# Function to print in red (centered)
print_red() {
    local message="$1"
    center_text "$(echo -e "\e[31m$message\e[0m")"
}

# Function to print in orange (centered)
print_orange() {
    local message="$1"
    center_text "$(echo -e "\e[38;5;208m$message\e[0m")"
}

# Function to print in blue (centered)
print_blue() {
    local message="$1"
    center_text "$(echo -e "\e[34m$message\e[0m")"
}

# Function to prompt in blue and return user input in green
print_dirpath_blue() {
    local prompt=$1
    echo -e "\e[34m$prompt\e[0m"  # Print the prompt in blue
    read dir_path         # Read the user input and assign it to the reference variable
 #   echo "$user_input"         # Echo the user input to capture it later
    echo -e "\e[35m$dir_path\e[0m"  # Print the user input in yellow
}

# Function to prompt for sudo if needed
run_with_sudo() {
    if [ "$EUID" -ne 0 ]; then
        sudo "$@"
    else
        "$@"
    fi
}



# General script functions
##########################################################################################
# Step 4 update the source list

# Function to update sources.list
update_sources_list() {
    
    print_orange "Updating /etc/apt/sources.list.d/local.list file"
    echo ""
    
    if [ ! -f /etc/apt/sources.list.d/local.list ]; then
        run_with_sudo touch /etc/apt/sources.list.d/local.list
        print_green "/etc/apt/sources.list.d/local.list created."
    else
        print_green "/etc/apt/sources.list.d/local.list already exists."
    fi
    
    cd $dir_path
    echo $(pwd)
    
    print_orange "Updating sources.list with signed-by directive..."
    print_green "deb [Signed-By=$(pwd)/${kerray[0]}.key] file:$(pwd)/ ./"
    echo "deb [Signed-By=$(pwd)/${kerray[0]}.key] file:$(pwd)/ ./" | run_with_sudo tee -a /etc/apt/sources.list.d/local.list >/dev/null

    # Confirm correct signing
    print_blue "Are these the local repositories you inteded to keep?"
    print_green "$(grep -E "\./$" /etc/apt/sources.list.d/local.list)"
    echo ""
    read -p $'\033[34m(y)es, (n)o \033[0m' sign_confirmed

    case "$sign_confirmed" in
        y|Y)
            print_green "Confirmed."
            echo ""
            ;;
        n|N)
            print_blue "For local repository change directory"
            cd $dir_path
            clean_local_source
            echo ""
            exit 0
            ;;
        *)
            print_red "Invalid choice. Try again..."
            ;;
    esac
    
    print_green "Repository "$current_directory" signed and added to update sources. You can now 'sudo apt update' to find you have a local signed repository"
    echo ""
    
    # Optional apt update
    read -p $'\033[34mDo you want to apt update now? (Y)es! (n)o. \033[0m' update_confirmed
    print_green $(grep -E "$search_pattern" /etc/apt/sources.list.d/local.list)

    case "$update_confirmed" in
        y|Y)
            print_orange "...apt updating"
            run_with_sudo apt update
            exit
            ;;
        n|N)
            print_green "Thanks for using my script. It was a great way to learn scripting!"
            exit
            ;;
        *)
            print_red "Invalid choice. Try again..."
            ;;
    esac
    
    
}

clean_local_source() {
    local search_pattern="\./$"
    local sources_list="/etc/apt/sources.list.d/local.list"
    
    echo ""
    print_orange "Time to add your local repository as a Source for apt to find"
    
    # Counter for intended local repositories
    counter=0
    
    # Loop to clean and check previously created local repositories 
    until ! rem_repo=$(grep -E "$search_pattern" /etc/apt/sources.list.d/local.list | tail -n +$counter | head -n 1) || [ -z "$rem_repo" ]; do
        print_blue "Found matching line in sources.list:"
        print_green "$rem_repo"
        echo ""
        echo ""
        
        # Until the cleaning list is empty
        if [[ -n "$rem_repo" ]]; then

            # Prompt user to remove or leave local repositories in place or skip the process
            read -p $'\033[34mDo you want to remove this Repo? (y)es, (n)o, or (s)kip remaining repositories: \033[0m' response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                escaped_line=$(printf '%s\n' "$rem_repo" | sed 's/[][\/$*. -]/\\&/g')
                # to debug incorrect escaped_line uncomment below
                # echo "$escaped_line"
                run_with_sudo sed -i "\%$escaped_line%d" $sources_list
                print_green "Line removed."
            elif [[ "$response" =~ ^[Nn]$ ]]; then
                print_green "Line not removed."
                ((counter++))  # Increment counter for next iteration
                print_orange "Working on line $counter"
            elif [[ "$response" =~ ^[Ss]$ ]]; then
                echo ""
                print_orange "Skipping remaining lines."
                break
            else
                print_red "Invalid response. Please enter y, n, or s (skip)."
            fi
        fi
    done

    print_green "Finished checking for matching lines."
    update_sources_list
    return
}



# Step 4 update the source list 
############################################################################################
# Step 3 Sign repository Release file

# Function to create Release files
sign_release() {

    # Check for the existance of the Release file
    if [ -f "Release" ]; then
            print_green "Release file exists in the current directory. "
        else
            print_red "Release file does not exist. Please run the create-local-repo script first. "
            # exit 1
        fi

    print_orange "Signing Release by creating Release.gpg and InRelease file using key:"; print_green "$key_id"
    echo ""
    
    # Create Release.gpg signed with the specified key-id
    gpg --default-key "$key_id" -b -a -o Release.gpg Release

    # Create InRelease signed with the specified key-id
    gpg --clearsign -u "$key_id" -o InRelease Release

    echo ""
    print_green "Release signatures created successfully. Adding public key to apt key store."
    echo""
    
    # Goto add repository to sources.list
    clean_local_source
    
}



# Step 3 Sign repository Release file
###############################################################################################################
# Part 2 Confirm existing or Create, export and add gpg key-pair

# Function to add GPG key to apt-key store
add_key_to_apt() {
    local key_name="$1"
    print_orange "Adding GPG key $key_id to apt-key store..."
    run_with_sudo apt-key add "${kerray[0]}.key"
    print_green "GPG key added to apt-key store."
    echo ""

    # Continue with signing the release
    sign_release
}

# Create key unsuccessful loop
handle_gpg_success() {
    local gpg_success="$1"
    local attempts=0
    
    until [[ "$gpg_success" == "n" || $attempts -ge 2 ]]; do
        case "$gpg_success" in
            y)
                if (( attempts == 1 )); then
                    print_red "SECOND TRY! 3rd IS A FAIL!!!"
                else
                    print_red "Check your gpg for availability! You can try one more time."
                fi
                (( attempts++ ))
                break
                ;;
            n)
                print_green "You have just successfully used gpg to generate a public key."
                break
                echo ""
                ;;
            *)
                print_red "Invalid input. Try again (n/y)!"
                ;;
        esac

        # Repeat question on wrong input
        read -p $'\033[34mDoes gpg show any errors? Answer NO (n) or YES (y): \033[0m' gpg_success
        gpg_success=$(echo "$gpg_success" | tr '[:upper:]' '[:lower:]')
    done
    
    
    if [[ "$gpg_success" == "y" && attempts -lt 2 ]]; then
        create_public_key
    elif [[ "$gpg_success" == "y" && attempts -eq 2 ]]; then
        print_red "Your gpg failed. Check if it  is installed and functioning. This is outside the scope of this script!"
        exit
    
    elif [[ "$gpg_success" == "n" && attempts -lt 2 ]]; then
        # Confirm current directory
        confirm_current_directory
        echo ""  # Optional newline for readability or spacing
     fi   
}

# Function to create a public key
create_public_key() {
    # Start variable
    local attempts=0

    # Generate the key
    gpg --gen-key
    echo -e $'\033[34mIn the above output you will find a key-id (gpg: key[randomcapitallettersandnumbers). \033[0m'
    read -p $'\033[34mCopy it and paste here for confirmation: \033[0m' key_id
    
    # Export the key
    if [ -n "$key_id" ]; then
        gpg -a --export "$key_id" "$key_name.key"
        print_green "Public key exported as $key_name.key"
    else
        print_red "Invalid key name. Export aborted."
        exit 1
    fi

    # Confirm success
    read -p $'\033[34mDoes gpg show any errors? (N/Y): \033[0m' gpg_success
    gpg_success=$(echo "$gpg_success" | tr '[:upper:]' '[:lower:]')

    # Call the next function to handle user input and retry logic
    handle_gpg_success "$gpg_success"
}

# Function to create a key name
create_key_name() {
    local kerray=()
    while true; do
       read -p $'\033[34m Enter a name for your public key (For example: [directoryname-machinename]): \033[0m' key_name 

        if [[ -n "$key_name" ]]; then
            
            # Place key_name in array to survive
            kerray+=("$key_name")
            print_green "Key name provided: $key_name /n"
            echo ""
            print_orange "We'll now create a public key next. A passphrase is NOT mandatory /n"
            echo ""
            break  # Exit the loop if a key name is provided
        else
            print_red "Key name cannot be empty. Please provide a valid name."
            echo ""
            echo ""
        fi
    done
    create_public_key
    echo ""
}

confirm_public_key() {
    local key_name
    local key_id
    local kerray=()

    read -p $'\033[34mEnter the name of your exported key, without the extension (.key): \033[0m' key_name
    
    if [[ "$key_name" == "Release" ]]; then
        print_red "The Reasle.gpg is not a public key. It is the signature of the Release file."
        echo ""
        confirm_public_key
    fi
    

    if [[ -n "$key_name" ]]; then
        kerray+=("$key_name")
        print_green "Key name provided: $(pwd)/$kerray.key"
        echo ""

        # Verify if the key is a valid public key
        import_output=$(gpg --import "$(pwd)/$kerray.key" 2>&1)
        # echo $import_output
        
        if echo "$import_output"; then
        
            # Extract the key ID (fingerprint)
            key_id=$(echo "$import_output" | grep "^gpg: key " | sed -E 's/^gpg: key ([A-F0-9]+):.*/\1/')
            # echo "$key_id" for debugging script
            
            # Capture the key_id from the user (emergency use only!!!!)
            # read -p $'\033[34mCopy and paste the key_id (fingerprint) for this key: \033[0m' key_id

             if [[ -n "$key_id" ]]; then
                # Key verifies
                print_green "Key ID found: $key_id"
                print_green "Public key verified: $key_name.key"
                
                # Go to apt-key Adding
                add_key_to_apt
                echo ""
                
            else
                print_red "Failed to retrieve key ID."
                echo ""
                read_with_timeout 20 "Is your prepared key-pair oke?"  # Restart the process
                echo ""
                echo ""
            fi
        else
            print_red "The key $key_name does not exist or is not a valid public key."
            echo ""
            confirm_public_key  # Restart the process
        fi
    else
        print_red "Invalid input. Create a new one or start again (Ctrl + c)"
        echo ""
        create_key_name  # Restart the process
    fi
}




# Part 2 Confirm existing or Create, export and add gpg key-pair
################################################################################################################
# Part 1 Directory confirmation

# Function to display countdown and read user input
read_with_timeout() {
    local timeout=$1
    local prompt="$2"
    local remaining=$timeout
    local user_choice=""

    # Loop to display countdown
    while [ $remaining -gt 0 ]; do
        printf "\r\e[34m$prompt (%02d seconds remaining)\e[0m " $remaining
        read -t 1 -n 1 keypress

        # Process user input
        if [ "$keypress" == "y" ] || [ "$keypress" == "Y" ]; then
            user_choice="y"
            break
        elif [ "$keypress" == "n" ] || [ "$keypress" == "N" ]; then
            user_choice="n"
            break
        fi

        sleep 1
        ((remaining--))
    done
    
    # If no input received, set user_choice to empty string
    if [ -z "$user_choice" ]; then
        user_choice=""
    fi

    # Case statement to handle user_choice
    case "$user_choice" in
        y|Y)
            echo ""
            print_orange "Let's find out if your public key can be used for signing"
            echo ""
            echo ""
            print_red "Press Enter to continue..."
            read
            confirm_public_key
            ;;
        n|N)
            print_orange "Let's create a key to sign the repository"
            echo ""
            create_key_name
            exit 0
            ;;
        *)
            echo ""
            echo "Thanks for using my script."
            ;;
    esac
}

is_valid_directory() {
    local path="$dir_path"
    print_orange "Checking directory: "$path" "
    if [[ -d "$path" ]]; then
  #      print_green "Directory "$path"' exists."
        return 0  # Path is a directory
    else
        print_red "Directory '$path' not found. Make sure to add the complete path."
        return 1  # Path is not a directory
    fi
}

# Function to prompt for the directory path to the local repository
go_to_repo() {
    while true; do
        print_dirpath_blue "Enter directory path:"

        if [[ -z "$dir_path" ]]; then
            echo "The path to your repository cannot be empty. Please provide a directory path."
        else
            if is_valid_directory; then
                print_green "Valid directory found: '$dir_path' "
                # Change directory to the specified path
                cd "$dir_path" || { print_red "Failed to change directory to $dir_path"; exit 1; }
                echo ""
                break  # Exit the loop as valid directory input is provided
            else
                print_red "Directory '$dir_path' does not exist or is not a directory."
                user_input=""  # Clear user_input to prompt again
                # Uncomment the next line if you want to prompt again here
                print_dirpath_blue "Enter directory path:"  # Prompt again
            fi
        fi
    done
    
    # Chose prepared key (format is armored *.key) or generate a new key
    read_with_timeout 20 "Did you create a key to sign the Repository and is it exported (armored) to this directory?"
    echo ""
    echo ""
}

# Function to confirm current directory
confirm_current_directory() {

    print_orange "We have to work from the directory we want to sign"
    echo ""

    read -p $'\033[34mIs this the directory where your repository should be signed? (y/n): '"$current_directory"$'\033[0m)' confirm_dir

    case "$confirm_dir" in
        y|Y)
            print_green "Confirmed. Proceeding with signing Repository files."
            echo ""
            ;;
        n|N)
            print_blue "For local repository change directory"
            go_to_repo
            echo ""
            exit 0
            ;;
        *)
            print_red "Invalid choice. Try again..."
            confirm_current_directory
            ;;
    esac
    
    # Create Release.gpg & InRelease
    # sign_release
    read_with_timeout 20 "Did you create a key to sign the Repository and is it exported (armored) to this directory?"
}


## Start of the main script
print_orange "First let's double-check the correct repository directory"
echo ""
confirm_current_directory

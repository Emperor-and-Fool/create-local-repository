#!/bin/bash


# General functions

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
# Part 4 create local signed source

# Function to update sources.list
update_sources_list() {
    print_orange "Updating /etc/apt/sources.list file"
    # Check if the file exists; if not, create it
    run_with_sudo
    if [ ! -f /etc/apt/sources.list ]; then
        run_with_sudo /etc/apt/sources.list
        print_orange "Created new sources.list"
    fi
    print_blue "Updating sources.list with signed-by directive..."
    print_green "[signed-by=\"$current_directory/${kerray[0]}.gpg\"] \"$current_directory\"" | tee -a /etc/apt/sources.list >/dev/null
    print_green "Repository signed and added to update sources. You can now 'sudo apt update' to find you have a local signed repository"
}

clean_local_source(){
    print_orange "Time to add your local repository as a Source for apt to find"
    # Define the search pattern
    search_pattern="\./$"
#    search_pattern="^deb \[[^]]*\] file:/.* \./"
    print_blue "Search for lines with this pattern inside:" 
    echo $search_pattern
    
    # Search for the line in sources.list that matches the pattern
#    existing_line=$(grep -E "$search_pattern" /etc/apt/sources.list)
#    print_green "$existing_line"
    
    while true; do
        # Search for the line in sources.list that matches the pattern
         grep_output=$(grep -E "$search_pattern" /etc/apt/sources.list)

#            echo $grep_output
            
            
#            existing_line="$grep_output"
#            echo "$existing_line"
            
            
#           escaped_line=$(printf '%s\n' "$existing_line" | sed -e 's/[]\/$*. -e ^[]/\\&/g')
#           escaped_line=$(printf '%s\n' "$existing_line" | sed 's/[]\/$*. -]/\\&/g')
            # print_green "$existing_line"
            
            # echo $grep_output
            # Process each line individually
            while IFS= read -r existing_line; do
                # print_green "$existing_line"
                # Prompt user for removal confirmation
                read -p "Do you want to remove this line? (y/n): " response
                echo "$user_response"
                if [[ "$response" =~ ^[Yy]$ ]]; then
                    # Create escaped line
                    escaped_line=$(printf '%s\n' "$existing_line" | sed 's/[][\/$*. -]/\\&/g')
                    echo "$escaped_line"
                    # Remove the line from sources.list
                    # run_with_sudo sed -i "\%$escaped_line%d" /etc/apt/sources.list
                    
                    echo "Line removed."
                    user_response=""
                    # Reset existing_line variable
#                   existing_line=
            else
                echo "Line not removed."
                break  # Exit the loop if user does not want to remove the line
            fi
        done <<< "$(grep -E "$search_pattern" /etc/apt/sources.list)"
        
done

    update_sources_list

}

# Function to add GPG key to apt-key store
add_key_to_apt() {
    local key_name="$1"
    print_blue "Adding GPG key $key_id to apt-key store..."
    run_with_sudo apt-key add "${kerray[0]}.gpg"
    print_green "GPG key added to apt-key store."
    
    # Goto add repository to sources.list
    echo ""
    clean_local_source
}


# Step 4 update the source list 
############################################################################################
# Step 3 verify and sign

# Function to create Release files
sign_release() {

    # Check for the existance of the Release file
    if [ -f "Release" ]; then
            print_green "Release file exists in the current directory."
        else
            print_red "Release file does not exist. Please run the create-local-repo script first."
            exit 1
        fi

    print_orange "Signing Release by creating Release.gpg and InRelease file using key:"; print_green "$key_id"
    echo ""
    
    # Create Release.gpg signed with the specified key-id
    gpg --default-key "$key_id" --output Release.gpg --detach-sign Release

    # Create InRelease signed with the specified key-id
    gpg --default-key "$key_id" --output InRelease --clearsign Release

    print_green "Release files created successfully. Adding public key to apt key store."
    echo""
    
    # Go to apt-key Adding
    add_key_to_apt
}



# Step 3 verify and sign
###############################################################################################################
# Step 2 Directory confirmation

# Function to prompt in blue and return user input in green
print_dirpath_blue() {
    local prompt=$1
    echo -e "\e[34m$prompt\e[0m"  # Print the prompt in blue
    read user_input         # Read the user input and assign it to the reference variable
 #   echo "$user_input"         # Echo the user input to capture it later
    echo -e "\e[33m$user_input\e[0m"  # Print the user input in yellow
}

is_valid_directory() {
    local path="$user_input"
    print_green "Checking directory: "$path" "
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

        if [[ -z "$user_input" ]]; then
            echo "The path to your repository cannot be empty. Please provide a directory path."
        else
            if is_valid_directory; then
                print_green "Valid directory found: '$user_input'."
                break  # Exit the loop as valid directory input is provided
            else
                print_red "Directory '$user_input' does not exist or is not a directory."
                user_input=""  # Clear user_input to prompt again
                # Uncomment the next line if you want to prompt again here
                # print_dirpath_blue "Enter directory path:"  # Prompt again
            fi
        fi
        
    done
    # Create Release.gpg & InRelease
    sign_release
}

# Function to confirm current directory
confirm_current_directory() {
    local current_directory=$(pwd)
    read -p $'\033[34mIs this the directory where your repository should be signed? (y/n): '"$current_directory"$'\033[0m)' confirm_dir

    case "$confirm_dir" in
        y|Y)
            print_green "Confirmed. Proceeding with signing Repository files."
            echo ""
            ;;
        n|N)
            echo "Directory not confirmed"
            go_to_repo
            echo ""
            exit 0
            ;;
        *)
            echo "Invalid choice. Exiting..."
            exit 1
            ;;
    esac
    
    # Create Release.gpg & InRelease
    sign_release
}


# Part 2 Create Signatures
#######################################################################################################
# Part 1 Create key

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
    
    
    if [[ "$gpg_success" == "n" && attempts < 2 ]]; then
        create_public_key
    elif [[ "$gpg_success" == "n" && attempts -eq 2 ]]; then
        print_red "You gpg failed. Check if it  is installed and functioning. This is outside the scope of this script!"
        exit
    
    elif [[ "$gpg_success" == "y" && attempts -lt 2 ]]; then
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
        gpg --export --armor "$key_id" > "$key_name.key"
        print_green "Public key exported as $key_name.key"
    else
        print_red "Invalid key name. Export aborted."
        exit 1
    fi

    # Convert to .gpg key
    gpg --output "$key_name.gpg" --dearmor "$key_name.key"
    print_green "Public key converted to $key_name.gpg"

    # Remove .key file
    rm -f "$key_name.key"
    
    # Confirm success
    print_green "Exported key $key_name.key removed."
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
            kerray+=("$key_name")
            print_green "Key name provided: $key_name"
            break  # Exit the loop if a key name is provided
        else
            echo "Key name cannot be empty. Please provide a valid name."
        fi
    done
    create_public_key
    echo ""
}

confirm_public_key() {
    local key_name
    local key_id
    local kerray=()

    read -p $'\033[34mEnter the name of your public key (without the .gpg extension): \033[0m' key_name
    
    if [[ "$key_name" == "Release" ]]; then
        print_red "The Reasle.gpg is not a public key. It is the signature of the Release file."
        confirm_public_key
    fi
    

    if [[ -n "$key_name" ]]; then
        kerray+=("$key_name")
        print_green "Key name provided: $kerray.gpg"

        # Verify if the key is a valid public key
        import_output=$(gpg --import "$key_name.gpg" 2>&1)
        
        if echo "$import_output"; then
        print_green "Public key verified: $key_name.gpg"
            
            # Capture the key_id from the gpg import process
#            key_id=$(gpg --with-colons --list-keys | grep "^pub" | grep -oE "[A-F0-9]{8,16}")
            # Extract the key ID (fingerprint)
            key_id=$(echo "$import_output" | grep "^gpg: key " | sed -E 's/^gpg: key ([A-F0-9]+):.*/\1/')
            
            # Capture the key_id from the user
#           read -p $'\033[34mCopy and paste the key_id (fingerprint) for this key: \033[0m' key_id

             if [[ -n "$key_id" ]]; then
                print_green "Key ID found: $key_id"
                echo ""
                print_orange "Now let's see if we are in the right directory"
                echo ""
                # Proceed to confirm_current_directory
                confirm_current_directory

                # Continue with signing the release
                # sign_release "$key_id"
            else
                print_red "Failed to retrieve key ID."
            fi
        else
            print_red "The key $key_name does not exist or is not a valid public key."
            confirm_public_key  # Restart the process
        fi
    else
        print_red "Invalid input. Please enter a valid key name."
        confirm_public_key  # Restart the process
    fi
}



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
    
    # Clear the line after countdown ends
    printf "\r%-${COLUMNS}s\r" ""

    # If no input received, set user_choice to empty string
    if [ -z "$user_choice" ]; then
        user_choice=""
    fi

    # Case statement to handle user_choice
    case "$user_choice" in
        y|Y)
            print_orange "Let's find out if youor public key can be used for signing"
            echo ""
            confirm_public_key
            echo ""
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


# Main script
# Call the function to prompt user for input with a timeout of 20 seconds
read_with_timeout 20 "Do you want to create a signed repository? (y/n): "

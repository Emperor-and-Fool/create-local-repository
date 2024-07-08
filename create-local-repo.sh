 #!/bin/bash


#######################################################################################################
## Global functions, variables & arrays

# Variables

# Location of scripts
dir_scripts=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Mandatory Repository File
override_file="override"

# Define a list of valid attributes
# valid_attributes=("Origin" "Label" "Suite" "Codename" "Date" "Architectures" "Components" "Description")


# Arrays

# Declare global associative array 'attributes'
declare -gA attributes=(
    ["Origin"]=""
    ["Label"]=""
    ["Suite"]="stable"
    ["Codename"]="focal"
    ["Date"]="$(date -u +'%a, %d %b %Y %H:%M:%S %Z')"
    ["Architectures"]="amd64"
    ["Components"]="main"
    ["Description"]=""
)

# Declare global indexed array 'part1_output'
declare -g part1_output

## Terminal color output user info logic

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
print_workdir_blue() {
    local prompt="$1"
    echo -e "\e[34m$prompt\e[0m"  # Print the prompt in blue
    read dir_path            # Read the user input
    echo -e "\e[32m$dir_path\e[0m"  # Return the user input in green
}

# Function to prompt in blue and return user input in green
print_dirpath_blue() {
    local prompt=$1
    echo -e "\e[34m$prompt\e[0m"  # Print the prompt in blue
    read dir_path         # Read the user input and assign it to the reference variable
 #   echo "$dir_path"         # Echo the user input to capture it later
    echo -e "\e[33m$dir_path\e[0m"  # Print the user input in yellow
}

# Function to prompt for sudo if needed
run_with_sudo() {
    if [ "$EUID" -ne 0 ]; then
        sudo "$@"
    else
        "$@"
    fi
}
## General functions & variables
########################################################################################################## 
## Part 1 Functions for steps in the main script

# Functions Part 1 set workdir

# Validate repository directory 
is_valid_directory() {
    local path="$dir_path"
    print_green "Checking directory: "$path" "
    if [[ -d "$path" ]]; then
  #      print_green "Directory "$path"' exists."
        return 0  # Path is a directory
    else
        print_red "Directory '$path' not found. Make sure to add the complete path."
        return 1  # Path is not a directory
    fi
}


## Functions Part 1 repository directory
########################################################################################################
## Part 2 Define attributes and generate Release file

# Function to compute checksums and append to 'Release' file
compute_checksums_and_append() {
    # Write content to a temporary file
    local final_tmp_file=$(mktemp)
    printf "%s\n" "${part1_output[@]}" > "$final_tmp_file"
    
    # Create/empty the 'Release' file
    local output_file="Release"
    : > "$output_file"
    
    # List of files to process
    local files=("Release" "Packages" "Packages.gz")
    
    # Initialize checksum variables
    local md5sums=""
    local sha1sums=""
    local sha256sums=""
    local sha512sums=""
    
    # Compute checksums for each file and append to 'Release' file
    for file in "${files[@]}"; do
        local md5sum=$(md5sum "$file" | awk '{print $1}')
        local sha1sum=$(sha1sum "$file" | awk '{print $1}')
        local sha256sum=$(sha256sum "$file" | awk '{print $1}')
        local sha512sum=$(sha512sum "$file" | awk '{print $1}')
        local size=$(stat -c%s "$file")
        
        md5sums+=" $md5sum $size $file"$'\n'
        sha1sums+=" $sha1sum $size $file"$'\n'
        sha256sums+=" $sha256sum $size $file"$'\n'
        sha512sums+=" $sha512sum $size $file"$'\n'
    done
    
     # Append checksums to part1_tmp_file
    {
        printf "MD5Sum:\n%s" "$md5sums"
        printf "SHA1:\n%s" "$sha1sums"
        printf "SHA256:\n%s" "$sha256sums"
        printf "SHA512:\n%s" "$sha512sums"
    } >> "$final_tmp_file"
    
    # Concatenate parts into the final 'Release' file
    cat $final_tmp_file > "$output_file"
    echo ""
    echo ""

    print_green "Release Data & checksums succesfully created "
    # Print the generated 'Release' file
    cat "$output_file" /dev/null
}

# Function to process attributes
process_repository_attributes() {
    # cat ./Release
        local release_file="Release"

    # Loop through keys in attributes array
    for key in "${!attributes[@]}"; do
    # Skip dynamically generated fields like Date
    if [[ "$key" == "Date" ]]; then
        continue
    fi
    
    # Check if attribute value is empty
    if [[ -z "${attributes[$key]}" ]]; then
        # Attempt to read value from Release file
        if [[ -f "$release_file" ]]; then
            while IFS=": " read -r file_key file_value; do
                file_key=$(echo "$file_key" | tr -d '\r')
                # Compare with attributes keys and update if match found
                if [[ "$key" == "$file_key" ]]; then
                    attributes["$key"]=$file_value
                    break
                fi
            done < "$release_file"
        fi
    fi
done

    # Display all attributes
    echo "Attributes after reading from Release file: "
    for key in "${!attributes[@]}"; do
        echo "$key: ${attributes[$key]}"
    done
    
    # Prompt for missing attribute values
    for key in "${!attributes[@]}"; do
        if [[ -z "${attributes[$key]}" ]]; then
            read -p "Enter value for $key: " value
            attributes[$key]=$value
        fi
    done

    # Define the order of attributes
    local ordered_keys=(
        "Origin"
        "Label"
        "Suite"
        "Codename"
        "Date"
        "Architectures"
        "Components"
        "Description"
    )

    # Store ordered output in global part1_output array
    part1_output=()
    for key in "${ordered_keys[@]}"; do
        part1_output+=("$key: ${attributes[$key]}")
    done
}

# Function to check package creation
check_package_creation() {
    local error_flag=false

    # Create Packages file
    errordpkg_log=$(mktemp) && dpkg-scanpackages . /dev/null > Packages 2> "$errordpkg_log"
    if [[ -s $errordpkg_log ]]; then
    print_red "Errors detected processing the application packages. They may not comply with the current standards.\n"
    more "$errordpkg_log"
    fi

     # Compress Packages file into Packages.gz
    ziperror_log=$(mktemp) && gzip -c Packages > Packages.gz 2> "$ziperror_log"
    if [[ -s "$ziperror_log" ]]; then
    print_red "Errors detected creating a Packages.gz file. We need proper application packages to create your local Repository"
    cat "$ziperror_log"
        error_flag=true
    fi

    # Exit if there were errors
    if [ "$error_flag" = true ]; then
    echo ""
    print_orange "Check your application packages. Make sure they comply with the standards. Remove all other files and try again."
        exit 1
    fi
    # Clean up temporary error log
    rm "$errordpkg_log"
    # Clean up temporary error log
    rm "$ziperror_log"
}

# Function to extract control information and append to override file
extract_control() {
    local deb_file="$1"
    local control_data=$(ar -p "$deb_file" control.tar.gz | tar -xzO ./control)

    if [[ -z "$control_data" ]]; then
        echo "Error: No control data found for $deb_file. Skipping."
    else
        # Extract fields from control data
        Package=$(echo "$control_data" | grep -Po '(?<=Package: ).*')
        Version=$(echo "$control_data" | grep -Po '(?<=Version: ).*')
        Architecture=$(echo "$control_data" | grep -Po '(?<=Architecture: ).*')
        Maintainer=$(echo "$control_data" | grep -Po '(?<=Maintainer: ).*')
        Installed_Size=$(echo "$control_data" | grep -Po '(?<=Installed-Size: ).*')
        
        #Control data to terminal
        echo $Package
        echo $Version
        echo $Architecture
        echo $Maintainer
        echo $Installed_Size

        # Write to override file
        echo "$Package $Version $Architecture $Maintainer $Installed_Size" >> "$override_file"
        
    fi
}

# Function to check for .deb files in the current directory
check_for_deb_files() {
    if ls *.deb 1> /dev/null 2>&1; then
        print_green "Found.deb files to process."
        return 0
    else
        print_red "No .deb files found in the current directory."
        return 1
    fi
}


## Part 2 Functions to generate files and data
########################################################################################################
## Part 3 Functions to add the repository to sources, turn it on or off

# Open script to sign the repository
sign_repo() {
    echo "Change to signed repository..."
    # Add your signing logic here
    
    echo $dir_scripts
    "$dir_scripts/signed-repo-script.sh"
    exit
}

# Function to enable the repository
activate_repo() {
    if [[ "$existing_line" == "# $repo_line" ]]; then
        # Enable repository by uncommenting the line if it exists
        if run_with_sudo sed -i -E "s|^# ($search_repo_line)|\1|" /etc/apt/sources.list.d/local.list; then
            print_green "Repository enabled."
        else
            print_red "Failed to enable repository."
        fi
    else
        print_green "Repository will be available."
    fi
}

# Function to disable the repository
disable_repo() {
    if [[ "$existing_line" == "$repo_line" ]]; then
        # Disable repository by commenting the line if it exists
        if run_with_sudo sed -i -E "s|^($search_repo_line)|# \1|" /etc/apt/sources.list.d/local.list; then
            print_red "Repository disabled."
        else
            print_red "Failed to disable repository."
        fi
    else
        print_red "Repository left disabled for now."
    fi
    sign_repo "Let's Go!"
    exit
}


## Part 3 Functions for steps in the main script
########################################################################################################## 
## Main script
 

# Part 1: Repository directory verification

# Script opening:
print_orange "Add your updated application .deb installers to the software auto-update cycle with your local repository. Make sure to add at least 1 .deb application package to your prefered location."

echo""

# Prompt user for directory path to local repository
while true; do
    print_dirpath_blue "Enter directory path:"

    if [[ -z "$dir_path" ]]; then
        echo "The Path to your repository cannot be empty. Please provide a directory path."
    else
        if is_valid_directory; then
            print_green "Valid directory found: '$dir_path'."
            break  # Exit the loop as valid directory input is provided
        else
            print_red "Directory '$dir_path' does not exist or is not a directory."
            dir_path=""  # Clear dir_path to prompt again
#            print_dirpath_blue "Enter directory path:"  # Prompt again
        fi
    fi
done

print_blue "We will now change to your repository and do the work from there."
echo ""

script_dir=$(dirname "${BASH_SOURCE[0]}")
echo $script_dir

# Change directory to the specified path
cd "$dir_path" || { echo "Failed to change directory to $dir_path"; exit 1; }

print_green "Your local repository under construction @$(pwd)"
echo ""


## Part 2.1 Repository file creation

print_orange "First let's create the default repository files using dpkg."
echo ""

print_red "Press Enter to continue..."
read
echo ""

# Initial check for .deb files
if ! check_for_deb_files; then
    read "Would you like to add a *.deb file now? (y/n): " user_input
    if [[ "$user_input" =~ ^[Yy]$ ]]; then
        # Add your logic here for handling the addition of *.deb files
        echo "Please add *.deb file(s) now and press enter to continue."
        read

        # Check again if no deb files are available
        if ! check_for_deb_files; then
            print_red "No .deb files found. /n"
            print_blue "We need at least one .deb file to process and generate the default repository files. "
            check_for_deb_files
        fi
    else
        print_red "Exiting the script. Prepare yourself."
        exit 1
    fi
fi

# Remove existing override file if exists
rm -f "$override_file"

# Iterate over each .deb file in the current directory
for deb_file in *.deb; do
    print_orange "Processing $deb_file..."
    extract_control "$deb_file"
    print_green "$deb_file"
    echo ""
done

print_green "Override file '$override_file' created successfully."
echo ""

# Create Packages and Packages.gz files for apt repository
check_package_creation
echo ""

print_orange "Files now in your repository: "
files=$(find ./ -maxdepth 1 -type f ! -name "*.sh")
while IFS= read -r file; do
    print_green "$file"
done <<< "$files"

print_blue "If you have a 'Packages', a 'Packages.gz', a 'Release' and an 'override' in your list.\n" 
print_blue "we will now add mandatory content to the files.\n"
print_red "Press Enter to continue...\n"
read
echo ""

## Part 2.2 Release file content & complience

process_repository_attributes

print_red "Press Enter to continue..."
read
echo ""

compute_checksums_and_append

# Debugging file generation
# print_green "$(<./Release)"
# echo""

print_blue "You can check the content for valid checksums and file-sizes. /n"
print_blue "Remember these are needed to correctly sign your release file later. /n"
print_red "Press Enter to continue... "
read
echo ""

## Part 3 Add repository to sources, enable or sign

# confirmation source list
print_orange "Add your local .deb repository to /etc/apt/sources.list.d/local.list (No signatures) /n" 
print_blue "If you have downloaded the script named 'create_signed-repo.sh', /n"
print_blue "make sure it is inside the repository if you like official sgning after creation. You can do this as a separate step later./n"

print_red "Press Enter to continue..."
read
echo ""

if [ ! -f /etc/apt/sources.list.d/local.list ]; then
    run_with_sudo touch /etc/apt/sources.list.d/local.list
    print_green "/etc/apt/sources.list.d/local.list created."
else
    print_green "/etc/apt/sources.list.d/local.list already exists."
fi

# Define the repository line to add
repo_line="deb [allow-insecure=yes] file:$(pwd)/ ./"

# Escape special characters for the grep search
search_repo_line=$(printf '%s\n' "$repo_line" | sed -e 's/[]\/$*.^[]/\\&/g')

# Debugging: Display the escaped repo_line being searched
print_orange "Searching for repo line: $repo_line"

if [[ ! -r /etc/apt/sources.list.d/local.list ]]; then
    print_red "Error: Cannot read /etc/apt/sources.list.d/local.list. Please check location and file permissions."
    exit 1
fi

# Check if repository line already exists in sources.list (commented or uncommented)
existing_line=$(grep -E "^(# )?$search_repo_line" /etc/apt/sources.list.d/local.list)

if [[ -z "$existing_line" ]]; then
    # Repository line does not exist, add it
    print_orange "Adding repository line to sources.list..."
    echo "$repo_line" | run_with_sudo tee -a /etc/apt/sources.list.d/local.list > /dev/null
    print_orange "Repository line added:"
    print_green "$repo_line"
else
    # Repository line already exists
    print_orange "apt repository is known"
    print_green "Existing repository line found: $existing_line"
fi


# Prompt user to enable, disable the repository, or sign the repository
read -p "Do you want to enable (E), disable (D) this repository or sign it (S)? [e/d/s]: " enable_repo

# Normalize user input to lowercase & handle input
enable_repo=$(echo "$enable_repo" | tr '[:upper:]' '[:lower:]')

case "$enable_repo" in
    e)
        activate_repo
        ;;
    d)
        disable_repo
        ;;
    s)
        disable_repo
        ;;
    *)
        print_orange "Invalid input. No changes made."
        ;;
esac
#!/bin/bash


#######################################################################################################
## Global functions, variables & arrays

# Variables

# Location of scripts
dir_scripts=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Mandatory Repository File
override_file="override"

# Define a list of valid attributes
# valid_attributes=("Origin" "Label" "Suite" "Codename" "Date" "Architectures" "Components" "Description")


# Arrays

# Declare global associative array 'attributes'
declare -gA attributes=(
    ["Origin"]=""
    ["Label"]=""
    ["Suite"]="stable"
    ["Codename"]="focal"
    ["Date"]="$(date -u +'%a, %d %b %Y %H:%M:%S %Z')"
    ["Architectures"]="amd64"
    ["Components"]="main"
    ["Description"]=""
)

# Declare global indexed array 'part1_output'
declare -g part1_output

## Terminal color output user info logic

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
print_workdir_blue() {
    local prompt="$1"
    echo -e "\e[34m$prompt\e[0m"  # Print the prompt in blue
    read dir_path            # Read the user input
    echo -e "\e[32m$dir_path\e[0m"  # Return the user input in green
}

# Function to prompt in blue and return user input in green
print_dirpath_blue() {
    local prompt=$1
    echo -e "\e[34m$prompt\e[0m"  # Print the prompt in blue
    read dir_path         # Read the user input and assign it to the reference variable
 #   echo "$dir_path"         # Echo the user input to capture it later
    echo -e "\e[33m$dir_path\e[0m"  # Print the user input in yellow
}

# Function to prompt for sudo if needed
run_with_sudo() {
    if [ "$EUID" -ne 0 ]; then
        sudo "$@"
    else
        "$@"
    fi
}
## General functions & variables
########################################################################################################## 
## Part 1 Functions for steps in the main script

# Functions Part 1 set workdir

# Validate repository directory 
is_valid_directory() {
    local path="$dir_path"
    print_green "Checking directory: "$path" "
    if [[ -d "$path" ]]; then
  #      print_green "Directory "$path"' exists."
        return 0  # Path is a directory
    else
        print_red "Directory '$path' not found. Make sure to add the complete path."
        return 1  # Path is not a directory
    fi
}


## Functions Part 1 repository directory
########################################################################################################
## Part 2 Define attributes and generate Release file

# Function to compute checksums and append to 'Release' file
compute_checksums_and_append() {
    # Write content to a temporary file
    local final_tmp_file=$(mktemp)
    printf "%s\n" "${part1_output[@]}" > "$final_tmp_file"
    
    # Create/empty the 'Release' file
    local output_file="Release"
    : > "$output_file"
    
    # List of files to process
    local files=("Release" "Packages" "Packages.gz")
    
    # Initialize checksum variables
    local md5sums=""
    local sha1sums=""
    local sha256sums=""
    local sha512sums=""
    
    # Compute checksums for each file and append to 'Release' file
    for file in "${files[@]}"; do
        local md5sum=$(md5sum "$file" | awk '{print $1}')
        local sha1sum=$(sha1sum "$file" | awk '{print $1}')
        local sha256sum=$(sha256sum "$file" | awk '{print $1}')
        local sha512sum=$(sha512sum "$file" | awk '{print $1}')
        local size=$(stat -c%s "$file")
        
        md5sums+=" $md5sum $size $file"$'\n'
        sha1sums+=" $sha1sum $size $file"$'\n'
        sha256sums+=" $sha256sum $size $file"$'\n'
        sha512sums+=" $sha512sum $size $file"$'\n'
    done
    
     # Append checksums to part1_tmp_file
    {
        printf "MD5Sum:\n%s" "$md5sums"
        printf "SHA1:\n%s" "$sha1sums"
        printf "SHA256:\n%s" "$sha256sums"
        printf "SHA512:\n%s" "$sha512sums"
    } >> "$final_tmp_file"
    
    # Concatenate parts into the final 'Release' file
    cat $final_tmp_file > "$output_file"
    echo ""
    echo ""

    print_green "Release Data & checksums succesfully created "
    # Print the generated 'Release' file
    cat "$output_file" /dev/null
}

# Function to process attributes
process_repository_attributes() {
    # cat ./Release
        local release_file="Release"

    # Loop through keys in attributes array
    for key in "${!attributes[@]}"; do
    # Skip dynamically generated fields like Date
    if [[ "$key" == "Date" ]]; then
        continue
    fi
    
    # Check if attribute value is empty
    if [[ -z "${attributes[$key]}" ]]; then
        # Attempt to read value from Release file
        if [[ -f "$release_file" ]]; then
            while IFS=": " read -r file_key file_value; do
                file_key=$(echo "$file_key" | tr -d '\r')
                # Compare with attributes keys and update if match found
                if [[ "$key" == "$file_key" ]]; then
                    attributes["$key"]=$file_value
                    break
                fi
            done < "$release_file"
        fi
    fi
done

    # Display all attributes
    echo "Attributes after reading from Release file: "
    for key in "${!attributes[@]}"; do
        echo "$key: ${attributes[$key]}"
    done
    
    # Prompt for missing attribute values
    for key in "${!attributes[@]}"; do
        if [[ -z "${attributes[$key]}" ]]; then
            read -p "Enter value for $key: " value
            attributes[$key]=$value
        fi
    done

    # Define the order of attributes
    local ordered_keys=(
        "Origin"
        "Label"
        "Suite"
        "Codename"
        "Date"
        "Architectures"
        "Components"
        "Description"
    )

    # Store ordered output in global part1_output array
    part1_output=()
    for key in "${ordered_keys[@]}"; do
        part1_output+=("$key: ${attributes[$key]}")
    done
}

# Function to check package creation
check_package_creation() {
    local error_flag=false

    # Create Packages file
    errordpkg_log=$(mktemp) && dpkg-scanpackages . /dev/null > Packages 2> "$errordpkg_log"
    if [[ -s $errordpkg_log ]]; then
    print_red "Errors detected processing the application packages. They may not comply with the current standards.\n"
    more "$errordpkg_log"
    fi

     # Compress Packages file into Packages.gz
    ziperror_log=$(mktemp) && gzip -c Packages > Packages.gz 2> "$ziperror_log"
    if [[ -s "$ziperror_log" ]]; then
    print_red "Errors detected creating a Packages.gz file. We need proper application packages to create your local Repository"
    cat "$ziperror_log"
        error_flag=true
    fi

    # Exit if there were errors
    if [ "$error_flag" = true ]; then
    echo ""
    print_orange "Check your application packages. Make sure they comply with the standards. Remove all other files and try again."
        exit 1
    fi
    # Clean up temporary error log
    rm "$errordpkg_log"
    # Clean up temporary error log
    rm "$ziperror_log"
}

# Function to extract control information and append to override file
extract_control() {
    local deb_file="$1"
    local control_data=$(ar -p "$deb_file" control.tar.gz | tar -xzO ./control)

    if [[ -z "$control_data" ]]; then
        echo "Error: No control data found for $deb_file. Skipping."
    else
        # Extract fields from control data
        Package=$(echo "$control_data" | grep -Po '(?<=Package: ).*')
        Version=$(echo "$control_data" | grep -Po '(?<=Version: ).*')
        Architecture=$(echo "$control_data" | grep -Po '(?<=Architecture: ).*')
        Maintainer=$(echo "$control_data" | grep -Po '(?<=Maintainer: ).*')
        Installed_Size=$(echo "$control_data" | grep -Po '(?<=Installed-Size: ).*')
        
        #Control data to terminal
        echo $Package
        echo $Version
        echo $Architecture
        echo $Maintainer
        echo $Installed_Size

        # Write to override file
        echo "$Package $Version $Architecture $Maintainer $Installed_Size" >> "$override_file"
        
    fi
}

# Function to check for .deb files in the current directory
check_for_deb_files() {
    if ls *.deb 1> /dev/null 2>&1; then
        print_green "Found.deb files to process."
        return 0
    else
        print_red "No .deb files found in the current directory."
        return 1
    fi
}


## Part 2 Functions to generate files and data
########################################################################################################
## Part 3 Functions to add the repository to sources, turn it on or off

# Open script to sign the repository
sign_repo() {
    echo "Change to signed repository..."
    # Add your signing logic here
    
    echo $dir_scripts
    "$dir_scripts/signed-repo-script.sh"
    exit
}

# Function to enable the repository
activate_repo() {
    if [[ "$existing_line" == "# $repo_line" ]]; then
        # Enable repository by uncommenting the line if it exists
        if run_with_sudo sed -i -E "s|^# ($search_repo_line)|\1|" /etc/apt/sources.list.d/local.list; then
            print_green "Repository enabled."
        else
            print_red "Failed to enable repository."
        fi
    else
        print_green "Repository will be available."
    fi
}

# Function to disable the repository
disable_repo() {
    if [[ "$existing_line" == "$repo_line" ]]; then
        # Disable repository by commenting the line if it exists
        if run_with_sudo sed -i -E "s|^($search_repo_line)|# \1|" /etc/apt/sources.list.d/local.list; then
            print_red "Repository disabled."
        else
            print_red "Failed to disable repository."
        fi
    else
        print_red "Repository left disabled for now."
    fi
    sign_repo "Let's Go!"
    exit
}


## Part 3 Functions for steps in the main script
########################################################################################################## 
## Main script
 

# Part 1: Repository directory verification

# Script opening:
print_orange "Add your updated application .deb installers to the software auto-update cycle with your local repository. Make sure to add at least 1 .deb application package to your prefered location."

echo""

# Prompt user for directory path to local repository
while true; do
    print_dirpath_blue "Enter directory path:"

    if [[ -z "$dir_path" ]]; then
        echo "The Path to your repository cannot be empty. Please provide a directory path."
    else
        if is_valid_directory; then
            print_green "Valid directory found: '$dir_path'."
            break  # Exit the loop as valid directory input is provided
        else
            print_red "Directory '$dir_path' does not exist or is not a directory."
            dir_path=""  # Clear dir_path to prompt again
#            print_dirpath_blue "Enter directory path:"  # Prompt again
        fi
    fi
done

print_blue "We will now change to your repository and do the work from there."
echo ""

script_dir=$(dirname "${BASH_SOURCE[0]}")
echo $script_dir

# Change directory to the specified path
cd "$dir_path" || { echo "Failed to change directory to $dir_path"; exit 1; }

print_green "Your local repository under construction @$(pwd)"
echo ""


## Part 2.1 Repository file creation

print_orange "First let's create the default repository files using dpkg."
echo ""

print_red "Press Enter to continue..."
read
echo ""

# Initial check for .deb files
if ! check_for_deb_files; then
    read "Would you like to add a *.deb file now? (y/n): " user_input
    if [[ "$user_input" =~ ^[Yy]$ ]]; then
        # Add your logic here for handling the addition of *.deb files
        echo "Please add *.deb file(s) now and press enter to continue."
        read

        # Check again if no deb files are available
        if ! check_for_deb_files; then
            print_red "No .deb files found. /n"
            print_blue "We need at least one .deb file to process and generate the default repository files. "
            check_for_deb_files
        fi
    else
        print_red "Exiting the script. Prepare yourself."
        exit 1
    fi
fi

# Remove existing override file if exists
rm -f "$override_file"

# Iterate over each .deb file in the current directory
for deb_file in *.deb; do
    print_orange "Processing $deb_file..."
    extract_control "$deb_file"
    print_green "$deb_file"
    echo ""
done

print_green "Override file '$override_file' created successfully."
echo ""

# Create Packages and Packages.gz files for apt repository
check_package_creation
echo ""

print_orange "Files now in your repository: "
files=$(find ./ -maxdepth 1 -type f ! -name "*.sh")
while IFS= read -r file; do
    print_green "$file"
done <<< "$files"

print_blue "If you have a 'Packages', a 'Packages.gz', a 'Release' and an 'override' in your list.\n" 
print_blue "we will now add mandatory content to the files.\n"
print_red "Press Enter to continue...\n"
read
echo ""

## Part 2.2 Release file content & complience

process_repository_attributes

print_red "Press Enter to continue..."
read
echo ""

compute_checksums_and_append

# Debugging file generation
# print_green "$(<./Release)"
# echo""

print_blue "You can check the content for valid checksums and file-sizes. /n"
print_blue "Remember these are needed to correctly sign your release file later. /n"
print_red "Press Enter to continue... "
read
echo ""

## Part 3 Add repository to sources, enable or sign

# confirmation source list
print_orange "Add your local .deb repository to /etc/apt/sources.list.d/local.list (No signatures) /n" 
print_blue "If you have downloaded the script named 'create_signed-repo.sh', /n"
print_blue "make sure it is inside the repository if you like official sgning after creation. You can do this as a separate step later./n"

print_red "Press Enter to continue..."
read
echo ""

if [ ! -f /etc/apt/sources.list.d/local.list ]; then
    run_with_sudo touch /etc/apt/sources.list.d/local.list
    print_green "/etc/apt/sources.list.d/local.list created."
else
    print_green "/etc/apt/sources.list.d/local.list already exists."
fi

# Define the repository line to add
repo_line="deb [allow-insecure=yes] file:$(pwd)/ ./"

# Escape special characters for the grep search
search_repo_line=$(printf '%s\n' "$repo_line" | sed -e 's/[]\/$*.^[]/\\&/g')

# Debugging: Display the escaped repo_line being searched
print_orange "Searching for repo line: $repo_line"

if [[ ! -r /etc/apt/sources.list.d/local.list ]]; then
    print_red "Error: Cannot read /etc/apt/sources.list.d/local.list. Please check location and file permissions."
    exit 1
fi

# Check if repository line already exists in sources.list (commented or uncommented)
existing_line=$(grep -E "^(# )?$search_repo_line" /etc/apt/sources.list.d/local.list)

if [[ -z "$existing_line" ]]; then
    # Repository line does not exist, add it
    print_orange "Adding repository line to sources.list..."
    echo "$repo_line" | run_with_sudo tee -a /etc/apt/sources.list.d/local.list > /dev/null
    print_orange "Repository line added:"
    print_green "$repo_line"
else
    # Repository line already exists
    print_orange "apt repository is known"
    print_green "Existing repository line found: $existing_line"
fi


# Prompt user to enable, disable the repository, or sign the repository
read -p "Do you want to enable (E), disable (D) this repository or sign it (S)? [e/d/s]: " enable_repo

# Normalize user input to lowercase & handle input
enable_repo=$(echo "$enable_repo" | tr '[:upper:]' '[:lower:]')

case "$enable_repo" in
    e)
        activate_repo
        ;;
    d)
        disable_repo
        ;;
    s)
        disable_repo
        ;;
    *)
        print_orange "Invalid input. No changes made."
        ;;
esac

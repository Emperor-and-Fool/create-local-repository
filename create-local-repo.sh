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

# Function to prompt in blue and return user input in green
print_dirpath_blue() {
    local prompt=$1
    echo -e "\e[34m$prompt\e[0m"  # Print the prompt in blue
    read user_input         # Read the user input and assign it to the reference variable
 #   echo "$user_input"         # Echo the user input to capture it later
    echo -e "\e[33m$user_input\e[0m"  # Print the user input in yellow
}


 
# Part 0 Opening settings

# Functions Part 0 set workdir
is_valid_directory() {
    local path="user_input"
    if [[ -d "$path" ]]; then
        return 0  # Indicates success (path is a directory)
    else
        return 1  # Indicates failure (path is not a directory)
    fi
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

# Function to sign the repository
sign_repo() {
    echo "Signing the repository..."
    # Add your signing logic here
    # For example:
    ./signed-repo-script.sh
    exit
}




# Main script
echo""

# Script opening:
print_orange "Add your updated application .deb installers to the software auto-update cycle with your local repository. Make sure to add at least 1 .deb application package to your prefered location."

echo""

# Prompt user for directory path to local repository
while true; do
    print_dirpath_blue "Enter directory path:"

    if [[ -z "$user_input" ]]; then
        echo "The Path to your repository cannot be empty. Please provide a directory path."
    else
        if is_valid_directory; then
            print_green "Valid directory found: '$user_input'."
            break  # Exit the loop as valid directory input is provided
        else
            print_red "Directory '$user_input' does not exist or is not a directory."
            user_input=""  # Clear user_input to prompt again
#            print_dirpath_blue "Enter directory path:"  # Prompt again
        fi
    fi
done

print_blue "We will now change to your repository and do the work from there."
echo ""
print_blue "Press Enter to continue..."
read

# Change directory to the specified path
cd "$dir_path" || { echo "Failed to change directory to $dir_path"; exit 1; }

print_green "Your local repository under construction @$(pwd)"

echo ""

echo ""


## Part 1 create default apt repository content

# Function to prompt in blue and return user input in green
print_workdir_blue() {
    local prompt="$1"
    echo -e "\e[34m$prompt\e[0m"  # Print the prompt in blue
    read user_input            # Read the user input
    echo -e "\e[32m$user_input\e[0m"  # Return the user input in green
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

# Function to check package creation
check_package_creation() {
    local error_flag=false

    # Create Packages file
    dpkg-scanpackages . /dev/null > Packages 2> errordpkg.log
    if [[ -s error.log ]]; then
    print_red "Errors detected processing the application packages. They may not comply with the current standards."
    fi

     # Compress Packages file into Packages.gz
    gzip -c Packages > Packages.gz 2> ziperror.log
    if [[ -s error.log ]]; then
    print_red "Errors detected creating a Packages.gz file. We need proper application packages to create your local Repository"
        error_flag=true
    fi

    # Exit if there were errors
    if [ "$error_flag" = true ]; then
    echo ""
    print_orange "Check your application packages. Make sure they comply with the standards. Remove all other files and try again."
        exit 1
    fi
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

        # Write to override file
        echo "$Package $Version $Architecture $Maintainer $Installed_Size" >> "$override_file"
    fi
}

# Opening part 1: file creation
print_orange "First let's create the default files using dpkg."

echo ""

# Initial check for .deb files
if ! check_for_deb_files; then
    print_read_blue "Would you like to add a *.deb file now? (y/n): "
    if [[ "$user_input" =~ ^[Yy]$ ]]; then
        # Add your logic here for handling the addition of *.deb files
        echo "Please add *.deb file(s) now and press enter to continue."
        read

        # Check again after user presses enter
        if ! check_for_deb_files; then
            print_orange "No .deb files found.
We need at least one .deb file to process and generate the default repository files. 
Exiting the script until you know what you realy want."
            exit 1
        fi
    else
        echo "Exiting the script."
        exit 1
    fi
fi

# Create Packages and Packages.gz files for apt repository
check_package_creation

echo ""

override_file="override"

# Remove existing override file if exists
rm -f "$override_file"

# Iterate over each .deb file in the current directory
for deb_file in *.deb; do
    echo "Processing $deb_file..."
    extract_control "$deb_file"
done

echo "Override file '$override_file' created successfully."

echo ""



## Part 2: Define attributes and generate Release file

# Function to compute checksums and sizes
compute_checksums() {
    local file=$1
    md5sum=$(md5sum "$file" | awk '{print $1}')
    sha1sum=$(sha1sum "$file" | awk '{print $1}')
    sha256sum=$(sha256sum "$file" | awk '{print $1}')
    size=$(stat -c%s "$file")
    
    md5sums+=" $md5sum $size $file"$'\n'
    sha1sums+=" $sha1sum $size $file"$'\n'
    sha256sums+=" $sha256sum $size $file"$'\n'
}

# Define the default attributes
declare -A attributes
attributes=(
    ["Origin"]=""
    ["Label"]=""
    ["Suite"]="stable"
    ["Codename"]="focal"
    ["Date"]="$(date -u +'%a, %d %b %Y %H:%M:%S %Z')"
    ["Architectures"]="amd64"
    ["Components"]="main"
    ["Description"]=""
)

# Check if Release file exists and read existing values
if [[ -f "Release" ]]; then
    while IFS=": " read -r key value; do
        key=$(echo "$key" | tr -d '\r')  # Remove any carriage return characters
        if [[ -v attributes["$key"] ]]; then
            attributes["$key"]=$value
        fi
    done < "Release"
fi

# Debugging: Print the attributes array to check the values
for key in "${!attributes[@]}"; do
    echo "Attribute key: '$key' has value: '${attributes[$key]}'"
done

# Prompt for missing attribute values
for key in "${!attributes[@]}"; do
    if [[ -z "${attributes[$key]}" ]]; then
        read -p "Enter value for $key: " value
        attributes[$key]=$value
    fi
done

# Define the order of attributes
ordered_keys=(
    "Origin"
    "Label"
    "Suite"
    "Codename"
    "Date"
    "Architectures"
    "Components"
    "Description"
)

# Create an array in memory to hold Part 1 output
declare -a part1_output

# Store Part 1 output in the array
for key in "${ordered_keys[@]}"; do
    part1_output+=("$key: ${attributes[$key]}")
done

# Write Part 1 output to a temporary file
part1_tmp_file=$(mktemp)
printf "%s\n" "${part1_output[@]}" > "$part1_tmp_file"

# Step 2: Compute checksums and append to 'Release' file

# List of files to process
files=("Release" "Packages" "Packages.gz")

# Create/empty the 'Release' file
output_file="Release"
: > $output_file

# Initialize checksum variables
md5sums=""
sha1sums=""
sha256sums=""

# Compute checksums for each file
for file in "${files[@]}"; do
    compute_checksums $file
done

# Append step 2 output to the temporary file
{
    printf "MD5Sum:\n%s" "$md5sums"
    printf "SHA1:\n%s" "$sha1sums"
    printf "SHA256:\n%s" "$sha256sums"
} >> "$part1_tmp_file"

# Concatenate parts into the final 'Release' file
cat "$part1_tmp_file" > "$output_file"

# Print the generated 'Release' file
cat $output_file

# Debugging file generation
print_green "$(<./Release)"

echo""


## Part 3: Add the repository, turn it on or off



# Function to enable the repository
activate_repo() {
    if [[ "$existing_line" == "# $repo_line" ]]; then
        # Enable repository by uncommenting the line if it exists
        if run_with_sudo sed -i -E "s|^# ($search_repo_line)|\1|" /etc/apt/sources.list; then
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
        if run_with_sudo sed -i -E "s|^($search_repo_line)|# \1|" /etc/apt/sources.list; then
            print_red "Repository disabled."
        else
            print_red "Failed to disable repository."
        fi
    else
        print_red "Repository left disabled for now."
    fi
}

# Function to sign the repository
sign_repo() {
    echo "Signing the repository..."
    ./signed-repo-script.sh
}

# main script
print_blue "Local Repository in sources.list"

echo""

# Define the repository line to add
repo_line="deb [allow-insecure=yes] file:$(pwd)/ ./"

# Escape special characters for the grep search
search_repo_line=$(printf '%s\n' "$repo_line" | sed -e 's/[]\/$*.^[]/\\&/g')

# Debugging: Display the escaped repo_line being searched
print_orange "Searching for repo line: $repo_line"

if [[ ! -r /etc/apt/sources.list ]]; then
    print_red "Error: Cannot read /etc/apt/sources.list. Please check location and file permissions."
    exit 1
fi

# Check if repository line already exists in sources.list (commented or uncommented)
existing_line=$(grep -E "^(# )?$search_repo_line" /etc/apt/sources.list)

if [[ -z "$existing_line" ]]; then
    # Repository line does not exist, add it
    print_orange "Adding repository line to sources.list..."
    echo "$repo_line" | run_with_sudo tee -a /etc/apt/sources.list > /dev/null
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
        sign_repo "Let's Go!"
        ;;
    *)
        print_orange "Invalid input. No changes made."
        ;;
esac

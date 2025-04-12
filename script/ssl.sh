#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Display script header with a colored frame
echo -e "${YELLOW}+--------------------------------------------+${NC}"
echo -e "${YELLOW}|                                            |${NC}"
echo -e "${YELLOW}| ${CYAN}OpenSSL Installation Script${NC}                ${YELLOW}|${NC}"
echo -e "${YELLOW}| ${CYAN}For Ubuntu 22, Created by Rede${NC}             ${YELLOW}|${NC}"
echo -e "${YELLOW}|                                            |${NC}"
echo -e "${YELLOW}+--------------------------------------------+${NC}"
echo -e "${CYAN}Do you want to proceed with the installation? [y/n]${NC}"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Installation aborted by user.${NC}"
    exit 1
fi

# OpenSSL versions to install
OPENSSL_VERSIONS=("1.0.2g" "1.1.1u" "1.1.1t")
INSTALL_DIR="$HOME/openssl"
LOG_FILE="$HOME/openssl_install_log.txt"
TMP_DIR="$HOME/tmp"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Array to store installation statuses
declare -A INSTALL_STATUS

# Function for dots animation
animate_dots() {
    local message=$1
    local pid=$2
    local dots=("." ".." "..." "...." "....." "......" "......." "........" "........." ".........." 
                "..........." "............" "............." ".............." "..............." 
                "................" "................." ".................." "..................." 
                "...................." "....................." "......................" 
                "......................." "........................" "........................." 
                ".........................." "..........................." "............................" 
                "............................." ".............................." "..............................." 
                "................................" "................................." ".................................." 
                "..................................." "...................................." "....................................." 
                "......................................" "......................................." "........................................" 
                "........................................." ".........................................." "..........................................." 
                "............................................" "............................................." 
                ".............................................." "..............................................." 
                "................................................" "................................................." 
                "..................................................")
    local i=0
    printf "${YELLOW}%s${NC}" "$message"
    while kill -0 $pid 2>/dev/null; do
        printf "\r${YELLOW}%s%s${NC}" "$message" "${dots[$i]}"
        i=$(( (i + 1) % ${#dots[@]} ))
        sleep 0.5
    done
    wait $pid
    local status=$?
    printf "\r${YELLOW}%s${NC}\n" "$message"
    return $status
}

# Function to install dependencies
install_dependencies() {
    echo -e "${CYAN}${DATE} - Updating package list...${NC}" | tee -a $LOG_FILE
    sudo apt update >> $LOG_FILE 2>&1 &
    animate_dots "Updating package list" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error updating package list${NC}" | tee -a $LOG_FILE
        return 1
    fi

    echo -e "${CYAN}${DATE} - Installing dependencies...${NC}" | tee -a $LOG_FILE
    sudo apt install -y build-essential wget curl libssl-dev >> $LOG_FILE 2>&1 &
    animate_dots "Installing dependencies" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error installing dependencies${NC}" | tee -a $LOG_FILE
        return 1
    fi
    echo -e "${GREEN}${DATE} - Dependencies installed successfully.${NC}" | tee -a $LOG_FILE
}

# Function to install a specific OpenSSL version
install_openssl_version() {
    VERSION=$1
    PREFIX_DIR="$INSTALL_DIR/openssl-$VERSION"
    TAR_FILE="$TMP_DIR/openssl-$VERSION.tar.gz"
    SRC_DIR="$TMP_DIR/openssl-$VERSION"

    echo -e "${YELLOW}Downloading OpenSSL $VERSION...${NC}" | tee -a $LOG_FILE
    wget -q "https://www.openssl.org/source/openssl-$VERSION.tar.gz" -O "$TAR_FILE" --no-check-certificate &
    animate_dots "Downloading OpenSSL $VERSION" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error downloading OpenSSL $VERSION${NC}" | tee -a $LOG_FILE
        INSTALL_STATUS[$VERSION]="Download error"
        return 1
    fi

    echo -e "${YELLOW}Unpacking OpenSSL $VERSION...${NC}" | tee -a $LOG_FILE
    tar -zxf "$TAR_FILE" -C "$TMP_DIR" &
    animate_dots "Unpacking OpenSSL $VERSION" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error unpacking OpenSSL $VERSION${NC}" | tee -a $LOG_FILE
        INSTALL_STATUS[$VERSION]="Unpacking error"
        return 1
    fi
    cd "$SRC_DIR" || { echo -e "${RED}Error: Cannot change to directory $SRC_DIR${NC}" | tee -a $LOG_FILE; INSTALL_STATUS[$VERSION]="Unpacking error"; return 1; }

    echo -e "${YELLOW}Configuring OpenSSL $VERSION...${NC}" | tee -a $LOG_FILE
    ./config --prefix="$PREFIX_DIR" --openssldir="$PREFIX_DIR" shared zlib >> $LOG_FILE 2>&1 &
    animate_dots "Configuring OpenSSL $VERSION" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error configuring OpenSSL $VERSION${NC}" | tee -a $LOG_FILE
        INSTALL_STATUS[$VERSION]="Configuration error"
        return 1
    fi

    echo -e "${YELLOW}Compiling OpenSSL $VERSION...${NC}" | tee -a $LOG_FILE
    make -j$(nproc) >> $LOG_FILE 2>&1 &
    animate_dots "Compiling OpenSSL $VERSION" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error compiling OpenSSL $VERSION${NC}" | tee -a $LOG_FILE
        INSTALL_STATUS[$VERSION]="Compilation error"
        return 1
    fi

    echo -e "${YELLOW}Installing OpenSSL $VERSION...${NC}" | tee -a $LOG_FILE
    make install >> $LOG_FILE 2>&1 &
    animate_dots "Installing OpenSSL $VERSION" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error installing OpenSSL $VERSION${NC}" | tee -a $LOG_FILE
        INSTALL_STATUS[$VERSION]="Installation error"
        return 1
    fi

    echo -e "${YELLOW}Removing temporary files for OpenSSL $VERSION...${NC}" | tee -a $LOG_FILE
    rm -rf "$SRC_DIR" "$TAR_FILE" &
    animate_dots "Removing temporary files for OpenSSL $VERSION" $!

    echo -e "${GREEN}Installed OpenSSL $VERSION to directory $PREFIX_DIR${NC}" | tee -a $LOG_FILE
    INSTALL_STATUS[$VERSION]="Installed"
    return 0
}

# Function to display installation summary table
print_summary_table() {
    # Version without colors for log file
    {
        echo "Installation summary:"
        printf "+-----------------+--------------------+\n"
        printf "| %-15s | %-18s |\n" "Version" "Status"
        printf "+-----------------+--------------------+\n"
        for VERSION in "${OPENSSL_VERSIONS[@]}"; do
            STATUS="${INSTALL_STATUS[$VERSION]:-Not started}"
            printf "| %-15s | %-18s |\n" "$VERSION" "$STATUS"
        done
        printf "+-----------------+--------------------+\n"
    } >> $LOG_FILE

    # Version with colors for terminal
    echo -e "\n${CYAN}Installation summary:${NC}"
    printf "${WHITE}+-----------------+--------------------+${NC}\n"
    printf "${WHITE}| %-15s | %-18s |${NC}\n" "Version" "Status"
    printf "${WHITE}+-----------------+--------------------+${NC}\n"
    for VERSION in "${OPENSSL_VERSIONS[@]}"; do
        STATUS="${INSTALL_STATUS[$VERSION]:-Not started}"
        if [[ "$STATUS" == "Installed" ]]; then
            COLOR="${GREEN}"
        else
            COLOR="${RED}"
        fi
        printf "| %-15s | ${COLOR}%-18s${NC} |\n" "$VERSION" "$STATUS"
    done
    printf "${WHITE}+-----------------+--------------------+${NC}\n"
}

# Main script
echo -e "${CYAN}Starting OpenSSL installation${NC}" | tee $LOG_FILE

# Create temporary directory
mkdir -p "$TMP_DIR"

# Install dependencies
install_dependencies

# Install each version
for VERSION in "${OPENSSL_VERSIONS[@]}"; do
    install_openssl_version "$VERSION"
done

# Display summary
print_summary_table

echo -e "${GREEN}Installation completed. See logs in $LOG_FILE${NC}"


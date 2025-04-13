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
echo -e "${YELLOW}| ${CYAN}System Installation Script${NC}                ${YELLOW}|${NC}"
echo -e "${YELLOW}| ${CYAN}For Ubuntu 18, Created by Rede${NC}           ${YELLOW}|${NC}"
echo -e "${YELLOW}|                                            |${NC}"
echo -e "${YELLOW}+--------------------------------------------+${NC}"
echo -e "${CYAN}Do you want to proceed with the installation? [y/n]${NC}"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Installation aborted by user.${NC}"
    exit 1
fi

# Versions to install
BERKELEY_VERSIONS=("db-4.8.30.NC" "db-5.1.29" "db-5.3.28" "db-6.2.32")
OPENSSL_VERSIONS=("1.0.2g" "1.1.1u" "1.1.1t")
INSTALL_DIR="$HOME/berkeley"
OPENSSL_DIR="$HOME/openssl"
LOG_FILE="$HOME/system_install_log.txt"
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
        INSTALL_STATUS["Dependencies"]="Update error"
        return 1
    fi

    echo -e "${CYAN}${DATE} - Installing dependencies...${NC}" | tee -a $LOG_FILE
    sudo apt install -y build-essential libtool autotools-dev automake pkg-config libssl-dev \
        libevent-dev bsdmainutils libboost-system-dev libboost-filesystem-dev libboost-chrono-dev \
        libboost-program-options-dev libboost-test-dev libboost-thread-dev libboost-all-dev \
        libminiupnpc-dev libzmq3-dev software-properties-common mc aptitude htop lynx \
        apt-transport-https autoconf make gcc g++ screen wget curl ntp libdb4.8-dev libdb4.8++-dev >> $LOG_FILE 2>&1 &
    animate_dots "Installing dependencies" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error installing dependencies${NC}" | tee -a $LOG_FILE
        INSTALL_STATUS["Dependencies"]="Installation error"
        return 1
    fi

    echo -e "${CYAN}${DATE} - Enabling and starting NTP service...${NC}" | tee -a $LOG_FILE
    sudo systemctl enable ntp >> $LOG_FILE 2>&1 &&
    sudo systemctl start ntp >> $LOG_FILE 2>&1 &
    animate_dots "Configuring NTP service" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error configuring NTP service${NC}" | tee -a $LOG_FILE
        INSTALL_STATUS["Dependencies"]="NTP error"
        return 1
    fi

    echo -e "${GREEN}${DATE} - Dependencies installed successfully.${NC}" | tee -a $LOG_FILE
    INSTALL_STATUS["Dependencies"]="Installed"
}

# Function to install a specific Berkeley DB version
install_berkeley_version() {
    VERSION=$1
    VERSION_DIR=$(echo $VERSION | cut -d- -f2)
    PREFIX_DIR="$INSTALL_DIR/db${VERSION_DIR}"
    TAR_FILE="$TMP_DIR/$VERSION.tar.gz"
    SRC_DIR="$TMP_DIR/$VERSION"

    echo -e "${YELLOW}Downloading Berkeley DB $VERSION...${NC}" | tee -a $LOG_FILE
    wget -q "http://download.oracle.com/berkeley-db/$VERSION.tar.gz" -O "$TAR_FILE" &
    animate_dots "Downloading Berkeley DB $VERSION" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error downloading Berkeley DB $VERSION Wound't work with Ubuntu 18${NC}" | tee -a $LOG_FILE
        INSTALL_STATUS["Berkeley $VERSION"]="Download error"
        return 1
    fi

    echo -e "${YELLOW}Unpacking Berkeley DB $VERSION...${NC}" | tee -a $LOG_FILE
    tar -zxf "$TAR_FILE" -C "$TMP_DIR" &
    animate_dots "Unpacking Berkeley DB $VERSION" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error unpacking Berkeley DB $VERSION${NC}" | tee -a $LOG_FILE
        INSTALL_STATUS["Berkeley $VERSION"]="Unpacking error"
        return 1
    fi
    cd "$SRC_DIR" || { echo -e "${RED}Error: Cannot change to directory $SRC_DIR${NC}" | tee -a $LOG_FILE; INSTALL_STATUS["Berkeley $VERSION"]="Unpacking error"; return 1; }

    # Apply modifications for specific versions
    if [[ "$VERSION" == "db-4.8.30.NC" ]]; then
        if [[ -f "./dbinc/atomic.h" && -f "./mutex/mut_tas.c" ]]; then
            echo -e "${YELLOW}Modifying files for Berkeley DB $VERSION...${NC}" | tee -a $LOG_FILE
            sed -i 's/__atomic_compare_exchange/my_atomic_compare_exchange/' ./dbinc/atomic.h
            sed -i 's/__atomic_compare_exchange/my_atomic_compare_exchange/' ./mutex/mut_tas.c
        else
            echo -e "${RED}Required files missing for Berkeley DB $VERSION, skipping modifications...${NC}" | tee -a $LOG_FILE
        fi
    elif [[ "$VERSION" != "db-6.2.32" ]]; then
        if [[ -f "./src/dbinc/atomic.h" && -f "./src/mutex/mut_tas.c" ]]; then
            echo -e "${YELLOW}Modifying files for Berkeley DB $VERSION...${NC}" | tee -a $LOG_FILE
            sed -i 's/__atomic_compare_exchange/my_atomic_compare_exchange/' ./src/dbinc/atomic.h
            sed -i 's/__atomic_compare_exchange/my_atomic_compare_exchange/' ./src/mutex/mut_tas.c
        else
            echo -e "${RED}Required files missing for Berkeley DB $VERSION, skipping modifications...${NC}" | tee -a $LOG_FILE
        fi
    fi

    mkdir -p build_unix
    cd build_unix || { echo -e "${RED}Error: Cannot change to directory build_unix${NC}" | tee -a $LOG_FILE; INSTALL_STATUS["Berkeley $VERSION"]="Configuration error"; return 1; }

    echo -e "${YELLOW}Configuring Berkeley DB $VERSION...${NC}" | tee -a $LOG_FILE
    ../dist/configure --enable-cxx --disable-shared --with-pic --prefix="$PREFIX_DIR" >> $LOG_FILE 2>&1 &
    animate_dots "Configuring Berkeley DB $VERSION" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error configuring Berkeley DB $VERSION${NC}" | tee -a $LOG_FILE
        INSTALL_STATUS["Berkeley $VERSION"]="Configuration error"
        return 1
    fi

    echo -e "${YELLOW}Compiling Berkeley DB $VERSION...${NC}" | tee -a $LOG_FILE
    make -j$(nproc) >> $LOG_FILE 2>&1 &
    animate_dots "Compiling Berkeley DB $VERSION" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error compiling Berkeley DB $VERSION${NC}" | tee -a $LOG_FILE
        INSTALL_STATUS["Berkeley $VERSION"]="Compilation error"
        return 1
    fi

    echo -e "${YELLOW}Installing Berkeley DB $VERSION...${NC}" | tee -a $LOG_FILE
    make install >> $LOG_FILE 2>&1 &
    animate_dots "Installing Berkeley DB $VERSION" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error installing Berkeley DB $VERSION${NC}" | tee -a $LOG_FILE
        INSTALL_STATUS["Berkeley $VERSION"]="Installation error"
        return 1
    fi

    echo -e "${YELLOW}Removing temporary files for Berkeley DB $VERSION...${NC}" | tee -a $LOG_FILE
    rm -rf "$SRC_DIR" "$TAR_FILE" &
    animate_dots "Removing temporary files for Berkeley DB $VERSION" $!

    echo -e "${GREEN}Installed Berkeley DB $VERSION to directory $PREFIX_DIR${NC}" | tee -a $LOG_FILE
    INSTALL_STATUS["Berkeley $VERSION"]="Installed"
    return 0
}

# Function to install a specific OpenSSL version
install_openssl_version() {
    VERSION=$1
    PREFIX_DIR="$OPENSSL_DIR/openssl-$VERSION"
    TAR_FILE="$TMP_DIR/openssl-$VERSION.tar.gz"
    SRC_DIR="$TMP_DIR/openssl-$VERSION"

    echo -e "${YELLOW}Downloading OpenSSL $VERSION...${NC}" | tee -a $LOG_FILE
    # Use different URL for older version (1.0.2g)
    if [[ "$VERSION" == "1.0.2g" ]]; then
        wget -q "https://www.openssl.org/source/old/1.0.2/openssl-$VERSION.tar.gz" -O "$TAR_FILE" --no-check-certificate &
    else
        wget -q "https://www.openssl.org/source/openssl-$VERSION.tar.gz" -O "$TAR_FILE" --no-check-certificate &
    fi
    animate_dots "Downloading OpenSSL $VERSION" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error downloading OpenSSL $VERSION${NC}" | tee -a $LOG_FILE
        INSTALL_STATUS["OpenSSL $VERSION"]="Download error"
        return 1
    fi

    echo -e "${YELLOW}Unpacking OpenSSL $VERSION...${NC}" | tee -a $LOG_FILE
    tar -zxf "$TAR_FILE" -C "$TMP_DIR" &
    animate_dots "Unpacking OpenSSL $VERSION" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error unpacking OpenSSL $VERSION${NC}" | tee -a $LOG_FILE
        INSTALL_STATUS["OpenSSL $VERSION"]="Unpacking error"
        return 1
    fi
    cd "$SRC_DIR" || { echo -e "${RED}Error: Cannot change to directory $SRC_DIR${NC}" | tee -a $LOG_FILE; INSTALL_STATUS["OpenSSL $VERSION"]="Unpacking error"; return 1; }

    echo -e "${YELLOW}Configuring OpenSSL $VERSION...${NC}" | tee -a $LOG_FILE
    ./config --prefix="$PREFIX_DIR" --openssldir="$PREFIX_DIR" shared zlib >> $LOG_FILE 2>&1 &
    animate_dots "Configuring OpenSSL $VERSION" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error configuring OpenSSL $VERSION${NC}" | tee -a $LOG_FILE
        INSTALL_STATUS["OpenSSL $VERSION"]="Configuration error"
        return 1
    fi

    echo -e "${YELLOW}Compiling OpenSSL $VERSION...${NC}" | tee -a $LOG_FILE
    make -j$(nproc) >> $LOG_FILE 2>&1 &
    animate_dots "Compiling OpenSSL $VERSION" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error compiling OpenSSL $VERSION${NC}" | tee -a $LOG_FILE
        INSTALL_STATUS["OpenSSL $VERSION"]="Compilation error"
        return 1
    fi

    echo -e "${YELLOW}Installing OpenSSL $VERSION...${NC}" | tee -a $LOG_FILE
    make install >> $LOG_FILE 2>&1 &
    animate_dots "Installing OpenSSL $VERSION" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error installing OpenSSL $VERSION${NC}" | tee -a $LOG_FILE
        INSTALL_STATUS["OpenSSL $VERSION"]="Installation error"
        return 1
    fi

    echo -e "${YELLOW}Removing temporary files for OpenSSL $VERSION...${NC}" | tee -a $LOG_FILE
    rm -rf "$SRC_DIR" "$TAR_FILE" &
    animate_dots "Removing temporary files for OpenSSL $VERSION" $!

    echo -e "${GREEN}Installed OpenSSL $VERSION to directory $PREFIX_DIR${NC}" | tee -a $LOG_FILE
    INSTALL_STATUS["OpenSSL $VERSION"]="Installed"
    return 0
}

# Function to display installation summary table
print_summary_table() {
    # Version without colors for log file
    {
        echo "Installation summary:"
        printf "+-------------------------+--------------------+\n"
        printf "| %-23s | %-18s |\n" "Component" "Status"
        printf "+-------------------------+--------------------+\n"
        printf "| %-23s | %-18s |\n" "Dependencies" "${INSTALL_STATUS[Dependencies]:-Not started}"
        for VERSION in "${BERKELEY_VERSIONS[@]}"; do
            printf "| %-23s | %-18s |\n" "Berkeley $VERSION" "${INSTALL_STATUS[Berkeley $VERSION]:-Not started}"
        done
        for VERSION in "${OPENSSL_VERSIONS[@]}"; do
            printf "| %-23s | %-18s |\n" "OpenSSL $VERSION" "${INSTALL_STATUS[OpenSSL $VERSION]:-Not started}"
        done
        printf "+-------------------------+--------------------+\n"
    } >> $LOG_FILE

    # Version with colors for terminal
    echo -e "\n${CYAN}Installation summary:${NC}"
    printf "${WHITE}+-------------------------+--------------------+${NC}\n"
    printf "${WHITE}| %-23s | %-18s |${NC}\n" "Component" "Status"
    printf "${WHITE}+-------------------------+--------------------+${NC}\n"
    STATUS="${INSTALL_STATUS[Dependencies]:-Not started}"
    if [[ "$STATUS" == "Installed" ]]; then COLOR="${GREEN}"; else COLOR="${RED}"; fi
    printf "| %-23s | ${COLOR}%-18s${NC} |\n" "Dependencies" "$STATUS"
    for VERSION in "${BERKELEY_VERSIONS[@]}"; do
        STATUS="${INSTALL_STATUS[Berkeley $VERSION]:-Not started}"
        if [[ "$STATUS" == "Installed" ]]; then COLOR="${GREEN}"; else COLOR="${RED}"; fi
        printf "| %-23s | ${COLOR}%-18s${NC} |\n" "Berkeley $VERSION" "$STATUS"
    done
    for VERSION in "${OPENSSL_VERSIONS[@]}"; do
        STATUS="${INSTALL_STATUS[OpenSSL $VERSION]:-Not started}"
        if [[ "$STATUS" == "Installed" ]]; then COLOR="${GREEN}"; else COLOR="${RED}"; fi
        printf "| %-23s | ${COLOR}%-18s${NC} |\n" "OpenSSL $VERSION" "$STATUS"
    done
    printf "${WHITE}+-------------------------+--------------------+${NC}\n"
}

# Main script
echo -e "${CYAN}Starting system installation${NC}" | tee $LOG_FILE

# Create temporary directory
mkdir -p "$TMP_DIR"

# Install dependencies
install_dependencies

# Install Berkeley DB versions
for VERSION in "${BERKELEY_VERSIONS[@]}"; do
    install_berkeley_version "$VERSION"
done

# Install OpenSSL versions
for VERSION in "${OPENSSL_VERSIONS[@]}"; do
    install_openssl_version "$VERSION"
done

# Clean up temporary directory
echo -e "${YELLOW}Cleaning up temporary directory...${NC}" | tee -a $LOG_FILE
rm -rf "$TMP_DIR" &
animate_dots "Cleaning up temporary directory" $!
echo -e "${GREEN}Temporary directory cleaned up.${NC}" | tee -a $LOG_FILE

# Display summary
print_summary_table

echo -e "${GREEN}Installation completed. See logs in $LOG_FILE${NC}"

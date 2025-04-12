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
echo -e "${YELLOW}| ${CYAN}Berkeley DB Installation Script${NC}            ${YELLOW}|${NC}"
echo -e "${YELLOW}| ${CYAN}For Ubuntu 22, Created by Rede${NC}             ${YELLOW}|${NC}"
echo -e "${YELLOW}|                                            |${NC}"
echo -e "${YELLOW}+--------------------------------------------+${NC}"
echo -e "${CYAN}Do you want to proceed with the installation?${NC}"
echo -e "${RED}${NC}"
echo -e "${RED}               [y/n]${NC}"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Installation aborted by user.${NC}"
    exit 1
fi

# Database versions to install
DB_VERSIONS=("db-4.8.30.NC" "db-5.1.29" "db-5.3.28" "db-6.2.32")
INSTALL_DIR="$HOME/berkeley"
LOG_FILE="$HOME/db_install_log.txt"
TMP_DIR="/tmp/berkeley_db_install"
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

# Function to remove previous installations
remove_old_installations() {
    echo -e "${CYAN}${DATE} - Removing old installations...${NC}" | tee -a $LOG_FILE
    rm -rf $INSTALL_DIR/* $TMP_DIR
    mkdir -p $TMP_DIR
    echo -e "${GREEN}${DATE} - Removed old installations and created temporary directory.${NC}" | tee -a $LOG_FILE
}

# Function to install a specific DB version
install_db_version() {
    VERSION=$1
    PREFIX_DIR="$INSTALL_DIR/$(echo $VERSION | cut -d- -f2)"
    TAR_FILE="$TMP_DIR/$VERSION.tar.gz"
    SRC_DIR="$TMP_DIR/$VERSION"

    echo -e "${YELLOW}Downloading $VERSION...${NC}" | tee -a $LOG_FILE
    wget -q "http://download.oracle.com/berkeley-db/$VERSION.tar.gz" -O "$TAR_FILE" &
    animate_dots "Downloading $VERSION" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error downloading $VERSION${NC}" | tee -a $LOG_FILE
        INSTALL_STATUS[$VERSION]="Download error"
        return 1
    fi

    echo -e "${YELLOW}Unpacking $VERSION...${NC}" | tee -a $LOG_FILE
    tar -zxf "$TAR_FILE" -C "$TMP_DIR" &
    animate_dots "Unpacking $VERSION" $!
    cd "$SRC_DIR" || { echo -e "${RED}Error: Cannot change to directory $SRC_DIR${NC}" | tee -a $LOG_FILE; INSTALL_STATUS[$VERSION]="Unpacking error"; return 1; }

    # Apply modifications only for versions that require it
    if [[ "$VERSION" == "db-4.8.30.NC" ]]; then
        if [[ -f "./dbinc/atomic.h" && -f "./mutex/mut_tas.c" ]]; then
            echo -e "${YELLOW}Modifying files for version $VERSION...${NC}" | tee -a $LOG_FILE
            sed -i 's/__atomic_compare_exchange/my_atomic_compare_exchange/' ./dbinc/atomic.h
            sed -i 's/__atomic_compare_exchange/my_atomic_compare_exchange/' ./mutex/mut_tas.c
        else
            echo -e "${RED}Required files missing for version $VERSION, skipping modifications...${NC}" | tee -a $LOG_FILE
        fi
    elif [[ "$VERSION" != "db-6.2.32" ]]; then
        if [[ -f "./src/dbinc/atomic.h" && -f "./src/mutex/mut_tas.c" ]]; then
            echo -e "${YELLOW}Modifying files for version $VERSION...${NC}" | tee -a $LOG_FILE
            sed -i 's/__atomic_compare_exchange/my_atomic_compare_exchange/' ./src/dbinc/atomic.h
            sed -i 's/__atomic_compare_exchange/my_atomic_compare_exchange/' ./src/mutex/mut_tas.c
        else
            echo -e "${RED}Required files missing for version $VERSION, skipping modifications...${NC}" | tee -a $LOG_FILE
        fi
    fi

    mkdir -p build_unix
    cd build_unix || { echo -e "${RED}Error: Cannot change to directory build_unix${NC}" | tee -a $LOG_FILE; INSTALL_STATUS[$VERSION]="Configuration error"; return 1; }

    echo -e "${YELLOW}Configuring $VERSION...${NC}" | tee -a $LOG_FILE
    ../dist/configure --enable-cxx --disable-shared --with-pic --prefix="$PREFIX_DIR" >> $LOG_FILE 2>&1 &
    animate_dots "Configuring $VERSION" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error configuring $VERSION${NC}" | tee -a $LOG_FILE
        INSTALL_STATUS[$VERSION]="Configuration error"
        return 1
    fi

    echo -e "${YELLOW}Compiling $VERSION...${NC}" | tee -a $LOG_FILE
    make -j$(nproc) >> $LOG_FILE 2>&1 &
    animate_dots "Compiling $VERSION" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error compiling $VERSION${NC}" | tee -a $LOG_FILE
        INSTALL_STATUS[$VERSION]="Compilation error"
        return 1
    fi

    echo -e "${YELLOW}Installing $VERSION...${NC}" | tee -a $LOG_FILE
    make install >> $LOG_FILE 2>&1 &
    animate_dots "Installing $VERSION" $!
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error installing $VERSION${NC}" | tee -a $LOG_FILE
        INSTALL_STATUS[$VERSION]="Installation error"
        return 1
    fi

    echo -e "${YELLOW}Removing temporary files for $VERSION...${NC}" | tee -a $LOG_FILE
    rm -rf "$SRC_DIR" "$TAR_FILE" &
    animate_dots "Removing temporary files for $VERSION" $!

    echo -e "${GREEN}Installed version $VERSION to directory $PREFIX_DIR${NC}" | tee -a $LOG_FILE
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
        for VERSION in "${DB_VERSIONS[@]}"; do
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
    for VERSION in "${DB_VERSIONS[@]}"; do
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
echo -e "${CYAN}Starting Berkeley DB installation${NC}" | tee $LOG_FILE

# Remove old installations and create temporary directory
remove_old_installations

# Install each version
for VERSION in "${DB_VERSIONS[@]}"; do
    install_db_version "$VERSION"
done

# Display summary
print_summary_table

echo -e "${GREEN}Installation completed. See logs in $LOG_FILE${NC}"


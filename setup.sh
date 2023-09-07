#!/bin/sh

set -ue

#########################################
# Environment variable
#########################################

### Set enviroment parameters
DEPLOY_FLG="a"
REMOVE_FLG=""
REQUIRED_MEM_TOTAL=4000000
REQUIRED_FREE_FOR_CONTAINER_IMAGE=25600
REQUIRED_FREE_FOR_EXASTRO_DATA=1024
DOCKER_COMPOSE_VER="v2.20.3"
PROJECT_DIR="${HOME}/exastro-docker-compose"
COMPOSE_FILE="${PROJECT_DIR}/docker-compose.yml"
LOG_FILE="${HOME}/exastro-installation.log"
ENV_FILE="${PROJECT_DIR}/.env"
COMPOSE_PROFILES="except-gitlab"
if [ -f ${ENV_FILE} ]; then
    . ${ENV_FILE}
fi

#########################################
# Utility functions
#########################################

### Logger functions
info() {
    echo `date`' [INFO]:' "$@" | tee -a "${LOG_FILE}"
}
warn() {
    echo `date`' [WARN]:' "$@" >&2 | tee -a "${LOG_FILE}"
}
error() {
    echo `date`' [ERROR]:' "$@" >&2 | tee -a "${LOG_FILE}"
    exit 1
}

### Convert to lowercase
to_lowercase() {
    echo "$1" | sed "y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/"
}

### Generate password
generate_password() {
    # Specify the length of the password
    length="$1"
    # Generate a random password
    password=$(dd if=/dev/urandom bs=1 count=100 2>/dev/null | base64 | tr -dc 'a-zA-Z0-9' | fold -w $length | head -n 1)
    # Display the generated password
    echo $password
}

### Check System
get_system_info() {
    if [ $(to_lowercase $(uname)) != "linux" ]; then
        error "Not supported OS."
    fi

    ARCH=$(uname -p)
    OS_TYPE=$(uname)
    OS_NAME=$(awk -F= '$1=="NAME" { print $2; }' /etc/os-release | tr -d '"')
    VERSION_ID=$(awk -F= '$1=="VERSION_ID" { print $2; }' /etc/os-release | tr -d '"')
    if [ "${OS_NAME}" = "Red Hat Enterprise Linux" ]; then
        if [ $(expr "${VERSION_ID}" : "^8\..*") != 0 ]; then
            DEP_PATTERN="RHEL8"
        fi
    elif [ "${OS_NAME}" = "AlmaLinux" ]; then
        if [ $(expr "${VERSION_ID}" : "^8\..*") != 0 ]; then
            DEP_PATTERN="AlmaLinux8"
        fi
    elif [ "${OS_NAME}" = "Ubuntu" ]; then
        if [ $(expr "${VERSION_ID}" : "^20\..*") != 0 ]; then
            DEP_PATTERN="Ubuntu20"
        elif [ $(expr "${VERSION_ID}" : "^22\..*") != 0 ]; then
            DEP_PATTERN="Ubuntu22"
        fi
    fi
}

#########################################
# Main functions
#########################################
main() {
    if [ "$#" = 0 ]; then
        cat <<'_EOF_'

Usage:
  sh <(curl -Ssf https://ita.exastro.org/setup) COMMAND [options]
     or
  setup.sh COMMAND [options]

Commands:
  install     Installation Exastro system
  remove      Remove Exastro system

_EOF_
        exit 2
    fi

    SUB_COMMAND="$1"

    case "$SUB_COMMAND" in
        install)
            shift
            install "$@"
            break
            ;;
        remove)
            shift
            remove "$@"
            break
            ;;
        *)
            cat <<'_EOF_'

Usage:
  sh <(curl -Ssf https://ita.exastro.org/setup) COMMAND [options]
     or
  setup.sh COMMAND [options]

Commands:
  install     Installation Exastro system
  remove      Remove Exastro system

_EOF_
            exit 2
            ;;
    esac
}

### Get options when install
install() {
    args=$(getopt -o "ciferph" --long "check,install-packages,fetch,setup-env,regist-service,print,help" -- "$@") || exit 1

    eval set -- "$args"

    while true; do
        case "$1" in
            -c | --check )
                shift
                DEPLOY_FLG="c"
                ;;
            -i | --install-packages )
                shift
                DEPLOY_FLG="i"
                ;;
            -f | --fetch )
                shift
                DEPLOY_FLG="f"
                ;;
            -e | --setup-env )
                shift
                DEPLOY_FLG="e"
                ;;
            -r | --regist-service )
                shift
                DEPLOY_FLG="r"
                ;;
            -p | --print )
                shift
                DEPLOY_FLG="p"
                ;;
            -- )
                shift
                break
                ;;
            * )
                shift
                cat <<'_EOF_'

Usage:
  exastro install [options]

Options:
  -c, --check                       Check if your system meets the requirements
  -i, --install-packages            Only install required packages and fetch exastro source files
  -f, --fetch                       Only fetch Exastro resources.
  -e, --setup                       Only generate environment file (.env)
  -r, --regist-service              Only install exastro service
  -p, --print                       Print Exastro system information.

_EOF_
                exit 2
                ;;
        esac
    done

    info "======================================================"
    info "Start to setup Exastro system."
    get_system_info
    case "$DEPLOY_FLG" in
        a )
            if [ ! -f ${ENV_FILE} ]; then
                banner
                check_requirement
                installation_container_engine
                fetch_exastro
                setup
                installation_exastro
                start_exastro
            fi
            prompt
            ;;
        c )
            banner
            check_requirement
            ;;
        i )
            banner
            check_requirement
            installation_container_engine
            ;;
        f )
            if [ ! -f ${ENV_FILE} ]; then
                banner
                fetch_exastro
            fi
            ;;
        e )
            if [ -f ${ENV_FILE} ]; then
                banner
                setup
            else
                error "Exasto system in NOT installed."
            fi
            ;;
        r )
            if [ -f ${ENV_FILE} ]; then
                banner
                installation_exastro
            else
                error "Exasto system in NOT installed."
            fi
            ;;
        p )
            if [ -f ${ENV_FILE} ]; then
                prompt
            else
                error "Exasto system in NOT installed."
            fi
            ;;
        * )
            ;;
    esac
        
}

### Banner
banner(){
    # Get window width
    WIN_WIDTH=$(tput cols 2>/dev/null)

    if [ "${WIN_WIDTH}" = "" ] || [ "${WIN_WIDTH}" -lt 80 ]; then
        # Small banner
        cat <<'_EOF_'
################################################
#
# Exastro IT Automation
#
################################################


_EOF_

    elif [ "${WIN_WIDTH}" -lt 100 ]; then

        # Middle banner
        cat <<'_EOF_'
===============================================================================
|     _____               _                                                   |
|    | ____|_  ____ _ ___| |_ _ __ ___                                        |
|    |  _| \ \/ / _` / __| __| '__/ _ \                                       |
|    | |___ >  < (_| \__ \ |_| | | (_) |                                      |
|    |_____/_/\_\__,_|___/\__|_|  \___/                                       |
|                                                                             |
|     ___ _____      _         _                        _   _                 |
|    |_ _|_   _|    / \  _   _| |_ ___  _ __ ___   __ _| |_(_) ___  _ __      |
|     | |  | |     / _ \| | | | __/ _ \| '_ ` _ \ / _` | __| |/ _ \| '_ \     |
|     | |  | |    / ___ \ |_| | || (_) | | | | | | (_| | |_| | (_) | | | |    |
|    |___| |_|   /_/   \_\__,_|\__\___/|_| |_| |_|\__,_|\__|_|\___/|_| |_|    |
|                                                                             |
===============================================================================


_EOF_

    elif [ "${WIN_WIDTH}" -gt 300 ]; then

        # Middle banner
        cat <<'_EOF_'

 .        .. .... :O0OOXNNXXNNXXXKO0KXXNX0llXNNWWN0Okdko;lKNXddOXXKNWX0NWWWNNNK0xoloooOXNNNNNNNNNNNNXNNXXXXKKKK0KKKKXXNNNNNNNNNNNWWWWWWWNNNNNNNNNNWWWWWWWNNNNNNNO,...'':kk000KKKOxdO00KK0O000OONNWWWWWWX0KXKNWWWk:oxodKWWWXXXKKKKKKKKKKKKKKKKKKKKKKKKXKKKKKKKKKKKKKXXKKKKXXKKKXXXXXKXXXXXKO0KKNWWWNXNWWWWWWWN
..       ..  ... :O0O0XNNNNNNXXX0O0XXXNX0loNNNWWN0OkdddoxXNO;lKNXXNNKKWWWWNWN00xlxXXXXXXXXXXXXXXNXXXXXXXXXXXXXXXXKXXKKXXXXXXXKKXNWWWWWWNNNNNNNNNNNNNNNWWWWWWWWNx......,xccxkOOxkdoO0000OO000OONNWWWNWWX0KXKNWWWOcoxddXWNNXXX000000000000000000000000000O000000000000000KK0OO0KKKK000KKKX0O0KK0XNNWNXNWWWWWWN
..       ..  ... :O0OOXNNXXNNXXXK0KXNNNXKkONNNWWNOdx0KK0XNNd,oXNXNNN0XWWWWWWKkOxok00K0000000000000000000000000000OO0OOOOO0000OO0NNWWWNNNNNNNNNNNNNNNNNNNNNNNNWNOoxo,'.;xc;cclooOxxO0000OO000OONNWWWWWWXKKXKNWWWOloddxXNXNNXNOxxxxxxxxxxxxxxxxxxxxxxxxxxddddxxdxxxxxxxxxxxxddxkkkxxdxxkO0000K0lcOX0dONWWWWWNN
.........''..',,.lO000XNNXXXXXXKKO0XXXXX0kOXXXXNXOOO0000KXKddOXXXXXKOKXXXKKKOxkkOkkkkkkkkkkkkxkkkxxkkkkkkkkkkOOOOOOOOOOOOOOOOOOO000000000000OOOOkkkkkOkOOOOOOOO00OOkkkkOkkkkkkkkkkkkkkkkOOOOOO000OO00OOOOOO000OOkkkOkO0OOOOOOkkOOOOOOOOOOO00OOOOOOOOOOOOOOOOOOOOOOOOkOOOkOkkkkkkOkkkkOOOOOOOOkkOOkkOO00000OO
loodddddxxxxxkkkkkkkkkkkkkkkkkkkkkkkkkxxxxkkkkkkkkkkkkkkkkkkkkkkkkkxkkkkkxxxkkxkkxxxkxxkkkxxxxxxddddxxxxkxxxxxkkkkkkOkkkkOOOOOOOOOOOOOOkOkkkkdoolccc:::clodkkkkkkkkkkkkkkkkkkkkkkxkxxkkkkkkkkOOOOkkOOOkkkOkkkkkkkkkkkkkxxxxkkkkkkkkkOOOOOOOOOkOOOOOOOOOOOOOOOOOOOOOOOOkkOkkkkkOOOOOOOOOkkOOOOOOOOOOOOOOOOOkk
oddddxxxxkkkkkkkkkkkkkkkkkkkkkkkkkxxxxxkkxxxkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkxxxkkxxxxkkkxxxxxxxxxkkkkkkkkkkkOOOOOOxxxxkkkxdoc;'''....'''',,;:ldxkkkkkkkxxxxxkkkkxxxxxxxxxxxkkkxkkkkxxxkkxxxxxxxxxkkkkxkxxkkkkxkkkkkkkkkkkkkkkkkkkkkOOOkOkkkkkkkOOOkkkkkkkkkkkkkkkkkkkOOOOOOOkkkkOOOOOOOOOOOOO
ddxxxxkkkkkkkkkkkkkkkkkxkkxxkkkkkxxxkkkkkkkkkkkkkkkkkkkkkkOkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkxkkkkkkkxxxxxxxxxkkkkkkkkkkkxdlooooollc,..........,,,,,;;;;;;:codxxxxxxxxxxxxxxxxxxxkkxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxkkkkxkxxxkkkkkkkkkkkkkkkkkOkkkkkkkkkkkkkkkkkkkkkkkkkkkOOkkkkkOOkkkkkkkOOkkkkkkkOOkkO
dddxxkkkkkkkkkkkxxkkkkkxxkxxxxxxxkkxxxxxkxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxkkkkOOkkO0000OkkkkOOO000K000KKKKKKKKKKKXK0Oxl::loddc:.....     ........'''....'',;clcccclccccclllllllooooooddddddxkkkOOOOOOOOOOOOOOOOOOOOOOOOkkkkkkkkkkkkkOOOkkxxdooooddxxxdddddddoddoooooooooooooooooooooooooodddddddxxxx
....................................... ... .                      .. .....................''''..........''...'''.'''.',;:;;,'..'',''....            ......''','.....''..                                                                                                                                   
                                                                               .......................................''.''''..'...'',' ... . ....       .......',,,'''','.                                                                                                                                 
                                                                             ........................................'''''............,'''.........        ...........''''''.                                                    . ...                ..            .                                       
                                                                          .........................................'''''................................     ...',,,,.......'..              .                    ..........................................................................................
                                                                         ........................................'''''........ ............ ..........'''...    ...'''''.... ....          ............... .................................................................................................
.                                                                        ................................'.'..'...''........ ...........    ...,.....................'.......  .,.         .................................................................................................................
..       .                                                              ............................'''''''.'.'''''............'......    .....''.......'''',,'................ .'.....................lxxxxxdlllccc:::;;;,,'...............................................................................
..       .                                                             .................................'..'....'... .........'........................,,;::lol:,''..............';docc::;;,,,,'. .....0WWWWNN0xdolcllcc:;,''.  ............................................................................
..       .                                                             ......................................'.'..   ......'........ .''............',;:codxkOOxdol:;;,;'.. .. ..'';'............ ... .ONWNNNXd.....':;;,,....    ..........................................................................
..       ..                        .cllcclol;,;c:;,',,,,''..........   ..........................................  ......'.......... ..'..    .....,clloxO0O000OOOkxdolclc;.... .'';;............ ... .kKKK00Xd,c;'';cc:;;'.'.    ..........................................................................
..       ..                    ':ccxXNXKKNWKlldOxoc:::;;;;;''........,:ccll::cccc:;::;,',,,'..................... .. ....................      ...,:odxO0KKKKKKK00000Okkxdo;...  ...:.........;:;;;,',;0XK0KXXx;ooooooolcc,...   ...........................................................................
..       ..              ...  .cxkkxXNNXNNWXddx00kodoclcllc:lO0Odlc:kXNNXNKO000Oo:cloc;,,,,,.     ....................... ..................  ...;:oxO0KKKKKKKKKKKKKK000OOkxlcc. ...c:clc;,,;;0NNNN0xddXWNNWNNx:ddocldolc:'.'.:::;;;,,,;;,''................................................................
..       ..          .:oxxkx:,,lkKKkKWNXXXWNxox00kddxcc:;,:;lKXKkoc;oKXKXXxccx0d:'',;;,......       .................  ..  .. ..........     ...;ldk0KKKKXXKKKKKKKKKKKKKK000000x....,;dkl;,,;,cxOkxxoloXWWWWWNx:lc:,ldolc;'''cXXXOxo::loolc:,... ...........................................................
..       ..      ..  .:k0xkxc;,ckKXOKNNXOONWOdkO0Ox:,.....,cl0NXOdc;:xOkKX0,',;'......'....          ........ . ....  ..  ... ..........   . .';oxO0KKKKXXXKKKKKKKKKKKKKKKKKKKK0o...';x0xlc:;;;lxl:'..;XWWWMWNd;:c:cdxdodkkkxkXKKkdc:cloolc;,...  ..........................................................
..       ..           'cddxkl:,ck0KkKNNXOkNWOodk0Ok:,':ol',lcONX0xl,:0K0XXxc:;cc,':;,lc.,;...         .......  .    ...  .... ....... ..   ..:odkO00KKKKKXXXXXKKKKKKKKKKKKKKKKK00:..;c0XK0OkdoloxlcdxdlNWWWWWNx:lccOKXKkxNWWNNWWXkoc:loolc:;,...............................................................
..       ..     ...   ,xXKllc;,;xOOO0NWNKOXW0llx0Okl;;ckx;cOdkNN0ko;lXX0OxoOk:od;;occddooc:cc::;,,.  ........  .   ...    .......       ...;ldkO000000KKKXXXXXXKKKKKKKKKKK0OOkxllc,;:oKXNWWXOdookocKNKxNWWWWWNxcoll0KXKxxNWWNNWWKxdlcoooc::,'... ...........................................................
...      ..   .....   'dXKc;;,,,dOOOOXNNX0XWXoox000k:;:kkclkoxNNKOxco0kllllcc;,,xXNNXKKKK0000000OOkkkkkkkkko...    ..     ... .         .':dkOOO00000KKKKXKKK00000O000000Okxo:,,:oo;:;oONWWNklllxoc0OOxNWWWWWNxoocl0KXK0KNWWNWWW0xdlcoolcodolccccllcc:,.....................................................
...      ..   .....   .oK0oll;:;dOOOOKNNXKXWNdcoO00Oc;:xOllkdxNNK0xockOolldl:::;OXNNX0OO0KKKKKKXXXXXXXXXXXXd...           ...          .;lxOOOOOOOO0000OxxddlclooddxxOOOOkdlccdO00x;::dkNWWN0xdxxxoKNXkNWWWWWNxdl:o0Ox0NNWWWNWWN0xolllccoXWWX0K00Okkxxc:cccccccl:;::,.......................................
...      ..    ...    .o0OxOd::;d00K00XNNNNWNo;:k00Ol;;dOocxxdXNX0kddOkllOXKxlOO0NNWNK00KKKKKKXNXXXXXXNNNNNkl;                        .cxkOOOOOOOOO0kxxxxxdolccccloodxkOkxooxkkxdddlc;odXWWNOxOXKKOx0OoNWWWWWNxdocoKO0KXKWWNXWWNOxddol;;xXNNNNOxOOkkkxdXNWNNK0OOkxdo:.......................................
...       .     ..    .l0Oldxcccd0KKKOKXNXXWWd;;kK0Oo;;oOdlxkdXWX0kdxOddKNXKdoOk0NNWNKOO0KKKKXNNXXXXXXXXNNNXK0.                     .'cxkOOOOOOOO0OOkO0KKKKKKK0Okdddxk0OOoododo.,ok0xc00XNWNXNX0K0xOO0kNWWWWWNxoc:d0OOKXXWWNXWWXOk0KKOkckXNNWNOkOOkOKK0XNNWNKkxkkxol;.......................................
...       .           .ckkcllclld0KXKOkKN0kNWk,,xK0Od;;ckxoxOdKNXOl:dOkoodd:;lxckXNWNK00KKKKXNNOxxxxxxxxxxxxkk'.                   .'cdkOOO0000O00OOOO000OOkdccclddkO0KXXOkdxkkxOO0KkcKKNNWNNNKKXO:loooNWWWWWNdl:;d0kkXXNWWXXWWKOk0NXKOl0NNNWX00000KNXKNNNNNKOkOkdllccloddddddxdxddddddoollcc:,.............
...       .           .:dd,.';odx0KKK0OKNXOXW0;,o00Ox;;:kOxxkd0NXd;clcllcoko,;:;xXNWNXXKXXXXNWXxdxxxxxkkkkkkOkd.        .          .;oxkkOO00KKK000Okxxdddxkd,;lldOKKKKXXX0Okxxxxk0KOc00XNWNNNKO00xokooNWWWWWXdc:;x0kkXXNWWXNWN0kxKNXKxoXNWWNXKKXNNXNKKNNNNN0kkOkdoooddxxxxkkk0KK0kkkkkkkxxxxxl. ...........
...       .           .....,:;ldd0KXXK0XNNXNWXc,cO0Ox:;;xOkxkoONXl;lollcccl:;;;,oXNWNXKKKXXNWW0dxxxxxkkOkkxkOOOc     ..',.....    .':ldkkOO00KKKXXXXKKKKKKK00OOxk0KXXKKKXXXKK0OO0KXK0lxxXWWNNNXK0KkkX0kNWWWWWXdl;;k0O0NXWWWXWWXOxkKXKKddXNWWNXXXNNXKK0KNWWWX0kO0kdddxxxkk0OOkO0X0OOKXKOOkkkkkxocclllllllllcc
...       .             ...cd;cl:OXXXK0KNN0KWNl,:kOOk:,;dOkxdlkNXl,coc;::cc:;;;,oXNWNXXXXXNNWNkxxxkkkOOOOOOkkkkk;  .':ccl::;,'.   .';ldxkkO00KKKXXXXXXKK00OOOkO0KKKXXXKKXXXXKKKXXKK00oxkXWWNXNX000OO0ddNWWWWWXoc;;k0O0NNWWNXWWKxkOXNX0cxXNWWNNNXNNXXXOKNWNWNKK00kxxxxkOOOK0OO0XNK00XNX0OOOOOOxdkOO0000OOO0OO
...       .            .'..;o;lo;kXXXK0KNNKONNd,;k00Oc,,oOkkkkdX0::lc:clllc;;cocoXNWNNXXXNNWN0xkkkkkkkkOOOOkkkxkx. .'odokxl:;:. ...':ldxkkkO000KKKXXXXXXXXXXXXXKKKKKXKKKXXXXK0KKKK00OlxxKWWNXNKoollKKKONWWWWWXlolcO0kONNWWXXWNOxk0NNX0dkKNNWNNNNNNXXKOXNWNNXKKK0kkkkkOOOKK000KXK00KNNX000000OkkO000000000000
...       .            ....'c;:o:kXXXXK0NNXkNNk,;x000o:clkOkOOdXO::lc:lodl::;cocdXNWNNNXXNWWNkkkkkkkOOOOOOOOkkkkKK.  ,kxOdlool;'..,;ldxxxkkOO0000KKKKKXXXKXXKKKKKKKKKKKKXXXXXK00000OOdloKWWNXNKoxocOkOkNWWWWWXooc:O0O0NNWWXNWNOxk0NXKkoxO0XWNNNNNNXXKOXWWWNXKK0OkkOOOO00XK000XXXKKXNNXK000000XNNNNNNNNNNNNNX
...       .            .'....',;;xXXXXK0XNXkXW0,,dO00xddlxOOkOdXXdcc:;cooooc;clcoKNWNNNXNWWN0kkkOOOOOOOOOOOOkOk0NWO.  ,kkkxkxool::ldkkkkkkkkkkOO00000KKKKXKKKK000OkO0KKKKKKKKKOOOOOkOx;:KNWNNNKodocK00kNWNWWWXol;;O0O0XXWWXNWXkxkKNKOddx00XWNNNNNXXX0ONWWWNXKK0OOOO0000KXKKKXXXNXKXNXK0000000NNxdxxxxkOOOOO0
...                     .....',;;dXNNX0OKNNOKWK:,lOO0kdocxOOkkoKN0kxc,;:::::;coloKXNNNNNNWWXkkOOOOOOOOOOOOOOOkkXWWWd   ;kkkOkkxdodkOOOOOkkkkkkkkkOO00000000000OkkkkO000OkOOOOkOOkkkkkc.,KNWNXNXoolcOkOkNWWNWWK:;,:0Ok0Kdod0NNKxxOXNKOxdxO0XNNNNNNXXKO0WWWWNXKKOkO0000KKNNXKNNXXNKKXXK000000OKWXodxxxkxxxxxxx
...                      .....';;oKXK0kOKNNO0WNc;dO00x:,,okddkd0XKkd:;cllcc:;clcl0XNWNNNWWN0kkOOOOOOOOOOOOOOOO0NWWWWk.  .oOOOOOOOkkOkOOOkkkkkkkkkkkkkOOO000OOOkxOK0kdolc;clodO0K0Okkkl',KNWNXNXoolcKX0kNWNNWWK:,'c0Ox00xdoKNW0dx0XXKkodk0KWNNNNNNXKKOKWWWWNXKKOkOO0000KXXKXWWWWX0KXNXKKKKKKKNW0lxxddddddxxxx
...                      ..'..',,:0KXK0O0NNXXNNd:ok0Ox;',lklclckXKkoc;;:ccc:;colo0XNWNNNWWN0KKKKKKKK0000000000XWWWWWN0;   .c0KKKXKkkkkkOkkkkkkkkkkkkkkOOOOOOkxk0KXXXXK00kxdkkO000kkk0o,,0NWNXNXool:xxdkNNNNWWK;,,lKOOKKKNXNWWOxkKNXOdodk0KNXKXNNNXX0OXNNWWXXK0kkxxxkOOXX00KNNNXK0OO0KKKKKKKKWWOdkdllodkOOkkO
...                      .....'';l0XXXK00XNNNWWk;dkOOkdoodkc:dodXXOdl;,,;;:::::;:0NNWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWN00l.   .lxO00kxdxkkkkkkkkkkkOOkkkkkkkkkkkO0KKKKK00KKK0K00OkxxxkXk;,0NNNXNXooo,...oNNNWWW0cc;oKdoK0kOONWNOxOXNKkxxxOOodoOXNNNXX0OXNNWWXXKOxxxxxkOOOOOOXNNWX00OO0000000OKWWXXX0xddxkO0OO0
...                      .....''',x0KK0OOKNNNWW0;oxkO0OxllxdodloXX0dc;;;;;::::c::0NNWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWNK000x,     .clodxxxxxxxxkkkkOOOOOkOOOOOOkkOOOOOOO000kxxxooooldxONOlc0NWNNNXxdd:'''xNNNWWW0oo:dKolKX0kOWWNkx0XX0dclkKOloo0NNNXXXOONWWWNXX0kkkkxxxkxxdxxO00KOkxxxkkxkO00ONWNK0KKKOoxOOOkk0
...                      ......'''ck000Ok0NNXNWXcldk0K0xolxkOd:dXX0l::;::;;::::;;ONNWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWX0OOO0O.  ...:lloddddddddxxxkOO0000000000Okkkddddolcc:;:;clocoxx0XOoo0WWNNNNXNN0ollkNNNWWW0;,;xKkkKXNO0WWXOkOKKOo;lO0xlodXNNNXKKO0NWWWNXKOdooooooooddddddddddddddddddxxONWWNX0OOK00000OOx
...                      ..'....''oKKKKO0KNNKXWNdldx0KK0Okkxlc;oXX0o,:;;;;;:;;;;;kXNNWWWWWWWWWWWWWWWWWWWWWWWWWWWWWNKOOOOO0c.;c .cllooooooooddxxxkO00000000OOOOkxxxxxxkkkkkOOOOkkkxo0Kkdd0NWNNNNXXXOolckNNNWWW0:;;kK00KkdoXWW0dxO0KklcdO0dlokXNNNXOOOKXNNNNX0xooododdddddddddoodddddddddddlxWWWWWNK0NWWWWNX0k
...                     ..........c0000O0KKKKXNNxcoxOKK00Okk:;;lXX0d,c;;od:;;;;,,kXNNWWWNNNNNNXXXXXXXXXXXXXXXXXXXXXK0000000kx. ;olooooolllloooddxkkOOOOOOOOOOOO0KKK0OkxddolloloxkccKXOxx0NWNNNNNNX0dcckNWWWWNO:;;kKO0KddxNWNOok0K0xlcxO0dodOXNNXKOOOXXNNNNKOdddxxxxxxxkxxxxxxxkkkkkkkkkkko0WWNNWWWNNNNNNNXXX
....                   ..... ..'..,xkkkxkK00KNNNx;;okKX00Oxd:,cl0X0c;l::dxoodxkO0XNNNNNNXXXXXXXXXXXKKKK000000KKKKXXXXXXXXXKd'. :KooooolollllllooodddxxxxxxkkO00KK000OOOOkxooodxkOclKX000KNWNNNNNNNKc':kNWWWWNO;;:k0lk0l:dNWXkdOKK0xllxOOkxx0NNNX0OOOXXNNNX0kodxxxkkkkkkkkkkkkkOOOOOOO000OkNWNXKXNWWWNNNXNWNN
....      .. .....'',,,;;;;;'.','',ldddodOO0KXNNk;:lxKX0Oxdoc:coKXKkO0000KKKKXXXXXXXXXXXXXXKKKKKKKK0000OOOO000000KKXXNXXKx;....,KKdooolllllllllllloooodddxxkOO0000000KKKK000000OOclKXK0OKNWNNNNNNNK;..xNNWWWNOcccdx:kK0OONWXkk0KKOoclO0OxdkKNN0OOOO0NNWWNKOxxkkkOkkkkkOOOOOOOOOOOOOOOO0OkOWWNK00KKKXKK00XNNN
::clccccccccllooooooodddddddddddddxkkkkkO0000KXX0kkOO0K0OOOOkkk0KK000000000O00000OOOOOOOOOO00000000KKKKKKKKXXXKKK00OOO0x;'......oXX0doollllllllllllllooodxxxkkOOO000KKKK000O000O0:;x0KKKKNWNNNNNNX0cl;xNNNWWNKxddxxd0Kkx0WWKkOKKKkl:oO0kdoxKXXK0OOO0NWWWN0kKXXXXXXXXXXXXXXXXXXXXKKKKKKKK0KWNXK00000000000000
lllooooodddddxxxxxxxxxxxkkkkkkkkkkOO00000KKKKKXXK0000KKK00000OOKXKKKKKKKKKKKKKKKKKKKK00000000000000000OO000000KK00K00xc'........'0XNN0xolllllccccccllllllooooodxkkOOO00OOkkxxxxc:::oxkO0KNNNXXXNXXOoxlkNWWWWNXKOkkxkKKKOKNNOxOKK0x::okO00OKNNNNKOOkOXNNNKxoOK0KKKKKKKKKKKKKKKKKKXXXKXXXKKXXXXXXXXXXXXXXXXXXX
::ccccllllccllllooooooooodxxddddddoooddddddddxxxxxxxxkkkkkkOOOOKXXXXXXXXKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKOkxoc:;,''.........dXXXNNKkdollllccccccllllllccccclooddddoolcc:;;;,;,;;;;:coxOKKKKXX0ollONNWWWNXKOkkxx0KK0XNXkxkO0Oxodk00XXK0KKKK0O0kkOO0OxooxkxxxxkkkkxkkkkkkkkkkkkkkkkkkkkOOOO00000000000000
:ccclloollccllllooooooodddxxdddoooooollllllollllooooooooooooooooooolooooollllloooodddddxxxxxxxxkkkkOOOOOOOxoc;;;,,,,'''''..'.....,0XXXNNNNKkoooollcc::::::;;;;:;;::::codxx;...,;;,,;;;;;,,,;:oxdolc:;;:cloxkOKK00000KKK0KXK000KKK0OO0000000KKKKK0000KXXKKK0000000000000OOOOOOOOOOOkkkkkkkkkkkkkkkkkkkkkkkxxx
ccclllooolllllolooooooooooooooooooooollllloolllloooooooooooooolc:::;;;;;,,,,''.........................';,,,,,,,,,''''''''''......cXXXXNNNNNXOxlllccc::;;;,,,,,,','.'xKKKKc....,;;;;;;;;;,,,,,;cccc::;,;:::::codx0KKKKKKXXXXKKXXXKKKKKKKKKKKXXKKKKKKXXXXXKKKKKKKKKKK0KKKK00000000000000000000000000000000000
.......''''',,,,,;;;;;;:::::cccllloollccclllllllllllloooooolllcc::;;;;;;;;,,,,,'''''''''''''''''''''',;;,''''''''''''''''''''.'''.'dXXXXXNNNNNNXko::::;;,,,,,,,,'..;OKXXX0,....'',,,;;;;;;,,,',;;::::;,;;::;;;:;:coxkkkkkkkkkOOOOOOOOOOOOOO0000000000KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
                                          ..............'''''''''.'''''''''''''''''',,',,;;:;;;;;;:::;;,,''''''''''''''''''''''.''';0KXXXXNNWWWNNN0d;;,,,,,,,,,'..o0KXXXK0;....'''',,,;',;;,,'',,;;;;;;;;;;,,;:;:::cdddddddddddxxxxxxdxxxxxxddxdxxxddddxddxxxxxxxxxxxxkxxxxxxkxxxkkkOOO0O000000K0KKKKK0KKKKK
                                                                                   .',;::;;;;,,;;;,,,,,,'''.'''''.''''..''''''.'''.'oXXXXXNNNWWWWNNNXx;'''',''',:kKXXXXXKKl....''',',,,,,;;,,''',,;;;;;;;;;,,',,;:::ldddddxdddddxxxxxxxxxxxxxxxxxxxxdddxxdxxdxdxxxxxxxxxddddxddoooddddxxxxxxxxxxkkkkkkkkkkkk
                                                                                ..,,,,,,,,,,;;;;,,,,,,,,''.''''....'''''''..''.''''',KXXXXXNNWWWWWNOdllooolllccc' .,dOKXXXx'..'''''',,,,,;;;,,'''',,,,,;;,,,,'',';;::lodddddxdddxxxxxxxxxxdxxxxxxxxxxxxxxxxxxxxxxxxxxkxxxxxxxxxxxxxxxxxxxddxxxxxxxxxkkkkkkkk
                                    ..........                                .',,,,,,,,,,,,,,;;;,,,,,,,''.''''........''.'''''''''''oNNNNXNNNNW0c. ....,,.......  .o::dXX0:...''''',',,,,,;;;,,,'',,,,,,,,,,'',',;;::cc:::cccllloooooddddddxxxdxxxdxxxxxxxddxxxdddxxxxxxxxkkxxxxxxxkkxxxkxxxxxxxxkkkkkkkkkk
...                           .',,''.....                                    .,''''''''',',,,,,,,;,,,,'''.'''''.'..''...'.''''''''''',0NNNNNNXOxdl'.'..';;'';'...,.'cclcckKo...'','',',,,,,,;,,;,','',,,,,,,,'','';;;;:;.             ................'''''',,,,;;;;;:::::ccccclllllooddddddddxxxxxxkkkkkkkO
...                           .;,.......                                    .,,,''''''''''',,,,,,,;,,''''..''''''.''''''''''''''''''''dNNNNXkloddddc'.,,'''',''..',oooololox...'','''',,,,,,,;,;,,,,,,,,;,,,''',,.,;;;,,:,.                                                             .............''''',,
...                           .;;',''..............                         ,,,,'''''''''','''''''''''.''.'''''''''''''''''''''''''''';XNXOddxkkkkkxdc....;;','.:,;kkOOOxxxd'..','',,','''',,,;;,','',,,,,,,'..',',,,,',;:c.                                                                                
....                          .;;'''''...............    ..                .....''''''''''''.'''''''''''.''....''''''''''''''''''''''''o0kkO00KK0K00Okd;.....;c,.,ckkO0000OO;.'',,',,',,,,'''',;;,,''',,,,,,'..',',,'',;,;:.                                                                                
....       ..  ...    .;;:;::;,;;,,,,'',,;:c:,,;;;;,,'....                .,.......''''''''''''''''''''''''.....''''''''''''''''''''''',0XKKKKKKXKKK00Okxc........l000K00000o.'','',,',,,,',,,,;;,'''',,,','''.'''''',;;,,.'                                                                                
....       ......'... lKKKXXXKl;:,;;,coxkkxxl:;;'....                    .;,,''......''''''''..','''.''.''''''...'''''''''''''''''''''''lXKKXXXXXKXKKKK0OOo;..c:..:000KKKK00k..''',,,',,,,,,'',,;''''',,,'''''..''..',,,'.';,                                                                               
....       ....'''''. lXXXXXNXd::''......','...         ...................,,,'''......'''''''.'''''.'.''''''.''...'''''''''''''''.''''',OKKKKXKKXKKXKKK0k,...,'...lKXXKKXKKK,.''',,,',,,,',,,,,,''''',,'''''...''.','...';;:.                                                                              
....        ...'',,'. lXXXNNNXd::'......'''......',,;cloddddddddddoooollcc;..''''''........'''..'''''''''''''''''...'''''''''''''''''''''dXXXXKXXXXXXXKK0;....'',c''xKXXKKKKXc.',,,,,,,,,,'''',,,,'''',,'''''...''.'...',;;,;,                                                                 .......      
....        ....''''. cXNNNNNXxc:'......:::codxkOO000OOOOOOOOOOOOkkkxxkkkd,'...','''.........''..''''''''''..'''''...'''''''''''''''''''''OKKKKXXKXKKKKKdo;..';o'',':KKKXXXKKl.',,,,,,,,,,'''',,,,'''',,'''''...''...'',,'',;:.                                                         ...,:::clol:'.      
....        ......... cKkxxkXXkllccoxkO0KKK0OKXXKKXXKKKKKKXXK00xo:cod0K0O;,''...''''''''......''.''.''''''..''''''''..''''''''''''''''''''dKXKXKXXKXXXKO',..''',..,,.xKXKKKKXx.'','',,,,,','',,,,,,''','''''...''...,''.'',;;;,                                               ........':ldxkkkkxl:,...      
....        .     ....cKc..'0X00XXXK00Okxxddo0XX00KKOxkkOO0K0OOxc,;olO00c,,'''....'''...'......'..'.'''.''''''',''','..''''''''''''''''''',KXXKKXXKXKXKc'..;,'....,;.:KKKXXKK0..''''',,,,',,',,,,',''','..'''''''......',,,,,,;.                                          ..........:x00Okkkxoc,,;,'..      
....        .      ...:Kl..'0XOkOOkxxxxxxxxdlOXX0O0K0xxxkO0KK0Od:,,olKNd,,'''''......'...''''...'..''''.''''''''''''''..'''''''''''''''''''oKKKXXKXKKKO'c'..'..,:....'xKXKKKKK:.''''',',,','',,,,'''''''..'''.'''...''','''',;;,                                      ..............kKK0xldo:,,,;;;'..      
....               ...:Kl..'0XOOOOOOOkkxxddol0XX0OKKOxxkkOOKK0Od:',ooK0;,''''''''.....'.....''.....''''.'''''''''''''''..''''''''''''''''''cXXKKKKKKXXd...'c.......,:.;KXXXXKKl''',,,'',',,,,,,,,'''''''..'...''...''...',,,,;;;.                               .'coollloooolllcc:,;kKK0koxx::c;,;,..       
....               ...:Ko...OXkxOOOkkkkxxxxol0NNKXXX00K00KKKKK0xc,,llKl''''''''''''........ .......'.''.''''''''..........''''''''''''''''''OXXKKXXKXKl',..'..,;'......lXXXKXNx.'''','',',,,,,','.''''''......'.......'',,,,,,;;:cllloodddddoollcc:::;,,,''....,xOOOOkkOOOOkkkOOkxdokKK0kokx:c;,,;,.'.......
....               ...;Ko...kXdoxxkOOOkkkxdlcOXX00KK0O0K0KKK0Okdolllcx'''''''''''''''........  ......''''''.''...'.........'''''''''''''''''lKKXKXKXKKc';..''.';..''..''0KK0KK0''''''','',,,,,','.''''''...........'.'''',,,,,;;:lOOOOOO0KKKKXXXXXXXXXXXXKK000OKNNNNNXXXXXKKKK0OxoookKXKOdOkc;;::loddddoc,'.
....               ...,Ko...xKdoooodkOOOOkxl:ONXKKXK00KKKKKKK00xoxxl,:''''''''''''''''''.......   ..'..''.'.'''''''....... .'''''''''''''''',0XKKKXKXX:...':'...'.''....dXKKK00;..''',,,,,',,,','..''''...........''..''',,',,;;;:O00OOOOkOOOXXNXXXXXXXXXK00KKKXNNNNNNNXXNNNNN0xxdddOKXKOk0kcldkkO00Oxdl:;,'
....               ...,0d...dKdodoooodxOOOko;kKXK00KK0XXK0KKKKKkoxkd''''''.''.''''''''''''......   ..'''..'.'''.'..''..'... .''''''''''''''''oXXXKKKKKll..';.''l;....,;.,KKKXX0c.'''',,,,,'','',..'''''...............''',,,,,;;;;d0000OOOkk0XNNXXXXXXXXXXXXXKKXNNXXNNNNNNNNWNK0KKKK0KKKkx0xckXNWWWN0doddxxx
....               ...'0d...o0olollooodxkkko;kXXKKKKKKXK000KK00kdkkl,''''''''.''...''''''''''..... ....'.'..'''''''''....... '''''''''''''''';0KKXXXXK'..''','.'...:,....dKK0NKo.''''''',''''',,....''..............'.''',,,,,,;;;cKKKKkkOOKXNNNNXXXXXXXXXXXXXXXNNNNNNNNXNNNNNXXNNXXXKXKxckd:dXNWWWW0xO00000
....           .......'0Olccx0ocoooddddxxxdl,xKX0KXXKKXK00KKKXKkdkx,''''''''.'''.....''''.......... .......'''''''''.''.....  .''''''''''''''.xXXKKK0k.....,d,'';.......'lXX0KKx..'''''''''''',,...................''.''''',,,,;;;;kKXNXXXNNNNNNNNNNNNNNXXKKXXXXNWNNNNNNNNNNNWNNNNNNXKXKkoOkcxXNWWWWOONNNNXN
 ...         ..........0XXXXXKddkkOOOOOOOxdx;xXXKXXXKKK000O00Okxdkk;'''''''''''..''.'...'''.......  .....''''''''''.......... ..'''''''''''''':XXKXXXk.'l,'''''':'....,'..0KXKXO'.'''''''''''',,....................'''''''',,,,;;;lKNNNNNNNNNNNNNNNNNNNNNNXNNNXNWNNNWWNNNWNNWNNNNNNXKXKkoOkokXNWWWWOONNNNXN
....         ..........OXXXXXKoo0K0KKKKK0kxk;dKKKXNNXXNNXNNKOOOkdkk:'''''''''''''''''.....''''....  .......'''''.............. .''''''''''''''.kKKK0Kx...''':,.....';.....x0XNXK;.''''''''''''',.....................''','',',,,,;;;0NNNNNNNNNNNNNWWWWNNNNNNNNNXXNNNNWWNNNWNNWNNNKXXKKKKkdOOdONWWWWW00NNNWNN
....         ..........kXXXXX0dxXNXXXKKKX0OO;o0K0XNNXXNNNNNN000kdkk:'''''''''''''.'''.''........... ........................... .''''''''''''''dXXK0Kd.....,l,'.''.....;..l0K0XKc.''''''''''''''.....................''.','',,,,,,;;dXNNWWWWWWWWWWWWWWWWWWNNNNNKKWNNNWWNNNWWWWNNNOKKKKKKOododONWWWWW00NWWWXN
             ..........kXXXXX0dxNNKXXKKXXO0O;oKX00K000K00KKK000kdxd;,''''''''''..'''.''............  ..................'.......  .''''''''''''':XXXK0o.;;.'''...,;.....'..;KKKKKo.''''''''''''''.......................'.'',,',,,,,,,;dWNNNNNNNXNXNNNNWWNXK000Kk0WWWWWWNNNWWWWWNN0KXKKKKOldoo0NWWWWN00NWWWXX
             ..........xKXXXX0oxXNKXK0KXXOOO;oKNK0OkOOkkkO0KK0Kd;''.......'''''''''''''''..........  ...........'..''............ .'''''''''''',0KXX0o...'''l:......,,....;K0KKKk'.''''''.'...'..........................''.'.'''',,,,dWWWWWWWNNNNWWWWWX0000000dkWWWWWWWNNWWWWWNNKKXXKKKOoddd0NNWWWN0KWWWWXN
             ..........xKXXXX0oxXXKXK0XXKkdc.oKXKOO0K0OOOO0KK00,....''.''.'''....'''''''''''.......  ..........''.''.............  .'''''''''''.xKKX0l..';'','..;,......'..OKKKK0,....''.'''.''..........................''',,,,,,;;;;cXWWWWWWWWWWWWWWWX00000K0loWWWWWWWNNWWWWWNNKXNNXXX0ddlckXNWWWN0KWWWWNN
               ........dKXXXX0dx0OkOkOXK0dl:'lO00OO00000OkO00OO,''''''''''''''''''''''''''''.......  .............''.''........... .'.''''''''''lKKXNo..':,''...',..';..'..kKKKX0;.'.''''''.'.........................''''','',,,,,,;;:kWWWWWWWWWWWWWWWWNXXXXX0;cNWNNWWNNNNWWWWNNXXNNXXXKxl:lONWWWWNOKNNWWNN
               ........oKXXXX0dodddkkO0kxllo:oOK0OO0KOOOOkk0KK0;',,''''''''''''''''''''''''''.....    ............................. .''''''''''':KKKXd'.....,l,...'..'.....dKKXKKc..''''''..'................. .........''''',,,,,;;;::cKWWWWWWWWWWWWWWWWWWWWNk.;NWWWWWWNNWWWWWNWNNNNXXXKdllxKNWWWWNOKWWWWXN
.              ........oKXXXX0ocodxxxddddddo:o000OO00OOOkkkOK0O;,,''''''''''',''''''',''''''.......    ............................ ...''.'''...,0KKK:..;:'.''...'c'...'c'.;KKXXKo.'''.'''.................... .........'''''',,;;;;::;;lWWWWNNNNNNNWWWWNNWWWXo 'NNNWWWWWWWWWWWWWWWNNXXK0kxdd0NWWWWNOKNWNNXN
..             ........oKXKKK0l;clllllooolcc,lO00OO0KOOOOxkKXKk'''''.'''''''''''''''''''''.........    .................'..........  .'....'..''.dKX0c..;;'...'......,kXXX0OXXXXKx.''........................  ......'...'''''',,,;;;;,',0WWWWWWWWWWWWWWWWWWNK; .XWNNWWWNNWWWWWWWWWNNXXX0kxlo0NWWWWNkKNNNNXN
.....        . ...',;:cdkOOOOxollcclllllccllcokOOkO00kOOkkO0KOd.......'''''...'''''''''''''''.......    ................'........... ...........'cKK0;...''..'l:.';..c0KKKK000KKX0;..................,x0Od:..  .........'''''',,,,,,;;,''oWWNNWWWWWWWWWWWWWWNO. .KWWWWWWWWWWWWWWWWWNNXXXKOxooONWWWWNd0NNWNXN
...',;;;;,''',;cloddddddxxxxdokKOcccllodxkkkkOOOOOOOOOOOOkkO0Ol......''.....''''''''..''''''''......     ............................ .........'''kK0,...c:''.....,'..:xOO0OOkOOKXXkl;''...........':xKKK00x'  ...................''',;;';NWWNNWWWWWWWWWWWWWXl   kNWWWWWWWWWWWWWWWWWNXXXKOkdd0NWWWWXoKNWWNNN
cooddddddddddddxxxxxxxxkkOOOkkdxddxxkOOOOOOOO000000000000O0000o....'''...'''''''''''''''''''.'......     ..........'...'..''......... ..........'.dXOc..'.'''',,......;,';ldxxk0KKXXXX0xo:,,;::loxOKK0kkkxxkx    .................... ..,,KWWWWWWWWWWWWWWWWNK'   oNWWWWWWNWWWWWWWWWWNXXXKOxdd0NWWWWXoKWWWNXN
odddddxxxxxkkkkkkkOOOOOO00000000000000000000000000000000000000d...''.''''''''''''''''''''''........      ......................................'..oXO,...;,''.;,...;'.......;0OOO00KKXKKKXXXXXKKKK0000Oxxxxd,   ..... ...'''....'',,;'.  .lXNNNWWWWWWWWWWWWNx    :NWNWWWNNWWWWWWWWWNNXKK0xdddKNWWWWXoKWNWNNN
ccccccclllloloooddddxxxkkOO0000000KKKKKKKKKKKKKKKKKKKKKKKKKKKKc......''''''''''''''''''''.'........     ..........................................cXO'.'.:c'..'....:'.....'..kKOkO00KKKKKKKKK00KKK0OOOkxxo;.   ....'',,,,;;;;;;;;::;;::,. .;0XXXKXXXNWWWWWWXc....;XWWWWWNNWWWWWNWWWNNXXXKxodd0NWWWWKoKWNWNNN
cccccccclllllllllccccccccccclllloooddddxxxkkkkOOO0000KKKKKKKKO'.'...''''''.........'''''''.......        .........................................;0xc,..'''.,c'.,'...:'....'dKKOxkO00K00K0000O0KKK0kxoox.....',,;;;:;;:::;;;;:;;;::;;;;;,..lXXKKKXNWWWWWWWXkxxxdxXWWWWWWWWWWWWWNNNNNXXXKdclo0NNWWWKlKWWWNNN
:::::ccccccccccc:cccccclllllllccclllllllllcccccccllllooodddddl.'''''''...........'..............         .............................. .........',kc..'',l,.....,,......,...cKKKkxkO000OOOOOOkO00KKK0OO00000xccccc::::::::;;,;;,';;:;;;::;,,O0000KXWWWWWNNNXXXKXNNNNWWWNWNNNNWWWWWWNNNNXKOOOXNNWWWKxXWWWNNN
....'',,,,;;;::::ccc:clllllllcllllllllllllllccllllllllollllll;.''''....''''''''''''''''.........         ..........................................o:.....''..,;.....;,..'..;cKKK0dkO0000OOOOOkkOO0K000KXXXK0Kkcccccc::::;:;;;;,,,,'::::;::c:oxxxdxkO0XNNNNNNNXXXNNNNNNNNNXXXXNXXXXXXXXNXXXXXNNWWWWWNNNNWNNN
                 ......'''',,;;::cccccccllllllllllloooooooooo,'''.''...''''''''''''''''''......           .. ........................... ..........:,..,c,....',..,...........xXXKdok00000OOOkkkO0KKOkO0K00OkOx:c:::cccc:;;;,,,,;;;,.,,'.,;:lclodddoodoloO0XXXXXXXNNNNNNXXNNNNNNNNNNXXXXK0KXNWWWWWWN0KNNNNXN
                                       .........'',;;:::ccllc'''''''',,,,,,,,,,,,,,''''''''....              ............................ .........;;''',...;,...''.......'...oKKKdl:xO00000OOOkOKKK0xoldxOO0KNO:::::::::;;::,''',;;.'''..:lccclodddooll:;,xXXXXXXXNNXK00KXNNXXXXXXKKKK00KNWWWWWWNXKKK0KK000
                                                           ..''',,,,,,''.......'''''''''''''....          ............................... ........';;'..''..;;.......,........cXKKxl:.okOOOOOOOOO0KK00Okdd0NWWWWKc;:;;;;;;'',,,''';;.''....''''''..........;oXWWWNNNXKKKKXXXXXKKKKKK0OOKXWWWWWWNXXXXK00KKKKK
                                                            .''',,,,,'',,''..........'''''''.....           .............................. ........;,...cc......,;.......,....'KK0dld'.ckkO0000OO0XXKOkxkkkkNWWWNKc,;;,,,,,..';,,'.,'........''''.........'::OWNNNNNNNNNXXXKKKKXNNNNNNNWWWWWWNXXNXX000KKKKKK
                                                           ..',,'.....'''',,,,,,'.........'''...             ............................. ........,:;......'c'..'...;...;....'0KKOdx:.c:dOOOOOOO0K00OkxxxxxKKKKKKkc:c:::::::::cc:::::::ccccc:::::::::::;;;;;:::::::::::;;;,,,,;oNWWWWWWWWWNXXNNX0000KKKKKXX
                                                           .''''..'''''''',,,,,''''','.....''..              .................................',;;;::;;;;;;;;:;;;;;;;:;::::::c:oollccc::::cccc::::::;;;;;;;;;;;,,,,,,',,''''''''''''................'''''''',;::clooooolcc:;,'''.0KKKKKKKXXXNNX0000KKKXXXXXX
                            ..';;;:'                      ..''.''','''',,,;,,,,,,''''''......'.              . ..............................'',,,,,,,,,,,,,,,,'''''''.''....................................',,..   ...........................'''''''''',;:lodxkkkkOkkxdlc;,,.,KKKKKKKXXNXKKKKKKKKKXXXXXXX
.                      ..,coxkkOkkko.                     ..'.''',','''',,,,,,,,,,,'',''....''.                 ......................................,'......;;. .:,.  .;lllc'   .o'   'dolod'   'x.      lkc;;,.   .......,clc;'..',,''''''',,:;;;;:;,,;:ldxkOxl:;;:oOOkxoc:,.:KKKKKKKNNKolodddxxxkkkkOOOO
.... .            .';cdkO0000OOOOkkx.                    ...'''..''''''''''',,'',,,,,,,'''.....                 .....................................lkk;..  ,OOd,'Oo.  'xxc;'.   ;0,   :Ol:dO;   :k.     .xklc,     .''''cx0OkO0ko:OOdokxdOkkOkOxOxOkO:,;coxOOxc.;c,,'lOkdl:,'..',,,;;::c;:lodoooodddddddoo
.....         ':lx0KKXKKKK000OOkkkkk:                    ...''...',,,'',,,,,;;,;,,,',,,',''.  .                 ....................................lOdxO;.. ;Ol;xx0l   ..';dOc   :0'   ck;,:kl   lk;,;.  'kd;;:.    ....;dk0kkOOd,;kklldodxolocol:,ll:'';coxOkc..cl;cokOkdl:;...........',:clooddddddddoodd
...          ;0XNNXXXXXXKK00OOOkOkkko.                    .'..''''''''',,,,,,,,,,,,,',,,,'''.                     .. ..............................ck;,lkx.  ,x; .lx;   ,loooc.   ,c.   'c:::,.   .;,,,.   ..''..    ......':ooc,.............'''',,,,,,;:ldxkOx:,,;;lkOkxoc:;.........'',;:cclllooooooooooo
...          .ONNNNNXXXXKKKK000OOOOOx'                    .''''''''',,,,,,,,,,,,,,,;;;;,;,,,'.                  .....................................................                                               ..''''''';;;;;;;;;;,;;;:;;;;:;,,,,,,,;:lodxkOkkkkkxdol:,,'.       .......'''',,;;::ccccc
...           cXNNNNNNNNXXXXKKKKKK00Oc                    .'....',,,,;;,;;;;;;;;;;;;;;;;;;,,,,.        .',;;,. ........................................................                                             .............................''''''''',;:cloooooolc:;,''....                            
..            .OXNNNNNNNNNNNNKKKKKKOOx.                    ....''''''''',,,;;;;;;;;;;;;;;;;;;;,..,okOOO0KKKKK0o'.........................................................                                           ..........................................''.......        .                            
.              :KKXXXNWWNNNNNKl:xKXKOO;                  . ............',,,,;;;;;;;;;;;;;;;:lodxOKKK00OO0KKXXXXXo..........................................................                                                                          .';cllooooolll:;'.       ..                            
               .dO00OKNWWNNNNXxcdKXX0Ox.         ....................''',,,,,;;;;;;;;;;;;:d0KKKKKKKKKK0kxk0KXXXXXO, .........................................................                                                                     .;coollllllllllllllll:..    ;kkkkkkkkkkxkxxxxxxxxxxdddddoo
.               ,k00OOXNWNNNNNKOO000KK0d    .........................'''',,,,;;,;coxkO0KK0KKKXKKK00KKKXXKkoxOKKKKKKl...........................................................                                                                .,clllllllllloolllllllllllc.   lKKKKKKKKKKKXXXKKKKKKKXXXXXXXX
                 dO00kOXNWNNNX0kkxldKK0Ol,,'''cd:''......'''.........''''',,,,lONWWWWWWWK00KKXXNX00KXXXXXNXOdd0KKKKXk..........................................................                                                               ,llllllllllllxKKkolllllllllll'..xKKKKKKKKKKKKKKKKKKKKKKXXXXKKK
                                                                                                                                                                                                                                                                                                            
                                                                                                                                                                                                                                                                                                            
                                                                                                                                                                                                                                                                                                            
                                               .,:ldxk0KKKKKOkxdl:'.                                                   OKKKKKKKKKKKKKKKKKKKKKKK                                                                                  cKKKKKK,                                                                   
                                          .:d0WMMMMMMMMMMMMMMMMMMMMMNOo,                                               XMMMMMMMMMMMMMMMMMMMMMMM                                                                                  dMMMMMMc                                                                   
                                       .oKMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMW0c.                                           XMMMMMMMMMMMMMMMMMMMMMMM   .kkkkkkkk        ,kkkkkkkk.   kkkkkkkkkkol;.             ':odkkkkkkkkkkk.   kkkNMMMMMMNkkkkk;   dkkkkkk.   .,cok           ':ookkkoo:,                    
                                     lKMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM0:                                         XMMMMMMMO                    MMMMMMMW.     cMMMMMMMM     MMMMMMMMMMMMMM0c         dNMMMMMMMMMMMMMMM.   MMMMMMMMMMMMMMMMd   XMMMMMM. c0MMMMM       ,dKMMMMMMMMMMMMMKd,                
                                  .xWMMMMMMMMMMo       .....       KMMMMMMMMMMNo                                       XMMMMMMMd                     NMMMMMMW:   xMMMMMMMK      MMMMMMMMMMMMMMMMNc     :WMMMMMMMMMMMMMMMMM.   MMMMMMMMMMMMMMMMd   XMMMMMMKNMMMMMMM     oNMMMMMMMMM.MMMMMMMMMNo              
                                .OMMMMMMMMMW    .:ok0NWMMMMMNX0xl,.   .MMMMMMMMMWo                                     XMMMMMMMd                      WMMMMMMMd KMMMMMMMx                ,MMMMMMMMc   .MMMMMMMK                  OMMMMMMo         XMMMMMMMMMMMMMo    lWMMMMMMMMMM: :MMMMMMMMMMWl            
                              .OMMMMMMMMMc   ;xNMMMMMMMMMMMMMMMMMMMKd,   OMMMMMMMMX.                                   XMMMMMMMd                       KMMMMMMMWMMMMMMMo                   .MMMMMMM   cMMMMMMk                   dMMMMMMc         XMMMMMMMMMO       kMMMMMMMMMMMK   KMMMMMMMMMMMO           
                            ;0MMMMMMMMM.  ,xNMMMMMMMMMMMMMMMMMMMMMMMMMNo.  lMMMMMMMWo                                  XMMMMMMMWKKKKKKKKKKKK;           oMMMMMMMMMMMMM.           ,::::::::dMMMMMMM   .MMMMMMWd::::::,.          dMMMMMMc         XMMMMMMMM.       xMMMMMMMMMMMM     MMMMMMMMMMMMx          
                          :KMMMMMMMMM.  :KMMMMMMMMMMMW.     :MMMMMMMMMMMMk   MMMMMMMMO    .',:cookk0K:                 XMMMMMMMMMMMMMMMMMMMMl            ;MMMMMMMMMMM          :0MMMMMMMMMMMMMMMMMM    ;MMMMMMMMMMMMMMMNx,       dMMMMMMc         XMMMMMMM,        MMMMN                     NMMMM          
                        :KMMMMMMMMM.  :KMMMMMMMMMx               XMMMMMMMMW:  0MMMMMM;  .OMM   ,xl.   .dl              XMMMMMMMMMMMMMMMMMMMMl             .MMMMMMMMM          OMMMMMMMMMMMMMMMMMMMM      0MMMMMMMMMMMMMMMMK.     dMMMMMMc         XMMMMMMN        .MMMMMNd'               'dNMMMMM.         
                      cXMMMMMMMMW   cXMMMMMMMMM                    'MMMMMMMMx  kMMM.  ;0MMMM;  .Xk   xWM.              XMMMMMMMk                          0MMMMMMMMMo        ;MMMMMMMMMMMMMMMMMMMMM          dMMMMMMMMMMMMMW'    dMMMMMMc         XMMMMMMo        .MMMMMMMMXd'         'dXMMMMMMMM.         
                    lNMMMMMMMMW   lNMMMMMMMMM           .W           KMMMMMMMd  M.  :KMMMMMMk:kWMMNo;MMM               XMMMMMMMd                         XMMMMMMMMMMMk       lMMMMMMo       MMMMMMM                  ;MMMMMMW    dMMMMMMc         XMMMMMM,         WMMMMMMMMM,         ,MMMMMMMMMW          
                  lNMMMMMMMMW   lNMMMMMMMMM             NMd           XMMMMMMM.   :KMMMMMMMMc  ,MM   WMk               XMMMMMMMd                       .NMMMMMMMMMMMMM0      lMMMMMMo       MMMMMMM                   MMMMMMM    dMMMMMMc         XMMMMMM.         .MMMMMMMMk     :     kMMMMMMMM.          
                oNMMMMMMMMO   oNMMMMMMMM0              dMMM,           MMMMMN   cXMMMMMMMMW   .'Xk.  .M'               XMMMMMMMd                      ;WMMMMMMMoMMMMMMMX.    lMMMMMMo       MMMMMMM                 .OMMMMMMX    dMMMMMMc         XMMMMMM.           MMMMMMM  .c0WMW0c.  MMMMMMM            
              dWMMMMMMMMO   dWMMMMMMMM0   ll      :MMMMMMMMMMMMM.      XMMN   lNMMMMMMMMW   :KMMMMMMWXM                XMMMMMMMWNNNNNNNNNNNNNNN      :MMMMMMMM  .MMMMMMMW'   .MMMMMMWNNNNNNNMMMMMMMWNN   ;NNNNNNNNNNMMMMMMMM     ,MMMMMMWNNNNNl   XMMMMMM.            xMMMMOc0MMMMMMMMM0:kMMMMk             
            dWMMMMMMMMO   dWMMMMMMMM0   lNMl         kMMMMMMM:         XN   lNMMMMMMMMW   :KMMMMMMMMM                  XMMMMMMMMMMMMMMMMMMMMMMM     :MMMMMMMX    .MMMMMMMM:   lMMMMMMMMMMMMMMMMMMMMMMM   cMMMMMMMMMMMMMMMMx       dMMMMMMMMMMMd   XMMMMMM.              xMMMMMMMMMMMMMMMMMMMx               
           cM. .0MMk.   dWMMMMMMMM0   lNMMMX         xMMMMMMM'            lNMMMMMMMMW   :KMMMMMMMMM                    XMMMMMMMMMMMMMMMMMMMMMMM    dMMMMMMM0       MMMMMMMMo    KMMMMMMMMMMMMMMMMMMMMM   cMMMMMMMMMMMMMM;           NMMMMMMMMMd   XMMMMMM.                 oMMMMMMMMMMMMMo                  
           NM:  .0k   lWMMMMMMMMl   ,NMMMMMM'       .MMo   KMN          oNMMMMMMMMO   cXMMMMMMMMX                                                                                                                                                                                                           
           MMW,dWMMNo'MMMMMMMMl   ,  MMMMMMMW'      O         O       dWMMMMMMMMO   lNMMMMMMMMX                                                                                                                                                                                                             
          ,MMx  ,MM.  XMMMMMl   dWM. .MMMMMMMMo                     dWMMMMMMMMO   lNMMMMMMMMX                                                                                                                                                                                                               
          0M.   'XO.  .MMM'  .xWMMMW.  MMMMMMMMNo.               ,xWMMMMMMMMc   oNMMMMMMMMo                                                                                                                                                                                                                 
          .  :KMMMMMMXKX.    MMMMMMMW:  oMMMMMMMMMXdc'.     .,lkWMMMMMMMMMc  .dWMMMMMMMMo                              :ccc: .ccccccccccccc.           cccccc                                                                                                 '000:                                         
                             .MMMMMMMMk   OMMMMMMMMMMMMMNNNMMMMMMMMMMMMMc  .dWMMMMMMMMo                                XMMMW cMMMMMMMMMMMMMl          .MMMMMMO                       .,cd                                                            .,cd     oMMM0                                         
                               KMMMMMMMWo.   WMMMMMMMMMMMMMMMMMMMMMMM0   'xWMMMMMMMM,                                  XMMMW      XMMMX               NMMKOMMM.                     cMMMM                                                           lMMMM                                                   
                                ,MMMMMMMMMO:    cMMMMMMMMMMMMMMMMM.    cKMMMMMMMMM,                                    XMMMW      XMMMX              .MMM'.MMMN     0000,   c0000 .0WMMMMK00.   :x0XNK0d,    ;000',d0NX0l .d0NX0o    .lk0KNNKOo.  .0WMMMMK00  x000O    .lk0NNKOl.    O000.ckKNKOc           
                                  oMMMMMMMMMWkc.                   'l0WMMMMMMMMM,                                      XMMMW      XMMMX              KMMM  NMMM.    MMMMc   dMMMM .ONMMMMKOO. :NMMMl NMMMK.  cMMMMMMMMMMMNMMMMMMMN    NX   :MMMMc .ONMMMM0OO  KMMMW   kMMMM..MMMMk   XMMMMMMMMMMMK          
                                    .MMMMMMMMMMMN0xo:;,'...,,;cokKWMMMMMMMMMMW                                         XMMMW      XMMMX             .MMM:  ,MMMN    MMMMc   dMMMM   cMMMM    'MMMM.   dMMMW  cMMMM   'MMMM,  .MMMM;      .,:NMMMM   lMMMM     KMMMW  OMMMX    WMMMk  XMMMW   ,MMMM.         
                                       oMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM;                                           XMMMW      XMMMX             NMMM0oo0MMMM'   MMMMc   dMMMM   cMMMM    kMMMM    'MMMM. cMMMM   .MMMM.   MMMMc  .dXMMMMMMMMM   lMMMM     KMMMW  MMMMo    OMMMM  XMMMX   .MMMM.         
                                          .MMMMMMMMMMMMMMMMMMMMMMMMMMMMW                                               XMMMW      XMMMX            'MMMMMMMMMMMMN   MMMMl   dMMMM   cMMMM    oMMMM    :MMMM  cMMMM   .MMMM.   MMMMc .WMMM   'MMMM   lMMMM     KMMMW  WMMMK    WMMMX  XMMMX   .MMMM.         
                                               cMMMMMMMMMMMMMMMMMMM'                                                   XMMMW      XMMMX            NMMM'    .MMMM;  WMMMW,.:WMMMM   .MMMMx..  MMMMk  'WMMMo  cMMMM   .MMMM.   MMMMc :MMMM.  OMMMM   ;MMMMd..  KMMMW  'MMMMc  lMMMM.  XMMMX   .MMMM.         
                                                                                                                       XMMMW      XMMMX           :MMMK      kMMMW   WMMMMMM:MMMM    cMMMMMM   'MMMWNMMMK    cMMMM   .MMMM.   MMMMc  lMMMWXW0MMMM    oMMMMMM  KMMMW    dMMMNNMMMc    XMMMX   .MMMM.         
                                                                                                                                                                                                                                                                                                            
                                                                                                                                                                                                                                                                                                            
 .....            cO00OkKNWWNNXKxdl:dKX0Ol.....',';;,,''',,,,,.'.....'''',,,,,dWWWWWWWWWXOO0KKXXNNN00XXXXXXNXkoxO0KXXXx....................''.........................................                                                        ,oollollllloodKXXKdoolllllllooc..OKKXXXXXKKKKXXXKKKKKKKKKKKXXXX
_EOF_

    else

        # Large banner
        cat <<'_EOF_'
===============================================================================================

                                                                                               
   NMMMMMMMMMMMd                                           MMMk                                
   0XXXXXXXXXXXo                                           XXXd                                
   0XXXo          xXXXN  cXXXX'  XXXXXXXN0   ,NXXXXXXXX. KXXXXXXX0 'XXXdWNXX.  kNNXXXXXNNW     
   0XXXo           lXXXNkXXXX.        OXXXX .XXXX.         XXXd    'XXXXXXX. :NXXXXX.kXXXXXO   
   0XXXXWWWWWW,     ,XXXXXXX      MWWWWXXXX..XXXXWWWM      XXXd    'XXXX:   ;XXXXXX;  XXXXXXk  
   0XXXXXXXXXX,      .XXXXO     XXXXXXXXXXX.  OXXXXXXXNO   XXXd    'XXXk    xXXXl       .NXXX  
   0XXXo             NXXXXXk   ,XXXc   xXXX.        ;XXXx  XXXd    'XXXl    cXXXXN     kXXXXO  
   0XXXo           'NXXXXXXX0  ,XXXc   xXXX.        cXXXd  XXXd    'XXXc     kXXX; KNW..XXXX.  
   0XXXXNNNNNNNo  cXXXX' dXXXN  KXXXNNNXXXXXl dNNNNNXXXx   kXXXNNK 'XXXc      .XXNXXXXXNXXc    
   0XXXXXXXXXXXo xXXXX.   cXXXN.  XXXXXXk;XXl dXXXXXX        OXXX0 'XXXc          dXXXK        
                                                                                               
                                                                                               
   0XddXXXXXX0     ;XXXd           xWK                              .WW,  kX,                  
   0Xd  .XX;       KX,XX. ;WW  NWodXXXWl 0WNWW. dWkWNWkXWNW  NWNNWc NXXNW NNl .WWNWO  NWOWNW:  
   0Xd  .XX;      cXk xXd ;XX  KXl oXO  0Xd ,XX.lXX 'XX. KXl   ;XXX..XX,  XXl,XX. xXO 0Xo lXX  
   0Xd  .XX;      XXXNXXX.;XX  KXl dXO  KXl .XX'lXK .XX. 0Xl:NX .XX'.XX,  XXl;XX  dX0 0Xl cXX  
   0Xd  .XX;     dX0   0Xd KXNNXXo 'XXN; XXWNX: lXK .XX. 0Xl.XXWNXX' OXXX XXl cXNWXX  0Xl cXX  


===============================================================================================

_EOF_

    fi
}

### Check requirements
check_requirement() {
    check_system
    check_security
    check_command
    check_resource
}

### Check system requirements
check_system() {
    printf "$(date) [INFO]: Checking Operating System.....................\n" | tee -a "${LOG_FILE}"

    # Check CPU architecture
    if [ "${ARCH}" != "x86_64" ] && [ "${ARCH}" != "amd64" ]; then
        printf "\r\033[1F\033[K$(date) [INFO]: Checking Operating System......................ng" | tee -a "${LOG_FILE}"
        printf "\r\033[1E\033[K" | tee -a "${LOG_FILE}"
        error "Not supported CPU architecture."
    fi

    # Check OS type
    OS_TYPE=$(to_lowercase $(uname))
    if [ "${OS_TYPE}" != "linux" ]; then
        error "Not supported OS."
    fi
    OS_TYPE=$(uname)

    # Check OS
    info "NAME:         ${OS_NAME}"
    info "VERSION_ID:   ${VERSION_ID}"
    info "ARCH:         ${ARCH}"

    case "${DEP_PATTERN}" in
        RHEL8 )
            ;;
        AlmaLinux8 )
            ;;
        Ubuntu20 )
            ;;
        Ubuntu22 )
            ;;
        * )
            printf "\r\033[4F\033[K$(date) [INFO]: Checking Operating System......................ng" | tee -a "${LOG_FILE}"
            printf "\r\033[4E\033[K" | tee -a "${LOG_FILE}"
            error "Unsupported OS."
            ;;
    esac

    sleep 1
    printf "\r\033[4F\033[K$(date) [INFO]: Checking Operating System......................ok" | tee -a "${LOG_FILE}"
    printf "\r\033[4E\033[K" | tee -a "${LOG_FILE}"
    echo ""
}

### Check system requirements
check_security() {
    printf "$(date) [INFO]: Checking running security services.............\n" | tee -a "${LOG_FILE}"
    SELINUX_STATUS=$(sudo getenforce 2>/dev/null || :)
    if [ "${SELINUX_STATUS}" = "Enforcing" ]; then
        info "SELinux is now Enforcing."
        SELINUX_STATUS="inactive"
        if [ "${DEP_PATTERN}" != "RHEL8" ]; then
            SELINUX_STATUS="active"
            printf "\r\033[2F\033[K$(date) [INFO]: Checking running security services.............check\n" | tee -a "${LOG_FILE}"
            printf "\r\033[2E\033[K" | tee -a "${LOG_FILE}"
        fi
    else
        SELINUX_STATUS="inactive"
        info "SELinux is not Enforcing."
        SELINUX_STATUS="inactive"
        if [ "${DEP_PATTERN}" = "RHEL8" ]; then
            SELINUX_STATUS="active"
            printf "\r\033[2F\033[K$(date) [INFO]: Checking running security services.............ng\n" | tee -a "${LOG_FILE}"
            printf "\r\033[2E\033[K" | tee -a "${LOG_FILE}"
            error "SELinux is must be Enforcing on Rootless Podman."
        fi
    fi

    FIREWALLD_STATUS=$(sudo firewall-cmd --state 2>/dev/null || :)
    if echo "${FIREWALLD_STATUS}" | grep -qi "running"; then
        printf "\r\033[2F\033[K$(date) [INFO]: Checking running security services.............check\n" | tee -a "${LOG_FILE}"
        printf "\r\033[2E\033[K" | tee -a "${LOG_FILE}"
        warn "Firewalld is now running."
        FIREWALLD_STATUS="active"
    else
        info "Firewalld is not running."
        FIREWALLD_STATUS="inactive"
    fi

    UFW_STATUS=$(sudo ufw status 2>/dev/null || :) 
    if echo "${UFW_STATUS}" | grep -qi "status: active"; then
        printf "\r\033[3F\033[K$(date) [INFO]: Checking running security services.............check\n" | tee -a "${LOG_FILE}"
        printf "\r\033[3E\033[K" | tee -a "${LOG_FILE}"
        warn "UFW is now active."
        UFW_STATUS="active"
    else
        info "UFW is inactive."
        UFW_STATUS="inactive"
    fi

    sleep 1
    printf "\r\033[4F\033[K$(date) [INFO]: Checking running security services.............ok\n" | tee -a "${LOG_FILE}"
    printf "\r\033[4E\033[K" | tee -a "${LOG_FILE}"

    # if [ "${SELINUX_STATUS}" = "active" ] || [ "${FIREWALLD_STATUS}" = "active" ] || [ "${UFW_STATUS}" = "active" ]; then
    #     echo ""
    #     echo "Security service is active."
    #     read -r -p "Are you sure you want to continue processing? (y/n) [default: n]: " confirm
    #     echo ""
    #     if ! (echo $confirm | grep -q -e "[yY]" -e "[yY][eE][sS]"); then
    #         info "Cancelled."
    #         exit 0
    #     fi
    # fi
    echo ""
}

### Check required command
check_command() {
    printf "$(date) [INFO]: Checking required commands.....................\n" | tee -a "${LOG_FILE}"
    if command -v sudo >/dev/null; then
        info "'sudo' command is exist."
    else
        printf "\r\033[1F\033[K$(date) [INFO]: Checking required commands.....................ng\n" | tee -a "${LOG_FILE}"
        printf "\r\033[1E\033[K" | tee -a "${LOG_FILE}"
        error "Required 'sudo' command and $(id -u -n) is appended to sudoers."
    fi
    sleep 1
    printf "\r\033[2F\033[K$(date) [INFO]: Checking running security services.............ok\n" | tee -a "${LOG_FILE}"
    printf "\r\033[2E\033[K" | tee -a "${LOG_FILE}"
    echo ""
}

### Check required resources
check_resource() {
    printf "$(date) [INFO]: Checking required resource.....................\n" | tee -a "${LOG_FILE}"
    # Total Memory
    info "Total memory (KiB):           $(cat /proc/meminfo  | grep MemTotal | awk '{ print $2 }')"
    if [ $(cat /proc/meminfo  | grep MemTotal | awk '{ print $2 }') -lt ${REQUIRED_MEM_TOTAL} ]; then
        error "Lack of total memory! Required at least ${REQUIRED_MEM_TOTAL} Bytes total memory."
        printf "\r\033[2F\033[K$(date) [INFO]: Checking required resource.....................ng\n" | tee -a "${LOG_FILE}"
        printf "\r\033[2E\033[K" | tee -a "${LOG_FILE}"
    fi

    if [ "${DEP_PATTERN}" != "RHEL8" ]; then
        # Check free space of /var
        info "'/var' free space (MiB):      $(df -m /var | awk 'NR==2 {print $4}')"
        if [ $(df -m /var | awk 'NR==2 {print $4}') -lt ${REQUIRED_FREE_FOR_CONTAINER_IMAGE} ]; then
            printf "\r\033[3F\033[K$(date) [INFO]: Checking required resource.....................ng\n" | tee -a "${LOG_FILE}"
            printf "\r\033[3E\033[K" | tee -a "${LOG_FILE}"
            error "Lack of free space! Required at least ${REQUIRED_FREE_FOR_CONTAINER_IMAGE} MBytes free space on /var directory."
        fi

        # Check free space of current directory 
        info "'${HOME}' free space (MiB):         $(df -m "${HOME}" | awk 'NR==2 {print $4}')"
        if [ $(df -m "${HOME}"| awk 'NR==2 {print $4}') -lt ${REQUIRED_FREE_FOR_EXASTRO_DATA} ]; then
            printf "\r\033[4F\033[K$(date) [INFO]: Checking required resource.....................ng\n" | tee -a "${LOG_FILE}"
            printf "\r\033[4E\033[K" | tee -a "${LOG_FILE}"
            error "Lack of free space! Required at least ${REQUIRED_FREE_FOR_EXASTRO_DATA} MBytes free space on current directory."
        fi
        sleep 1
        printf "\r\033[4F\033[K$(date) [INFO]: Checking required resource.....................ok\n" | tee -a "${LOG_FILE}"
        printf "\r\033[4E\033[K" | tee -a "${LOG_FILE}"
        echo ""
    else
        # Check free space of /var
        info "'${HOME}' free space (MiB):      $(df -m "${HOME}" | awk 'NR==2 {print $4}')"
        if [ $(df -m ${HOME} | awk 'NR==2 {print $4}') -lt ${REQUIRED_FREE_FOR_CONTAINER_IMAGE} ]; then
            printf "\r\033[3F\033[K$(date) [INFO]: Checking required resource.....................ng\n" | tee -a "${LOG_FILE}"
            printf "\r\033[3E\033[K" | tee -a "${LOG_FILE}"
            error "Lack of free space! Required at least ${REQUIRED_FREE_FOR_CONTAINER_IMAGE} MBytes free space on ${HOME} directory."
        else
            sleep 1
            printf "\r\033[3F\033[K$(date) [INFO]: Checking required resource.....................ok\n" | tee -a "${LOG_FILE}"
            printf "\r\033[3E\033[K" | tee -a "${LOG_FILE}"
            echo ""
        fi
    fi
}

### Installation container engine
installation_container_engine() {
    info "Installing container engine..."
    if [ "${DEP_PATTERN}" = "RHEL8" ]; then
        installation_podman_on_rhel8
    elif [ "${DEP_PATTERN}" = "AlmaLinux8" ]; then
        installation_docker_on_alamalinux8
    elif [ "${DEP_PATTERN}" = "Ubuntu20" ]; then
        installation_docker_on_ubuntu
    elif [ "${DEP_PATTERN}" = "Ubuntu22" ]; then
        installation_docker_on_ubuntu
    fi
}

### Installation Podman on RHEL8
installation_podman_on_rhel8() {
    # info "Enable the extras repository"
    # sudo subscription-manager repos --enable=rhel-8-for-x86_64-appstream-rpms --enable=rhel-8-for-x86_64-baseos-rpms

    info "Enable container-tools module"
    sudo dnf module enable -y container-tools:rhel8

    info "Install container-tools module"
    sudo dnf module install -y container-tools:rhel8

    # info "Update packages"
    # sudo dnf update -y

    info "Install Podman"
    sudo dnf install -y podman podman-docker git

    info "Check if Podman is installed"
    if ! command -v podman >/dev/null 2>&1; then
        error "Podman installation failed!"
    fi

    info "Install docker-compose command"
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VER}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod a+x /usr/local/bin/docker-compose

    info "Show Podman version"
    podman --version

    info "Change container netowrk driver"
    mkdir -p ${HOME}/.config/containers/
    cp /usr/share/containers/containers.conf ${HOME}/.config/containers/
    sed -i.$(date +%Y%m%d-%H%M%S) -e 's|^network_backend = "cni"|network_backend = "netavark"|' ${HOME}/.config/containers/containers.conf

    info "Start and enable Podman sockert service"
    systemctl --user enable --now podman.socket
    systemctl --user status podman.socket
    podman unshare chown $(id -u):$(id -g) /run/user/$(id -u)/podman/podman.sock

    DOCKER_HOST="unix:///run/user/$(id -ru)/podman/podman.sock"
    if grep -q "^export DOCKER_HOST" ${HOME}/.bashrc; then
        sed -i -e "s|^export DOCKER_HOST.*|export DOCKER_HOST=${DOCKER_HOST}|" ${HOME}/.bashrc
    else
        echo "export DOCKER_HOST=${DOCKER_HOST}" >> ${HOME}/.bashrc
        echo "alias docker-compose='podman unshare docker-compose'" >> ${HOME}/.bashrc
    fi
}

### Installation Docker on AlmaLinux
installation_docker_on_alamalinux8() {
    # info "Update packages"
    # sudo dnf update -y

    info "Add Docker repository"
    sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo

    info "Install Docker and additional tools"
    sudo dnf install -y docker-ce docker-ce-cli containerd.io git

    info "Start and enable Docker service"
    sudo systemctl enable --now docker

    info "Add current user to the docker group (optional)"
    sudo usermod -aG docker ${USER}
}

### Installation Docker on Ubuntu
installation_docker_on_ubuntu() {
    info "Update packages"
    sudo apt update

    info "Install prerequisites"
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release git

    info "Add Docker GPG key"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    info "Add Docker repository"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    info "Update packages"
    sudo apt update

    info "Install Docker and additional tools"
    sudo apt install -y docker-ce docker-ce-cli containerd.io

    info "Start and enable Docker service (should be already started and enabled)"
    sudo systemctl enable --now docker

    info "Add current user to the docker group (optional)"
    sudo usermod -aG docker ${USER}
}

### Fetch Exastro
fetch_exastro() {
    info "Fetch compose files..."
    cd ${HOME}
    if [ ! -d ${PROJECT_DIR} ]; then
        git clone https://github.com/exastro-suite/exastro-docker-compose.git
        if [ "${DEP_PATTERN}" = "RHEL8" ]; then
            podman unshare chown $(id -u):$(id -g) "${PROJECT_DIR}/.volumes/storage/"
            sudo chcon -R -h -t container_file_t "${PROJECT_DIR}"
        fi
    fi
}

### Setup Exastro system
setup() {

    info "Setup Exastro system..."
    echo "Please regist system settings."
    echo ""

    if [ -f ${ENV_FILE} ]; then
        info "'.env' file is already exist. [${ENV_FILE}]"
        echo ""
        read -r -p "Regenerate .env file? (y/n) [default: n]: " confirm
        echo ""
        if ! (echo $confirm | grep -q -e "[yY]" -e "[yY][eE][sS]"); then
            info "Cancelled."
            exit 0
        fi
    fi
    while true; do

        read -r -p "Generate all password and token automatically.? (y/n) [default: y]: " confirm
        echo ""
        if echo $confirm | grep -q -e "[nN]" -e "[nN][oO]"; then
            PWD_METHOD="manually"
        else
            PWD_METHOD="auto"
        fi

        if [ "${PWD_METHOD}" = "manually" ]; then
            while true; do
                read -r -p "Exastro system admin password: " password1
                echo ""
                if [ "$password1" = "" ]; then
                    echo "Invalid password!!"
                else
                    SYSTEM_ADMIN_PASSWORD=$password1
                    break
                fi
            done
            while true; do
                read -r -p "Database password: " password1
                echo ""
                if [ "$password1" = "" ]; then
                    echo "Invalid password!!"
                else
                    DB_ADMIN_PASSWORD=$password1
                    KEYCLOAK_DB_PASSWORD=$password1
                    ITA_DB_ADMIN_PASSWORD=$password1
                    ITA_DB_PASSWORD=$password1
                    PLATFORM_DB_ADMIN_PASSWORD=$password1
                    PLATFORM_DB_PASSWORD=$password1
                    break
                fi
            done
        else
            password1=$(generate_password 12)
            SYSTEM_ADMIN_PASSWORD=$(generate_password 12)
            DB_ADMIN_PASSWORD=${password1}
            KEYCLOAK_DB_PASSWORD=$(generate_password 12)
            ITA_DB_ADMIN_PASSWORD=${password1}
            ITA_DB_PASSWORD=$(generate_password 12)
            PLATFORM_DB_ADMIN_PASSWORD=${password1}
            PLATFORM_DB_PASSWORD=$(generate_password 12)
        fi
        ENCRYPT_KEY=$(head -c 32 /dev/urandom | base64)

        while true; do
            read -r -p "Service URL? [default: http://127.0.0.1:30080]: " url
            echo ""
            if $(echo "${url}" | grep -q "http://.*") && $(echo "${url}" | grep -q "https://.*") && [ "${url}" != "" ]  ; then
                echo "Invalid URL format"
                continue
            fi
            if [ "$url" = "" ]; then
                EXTERNAL_URL_PROTOCOL=http
                EXTERNAL_URL_HOST=127.0.0.1
                EXTERNAL_URL_PORT=30080
            else
                EXTERNAL_URL_PROTOCOL=$(echo $url | awk -F[:/] '{print $1}')
                EXTERNAL_URL_HOST=$(echo $url | awk -F[:/] '{print $4}')
                EXTERNAL_URL_PORT=$(echo $url | awk -F[:/] '{print $5}')
            fi
            if [ "${EXTERNAL_URL_PORT}" = "" ]; then
                if [ "${EXTERNAL_URL_PROTOCOL}" = "http" ]; then
                    EXTERNAL_URL_PORT="80"
                else
                    EXTERNAL_URL_PORT="443"
                fi
            fi
            break
        done

        while true; do
            read -r -p "Management URL? [default: http://127.0.0.1:30081]: " url
            echo ""
            if $(echo "${url}" | grep -q "http://.*") && $(echo "${url}" | grep -q "https://.*") && [ "${url}" != "" ]  ; then
                echo "Invalid URL format"
                continue
            fi
            if [ "$url" = "" ]; then
                EXTERNAL_URL_MNG_PROTOCOL=http
                EXTERNAL_URL_MNG_HOST=127.0.0.1
                EXTERNAL_URL_MNG_PORT=30081
            else
                EXTERNAL_URL_MNG_PROTOCOL=$(echo $url | awk -F[:/] '{print $1}')
                EXTERNAL_URL_MNG_HOST=$(echo $url | awk -F[:/] '{print $4}')
                EXTERNAL_URL_MNG_PORT=$(echo $url | awk -F[:/] '{print $5}')
            fi
            if [ "${EXTERNAL_URL_MNG_PORT}" = "" ]; then
                if [ "${EXTERNAL_URL_MNG_PROTOCOL}" = "http" ]; then
                    EXTERNAL_URL_MNG_PORT="80"
                else
                    EXTERNAL_URL_MNG_PORT="443"
                fi
            fi
            break
        done

        if [ "${DEP_PATTERN}" = "RHEL8" ]; then
            HOST_DOCKER_GID=1000
            HOST_DOCKER_SOCKET_PATH="/run/user/$(id -ru)/podman/podman.sock"
        else
            HOST_DOCKER_GID=$(grep docker /etc/group|awk -F':' '{print $3}')
            HOST_DOCKER_SOCKET_PATH="/var/run/docker.sock"
        fi

        GITLAB_ROOT_PASSWORD="None"
        GITLAB_ROOT_TOKEN="None"
        read -r -p "Deploy GitLab container? (y/n) [default: n]: " confirm
        echo ""
        if echo $confirm | grep -q -e "[yY]" -e "[yY][eE][sS]"; then
            COMPOSE_PROFILES=all
            GITLAB_PORT="40080"
            if [ ${PWD_METHOD} = "manually" ]; then
                while true; do
                    read -r -p "GitLab root password: " password1
                    echo ""
                    if [ "$password1" = "" ]; then
                        echo "Invalid password!!"
                        continue
                    else
                        GITLAB_ROOT_PASSWORD=$password1
                        break
                    fi
                done

                while true; do
                    read -r -p "GitLab root token (e.g. root-access-token): " password1
                    echo ""
                    if [ "$password1" = "" ]; then
                        echo "Invalid password!!"
                        continue
                    else
                        GITLAB_ROOT_TOKEN=$password1
                        break
                    fi
                done
            else
                password1=$(generate_password 12)
                password2=$(generate_password 20)
                GITLAB_ROOT_PASSWORD=$password1
                GITLAB_ROOT_TOKEN=$password2
            fi
        else
            COMPOSE_PROFILES=except-gitlab
        fi

        cat <<_EOF_
    

System parametes are bellow.

System administrator password:    ********
Database password:                ********
Service URL:                      ${EXTERNAL_URL_PROTOCOL}://${EXTERNAL_URL_HOST}:${EXTERNAL_URL_PORT}
Manegement URL:                   ${EXTERNAL_URL_MNG_PROTOCOL}://${EXTERNAL_URL_MNG_HOST}:${EXTERNAL_URL_MNG_PORT}
Docker GID:                       ${HOST_DOCKER_GID}
Docker Socket path:               ${HOST_DOCKER_SOCKET_PATH}
GitLab deployment:                $(if [ ${COMPOSE_PROFILES} = "all" ]; then echo "true"; else echo "false"; fi)
_EOF_
        if [ "${COMPOSE_PROFILES}" = "all" ]; then
            cat <<_EOF_
GitLab URL:                       ${EXTERNAL_URL_PROTOCOL}://${EXTERNAL_URL_HOST}:${GITLAB_PORT}
GitLab root password:             ********
GitLab root token:                ********

_EOF_
        else
            cat <<_EOF_
GitLab URL:                       None

_EOF_
        fi

        read -r -p "Generate .env file by above settings? (y/n) [default: n]: " confirm
        echo ""
        if echo $confirm | grep -q -e "[yY]" -e "[yY][eE][sS]"; then
            info "Generate settig file [${PWD}/.env]."
            info "System administrator password:    ********"
            info "Database password:                ********"
            info "Service URL:                      ${EXTERNAL_URL_PROTOCOL}://${EXTERNAL_URL_HOST}:${EXTERNAL_URL_PORT}"
            info "Manegement URL:                   ${EXTERNAL_URL_MNG_PROTOCOL}://${EXTERNAL_URL_MNG_HOST}:${EXTERNAL_URL_MNG_PORT}"
            info "Docker GID:                       ${HOST_DOCKER_GID}"
            info "Docker Socket path:               ${HOST_DOCKER_SOCKET_PATH}"
            if [ "${COMPOSE_PROFILES}" = "all" ]; then
                info "GitLab URL:                       ${EXTERNAL_URL_PROTOCOL}://${EXTERNAL_URL_HOST}:${GITLAB_PORT}"
                info "GitLab root password:             ********"
                info "GitLab root token:                ********"
            else
                info "GitLab URL:                       None"
            fi
            
            generate_env
            break
        fi
    done
}

### Generate .env file
generate_env() {
    if [ -f ${ENV_FILE} ]; then
        mv -f ${ENV_FILE} ${ENV_FILE}.$(date +%Y%m%d-%H%M%S) 
    fi
    cp -f ${ENV_FILE}.docker.sample ${ENV_FILE}
    sed -i -e "s/^SYSTEM_ADMIN_PASSWORD=.*/SYSTEM_ADMIN_PASSWORD=${SYSTEM_ADMIN_PASSWORD}/" ${ENV_FILE}
    sed -i -e "s/^DB_ADMIN_PASSWORD=.*/DB_ADMIN_PASSWORD=${DB_ADMIN_PASSWORD}/" ${ENV_FILE}
    sed -i -e "s/^KEYCLOAK_DB_PASSWORD=.*/KEYCLOAK_DB_PASSWORD=${KEYCLOAK_DB_PASSWORD}/" ${ENV_FILE}
    sed -i -e "s/^ITA_DB_ADMIN_PASSWORD=.*/ITA_DB_ADMIN_PASSWORD=${ITA_DB_ADMIN_PASSWORD}/" ${ENV_FILE}
    sed -i -e "s/^ITA_DB_PASSWORD=.*/ITA_DB_PASSWORD=${ITA_DB_PASSWORD}/" ${ENV_FILE}
    sed -i -e "s/^PLATFORM_DB_ADMIN_PASSWORD=.*/PLATFORM_DB_ADMIN_PASSWORD=${PLATFORM_DB_ADMIN_PASSWORD}/" ${ENV_FILE}
    sed -i -e "s/^PLATFORM_DB_PASSWORD=.*/PLATFORM_DB_PASSWORD=${PLATFORM_DB_PASSWORD}/" ${ENV_FILE}
    sed -i -e "/^# EXTERNAL_URL_PROTOCOL=.*/a EXTERNAL_URL_PROTOCOL=${EXTERNAL_URL_PROTOCOL}" ${ENV_FILE}
    sed -i -e "/^# EXTERNAL_URL_HOST=.*/a EXTERNAL_URL_HOST=${EXTERNAL_URL_HOST}" ${ENV_FILE}
    sed -i -e "/^# EXTERNAL_URL_PORT=.*/a EXTERNAL_URL_PORT=${EXTERNAL_URL_PORT}" ${ENV_FILE}
    sed -i -e "/^# EXTERNAL_URL_MNG_PROTOCOL=.*/a EXTERNAL_URL_MNG_PROTOCOL=${EXTERNAL_URL_MNG_PROTOCOL}" ${ENV_FILE}
    sed -i -e "/^# EXTERNAL_URL_MNG_HOST=.*/a EXTERNAL_URL_MNG_HOST=${EXTERNAL_URL_MNG_HOST}" ${ENV_FILE}
    sed -i -e "/^# EXTERNAL_URL_MNG_PORT=.*/a EXTERNAL_URL_MNG_PORT=${EXTERNAL_URL_MNG_PORT}" ${ENV_FILE}
    sed -i -e "s/^HOST_DOCKER_GID=.*/HOST_DOCKER_GID=${HOST_DOCKER_GID}/" ${ENV_FILE}
    sed -i -e "/^# HOST_DOCKER_SOCKET_PATH=.*/a HOST_DOCKER_SOCKET_PATH=${HOST_DOCKER_SOCKET_PATH}" ${ENV_FILE}
    sed -i -e "s/^COMPOSE_PROFILES=.*/COMPOSE_PROFILES=${COMPOSE_PROFILES}/" ${ENV_FILE}
    sed -i -e "s/^GITLAB_ROOT_PASSWORD=.*/GITLAB_ROOT_PASSWORD=${GITLAB_ROOT_PASSWORD}/" ${ENV_FILE}
    sed -i -e "s/^GITLAB_ROOT_TOKEN=.*/GITLAB_ROOT_TOKEN=${GITLAB_ROOT_TOKEN}/" ${ENV_FILE}
    if [ ${COMPOSE_PROFILES} = "all" ]; then
        sed -i -e "s/^GITLAB_HOST=.*/GITLAB_HOST=${EXTERNAL_URL_HOST}/" ${ENV_FILE}
        sed -i -e "/^# GITLAB_PORT=.*/a GITLAB_PORT=${GITLAB_PORT}" ${ENV_FILE}
    fi
}

### Installation Exastro
installation_exastro() {
    if [ "${DEP_PATTERN}" = "RHEL8" ]; then
        DOCKER_COMPOSE=$(command -v docker-compose)
        installation_exastro_on_rhel8
    fi
    DOCKER_COMPOSE=$(command -v docker)" compose"
    installation_cronjob
    installtion_firewall_rules
}

### Installation Exastro on RHEL8
installation_exastro_on_rhel8() {
    info "Installing Exastro service..."
    cat << _EOF_ >${HOME}/.config/systemd/user/exastro.service
[Unit]
Description=Exastro System
After=podman.socket
Requires=podman.socket
 
[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=${PROJECT_DIR}
ExecStartPre=/usr/bin/podman unshare chown $(id -u):$(id -g) /run/user/$(id -u)/podman/podman.sock
Environment=DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock
Environment=PWD=${PROJECT_DIR}
ExecStart=podman unshare ${DOCKER_COMPOSE} --profile ${COMPOSE_PROFILES} -f ${COMPOSE_FILE} --env-file ${ENV_FILE} up -d
ExecStop=podman unshare ${DOCKER_COMPOSE} --profile ${COMPOSE_PROFILES} -f ${COMPOSE_FILE} --env-file ${ENV_FILE} down
 
[Install]
WantedBy=default.target
_EOF_
    systemctl --user daemon-reload
    systemctl --user enable exastro
}

### Installation job to Crontab
installation_cronjob() {
    # Specify the input file name and output file name here
    cd 
    backup_file="${PROJECT_DIR}/backup/crontab."$(date +%Y%m%d-%H%M%S)
    output_file="${HOME}/.tmp.txt"

    # Backup current crontab
    crontab -l > $backup_file || :

    if ! grep -q "Exastro auto generate" $backup_file; then
        crontab -l 2>/dev/null > $output_file || :
        cat << _EOF_ >> $output_file
######## START Exastro auto generate (DO NOT REMOVE bellow lines.) ########
0 * * * * cd ${PROJECT_DIR}; ${DOCKER_COMPOSE} --profile ${COMPOSE_PROFILES} run ita-by-execinstance-dataautoclean > /dev/null 2>&1
0 * * * * cd ${PROJECT_DIR}; ${DOCKER_COMPOSE} --profile ${COMPOSE_PROFILES} run ita-by-file-autoclean > /dev/null 2>&1
######## END Exastro auto generate   (DO NOT REMOVE bellow lines.) ########
_EOF_
        cat $output_file | crontab -
        rm -f $output_file
        info "Registed job to crontab."
    else
        info "Already registed job to crontab."
        rm -f $backup_file
    fi
}

### Installation Firewall rules
installtion_firewall_rules() {
    info "Add firewall rules."
    if [ ${FIREWALLD_STATUS} = "active" ]; then
        info "Add ${EXTERNAL_URL_PORT}/tcp for external service port."
        sudo firewall-cmd --add-port=${EXTERNAL_URL_PORT}/tcp --zone=public --permanent
        info "Add ${EXTERNAL_URL_MNG_PORT}/tcp for external management port."
        sudo firewall-cmd --add-port=${EXTERNAL_URL_MNG_PORT}/tcp --zone=public --permanent
        if [ ${COMPOSE_PROFILES} = "all" ]; then
            info "Add ${GITLAB_PORT}/tcp for external GitLab port."
            sudo firewall-cmd --add-port=${GITLAB_PORT}/tcp --zone=public --permanent
        fi
        sudo firewall-cmd --reload
    fi
    if [ ${UFW_STATUS} = "active" ]; then
        info "Add ${EXTERNAL_URL_PORT}/tcp for external service port."
        sudo ufw allow ${EXTERNAL_URL_PORT}/tcp
        info "Add ${EXTERNAL_URL_MNG_PORT}/tcp for external management port."
        sudo ufw allow ${EXTERNAL_URL_MNG_PORT}/tcp
        if [ ${COMPOSE_PROFILES} = "all" ]; then
            info "Add ${GITLAB_PORT}/tcp for external GitLab port."
            sudo ufw allow ${GITLAB_PORT}/tcp
        fi
        sudo ufw reload
    fi
}

### Start Exastro system
start_exastro() {
    info "Starting Exastro system..."
    read -r -p "Deploy Exastro containers now? (y/n) [default: n]: " confirm
    echo ""
    if echo $confirm | grep -q -e "[yY]" -e "[yY][eE][sS]"; then
        echo "Please wait for a little while. It will take 10 minutes or later.........."
        if [ "${DEP_PATTERN}" = "RHEL8" ]; then
            systemctl --user start exastro
            # pid1=$!
        else
            cd ${PROJECT_DIR}
            sudo -u $(id -u -n) -E ${DOCKER_COMPOSE} --profile ${COMPOSE_PROFILES:-all} -f ${COMPOSE_FILE} --env-file ${ENV_FILE} up -d
            # pid1=$!
        fi
    else
        info "Cancelled."
        exit 0
    fi
    # printf "\r\033[2KPlease wait installation completed.";
    # while true;
    # do
    #     sleep 0.1
    #     printf ".";
    # done &
    # pid2=$!
    # wait $pid1
    # printf "Complete!\n"
    # kill $pid2
    # wait $pid2 2> /dev/null
}

### Display Exastro system information
prompt() {
    banner
    cat<<_EOF_


System manager page:
  URL:                ${EXTERNAL_URL_MNG_PROTOCOL}://${EXTERNAL_URL_MNG_HOST}:${EXTERNAL_URL_MNG_PORT}/auth/
  Login user:         admin
  Initial password:   ${SYSTEM_ADMIN_PASSWORD}

Organization page:
  URL:                ${EXTERNAL_URL_PROTOCOL}://${EXTERNAL_URL_HOST}:${EXTERNAL_URL_PORT}/{{ Organization ID }}/platform

_EOF_
    if [ "${COMPOSE_PROFILES}" = "all" ]; then
        cat <<_EOF_


Make sure you can successfully access the GitLab login screen.

Wait until the GitLab container has completely started before creating the organization.
It may take more than 5 minutes.

If you are unable to access due to a 503 error, please wait a while and try again.

GitLab page:
  URL:                ${EXTERNAL_URL_PROTOCOL}://${EXTERNAL_URL_HOST}:${GITLAB_PORT}
  Login user:         root
  Initial password:   ${GITLAB_ROOT_PASSWORD}

_EOF_
    printf "GitLab service is not ready."
    while [ $(curl -s -I -o nul -w "%{http_code}" ${GITLAB_PROTOCOL:-http}://${GITLAB_HOST:-localhost}:${GITLAB_PORT:-40080}/users/sign_in) -ne 200 ]; do
        printf "."
        sleep 1
    done
    while [ $(curl -s -I -o nul -w "%{http_code}" "PRIVATE-TOKEN: ${GITLAB_ROOT_TOKEN:-}" "${GITLAB_PROTOCOL:-http}://${GITLAB_HOST:-localhost}:${GITLAB_PORT:-40080}/api/v4/version") -ne 200 ]; do
        printf "."
        sleep 1
    done
    echo ""
    echo "GitLab service is has completely started!"
fi

    cat<<_EOF_

Run creation organization command:
   bash ${PROJECT_DIR}/create-organization.sh 


! ! ! ! ! ! ! ! ! ! ! ! ! ! !
! ! !   C A U T I O N   ! ! !
! ! ! ! ! ! ! ! ! ! ! ! ! ! !

Be sure to reboot the you host operating system to ensure proper system operation.

_EOF_
}

### Get options when remove
remove() {
    args=$(getopt -o "ch" --long "completely-clean-up,help" -- "$@") || exit 1

    eval set -- "$args"

    while true; do
        case "$1" in
            -c | --crean-up )
                shift
                REMOVE_FLG="c"
                ;;
            -- )
                shift
                break
                ;;
            * )
                shift
                cat <<'_EOF_'

Usage:
  exastro remove [options]

Options:
  -c, --completely-clean-up         Remove all containers, persistent data and configurations.

_EOF_
                exit 2
                ;;
        esac
    done

    info "======================================================"
    info "Remove Exastro system."
    get_system_info
    if [ "$REMOVE_FLG" = "" ]; then
        echo ""
        read -r -p "Really remove all containers? But, not remove presistent data. (y/n) [default: n]: " confirm
        if echo $confirm | grep -q -e "[yY]" -e "[yY][eE][sS]"; then
            remove_cronjob
            remove_service
            check_security
            remove_firewall_rules
        else
            info "Cancelled."
            exit 0
        fi
    elif [ "$REMOVE_FLG" = "c" ]; then
        echo ""
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "!!              ! ! !  C A U T I O N  ! ! !                     !!!"
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo ""
        echo "You will NEVER be able to recovery your data again."
        read -r -p "Really remove all containers and persistent data? (y/n) [default: n]: " confirm
        if echo $confirm | grep -q -e "[yY]" -e "[yY][eE][sS]"; then
            remove_cronjob
            remove_service
            check_security
            remove_firewall_rules
            remove_exastro_data
        else
            info "Cancelled."
            exit 0
        fi
    fi
}

### Remvoe job to Crontab
remove_cronjob() {
    info "Removing Exastro cron job..."
    # Specify the input file name and output file name here

    input_file="${PROJECT_DIR}/backup/crontab."$(date +%Y%m%d-%H%M%S)
    output_file="${HOME}/.tmp.txt"
    touch $output_file

    # Backup current crontab
    crontab -l > $input_file

    # Specify the starting string and ending string for deletion here
    start_string="START Exastro auto generate"
    end_string="END Exastro auto generate"

    # Check if the input file exists
    if [ ! -f "$input_file" ]; then
        error "File does not exist: $input_file"
        exit 1
    fi

    # Read input file line by line and write to output file, while excluding the specified lines
    delete_lines=false
    while read -r line; do
        if echo $line | grep -q "$start_string"; then
            delete_lines="true"
        fi
        if [ "$delete_lines" = "false" ]; then
            echo "$line" >> $output_file
        fi
        if echo $line | grep -q "$end_string"; then
            delete_lines="false"
        fi
    done < $input_file

    # Display the result
    cat $output_file | crontab -
    info "Remove cron job completed."
    rm -f $output_file
}

### Remove Exastro service
remove_service() {
    info "Stopping and removing Exastro service..."
    cd ${PROJECT_DIR}
 
    DOCKER_COMPOSE="docker compose"
    if [ "${DEP_PATTERN}" = "RHEL8" ]; then
        DOCKER_COMPOSE="podman unshare docker-compose"
    fi

    ${DOCKER_COMPOSE} --profile all down
    if [ "${DEP_PATTERN}" = "RHEL8" ]; then
        systemctl --user disable --now exastro
        rm -f ${HOME}/.config/systemd/user/exastro.service
        systemctl --user daemon-reload
    fi
    info "Remove Exastro service completed."
}

### Installation Firewall rules
remove_firewall_rules() {
    info "Remove firewall rules."
    if [ ${FIREWALLD_STATUS} = "active" ]; then
        info "Remove ${EXTERNAL_URL_PORT}/tcp for external service port."
        sudo firewall-cmd --remove-port=${EXTERNAL_URL_PORT}/tcp --zone=public --permanent
        info "Remove ${EXTERNAL_URL_MNG_PORT}/tcp for external management port."
        sudo firewall-cmd --remove-port=${EXTERNAL_URL_MNG_PORT}/tcp --zone=public --permanent
        if [ ${COMPOSE_PROFILES} = "all" ]; then
            info "Remove ${GITLAB_PORT}/tcp for external GitLab port."
            sudo firewall-cmd --remove-port=${GITLAB_PORT}/tcp --zone=public --permanent
        fi
        sudo firewall-cmd --reload
    fi
    if [ ${UFW_STATUS} = "active" ]; then
        info "Remove ${EXTERNAL_URL_PORT}/tcp for external service port."
        sudo ufw deny ${EXTERNAL_URL_PORT}/tcp
        info "Remove ${EXTERNAL_URL_MNG_PORT}/tcp for external management port."
        sudo ufw deny ${EXTERNAL_URL_MNG_PORT}/tcp
        if [ ${COMPOSE_PROFILES} = "all" ]; then
            info "Remove ${GITLAB_PORT}/tcp for external GitLab port."
            sudo ufw deny ${GITLAB_PORT}/tcp
        fi
        sudo ufw reload
    fi
}

### Remove all containers and data
remove_exastro_data() {
        info "Deleting Exastro system..."
        cd ${PROJECT_DIR}
        DOCKER_COMPOSE="docker compose"
        if [ "${DEP_PATTERN}" = "RHEL8" ]; then
            DOCKER_COMPOSE="podman unshare docker-compose"
        fi
        ${DOCKER_COMPOSE} --profile all down -v
        sudo rm -rf ${PROJECT_DIR}/.volumes/storage/*
        # yes | docker system prune
}

main "$@"

#!/bin/bash

set -e

# Inspired from dokku config plugin https://github.com/dokku/dokku/blob/a308ff65464dce6ce1bb709e3afddd7066e77381/plugins/config/commands

function get_script_file() {
    local script_file
    script_file="$(basename "$0")"
    if [ -z "$(which "$script_file")" ]; then
        script_file="./$script_file"
    fi
    echo "$script_file"
}

# Constants:
SCRIPT_FILE="$(get_script_file)"
SCRIPT_VERSION="0.2.0-alpha.1"
SCRIPT_DESCRIPTION="Config the \`.env\` file, dotenv v$SCRIPT_VERSION"
TRY_HELP_COMMAND_FOR_MORE_INFORMATION="Try \`$SCRIPT_FILE --help\` for more information"
KEY_REGEX="[a-zA-Z_][a-zA-Z0-9_]*"

# Options
verbose=false
export_prefix="export "
force=false
from_file=false
env_file="$PWD/.env"
backup_file=false
delimiter=" "

function cat_help_message() {
    cat <<EOF
$SCRIPT_DESCRIPTION

Usage:
  $SCRIPT_FILE [OPTIONS] COMMAND [CMD_OPTIONS]     execute the script with the specified command and/or options
  $SCRIPT_FILE -h|--help                           display this output
  $SCRIPT_FILE -v|--version                        display the script version

Options:
  --path <string>                   \`"\$PWD/.env"\` by default, the path of the \`.env\` file
                                    e.g. \`$SCRIPT_FILE --path "\$PWD/prod.env" init\`
  --no-export-prefix                the "$export_prefix" prefix will be added by default, use \`--no-export-prefix\` to disable it
                                    e.g. \`$SCRIPT_FILE --no-export-prefix set DEBUG=true\`, will write \`DEBUG=true\`
                                    e.g. \`$SCRIPT_FILE set DEBUG=true\`, will write \`${export_prefix}DEBUG=true\`
  -vvv|--verbose                    the verbose mode, disabled by default, use \`-vvv\` or \`--verbose\` to enable it

Commands:
  init [CMD_OPTIONS]                create an empty \`.env\` file, only if \`.env\` not already exists
       --from <string>              use a source file to init the \`.env\` file, only if \`.env\` not already exists
                                    e.g. \`$SCRIPT_FILE init --from "\$PWD/.env.default"\`
       --force                      force the init if an \`.env\` already exist, a backup for the existent file will be created
                                    e.g. \`$SCRIPT_FILE init --force\`
       --backup-file <string>       used with \`--force\` cmd option to force the backup file name instead of auto-naming
                                    e.g. \`$SCRIPT_FILE init --force --backup-file "\$PWD/.env-20221127235937.bak"\`

  get KEY                           get the value of the passed KEY
                                    e.g. \`$SCRIPT_FILE get DEBUG\`, will return the value of the DEBUG env var
                                    you can use the \`--no-export-prefix\` to get the value without "$export_prefix"
                                    e.g. \`$SCRIPT_FILE --no-export-prefix get DEBUG\`

  set KEY1=VALUE1 [KEY2=VALUE2 ...] set the value of the passed key(s)
                                    e.g. \`$SCRIPT_FILE set DEBUG=true\`
                                    e.g. \`$SCRIPT_FILE set APP_ROOT="\$PWD" DEBUG=true API_VERSION="v1"\`
                                    e.g. \`$SCRIPT_FILE set DB_PASSWORD="\$(printenv APP_DB_PASSWORD)" APP_ROOT="\$PWD" API_VERSION="v1"\`

  unset KEY1 [KEY2 ...]             unset the the passed key(s)
                                    e.g. \`$SCRIPT_FILE unset DEBUG API_VERSION\`

  list                              list the env vars
                                    e.g. \`$SCRIPT_FILE list\`
                                    you can use the \`--no-export-prefix\` to list only the vars without "$export_prefix"

  keys [CMD_OPTIONS]                get the list of env var keys separated by whitespace \`" "\`(the default delimiter)
       --delimiter <character>      single character delimiter, can't be an empty string
                                    you can use \`\n\`(for newline) or \`,\`, \`:\` ...
                                    e.g. \`$SCRIPT_FILE keys --delimiter " "\`
                                    you can use the \`--no-export-prefix\` to get the keys without "$export_prefix"
                                    e.g. \`$SCRIPT_FILE --no-export-prefix keys\`

  has KEY1 [KEY2 ...]               check if key(s) exist(s) and return 0 or 1
                                    e.g. \`$SCRIPT_FILE has DEBUG API_VERSION\`
                                    you can use the verbose flag to get a success or error message
                                    e.g. \`$SCRIPT_FILE --verbose has DEBUG API_VERSION\`
                                    you can use the \`--no-export-prefix\` to check only the key(s) without "$export_prefix"
                                    e.g. \`$SCRIPT_FILE --no-export-prefix has DEBUG API_VERSION\`

  truncate [CMD_OPTIONS]            truncate the \`.env\` file
           --force                  force the truncate, avoid the prompt message

  backup [CMD_OPTIONS]              create a backup file for the \`.env\` using this format \`<env_file_name>-<now>.bak\`
                                    e.g. \`$SCRIPT_FILE backup\`, will create a copy from \`.env\` named \`.env-20221125192400.bak\`
         --backup-file <string>     force the backup file name instead of auto-naming
                                    e.g. \`$SCRIPT_FILE backup --backup-file "\$PWD/.env-20221127235937.bak"\`

  destroy [CMD_OPTIONS]             remove the \`.env\` file
          --force                   force the destroy, avoid the prompt message
EOF
}

# Display the passed message only if verbose is true
function verbose_message() {
    local message="$1"
    if [ "$verbose" == true ]; then
        echo "$message"
    fi
}

function echo_invalid_option_for_command() {
    local option="$1"
    local cmd="$2"

    echo " ✘ Invalid \`$option\` option for \`$cmd\` command !"
}

function test_path_option() {
    local value="$1"
    if [[ -z "$value" ]]; then
        echo " ✘ Missing \`--path\` option value !"
        echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
        exit 1
    fi
}

function test_from_option() {
    local cmd="$1"
    local value="$2"
    if [[ -z "$value" ]]; then
        echo " ✘ Missing \`--from\` option value for the \`$cmd\` command !"
        echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
        exit 1
    fi
}

function test_backup_file_option() {
    local cmd="$1"
    local value="$2"
    if [[ -z "$value" ]]; then
        echo " ✘ Missing \`--backup-file\` option value for the \`$cmd\` command !"
        echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
        exit 1
    fi
}

function test_delimiter_option() {
    local cmd="$1"
    local value="$2"
    if [[ -z "$value" ]]; then
        echo " ✘ Missing \`--delimiter\` option value for the \`$cmd\` command !"
        echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
        exit 1
    fi
}

function case_init() {
    local env_file="$1"
    local force="$2"
    local from_file="$3"
    local backup_file="$4"

    if [[ "$from_file" != "false" ]] && [[ ! -f "$from_file" ]]; then
        echo " The source file \`$from_file\` used to init the .env file doesn't exist !"
        echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
        exit 1
    fi

    if [ -f "$env_file" ]; then
        if [[ "$force" == "true" ]]; then
            echo "The \`$env_file\` already exist, creating a backup file ..."
            _create_backup_file_and_echo_success_message "$env_file" "$backup_file"
        else
            echo " ✘ The \`$env_file\` already exist, you can use the \`--force\` option !"
            echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
            exit 1
        fi
    fi

    if [[ "$from_file" == "false" ]]; then
        # create an empty file, don't use `touch` since it will not override the file if it already exists !!!
        true >"$env_file"
        echo " ✔ The \`$env_file\` file has been successfully created !"
    else
        cp -p "$from_file" "$env_file"
        echo " ✔ The \`$env_file\` file has been successfully created from \`$from_file\` !"
    fi
}

function case_get() {
    local env_file="$1"
    local key="$2"
    local export_prefix="$3"
    local filtered_output
    local key_line
    local value

    throw_an_error_if_env_file_does_not_exist "$env_file"

    # grep <"$env_file" -Eo "$export_prefix([a-zA-Z_][a-zA-Z0-9_]*=.*)" | cut -d" " -f2 | grep "^$key=" | cut -d"=" -f2-
    filtered_output=$(_strip_comments_and_export_prefix_from_env_file "$env_file" "$export_prefix")
    if ! _key_exists "$filtered_output" "$key"; then
        echo " ✘ Undefined KEY \`$key\` for \`get\` command !"
        echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
        exit 1
    fi

    key_line=$(echo "$filtered_output" | grep "^$key=")
    value=$(echo "$key_line" | cut -d"=" -f2-)
    echo "$value"
}

function case_set() {
    local env_file="$1"
    local export_prefix="$2"
    local vars="$3" # as whitespace separated string
    local setting=""
    local env_temp

    throw_an_error_if_env_file_does_not_exist "$env_file"

    # convert the `$vars` string to an array and assign it to `$vars_array`
    read -r -a vars_array <<<"$vars"
    for var in "${vars_array[@]}"; do
        _test_var_format "$var"
    done

    env_temp=$(cat "$env_file")
    filtered_output=$(_strip_comments_and_export_prefix_from_env_file "$env_file" "$export_prefix")

    for var in "${vars_array[@]}"; do
        local key
        local value
        local new_var
        key=$(echo "$var" | cut -d"=" -f1)
        value=$(echo "$var" | cut -d"=" -f2-)

        if _key_exists "$filtered_output" "$key"; then
            env_temp=$(echo -e "$env_temp" | sed -E "s/^$export_prefix$key=.+/$export_prefix$key=$value/")
            setting+="\n   ✔ The \`$key\` var has been updated !"
        else
            new_var="$export_prefix$key=$value"
            if [ -z "$env_temp" ]; then
                env_temp="$new_var"
            else
                env_temp+="\n$new_var"
            fi
            setting+="\n   ✔ The \`$key\` var has been added !"
        fi
    done

    echo " Setting .env var(s) to \`$env_file\` file:"
    echo -e "$env_temp" >"$env_file"
    echo -e "$setting\n"
}

function case_unset() {
    local env_file="$1"
    local export_prefix="$2"
    local keys="$3" # as whitespace separated string
    local filtered_output
    local var_or_vars_string="var" # singular or plural form of the "var" string
    local env_temp

    throw_an_error_if_env_file_does_not_exist "$env_file"

    env_temp=$(cat "$env_file")
    filtered_output=$(_strip_comments_and_export_prefix_from_env_file "$env_file" "$export_prefix")

    # convert the `$keys` string to an array and assign it to `$keys_array`
    read -r -a keys_array <<<"$keys"
    # loop the `$keys_array`
    for key in "${keys_array[@]}"; do
        if ! _key_exists "$filtered_output" "$key"; then
            echo " ✘ Undefined KEY \`$key\` for \`unset\` command !"
            echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
            exit 1
        fi
    done

    for key in "${keys_array[@]}"; do
        env_temp=$(echo -e "$env_temp" | sed "/^$export_prefix$key=/ d")
    done

    if [ ${#keys_array[@]} -gt 1 ]; then
        var_or_vars_string="vars"
    fi

    echo -e "$env_temp" >"$env_file"
    echo " ✔ The \`${keys// /, }\` $var_or_vars_string has been removed from your \`$env_file\` file !"
}

function case_list() {
    local env_file="$1"
    local export_prefix="$2"
    local filtered_output
    local key_or_keys_string="key" # singular or plural form of the "key" string

    throw_an_error_if_env_file_does_not_exist "$env_file"

    filtered_output=$(_strip_comments_and_export_prefix_from_env_file "$env_file" "$export_prefix")

    if [ -z "$filtered_output" ]; then
        echo " ✘ No vars found for \`$env_file\` !"
        echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
        exit
    fi

    echo " ✔ The \`$env_file\` file vars list:"
    _config_styled_hash "$filtered_output"
}

function case_keys() {
    local env_file="$1"
    local export_prefix="$2"
    local delimiter="$3"
    local keys_list=""

    throw_an_error_if_env_file_does_not_exist "$env_file"

    filtered_output=$(_strip_comments_and_export_prefix_from_env_file "$env_file" "$export_prefix")

    if [ -z "$filtered_output" ]; then
        echo " ✘ No vars found for \`$env_file\` !"
        echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
        exit 1
    fi

    # first pipe: cut used to keep only the keys(remove the "=VALUE")
    # second pipe: tr used to force the command `--delimiter` option but it will add an extra delimiter at the end !
    # third pipe: sed used to remove the extra delimiter added by the `tr` command
    keys_list=$(echo -e "$filtered_output" | cut -d"=" -f1 | tr '\n' "$delimiter" | sed "s/$delimiter$//")
    echo -e "$keys_list"
}

function case_has() {
    local env_file="$1"
    local export_prefix="$2"
    local keys="$3" # as whitespace separated string
    local filtered_output
    local key_or_keys_string="key" # singular or plural form of the "key" string

    throw_an_error_if_env_file_does_not_exist "$env_file"

    filtered_output=$(_strip_comments_and_export_prefix_from_env_file "$env_file" "$export_prefix")

    # convert the `$keys` string to an array and assign it to `$keys_array`
    read -r -a keys_array <<<"$keys"
    # loop the `$keys_array`
    for key in "${keys_array[@]}"; do
        if ! _key_exists "$filtered_output" "$key"; then
            verbose_message " ✘ Undefined KEY \`$key\` for \`has\` command !"
            verbose_message "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
            exit 1
        fi
    done

    if [ ${#keys_array[@]} -gt 1 ]; then
        key_or_keys_string="keys"
    fi

    verbose_message " ✔ The \`$env_file\` file has the \`${keys// /, }\` $key_or_keys_string !"
}

function case_backup() {
    local env_file="$1"
    local backup_file="$2"

    throw_an_error_if_env_file_does_not_exist "$env_file"

    _create_backup_file_and_echo_success_message "$env_file" "$backup_file"
}

function case_truncate() {
    local env_file="$1"
    local force="$2"

    throw_an_error_if_env_file_does_not_exist "$env_file"

    if [ -f "$env_file" ]; then
        if [[ "$force" == "true" ]]; then
            _truncate_env_file_and_echo_success_message "$env_file"
        else
            read -r -p "Confirm the truncate of \`$env_file\` (y/N) ? " confirm
            case "$confirm" in
            y)
                _truncate_env_file_and_echo_success_message "$env_file"
                ;;
            *)
                echo " The truncate of \`$env_file\` file has been canceled !"
                ;;
            esac
        fi
    fi
}

function case_destroy() {
    local env_file="$1"
    local force="$2"

    throw_an_error_if_env_file_does_not_exist "$env_file"

    if [ -f "$env_file" ]; then
        if [[ "$force" == "true" ]]; then
            _remove_env_file_and_echo_success_message "$env_file"
        else
            read -r -p "Confirm the destroy of \`$env_file\` (y/N) ? " confirm
            case "$confirm" in
            y)
                _remove_env_file_and_echo_success_message "$env_file"
                ;;
            *)
                echo " The destroy of \`$env_file\` file has been canceled !"
                ;;
            esac
        fi
    fi
}

function _create_backup_file_and_echo_success_message() {
    local env_file="$1"
    local backup_file="$2"
    local now
    local env_backup_file

    if [ "$backup_file" != "false" ]; then
        env_backup_file="$backup_file"
    else
        now=$(date '+%Y%m%d%H%M%S')
        env_backup_file="$env_file-$now.bak"
    fi
    cp -p "$env_file" "$env_backup_file"
    echo " ✔ The backup file \`$env_backup_file\` of \`$env_file\` has been successfully created !"
}

function throw_an_error_if_env_file_does_not_exist() {
    local env_file="$1"
    if [ ! -f "$env_file" ]; then
        echo " ✘ The env file \`$env_file\` doesn't exist !"
        echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
        exit 1
    fi
}

function throw_an_error_if_missing_command_to_exec() {
    local cmd="$1"
    if [ -z "$cmd" ]; then
        echo " ✘ Missing command to exec, e.g. \`init\`, \`get KEY\`, \`set KEY1=VALUE1 [KEY2=VALUE2]\`, \`unset KEY1 [KEY2]\`, \`list\`, \`has KEY1 [KEY2]\`, \`destroy\` !"
        echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
        exit 1
    fi
}

function _remove_env_file_and_echo_success_message() {
    local env_file="$1"
    rm -f "$env_file"
    echo " ✔ The \`$env_file\` file has been successfully removed !"
}

function _truncate_env_file_and_echo_success_message() {
    local env_file="$1"
    true >"$env_file"
    echo " ✔ The \`$env_file\` file has been successfully truncated !"
}

function _key_exists() {
    local filtered_output="$1" # the output without comments and export_prefix
    local key="$2"
    if echo "$filtered_output" | grep -q "^$key="; then
        return 0
    else
        return 1
    fi
}

function _test_var_format() {
    local var="$1"
    local key

    if [[ ! $var =~ ^.+=.+$ ]]; then
        echo " ✘ Missing KEY or VALUE for \`${var//=/}\` var, try this format \`YOUR_KEY=YOUR_VALUE\` !"
        echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
        exit 1
    fi

    key=$(echo "$var" | cut -d"=" -f1)

    if [[ ! $key =~ $KEY_REGEX ]]; then
        echo " ✘ Invalid key \`$key\` name, keys must start with a letter or \`_\`, followed by alphanumeric character(s) !"
        echo "e.g. \`DEBUG\`, \`_USER\`, \`__DATA\`, \`API_V1_LINK\` ..."
        echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
        exit 1
    fi
}

function _strip_comments_and_export_prefix_from_env_file() {
    local env_file="$1"
    local export_prefix="$2"
    grep <"$env_file" -Eo "^$export_prefix([a-zA-Z_][a-zA-Z0-9_]*=.+)" | cut -d" " -f2
}

function _config_styled_hash() {
    local vars="$1"
    local longest

    longest=""
    for word in $vars; do
        local key
        key=$(echo "$word" | cut -d"=" -f1)
        if [ ${#key} -gt ${#longest} ]; then
            longest=$key
        fi
    done

    for word in $vars; do
        local key
        local value
        local num_zeros
        local zeros
        key=$(echo "$word" | cut -d"=" -f1)
        value=$(echo "$word" | cut -d"=" -f2-)

        num_zeros=$((${#longest} - ${#key}))
        zeros=" "
        while [ $num_zeros -gt 0 ]; do
            zeros="$zeros "
            num_zeros=$((num_zeros - 1))
        done
        echo -e "$key:$zeros$value"
    done
}

# No args passed, just display the help message :)
if [ $# -eq 0 ]; then
    cat_help_message
    exit
fi

# Display the help or version message and exit with 0;
if [ $# -eq 1 ]; then
    case $1 in
    --version | -v)
        echo "$SCRIPT_DESCRIPTION"
        exit
        ;;
    --help | -h)
        cat_help_message
        exit
        ;;
    esac
fi

# Parse the passed arguments and intialiaze/mutate some variables
# Will display an error for invalid option(s)
while [[ $# -gt 0 ]]; do
    case $1 in
    --verbose | -vvv)
        shift # remove `--verbose` or `-vvv` from command
        verbose=true

        throw_an_error_if_missing_command_to_exec "$1"
        ;;
    --no-export-prefix)
        shift # remove `--no-export-prefix` from command
        export_prefix=""

        throw_an_error_if_missing_command_to_exec "$1"
        ;;
    --path)
        shift # remove `--path` from command
        test_path_option "$1"
        env_file="$1"
        shift # remove `<env_file_value>` from command

        throw_an_error_if_missing_command_to_exec "$1"
        ;;
    init)
        shift # remove `init` from command
        while [[ $# -gt 0 ]]; do
            case $1 in
            --from)
                shift # remove `--from` from command
                test_from_option "init" "$1"
                from_file="$1"
                shift # remove `<from_value>` from command
                ;;
            --force)
                shift # remove `--force` from command
                force="true"
                ;;
            --backup-file)
                shift # remove `--backup-file` from command
                test_backup_file_option "init" "$1"
                backup_file="$1"
                shift # remove `<backup_file_value>` from command
                ;;
            -*)
                echo_invalid_option_for_command "$1" "init"
                echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
                exit 1
                ;;
            *)
                echo_invalid_option_for_command "$1" "init"
                echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
                exit 1
                ;;
            esac
        done

        case_init "$env_file" "$force" "$from_file" "$backup_file"
        exit
        ;;
    get)
        shift # remove `get` from command

        if [[ $# -eq 0 ]]; then
            echo " ✘ You need to pass the KEY to the \`get\` command !"
            echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
            exit 1
        fi

        if [[ $# -gt 1 ]]; then
            echo " ✘ The \`get\` command accepts only one KEY !"
            echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
            exit 1
        fi

        case_get "$env_file" "$1" "$export_prefix"
        exit
        ;;
    set)
        shift # remove `set` from command

        if [[ $# -eq 0 ]]; then
            echo " ✘ You need to pass at least a var \`KEY=VALUE\` to the \`set\` command !"
            echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
            exit 1
        fi

        case_set "$env_file" "$export_prefix" "$*"
        exit
        ;;
    unset)
        shift # remove `unset` from command

        if [[ $# -eq 0 ]]; then
            echo " ✘ You need to pass at least one KEY to the \`unset\` command !"
            echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
            exit 1
        fi

        case_unset "$env_file" "$export_prefix" "$*"
        exit
        ;;
    list)
        shift # remove `list` from command

        if [[ $# -gt 0 ]]; then
            echo " ✘ The \`list\` command doesn't accept any extra option !"
            echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
            exit 1
        fi

        case_list "$env_file" "$export_prefix"
        exit
        ;;
    keys)
        shift # remove `keys` from command
        while [[ $# -gt 0 ]]; do
            case $1 in
            --delimiter)
                shift # remove `--delimiter` from command
                test_delimiter_option "keys" "$1"
                delimiter="$1"
                shift # remove `<delimiter_value>` from command
                ;;
            -*)
                echo_invalid_option_for_command "$1" "keys"
                echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
                exit 1
                ;;
            *)
                echo_invalid_option_for_command "$1" "keys"
                echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
                exit 1
                ;;
            esac
        done

        if [[ $# -gt 0 ]]; then
            echo " ✘ The \`keys\` command doesn't accept any extra option !"
            echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
            exit 1
        fi

        case_keys "$env_file" "$export_prefix" "$delimiter"
        exit
        ;;
    has)
        shift # remove `has` from command

        if [[ $# -eq 0 ]]; then
            echo " ✘ You need to pass at least one KEY to the \`has\` command !"
            echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
            exit 1
        fi

        case_has "$env_file" "$export_prefix" "$*"
        exit
        ;;
    truncate)
        shift # remove `truncate` from command
        while [[ $# -gt 0 ]]; do
            case $1 in
            --force)
                shift # remove `--force` from command
                force="true"
                ;;
            -*)
                echo_invalid_option_for_command "$1" "truncate"
                echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
                exit 1
                ;;
            *)
                echo_invalid_option_for_command "$1" "truncate"
                echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
                exit 1
                ;;
            esac
        done

        case_truncate "$env_file" "$force"
        exit
        ;;
    backup)
        shift # remove `backup` from command
        while [[ $# -gt 0 ]]; do
            case $1 in
            --backup-file)
                shift # remove `--backup-file` from command
                test_backup_file_option "backup" "$1"
                backup_file="$1"
                shift # remove `<backup_file_value>` from command
                ;;
            -*)
                echo_invalid_option_for_command "$1" "backup"
                echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
                exit 1
                ;;
            *)
                echo_invalid_option_for_command "$1" "backup"
                echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
                exit 1
                ;;
            esac
        done

        if [[ $# -gt 0 ]]; then
            echo " ✘ The \`backup\` command doesn't accept any extra option !"
            echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
            exit 1
        fi

        case_backup "$env_file" "$backup_file"
        exit
        ;;
    destroy)
        shift # remove `destroy` from command
        while [[ $# -gt 0 ]]; do
            case $1 in
            --force)
                shift # remove `--force` from command
                force="true"
                ;;
            -*)
                echo_invalid_option_for_command "$1" "destroy"
                echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
                exit 1
                ;;
            *)
                echo_invalid_option_for_command "$1" "destroy"
                echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
                exit 1
                ;;
            esac
        done

        case_destroy "$env_file" "$force"
        exit
        ;;
    -*)
        echo " ✘ Invalid option \`$1\` !"
        echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
        exit 1
        ;;
    *)
        echo " ✘ Invalid command \`$1\` !"
        echo "$TRY_HELP_COMMAND_FOR_MORE_INFORMATION"
        exit 1
        ;;
    esac
done

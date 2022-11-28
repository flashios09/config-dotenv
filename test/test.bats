#!/bin/bash

function setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    load 'test_helper/bats-file/load'

    TEST_FIXTURE_ROOT="$PWD/fixture"

    rm -f .env .env.prod .env-*.bak .env-with-custom-backup-file-name
}

# tests for `init` command
@test "\`dotenv init\`" {
    run dotenv init
    assert_success
    assert_file_exists "$PWD/.env"
    assert_output --partial " ✔ The \`$PWD/.env\` file has been successfully created !"
}

@test "\`--path\` option with \`dotenv init\`" {
    run dotenv --path "$PWD/.env.prod" init
    assert_success
    assert_file_exists "$PWD/.env.prod"
    assert_output --partial " ✔ The \`$PWD/.env.prod\` file has been successfully created !"
}

@test "\`dotenv init\` with \`--from\` cmd option" {
    run dotenv init --from "$PWD/.env.default"
    assert_success
    assert_file_exists "$PWD/.env.default"
    assert_output --partial " ✔ The \`$PWD/.env\` file has been successfully created from \`$PWD/.env.default\` !"
}

@test "\`dotenv init\` with already existent .env file" {
    touch .env
    run dotenv init
    assert_failure
    assert_file_exists "$PWD/.env"
    assert_output --partial " ✘ The \`$PWD/.env\` already exist, you can use the \`--force\` option !"
}

@test "\`dotenv init\` with \`--force\` cmd option(already existent .env file)" {
    touch .env
    run dotenv init --force
    assert_success
    assert_file_exists "$PWD/.env"
    assert_output --partial " ✔ The backup file "
    assert_output --partial " ✔ The \`$PWD/.env\` file has been successfully created !"
}

@test "\`dotenv init\` with \`--force\` and \`--backup-file\` cmd options(already existent .env file)" {
    touch .env
    backup_file="$PWD/.env-with-custom-backup-file-name"
    run dotenv init --force --backup-file "$backup_file"
    assert_success
    assert_file_exists "$PWD/.env"
    assert_file_exists "$backup_file"
    assert_output --partial "✔ The backup file \`$backup_file\` of \`$PWD/.env\` has been successfully created !"
    assert_output --partial " ✔ The \`$PWD/.env\` file has been successfully created !"
}

# tests for `set` command
@test "\`dotenv set KEY=VALUE\`" {
    dotenv init
    run dotenv set ENV=development
    assert_success
    assert_file_contains "$PWD/.env" "^export ENV=development"
    assert_output --partial " ✔ The \`ENV\` var has been added !"
}

@test "\`dotenv set KEY1=VALUE1 KEY2=VALUE=2 ...\`" {
    dotenv init
    run dotenv set ENV=development DEBUG=true
    assert_success
    assert_file_contains "$PWD/.env" "^export ENV=development"
    assert_file_contains "$PWD/.env" "^export DEBUG=true"
    assert_output --partial " ✔ The \`ENV\` var has been added !"
    assert_output --partial " ✔ The \`DEBUG\` var has been added !"
}

@test "\`dotenv set KEY1=\$(printenv MY_ENV_VAR) KEY2=VALUE2 ...\`" {
    dotenv init
    export DB_PASSWORD="my_password"
    run dotenv set APP_DB_PASSWORD=$(printenv DB_PASSWORD) APP_DB_HOST=localhost
    assert_success
    assert_file_contains "$PWD/.env" "^export APP_DB_PASSWORD=my_password"
    assert_file_contains "$PWD/.env" "^export APP_DB_HOST=localhost"
    assert_output --partial " ✔ The \`APP_DB_PASSWORD\` var has been added !"
    assert_output --partial " ✔ The \`APP_DB_HOST\` var has been added !"
}

@test "\`--no-export-prefix\` option with \`dotenv set KEY1=VALUE1 KEY2=VALUE2 ...\`" {
    dotenv init
    run dotenv --no-export-prefix set ENV=development DEBUG=true
    assert_success
    assert_file_contains "$PWD/.env" "^ENV=development"
    assert_file_contains "$PWD/.env" "^DEBUG=true"
    assert_output --partial " ✔ The \`ENV\` var has been added !"
    assert_output --partial " ✔ The \`DEBUG\` var has been added !"
}

@test "\`dotenv set EXISTENT_KEY=NEW_VALUE\` update existent key" {
    dotenv init --from "$PWD/.env.default"
    run dotenv set ENV=production DEBUG=false
    assert_success
    assert_file_contains "$PWD/.env" "^export ENV=production"
    assert_file_contains "$PWD/.env" "^export DEBUG=false"
    assert_output --partial " ✔ The \`ENV\` var has been updated !"
    assert_output --partial " ✔ The \`DEBUG\` var has been updated !"
}

@test "\`dotenv set EXISTENT_KEY=NEW_VALUE_WITH_SPECIAL_CHARS\` update value with special chars" {
    dotenv init --from "$PWD/.env.default"
    dotenv set CORS_ALLOW_ORIGINS=https://localhost:4200,https://api.my-app.test
    run dotenv set CORS_ALLOW_ORIGINS=https://api.my-app.com
    assert_success
    assert_file_contains "$PWD/.env" "^export CORS_ALLOW_ORIGINS=https://api.my-app.com"
    assert_output --partial " ✔ The \`CORS_ALLOW_ORIGINS\` var has been updated !"
}

# tests for `has` command
@test "\`dotenv has KEY1 KEY2 ...\`" {
    dotenv init --from "$PWD/.env.default"
    run dotenv has ENV DEBUG
    assert_success
}

@test "\`dotenv has NON_EXISTENT_KEY ...\`" {
    dotenv init --from "$PWD/.env.default"
    run dotenv has NON_EXISTENT_KEY
    assert_failure
}

@test "\`--no-export-prefix\` option with \`dotenv has KEY1 KEY2\`" {
    dotenv init
    dotenv --no-export-prefix set ENV=development DEBUG=true
    run dotenv --no-export-prefix has ENV DEBUG
    assert_success
    run dotenv has ENV DEBUG
    assert_failure
}

@test "\`--verbose\` option with \`dotenv has KEY1 KEY2 ...\`" {
    dotenv init --from "$PWD/.env.default"
    run dotenv --verbose has ENV DEBUG
    assert_success
    assert_output --partial " ✔ The \`$PWD/.env\` file has the \`ENV, DEBUG\` keys !"
}

@test "\`--verbose\` option with \`dotenv has NON_EXISTENT_KEY\`" {
    dotenv init --from "$PWD/.env.default"
    run dotenv --verbose has NON_EXISTENT_KEY
    assert_failure
    assert_output --partial " ✘ Undefined KEY \`NON_EXISTENT_KEY\` for \`has\` command !"
}

# tests for `unset` command
@test "\`dotenv unset KEY1 KEY2 ...\`" {
    dotenv init --from "$PWD/.env.default"
    run dotenv unset ENV DEBUG
    assert_success
    assert_output --partial " ✔ The \`ENV, DEBUG\` vars has been removed from your \`$PWD/.env\` file !"
}

@test "\`dotenv unset NON_EXISTENT_KEY\`" {
    dotenv init --from "$PWD/.env.default"
    run dotenv unset NON_EXISTENT_KEY
    assert_failure
    assert_output --partial " ✘ Undefined KEY \`NON_EXISTENT_KEY\` for \`unset\` command !"
}

@test "\`--no-export-prefix\` option with \`dotenv unset KEY1 KEY2\`" {
    dotenv init
    dotenv --no-export-prefix set ENV=development DEBUG=true
    run dotenv unset ENV DEBUG
    assert_failure
    assert_output --partial " ✘ Undefined KEY \`ENV\` for \`unset\` command !"
    run dotenv --no-export-prefix unset ENV DEBUG
    assert_success
    assert_output --partial " ✔ The \`ENV, DEBUG\` vars has been removed from your \`$PWD/.env\` file !"
}

# tests for `get` command
@test "\`dotenv get KEY\`" {
    dotenv init --from "$PWD/.env.default"
    run dotenv get DB_USER
    assert_success
    assert_output --partial "root"
}

@test "\`--no-export-prefix\` option with \`dotenv get KEY\`" {
    dotenv init
    echo "DB_USER=root" >.env
    run dotenv get DB_USER
    assert_failure
    assert_output --partial " ✘ Undefined KEY \`DB_USER\` for \`get\` command !"
    run dotenv --no-export-prefix get DB_USER
    assert_success
    assert_output --partial "root"
}

@test "\`dotenv get NON_EXISTENT_KEY\`" {
    dotenv init --from "$PWD/.env.default"
    run dotenv get NON_EXISTENT_KEY
    assert_failure
    assert_output --partial " ✘ Undefined KEY \`NON_EXISTENT_KEY\` for \`get\` command !"
}

# tests for `list` command
@test "\`dotenv list\`" {
    dotenv init
    dotenv set ENV=development DEBUG=true API_VERSION=v1
    run dotenv list
    assert_success
    expected_output=$(echo -e " ✔ The \`$PWD/.env\` file vars list:")
    expected_output+=$(echo -e "\nENV:         development")
    expected_output+=$(echo -e "\nDEBUG:       true")
    expected_output+=$(echo -e "\nAPI_VERSION: v1")
    assert_output "$expected_output"
}

@test "\`--no-export-prefix\` option with \`dotenv list\`" {
    dotenv init
    dotenv set ENV=development DEBUG=true API_VERSION=v1
    dotenv --no-export-prefix set SSH_PORT=22 MYSQL_PORT=3306
    run dotenv --no-export-prefix list
    assert_success
    expected_output=$(echo -e " ✔ The \`$PWD/.env\` file vars list:")
    expected_output+=$(echo -e "\nSSH_PORT:   22")
    expected_output+=$(echo -e "\nMYSQL_PORT: 3306")
    assert_output "$expected_output"
}

@test "\`dotenv list\`(no vars found)" {
    dotenv init
    run dotenv list
    assert_success
    assert_output --partial " ✘ No vars found for \`$PWD/.env\` !"
}

# tests for `keys` command
@test "\`dotenv keys\`" {
    dotenv init
    dotenv set ENV=development DEBUG=true API_VERSION=v1
    run dotenv keys
    assert_success
    assert_output "ENV DEBUG API_VERSION"
}

@test "\`dotenv keys\`(no vars found)" {
    dotenv init
    run dotenv keys
    assert_failure
    assert_output --partial " ✘ No vars found for \`$PWD/.env\` !"
}

@test "\`dotenv keys\` with \`--delimiter ','\` cmd option" {
    dotenv init
    dotenv set ENV=development DEBUG=true API_VERSION=v1
    run dotenv keys --delimiter ','
    assert_success
    assert_output "ENV,DEBUG,API_VERSION"
}

@test "\`dotenv keys\` with \`--delimiter '\n'\` cmd option" {
    dotenv init
    dotenv set ENV=development DEBUG=true API_VERSION=v1
    run dotenv keys --delimiter '\n'
    assert_success
    expected_output=$(echo -e "ENV")
    expected_output+=$(echo -e "\nDEBUG")
    expected_output+=$(echo -e "\nAPI_VERSION")
    assert_output "$expected_output"
}

@test "\`--no-export-prefix\` option with \`dotenv keys\`" {
    dotenv init
    dotenv set ENV=development DEBUG=true API_VERSION=v1
    dotenv --no-export-prefix set SSH_PORT=22 MYSQL_PORT=3306
    run dotenv --no-export-prefix keys
    assert_success
    assert_output "SSH_PORT MYSQL_PORT"
}

# tests for `truncate` command
@test "\`dotenv truncate\` with \`--force\` cmd option" {
    dotenv init
    dotenv set ENV=development DEBUG=true
    run dotenv truncate --force
    assert_success
    assert_size_zero "$PWD/.env"
    assert_output --partial " ✔ The \`$PWD/.env\` file has been successfully truncated !"
}

# tests for `backup` command
@test "\`dotenv backup\`" {
    dotenv init
    dotenv set ENV=development DEBUG=true
    run dotenv backup
    assert_success
    assert_file_exists "$PWD/.env"
    assert_output --partial " ✔ The backup file "
    ls -a >"$TEST_FIXTURE_ROOT/ls_output"
    run grep .env-[0-9]*.bak "$TEST_FIXTURE_ROOT/ls_output"
    assert_success
    assert_output --partial ".bak"
}

@test "\`dotenv backup\` with \`--backup-file\` cmd option" {
    dotenv init
    dotenv set ENV=development DEBUG=true
    run dotenv backup --backup-file "$PWD/.env-with-custom-backup-file-name"
    assert_success
    assert_file_exists "$PWD/.env"
    assert_file_exists "$PWD/.env-with-custom-backup-file-name"
    assert_output --partial " ✔ The backup file \`$PWD/.env-with-custom-backup-file-name\` of \`$PWD/.env\` has been successfully created !"
}

# tests for `destroy` command
@test "\`dotenv destroy\` with \`--force\` cmd option" {
    dotenv init
    run dotenv destroy --force
    assert_success
    assert_file_not_exists "$PWD/.env"
    assert_output --partial " ✔ The \`$PWD/.env\` file has been successfully removed !"
}

@test "\`--path\` option \`dotenv destroy --force\`" {
    dotenv --path "$PWD/.env.prod" init
    run dotenv --path "$PWD/.env.prod" destroy --force
    assert_success
    assert_file_not_exists "$PWD/.env.prod"
    assert_output --partial " ✔ The \`$PWD/.env.prod\` file has been successfully removed !"
}

function teardown() {
    rm -f .env .env.prod .env-*.bak .env-with-custom-backup-file-name
}

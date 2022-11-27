#!/bin/bash

function setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    load 'test_helper/bats-file/load'

    rm -f .env .env.prod .env-*.bak
}

@test "\`dotenv init\`" {
    run dotenv init
    assert_success
    assert_output --partial " ✔ The \`$PWD/.env\` file has been successfully created"
}

@test "\`--path\` option with \`dotenv init\`" {
    run dotenv --path "$PWD/.env.prod" init
    assert_success
    assert_output --partial " ✔ The \`$PWD/.env.prod\` file has been successfully created !"
}

@test "\`dotenv init\` with \`--from\` cmd option" {
    run dotenv init --from "$PWD/.env.default"
    assert_success
    assert_output --partial " ✔ The \`$PWD/.env\` file has been successfully created from \`$PWD/.env.default\` !"
}

@test "\`dotenv init\` with already existent .env file" {
    touch .env
    run dotenv init
    assert_failure
    assert_output --partial " ✘ The \`$PWD/.env\` already exist, you can use the \`--force\` option !"
}

@test "\`dotenv init\` with \`--force\` cmd option(already existent .env file)" {
    touch .env
    run dotenv init --force
    assert_failure
    assert_output --partial " ✘ The \`$PWD/.env\` alread exist, you can use the \`--force\` option !"
}


function teardown() {
    rm -f .env .env.prod .env-*.bak
}

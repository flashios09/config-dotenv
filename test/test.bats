#!/bin/bash

function setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    load 'test_helper/bats-file/load'

    rm -f .env
}

@test "test \`dotenv init\` command" {
    dotenv init
}

@test "test \`dotenv init\` command with already existent .env file" {
    touch .env
    run dotenv init
    assert_failure
    assert_output --partial "already exist, you can use the \`--force\` option !"
}

function teardown() {
    rm -f .env
}

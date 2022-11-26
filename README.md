# Config dotenv

<p align="center">
    <a href="https://github.com/flashios09/config-dotenv/actions/workflows/ci.yml" target="_blank">
        <img src="https://github.com/flashios09/config-dotenv/actions/workflows/ci.yml/badge.svg" alt="CI Status">
    </a>
    <a href="https://github.com/flashios09/config-dotenv/releases/latest" target="_blank">
        <img alt="GitHub release (latest by date)" src="https://img.shields.io/github/v/release/flashios09/config-dotenv">
    </a>
</p>

Config the `.env` file(inspired from [dokku config plugin](https://github.com/dokku/dokku/blob/a308ff65464dce6ce1bb709e3afddd7066e77381/plugins/config/commands))

## Installation
```bash
# Clone the repo
git clone git@github.com:flashios09/config-dotenv.git
# CD to `config-dotenv` folder
cd config-dotenv
# Make `script.sh` executable
chmod +x ./script.sh
# Create a symlink inside a bin dir, e.g. `/usr/local/bin`(must be in your path)
ln -s "$PWD/script.sh" /usr/local/bin/dotenv
# Check dotenv is installed, must output `/usr/local/bin/dotenv` !
which dotenv
```

## Usage
```bash
dotenv [OPTIONS] COMMAND [CMD_OPTIONS]     execute the script with the specified command and/or options
dotenv -h|--help                           display this output
dotenv -v|--version                        display the script version
```
## Options:
```bash
--path <string>                   `"$PWD/.env"` by default, the path of the `.env` file
                                  e.g. `dotenv --path "$PWD/prod.env" init`
--no-export-prefix                the "export " prefix will be added by default, use `--no-export-prefix` to disable it
                                  e.g. `dotenv --no-export-prefix set DEBUG=true`, will write `DEBUG=true`
                                  e.g. `dotenv set DEBUG=true`, will write `export DEBUG=true`
-vvv|--verbose                    the verbose mode, disabled by default, use `-vvv` or `--verbose` to enable it
```
## Commands:
```bash
init [CMD_OPTIONS]                create an empty `.env` file, only if `.env` not already exists
     --from <string>              use a source file to init the `.env` file, only if `.env` not already exists
                                  e.g. `dotenv init --from "$PWD/.env.default"`
     --force                      force the init if an `.env` already exist, a backup for the existent file will be created
                                  e.g. `dotenv init --force`

get KEY                           get the value of the passed KEY
                                  e.g. `dotenv get DEBUG`, will return the value of the DEBUG env var
                                  you can use the `--no-export-prefix` to get the value without "export "
                                  e.g. `dotenv --no-export-prefix get DEBUG`

set KEY1=VALUE1 [KEY2=VALUE2 ...] set the value of the passed key(s)
                                  e.g. `dotenv set DEBUG=true`
                                  e.g. `dotenv set APP_ROOT="$PWD" DEBUG=true API_VERSION="v1"`
                                  e.g. `dotenv set DB_PASSWORD="$(printenv APP_DB_PASSWORD)" APP_ROOT="$PWD" API_VERSION="v1"`

unset KEY1 [KEY2 ...]             unset the the passed key(s)
                                  e.g. `dotenv unset DEBUG API_VERSION`

list                              list the env vars
                                  e.g. `dotenv list`
                                  you can use the `--no-export-prefix` to list only the vars without "export "
                                  e.g. `dotenv --no-export-prefix list`

has KEY1 [KEY2 ...]               check if key(s) exist(s) and return 0 or 1
                                  e.g. `dotenv has DEBUG API_VERSION`
                                  you can use the verbose flag to get a success or error message
                                  e.g. `dotenv --verbose has DEBUG API_VERSION`
                                  you can use the `--no-export-prefix` to check only the key(s) without "export "
                                  e.g. `dotenv --no-export-prefix has DEBUG API_VERSION`

truncate [CMD_OPTIONS]            truncate the `.env` file
         --force                  force the truncate, avoid the prompt message

backup                            create a backup file for the `.env` using this format `<env_file_name>-<now>.bak`
                                  e.g. `dotenv backup`, will create a copy from `.env` named `.env-20221125192400.bak`

destroy [CMD_OPTIONS]             remove the `.env` file
        --force                   force the destroy, avoid the prompt message
```
Check the [test.bats](test/test.bats) for more examples and tests.

## Contributing
Just clone or fork the repository :)

We are using [shellcheck](https://github.com/koalaman/shellcheck) as script analysis tool and [shfmt](https://github.com/patrickvane/shfmt) for script formatting.

### Linting:
```bash
# used on `ci.yml` github action
shellcheck ./script.sh
shfmt -i 4 -d ./script.sh
```
### Testing:
We are using [bats](https://bats-core.readthedocs.io/en/stable/) to write tests, check [test.bats](test/test.bats) for more examples and tests.
```bash
# used on `ci.yml` github action
# install `bats` bin and `bats-support`, `bats-assert`, `bats-file` submodules
git submodule update
# make `test` folder your working directory for all your tests
cd ./test
# run the tests
./bats/bin/bats test.bats
```

## License
 This project is licensed under the [MIT License](LICENSE.md).
## `dap` strategy testing environment for neotest-phpunit

### Usage
In this directory run
```sh
    make start
```
then press `,nd` to run test with `dap` strategy on provided PHPUnit test.

If it works, from some PHP project directory try
```sh
    make -C /path/to/this/directory run
```
or directly
```sh
    nvim -C /path/to/this/directory/init.lua ./path/to/your/UnitTest.php
```

### Keymaps
Look what's already defined in `init.lua`.

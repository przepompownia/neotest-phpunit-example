local thisInitFile = debug.getinfo(1).source:match('@?(.*)')
local configDir = vim.fs.dirname(vim.fs.dirname(thisInitFile))

vim.env['XDG_CONFIG_HOME'] = configDir
vim.env['XDG_DATA_HOME'] = vim.fs.joinpath(configDir, '.xdg', 'data')
vim.env['XDG_STATE_HOME'] = vim.fs.joinpath(configDir, '.xdg', 'state')
vim.env['XDG_CACHE_HOME'] = vim.fs.joinpath(configDir, '.xdg', 'cache')
local stdPathConfig = vim.fn.stdpath('config')

vim.opt.runtimepath:prepend(stdPathConfig)
vim.opt.packpath:prepend(stdPathConfig)

local pluginsPath = vim.fs.joinpath(configDir, 'nvim/pack/plugins/opt')
vim.fn.mkdir(pluginsPath, 'p')
pluginsPath = vim.uv.fs_realpath(pluginsPath)

local function gitClone(url, installPath, branch)
  if vim.fn.isdirectory(installPath) ~= 0 then
    return
  end

  local command = {'git', 'clone', '--', url, installPath}
  if branch then
    table.insert(command, 3, '--branch')
    table.insert(command, 4, branch)
  end

  vim.notify(('Cloning %s dependency into %s...'):format(url, installPath), vim.log.levels.INFO, {})
  local sysObj = vim.system(command, {}):wait()
  if sysObj.code ~= 0 then
    error(sysObj.stderr)
  end
  vim.notify(sysObj.stdout)
  vim.notify(sysObj.stderr, vim.log.levels.WARN)
end

local plugins = {
  ['plenary.nvim'] = {url = 'https://github.com/nvim-lua/plenary.nvim'},
  ['nvim-nio'] = {url = 'https://github.com/nvim-neotest/nvim-nio'},
  ['neotest'] = {url = 'https://github.com/nvim-neotest/neotest'},
  ['nvim-dap'] = {url = 'https://github.com/mfussenegger/nvim-dap'},
  ['nvim-treesitter'] = {url = 'https://github.com/nvim-treesitter/nvim-treesitter'},
  ['neotest-phpunit'] = {url = 'https://github.com/przepompownia/neotest-phpunit'},
}

for name, repo in pairs(plugins) do
  local installPath = vim.fs.joinpath(pluginsPath, name)
  gitClone(repo.url, installPath, repo.branch)
  -- vim.opt.runtimepath:append(installPath)
  vim.cmd.packadd({args = {name}, bang = true})
end

local function init()
  vim.cmd.colorscheme 'habamax'
  vim.go.termguicolors = true
  vim.treesitter.language.register('php_only', {'php'})
  vim.wo.foldmethod = 'expr'
  vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
  vim.wo.foldtext = ''
  vim.wo.foldlevel = 99
  vim.wo.number = true
  vim.wo.numberwidth = 1
  vim.opt.signcolumn = 'auto:1-9'
  local dap = require 'dap'
  dap.defaults.fallback.switchbuf = 'useopen'
  dap.set_log_level('TRACE')
  dap.adapters.php = {
    type = 'executable',
    command = vim.fs.joinpath(configDir, 'bin/dap-adapter-utils'),
    args = {'run', 'vscode-php-debug', 'phpDebug'}
  }

  dap.configurations.php = {
    {
      log = true,
      type = 'php',
      request = 'launch',
      name = 'Listen for XDebug',
      port = 9003,
      stopOnEntry = false,
      xdebugSettings = {
        max_children = 512,
        max_data = 1024,
        max_depth = 4,
      },
      breakpoints = {
        exception = {
          Notice = false,
          Warning = false,
          Error = false,
          Exception = false,
          ['*'] = false,
        },
      },
    }
  }

  require('nvim-treesitter.configs').setup {
    ensure_installed = {'php_only'},
    highlight = {
      enable = true,
    },
  }
  local phpXdebugCmd = {
    'php',
    '-dzend_extension=xdebug.so',
    'vendor/bin/phpunit',
  }
  local phpXdebugEnv = {XDEBUG_CONFIG = 'idekey=neotest'}
  local neotest = require('neotest')
  neotest.setup({
    -- log_level = vim.log.levels.DEBUG,
    adapters = {
      require('neotest-phpunit') {
        env = phpXdebugEnv,
        dap = dap.configurations.php[1],
        phpunit_cmd = function ()
          return 'vendor/bin/phpunit'
        end,
      },
    }
  })
  vim.api.nvim_create_user_command('PhpUnitWithXdebug', function (opts)
    local onExit = vim.schedule_wrap(function (obj)
      vim.notify(obj.stdout)
      vim.notify(obj.stderr, vim.log.levels.WARN)
    end)

    local phpunit = vim.tbl_values(phpXdebugCmd)
    table.insert(phpunit, opts.fargs[1] or vim.api.nvim_buf_get_name(0))
    vim.system(phpunit, {env = phpXdebugEnv}, onExit)
  end, {nargs = '?', complete = 'file'})

  vim.keymap.set('n', '<Esc>', vim.cmd.fclose)
  vim.keymap.set(
    {'n'},
    'dQ',
    function ()
      dap.close()
      dap.clear_breakpoints()
    end
  )
  vim.keymap.set({'n'}, ',dr', dap.continue)
  vim.keymap.set({'n'}, ',ds', dap.step_over)
  vim.keymap.set({'n'}, ',dc', dap.close)
  vim.keymap.set({'n'}, ',dt', dap.toggle_breakpoint)
  vim.keymap.set({'n'}, ',ns', neotest.summary.toggle)
  vim.keymap.set({'n'}, ',no', neotest.output_panel.toggle)
  vim.keymap.set({'n'}, ',nr', neotest.run.run)
  vim.keymap.set({'n'}, ',nd', function ()
    neotest.run.run({
      strategy = 'dap',
      -- env = phpXdebugEnv,
    })
  end)

  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'php',
    callback = function ()
      function ShowListeningIndicator()
        local indicator = '%#DiagnosticError#⛧ %#StatusLine# [Listening...]'
        return dap.session() and indicator or '%#DiagnosticInfo#☠ %#StatusLine# [No debug session]'
      end
      vim.opt_local.statusline = '%{%v:lua.ShowListeningIndicator()%} %f'
    end
  })
end

vim.api.nvim_create_autocmd('UIEnter', {
  callback = init,
})

# calltree.nvim

A Neovim plugin that displays Go function call trees using `gopls` LSP server.

## Features

- 🔍 Show function call hierarchy (callers and callees)
- 🌳 Tree-like display with interactive navigation
- 🎯 Jump to function definitions with Enter or double-click
- ⚡ Powered by gopls LSP for accurate analysis
- 🚀 Async support for large projects

## Requirements

- Neovim >= 0.8
- `gopls` LSP server running  
- Go project
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (dependency)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    'your-username/calltree.nvim',
    dependencies = {
        'nvim-lua/plenary.nvim',
    },
    ft = 'go',
    config = function()
        require('calltree').setup()
    end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    'your-username/calltree.nvim',
    requires = {
        'nvim-lua/plenary.nvim',
    },
    ft = 'go',
    config = function()
        require('calltree').setup()
    end
}
```

## Usage

### Commands

- `:CallTree [direction]` - Show call tree (directions: `in`, `out`, `both`)
- `:CallTreeIncoming` - Show only callers
- `:CallTreeOutgoing` - Show only callees  
- `:CallTreeSetup` - Show configuration example

### Keymaps in Call Tree Window

- `<CR>` or `<2-LeftMouse>` - Jump to function definition
- `q` or `<Esc>` - Close window
- `?` - Show help

## Configuration

```lua
require('calltree').setup({
    max_depth = 3,        -- Maximum call depth
    direction = "both",   -- Default direction: "incoming", "outgoing", "both"
    async = true,         -- Use async requests
    window = {
        width = 60,       -- Window width
        height = 20,      -- Window height  
        border = "rounded" -- Window border style
    }
})
```

## Example Keybindings

```lua
vim.keymap.set('n', '<leader>ct', ':CallTree<CR>', { desc = 'Show call tree' })
vim.keymap.set('n', '<leader>ci', ':CallTreeIncoming<CR>', { desc = 'Show callers' })
vim.keymap.set('n', '<leader>co', ':CallTreeOutgoing<CR>', { desc = 'Show callees' })
```

## Symbols

- 🎯 Root function (current function)
- 📞 Caller (functions that call this one)
- 📤 Callee (functions called by this one)

## Troubleshooting

1. **"gopls not available"** - Ensure gopls LSP is running: `:LspInfo`
2. **"No call hierarchy found"** - Position cursor on a function name
3. Empty results - Function might not have callers/callees in the current scope

## Development

To test the plugin:

1. Clone this repository
2. Add to your Neovim runtime path
3. Open a Go file in a project with gopls running
4. Position cursor on a function name
5. Run `:CallTree`
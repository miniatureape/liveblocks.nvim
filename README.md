# liveblocks.nvim

*This is probably not ready for wide consumption*

A Neovim plugin that allows you to embed live content from other files or command outputs directly into your text files. Perfect for keeping documentation up-to-date with code samples or command outputs.

## Features

- **File Embedding**: Include content from other files that stays synchronized
- **Command Execution**: Execute shell commands and embed their output
- **Auto-refresh**: Content updates automatically when you focus the Neovim window
- **Auto-save**: All liveblocks are automatically saved when you write the buffer
- **Write-back**: Update source files directly from embedded content
- **Aliases**: Configure shortcuts for frequently used files
- **Directory Control**: Enable only in specific directories
- **Configurable Blocks Directory**: Store blocks in a dedicated directory
- **Folding**: Liveblock fences act as fold markers, letting you collapse blocks to focus on your document

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'miniatureape/liveblocks.nvim',
  config = function()
    require('liveblocks').setup({
      root_dirs = {
        "~/projects",
        "~/documents",
      },
      blocks_dir = "liveblocks",  -- Directory for storing blocks (default: "liveblocks")
    })
  end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  '',
  config = function()
    require('liveblocks').setup({
      root_dirs = {},
      blocks_dir = "liveblocks",
    })
  end
}
```

## Usage

### Embedding File Content

Add a liveblock fence to your markdown or text file:

```markdown
[//]: #lb "path/to/file.txt"
[//]: #/lb
```

The content between the fences will be replaced with the contents of `path/to/file.txt` when you focus the Neovim window.

### Embedding Command Output

Prefix a shell command with `!` to execute it and embed the output:

```markdown
[//]: #lb !ls -la ~/
[//]: #/lb
```

The content will be replaced with the output of the command.

### Path Resolution

- Relative paths are resolved within the configured `blocks_dir` (default: `liveblocks/` directory)
- Absolute paths are supported and bypass the `blocks_dir`
- Use quotes for paths with spaces: `[//]: #lb "path with spaces/file.txt"`
- Example: With `blocks_dir = "liveblocks"` and working directory `~/wiki`, a block `[//]: #lb myfile` will be stored at `~/wiki/liveblocks/myfile`

### Write-back Feature

When you write a buffer with liveblocks in it, all the live blocks are written back.

Position your cursor inside a liveblock and press `<leader>lbw` (or run `:LiveblocksWriteBack`) to write the current content back to the source file. This does not work for command blocks.

All liveblocks in markdown files are automatically saved when you write the buffer (`:w`). You'll see a notification showing how many blocks were written.

## Configuration

```lua
require('liveblocks').setup({
  -- Map shortcuts to file paths
  aliases = {
    weekly = "Weekly Goals.md",
    todo = "~/documents/todo.txt",
  },

  -- Only run liveblocks in these directories (empty = all directories)
  root_dirs = {
    "~/projects",
    "~/documents",
  },

  -- Directory for storing liveblock files (relative paths are resolved here)
  -- Default: "liveblocks"
  blocks_dir = "liveblocks",

  -- Enable folding of liveblock fences (default: true)
  folding = true,
})
```

## Commands

- `:LiveblocksRefresh` - Manually refresh all liveblocks in the current buffer
- `:LiveblocksWriteBack` - Write the current block content back to its source file
- `:LiveblocksCreate` - Generate the liveblock fences to start a new liveblock
- `:LiveblocksGoto` - Open the source file of the liveblock under the cursor
- `:LiveblocksTelescope` - Open a Telescope picker to browse all liveblocks across your project

## Key Mappings

- `<leader>lbw` - Write back to source file (when cursor is inside a liveblock)
- `<leader>lg` - Go to liveblock source (example mapping below)

```lua
vim.keymap.set('n', '<leader>lg', require('liveblocks').goto, { desc = 'Go to liveblock source' })
```

## Telescope Integration

If you have [Telescope](https://github.com/nvim-telescope/telescope.nvim) installed, you can browse all liveblocks across your configured `root_dirs` with fuzzy search and preview.

```
:Telescope liveblocks
```

Or use the convenience command:

```
:LiveblocksTelescope
```

The picker lets you fuzzy-search by block name or file path. The preview pane shows the markdown file at the block's location, and pressing enter jumps to the selected liveblock.

Telescope is optional — the plugin works fine without it.

## Folding

Liveblock fences double as Neovim fold markers, so you can collapse blocks to see just your document structure. Folding is enabled by default. To disable it:

```lua
require('liveblocks').setup({
  folding = false,
})
```

Common fold commands:

| Command | Description |
|---------|-------------|
| `za` | Toggle fold under cursor |
| `zo` | Open fold under cursor |
| `zc` | Close fold under cursor |
| `zR` | Open all folds |
| `zM` | Close all folds |
| `zj` | Jump to next fold |
| `zk` | Jump to previous fold |

## How It Works

The plugin uses markdown comment syntax for the fences, so when rendered, you'll only see the embedded content, not the fence markers.

- Content automatically refreshes when you focus the Neovim window (markdown files only)
- All liveblocks are automatically saved to their source files when you write the buffer (markdown files only)
- The plugin only operates on `*.md` files by default

## Examples

### Example 1: Code Sample in Documentation

```markdown
Here's the current implementation:

[//]: #lb "src/utils/helper.js"
[//]: #/lb
```

### Example 2: Directory Listing

```markdown
Current project structure:

[//]: #lb !tree -L 2
[//]: #/lb
```

## License

MIT


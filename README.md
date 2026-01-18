# liveblocks.nvim

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

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'yourusername/liveblocks.nvim',
  config = function()
    require('liveblocks').setup({
      aliases = {
        weekly = "Weekly Goals.md",
      },
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
  'yourusername/liveblocks.nvim',
  config = function()
    require('liveblocks').setup({
      aliases = {},
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
[//]: #liveblock "path/to/file.txt"
[//]: #/liveblock
```

The content between the fences will be replaced with the contents of `path/to/file.txt` when you focus the Neovim window.

### Using Aliases

Configure an alias in your setup:

```lua
require('liveblocks').setup({
  aliases = {
    weekly = "Weekly Goals.md",
  },
})
```

Then use it in your files:

```markdown
[//]: #liveblock weekly
[//]: #/liveblock
```

### Embedding Command Output

Use the special `cmd` keyword to execute commands:

```markdown
[//]: #liveblock cmd ls -la /srv
[//]: #/liveblock
```

The content will be replaced with the output of the command.

### Path Resolution

- Relative paths are resolved within the configured `blocks_dir` (default: `liveblocks/` directory)
- Absolute paths are supported and bypass the `blocks_dir`
- Use quotes for paths with spaces: `[//]: #liveblock "path with spaces/file.txt"`
- Example: With `blocks_dir = "liveblocks"` and working directory `~/wiki`, a block `[//]: #liveblock myfile.txt` will be stored at `~/wiki/liveblocks/myfile.txt`

### Write-back Feature

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
})
```

## Commands

- `:LiveblocksRefresh` - Manually refresh all liveblocks in the current buffer
- `:LiveblocksWriteBack` - Write the current block content back to its source file

## Key Mappings

- `<leader>lbw` - Write back to source file (when cursor is inside a liveblock)

## How It Works

The plugin uses markdown comment syntax for the fences, so when rendered, you'll only see the embedded content, not the fence markers.

- Content automatically refreshes when you focus the Neovim window (markdown files only)
- All liveblocks are automatically saved to their source files when you write the buffer (markdown files only)
- The plugin only operates on `*.md` files by default

## Examples

### Example 1: Code Sample in Documentation

```markdown
Here's the current implementation:

[//]: #liveblock "src/utils/helper.js"
[//]: #/liveblock
```

### Example 2: Directory Listing

```markdown
Current project structure:

[//]: #liveblock cmd tree -L 2
[//]: #/liveblock
```

### Example 3: Using Aliases

```markdown
My goals for this week:

[//]: #liveblock weekly
[//]: #/liveblock
```

## License

MIT

## TODO
- If replacement does not match current content, you should not replace and add virtual text saying the content was edited
- Rename all the project_dir methods as root_dir

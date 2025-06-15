# VimNC

A simple and intuitive file manager plugin for Vim that allows you to navigate and manage your files directly within Vim.

## Features

- Navigate the filesystem with Vim-style keys
- Open files quickly
- Select, cut, copy, paste, and delete files/folders
- Create folders and rename files/folders
- Toggle an in-editor help screen for quick reference

## Keybindings

 | Key        | Action                          |
 | ---------- | -------------------------       |
 | `h`        | Go to parent folder             |
 | `l`        | Go into folder                  |
 | `j`        | Move down the list              |
 | `k`        | Move up the list                |
 | `Enter`    | Open file/folder                |
 | `Space`    | Select / unselect files/folders |
 | `x`        | Cut selected items              |
 | `y`        | Copy selected items             |
 | `p`        | Paste items                     |
 | `d`        | Delete selected items           |
 | `a`        | Create a new folder             |
 | `c`        | Rename a file or folder         |
 | `r`        | Refresh directory               |
 | `?`        | Toggle this help screen         |

## Installation

You can install this plugin using your favorite plugin manager:

### Using [vim-plug](https://github.com/junegunn/vim-plug):

    Plug 'yourusername/vim-file-manager'

Then run:

    :PlugInstall

### Using [Vundle](https://github.com/VundleVim/Vundle.vim):

    Plugin 'yourusername/vim-file-manager'

Then run:

    :PluginInstall

## Usage

Open the VimNC file manager with the command:

    :VimNC

Navigate and manage your files using the keys listed above. Press `?` anytime to toggle the help screen.

To make opening VimNC even quicker, you can map the command to a convenient key combination. For example, to map it to `<leader>f`, add the following to your `.vimrc` or `init.vim`:

```vim
" Map <leader>f to open VimNC file manager
nnoremap <leader>f :VimNC<CR>
```

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

MIT License © Mahadevan K

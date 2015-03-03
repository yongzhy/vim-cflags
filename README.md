# vim-cflags

## Introduction

## Installation
Use [Vundle.vim](https://github.com/gmarik/Vundle.vim) to install this plugin
```
Plugin 'yongzhy/vim-cflags'
```

## Setting

Only one global veriable is required, **g:c_define_file** points to the file has all global defines.
```
 let g:c_define_file="f:/flags.h"
 ```
 
Example of the define file:
 ```
 #define _HELLO_ 1
 #define _WORLD_ 0
 ```
 
## Key Setting

**cflags#SynUpdate()** will update current buffer to gray out those inactive code blocks
**cflags#PrintDefine()** will display the flag value under cursor
```
nnoremap <leader>bu :call cflags#SynUpdate()<cr>
nnoremap <leader>fv :call cflags#PrintDefine()<cr>
```
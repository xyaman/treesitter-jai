#load "bindings.jai";

#if OS == .LINUX && CPU == .X64 libtreesitter :: #library,no_dll "linux/x64/libtree-sitter";
#if OS == .WINDOWS && CPU == .X64 libtreesitter :: #library,no_dll "windows/x64/tree-sitter_static";

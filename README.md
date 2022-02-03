# Introduction 
This repository contains powershell scripts used to customize my powershell environment.

Features:
- dirs, pushd, popd: rewrite of Powershell provided cmdlets to better align with the twin linux based tools. This version contains the dirs cmd that shows what directories currently exist on the directory stack.
- ls, ll: these cmdlets provides a bare (ls) and detailed (ll) version of directory listing with colors.
- od: this cmdlet provides a formatted octal dump of the cmdlet target file
- touch: this cmdlet updates the modified date to system date for existing files and creates a zero byte file for new files. Traditionally used to support file system based operations based on process file state.
- prompt: customized prompt to display user, directory, elevation state, and git directory name and state if found.
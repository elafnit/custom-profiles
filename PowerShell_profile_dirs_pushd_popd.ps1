$Global:myDirStack = @()

function Shift-Array {
    Param(
        [int] $i,
        $array
    )
    $i = $i % $array.Count
    $mi = $array.Count - 1

    if ($i -lt 0) { $i = $array.Count + $i }

    if ($i -gt 0) { ($array[$i..$mi] + $array[0..($i - 1)]) }
    else { $array }
}

function Remove-ArrayItem {
    Param(
        [int] $i,
        $array
    )
    $mi = $array.Count - 1

    $le = $i - 1
    if ($le -ge 0) { $left = $a[0..$le] }
    else { $left = @() }

    $re = $i + 1
    if ($re -le $mi) { $right = $a[$re..$mi] }
    else { $right = @() }

    $left + $right
}

<#
.Synopsis
Display directory stack.

.Description
Display the list of currently remembered directories. Directories find their way onto the list with the `pushd' command; you can get back up through the list with the `popd' command.

.Parameter c
clear the directory stack by deleting all of the elements

.Parameter l
do not print tilde-prefixed versions of directories relative to your home directory

.Parameter p
print the directory stack with one entry per line

.Parameter v
print the directory stack with one entry per line prefixed

.Parameter N
[+|-]N Displays the Nth entry counting from the [left|right] of the listshown by dirs when invoked without options, starting with zero.

.Inputs
None

.Outputs
The current directory stack

#>
function List-Locations {
    [CmdletBinding()]
    Param (
        [string] $N = "",
        [switch] $v = $false,
        [switch] $c = $fasle,
        [switch] $p = $false,
        [switch] $l = $false
    )

    if ($c) {
        $Global:myDirStack = @()
        return
    }

    $a = ,(Get-Location).Path + $Global:myDirStack
    if (-not($l)) { $a = $a | % { $_ -replace "$($env:HOME -replace '\\','\\')", "~" } }

    $mi = $a.Count - 1

    if ($v) {
        $i = 0
        $a | % { "$i  $_"; $i++ }
        return
    }

    if ($p) {
        $a | % { $_ }
        return
    }

    if ($N) {
        if (('+', '-') -contains $N.ToCharArray()[0]) {
            $i = [int]$N

            if ($i -ne $null) {
                if ($i -lt (-1 * $mi) -or $i -gt $mi) {
                    Write-Host "dirs: $($N): directory stack index out of range"
                    return
                }

                if ($N.ToCharArray()[0] -eq '-') { $i = $mi + $i }
                
                $a[$i]
            }
            else {
                Write-Host "dirs: $($N): invalid number"
            }
        }
        return
    }

    $a -join "`r`n"
}

Set-Alias -Name dirs -Value List-Locations

<#
.Synopsis
Add directories to stack.

.Description
Adds a directory to the top of the directory stack, or rotates the stack, making the new top of the stack the current working directory.  With no arguments, exchanges the top two directories.

.Parameter Path
A string prefixed by '+' followed by integer N rotates the stack so that the Nth directory (counting from the left of the list shown by `dirs', starting with zero) is at the top.
A string prefixed by '-' followed by integer N rotates the stack so that the Nth directory (countingfrom the right of the list shown by `dirs', starting with zero) is at the top.
Otherwise a path is assumed and, when valid, adds <String> to the directory stack at the top, making it the new current working directory.

The `dirs' builtin displays the directory stack.

.Inputs
None

.Outputs
The new directory stack

#>
function Push-Location {
    Param(
        [string] $Path
    )
    $c = (Get-Location).Path

    if (-not($Path)) {
        if ($Global:myDirStack.Count -gt 0) {
            Set-Location $Global:myDirStack[0]
            $Global:myDirStack[0] = $c
        }
        else {
            Write-Host "pushd: no other directory"; return;
        }
    }
    elseif ($Path.ToCharArray()[0] -eq "+" -or $Path.ToCharArray()[0] -eq "-") {
        $a = ,$c + $Global:myDirStack
        $mi = $a.Count - 1
        $i = [int]$Path
        if ($i -ne $null) {
            if ($Path.ToCharArray()[0] -eq "-") {
                $i = $mi + $i
            }

            if ($i -lt 0 -or $i -gt $mi) {
                Write-Host "pushd: $($Path): directory stack index out of range"
                return
            }

            $a = Shift-Array $i $a
            $Global:myDirStack = $a[1..$mi]
            Set-Location $a[0]
        }
        else {
            Write-Host "pushd: $($Path): invalid number"
        }
    }
    else {
        $n = Resolve-Path -Path $Path
        if ($n) {
            $Global:myDirStack = ,$c + $Global:myDirStack
            Set-Location $n
        }
    }
    List-Locations
}

<#
.Synopsis
Remove directories from stack.

.Description
Removes entries from the directory stack. With no arguments, removes the top directory from the stack, and changes to the new top directory.

.Parameter n
Suppresses the normal change of directory when removingdirectories from the stack, so only the stack is manipulated.

.Parameter Index
A string prefixed with '+' followed by an integer N removes the Nth entry counting from the left of the list shown by `dirs', starting with zero.  For example: `popd +0' removes the first directory, `popd +1' the second.
A string prefixed with '-' followed by an integer N removes the Nth entry counting from the right of the list shown by `dirs', starting with zero.  For example: `popd -0' removes the last directory, `popd -1' the next to last.

#>
function Pop-Location {
    Param (
        [string] $Index = "+0",
        [switch] $n = $false
    )

    if ($Global:myDirStack.Count -gt 0) {
        $a = ,(Get-Location).Path + $Global:myDirStack
        $mi = $a.Count - 1
        $i = [int]$Index

        if ($i -ne $null) {
            if ($i -lt (-1 * $mi) -or ($i -gt $mi)) {
                Write-Host "popd: $($Index): directory stack index out of range"
                return
            }

            if ($Index.ToCharArray()[0] -eq '-') { $i = $mi + $i }

            $a = Remove-ArrayItem $i $a

            if (-not($n)) {
                if ($a.Count -eq 1) { Set-Location $a }
                else { Set-Location $a[0] }
            }

            if ($a.Count -gt 1) { $Global:myDirStack = $a[1..($a.Count - 1)] }
            else { $Global:myDirStack = @() }
            
            List-Locations
        }
        else {
            Write-Host "popd: $($Index): invalid number"
        }
    }
    else {
        Write-Host "popd: directory stack empty"; return;
    }
}
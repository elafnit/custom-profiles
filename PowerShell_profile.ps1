# Import module from previous step
Import-Module -Name 'C:\Program Files\WindowsPowerShell\Modules\posh-git\0.7.3\posh-git.psd1'

#----------- prompt
function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function prompt {
    $realLASTEXITCODE = $LASTEXITCODE
    $curDir = ($(Get-Location) -replace ($($env:HOME) -replace "\\","\\"),'~')

    Write-Host

    if (Test-Administrator) {  # Use different username if elevated
        Write-Host "(admin)$($env:USERNAME)" -NoNewline -ForegroundColor Yellow
    }
    else {
        Write-Host "$($env:USERNAME)" -NoNewline -ForegroundColor Green
    }
    Write-Host ":" -NoNewline -ForegroundColor White
    Write-Host $curDir -NoNewline -ForegroundColor Blue

    $global:LASTEXITCODE = $realLASTEXITCODE

    Write-VcsStatus

    Write-Host ""
    $Host.UI.RawUI.WindowTitle = $curDir
    "ψ > "
}

function console {
    $console = $host.ui.rawui
    $console.foregroundcolor = "White"
}

#----------- touch

<#
.Synopsis
Update-FileStamp [OPTION]... FILE...

.Description
Update the access and modification times of each FILE to the current time.

A FILE argument that does not exist is created empty, unless -c is supplied.

Mandatory arguments to long options are mandatory for short options too.

-a  change only the access time

-c, --no-create
    do not create any files

-d, --date STRING
    parse STRING and use it instead of current time

-m  change only the modification time

-r, --reference FILE
    use this file's times instead of current time

-t STAMP
    use [[CC]YY]MMDDhhmm[.ss] instead of current time

--time WORD
    change  the  specified  time: 
    WORD is access, atime, or use: equivalent to -a 
    WORD is modify or mtime: equivalent to -m

--version
    output version information and exit

    Note that the -d and -t options accept different time-date formats.

#>
function Update-FileStamp {
    $version = 'Update-FileStamp v1.0'
    if ($args -contains '--version') { return $version }

    $parameters = @{}

    $paths = @()

    #parse arguments into parameters
    for ($i = 0; $i -lt $args.Length; $i++) {
        if ($paths.Length -eq 0) {

            if ($args[$i][0] -eq '-') {
                if (@('-a', '-c', '-m', '--no-create') -contains $args[$i]) {
                    $parameters[$args[$i]] = $true
                }
                elseif (@('-d', '-r', '-t', '--time', '--date', '--reference') -contains $args[$i]) {
                    $parameters[$args[$i]] = $args[$i + 1]
                    $i++
                }
                else {
                    Write-Error "Parameter $($args[$i]) is not a supported."
                    exit
                }
            }
            else {
                $paths += $args[$i]
            }
        }
        else {
            $paths += $args[$i]
        }
    }

    #apply parameters
    $paths | % {
        $file = Get-Item $_ -ErrorAction SilentlyContinue
        $accessDate = Get-Date
        if (-not($file)) {
            if (-not($parameters['-c'] -or $parameters['--no-create'])) {
                $file = New-Item -Path $_ -ItemType File
                $accessDate = $file.CreationTime
            }
            else {
                "File: $($_) does not exist."
            }
        }
        if ($file) {
            $modifiedDate = $accessDate

            if ($null -ne $parameters['-r'] -or $null -ne $parameters['--reference']) {
                if ($parameters['--reference']) { $parameters['-r'] = $parameters['--reference'] }
                $refFile = Get-Item $parameters['-r'] -ErrorAction SilentlyContinue
                if (-not($refFile)) {
                    Write-Error "Reference file '$($parameters['-r'])' does not exist."
                    exit
                }
                else {
                    $accessDate = $refFile.LastAccessTime
                    $modifiedDate = $refFile.LastWriteTime
                }
            }
            elseif ($null -ne $parameters['-d'] -or $null -ne $parameters['--date']) {
                if ($parameters['--date']) { $parameters['-d'] = $parameters['--date'] }
                $date = [datetime]::Parse($parameters['-d'])
                $accessDate = $date
                $modifiedDate = $date
            }
            elseif ($null -ne $parameters['-t']) {
                if ( $parameters['-t'] -match '^(\d{2,4})(\d{2})(\d{2})(\d{2})(\d{2})(\.(\d{2}))?$') {
                    $parsedFormat = 'yyyy'
                    if ($matches[1].Length -eq 2) { $parsedFormat = 'yy' }
                    $parsedFormat += "MMddHHmm"
                    if ($matches[7]) { $parsedFormat += '.ss' }

                    $date = [datetime]::ParseExact($parameters['-t'], $parsedFormat, [cultureinfo]::InvariantCulture)
                    $accessDate = $date
                    $modifiedDate = $date
                }
                else {
                    Write-Error "Invalid date '$($parameters['-t'])' for this option."
                    exit
                }
            }

            if ($parameters['--time']) {
                if (-not(@('access', 'atime', 'use', 'modify', 'mtime') -contains $parameters['--time'])) {
                    Write-Error "Time parameter value '$($parameters['--time'])' not supported. Try one of 'access', 'atime', 'use', 'modify', or 'mtime'."
                    exit
                }
                elseif (@('access', 'atime', 'use') -contains $parameters['--time']) {
                    $parameters['-a'] = $true
                }
                else {
                    $parameters['-m'] = $true
                }
            }

            if ($parameters['-a'] -or $parameters['-m']) {
                if ($parameters['-a']) {
                    $file.LastAccessTime = $accessDate
                }
                if ($parameters['-m']) {
                    $file.LastWriteTime = $modifiedDate
                }
            }
            else {
                $file.LastAccessTime = $accessDate
                $file.LastWriteTime = $modifiedDate
            }
        }
    }
}

Set-Alias -Name touch -Value Update-FileStamp

#----------- pushd, popd, dirs
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

    $a = , (Get-Location).Path + $Global:myDirStack
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
        $a = , $c + $Global:myDirStack
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
            $Global:myDirStack = , $c + $Global:myDirStack
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
        $a = , (Get-Location).Path + $Global:myDirStack
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

$Global:OriginalForegroundColor = $Host.UI.RawUI.ForegroundColor
if ([System.Enum]::IsDefined([System.ConsoleColor], 1) -eq "False") { $Global:OriginalForegroundColor = "Gray" }

$Global:GetChildItemColorVerticalSpace = 1

$Global:GetChildItemColorExtensions = @{}

$GetChildItemColorExtensions.Add(
    'CompressedList',
    @(
        ".7z",
        ".gz",
        ".rar",
        ".tar",
        ".zip"
    )
)

$GetChildItemColorExtensions.Add(
    'ExecutableList',
    @(
        ".exe",
        ".bat",
        ".cmd",
        ".reg",
        ".fsx",
        ".sh"
    )
)

$GetChildItemColorExtensions.Add(
    'DllPdbList',
    @(
        ".dll",
        ".pdb"
    )
)

$GetChildItemColorExtensions.Add(
    'TextList',
    @(
        ".csv",
        ".log",
        ".markdown",
        ".md",
        ".rst",
        ".txt"
    )
)

$GetChildItemColorExtensions.Add(
    'ConfigsList',
    @(
        ".cfg",
        ".conf",
        ".config",
        ".ini",
        ".json"
    )
)

$GetChildItemColorExtensions.Add(
    'SourceCodeList',
    @(
        # Ada
        ".adb", ".ads",

        # C Programming language
        ".c", ".h",

        # C++
        #".C", ".h"
        ".cc", ".cpp", ".cxx", ".c++", ".hh", ".hpp", ".hxx", ".h++",

        # C#
        ".cs",

        # COBOL
        ".cbl", ".cob", ".cpy",

        # Common Lisp
        ".lisp", ".lsp", ".l", ".cl", ".fasl",

        # Clojure
        ".clj", ".cljs", ".cljc", "edn",

        # Erlang
        ".erl", ".hrl",

        # F# Programming Language
        #".fsx"
        ".fs", ".fsi", ".fsscript",

        # Fortran
        ".f", ".for", ".f90",

        # Go
        ".go",

        # Groovy
        ".grooy",

        # Haskell
        ".hs", ".lhs",

        # HTML
        ".html", ".htm", ".hta", ".css", ".scss",
        
        # Java
        ".java", ".class", ".jar",

        # Javascript
        ".js", ".mjs", ".ts", ".tsx"

        # Objective C
        ".m", ".mm",

        # P Programming Language
        ".p",

        # Perl
        ".pl", ".pm", ".t", ".pod",

        # PHP
        ".php", ".phtml", ".php3", ".php4", ".php5", ".php7", ".phps", ".php-s", ".pht",

        # Pascal
        ".pp", ".pas", ".inc",

        # PowerShell
        ".ps1", ".psm1", ".ps1xml", ".psc1", ".psd1", ".pssc", ".cdxml",

        # Prolog
        #".P"
        #".pl"
        ".pro",

        # Python
        ".py", ".pyx", ".pyc", ".pyd", ".pyo", ".pyw", ".pyz",

        # R Programming Language
        ".r", ".RData", ".rds", ".rda",

        # Ruby
        ".rb"

        # Rust
        ".rs", ".rlib",

        # Scala
        ".scala", ".sc",

        # Scheme
        ".scm", ".ss",

        # Swift
        ".swift",

        # Unreal Script
        ".uc", ".uci", ".upkg",

        # SQL
        ".sql",

        # VB Script
        ".vbs", ".vbe", ".wsf", ".wsc", ".asp"
    )
)

$Global:GetChildItemColorTable = @{
    File    = @{ Default = $Global:OriginalForegroundColor }
    Service = @{ Default = $Global:OriginalForegroundColor }
    Match   = @{ Default = $Global:OriginalForegroundColor }
}

$Global:GetChildItemColorTable.File.Add('Directory', "Blue")
$Global:GetChildItemColorTable.File.Add('Symlink', "Cyan") 

ForEach ($Extension in $GetChildItemColorExtensions.CompressedList) {
    $Global:GetChildItemColorTable.File.Add($Extension, "Red")
}

ForEach ($Extension in $GetChildItemColorExtensions.ExecutableList) {
    $Global:GetChildItemColorTable.File.Add($Extension, "Green")
}

ForEach ($Extension in $GetChildItemColorExtensions.TextList) {
    $Global:GetChildItemColorTable.File.Add($Extension, "Yellow")
}

ForEach ($Extension in $GetChildItemColorExtensions.DllPdbList) {
    $Global:GetChildItemColorTable.File.Add($Extension, "DarkGreen")
}

ForEach ($Extension in $GetChildItemColorExtensions.ConfigsList) {
    $Global:GetChildItemColorTable.File.Add($Extension, "Gray")
}

ForEach ($Extension in $GetChildItemColorExtensions.SourceCodeList) {
    $Global:GetChildItemColorTable.File.Add($Extension, "DarkYellow")
}

$Global:GetChildItemColorTable.Service.Add('Running', "DarkGreen")
$Global:GetChildItemColorTable.Service.Add('Stopped', "DarkRed")

$Global:GetChildItemColorTable.Match.Add('Path', "Cyan")
$Global:GetChildItemColorTable.Match.Add('LineNumber', "Yellow")
$Global:GetChildItemColorTable.Match.Add('Line', $Global:OriginalForegroundColor)


#. "$PSScriptRoot\Get-ChildItemColorTable.ps1"

Function Get-FileColor($Item) {
    $Key = 'Default'

    if ([bool]($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        $Key = 'Symlink'
    }
    Else {
        If ($Item.GetType().Name -eq 'DirectoryInfo') {
            $Key = 'Directory'
        }
        Else {
            If ($Item.PSobject.Properties.Name -contains "Extension") {
                If ($Global:GetChildItemColorTable.File.ContainsKey($Item.Extension)) {
                    $Key = $Item.Extension
                }
            }
        }
    }

    $Color = $Global:GetChildItemColorTable.File[$Key]
    Return $Color
}

Function Get-ChildItemColor {
    Param(
        [string]$Path = ""
    )
    $Expression = "Get-ChildItem -Path `"$Path`" $Args"

    $Items = Invoke-Expression $Expression

    ForEach ($Item in $Items) {
        $Color = Get-FileColor $Item

        $Host.UI.RawUI.ForegroundColor = $Color
        $Item
        $Host.UI.RawUI.ForegroundColor = $Global:OriginalForegroundColor
    }
}

Function Get-ChildItemColorFormatWide {
    Param(
        [string]$Path = "",
        [switch]$Force
    )

    $nnl = $True

    $Expression = "Get-ChildItem -Path `"$Path`" $Args"

    if ($Force) { $Expression += " -Force" }

    $Items = Invoke-Expression $Expression

    $lnStr = $Items | Select-Object Name | Sort-Object { LengthInBufferCells("$_") } -Descending | Select-Object -First 1
    $len = LengthInBufferCells($lnStr.Name)
    $width = $Host.UI.RawUI.WindowSize.Width
    $cols = If ($len) { [math]::Floor(($width + 1) / ($len + 2)) } Else { 1 }
    if (!$cols) { $cols = 1 }

    $i = 0
    $pad = [math]::Ceiling(($width + 2) / $cols) - 3

    ForEach ($Item in $Items) {
        If ($Item.PSobject.Properties.Name -contains "PSParentPath") {
            If ($Item.PSParentPath -match "FileSystem") {
                $ParentType = "Directory"
                $ParentName = $Item.PSParentPath.Replace("Microsoft.PowerShell.Core\FileSystem::", "")
            }
            ElseIf ($Item.PSParentPath -match "Registry") {
                $ParentType = "Hive"
                $ParentName = $Item.PSParentPath.Replace("Microsoft.PowerShell.Core\Registry::", "")
            }
        }
        Else {
            $ParentType = ""
            $ParentName = ""
            $LastParentName = $ParentName
        }

        If ($LastParentName -ne $ParentName) {
            If ($i -ne 0 -AND $Host.UI.RawUI.CursorPosition.X -ne 0) {
                # conditionally add an empty line
                Write-Host ""
            }

            For ($l = 1; $l -le $GetChildItemColorVerticalSpace; $l++) {
                Write-Host ""
            }

            Write-Host -Fore $Global:OriginalForegroundColor "   $($ParentType):" -NoNewline

            $Color = $Global:GetChildItemColorTable.File['Directory']
            Write-Host -Fore $Color " $ParentName"

            For ($l = 1; $l -le $GetChildItemColorVerticalSpace; $l++) {
                Write-Host ""
            }

        }

        $nnl = ++$i % $cols -ne 0

        # truncate the item name
        $toWrite = $Item.Name
        $itemLength = LengthInBufferCells($toWrite)
        If ($itemLength -gt $pad) {
            $toWrite = (CutString $toWrite $pad)
            $itemLength = LengthInBufferCells($toWrite)
        }

        $Color = Get-FileColor $Item
        $widePad = $pad - ($itemLength - $toWrite.Length)
        Write-Host ("{0,-$widePad}" -f $toWrite) -Fore $Color -NoNewLine:$nnl

        If ($nnl) {
            Write-Host "  " -NoNewLine
        }

        $LastParentName = $ParentName
    }

    For ($l = 1; $l -lt $GetChildItemColorVerticalSpace; $l++) {
        Write-Host ""
    }

    If ($nnl) {
        # conditionally add an empty line
        Write-Host ""
    }
}

Add-Type -assemblyname System.ServiceProcess

# Helper method for simulating ellipsis
function CutString {
    param ([string]$Message, $length)

    $len = 0
    $count = 0
    $max = $length - 3
    ForEach ($c in $Message.ToCharArray()) {
        $len += LengthInBufferCell($c)
        if ($len -gt $max) {
            Return $Message.SubString(0, $count) + '...'
        }
        $count++
    }
    Return $Message
}

function LengthInBufferCells {
    param ([string]$Str)

    $len = 0
    ForEach ($c in $Str.ToCharArray()) {
        $len += LengthInBufferCell($c)
    }
    Return $len
}


function LengthInBufferCell {
    param ([char]$Char)
    # The following is based on http://www.cl.cam.ac.uk/~mgk25/c/wcwidth.c
    # which is derived from https://www.unicode.org/Public/UCD/latest/ucd/EastAsianWidth.txt
    [bool]$isWide = $Char -ge 0x1100 -and
    ($Char -le 0x115f -or # Hangul Jamo init. consonants
        $Char -eq 0x2329 -or $Char -eq 0x232a -or
        ([uint32]($Char - 0x2e80) -le (0xa4cf - 0x2e80) -and
            $Char -ne 0x303f) -or # CJK ... Yi
        ([uint32]($Char - 0xac00) -le (0xd7a3 - 0xac00)) -or # Hangul Syllables
        ([uint32]($Char - 0xf900) -le (0xfaff - 0xf900)) -or # CJK Compatibility Ideographs
        ([uint32]($Char - 0xfe10) -le (0xfe19 - 0xfe10)) -or # Vertical forms
        ([uint32]($Char - 0xfe30) -le (0xfe6f - 0xfe30)) -or # CJK Compatibility Forms
        ([uint32]($Char - 0xff00) -le (0xff60 - 0xff00)) -or # Fullwidth Forms
        ([uint32]($Char - 0xffe0) -le (0xffe6 - 0xffe0)))

    # We can ignore these ranges because .Net strings use surrogate pairs
    # for this range and we do not handle surrogage pairs.
    # ($Char -ge 0x20000 -and $Char -le 0x2fffd) -or
    # ($Char -ge 0x30000 -and $Char -le 0x3fffd)
    if ($isWide) {
        Return 2
    }
    else {
        Return 1
    }
}

# Helper method to write file length in a more human readable format
function Write-FileLength {
    Param ($Length)

    If ($Length -eq $null) {
        Return ""
    }
    ElseIf ($Length -ge 1GB) {
        Return ($Length / 1GB).ToString("F") + 'GB'
    }
    ElseIf ($Length -ge 1MB) {
        Return ($Length / 1MB).ToString("F") + 'MB'
    }
    ElseIf ($Length -ge 1KB) {
        Return ($Length / 1KB).ToString("F") + 'KB'
    }

    Return $Length.ToString() + '  '
}

# Outputs a line of a DirectoryInfo or FileInfo
function Write-Color-LS {
    param ([string]$Color = "White", $Item)

    Write-host ("{0,-7} {1,25} {2,10} " -f $Item.mode, ([String]::Format("{0,10}  {1,8}", $Item.LastWriteTime.ToString("d"), $Item.LastWriteTime.ToString("t"))), (Write-FileLength $Item.length)) -NoNewline -ForegroundColor $Global:OriginalForegroundColor
    Write-host ($Item.name) -ForegroundColor $Color
}

function FileInfo {
    param (
        [Parameter(Mandatory = $True, Position = 1)]
        $Item
    )

    $ParentName = $Item.PSParentPath.Replace("Microsoft.PowerShell.Core\FileSystem::", "")

    If ($Script:LastParentName -ne $ParentName) {
        $Color = $Global:GetChildItemColorTable.File['Directory']
        $ParentName = $Item.PSParentPath.Replace("Microsoft.PowerShell.Core\FileSystem::", "")

        Write-Host
        Write-Host "    Directory: " -noNewLine
        Write-Host " $($ParentName)`n" -ForegroundColor $Color

        For ($l = 1; $l -lt $GetChildItemColorVerticalSpace; $l++) {
            Write-Host ""
        }

        Write-Host "Mode                LastWriteTime     Length Name"
        Write-Host "----                -------------     ------ ----"
    }

    $Color = Get-FileColor $Item

    Write-Color-LS $Color $Item

    $Script:LastParentName = $ParentName
}

# Outputs a line of a ServiceController
function Write-Color-Service {
    param ([string]$Color = "White", $service)

    Write-host ("{0,-8}" -f $_.Status) -ForegroundColor $Color -noNewLine
    Write-host (" {0,-18} {1,-39}" -f (CutString $_.Name 18), (CutString $_.DisplayName 38)) -ForegroundColor "white"
}

function ServiceController {
    param (
        [Parameter(Mandatory = $True, Position = 1)]
        $Service
    )

    if ($script:showHeader) {
        Write-Host
        Write-Host "Status   Name               DisplayName"
        $script:showHeader = $false
    }

    if ($Service.Status -eq 'Stopped') {
        Write-Color-Service $Global:GetChildItemColorTable.Service["Stopped"] $Service
    }
    elseif ($Service.Status -eq 'Running') {
        Write-Color-Service $Global:GetChildItemColorTable.Service["Running"] $Service
    }
    else {
        Write-Color-Service $Global:GetChildItemColorTable.Service["Default"] $Service
    }
}

function MatchInfo {
    param (
        [Parameter(Mandatory = $True, Position = 1)]
        $Match
    )

    Write-host $Match.RelativePath($pwd) -ForegroundColor $Global:GetChildItemColorTable.Match["Path"] -noNewLine
    Write-host ':' -ForegroundColor $Global:GetChildItemColorTable.Match["Default"] -noNewLine
    Write-host $Match.LineNumber -ForegroundColor $global:GetChildItemColorTable.Match["Line"] -noNewLine
    Write-host ':' -ForegroundColor $Global:GetChildItemColorTable.Match["Default"] -noNewLine
    Write-host $Match.Line -ForegroundColor $Global:GetChildItemColorTable.Match["Line"]
}

function Write-Color-Process {
    param ([string]$color = "white", $file)

    Write-host ("{0,-7} {1,25} {2,10} {3}" -f $file.mode, ([String]::Format("{0,10}  {1,8}", $file.LastWriteTime.ToString("d"), $file.LastWriteTime.ToString("t"))), (Write-FileLength $file.length), $file.name) -foregroundcolor $color
}

function ProcessInfo {
    param (
        [Parameter(Mandatory = $True, Position = 1)]
        $process
    )

    if ($script:showHeader) {
        Write-Host        
        Write-Host 'Handles  NPM(K)    PM(K)      WS(K) VM(M)   CPU(s)     Id ProcessName'
        Write-Host '-------  ------    -----      ----- -----   ------     -- -----------'
        $script:showHeader = $false
    }
    $id = $_.Id
    $owner = (Get-WmiObject -Class Win32_Process -Filter "ProcessId = $id").getowner()

    Write-Host ("{0,7} {1,7} {2,8} {3} {4}" -f $_.Handles, `
            [math]::Round($_.NonpagedSystemMemorySize / 1KB), `
            [math]::Round($_.PagedMemorySize / 1KB),
        $owner.domain,
        $owner.user

    )
}

$script:showHeader = $true

function Out-Default {
    [CmdletBinding(HelpUri = 'http://go.microsoft.com/fwlink/?LinkID=113362', RemotingCapability = 'None')]
    param(
        [switch]
        ${Transcript},

        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [psobject]
        ${InputObject})

    begin {
        try {
            For ($l = 1; $l -lt $GetChildItemColorVerticalSpace; $l++) {
                Write-Host ""
            }

            $outBuffer = $null
            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer)) {
                $PSBoundParameters['OutBuffer'] = 1
            }
            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Core\Out-Default', [System.Management.Automation.CommandTypes]::Cmdlet)
            $scriptCmd = { & $wrappedCmd @PSBoundParameters }

            $steppablePipeline = $scriptCmd.GetSteppablePipeline()
            $steppablePipeline.Begin($PSCmdlet)
        }
        catch {
            throw
        }
    }

    process {
        try {
            if (($_ -is [System.IO.DirectoryInfo]) -or ($_ -is [System.IO.FileInfo])) {
                FileInfo $_
                $_ = $null
            }

            elseif ($_ -is [System.ServiceProcess.ServiceController]) {
                ServiceController $_
                $_ = $null
            }

            elseif ($_ -is [Microsoft.Powershell.Commands.MatchInfo]) {
                MatchInfo $_
                $_ = $null
            }
            else {
                $steppablePipeline.Process($_)
            }
        }
        catch {
            throw
        }
    }

    end {
        try {
            For ($l = 1; $l -le $GetChildItemColorVerticalSpace; $l++) {
                Write-Host ""
            }

            $script:showHeader = $true
            $steppablePipeline.End()
        }
        catch {
            throw
        }
    }
    <#
    .ForwardHelpTargetName Out-Default
    .ForwardHelpCategory Function
    #>
}
Set-Alias -Name ls -Value Get-ChildItemColorFormatWide -Option AllScope
Set-Alias -Name ll -Value Get-ChildItemColor

#----------- od
function Get-HexDump {
    [CmdletBinding(DefaultParameterSetName = "FileName", SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$FileName,
    
        [Parameter(Mandatory = $false,
            Position = 1)]
        [ValidateRange(0, 65535)]
        [Int32]$BytesToProcess = -1
    )

    begin {
        $ofs = ''
        [Int32]$line = 0
        $asciiWhitespaces = @{
            [byte]9 = "\t"
            [byte]10 = "\n"
            [byte]11 = "\v"
            [byte]12 = "\f"
            [byte]13 = "\r"
            [byte]32 = "  "
        }
    }
    process {
        switch ((Test-Path $FileName)) {
            $true {
                if ($PSCmdlet.ShouldProcess($FileName, "Get hex dump of")) {

                    gc -ea 0 -AsByteStream $FileName -re 16 -to $BytesToProcess | % {
                        "{0:X8} {1}`n         {2, -64}" -f $line++, [String](
                            $_ | % {
                                if ([Char]::IsLetterOrDigit($_) -or [Char]::IsSymbol($_) `
                                        -or [Char]::IsPunctuation($_)) { $c = " " + [Char]$_ }
                                elseif ([Char]::IsWhiteSpace($_)) { $c = $asciiWhitespaces[$_] }
                                else { $c = ' .' }
                                " $c "
                            }
                        ), [String](
                            $_ | % { ' ' + ('{0}' -f $_).PadLeft(3, "0") }
                        )
                    }
                }
            }
            default { Write-Warning "file not found or does not exist." }
        }
    }
    end {}
}

Set-Alias od Get-HexDump

#----------- which

Function Get-FilePath () {
    [CmdletBinding()]
    Param (
        $FileName
    )

    $env:path.ToLower() -split ';' | % {
        if ($_[$_.length - 1] -eq '\') {
            $_.Remove($_.length - 1)
        }
        else {
            $_
        } } | sort | unique | % {
        Get-ChildItem -Path $_ -Filter "$FileName.*" -Force -ErrorAction SilentlyContinue } | % {
        if (@('.bat', '.bin', '.cmd', '.com', '.cpl', '.exe', '.gadget', '.inf1', '.ins', '.inx', '.isu', '.job', '.jse', '.lnk', '.msc', '.msi', '.msp', '.mst', '.paf', '.pif', '.ps1', '.reg', '.rgs', '.scr', '.sct', '.shb', '.shs', '.u3p', '.vb', '.vbe', '.vbs', '.vbscript', '.ws', '.wsf', '.wsh') -contains $_.Extension) {
            $_.FullName
        }
    }
}

Set-Alias which Get-FilePath

#Aliases
Set-Alias -Name vi -Value vim
Set-Alias -Name vs19 -Value "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\Common7\IDE\devenv.exe"
Set-Alias -Name vs22 -Value "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\devenv.exe"
Set-Alias -Name vs -Value "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\devenv.exe"

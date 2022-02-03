
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
Set-Alias -Name ls -Value Get-ChildItemColorFormatWide
Set-Alias -Name ll -Value Get-ChildItemColor

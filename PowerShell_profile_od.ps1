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
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
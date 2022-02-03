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

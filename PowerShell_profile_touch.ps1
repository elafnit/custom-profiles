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
    if ($args -contains '--version') {return $version}

    $parameters = @{}

    $paths = @()

    #parse arguments into parameters
    for($i = 0; $i -lt $args.Length; $i++){
        if ($paths.Length -eq 0){

            if ($args[$i][0] -eq '-'){
                if (@('-a','-c','-m','--no-create') -contains $args[$i]){
                    $parameters[$args[$i]] = $true
                }
                elseif (@('-d','-r','-t','--time','--date','--reference') -contains $args[$i]) {
                    $parameters[$args[$i]] = $args[$i+1]
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

    #apply parameters to files
    $paths | % {
        #determine if file exists and how to manage if not
        $file = Get-Item $_ -ErrorAction SilentlyContinue
        $accessDate = Get-Date
        if (-not($file)) {
            if (-not($parameters['-c'] -or $parameters['--no-create'])){
                $file = New-Item -Path $_ -ItemType File
                $accessDate = $file.CreationTime
            }
        }
        if ($file) {
            #determine which date to use

            #current
            $modifiedDate = $accessDate

            #date from reference file
            if ($null -ne $parameters['-r'] -or $null -ne $parameters['--reference']){
                if ($parameters['--reference']){ $parameters['-r'] = $parameters['--reference']}
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
            #date from -d parameter
            elseif ($null -ne $parameters['-d'] -or $null -ne $parameters['--date']){
                if ($parameters['--date']){ $parameters['-d'] = $parameters['--date']}
                $date = [datetime]::Parse($parameters['-d'])
                $accessDate = $date
                $modifiedDate = $date
            }
            #date from -t parameter
            elseif ($null -ne $parameters['-t']){
                if ( $parameters['-t'] -match '^(\d{2,4})(\d{2})(\d{2})(\d{2})(\d{2})(\.(\d{2}))?$'){
                    $parsedFormat = 'yyyy'
                    if ($matches[1].Length -eq 2){ $parsedFormat = 'yy'}
                    $parsedFormat += "MMddHHmm"
                    if ($matches[7]){ $parsedFormat += '.ss'}

                    $date = [datetime]::ParseExact($parameters['-t'],$parsedFormat,[cultureinfo]::InvariantCulture)
                    $accessDate = $date
                    $modifiedDate = $date
                }
                else {
                    Write-Error "Invalid date '$($parameters['-t'])' for this option."
                    exit
                }
            }
            #determine which date to update if --time parameter is used
            if ($parameters['--time']) {
                if (-not(@('access','atime','use','modify','mtime') -contains $parameters['--time'])) {
                    Write-Error "Time parameter value '$($parameters['--time'])' not supported. Try one of 'access', 'atime', 'use', 'modify', or 'mtime'."
                    exit
                }
                elseif (@('access','atime','use') -contains $parameters['--time']){
                    $parameters['-a'] = $true
                }
                else {
                    $parameters['-m'] = $true
                }
            }
            #apply update to file
            if ($parameters['-a'] -or $parameters['-m']){
                if ($parameters['-a']){
                    $file.LastAccessTime = $accessDate
                }
                if ($parameters['-m']){
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

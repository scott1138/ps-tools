function Get-TimeStamp {

    param (
        [switch]$Time
    )

    $Format = 'yyyyMMdd'

    if ($Time) {
        $Format = $Format + '_hhmmss'
    }

    $TimeStamp = Get-Date -Format $Format

    return $TimeStamp

}
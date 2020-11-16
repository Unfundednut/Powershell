## Config Options ##
$TautulliAPIKey = ""
$TautulliBaseURL = "http://IPOFTAUT:8181/api/v2"
$TautulliURL = $TautulliBaseURL + "?apikey=" + $TautulliAPIKey
# Get Libraries
$PlexLibraries = (Invoke-RestMethod -Method GET -Uri ($TautulliURL + "&cmd=get_libraries")).response.data
$PlexMovieLibrary = @()
foreach ($PlexLibrary in $PlexLibraries) {
    # $PlexLibraryName = $PlexLibrary.section_name
    $PlexLibraryType = $PlexLibrary.section_type
    $PlexLibrarySectionID = $PlexLibrary.section_id
    if ($PlexLibraryType -eq 'movie') {
        # Write-Host "Running Against $PlexLibraryName"
        $PlexLibraryTitles = Invoke-RestMethod -Method GET -Uri ($TautulliURL + "&cmd=get_library_media_info&section_id=" + $PlexLibrarySectionID + "&length=10000")
        $Movies = $PlexLibraryTitles | Select-Object -ExpandProperty response | Select-Object -ExpandProperty data | Select-Object -ExpandProperty data
        $PlexMovieLibrary += $Movies
    }
}

$TotalMovies = ($PlexMovieLibrary | Measure-Object).Count
$TotalWatchedMovies = ($PlexMovieLibrary | Where-Object {$_.play_count -ge '1'} | Measure-Object).Count
$TotalUnwatchedMovies = $TotalMovies - $TotalWatchedMovies

$MoviesObject = @()
$CurrentStep = 1
foreach ($Movie in $PlexMovieLibrary) {
    $MovieTitle = $Movie.title
    Write-Progress -Activity "Gathering More Information" -Status "($CurrentStep of $TotalMovies) - $MovieTitle ($CurrentStep of $TotalMovies)" -PercentComplete ($CurrentStep / $TotalMovies*100)
    $LastWatched = ((Get-Date "1970-01-01 00:00:00.000Z") + ([TimeSpan]::FromSeconds($Movie.last_played))).ToString('yyyy-MM-dd')
    $LastWatchedDaysAgo = (New-TimeSpan -Start $LastWatched -End (Get-Date)).Days
    $TempSize = [math]::round($Movie.file_size/1GB, 2)
    $TempRatingKey = $Movie.rating_key
    $TempMediaInfo = (Invoke-RestMethod -Method GET -Uri ($TautulliURL + "&cmd=get_metadata&rating_key=$TempRatingKey")).response.data.media_info.parts.file
    $TempMediaFile = $TempMediaInfo -join ","
    $TempMovie = New-Object -TypeName psobject
    Add-Member -InputObject $TempMovie -MemberType NoteProperty Title $MovieTitle
    Add-Member -InputObject $TempMovie -MemberType NoteProperty FileLocation $TempMediaFile
    Add-Member -InputObject $TempMovie -MemberType NoteProperty LastWatched $LastWatched
    Add-Member -InputObject $TempMovie -MemberType NoteProperty LastWatchedDaysAgo $LastWatchedDaysAgo
    Add-Member -InputObject $TempMovie -MemberType NoteProperty PlayCount $Movie.play_count
    Add-Member -InputObject $TempMovie -MemberType NoteProperty FileSizeGB $TempSize
    $MoviesObject += $TempMovie
    $CurrentStep++
}
$WatchedMovieSize = ($MoviesObject | Where-Object {$_.PlayCount -ge '1'} | Measure-Object 'FileSizeGB' -Sum).Sum
$UnWatchedMovieSize = ($MoviesObject | Where-Object {$_.PlayCount -eq $null} | Measure-Object 'FileSizeGB' -Sum).Sum
$TotalSize = ($MoviesObject | Measure-Object 'FileSizeGB' -Sum).Sum
Write-Host "Overall: $TotalMovies Movies At $TotalSize GB"
Write-Host "Watched: $TotalWatchedMovies Movies At $WatchedMovieSize GB"
Write-Host "Unwatched: $TotalUnwatchedMovies Movies $UnWatchedMovieSize GB"

$title    = 'File Removal Confirmation'
$question = 'Would you like to mark files for removal?'
$choices  = '&Yes', '&No'

$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
if ($decision -eq 0) {
    Write-Host 'Choose which files you want to remove and click OK. Press Enter To Continue.'
    $FilesToDelete = $MoviesObject | Out-GridView -Title "Choose Files To Delete" -PassThru
    if ($null -eq $FilesToDelete) {
        Write-Warning "You did not choose any files."
    } else {
        Write-Host "Deleting the chosen file(s)"
        foreach ($File in $FilesToDelete) {
            Remove-Item $File.FileLocation -Force
        }
    }
} else {
    Write-Host 'Well Then'
}

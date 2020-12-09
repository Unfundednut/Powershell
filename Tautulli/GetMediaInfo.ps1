## Config Options ##
$TautulliAPIKey = ""
$TautulliBaseURL = "http://IP:8181/api/v2"
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

$MoviesObject = @()
$CurrentStep = 1
foreach ($Movie in $PlexMovieLibrary) {
    $MovieTitle = $Movie.title
    Write-Progress -Activity "Gathering More Information" -Status "($CurrentStep of $TotalMovies) - $MovieTitle ($CurrentStep of $TotalMovies)" -PercentComplete ($CurrentStep / $TotalMovies*100)
    $TempSize = [math]::round($Movie.file_size/1GB, 2)
    $TempRatingKey = $Movie.rating_key
    $TempInfo = (Invoke-RestMethod -Method GET -Uri ($TautulliURL + "&cmd=get_metadata&rating_key=$TempRatingKey")).response.data
    $TempMediaCodec = $TempInfo.media_info
    $TempMediaContainer = $TempMediaCodec.container
    $TempMediaVideoCodec = $TempMediaCodec.video_codec
    $TempMediaFilePath = $TempInfo.media_info.parts.file
    $TempMediaFile = $TempMediaFilePath -join ","
    $TempMovie = New-Object -TypeName psobject
    Add-Member -InputObject $TempMovie -MemberType NoteProperty Title $MovieTitle
    Add-Member -InputObject $TempMovie -MemberType NoteProperty Library $TempInfo.library_name
    Add-Member -InputObject $TempMovie -MemberType NoteProperty VideoCodec $TempMediaVideoCodec
    Add-Member -InputObject $TempMovie -MemberType NoteProperty VideoContainer $TempMediaContainer
    Add-Member -InputObject $TempMovie -MemberType NoteProperty VideoHeight $TempMediaCodec.height
    Add-Member -InputObject $TempMovie -MemberType NoteProperty VideoWidth $TempMediaCodec.width
    Add-Member -InputObject $TempMovie -MemberType NoteProperty VideoAspectRatio $TempMediaCodec.aspect_ratio
    Add-Member -InputObject $TempMovie -MemberType NoteProperty VideoResolution $TempMediaCodec.video_resolution
    Add-Member -InputObject $TempMovie -MemberType NoteProperty VideoFullResolution $TempMediaCodec.video_full_resolution
    Add-Member -InputObject $TempMovie -MemberType NoteProperty VideoFramerate $TempMediaCodec.video_framerate
    Add-Member -InputObject $TempMovie -MemberType NoteProperty VideoProfile $TempMediaCodec.video_profile
    Add-Member -InputObject $TempMovie -MemberType NoteProperty AudioCodec $TempMediaCodec.audio_codec
    Add-Member -InputObject $TempMovie -MemberType NoteProperty AudioChannels $TempMediaCodec.audio_channels
    Add-Member -InputObject $TempMovie -MemberType NoteProperty AudioChannelLayout $TempMediaCodec.audio_channel_layout
    Add-Member -InputObject $TempMovie -MemberType NoteProperty FileLocation $TempMediaFile
    Add-Member -InputObject $TempMovie -MemberType NoteProperty FileSizeGB $TempSize
    $MoviesObject += $TempMovie
    $CurrentStep++
}
$MoviesObject | Out-GridView

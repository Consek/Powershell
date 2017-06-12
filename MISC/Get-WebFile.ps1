function Get-WebFile{ 
    <#
    .SYNOPSIS
    Downloads file from url.
    
    .DESCRIPTION
    Downloads file from url and displays progress to the console.
    
    .PARAMETER url
    Url from which to download the file.
    
    .PARAMETER targetFile
    Path to save the file
    
    .EXAMPLE
    Get-WebFile -url "https://www.example.com" -targetFile '.\install.exe'

    Downloads file from "https://www.example.com" and saves it to '.\install.exe.
    
    .NOTES
    Sources:
    https://blogs.msdn.microsoft.com/jasonn/2008/06/13/downloading-files-from-the-internet-in-powershell-with-progress/
    https://stackoverflow.com/questions/21422364/is-there-any-way-to-monitor-the-progress-of-a-download-using-a-webclient-object

    .LINK
    Sources:
    https://blogs.msdn.microsoft.com/jasonn/2008/06/13/downloading-files-from-the-internet-in-powershell-with-progress/
    https://stackoverflow.com/questions/21422364/is-there-any-way-to-monitor-the-progress-of-a-download-using-a-webclient-object

    #>
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [String]$url,
        [Parameter(Mandatory=$true,Position=1)]
        [String]$targetFile
    )

    $uri = New-Object "System.Uri" "$url" 
    $request = [System.Net.HttpWebRequest]::Create($uri) 
    $request.set_Timeout(15000) #15 second timeout 
    $request.ContentType = "application/octet-stream"
    $response = $request.GetResponse() 
    $totalLength = [System.Math]::Round(($response.get_ContentLength()/1MB),2) 
    $responseStream = $response.GetResponseStream() 
    $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create 
    $buffer = new-object byte[] 50KB 
    $count = $responseStream.Read($buffer,0,$buffer.length) 
    $downloadedBytes = $count 
    while ($count -gt 0) { 
        $downloaded = "{0:N2}" -f [System.Math]::Round(($downloadedBytes/1MB),2)
        Write-Host -NoNewline "`r Downloaded $downloaded MB of $totalLength MB"
        $targetStream.Write($buffer, 0, $count) 
        $count = $responseStream.Read($buffer,0,$buffer.length) 
        $downloadedBytes = $downloadedBytes + $count 
    } 
    "`nFinished Download" 
    $targetStream.Flush();
    $targetStream.Close() ;
    $targetStream.Dispose() ;
    $responseStream.Dispose() ;
}
# This script will be pulled by a local PowerShell script, triggered by Task Scheduler
# This allows a centrally-managed script to run custom NR monitoring on any number of VMs
# (Avoiding the need to access each VM and update the script each time a change is made)

# Pass New Relic API details into this script or uncomment below
# $accountId = ""  # Replace with your New Relic account ID
# $insertKey = ""  # Replace with your New Relic insert API key
$entityName = $env:COMPUTERNAME    # Auto set computer name for NR metrics

# Run the quser command and get the state for the administrator user
$state = ((quser | Select-String -Pattern "administrator").ToString() -replace '\s+', ' ').Split() | Select-Object -Last 5 | Select-Object -First 1

# Convert the state into a numerical value or string to comply with New Relic's event API requirements
# State will either be "Active" or "Disc"
if ($state -eq "Active") {
    $stateValue = "Occupied"
} else {
    $stateValue = "Free"
}

# Construct the JSON payload
$timestamp = [int64](Get-Date(Get-Date).ToUniversalTime() -UFormat %s)  # Unix timestamp in seconds
$body = @(
    @{
        "eventType" = "RDPConnectionState"    # Event type name (string)
        "state" = $stateValue                 # State ("Running" or "Offline")
        "entityName" = $entityName            # Entity Name (string)
        "timestamp" = $timestamp              # Unix timestamp (number)
    }
) | ConvertTo-Json

# Set the headers for the API request
$headers = @{
    "Api-Key" = $insertKey  # Insert API Key
    "Content-Encoding" = "gzip"
}
$encoding = [System.Text.Encoding]::UTF8
$enc_data = $encoding.GetBytes($body)

# GZip compress the JSON payload
$output = [System.IO.MemoryStream]::new()
$gzipStream = New-Object System.IO.Compression.GzipStream $output, ([IO.Compression.CompressionMode]::Compress)
$gzipStream.Write($enc_data, 0, $enc_data.Length)
$gzipStream.Close()
$gzipBody = $output.ToArray()

# Define the API endpoint URL for the New Relic event
$uri = "https://insights-collector.newrelic.com/v1/accounts/$accountId/events"

# Send the HTTP POST request with compressed data
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
Invoke-WebRequest -Headers $headers -Method Post -Body $gzipBody -Uri $uri 
 
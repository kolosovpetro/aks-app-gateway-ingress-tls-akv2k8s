# Requires Install-Module -Name CloudflareDnsTools -Scope AllUsers

$ErrorActionPreference = "Stop"

$zoneName = "razumovsky.me"

$newDnsEntriesHashtable = @{ }

$newDnsEntriesHashtable["agwy-ingress-test.$zoneName"] = $( terraform output -raw agwy_public_ip )

Set-CloudflareDnsRecord `
    -ApiToken $env:CLOUDFLARE_API_KEY `
    -ZoneName $zoneName `
    -NewDnsEntriesHashtable $newDnsEntriesHashtable

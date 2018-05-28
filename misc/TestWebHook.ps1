$uri = "https://s2events.azure-automation.net/webhooks?token=sHk7PkHA9Ia92Przhi8y%2bsJIEkcV30WFMQt%2fCdErgxI%3d"
$headers = @{"From"="user@contoso.com";"Date"="05/28/2015 15:47:00"}

$vms  = @(
            @{ Name="vm01";ServiceName="vm01"},
            @{ Name="vm02";ServiceName="vm02"}
        )
$body = ConvertTo-Json -InputObject $vms

$response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body
$jobid = ConvertFrom-Json $response
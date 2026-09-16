param(
	[Parameter(Mandatory = $true)][string]$Name,
	[string]$ArgsJson = "{}",
	[int]$Id = 100,
	[string]$SessionFile = "c:\github\Last-Lantern\terraria\debug\mcp_session_id.txt"
)

$ErrorActionPreference = "Stop"
$capPath = Join-Path $env:LOCALAPPDATA "godot-ai\capabilities\http-8001.json"
$cap = Get-Content -Raw $capPath | ConvertFrom-Json
$token = $cap.http
$url = "http://127.0.0.1:8001/mcp"
$headers = @{
	"Authorization" = "Bearer $token"
	"Accept" = "application/json, text/event-stream"
	"Content-Type" = "application/json"
}

function Invoke-Mcp([string]$Body, [hashtable]$ExtraHeaders) {
	$all = @{}
	foreach ($k in $headers.Keys) { $all[$k] = $headers[$k] }
	if ($ExtraHeaders -ne $null) {
		foreach ($k in $ExtraHeaders.Keys) { $all[$k] = $ExtraHeaders[$k] }
	}
	return Invoke-WebRequest -Uri $url -Method POST -Headers $all -Body $Body -UseBasicParsing
}

if (-not (Test-Path $SessionFile)) {
	$initBody = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"cursor-agent","version":"1.0"}}}'
	$init = Invoke-Mcp $initBody $null
	$sid = $init.Headers["mcp-session-id"]
	if (-not $sid) { $sid = $init.Headers["Mcp-Session-Id"] }
	if (-not $sid) { throw "No mcp-session-id. Status=$($init.StatusCode) Body=$($init.Content)" }
	Set-Content -Path $SessionFile -Value $sid -NoNewline
	$sh = @{ "Mcp-Session-Id" = $sid }
	[void](Invoke-Mcp '{"jsonrpc":"2.0","method":"notifications/initialized"}' $sh)
} else {
	$sid = (Get-Content -Raw $SessionFile).Trim()
}

$payload = @{
	jsonrpc = "2.0"
	id = $Id
	method = "tools/call"
	params = @{
		name = $Name
		arguments = ($ArgsJson | ConvertFrom-Json)
	}
} | ConvertTo-Json -Depth 30 -Compress

$resp = Invoke-Mcp $payload @{ "Mcp-Session-Id" = $sid }
Write-Output $resp.Content

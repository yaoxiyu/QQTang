param(
    [string]$Addr = "127.0.0.1:9100",
    [string]$HTTPAddr = "127.0.0.1:19100",
    [string]$ManifestPath = "../../build/generated/room_manifest/room_manifest.json"
)

$env:ROOM_WS_ADDR = $Addr
$env:ROOM_HTTP_ADDR = $HTTPAddr
$env:ROOM_MANIFEST_PATH = $ManifestPath

go run ./cmd/room_service

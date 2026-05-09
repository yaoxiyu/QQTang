class_name NativeWireContract
extends RefCounted

const SNAPSHOT_PAYLOAD_VERSION := 1
# v3: bubble pass phase 模型替换原 ignore_player_ids 列表；每个泡泡条目后附 N*5 个 int + sentinel。
const MOVEMENT_WIRE_VERSION := 3
const EXPLOSION_WIRE_VERSION := 2

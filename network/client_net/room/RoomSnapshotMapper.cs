using Godot;
using QQT.Room.V1;
using System;

namespace QQTang.Network.ClientNet.Room;

public static class RoomSnapshotMapper
{
    public static Godot.Collections.Dictionary ToGodotSnapshot(RoomSnapshot snapshot)
    {
        var plain = RoomSnapshotMapperCore.ToSnapshotDictionary(snapshot);
        return RoomGodotInteropConverter.ToGodotDictionary(plain);
    }
}

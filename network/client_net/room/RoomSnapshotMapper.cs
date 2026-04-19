using Godot;

namespace QQTang.Network.ClientNet.Room;

public static class RoomSnapshotMapper
{
    public static Godot.Collections.Dictionary ToGodotSnapshot(byte[] payload)
    {
        return new Godot.Collections.Dictionary
        {
            { "raw_size", payload?.Length ?? 0 }
        };
    }
}

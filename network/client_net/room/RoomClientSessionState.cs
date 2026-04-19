namespace QQTang.Network.ClientNet.Room;

public sealed class RoomClientSessionState
{
    public bool Connected { get; set; }
    public string ServerUrl { get; set; } = string.Empty;
    public long LastSequence { get; set; }
}

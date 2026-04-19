namespace QQTang.Network.ClientNet.Room;

public sealed class RoomClientSessionState
{
    public bool Connected { get; set; }
    public string ServerUrl { get; set; } = string.Empty;
    public long LastSequence { get; set; }
    public long NextSequence { get; set; } = 1;
    public string LastRequestId { get; set; } = string.Empty;
    public string BoundRoomId { get; set; } = string.Empty;
    public string BoundMemberId { get; set; } = string.Empty;
    public string LocalAccountId { get; set; } = string.Empty;
    public string LocalProfileId { get; set; } = string.Empty;
    public long LastSnapshotRevision { get; set; }
    public bool DirectorySubscribed { get; set; }
    public string ConnectionState { get; set; } = "disconnected";
}

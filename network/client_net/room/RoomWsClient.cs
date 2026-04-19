using Godot;
using QQTang.Network.ClientNet.Shared;

namespace QQTang.Network.ClientNet.Room;

public partial class RoomWsClient : Node
{
    [Signal]
    public delegate void ConnectedEventHandler();

    [Signal]
    public delegate void DisconnectedEventHandler();

    [Signal]
    public delegate void FrameReceivedEventHandler(byte[] payload);

    [Signal]
    public delegate void MessageReceivedEventHandler(Godot.Collections.Dictionary payload);

    [Signal]
    public delegate void RoomErrorEventHandler(string errorCode, string userMessage);

    private readonly WebSocketPeer _socket = new();
    private readonly RoomProtoCodec _codec = new();
    private readonly RoomClientEnvelopeFactory _envelopeFactory = new();
    private readonly RoomCanonicalMessageMapper _messageMapper = new();

    public RoomClientSessionState SessionState { get; } = new();

    public Error ConnectToServer(string host, int port)
    {
        var normalizedHost = string.IsNullOrWhiteSpace(host) ? "127.0.0.1" : host.Trim();
        var normalizedPort = port > 0 ? port : 9100;
        var url = $"ws://{normalizedHost}:{normalizedPort}/ws";

        var err = _socket.ConnectToUrl(url);
        if (err != Error.Ok)
        {
            EmitSignal(SignalName.RoomError, "ROOM_CONNECT_FAILED", $"connect failed: {err}");
            return err;
        }

        SessionState.ServerUrl = url;
        SessionState.Connected = false;
        SessionState.ConnectionState = "connecting";
        return Error.Ok;
    }

    public void DisconnectFromServer()
    {
        _socket.Close();
        if (SessionState.Connected)
        {
            SessionState.Connected = false;
            SessionState.ConnectionState = "disconnected";
            EmitSignal(SignalName.Disconnected);
        }
    }

    public Error SendBinary(byte[] payload)
    {
        if (_socket.GetReadyState() != WebSocketPeer.State.Open)
        {
            return Error.Unavailable;
        }
        return _socket.Send(payload ?? []);
    }

    public Error SendMessage(Godot.Collections.Dictionary message)
    {
        if (message == null)
        {
            return Error.InvalidData;
        }

        if (_socket.GetReadyState() != WebSocketPeer.State.Open)
        {
            return Error.Unavailable;
        }

        try
        {
            var envelope = _envelopeFactory.BuildEnvelope(message, SessionState);
            UpdateSessionStateOnOutgoingMessage(message);
            var encoded = _codec.EncodeEnvelope(envelope);
            return _socket.Send(encoded);
        }
        catch (System.Exception ex)
        {
            EmitSignal(SignalName.RoomError, "ROOM_SEND_FAILED", ex.Message);
            return Error.Failed;
        }
    }

    public override void _Process(double delta)
    {
        _socket.Poll();
        var state = _socket.GetReadyState();

        if (state == WebSocketPeer.State.Open && !SessionState.Connected)
        {
            SessionState.Connected = true;
            SessionState.ConnectionState = "connected";
            EmitSignal(SignalName.Connected);
        }
        else if (state == WebSocketPeer.State.Closed && SessionState.Connected)
        {
            SessionState.Connected = false;
            SessionState.ConnectionState = "disconnected";
            EmitSignal(SignalName.Disconnected);
        }

        while (_socket.GetAvailablePacketCount() > 0)
        {
            var packet = _socket.GetPacket();
            var payload = WsBinaryFrameReader.ToManagedBytes(packet);
            EmitSignal(SignalName.FrameReceived, payload);

            try
            {
                var envelope = _codec.DecodeServerEnvelope(payload);
                var dict = _messageMapper.Map(envelope);
                UpdateSessionStateOnIncomingMessage(dict);
                EmitSignal(SignalName.MessageReceived, dict);
            }
            catch (RoomProtocolDecodeException ex)
            {
                EmitSignal(SignalName.RoomError, ex.ErrorCode, ex.UserMessage);
            }
            catch (System.Exception ex)
            {
                EmitSignal(SignalName.RoomError, "ROOM_MESSAGE_MAP_FAILED", ex.Message);
            }
        }
    }

    private void UpdateSessionStateOnOutgoingMessage(Godot.Collections.Dictionary message)
    {
        var messageType = ReadString(message, "message_type");
        if (messageType == "ROOM_DIRECTORY_SUBSCRIBE")
        {
            SessionState.DirectorySubscribed = true;
        }
        else if (messageType == "ROOM_DIRECTORY_UNSUBSCRIBE")
        {
            SessionState.DirectorySubscribed = false;
        }
        else if (
            messageType == "ROOM_CREATE_REQUEST" ||
            messageType == "ROOM_JOIN_REQUEST" ||
            messageType == "ROOM_RESUME_REQUEST")
        {
            SessionState.LocalAccountId = ReadString(message, "account_id");
            SessionState.LocalProfileId = ReadString(message, "profile_id");
        }
    }

    private void UpdateSessionStateOnIncomingMessage(Godot.Collections.Dictionary message)
    {
        var messageType = ReadString(message, "message_type");
        if (messageType == "ROOM_SNAPSHOT")
        {
            var snapshot = ReadNestedDictionary(message, "snapshot");
            SessionState.BoundRoomId = ReadString(snapshot, "room_id");
            var ownerMemberId = ReadString(snapshot, "owner_member_id");
            var resolvedLocalMemberId = ResolveLocalMemberId(snapshot);
            if (!string.IsNullOrWhiteSpace(resolvedLocalMemberId))
            {
                SessionState.BoundMemberId = resolvedLocalMemberId;
            }
            else if (!string.IsNullOrWhiteSpace(ownerMemberId) && ReadMembers(snapshot).Count == 1)
            {
                SessionState.BoundMemberId = ownerMemberId;
            }
            DecorateSnapshotLocalFlags(snapshot);
            SessionState.LastSnapshotRevision = ReadInt64(snapshot, "snapshot_revision");
        }
    }

    private string ResolveLocalMemberId(Godot.Collections.Dictionary snapshot)
    {
        if (!string.IsNullOrWhiteSpace(SessionState.BoundMemberId))
        {
            return SessionState.BoundMemberId;
        }

        var localAccountId = SessionState.LocalAccountId?.Trim() ?? string.Empty;
        var localProfileId = SessionState.LocalProfileId?.Trim() ?? string.Empty;
        if (string.IsNullOrEmpty(localAccountId) || string.IsNullOrEmpty(localProfileId))
        {
            return string.Empty;
        }

        var members = ReadMembers(snapshot);
        for (var i = 0; i < members.Count; i++)
        {
            if (members[i].VariantType != Variant.Type.Dictionary)
            {
                continue;
            }
            var member = (Godot.Collections.Dictionary)members[i];
            var accountId = ReadString(member, "account_id");
            var profileId = ReadString(member, "profile_id");
            if (string.Equals(accountId, localAccountId, System.StringComparison.Ordinal) &&
                string.Equals(profileId, localProfileId, System.StringComparison.Ordinal))
            {
                return ReadString(member, "member_id");
            }
        }

        return string.Empty;
    }

    private void DecorateSnapshotLocalFlags(Godot.Collections.Dictionary snapshot)
    {
        var localMemberId = SessionState.BoundMemberId?.Trim() ?? string.Empty;
        if (string.IsNullOrEmpty(localMemberId))
        {
            return;
        }

        var members = ReadMembers(snapshot);
        for (var i = 0; i < members.Count; i++)
        {
            if (members[i].VariantType != Variant.Type.Dictionary)
            {
                continue;
            }
            var member = (Godot.Collections.Dictionary)members[i];
            var memberId = ReadString(member, "member_id");
            member["is_local_player"] = string.Equals(memberId, localMemberId, System.StringComparison.Ordinal);
            members[i] = member;
        }
        snapshot["members"] = members;
    }

    private static Godot.Collections.Array ReadMembers(Godot.Collections.Dictionary snapshot)
    {
        if (snapshot == null || !snapshot.ContainsKey("members"))
        {
            return [];
        }
        var value = snapshot["members"];
        return value.VariantType == Variant.Type.Array ? (Godot.Collections.Array)value : [];
    }

    private static Godot.Collections.Dictionary ReadNestedDictionary(Godot.Collections.Dictionary source, string key)
    {
        if (source == null || !source.ContainsKey(key))
        {
            return new Godot.Collections.Dictionary();
        }

        var value = source[key];
        return value.VariantType == Variant.Type.Dictionary ? (Godot.Collections.Dictionary)value : new Godot.Collections.Dictionary();
    }

    private static string ReadString(Godot.Collections.Dictionary source, string key)
    {
        if (source == null || !source.ContainsKey(key))
        {
            return string.Empty;
        }
        return source[key].VariantType switch
        {
            Variant.Type.String => source[key].AsString(),
            Variant.Type.StringName => source[key].AsStringName().ToString(),
            Variant.Type.NodePath => source[key].AsNodePath().ToString(),
            Variant.Type.Nil => string.Empty,
            _ => source[key].ToString(),
        };
    }

    private static long ReadInt64(Godot.Collections.Dictionary source, string key)
    {
        if (source == null || !source.ContainsKey(key))
        {
            return 0;
        }
        return source[key].VariantType switch
        {
            Variant.Type.Int => source[key].AsInt64(),
            Variant.Type.Float => (long)source[key].AsDouble(),
            Variant.Type.String when long.TryParse(source[key].AsString(), out var parsed) => parsed,
            _ => 0,
        };
    }
}

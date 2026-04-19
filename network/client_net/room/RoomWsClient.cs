using Godot;
using QQTang.Network.ClientNet.Shared;
using System.Collections.Generic;
using System.Text;
using System.Text.Json;

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
        return Error.Ok;
    }

    public void DisconnectFromServer()
    {
        _socket.Close();
        if (SessionState.Connected)
        {
            SessionState.Connected = false;
            EmitSignal(SignalName.Disconnected);
        }
    }

    public Error SendBinary(byte[] payload)
    {
        if (_socket.GetReadyState() != WebSocketPeer.State.Open)
        {
            return Error.Unavailable;
        }
        var encoded = _codec.EncodeEnvelope(payload);
        return _socket.Send(encoded);
    }

    public Error SendMessage(Godot.Collections.Dictionary message)
    {
        if (message == null)
        {
            return Error.InvalidData;
        }
        var json = JsonSerializer.Serialize(ToPlainObject(message));
        return SendBinary(Encoding.UTF8.GetBytes(json));
    }

    public override void _Process(double delta)
    {
        _socket.Poll();
        var state = _socket.GetReadyState();

        if (state == WebSocketPeer.State.Open && !SessionState.Connected)
        {
            SessionState.Connected = true;
            EmitSignal(SignalName.Connected);
        }
        else if (state == WebSocketPeer.State.Closed && SessionState.Connected)
        {
            SessionState.Connected = false;
            EmitSignal(SignalName.Disconnected);
        }

        while (_socket.GetAvailablePacketCount() > 0)
        {
            var packet = _socket.GetPacket();
            var payload = WsBinaryFrameReader.ToManagedBytes(packet);
            var decoded = _codec.DecodeEnvelope(payload);
            EmitSignal(SignalName.FrameReceived, decoded);
            var decodedText = Encoding.UTF8.GetString(decoded);
            if (TryParseJsonDictionary(decodedText, out var dict))
            {
                EmitSignal(SignalName.MessageReceived, dict);
            }
        }
    }

    private static bool TryParseJsonDictionary(string text, out Godot.Collections.Dictionary result)
    {
        result = new Godot.Collections.Dictionary();
        if (string.IsNullOrWhiteSpace(text))
        {
            return false;
        }
        var parsed = Json.ParseString(text);
        if (parsed.VariantType != Variant.Type.Dictionary)
        {
            return false;
        }
        result = (Godot.Collections.Dictionary)parsed;
        return true;
    }

    private static object ToPlainObject(Variant variant)
    {
        switch (variant.VariantType)
        {
            case Variant.Type.Dictionary:
                var dict = (Godot.Collections.Dictionary)variant;
                var map = new Dictionary<string, object>();
                foreach (var key in dict.Keys)
                {
                    map[key.ToString() ?? string.Empty] = ToPlainObject((Variant)dict[key]);
                }
                return map;
            case Variant.Type.Array:
                var arr = (Godot.Collections.Array)variant;
                var list = new List<object>();
                foreach (var item in arr)
                {
                    list.Add(ToPlainObject((Variant)item));
                }
                return list;
            case Variant.Type.String:
                return variant.AsString();
            case Variant.Type.Bool:
                return variant.AsBool();
            case Variant.Type.Int:
                return variant.AsInt64();
            case Variant.Type.Float:
                return variant.AsDouble();
            default:
                return variant.ToString();
        }
    }
}

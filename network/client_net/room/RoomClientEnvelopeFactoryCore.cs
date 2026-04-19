using QQTang.Network.ClientNet.Shared;
using QQT.Room.V1;
using System;
using System.Collections;
using System.Collections.Generic;

namespace QQTang.Network.ClientNet.Room;

public sealed class RoomClientEnvelopeFactoryCore
{
    private const string ProtocolVersion = "1";

    public ClientEnvelope BuildEnvelope(IDictionary<string, object?> message, RoomClientSessionState sessionState)
    {
        if (message == null)
        {
            throw new ArgumentNullException(nameof(message));
        }
        if (sessionState == null)
        {
            throw new ArgumentNullException(nameof(sessionState));
        }

        var messageType = ReadString(message, "message_type");
        if (string.IsNullOrWhiteSpace(messageType))
        {
            throw new ArgumentException("message_type is required", nameof(message));
        }

        var requestId = ProtoEnvelopeUtil.NewRequestId();
        var sequence = ProtoEnvelopeUtil.NextSequence(sessionState);
        var envelope = new ClientEnvelope
        {
            ProtocolVersion = ProtocolVersion,
            RequestId = requestId,
            Sequence = sequence,
            SentAtUnixMs = ProtoEnvelopeUtil.UnixTimeMs(),
        };
        sessionState.LastRequestId = requestId;

        switch (messageType)
        {
            case "ROOM_CREATE_REQUEST":
                envelope.CreateRoom = BuildCreateRoom(message);
                break;
            case "ROOM_JOIN_REQUEST":
                envelope.JoinRoom = BuildJoinRoom(message);
                break;
            case "ROOM_RESUME_REQUEST":
                envelope.ResumeRoom = BuildResumeRoom(message);
                break;
            case "ROOM_UPDATE_PROFILE":
                envelope.UpdateProfile = BuildUpdateProfile(message);
                break;
            case "ROOM_UPDATE_SELECTION":
                envelope.UpdateSelection = BuildUpdateSelection(message);
                break;
            case "ROOM_UPDATE_MATCH_ROOM_CONFIG":
                envelope.UpdateMatchRoomConfig = BuildUpdateMatchRoomConfig(message);
                break;
            case "ROOM_TOGGLE_READY":
                envelope.ToggleReady = BuildToggleReady(message);
                break;
            case "ROOM_LEAVE":
                envelope.LeaveRoom = new LeaveRoomRequest();
                break;
            case "ROOM_DIRECTORY_SUBSCRIBE":
                envelope.SubscribeDirectory = new SubscribeDirectoryRequest();
                break;
            case "ROOM_DIRECTORY_REQUEST":
                // Proto room.v1 does not define a dedicated directory request message.
                // Reuse subscribe to trigger a snapshot push from server.
                envelope.SubscribeDirectory = new SubscribeDirectoryRequest();
                break;
            case "ROOM_DIRECTORY_UNSUBSCRIBE":
                envelope.UnsubscribeDirectory = new UnsubscribeDirectoryRequest();
                break;
            case "ROOM_ENTER_MATCH_QUEUE":
                envelope.EnterMatchQueue = BuildEnterMatchQueue(message);
                break;
            case "ROOM_CANCEL_MATCH_QUEUE":
                envelope.CancelMatchQueue = new CancelMatchQueueRequest();
                break;
            case "ROOM_START_REQUEST":
                envelope.StartManualRoomBattle = new StartManualRoomBattleRequest();
                break;
            case "ROOM_ACK_BATTLE_ENTRY":
                envelope.AckBattleEntry = BuildAckBattleEntry(message);
                break;
            default:
                throw new ArgumentException($"unsupported room message_type: {messageType}", nameof(message));
        }

        return envelope;
    }

    private static CreateRoomRequest BuildCreateRoom(IDictionary<string, object?> message)
    {
        return new CreateRoomRequest
        {
            RoomIdHint = ReadString(message, "room_id_hint"),
            RoomKind = ReadString(message, "room_kind"),
            RoomDisplayName = ReadString(message, "room_display_name"),
            RoomTicket = ReadString(message, "room_ticket"),
            RoomTicketId = ReadString(message, "room_ticket_id"),
            AccountId = ReadString(message, "account_id"),
            ProfileId = ReadString(message, "profile_id"),
            DeviceSessionId = ReadString(message, "device_session_id"),
            PlayerName = ReadString(message, "player_name"),
            Loadout = BuildLoadout(message),
            Selection = BuildSelection(message),
        };
    }

    private static JoinRoomRequest BuildJoinRoom(IDictionary<string, object?> message)
    {
        return new JoinRoomRequest
        {
            RoomId = ReadString(message, "room_id", "room_id_hint"),
            RoomTicket = ReadString(message, "room_ticket"),
            RoomTicketId = ReadString(message, "room_ticket_id"),
            AccountId = ReadString(message, "account_id"),
            ProfileId = ReadString(message, "profile_id"),
            DeviceSessionId = ReadString(message, "device_session_id"),
            PlayerName = ReadString(message, "player_name"),
            Loadout = BuildLoadout(message),
        };
    }

    private static ResumeRoomRequest BuildResumeRoom(IDictionary<string, object?> message)
    {
        return new ResumeRoomRequest
        {
            RoomId = ReadString(message, "room_id"),
            MemberId = ReadString(message, "member_id"),
            ReconnectToken = ReadString(message, "reconnect_token"),
            MatchId = ReadString(message, "match_id"),
            RoomTicket = ReadString(message, "room_ticket"),
            RoomTicketId = ReadString(message, "room_ticket_id"),
            AccountId = ReadString(message, "account_id"),
            ProfileId = ReadString(message, "profile_id"),
            DeviceSessionId = ReadString(message, "device_session_id"),
        };
    }

    private static UpdateProfileRequest BuildUpdateProfile(IDictionary<string, object?> message)
    {
        return new UpdateProfileRequest
        {
            PlayerName = ReadString(message, "player_name"),
            TeamId = ReadInt32(message, "team_id"),
            Loadout = BuildLoadout(message),
        };
    }

    private static UpdateSelectionRequest BuildUpdateSelection(IDictionary<string, object?> message)
    {
        return new UpdateSelectionRequest
        {
            Selection = BuildSelection(message),
        };
    }

    private static UpdateMatchRoomConfigRequest BuildUpdateMatchRoomConfig(IDictionary<string, object?> message)
    {
        var request = new UpdateMatchRoomConfigRequest
        {
            MatchFormatId = ReadString(message, "match_format_id"),
        };
        request.SelectedModeIds.Add(ReadStringArray(message, "selected_mode_ids"));
        return request;
    }

    private static ToggleReadyRequest BuildToggleReady(IDictionary<string, object?> message)
    {
        return new ToggleReadyRequest
        {
            ExpectedReady = ReadBool(message, "expected_ready"),
        };
    }

    private static EnterMatchQueueRequest BuildEnterMatchQueue(IDictionary<string, object?> message)
    {
        return new EnterMatchQueueRequest
        {
            QueueType = ReadString(message, "queue_type"),
            MatchFormatId = ReadString(message, "match_format_id"),
        };
    }

    private static AckBattleEntryRequest BuildAckBattleEntry(IDictionary<string, object?> message)
    {
        return new AckBattleEntryRequest
        {
            AssignmentId = ReadString(message, "assignment_id"),
            BattleId = ReadString(message, "battle_id"),
        };
    }

    private static RoomLoadout BuildLoadout(IDictionary<string, object?> message)
    {
        var source = ReadNestedDictionary(message, "loadout") ?? message;
        return new RoomLoadout
        {
            CharacterId = ReadString(source, "character_id"),
            CharacterSkinId = ReadString(source, "character_skin_id"),
            BubbleStyleId = ReadString(source, "bubble_style_id"),
            BubbleSkinId = ReadString(source, "bubble_skin_id"),
        };
    }

    private static RoomSelection BuildSelection(IDictionary<string, object?> message)
    {
        var source = ReadNestedDictionary(message, "selection") ?? message;
        var selection = new RoomSelection
        {
            MapId = ReadString(source, "map_id"),
            RuleSetId = ReadString(source, "rule_set_id"),
            ModeId = ReadString(source, "mode_id"),
            MatchFormatId = ReadString(source, "match_format_id"),
        };
        selection.SelectedModeIds.Add(ReadStringArray(source, "selected_mode_ids"));
        return selection;
    }

    private static IDictionary<string, object?>? ReadNestedDictionary(IDictionary<string, object?> source, string key)
    {
        if (!source.TryGetValue(key, out var value) || value == null)
        {
            return null;
        }
        return value as IDictionary<string, object?>;
    }

    private static string ReadString(IDictionary<string, object?> source, string key, string fallbackKey = "")
    {
        if (source.TryGetValue(key, out var value))
        {
            return ToStringValue(value);
        }
        if (!string.IsNullOrEmpty(fallbackKey) && source.TryGetValue(fallbackKey, out var fallbackValue))
        {
            return ToStringValue(fallbackValue);
        }
        return string.Empty;
    }

    private static string[] ReadStringArray(IDictionary<string, object?> source, string key)
    {
        if (!source.TryGetValue(key, out var value) || value == null || value is string)
        {
            return [];
        }
        if (value is IEnumerable enumerable)
        {
            var list = new List<string>();
            foreach (var item in enumerable)
            {
                list.Add(ToStringValue(item));
            }
            return list.ToArray();
        }
        return [];
    }

    private static int ReadInt32(IDictionary<string, object?> source, string key)
    {
        if (!source.TryGetValue(key, out var value) || value == null)
        {
            return 0;
        }
        return value switch
        {
            int v => v,
            long v => (int)v,
            double v => (int)v,
            float v => (int)v,
            string v when int.TryParse(v, out var parsed) => parsed,
            _ => 0,
        };
    }

    private static bool ReadBool(IDictionary<string, object?> source, string key)
    {
        if (!source.TryGetValue(key, out var value) || value == null)
        {
            return false;
        }
        return value switch
        {
            bool v => v,
            int v => v != 0,
            long v => v != 0,
            string v when bool.TryParse(v, out var parsed) => parsed,
            _ => false,
        };
    }

    private static string ToStringValue(object? value)
    {
        return value switch
        {
            null => string.Empty,
            string v => v,
            _ => value.ToString() ?? string.Empty,
        };
    }
}

using QQT.Room.V1;
using System;
using System.Collections.Generic;

namespace QQTang.Network.ClientNet.Room;

public sealed class RoomCanonicalMessageMapperCore
{
    public Dictionary<string, object?> Map(ServerEnvelope envelope)
    {
        if (envelope == null)
        {
            throw new ArgumentNullException(nameof(envelope));
        }

        return envelope.PayloadCase switch
        {
            ServerEnvelope.PayloadOneofCase.OperationAccepted => MapOperationAccepted(envelope.OperationAccepted, envelope.RequestId),
            ServerEnvelope.PayloadOneofCase.OperationRejected => MapOperationRejected(envelope.OperationRejected, envelope.RequestId),
            ServerEnvelope.PayloadOneofCase.RoomSnapshotPush => MapRoomSnapshotPush(envelope.RoomSnapshotPush),
            ServerEnvelope.PayloadOneofCase.RoomDirectorySnapshotPush => MapRoomDirectorySnapshotPush(envelope.RoomDirectorySnapshotPush),
            ServerEnvelope.PayloadOneofCase.BattleEntryReadyPush => MapBattleEntryReadyPush(envelope.BattleEntryReadyPush),
            ServerEnvelope.PayloadOneofCase.ResumeRejected => MapResumeRejected(envelope.ResumeRejected, envelope.RequestId),
            ServerEnvelope.PayloadOneofCase.ServerNotice => MapServerNotice(envelope.ServerNotice),
            _ => new Dictionary<string, object?>
            {
                { "message_type", "ROOM_SERVER_UNKNOWN" },
                { "request_id", envelope.RequestId },
            },
        };
    }

    private static Dictionary<string, object?> MapOperationAccepted(OperationAccepted accepted, string requestId)
    {
        var messageType = accepted.Operation switch
        {
            "CreateRoom" => "ROOM_CREATE_ACCEPTED",
            "JoinRoom" => "ROOM_JOIN_ACCEPTED",
            "LeaveRoom" => "ROOM_LEAVE_ACCEPTED",
            _ => "ROOM_OPERATION_ACCEPTED",
        };
        return new Dictionary<string, object?>
        {
            { "message_type", messageType },
            { "request_id", SafeString(accepted.RequestId, requestId) },
            { "operation", accepted.Operation },
        };
    }

    private static Dictionary<string, object?> MapOperationRejected(OperationRejected rejected, string requestId)
    {
        var messageType = ResolveRejectedMessageType(rejected.Operation, rejected.Error?.Code ?? string.Empty);
        return new Dictionary<string, object?>
        {
            { "message_type", messageType },
            { "request_id", SafeString(rejected.RequestId, requestId) },
            { "operation", rejected.Operation },
            { "error", rejected.Error?.Code ?? "ROOM_OPERATION_REJECTED" },
            { "user_message", rejected.Error?.UserMessage ?? string.Empty },
        };
    }

    private static Dictionary<string, object?> MapRoomSnapshotPush(RoomSnapshotPush push)
    {
        return new Dictionary<string, object?>
        {
            { "message_type", "ROOM_SNAPSHOT" },
            { "snapshot", RoomSnapshotMapperCore.ToSnapshotDictionary(push.Snapshot ?? new RoomSnapshot()) },
        };
    }

    private static Dictionary<string, object?> MapRoomDirectorySnapshotPush(RoomDirectorySnapshotPush push)
    {
        return new Dictionary<string, object?>
        {
            { "message_type", "ROOM_DIRECTORY_SNAPSHOT" },
            { "snapshot", ToRoomDirectorySnapshotDict(push.Snapshot) },
        };
    }

    private static Dictionary<string, object?> MapBattleEntryReadyPush(BattleEntryReadyPush push)
    {
        var battleEntry = push.BattleEntry;
        return new Dictionary<string, object?>
        {
            { "message_type", "ROOM_MATCH_ASSIGNMENT_READY" },
            { "assignment_id", battleEntry?.AssignmentId ?? string.Empty },
            { "battle_id", battleEntry?.BattleId ?? string.Empty },
            { "match_id", battleEntry?.MatchId ?? string.Empty },
            { "battle_server_host", battleEntry?.ServerHost ?? string.Empty },
            { "battle_server_port", battleEntry?.ServerPort ?? 0 },
            { "battle_entry_ready", battleEntry?.BattleEntryReady ?? false },
        };
    }

    private static Dictionary<string, object?> MapResumeRejected(ResumeRejected rejected, string requestId)
    {
        return new Dictionary<string, object?>
        {
            { "message_type", "ROOM_RESUME_REJECTED" },
            { "request_id", SafeString(rejected.RequestId, requestId) },
            { "error", rejected.Error?.Code ?? "ROOM_RESUME_REJECTED" },
            { "user_message", rejected.Error?.UserMessage ?? string.Empty },
        };
    }

    private static Dictionary<string, object?> MapServerNotice(ServerNotice notice)
    {
        return new Dictionary<string, object?>
        {
            { "message_type", "ROOM_SERVER_NOTICE" },
            { "level", notice.Level },
            { "code", notice.Code },
            { "notice", notice.Message },
        };
    }

    private static Dictionary<string, object?> ToRoomDirectorySnapshotDict(RoomDirectorySnapshot snapshot)
    {
        var entries = new List<object?>();
        if (snapshot != null)
        {
            foreach (var entry in snapshot.Entries)
            {
                entries.Add(new Dictionary<string, object?>
                {
                    { "room_id", entry.RoomId ?? string.Empty },
                    { "room_display_name", entry.RoomDisplayName ?? string.Empty },
                    { "room_kind", entry.RoomKind ?? string.Empty },
                    { "owner_peer_id", 0 },
                    { "owner_name", string.Empty },
                    { "selected_map_id", entry.MapId ?? string.Empty },
                    { "rule_set_id", string.Empty },
                    { "mode_id", entry.ModeId ?? string.Empty },
                    { "member_count", entry.MemberCount },
                    { "max_players", entry.MaxPlayerCount },
                    { "match_active", false },
                    { "joinable", entry.Joinable },
                });
            }
        }
        return new Dictionary<string, object?>
        {
            { "revision", snapshot?.Revision ?? 0L },
            { "server_host", snapshot?.ServerHost ?? string.Empty },
            { "server_port", snapshot?.ServerPort ?? 0 },
            { "entries", entries },
        };
    }

    private static string ResolveRejectedMessageType(string operation, string errorCode)
    {
        if (!string.IsNullOrWhiteSpace(errorCode) && errorCode.StartsWith("ROOM_", StringComparison.Ordinal))
        {
            return errorCode;
        }
        return operation switch
        {
            "CreateRoom" => "ROOM_CREATE_REJECTED",
            "JoinRoom" => "ROOM_JOIN_REJECTED",
            "ResumeRoom" => "ROOM_RESUME_REJECTED",
            "LeaveRoom" => "ROOM_LEAVE_REJECTED",
            _ => "ROOM_OPERATION_REJECTED",
        };
    }

    private static string SafeString(string value, string fallback)
    {
        return string.IsNullOrWhiteSpace(value) ? fallback : value;
    }
}

using QQT.Room.V1;
using System;
using System.Collections.Generic;

namespace QQTang.Network.ClientNet.Room;

public static class RoomSnapshotMapperCore
{
    public static Dictionary<string, object?> ToSnapshotDictionary(RoomSnapshot snapshot)
    {
        if (snapshot == null)
        {
            throw new ArgumentNullException(nameof(snapshot));
        }

        var selection = snapshot.Selection ?? new RoomSelection();
        var battleEntry = snapshot.BattleEntry ?? new BattleEntryState();
        var members = new List<object?>(snapshot.Members.Count);
        var allReady = snapshot.Members.Count > 0;
        for (var i = 0; i < snapshot.Members.Count; i++)
        {
            var roomMember = snapshot.Members[i];
            members.Add(ToMemberDictionary(roomMember, snapshot.OwnerMemberId, i));
            if (allReady && !(roomMember?.Ready ?? false))
            {
                allReady = false;
            }
        }

        return new Dictionary<string, object?>
        {
            { "room_id", snapshot.RoomId ?? string.Empty },
            { "room_kind", snapshot.RoomKind ?? string.Empty },
            { "topology", "dedicated_server" },
            { "room_display_name", snapshot.RoomDisplayName ?? string.Empty },
            { "owner_member_id", snapshot.OwnerMemberId ?? string.Empty },
            { "owner_peer_id", ResolvePeerId(snapshot.OwnerMemberId) },
            { "room_lifecycle_state", snapshot.LifecycleState ?? string.Empty },
            { "snapshot_revision", snapshot.SnapshotRevision },
            { "match_format_id", selection.MatchFormatId ?? string.Empty },
            { "selected_match_mode_ids", ToStringList(selection.SelectedModeIds) },
            { "queue_type", ResolveQueueType(snapshot.RoomKind) },
            { "room_queue_state", snapshot.QueueState ?? string.Empty },
            { "room_queue_entry_id", string.Empty },
            { "battle_entry_ready", battleEntry.BattleEntryReady },
            { "battle_server_host", battleEntry.ServerHost ?? string.Empty },
            { "battle_server_port", battleEntry.ServerPort },
            { "current_assignment_id", battleEntry.AssignmentId ?? string.Empty },
            { "current_battle_id", battleEntry.BattleId ?? string.Empty },
            { "current_match_id", battleEntry.MatchId ?? string.Empty },
            { "all_ready", allReady },
            { "selected_map_id", selection.MapId ?? string.Empty },
            { "rule_set_id", selection.RuleSetId ?? string.Empty },
            { "mode_id", selection.ModeId ?? string.Empty },
            { "members", members },
        };
    }

    private static Dictionary<string, object?> ToMemberDictionary(RoomMember member, string ownerMemberId, int slotIndex)
    {
        var loadout = member?.Loadout ?? new RoomLoadout();
        var memberId = member?.MemberId ?? string.Empty;
        return new Dictionary<string, object?>
        {
            { "peer_id", ResolvePeerId(memberId) },
            { "member_id", memberId },
            { "account_id", member?.AccountId ?? string.Empty },
            { "profile_id", member?.ProfileId ?? string.Empty },
            { "player_name", member?.PlayerName ?? string.Empty },
            { "ready", member?.Ready ?? false },
            { "team_id", member?.TeamId ?? 0 },
            { "character_id", loadout.CharacterId ?? string.Empty },
            { "character_skin_id", loadout.CharacterSkinId ?? string.Empty },
            { "bubble_style_id", loadout.BubbleStyleId ?? string.Empty },
            { "bubble_skin_id", loadout.BubbleSkinId ?? string.Empty },
            { "connection_state", member?.ConnectionState ?? string.Empty },
            { "slot_index", slotIndex },
            { "is_owner", string.Equals(memberId, ownerMemberId ?? string.Empty, StringComparison.Ordinal) },
            { "is_local_player", false },
        };
    }

    private static List<object?> ToStringList(Google.Protobuf.Collections.RepeatedField<string> values)
    {
        var result = new List<object?>(values.Count);
        foreach (var value in values)
        {
            result.Add(value ?? string.Empty);
        }
        return result;
    }

    private static int TryParseInt(string value)
    {
        return int.TryParse(value, out var parsed) ? parsed : 0;
    }

    private static int ResolvePeerId(string memberId)
    {
        var parsedInt = TryParseInt(memberId);
        if (parsedInt > 0)
        {
            return parsedInt;
        }

        var normalized = memberId?.Trim() ?? string.Empty;
        if (!string.IsNullOrEmpty(normalized))
        {
            var lastDash = normalized.LastIndexOf("-");
            if (lastDash >= 0 && lastDash + 1 < normalized.Length)
            {
                var tail = normalized.Substring(lastDash + 1);
                if (int.TryParse(tail, out var tailId) && tailId > 0)
                {
                    return tailId;
                }
            }
        }

        uint hash = 2166136261;
        for (var i = 0; i < normalized.Length; i++)
        {
            hash ^= normalized[i];
            hash *= 16777619;
        }

        var positive = (int)(hash & 0x7FFFFFFF);
        return positive > 0 ? positive : 1;
    }

    private static string ResolveQueueType(string roomKind)
    {
        var kind = (roomKind ?? string.Empty).Trim();
        if (string.Equals(kind, "ranked_match_room", StringComparison.Ordinal))
        {
            return "ranked";
        }
        if (string.Equals(kind, "casual_match_room", StringComparison.Ordinal))
        {
            return "casual";
        }
        return string.Empty;
    }

}

package wsapi

import (
	"fmt"

	"google.golang.org/protobuf/encoding/protowire"
)

type PayloadType int

const (
	PayloadUnknown PayloadType = iota
	PayloadCreateRoom
	PayloadJoinRoom
	PayloadResumeRoom
)

type ClientEnvelope struct {
	ProtocolVersion string
	RequestID       string
	Sequence        int64
	SentAtUnixMS    int64
	PayloadType     PayloadType
	CreateRoom      *CreateRoomPayload
	JoinRoom        *JoinRoomPayload
	ResumeRoom      *ResumeRoomPayload
}

type CreateRoomPayload struct {
	RoomKind        string
	RoomDisplayName string
	RoomTicket      string
	AccountID       string
	ProfileID       string
	PlayerName      string
	Loadout         LoadoutPayload
	Selection       SelectionPayload
}

type JoinRoomPayload struct {
	RoomID     string
	RoomTicket string
	AccountID  string
	ProfileID  string
	PlayerName string
	Loadout    LoadoutPayload
}

type ResumeRoomPayload struct {
	RoomID         string
	MemberID       string
	ReconnectToken string
	RoomTicket     string
}

type LoadoutPayload struct {
	CharacterID     string
	CharacterSkinID string
	BubbleStyleID   string
	BubbleSkinID    string
}

type SelectionPayload struct {
	MapID         string
	RuleSetID     string
	ModeID        string
	MatchFormatID string
}

func DecodeClientEnvelope(payload []byte) (*ClientEnvelope, error) {
	var env ClientEnvelope
	for len(payload) > 0 {
		num, typ, n := protowire.ConsumeTag(payload)
		if n < 0 {
			return nil, fmt.Errorf("consume tag failed: %d", n)
		}
		payload = payload[n:]
		switch num {
		case 1:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume protocol_version failed: %d", m)
			}
			env.ProtocolVersion = value
			payload = payload[m:]
		case 2:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume request_id failed: %d", m)
			}
			env.RequestID = value
			payload = payload[m:]
		case 3:
			value, m := protowire.ConsumeVarint(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume sequence failed: %d", m)
			}
			env.Sequence = int64(value)
			payload = payload[m:]
		case 4:
			value, m := protowire.ConsumeVarint(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume sent_at_unix_ms failed: %d", m)
			}
			env.SentAtUnixMS = int64(value)
			payload = payload[m:]
		case 10:
			if typ != protowire.BytesType {
				return nil, fmt.Errorf("create_room payload wire type mismatch")
			}
			raw, m := protowire.ConsumeBytes(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume create_room failed: %d", m)
			}
			create, err := decodeCreateRoom(raw)
			if err != nil {
				return nil, err
			}
			env.PayloadType = PayloadCreateRoom
			env.CreateRoom = create
			payload = payload[m:]
		case 11:
			if typ != protowire.BytesType {
				return nil, fmt.Errorf("join_room payload wire type mismatch")
			}
			raw, m := protowire.ConsumeBytes(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume join_room failed: %d", m)
			}
			join, err := decodeJoinRoom(raw)
			if err != nil {
				return nil, err
			}
			env.PayloadType = PayloadJoinRoom
			env.JoinRoom = join
			payload = payload[m:]
		case 12:
			if typ != protowire.BytesType {
				return nil, fmt.Errorf("resume_room payload wire type mismatch")
			}
			raw, m := protowire.ConsumeBytes(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume resume_room failed: %d", m)
			}
			resume, err := decodeResumeRoom(raw)
			if err != nil {
				return nil, err
			}
			env.PayloadType = PayloadResumeRoom
			env.ResumeRoom = resume
			payload = payload[m:]
		default:
			m := protowire.ConsumeFieldValue(num, typ, payload)
			if m < 0 {
				return nil, fmt.Errorf("skip unknown field %d failed: %d", num, m)
			}
			payload = payload[m:]
		}
	}
	if env.PayloadType == PayloadUnknown {
		return nil, fmt.Errorf("envelope payload is empty")
	}
	return &env, nil
}

func decodeCreateRoom(payload []byte) (*CreateRoomPayload, error) {
	result := &CreateRoomPayload{}
	for len(payload) > 0 {
		num, typ, n := protowire.ConsumeTag(payload)
		if n < 0 {
			return nil, fmt.Errorf("consume create_room tag failed: %d", n)
		}
		payload = payload[n:]
		switch num {
		case 2:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume room_kind failed: %d", m)
			}
			result.RoomKind = value
			payload = payload[m:]
		case 3:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume room_display_name failed: %d", m)
			}
			result.RoomDisplayName = value
			payload = payload[m:]
		case 4:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume room_ticket failed: %d", m)
			}
			result.RoomTicket = value
			payload = payload[m:]
		case 6:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume account_id failed: %d", m)
			}
			result.AccountID = value
			payload = payload[m:]
		case 7:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume profile_id failed: %d", m)
			}
			result.ProfileID = value
			payload = payload[m:]
		case 9:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume player_name failed: %d", m)
			}
			result.PlayerName = value
			payload = payload[m:]
		case 10:
			raw, m := protowire.ConsumeBytes(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume loadout failed: %d", m)
			}
			loadout, err := decodeLoadout(raw)
			if err != nil {
				return nil, err
			}
			result.Loadout = loadout
			payload = payload[m:]
		case 11:
			raw, m := protowire.ConsumeBytes(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume selection failed: %d", m)
			}
			selection, err := decodeSelection(raw)
			if err != nil {
				return nil, err
			}
			result.Selection = selection
			payload = payload[m:]
		default:
			m := protowire.ConsumeFieldValue(num, typ, payload)
			if m < 0 {
				return nil, fmt.Errorf("skip create_room field %d failed: %d", num, m)
			}
			payload = payload[m:]
		}
	}
	return result, nil
}

func decodeJoinRoom(payload []byte) (*JoinRoomPayload, error) {
	result := &JoinRoomPayload{}
	for len(payload) > 0 {
		num, typ, n := protowire.ConsumeTag(payload)
		if n < 0 {
			return nil, fmt.Errorf("consume join_room tag failed: %d", n)
		}
		payload = payload[n:]
		switch num {
		case 1:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume room_id failed: %d", m)
			}
			result.RoomID = value
			payload = payload[m:]
		case 2:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume room_ticket failed: %d", m)
			}
			result.RoomTicket = value
			payload = payload[m:]
		case 4:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume account_id failed: %d", m)
			}
			result.AccountID = value
			payload = payload[m:]
		case 5:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume profile_id failed: %d", m)
			}
			result.ProfileID = value
			payload = payload[m:]
		case 7:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume player_name failed: %d", m)
			}
			result.PlayerName = value
			payload = payload[m:]
		case 8:
			raw, m := protowire.ConsumeBytes(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume loadout failed: %d", m)
			}
			loadout, err := decodeLoadout(raw)
			if err != nil {
				return nil, err
			}
			result.Loadout = loadout
			payload = payload[m:]
		default:
			m := protowire.ConsumeFieldValue(num, typ, payload)
			if m < 0 {
				return nil, fmt.Errorf("skip join_room field %d failed: %d", num, m)
			}
			payload = payload[m:]
		}
	}
	return result, nil
}

func decodeResumeRoom(payload []byte) (*ResumeRoomPayload, error) {
	result := &ResumeRoomPayload{}
	for len(payload) > 0 {
		num, typ, n := protowire.ConsumeTag(payload)
		if n < 0 {
			return nil, fmt.Errorf("consume resume_room tag failed: %d", n)
		}
		payload = payload[n:]
		switch num {
		case 1:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume room_id failed: %d", m)
			}
			result.RoomID = value
			payload = payload[m:]
		case 2:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume member_id failed: %d", m)
			}
			result.MemberID = value
			payload = payload[m:]
		case 3:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume reconnect_token failed: %d", m)
			}
			result.ReconnectToken = value
			payload = payload[m:]
		case 5:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return nil, fmt.Errorf("consume room_ticket failed: %d", m)
			}
			result.RoomTicket = value
			payload = payload[m:]
		default:
			m := protowire.ConsumeFieldValue(num, typ, payload)
			if m < 0 {
				return nil, fmt.Errorf("skip resume_room field %d failed: %d", num, m)
			}
			payload = payload[m:]
		}
	}
	return result, nil
}

func decodeLoadout(payload []byte) (LoadoutPayload, error) {
	var result LoadoutPayload
	for len(payload) > 0 {
		num, typ, n := protowire.ConsumeTag(payload)
		if n < 0 {
			return LoadoutPayload{}, fmt.Errorf("consume loadout tag failed: %d", n)
		}
		payload = payload[n:]
		switch num {
		case 1:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return LoadoutPayload{}, fmt.Errorf("consume character_id failed: %d", m)
			}
			result.CharacterID = value
			payload = payload[m:]
		case 2:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return LoadoutPayload{}, fmt.Errorf("consume character_skin_id failed: %d", m)
			}
			result.CharacterSkinID = value
			payload = payload[m:]
		case 3:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return LoadoutPayload{}, fmt.Errorf("consume bubble_style_id failed: %d", m)
			}
			result.BubbleStyleID = value
			payload = payload[m:]
		case 4:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return LoadoutPayload{}, fmt.Errorf("consume bubble_skin_id failed: %d", m)
			}
			result.BubbleSkinID = value
			payload = payload[m:]
		default:
			m := protowire.ConsumeFieldValue(num, typ, payload)
			if m < 0 {
				return LoadoutPayload{}, fmt.Errorf("skip loadout field %d failed: %d", num, m)
			}
			payload = payload[m:]
		}
	}
	return result, nil
}

func decodeSelection(payload []byte) (SelectionPayload, error) {
	var result SelectionPayload
	for len(payload) > 0 {
		num, typ, n := protowire.ConsumeTag(payload)
		if n < 0 {
			return SelectionPayload{}, fmt.Errorf("consume selection tag failed: %d", n)
		}
		payload = payload[n:]
		switch num {
		case 1:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return SelectionPayload{}, fmt.Errorf("consume map_id failed: %d", m)
			}
			result.MapID = value
			payload = payload[m:]
		case 2:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return SelectionPayload{}, fmt.Errorf("consume rule_set_id failed: %d", m)
			}
			result.RuleSetID = value
			payload = payload[m:]
		case 3:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return SelectionPayload{}, fmt.Errorf("consume mode_id failed: %d", m)
			}
			result.ModeID = value
			payload = payload[m:]
		case 4:
			value, m := protowire.ConsumeString(payload)
			if m < 0 {
				return SelectionPayload{}, fmt.Errorf("consume match_format_id failed: %d", m)
			}
			result.MatchFormatID = value
			payload = payload[m:]
		default:
			m := protowire.ConsumeFieldValue(num, typ, payload)
			if m < 0 {
				return SelectionPayload{}, fmt.Errorf("skip selection field %d failed: %d", num, m)
			}
			payload = payload[m:]
		}
	}
	return result, nil
}

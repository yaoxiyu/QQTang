package contentmanifest

import (
	"encoding/json"
	"fmt"
	"os"
)

type Loader struct {
	path     string
	manifest *Manifest
}

func LoadFromFile(path string) (*Loader, error) {
	if path == "" {
		return nil, fmt.Errorf("manifest path is empty")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read manifest: %w", err)
	}
	var m Manifest
	if err := json.Unmarshal(data, &m); err != nil {
		return nil, fmt.Errorf("decode manifest: %w", err)
	}
	if m.SchemaVersion <= 0 {
		return nil, fmt.Errorf("manifest schema_version is invalid")
	}
	return &Loader{path: path, manifest: &m}, nil
}

func (l *Loader) Path() string {
	if l == nil {
		return ""
	}
	return l.path
}

func (l *Loader) Manifest() *Manifest {
	if l == nil {
		return nil
	}
	return l.manifest
}

func (l *Loader) Ready() bool {
	return l != nil && l.manifest != nil && l.manifest.SchemaVersion > 0
}

func (l *Loader) FindMap(mapID string) *MapEntry {
	if l == nil || l.manifest == nil {
		return nil
	}
	for i := range l.manifest.Maps {
		if l.manifest.Maps[i].MapID == mapID {
			return &l.manifest.Maps[i]
		}
	}
	return nil
}

func (l *Loader) FirstMap() *MapEntry {
	if l == nil || l.manifest == nil || len(l.manifest.Maps) == 0 {
		return nil
	}
	return &l.manifest.Maps[0]
}

func (l *Loader) FindMatchFormat(matchFormatID string) *MatchFormat {
	if l == nil || l.manifest == nil {
		return nil
	}
	for i := range l.manifest.MatchFormats {
		if l.manifest.MatchFormats[i].MatchFormatID == matchFormatID {
			return &l.manifest.MatchFormats[i]
		}
	}
	return nil
}

func (l *Loader) FirstMatchFormat() *MatchFormat {
	if l == nil || l.manifest == nil || len(l.manifest.MatchFormats) == 0 {
		return nil
	}
	return &l.manifest.MatchFormats[0]
}

func (l *Loader) HasLegalCharacterID(characterID string) bool {
	if l == nil || l.manifest == nil {
		return false
	}
	return contains(l.manifest.Assets.LegalCharacterIDs, characterID)
}

func (l *Loader) HasLegalCharacterSkinID(characterSkinID string) bool {
	if l == nil || l.manifest == nil {
		return false
	}
	if characterSkinID == "" {
		return true
	}
	return contains(l.manifest.Assets.LegalCharacterSkinIDs, characterSkinID)
}

func (l *Loader) HasLegalBubbleStyleID(bubbleStyleID string) bool {
	if l == nil || l.manifest == nil {
		return false
	}
	return contains(l.manifest.Assets.LegalBubbleStyleIDs, bubbleStyleID)
}

func (l *Loader) HasLegalBubbleSkinID(bubbleSkinID string) bool {
	if l == nil || l.manifest == nil {
		return false
	}
	if bubbleSkinID == "" {
		return true
	}
	return contains(l.manifest.Assets.LegalBubbleSkinIDs, bubbleSkinID)
}

func contains(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}

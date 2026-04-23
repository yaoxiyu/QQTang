package manifest

import "qqtang/services/shared/contentmanifest"

type MapEntry = contentmanifest.MapEntry
type ModeEntry = contentmanifest.ModeEntry
type RuleEntry = contentmanifest.RuleEntry
type MatchFormat = contentmanifest.MatchFormat
type Assets = contentmanifest.Assets
type Manifest = contentmanifest.Manifest
type Loader = contentmanifest.Loader

func LoadFromFile(path string) (*Loader, error) {
	return contentmanifest.LoadFromFile(path)
}

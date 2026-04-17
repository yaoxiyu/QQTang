# LEGACY / PROTOTYPE FILE
# Retained for historical testing or LegacyMigration compatibility.
# Not part of the production battle startup path.

class_name TestContext
extends RefCounted

var world: SimWorld = null
var runner: Node = null
var bridge: Node = null

var tick: int = 0

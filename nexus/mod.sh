#!/bin/bash

MOD_DESCRIPTION=$(
	cat <<'DESCRIPTION'
The mod disables notifications messages in top left corner of screen for more immersive gameplay.

[b]Currently supported profiles:[/b]
[list]
%PROFILES%
[/list]

[b]If you found unsupported notification please open a bug.[/b]

[b]As a side effect it disables sounds linked to notification.[/b]

[i]Replace %INI% during installation via mod manager.[/i]

DESCRIPTION
)

MOD_PROFILE=$(
	cat <<'PROFILE'
[*][b]%PROFILE%[/b]:
[list]
%SECTIONS%
[/list]
PROFILE
)

MOD_SECTION=$(
	cat <<'SECTION'
[*]%SECTION%
SECTION
)

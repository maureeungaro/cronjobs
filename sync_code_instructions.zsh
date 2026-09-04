#!/bin/zsh

ilocation="$HOME/myenv/code"
proj_location="/opt/projects"

function remake_link() {
	efile=$1
	nlink=$2
	rm -f $efile
	ln -s $nlink $efile
}

typeset -A codes_inst=(
	binder.md  "gemc/binder-tutorials"
	g4install.md "gemc/g4install"
	gemc_clas12Tags.md "gemc/clas12Tags"
	gemc_home.md "gemc/home"
	gemc_src.md "gemc/src"
	gemc_pygemc.md "gemc/pygemc"
	clas12-systems.md "gemc/clas12-systems"
	myhome.md "home"
	simgrid.md "gemc/simGrid"
	casetta.md "casetta"
	threadscaling.md "gemc/ThreadScale"
	tech_note.md "pubs/notes/clas12_notes"
)


# codex/claude main
remake_link $HOME/.codex/AGENTS.md  $ilocation/global.md
remake_link $HOME/.claude/CLAUDE.md $ilocation/global.md
remake_link $HOME/.claude/settings.json $ilocation/claude_settings.json


for this_instr dest_instr in ${(kv)codes_inst}; do
	remake_link  "$proj_location/$dest_instr/AGENTS.md" "$ilocation/$this_instr"
	remake_link  "$proj_location/$dest_instr/CLAUDE.md" "$ilocation/$this_instr"
done

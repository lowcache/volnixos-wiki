# Project Instructions

## Memory protocol (managed by memd)
Read `./.memory/state.md`, `decisions.md`, `mistakes.md`, and `todo.md` before
substantive work. They are distilled automatically after sessions — keep them
authoritative. To leave an explicit note for the memory curator (from any CLI,
agent, or swarm member), write a markdown file into `./.memory/inbox/`.

Do not hand-edit the four memory files; the curator rewrites them on every pass.

Read by Claude Code. With memd's hooks installed the session-start brief is
injected automatically, so this file mainly states the contract for humans and
subagents.

## Delegation

Any token heavy tasks that are able to be delegated should be done so through the use of
`tether` and passed to either Gemini or opencode, or both. `Tether` has been made more
reliable and consistent through updates to its codebase, but the limits to which it can
handle certain tasks is unknown, and testing of its limits is perfect in a repo like this
one.

## Wiki drift

The wiki needs to reflect the configuration at ~/.nix-config/ which is the entire point. If
the wiki is not correctly explaining the configuration that is a huge problem that can easily 
be solved with a check each time work is done on this repo. 

During the process of checking that the wiki is accuratly reflecting the configuration the first
step is to check the directory at ~/.nix-config/docs/wikifixins/ for any markdown files that 
have corrections/additions/removals for the wiki. Whenever a change that would 
contradict the wiki or is not represented at all is made, a markdown note is saved in that
directory. So whenever work is done on this wiki, the first thing to check is that folder.

Once any wiki drift is taken care of, or delegated to opencode or gemini through the use of 
`tether`, you can move on to any technical issues. 


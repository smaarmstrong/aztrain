# Convenience wrappers around ./aztrain, for when you just want to practise and
# not think about the command surface.
#
# New to Azure?  Let it teach you first:
#
#     make learn     # explains the next task, then sets it up so you can try it
#     ...do the task (edit workspace files, or run az yourself for cloud tasks)...
#     make check     # grade it   (then `make learn` again for the next one)
#
# Already know the ropes?  Just practise:
#
#     make train     # picks what you should do next (new material or a review)
#     make check     # grade it
#
# `make train` decides on its own whether to give you new material (in a
# fundamentals-first teaching order) or bring back something older for review.
# It will PRESENT cloud tasks but never provision them for you — you start those
# yourself (your az login, your bill). Everything here forwards to ./aztrain;
# run `make help`, or `./aztrain help` for the full CLI (start/reset/teardown
# and per-task ids).

AZTRAIN := ./aztrain
.DEFAULT_GOAL := help

.PHONY: help learn train next check solution list status cli

help: ; @printf 'aztrain — just run one of:\n\n  make learn      teach the next task, then set it up to try\n  make train      pick the next task for you (new material, or a review)\n  make check      grade the task you are currently on\n  make solution   reveal the reference solution for it\n  make list       every task, grouped by track/domain, with your status\n  make status     your XP, streak and completion\n\nFull CLI (start/reset/teardown a specific task by id):  $(AZTRAIN) help\n'

learn:    ; @$(AZTRAIN) learn
train:    ; @$(AZTRAIN) train
next:     ; @$(AZTRAIN) train
check:    ; @$(AZTRAIN) check
solution: ; @$(AZTRAIN) solution
list:     ; @$(AZTRAIN) list
status:   ; @$(AZTRAIN) status
cli:      ; @$(AZTRAIN) help

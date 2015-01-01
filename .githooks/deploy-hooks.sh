#!/bin/sh
# Deploy hooks stored in your git repo to everyone!
#
# I keep this in $ROOT/$HOOK_DIR/deploy
# From the top level of your git repo, run ./hook/deploy (or equivalent) after
# cloning or adding a new hook.
# No output is good output.

BASE=`git rev-parse --git-dir`
ROOT=`git rev-parse --show-toplevel`
HOOK_DIR=.githooks # change to .githooks or whatever
HOOKS=$ROOT/$HOOK_DIR/*

if [ ! -d "$ROOT/$HOOK_DIR" ]
then
    echo "Couldn't find hooks dir"
    exit 1
fi

rm -f $BASE/hooks/*
for HOOK in $HOOKS
do
    (cd $BASE/hooks ; ln -s $HOOK `basename $HOOK` || echo "Failed to link $HOOK to `basename $HOOK`")
done

SUBMODULES=`git submodule`
if [ -n "$SUBMODULES" ]
then
    for SM in `grep path $BASE/../.gitmodules | sed 's/.*= //'`
    do
        SMHOOKS=$BASE/modules/$SM/hooks
        rm -f $SMHOOKS/*
        for HOOK in $HOOKS
        do
            (cd $SMHOOKS ; ln -s $HOOK `basename $HOOK` || echo "Failed to link $HOOK to `basename $HOOK`")
        done
    done
fi

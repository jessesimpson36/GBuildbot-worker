#!/bin/sh

# find all llvm lld binaries and create symlink for them

## may not be necessary anymore after switching to gentoo base image
# find /usr/bin/ -iname 'llvm-*-11' |
# while read line
# do
# 	BASE_NAME=$(echo $line | sed 's,-11$,,')
# 	echo "LINK $line to $BASE_NAME"
# 	ln -s $line $BASE_NAME
# done
# 
# find /usr/bin/ -iname '*lld-*-11' |
# while read line
# do
# 	BASE_NAME=$(echo $line | sed 's,-11$,,')
# 	echo "LINK $line to $BASE_NAME"
# 	ln -s $line $BASE_NAME
# done
# 
# find /usr/bin/ -iname '*lld-11' |
# while read line
# do
# 	BASE_NAME=$(echo $line | sed 's,-11$,,')
# 	echo "LINK $line to $BASE_NAME"
# 	ln -s $line $BASE_NAME
# done
